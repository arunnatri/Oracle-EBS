--
-- XXD_PO_POMODIFY_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_POMODIFY_UTILS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PO_POMODIFY_UTILS_PKG
    * Design       : This package is used to modify purchase order from PO Modify Utility OA Page
    * Notes        :
    * Modification :
    -- ==========================================================================================================================================
    -- Date         Version#    Name                    Comments
    -- ==========================================================================================================================================
    -- 16-Aug-2019  1.0         Tejaswi Gangumalla      Initial version
    -- 13-Apr-2020  1.1         Tejaswi Gangumalla      CCR0008501
    -- 09-Jun-2020  1.2         Kranthi Bollam          CCR0008710 - Fix Incorrect Ship to Location on Distributor PO's
    -- 07-Jul-2020  2.0         Gaurav Joshi            CCR0008752    PO Reroutes for Direct Ship POs
    -- 29-Jun-2021  3.0         Gaurav Joshi            CCR0009391 - PO Modify Utility Bug
    -- 21-OCT-2021  3.1         Showkath Ali            CCR0009609
    -- 12-Jan-2022  3.2         Shivanshu Talwar        CCR0010003  POC Enhancements
 -- 25-May-2022  3.3         Aravind Kannuri         CCR0010003  POC Enhancements
    -- 22-Aug-2022  3.4         Gowrishankar Chakrapani CCR0010003  POC Enhancements
 -- 15-Feb-2023  3.5         Ramesh BR               CCR0010446  P2P Modify tool : Provide correct Intransit time  for factory to Malaysia destination - US7
    *********************************************************************************************************************************************/
    -- ==========================================================================================================================================

    gv_mo_profile_option_name      CONSTANT VARCHAR2 (240)
                                                := 'MO: Security Profile' ;
    gv_responsibility_name         CONSTANT VARCHAR2 (240)
        := 'Deckers Purchasing User - Global' ;
    gv_mo_profile_option_name_so   CONSTANT VARCHAR2 (240)
                                                := 'MO: Operating Unit' ;
    gv_responsibility_name_so      CONSTANT VARCHAR2 (240)
        := 'Deckers Order Management User' ;
    gv_source_code                          VARCHAR2 (20) := 'PO_Modify';
    gn_request_id                           NUMBER
                                                := fnd_global.conc_request_id;

    -- ver 3.0 begin
    FUNCTION GET_ITEM_DESC (P_inventory_item_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_item_description   mtl_system_items_b.description%TYPE;
    BEGIN
        l_item_description   := NULL;

        --Get the territory short name from the territories lookup
        SELECT description
          INTO l_item_description
          FROM apps.mtl_system_items_b a, mtl_parameters b
         WHERE     ORGANIZATION_CODE = 'MST'
               AND inventory_item_id = P_inventory_item_id
               AND a.ORGANIZATION_ID = b.ORGANIZATION_ID;

        RETURN l_item_description;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN l_item_description;
    END GET_ITEM_DESC;

    --  ver 3.0 end


    -- ver 3.0 begin
    FUNCTION GET_SHIP_METHOD (P_VENDOR_ID        IN NUMBER,
                              P_VENDOR_SITE_id   IN NUMBER,
                              P_PO_TYPE          IN VARCHAR2,
                              P_DEST_COUNTRY     IN VARCHAR2,
                              p_po_header_id     IN NUMBER DEFAULT NULL -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022
                                                                       )
        RETURN VARCHAR2
    IS
        v_territory_short_name      VARCHAR2 (50);
        v_preferred_ship_method     VARCHAR2 (20);
        lv_po_dest_country          VARCHAR2 (50);
        --lv_po_number                NUMBER := p_po_num;
        ln_po_header_id             NUMBER := p_po_header_id;
        ln_po_line_vendor_site_id   NUMBER := 0;
    BEGIN
        -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022
        fnd_file.put_line (
            fnd_file.LOG,
            '-------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'GET_SHIP_METHOD - ln_po_header_id : ' || ln_po_header_id);
        fnd_file.put_line (fnd_file.LOG,
                           'GET_SHIP_METHOD - P_VENDOR_ID : ' || p_vendor_id);
        fnd_file.put_line (
            fnd_file.LOG,
            'GET_SHIP_METHOD - P_VENDOR_SITE_id : ' || p_vendor_site_id);
        fnd_file.put_line (fnd_file.LOG,
                           'GET_SHIP_METHOD - P_PO_TYPE : ' || p_po_type);
        fnd_file.put_line (
            fnd_file.LOG,
            'GET_SHIP_METHOD - P_DEST_COUNTRY : ' || p_dest_country);

        ln_po_line_vendor_site_id   := 0;

        -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022
        -- Changes for for CCR0010003 Starts
        /*
          --Get New PO Header ID
       BEGIN
        SELECT po_header_id
       INTO ln_po_header_id
       FROM po_headers_all
       WHERE segment1 = lv_po_number;
       EXCEPTION
        WHEN OTHERS
       THEN
         ln_po_header_id := NULL;
       END;
       */

        fnd_file.put_line (
            fnd_file.LOG,
            'GET_SHIP_METHOD - ln_po_header_id : ' || ln_po_header_id); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022

        --Get PO destination region
        lv_po_dest_country          := get_po_country_code (ln_po_header_id);

        fnd_file.put_line (
            fnd_file.LOG,
            'GET_SHIP_METHOD - lv_po_dest_country : ' || lv_po_dest_country); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022

        fnd_file.put_line (
            fnd_file.LOG,
            '-------------------------------------------------------------'); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022


        BEGIN
            SELECT assa.vendor_site_id
              INTO ln_po_line_vendor_site_id
              FROM ap_supplier_sites_all assa, po_lines_all pla
             WHERE     assa.vendor_site_code = pla.attribute7
                   AND assa.vendor_id = p_vendor_id
                   AND pla.po_header_id = ln_po_header_id
                   AND pla.attribute7 IS NOT NULL
                   AND ROWNUM = 1;

            fnd_file.put_line (
                fnd_file.LOG,
                   'GET_SHIP_METHOD - ln_po_line_vendor_site_id : '
                || ln_po_line_vendor_site_id); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_po_line_vendor_site_id   := p_vendor_site_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'GET_SHIP_METHOD - ln_po_line_vendor_site_id Exception: '
                    || SQLCODE
                    || ' - '
                    || SQLERRM); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'GET_SHIP_METHOD - ln_po_line_vendor_site_id : '
            || ln_po_line_vendor_site_id); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022

        -- Changes for for CCR0010003 Ends


        IF P_PO_TYPE LIKE 'SAMPLE%'
        THEN
            RETURN 'Air';
        ELSE
            BEGIN
                --Get the territory short name from the territories lookup
                SELECT territory_short_name
                  INTO v_territory_short_name
                  FROM fnd_territories_vl
                 WHERE territory_code = lv_po_dest_country;  --P_DEST_COUNTRY;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'GET_SHIP_METHOD - v_territory_short_name : '
                    || v_territory_short_name); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022
                fnd_file.put_line (
                    fnd_file.LOG,
                    'GET_SHIP_METHOD - p_vendor_id : ' || p_vendor_id); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022
                --fnd_file.put_line(fnd_file.log, 'GET_SHIP_METHOD - p_vendor_site_id : '||p_vendor_site_id); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022
                fnd_file.put_line (
                    fnd_file.LOG,
                       'GET_SHIP_METHOD - ln_po_line_vendor_site_id : '
                    || ln_po_line_vendor_site_id); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022

                --Set the ship method based on the po type and drop ship flag
                SELECT flv.attribute8
                  INTO v_preferred_ship_method
                  FROM FND_LOOKUP_VALUES FLV, ap_supplier_sites_all aps
                 WHERE     FLV.LANGUAGE = 'US'
                       AND aps.vendor_id = p_vendor_id
                       AND aps.vendor_site_id = ln_po_line_vendor_site_id --p_vendor_site_id
                       AND FLV.LOOKUP_TYPE = 'XXDO_SUPPLIER_INTRANSIT'
                       AND FLV.ATTRIBUTE1 = TO_CHAR (p_vendor_id)
                       AND FLV.ATTRIBUTE2 = aps.vendor_site_code
                       AND FLV.ATTRIBUTE4 = v_territory_short_name
                       AND SYSDATE BETWEEN flv.start_date_active
                                       AND NVL (flv.end_date_active,
                                                SYSDATE + 1);

                fnd_file.put_line (
                    fnd_file.LOG,
                       'GET_SHIP_METHOD - v_preferred_ship_method : '
                    || v_preferred_ship_method); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022

                RETURN NVL (v_preferred_ship_method, 'Ocean');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'GET_SHIP_METHOD - WHEN NO_DATA_FOUND : '
                        || v_preferred_ship_method); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022

                    RETURN 'Ocean';
                WHEN OTHERS
                THEN
                    RETURN 'Ocean';
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'GET_SHIP_METHOD - Preferred Ship Method : '
                || v_preferred_ship_method); -- Added by Gowrishankar for CCR0010003 on 31-Aug-2022
        END IF;
    END GET_SHIP_METHOD;

    --  ver 3.0 end
    PROCEDURE set_purchasing_context (pn_user_id IN NUMBER, pn_org_id IN NUMBER, pv_error_flag OUT VARCHAR2
                                      , pv_error_msg OUT VARCHAR2)
    IS
        pv_msg            VARCHAR2 (2000);
        pv_stat           VARCHAR2 (1);
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;
    BEGIN
        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name = gv_responsibility_name
                   AND fpov.profile_option_value IN
                           (SELECT security_profile_id
                              FROM apps.per_security_organizations
                             WHERE organization_id = pn_org_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_flag   := 'E';
                pv_error_msg    :=
                    SUBSTR (
                           'Error getting Purchasing context resp_id : '
                        || SQLERRM,
                        1,
                        2000);
        END;

        IF NVL (pv_error_flag, 'S') <> 'E'
        THEN
            --do intialize and purchssing setup
            apps.fnd_global.apps_initialize (pn_user_id,
                                             ln_resp_id,
                                             ln_resp_appl_id);
            mo_global.init ('PO');
            mo_global.set_policy_context ('S', pn_org_id);
            fnd_request.set_org_id (pn_org_id);
            pv_error_flag   := 'S';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_flag   := 'S';
            pv_error_msg    := SUBSTR (SQLERRM, 1, 2000);
    END set_purchasing_context;

    PROCEDURE set_om_context (pn_user_id IN NUMBER, pn_org_id IN NUMBER, pv_error_flag OUT VARCHAR2
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
                       gv_mo_profile_option_name_so
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name_so || '%'
                   AND fpov.profile_option_value = TO_CHAR (pn_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_flag   := 'E';
                pv_error_msg    :=
                    SUBSTR ('Error getting OM context resp_id : ' || SQLERRM,
                            1,
                            2000);
        END;

        IF NVL (pv_error_flag, 'S') <> 'E'
        THEN
            apps.fnd_global.apps_initialize (pn_user_id,
                                             ln_resp_id,
                                             ln_resp_appl_id);
            apps.oe_msg_pub.initialize;
            apps.oe_debug_pub.initialize;
            apps.mo_global.init ('ONT');
            apps.mo_global.set_org_context (pn_org_id, NULL, 'ONT');
            apps.fnd_global.set_nls_context ('AMERICAN');
            apps.mo_global.set_policy_context ('S', pn_org_id);
            pv_error_flag   := 'S';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_flag   := 'E';
            pv_error_msg    := SUBSTR (SQLERRM, 1, 2000);
    END set_om_context;

    PROCEDURE run_req_import (pv_import_source   IN     VARCHAR2,
                              pn_batch_id        IN     VARCHAR2,
                              pn_org_id          IN     NUMBER,
                              pn_inv_org_id      IN     NUMBER,
                              pn_user_id         IN     NUMBER,
                              pv_status             OUT VARCHAR,
                              pv_msg                OUT VARCHAR2,
                              pn_request_id         OUT NUMBER)
    AS
        ln_request_id     NUMBER;
        ln_req_id         NUMBER;
        l_req_status      BOOLEAN;
        x_ret_stat        VARCHAR2 (1);
        x_error_text      VARCHAR2 (20000);
        lv_phase          VARCHAR2 (80);
        lv_status         VARCHAR2 (80);
        lv_dev_phase      VARCHAR2 (80);
        lv_dev_status     VARCHAR2 (80);
        lv_message        VARCHAR2 (255);
        ln_app_id         NUMBER;
        ln_cnt            NUMBER;
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;
        ln_user_id        NUMBER;
        lv_error_flag     VARCHAR2 (50);
        lv_error_msg      VARCHAR2 (4000);

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
             WHERE     interface_source_code = pv_import_source
                   AND request_id = ln_request_id
                   AND batch_id = pn_batch_id
                   AND process_flag = 'ERROR';
    BEGIN
        set_purchasing_context (pn_user_id, pn_org_id, lv_error_flag,
                                lv_error_msg);

        IF lv_error_flag <> 'S'
        THEN
            pv_status   := 'E';
            pv_msg      :=
                'Error while Settting purchasing context ' || lv_error_msg;
        ELSE
            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'PO',
                    program       => 'REQIMPORT',
                    argument1     => pv_import_source,
                    argument2     => pn_batch_id,
                    argument3     => 'VENDOR',
                    argument4     => '',
                    argument5     => 'N',
                    argument6     => 'Y');
            COMMIT;
            l_req_status    :=
                apps.fnd_concurrent.wait_for_request (
                    request_id   => ln_request_id,
                    INTERVAL     => 10,
                    max_wait     => 0,
                    phase        => lv_phase,
                    status       => lv_status,
                    dev_phase    => lv_dev_phase,
                    dev_status   => lv_dev_status,
                    MESSAGE      => lv_message);

            IF NVL (lv_dev_status, 'ERROR') != 'NORMAL'
            THEN
                IF NVL (lv_dev_status, 'ERROR') = 'WARNING'
                THEN
                    x_ret_stat   := 'W';
                ELSE
                    x_ret_stat   := apps.fnd_api.g_ret_sts_error;
                END IF;

                x_error_text   :=
                    NVL (
                        lv_message,
                           'The requisition import request ended with a status of '
                        || NVL (lv_dev_status, 'ERROR'));
                pv_msg   := x_error_text;
            ELSE
                x_ret_stat   := 'S';
            END IF;

            --check for interface records from above request in error state and error out the corresponding stage records
            IF x_ret_stat = 'S'
            THEN
                ln_cnt   := 0;

                FOR err_rec IN c_err
                LOOP
                    ln_cnt   := ln_cnt + 1;
                END LOOP;

                IF ln_cnt > 0
                THEN
                    x_ret_stat   := 'W';
                    x_error_text   :=
                        'One or more records failed to interface to a requisition line';
                END IF;
            END IF;

            pv_status       := x_ret_stat;
            pv_msg          := x_error_text;
            pn_request_id   := ln_request_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_status       := 'U';
            pv_msg          :=
                   ' requisition import failed with unexpected error '
                || SQLERRM;
            pn_request_id   := NULL;
    END run_req_import;

    PROCEDURE po_approval (pv_po_num IN VARCHAR2, pn_org_id IN NUMBER, pv_error_flag OUT VARCHAR2
                           , pv_error_msg OUT VARCHAR2)
    IS
        l_api_errors              po_api_errors_rec_type;
        ln_po_header_id           NUMBER;
        ln_org_id                 NUMBER;
        lv_po_num                 VARCHAR2 (50);
        lv_doc_type               VARCHAR2 (50);
        lv_doc_sub_type           VARCHAR2 (50);
        lv_return_status          VARCHAR2 (1);
        ln_api_version   CONSTANT NUMBER := 2.0;
        lv_api_name      CONSTANT VARCHAR2 (50) := 'UPDATE_DOCUMENT';
        g_pkg_name       CONSTANT VARCHAR2 (30) := 'PO_DOCUMENT_UPDATE_GRP';
        ln_progress               VARCHAR2 (3) := '000';
        ln_agent_id               NUMBER;
        lv_item_key               VARCHAR2 (100);
    BEGIN
        ln_org_id          := pn_org_id;
        lv_po_num          := pv_po_num;

        BEGIN
            SELECT pha.po_header_id, pha.agent_id, pdt.document_subtype,
                   pdt.document_type_code, pha.wf_item_key
              INTO ln_po_header_id, ln_agent_id, lv_doc_sub_type, lv_doc_type,
                                  lv_item_key
              FROM apps.po_headers_all pha, apps.po_document_types_all pdt
             WHERE     pha.type_lookup_code = pdt.document_subtype
                   AND pha.org_id = pn_org_id
                   AND pdt.document_type_code = 'PO'
                   AND segment1 = pv_po_num;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_flag   := 'E';
        END;

        --calling seeded procedure to launch the po approval workflow
        po_reqapproval_init1.start_wf_process (itemtype => 'POAPPRV', itemkey => lv_item_key, workflowprocess => 'XXDO_POAPPRV_TOP', actionoriginatedfrom => 'PO_FORM', documentid => ln_po_header_id, documentnumber => lv_po_num -- Purchase Order Number
                                                                                                                                                                                                                                  , preparerid => ln_agent_id -- Buyer/Preparer_id
                                                                                                                                                                                                                                                             , documenttypecode => 'PO' --'PO'
                                                                                                                                                                                                                                                                                       , documentsubtype => 'STANDARD' --'STANDARD'
                                                                                                                                                                                                                                                                                                                      , submitteraction => 'APPROVE', forwardtoid => NULL, forwardfromid => NULL, defaultapprovalpathid => NULL, note => NULL, printflag => 'N', faxflag => 'N', faxnumber => NULL, emailflag => 'N', emailaddress => NULL, createsourcingrule => 'N', releasegenmethod => 'N', updatesourcingrule => 'N', massupdatereleases => 'N', retroactivepricechange => 'N', orgassignchange => 'N', communicatepricechange => 'N', p_background_flag => 'N', p_initiator => NULL, p_xml_flag => NULL, fpdsngflag => 'N'
                                               , p_source_type_code => NULL);
        lv_return_status   := fnd_api.g_ret_sts_success;

        IF (lv_return_status = 'S')
        THEN
            pv_error_flag   := 'S';
        ELSE
            pv_error_flag   := 'E';
        END IF;
    EXCEPTION
        WHEN fnd_api.g_exc_unexpected_error
        THEN
            pv_error_flag   := 'E';
            pv_error_msg    := SUBSTR (SQLERRM, 1, 2000);
        WHEN OTHERS
        THEN
            pv_error_msg    := SUBSTR (SQLERRM, 1, 2000);
            pv_error_flag   := 'E';
    END po_approval;

    PROCEDURE cancel_po_line (pn_user_id IN NUMBER, pn_header_id IN NUMBER, pn_line_id IN NUMBER
                              , pv_cancel_req_line IN VARCHAR2, pv_status_flag OUT VARCHAR2, pv_error_message OUT VARCHAR2)
    IS
        ln_org_id          NUMBER;
        lv_error_flag      VARCHAR2 (2);
        lv_error_msg       VARCHAR2 (4000);
        lv_doc_type        po_document_types.document_type_code%TYPE := 'PO';
        lv_doc_subtype     po_document_types.document_subtype%TYPE
                               := 'STANDARD';
        lv_return_status   VARCHAR2 (1);
        lv_cancel_reason   VARCHAR2 (50)
            := 'Cancelled From PO Modify Tool-' || gn_request_id;
    --Added for change 1.1
    BEGIN
        BEGIN
            SELECT pha.org_id
              INTO ln_org_id
              FROM po_headers_all pha
             WHERE pha.po_header_id = pn_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status_flag   := 'E';
                pv_error_message   :=
                       'Error while fetching org_id for purchase order '
                    || SQLERRM;
        END;

        set_purchasing_context (pn_user_id, ln_org_id, lv_error_flag,
                                lv_error_msg);

        IF lv_error_flag <> 'S'
        THEN
            pv_status_flag   := 'E';
            pv_error_message   :=
                'Error while Settting purchasing context ' || lv_error_msg;
        ELSE
            po_document_control_pub.control_document (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, x_return_status => lv_return_status, p_doc_type => lv_doc_type, p_doc_subtype => lv_doc_subtype, p_doc_id => pn_header_id, p_doc_num => NULL, p_release_id => NULL, p_release_num => NULL, p_doc_line_id => pn_line_id, p_doc_line_num => NULL, p_doc_line_loc_id => NULL, p_doc_shipment_num => NULL, p_action => 'CANCEL', p_action_date => SYSDATE, p_cancel_reason => lv_cancel_reason, --NULL,Added for change 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_cancel_reqs_flag => pv_cancel_req_line, p_print_flag => NULL, p_note_to_vendor => NULL, p_use_gldate => NULL
                                                      , p_org_id => ln_org_id);

            IF lv_return_status <> 'S'
            THEN
                FOR i IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    pv_error_message   :=
                        (fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F'));
                END LOOP;

                pv_status_flag   := 'E';
                pv_error_message   :=
                    'Error While Cancelling Po Line ' || pv_error_message;
            ELSE
                pv_status_flag   := 'S';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_status_flag     := 'E';
            pv_error_message   := 'Error In Cancel_Po Proc: ' || SQLERRM;
    END cancel_po_line;

    PROCEDURE cancel_req_line (pn_user_id         IN     NUMBER,
                               pn_req_header_id   IN     NUMBER,
                               pn_req_line_id     IN     NUMBER,
                               pv_status_flag        OUT VARCHAR2,
                               pv_error_message      OUT VARCHAR2)
    IS
        ln_org_id                NUMBER;
        ln_preparer_id           NUMBER;
        lv_type_lookup_code      VARCHAR2 (100);
        lv_error_flag            VARCHAR2 (2);
        lv_error_msg             VARCHAR2 (4000);
        x_req_control_error_rc   VARCHAR2 (4000);
    BEGIN
        BEGIN
            SELECT porh.org_id, porh.preparer_id, porh.type_lookup_code
              INTO ln_org_id, ln_preparer_id, lv_type_lookup_code
              FROM po_requisition_lines_all porl, po_requisition_headers_all porh
             WHERE     porl.requisition_header_id =
                       porh.requisition_header_id
                   AND porl.requisition_line_id = 2277139;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status_flag   := 'E';
                pv_error_message   :=
                       'Error while fetching org_id for purchase order '
                    || SQLERRM;
        END;

        set_purchasing_context (pn_user_id, ln_org_id, lv_error_flag,
                                lv_error_msg);

        IF lv_error_flag <> 'S'
        THEN
            pv_status_flag   := 'E';
            pv_error_message   :=
                'Error while Settting purchasing context ' || lv_error_msg;
        ELSE
            BEGIN
                po_reqs_control_sv.update_reqs_status (
                    x_req_header_id          => pn_req_header_id,
                    x_req_line_id            => pn_req_line_id,
                    x_agent_id               => ln_preparer_id,
                    x_req_doc_type           => 'REQUISITION',
                    x_req_doc_subtype        => lv_type_lookup_code,
                    x_req_control_action     => 'CANCEL',
                    x_req_control_reason     => 'CANCELLED BY API FOR PO MODIFY',
                    x_req_action_date        => SYSDATE,
                    x_encumbrance_flag       => 'N',
                    x_oe_installed_flag      => 'Y',
                    x_req_control_error_rc   => x_req_control_error_rc);

                IF x_req_control_error_rc IS NOT NULL
                THEN
                    pv_status_flag     := 'E';
                    pv_error_message   := x_req_control_error_rc;
                ELSE
                    pv_status_flag   := 'S';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_status_flag     := 'E';
                    pv_error_message   := SQLERRM;
            END;
        END IF;
    END cancel_req_line;

    PROCEDURE cancel_so_line (pn_user_id         IN     NUMBER,
                              pn_header_id       IN     NUMBER,
                              pn_line_id         IN     NUMBER,
                              pv_status_flag        OUT VARCHAR2,
                              pv_error_message      OUT VARCHAR2)
    IS
        ln_org_id          NUMBER;
        lv_error_flag      VARCHAR2 (2);
        lv_error_msg       VARCHAR2 (4000);
        p_header_rec       apps.oe_order_pub.header_rec_type;
        p_line_tbl         apps.oe_order_pub.line_tbl_type;
        p_price_adj_tbl    apps.oe_order_pub.line_adj_tbl_type;
        lv_cancel_reason   VARCHAR2 (100) := 'SYSTEM';
        x_header_rec       apps.oe_order_pub.header_rec_type;
        x_header_adj_tbl   apps.oe_order_pub.header_adj_tbl_type;
        x_line_tbl         apps.oe_order_pub.line_tbl_type;
        x_line_adj_tbl     apps.oe_order_pub.line_adj_tbl_type;
        ln_user_id         NUMBER;
    BEGIN
        SELECT user_id
          INTO ln_user_id
          FROM fnd_user
         WHERE user_name = fnd_profile.VALUE ('XXD_POC_USER');

        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM apps.oe_order_headers_all
             WHERE header_id = pn_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status_flag   := 'E';
                pv_error_message   :=
                       'Error while fetching org_id for purchase order '
                    || SQLERRM;
        END;

        set_om_context (ln_user_id, ln_org_id, lv_error_flag,
                        lv_error_msg);

        IF lv_error_flag <> 'S'
        THEN
            pv_status_flag   := 'E';
            pv_error_message   :=
                'Error while Settting OM context ' || lv_error_msg;
        ELSE
            p_header_rec             := apps.oe_order_pub.g_miss_header_rec;
            p_header_rec.operation   := apps.oe_globals.g_opr_update;
            p_header_rec.header_id   := pn_header_id;

            IF pn_line_id IS NOT NULL
            THEN
                p_line_tbl (p_line_tbl.COUNT + 1)                :=
                    apps.oe_order_pub.g_miss_line_rec;
                p_line_tbl (p_line_tbl.COUNT).operation          :=
                    apps.oe_globals.g_opr_update;
                p_line_tbl (p_line_tbl.COUNT).header_id          := pn_header_id;
                p_line_tbl (p_line_tbl.COUNT).line_id            := pn_line_id;
                p_line_tbl (p_line_tbl.COUNT).ordered_quantity   := 0;
                p_line_tbl (p_line_tbl.COUNT).attribute15        := 'C';
                p_line_tbl (p_line_tbl.COUNT).attribute16        := '';
                --Clear out the Attribute16 flag for ISO orders
                p_line_tbl (p_line_tbl.COUNT).change_reason      :=
                    lv_cancel_reason;
            ELSE
                p_header_rec.cancelled_flag   := 'Y';
                p_header_rec.change_reason    := lv_cancel_reason;
            END IF;

            apps.do_oe_utils.call_process_order (
                p_header_rec       => p_header_rec,
                p_line_tbl         => p_line_tbl,
                x_header_rec       => x_header_rec,
                x_header_adj_tbl   => x_header_adj_tbl,
                x_line_tbl         => x_line_tbl,
                x_line_adj_tbl     => x_line_adj_tbl,
                x_return_status    => lv_error_flag,
                x_error_text       => lv_error_msg,
                p_do_commit        => 0);

            IF NVL (lv_error_flag, 'U') != 'S'
            THEN
                pv_status_flag     := 'E';
                pv_error_message   := lv_error_msg;
            ELSE
                pv_status_flag   := 'S';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_status_flag   := 'E';
            pv_error_message   :=
                'Error In Cancel_So_Line procedure ' || SQLERRM;
    END cancel_so_line;

    PROCEDURE create_purchase_req (pn_user_id IN NUMBER, pn_header_id IN NUMBER, pt_line_det IN xxdo.xxd_po_line_det_type, pn_dest_org_id IN NUMBER, pn_vendor_id IN NUMBER, pn_vendor_site_id IN NUMBER, pv_new_req_num OUT VARCHAR2, pn_req_import_id OUT NUMBER, pv_error_flag OUT VARCHAR2
                                   , pv_error_message OUT VARCHAR2)
    IS
        CURSOR new_req_det_cur IS
              SELECT prha.interface_source_code,
                     DECODE (pn_dest_org_id,
                             NULL, prha.org_id,
                             (SELECT operating_unit
                                FROM org_organization_definitions
                               WHERE organization_id = (pn_dest_org_id)))
                         org_id,
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
                     NVL (pn_dest_org_id, prla.destination_organization_id)
                         destination_organization_id,
                     (SELECT location_id
                        FROM hr_organization_units
                       WHERE organization_id =
                             NVL (pn_dest_org_id,
                                  prla.destination_organization_id))
                         deliver_to_location_id,
                     prla.to_person_id
                         deliver_to_requestor_id,
                     prla.item_id,
                     NVL (pn_vendor_id, prla.vendor_id)
                         vendor,
                     NVL (pn_vendor_site_id, prla.vendor_site_id)
                         vendor_site,
                     prla.need_by_date,
                     p_po_line_tab.po_line_id,
                     prla.requisition_line_id,
                     (SELECT MAX (plla.promised_date)
                        FROM po_line_locations_all plla
                       WHERE plla.po_line_id = p_po_line_tab.po_line_id)
                         po_promised_date
                FROM po_requisition_headers_all prha, po_requisition_lines_all prla, mtl_parameters mpa,
                     mtl_system_items_b msib, TABLE (pt_line_det) p_po_line_tab, hr_operating_units hou
               WHERE     prha.requisition_header_id =
                         prla.requisition_header_id
                     AND ((pn_dest_org_id IS NOT NULL AND mpa.organization_id = pn_dest_org_id) OR (pn_dest_org_id IS NULL AND prla.destination_organization_id = mpa.organization_id))
                     AND hou.organization_id = prha.org_id
                     AND prla.item_id = msib.inventory_item_id
                     AND prla.destination_organization_id =
                         msib.organization_id
                     AND prla.requisition_line_id =
                         p_po_line_tab.requisition_line_id
            ORDER BY prla.line_num;

        lv_authorization_status   VARCHAR2 (20) := 'APPROVED';
        ln_batch_id               NUMBER := xxd_po_modify_interface_s.NEXTVAL;
        lv_org_id                 NUMBER := NULL;
        lv_organization_id        NUMBER := NULL;
        ln_req_import_id          NUMBER := 0;
        ln_new_req_num            NUMBER := 0;
        lv_error_flag             VARCHAR2 (100);
        lv_error_msg              VARCHAR2 (4000);
        ln_cnt                    NUMBER;
        ln_rec_count              NUMBER;
        ln_employee_id            NUMBER;
    BEGIN
        --Get employee_id for the user
        BEGIN
            SELECT employee_id
              INTO ln_employee_id
              FROM fnd_user
             WHERE user_id = pn_user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_flag   := 'E';
                pv_error_message   :=
                    'Employee_id not found for user_id ' || pn_user_id;
                RETURN;
        END;

        FOR new_req_det_rec IN new_req_det_cur
        LOOP
            BEGIN
                lv_org_id   := new_req_det_rec.org_id;
                lv_organization_id   :=
                    new_req_det_rec.destination_organization_id;

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
                                    ln_batch_id,
                                    gv_source_code,
                                    new_req_det_rec.org_id,
                                    new_req_det_rec.destination_type_code,
                                    lv_authorization_status,
                                    ln_employee_id,
                                    new_req_det_rec.charge_account_id,
                                    new_req_det_rec.source_type_code,
                                    new_req_det_rec.source_organization_id,
                                    new_req_det_rec.uom_code,
                                    new_req_det_rec.line_type_id,
                                    new_req_det_rec.quantity,
                                    new_req_det_rec.unit_price,
                                    new_req_det_rec.destination_organization_id,
                                    new_req_det_rec.deliver_to_location_id,
                                    ln_employee_id,
                                    new_req_det_rec.item_id,
                                    new_req_det_rec.vendor,
                                    new_req_det_rec.vendor_site,
                                    NVL (new_req_det_rec.po_promised_date,
                                         new_req_det_rec.need_by_date),
                                    SYSDATE,
                                    pn_user_id,
                                    SYSDATE,
                                    pn_user_id,
                                    'P',
                                    new_req_det_rec.po_line_id,
                                    new_req_det_rec.requisition_line_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_message   :=
                           'Error in Creating Data Into Requisition Interface Table : '
                        || SQLERRM;
                    RETURN;
            END;
        END LOOP;

        run_req_import (pv_import_source   => gv_source_code,
                        pn_batch_id        => TO_CHAR (ln_batch_id),
                        pn_org_id          => lv_org_id,
                        pn_inv_org_id      => lv_organization_id,
                        pn_user_id         => pn_user_id,
                        pv_status          => lv_error_flag,
                        pv_msg             => lv_error_msg,
                        pn_request_id      => ln_req_import_id);

        IF ln_req_import_id IS NOT NULL
        THEN
            BEGIN
                  SELECT COUNT (*), prha.segment1
                    INTO ln_cnt, ln_new_req_num
                    FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla
                   WHERE     prha.requisition_header_id =
                             prla.requisition_header_id
                         AND prha.interface_source_code = gv_source_code
                         AND prha.request_id = ln_req_import_id
                GROUP BY prha.segment1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_new_req_num   := NULL;
                WHEN OTHERS
                THEN
                    ln_new_req_num   := NULL;
            END;

            pv_new_req_num     := ln_new_req_num;
            pn_req_import_id   := ln_req_import_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_flag      := 'E';
            pv_error_message   := SQLERRM;
    END create_purchase_req;

    PROCEDURE add_lines_to_po (
        pv_intercompany_flag   IN     VARCHAR2,                     -- VER 3.0
        pn_user_id             IN     NUMBER,
        pn_move_po_header_id   IN     NUMBER,
        pn_new_req_header_id   IN     NUMBER,
        pt_line_det            IN     xxdo.xxd_po_line_det_type,
        pn_batch_id               OUT NUMBER,
        pv_error_flag             OUT VARCHAR2,
        pv_error_message          OUT VARCHAR2)
    IS
        ln_interface_header_id      NUMBER := po_headers_interface_s.NEXTVAL;
        ln_batch_id                 NUMBER := xxd_po_modify_interface_s.NEXTVAL;
        lv_po_num                   VARCHAR2 (100);
        ln_vendor_id                NUMBER;
        ln_vendor_site_id           NUMBER;
        ln_ship_to_location_id      NUMBER;
        ln_bill_to_location_id      NUMBER;
        lv_currency_code            VARCHAR2 (50);
        ln_agent_id                 NUMBER;
        ln_org_id                   NUMBER;
        lv_error_flag               VARCHAR2 (5);
        lv_error_msg                VARCHAR2 (4000);
        ln_line_num                 NUMBER;
        lv_new_line_attribute11     VARCHAR2 (150) := NULL;
        ln_line_interface_id        NUMBER;
        lv_return_status            VARCHAR2 (50);
        ln_processed_lines_count    NUMBER := 0;
        ln_rejected_lines_count     NUMBER := 0;
        lv_err_tolerance_exceeded   VARCHAR2 (100);
        lv_document_number          VARCHAR2 (100);
        ln_document_id              NUMBER;
        po_status                   VARCHAR2 (50);
        lv_ship_method              VARCHAR2 (100);                 -- ver 3.0
        l_item_description          mtl_system_items_b.description%TYPE;
        ln_line_vendor_site_id      NUMBER;           --added w.r.t CCR0010003
        ln_source_ir_line_id        NUMBER;           --added w.r.t CCR0010003
        ln_source_ir_head_id        NUMBER;           --added w.r.t CCR0010003

        CURSOR po_lines_interface_cursor IS
            SELECT prla.requisition_line_id, prla.requisition_header_id, -- ver 3.0
                                                                         -- prla.quantity, 3.0 commented
                                                                         p_po_line_tab.po_line_open_qty quantity, -- added for 3.0
                   prla.item_id, prla.job_id, prla.need_by_date,
                   prla.unit_price, prla.drop_ship_flag, pla.po_header_id,
                   pla.po_line_id, pla.attribute_category, pla.attribute1,
                   pla.attribute2, pla.attribute5, pla.attribute7,
                   pla.attribute8, pla.attribute9, pla.attribute11,
                   pla.attribute13, pla.attribute15 original_line_qty,  -- 3.1
                                                                       pla.line_num,
                   plla.attribute_category shipment_attr_category, plla.attribute4 ship_attribute4, plla.attribute5 ship_attribute5,
                   plla.attribute7 ship_attribute7, plla.attribute8 ship_attribute8, plla.attribute10 ship_attribute10,
                   plla.attribute11 ship_attribute11, plla.attribute12 ship_attribute12, plla.attribute13 ship_attribute13,
                   plla.attribute14 ship_attribute14
              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prd,
                   po_lines_all pla, po_line_locations_all plla, -- po_distributions_all pda,
                                                                 TABLE (pt_line_det) p_po_line_tab
             WHERE     1 = 1
                   AND prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prla.requisition_line_id = prd.requisition_line_id
                   AND prla.requisition_line_id =
                       p_po_line_tab.requisition_line_id
                   -- AND pla.po_header_id = pda.po_header_id
                   --AND pla.po_line_id = pda.po_line_id
                   AND pla.po_line_id = p_po_line_tab.po_line_id
                   AND pla.po_line_id = plla.po_line_id
                   AND NVL (plla.cancel_flag, 'N') = 'Y'            -- ver 3.0
                   AND plla.cancel_reason LIKE
                           'Cancelled From PO Modify Tool%'         -- ver 3.0
                   AND pn_new_req_header_id IS NULL
            UNION
            SELECT prla.requisition_line_id, prla.requisition_header_id, -- ver 3.0
                                                                         prla.quantity,
                   prla.item_id, prla.job_id, prla.need_by_date,
                   prla.unit_price, prla.drop_ship_flag, pla.po_header_id,
                   pla.po_line_id, pla.attribute_category, pla.attribute1,
                   pla.attribute2, pla.attribute5, pla.attribute7,
                   pla.attribute8, pla.attribute9, pla.attribute11,
                   pla.attribute13, pla.attribute15 original_line_qty,  -- 3.1
                                                                       pla.line_num,
                   plla.attribute_category shipment_attr_category, plla.attribute4 ship_attribute4, plla.attribute5 ship_attribute5,
                   plla.attribute7 ship_attribute7, plla.attribute8 ship_attribute8, plla.attribute10 ship_attribute10,
                   plla.attribute11 ship_attribute11, plla.attribute12 ship_attribute12, plla.attribute13 ship_attribute13,
                   plla.attribute14 ship_attribute14
              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_lines_all pla,
                   po_line_locations_all plla
             WHERE     prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prha.requisition_header_id = pn_new_req_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND TO_CHAR (pla.po_line_id) = prla.attribute1
                   AND pn_new_req_header_id IS NOT NULL
            ORDER BY line_num                                       -- Ver 2.0
                             ;

        -- ver 3.0 added cursor to get line destination country. it is required to get ship method
        CURSOR c_get_dest_country (p_in_req_header_id   NUMBER,
                                   p_in_req_line_id     NUMBER)
        IS
            (SELECT hl.country
               FROM hr_locations hl, hr_all_organization_units haou, po_requisition_lines_all prla
              WHERE     hl.location_id = haou.location_id
                    AND requisition_header_id = p_in_req_header_id
                    AND requisition_line_id = p_in_req_line_id
                    AND haou.organization_id =
                        NVL (
                            (SELECT porl.destination_organization_id
                               FROM po_requisition_headers_all porh, po_requisition_lines_all porl, oe_order_headers_all oha,
                                    oe_order_lines_all ola, mtl_reservations mtr
                              WHERE     oha.header_id = ola.header_id
                                    AND porh.requisition_header_id =
                                        porl.requisition_header_id
                                    AND ola.source_document_id =
                                        porh.requisition_header_id
                                    AND ola.source_document_line_id =
                                        porl.requisition_line_id
                                    AND prla.requisition_line_id =
                                        mtr.supply_source_line_id
                                    AND prla.requisition_header_id =
                                        mtr.supply_source_header_id
                                    AND mtr.supply_source_type_id = 17
                                    AND mtr.demand_source_line_id =
                                        ola.line_id),
                            prla.destination_organization_id));
    BEGIN
        --Getting PO details to which new lines have to be added
        BEGIN
            SELECT segment1,
                   vendor_id,
                   vendor_site_id,
                   ship_to_location_id,
                   bill_to_location_id,
                   currency_code,
                   agent_id,
                   org_id,
                   NVL (
                       (SELECT assa.vendor_site_id
                          FROM ap_supplier_sites_all assa, po_lines_all pla
                         WHERE     assa.vendor_site_code = pla.attribute7
                               AND assa.vendor_id = pha.vendor_id
                               AND pla.po_header_id = pha.po_header_id
                               AND pla.attribute7 IS NOT NULL
                               AND ROWNUM = 1),
                       vendor_site_id) line_vendor_site_id --added as part of CCR0010003
              INTO lv_po_num, ln_vendor_id, ln_vendor_site_id, ln_ship_to_location_id,
                            ln_bill_to_location_id, lv_currency_code, ln_agent_id,
                            ln_org_id, ln_line_vendor_site_id --added as part of CCR0010003
              FROM apps.po_headers_all pha
             WHERE po_header_id = pn_move_po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_flag   := 'E';
                pv_error_message   :=
                       'Error in procedure add_lines_to_po when fetching po detais '
                    || SQLERRM;
        END;

        set_purchasing_context (pn_user_id, ln_org_id, lv_error_flag,
                                lv_error_msg);

        IF lv_error_flag <> 'S'
        THEN
            pv_error_flag   := 'E';
            pv_error_message   :=
                'Error while Settting purchasing context ' || lv_error_msg;
        ELSE
            --Inserting into po header interface
            BEGIN
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
                     VALUES (ln_interface_header_id, ln_batch_id, 'UPDATE',
                             ln_org_id, 'STANDARD', lv_po_num,
                             lv_currency_code, ln_agent_id, ln_vendor_id,
                             ln_vendor_site_id, ln_ship_to_location_id, ln_bill_to_location_id
                             , 1234, pn_move_po_header_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_flag   := 'E';
                    pv_error_message   :=
                           'Error in procedure add_lines_to_po when loading header data into po_header_interface'
                        || SQLERRM;
            END;

            BEGIN
                SELECT MAX (line_num)
                  INTO ln_line_num
                  FROM po_lines_all pla, po_headers_all pha
                 WHERE     pha.po_header_id = pla.po_header_id
                       AND pha.po_header_id = pn_move_po_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_flag   := 'E';
                    pv_error_message   :=
                           'Error in procedure add_lines_to_po when getting max line number'
                        || SQLERRM;
            END;

            FOR po_lines_interface_rec IN po_lines_interface_cursor
            LOOP
                ln_line_num            := ln_line_num + 1;
                lv_ship_method         := NULL;

                -- ver 3.0 open cursor to get Dest coutnry

                IF pv_intercompany_flag = 'Y'        --Start  w.r.t CCR0010003
                THEN
                    BEGIN
                        SELECT source_ir_line_id, source_ir_header_id
                          INTO ln_source_ir_line_id, ln_source_ir_head_id
                          FROM xxdo.xxd_po_modify_details_t
                         WHERE     intercompany_po_flag = 'Y'
                               AND source_ir_line_id IS NOT NULL
                               AND source_pr_line_id =
                                   po_lines_interface_rec.requisition_line_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_source_ir_line_id   := NULL;
                            ln_source_ir_head_id   := NULL;
                    END;

                    FOR i
                        IN c_get_dest_country (
                               NVL (
                                   ln_source_ir_head_id,
                                   po_lines_interface_rec.requisition_header_id),
                               NVL (
                                   ln_source_ir_line_id,
                                   po_lines_interface_rec.requisition_line_id))
                    LOOP
                        -- use dest country to get ship method
                        lv_ship_method   :=
                            get_ship_method (
                                ln_vendor_id,
                                -- ln_vendor_site_id, commented as part of CCR0010003
                                NVL (ln_line_vendor_site_id,
                                     ln_vendor_site_id), --added as part of CCR0010003
                                'STANDARD',
                                i.country,
                                po_lines_interface_rec.po_header_id     --NULL
                                                                   );
                    END LOOP;
                ELSE                                   --End  w.r.t CCR0010003
                    FOR i
                        IN c_get_dest_country (
                               po_lines_interface_rec.requisition_header_id,
                               po_lines_interface_rec.requisition_line_id)
                    LOOP
                        -- use dest country to get ship method

                        lv_ship_method   :=
                            get_ship_method (
                                ln_vendor_id,
                                -- ln_vendor_site_id, commented as part of CCR0010003
                                NVL (ln_line_vendor_site_id,
                                     ln_vendor_site_id), --added as part of CCR0010003
                                'STANDARD',
                                i.country,
                                po_lines_interface_rec.po_header_id     --NULL
                                                                   );
                    END LOOP;
                END IF;                                --End  w.r.t CCR0010003

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

                BEGIN
                    SELECT po_lines_interface_s.NEXTVAL
                      INTO ln_line_interface_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_flag   := 'E';
                        pv_error_message   :=
                               'Error in procedure add_lines_to_po when geeting linr interface id'
                            || SQLERRM;
                END;

                -- ver 3.0 get item description
                l_item_description     :=
                    get_item_desc (po_lines_interface_rec.item_id);

                BEGIN
                    INSERT INTO po_lines_interface (
                                    interface_line_id,
                                    interface_header_id,
                                    line_num,
                                    job_id,
                                    action,
                                    line_type,
                                    item_id,
                                    item_description,               -- ver 3.0
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
                                    line_attribute15,                    --3.1
                                    shipment_attribute_category,
                                    shipment_attribute4,
                                    shipment_attribute5,
                                    shipment_attribute6,            -- ver 3.0
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
                                        ln_interface_header_id,
                                        ln_line_num,
                                        po_lines_interface_rec.job_id,
                                        'ADD',
                                        NULL,
                                        po_lines_interface_rec.item_id,
                                        l_item_description,         -- ver 3.0
                                        po_lines_interface_rec.requisition_line_id,
                                        po_lines_interface_rec.quantity,
                                        po_lines_interface_rec.unit_price,
                                        ln_ship_to_location_id,
                                        po_lines_interface_rec.need_by_date,
                                        po_lines_interface_rec.need_by_date,
                                        po_lines_interface_rec.unit_price,
                                        pn_user_id,
                                        SYSDATE,
                                        pn_user_id,
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
                                        po_lines_interface_rec.original_line_qty, --3.1
                                        po_lines_interface_rec.shipment_attr_category,
                                        po_lines_interface_rec.ship_attribute4,
                                        po_lines_interface_rec.ship_attribute5,
                                        DECODE (pv_intercompany_flag,
                                                'Y', 'Y',
                                                NULL), -- ver 3.0 shipment lineattr6
                                        po_lines_interface_rec.ship_attribute7,
                                        po_lines_interface_rec.ship_attribute8,
                                        lv_ship_method, --shipatt10 is ship method  ver 3.0
                                        po_lines_interface_rec.ship_attribute11,
                                        po_lines_interface_rec.ship_attribute12,
                                        po_lines_interface_rec.ship_attribute13,
                                        po_lines_interface_rec.ship_attribute14,
                                        pn_move_po_header_id);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_flag   := 'E';
                        pv_error_message   :=
                               'Error in procedure add_lines_to_po when loading lines data into po_lines_interface'
                            || SQLERRM;
                        ROLLBACK;
                END;
            END LOOP;

            --Calling import program
            apps.po_pdoi_pvt.start_process (
                p_api_version                  => 1.0,
                p_init_msg_list                => fnd_api.g_true,
                p_validation_level             => NULL,
                p_commit                       => fnd_api.g_false,
                x_return_status                => lv_return_status,
                p_gather_intf_tbl_stat         => 'N',
                p_calling_module               => NULL,
                p_selected_batch_id            => ln_batch_id,
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
                p_interface_header_id          => ln_interface_header_id,
                p_org_id                       => ln_org_id,
                p_ga_flag                      => NULL,
                p_submit_dft_flag              => 'N',
                p_role                         => 'BUYER',
                p_catalog_to_expire            => NULL,
                p_err_lines_tolerance          => NULL,
                p_clm_flag                     => NULL,
                x_processed_lines_count        => ln_processed_lines_count,
                x_rejected_lines_count         => ln_rejected_lines_count,
                x_err_tolerance_exceeded       => lv_err_tolerance_exceeded);
            pn_batch_id   := ln_batch_id;

            IF (lv_return_status = fnd_api.g_ret_sts_success)
            THEN
                BEGIN
                    SELECT segment1, phi.po_header_id
                      INTO lv_document_number, ln_document_id
                      FROM po_headers_all pha, po_headers_interface phi
                     WHERE     pha.po_header_id = phi.po_header_id
                           AND phi.interface_header_id =
                               ln_interface_header_id
                           AND phi.process_code = 'ACCEPTED';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_document_number   := NULL;
                END;

                IF lv_document_number IS NULL
                THEN
                    pv_error_flag   := 'E';
                    pv_error_message   :=
                        'Interface Errors While Creating Purchase Order';
                ELSE
                    po_approval (lv_po_num, ln_org_id, pv_error_flag,
                                 pv_error_message);
                END IF;
            ELSIF lv_return_status = (fnd_api.g_ret_sts_error)
            THEN
                pv_error_flag   := 'E';

                FOR i IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    pv_error_message   :=
                           pv_error_message
                        || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;
            ELSIF lv_return_status = fnd_api.g_ret_sts_unexp_error
            THEN
                pv_error_flag   := 'E';

                FOR i IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    pv_error_message   :=
                           pv_error_message
                        || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_flag      := 'E';
            pv_error_message   := SQLERRM;
    END add_lines_to_po;

    PROCEDURE create_po (pn_user_id IN NUMBER, pn_header_id IN NUMBER, pn_new_vendor_id IN NUMBER, pn_new_vendor_site_id IN NUMBER, pt_line_det IN xxdo.xxd_po_line_det_type, pn_new_req_header_id IN NUMBER, pn_new_inv_org_id IN NUMBER, pv_intercompany_flag IN VARCHAR2, -- Ver 3.0
                                                                                                                                                                                                                                                                             pv_action_type IN VARCHAR2, pv_new_document_num OUT VARCHAR2, pn_batch_id OUT NUMBER, pv_error_flag OUT VARCHAR2
                         , pv_error_msg OUT VARCHAR2)
    IS
        CURSOR po_headers_interface_cur IS
            SELECT pha.segment1
                       old_po_num,
                   pha.po_header_id
                       old_po_header_id,
                   pha.type_lookup_code,
                   pha.agent_id,
                   pha.creation_date,
                   pha.revision_num,
                   pha.print_count,
                   pha.closed_code,
                   pha.frozen_flag,
                   NVL (pn_new_vendor_id, pha.vendor_id)
                       vendor_id,
                   NVL (pn_new_vendor_site_id, pha.vendor_site_id)
                       vendor_site_id,
                   pha.vendor_contact_id,
                   pha.ship_to_location_id,
                   pha.bill_to_location_id,
                   pha.terms_id,
                   pha.ship_via_lookup_code,
                   pha.fob_lookup_code,
                   pha.pay_on_code,
                   pha.freight_terms_lookup_code,
                   pha.confirming_order_flag,
                   pha.currency_code,
                   pha.rate_type,
                   pha.rate_date,
                   pha.rate,
                   pha.acceptance_required_flag,
                   pha.firm_status_lookup_code,
                   pha.min_release_amount,
                   pha.pcard_id,
                   pha.blanket_total_amount,
                   pha.start_date,
                   pha.end_date,
                   pha.amount_limit,
                   pha.global_agreement_flag,
                   pha.consume_req_demand_flag,
                   pha.style_id,
                   pha.created_language,
                   pha.cpa_reference,
                   pha.attribute_category,
                   pha.attribute1,
                   pha.attribute2,
                   pha.attribute3,
                   pha.attribute4,
                   pha.attribute5,
                   pha.attribute6,
                   pha.attribute7,
                   pha.attribute8,
                   pha.attribute9,
                   pha.attribute10,
                   pha.attribute11,
                   pha.attribute12,
                   DECODE (pn_new_inv_org_id,
                           NULL, pha.org_id,
                           (SELECT operating_unit
                              FROM org_organization_definitions
                             WHERE organization_id = (pn_new_inv_org_id)))
                       org_id
              FROM po_headers_all pha
             WHERE pha.po_header_id = pn_header_id;

        CURSOR po_lines_interface_cur IS
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
                     DECODE (
                         pn_new_req_header_id,
                         NULL, p_po_line_tab.requisition_line_id,
                         (SELECT prl.requisition_line_id
                            FROM po_requisition_lines_all prl
                           WHERE     prl.requisition_header_id =
                                     pn_new_req_header_id
                                 AND TO_CHAR (pla.po_line_id) = prl.attribute1))
                         requisition_line_id,
                     pla.attribute_category,
                     pla.attribute1,
                     pla.attribute2,
                     --pla.attribute3, Commented for change 1.1
                     DECODE (pn_new_inv_org_id, NULL, pla.attribute3, NULL)
                         attribute3,                    --Added for change 1.1
                     pla.attribute4,
                     CASE
                         WHEN pla.attribute_category = 'Intercompany PO Copy'
                         THEN
                             NULL
                         ELSE
                             pla.attribute5
                     END
                         AS attribute5,
                     pla.attribute6,
                     /*NVL (pla.attribute7,
                            (SELECT vendor_site_code
                             FROM ap_supplier_sites_all
                            WHERE vendor_site_id = pn_new_vendor_site_id)
                          )
                         attribute7, -- Commented by Gowrishankar for CCR0010003 on 20-SEP-2022
                         */
                     pla.attribute7, -- Added by Gowrishankar for CCR0010003 on 20-SEP-2022
                     (SELECT vendor_site_code
                        FROM ap_supplier_sites_all
                       WHERE vendor_site_id = pn_new_vendor_site_id)
                         new_vendor_site, -- Added by Gowrishankar for CCR0010003 on 20-SEP-2022
                     pla.attribute8,
                     pla.attribute9,
                     pla.attribute10,
                     pla.attribute11,
                     pla.attribute12,
                     pla.attribute15
                         original_line_qty,                             -- 3.1
                     plla.attribute_category
                         shipment_attribute_category,
                     plla.attribute1
                         shipment_attribute1,
                     plla.attribute2
                         shipment_attribute2,
                     plla.attribute3
                         shipment_attribute3,
                     plla.attribute4
                         shipment_attribute4,
                     plla.attribute5
                         shipment_attribute5,
                     plla.attribute6
                         shipment_attribute6,
                     plla.attribute7
                         shipment_attribute7,
                     plla.attribute8
                         shipment_attribute8,
                     plla.attribute9
                         shipment_attribute9,
                     plla.attribute10
                         shipment_attribute10,
                     --plla.attribute11 shipment_attribute11, Commented for change 1.1
                     --plla.attribute12 shipment_attribute12, Commented for change 1.1
                     --plla.attribute13 shipment_attribute13, Commented for change 1.1
                     --plla.attribute14 shipment_attribute14, Commented for change 1.1
                     DECODE (pn_new_inv_org_id, NULL, plla.attribute11, NULL)
                         shipment_attribute11,          --Added for change 1.1
                     DECODE (pn_new_inv_org_id, NULL, plla.attribute12, NULL)
                         shipment_attribute12,          --Added for change 1.1
                     DECODE (pn_new_inv_org_id, NULL, plla.attribute13, NULL)
                         shipment_attribute13,          --Added for change 1.1
                     DECODE (pn_new_inv_org_id, NULL, plla.attribute14, NULL)
                         shipment_attribute14,          --Added for change 1.1
                     plla.attribute15
                         shipment_attribute15,
                     NVL (pn_new_vendor_id, pha.vendor_id)
                         vendor_id,                                 -- ver 3.0
                     NVL (pn_new_vendor_site_id, pha.vendor_site_id) -- ver 3.0
                         vendor_site_id,
                     p_po_line_tab.requisition_line_id
                         source_pr_line_id                          -- ver 3.0
                FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                     TABLE (pt_line_det) p_po_line_tab
               WHERE     pha.po_header_id = pn_header_id
                     AND pha.po_header_id = pla.po_header_id
                     AND pla.cancel_flag = 'Y'
                     AND plla.cancel_reason =
                         'Cancelled From PO Modify Tool-' || gn_request_id --Added for change 1.1
                     AND pla.po_line_id = p_po_line_tab.po_line_id
                     AND pla.po_header_id = plla.po_header_id
                     AND pla.po_line_id = plla.po_line_id
            ORDER BY pla.line_num;

        lv_ship_method              VARCHAR2 (100);                 -- ver 3.0
        ln_source_ir_line_id        NUMBER;           --added w.r.t CCR0010003

        -- ver 3.0 added cursor to get line destination country. it is required to get ship method
        -- ver 3.0 added cursor to get line destination country. it is required to get ship method
        CURSOR c_get_dest_country (p_in_req_line_id NUMBER)
        IS
            (SELECT hl.country
               FROM hr_locations hl, hr_all_organization_units haou, po_requisition_lines_all prla
              WHERE     hl.location_id = haou.location_id
                    AND prla.requisition_line_id = p_in_req_line_id
                    AND haou.organization_id =
                        NVL (
                            (SELECT porl.destination_organization_id
                               FROM po_requisition_headers_all porh, po_requisition_lines_all porl, oe_order_headers_all oha,
                                    oe_order_lines_all ola, mtl_reservations mtr
                              WHERE     oha.header_id = ola.header_id
                                    AND porh.requisition_header_id =
                                        porl.requisition_header_id
                                    AND ola.source_document_id =
                                        porh.requisition_header_id
                                    AND ola.source_document_line_id =
                                        porl.requisition_line_id
                                    AND prla.requisition_line_id =
                                        mtr.supply_source_line_id
                                    AND prla.requisition_header_id =
                                        mtr.supply_source_header_id
                                    AND mtr.supply_source_type_id = 17
                                    AND mtr.demand_source_line_id =
                                        ola.line_id),
                            prla.destination_organization_id));

        -- ver 3.0 added cursor to get line destination country. it is required to get ship method
        CURSOR c_get_intrcomp_dest_country (p_in_req_line_id     NUMBER,
                                            ln_organization_id   NUMBER)
        IS
            (SELECT hl.country
               FROM hr_locations hl, hr_all_organization_units haou
              WHERE     hl.location_id = haou.location_id
                    AND haou.organization_id = ln_organization_id);



        po_headers_interface_rec    po_headers_interface_cur%ROWTYPE;
        ln_ship_to_location_id      NUMBER;
        ln_org_id                   NUMBER;
        ln_interface_header_id      NUMBER;
        ln_batch_id                 NUMBER;
        lv_error_flag               VARCHAR2 (2);
        lv_error_msg                VARCHAR2 (4000);
        lv_return_status            VARCHAR2 (50);
        ln_processed_lines_count    NUMBER := 0;
        ln_rejected_lines_count     NUMBER := 0;
        lv_new_po_num               VARCHAR2 (50);
        lv_err_tolerance_exceeded   VARCHAR2 (100);
        lv_error_message            VARCHAR2 (4000);
        ln_po_type                  VARCHAR2 (100);                 -- ver 2.0
        l_item_description          mtl_system_items_b.description%TYPE;
        lv_action_type              VARCHAR2 (100);
        ln_move_inv_org_id          NUMBER;
        lv_po_line_vendor_site      VARCHAR2 (240);
        lv_new_po_header_id         NUMBER;
        lv_new_po_country_code      VARCHAR2 (240);
        lv_new_vendor_id            NUMBER;
        lv_new_vendor_site_id       NUMBER;
    BEGIN
        FOR po_headers_interface_rec IN po_headers_interface_cur
        LOOP
            ln_org_id          := po_headers_interface_rec.org_id;

            IF pn_new_inv_org_id IS NULL
            THEN
                ln_ship_to_location_id   :=
                    po_headers_interface_rec.ship_to_location_id;
            ELSE
                BEGIN
                    SELECT ship_to_location_id
                      INTO ln_ship_to_location_id
                      FROM hr_locations
                     WHERE inventory_organization_id = pn_new_inv_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_msg   := SUBSTR (SQLERRM, 1, 2000);
                        ln_ship_to_location_id   :=
                            po_headers_interface_rec.ship_to_location_id;
                END;
            END IF;

            -- ver begin 2.0 Added query to get PO type for the new PO from the lookup configuration
            BEGIN
                SELECT flv.attribute1
                  INTO ln_po_type
                  FROM fnd_lookup_values flv, mtl_parameters mp1, mtl_parameters mp2,
                       po_line_locations_all pla
                 WHERE     pla.po_header_id = pn_header_id
                       AND flv.description = mp1.organization_code
                       AND flv.tag = mp2.organization_code
                       AND flv.lookup_type LIKE 'XXD_PO_MODIFY_INV_ORG_LKP'
                       AND flv.language = 'US'
                       AND flv.attribute1 IS NOT NULL
                       AND flv.enabled_flag = 'Y'
                       AND ROWNUM = 1 -- all the lines have same dest org, so any non cancelled line
                       AND mp1.organization_id = pla.ship_to_organization_id --- SOURCE INV ORG
                       AND mp2.organization_id = pn_new_inv_org_id -- new DESTINATION INV ORG
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           flv.start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (
                                                           flv.end_date_active,
                                                           SYSDATE));
            EXCEPTION
                WHEN OTHERS
                THEN
                    -- No po type defined in the lookup. will go with what is available in source
                    ln_po_type   := NULL;
            END;

            -- ver End 2.0 Added query to get PO type for the new PO from the lookup configuration
            SELECT po_headers_interface_s.NEXTVAL
              INTO ln_interface_header_id
              FROM DUAL;

            SELECT xxd_po_modify_interface_s.NEXTVAL
              INTO ln_batch_id
              FROM DUAL;

            lv_new_vendor_id   := po_headers_interface_rec.vendor_id;
            lv_new_vendor_site_id   :=
                po_headers_interface_rec.vendor_site_id;

            BEGIN
                INSERT INTO po_headers_interface (action, process_code, batch_id, document_type_code, interface_header_id, created_by, org_id, document_subtype, agent_id, creation_date, revision_num, print_count, frozen_flag, vendor_id, vendor_site_id, ship_to_location_id, terms_id, freight_carrier, fob, pay_on_code, freight_terms, confirming_order_flag, currency_code, rate_type, rate_date, rate, acceptance_required_flag, firm_flag, min_release_amount, pcard_id, amount_agreed, effective_date, expiration_date, amount_limit, global_agreement_flag, consume_req_demand_flag, style_id, created_language, cpa_reference, attribute_category, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11
                                                  , attribute12, attribute14)
                         VALUES (
                                    'ORIGINAL',
                                    NULL,
                                    ln_batch_id,
                                    'STANDARD',
                                    ln_interface_header_id,
                                    fnd_profile.VALUE ('USER_ID'),
                                    po_headers_interface_rec.org_id,
                                    po_headers_interface_rec.type_lookup_code,
                                    po_headers_interface_rec.agent_id,
                                    SYSDATE,
                                    NULL,
                                    po_headers_interface_rec.print_count,
                                    po_headers_interface_rec.frozen_flag,
                                    po_headers_interface_rec.vendor_id,
                                    po_headers_interface_rec.vendor_site_id,
                                    ln_ship_to_location_id, -- ship_to_location_id
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
                                    NVL (
                                        ln_po_type,
                                        po_headers_interface_rec.attribute10), -- VER 2.0
                                    po_headers_interface_rec.attribute11,
                                    po_headers_interface_rec.attribute12,
                                    po_headers_interface_rec.old_po_num);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   := SQLERRM;
            END;

            COMMIT;
        END LOOP;

        FOR po_lines_interface_rec IN po_lines_interface_cur
        LOOP
            lv_ship_method   := NULL;

            IF pv_intercompany_flag = 'Y'            --Start  w.r.t CCR0010003
            THEN
                BEGIN
                    SELECT source_ir_line_id, action_type, move_inv_org_id
                      INTO ln_source_ir_line_id, lv_action_type, ln_move_inv_org_id
                      FROM xxdo.xxd_po_modify_details_t
                     WHERE     intercompany_po_flag = 'Y'
                           AND source_ir_line_id IS NOT NULL
                           AND source_pr_line_id =
                               po_lines_interface_rec.source_pr_line_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_source_ir_line_id   := NULL;
                END;

                IF lv_action_type = 'Move Org'
                THEN
                    FOR i
                        IN c_get_intrcomp_dest_country (
                               NVL (ln_source_ir_line_id,
                                    po_lines_interface_rec.source_pr_line_id),
                               ln_move_inv_org_id)
                    LOOP
                        -- use dest country to get ship method
                        lv_ship_method   :=
                            get_ship_method (
                                po_lines_interface_rec.vendor_id,
                                po_lines_interface_rec.vendor_site_id,
                                'STANDARD',
                                i.country,
                                po_lines_interface_rec.po_header_id     --NULL
                                                                   );

                        COMMIT;
                    END LOOP;
                ELSE              --intercompany_po but not move org operation
                    FOR i
                        IN c_get_dest_country (
                               NVL (ln_source_ir_line_id,
                                    po_lines_interface_rec.source_pr_line_id))
                    LOOP
                        -- use dest country to get ship method
                        lv_ship_method   :=
                            get_ship_method (
                                po_lines_interface_rec.vendor_id,
                                po_lines_interface_rec.vendor_site_id,
                                'STANDARD',
                                i.country,
                                po_lines_interface_rec.po_header_id     --NULL
                                                                   );
                        COMMIT;
                    END LOOP;
                END IF;
            ELSE                                       --End  w.r.t CCR0010003
                -- ver 3.0 open cursor to get Dest coutnry
                FOR i
                    IN c_get_dest_country (
                           po_lines_interface_rec.source_pr_line_id)
                LOOP
                    -- use dest country to get ship method
                    lv_ship_method   :=
                        get_ship_method (
                            po_lines_interface_rec.vendor_id,
                            po_lines_interface_rec.vendor_site_id,
                            'STANDARD',
                            i.country,
                            po_lines_interface_rec.po_header_id         --NULL
                                                               );
                END LOOP;
            END IF;                                 --End IF  w.r.t CCR0010003

            IF pv_action_type = 'Move Org'
            THEN
                lv_po_line_vendor_site   := po_lines_interface_rec.attribute7;
            ELSE
                lv_po_line_vendor_site   :=
                    po_lines_interface_rec.new_vendor_site;
            END IF;

            -- ver 3.0 get item description
            l_item_description   :=
                get_item_desc (po_lines_interface_rec.item_id);

            BEGIN
                INSERT INTO po_lines_interface (
                                action,
                                interface_line_id,
                                interface_header_id,
                                item_id,
                                item_description,               -- add ver 3.0
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
                                line_attribute15,                        --3.1
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
                                    ln_interface_header_id,
                                    po_lines_interface_rec.item_id,
                                    l_item_description,             -- ver 3.0
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
                                    ln_ship_to_location_id,
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
                                    --po_lines_interface_rec.attribute7, -- Commented by Gowrishankar for CCR0010003 on 20-SEP-2022
                                    lv_po_line_vendor_site,
                                    po_lines_interface_rec.attribute8,
                                    po_lines_interface_rec.attribute9,
                                    po_lines_interface_rec.attribute10,
                                    po_lines_interface_rec.attribute11,
                                    po_lines_interface_rec.attribute12,
                                    po_lines_interface_rec.original_line_qty, -- 3.1
                                    po_lines_interface_rec.shipment_attribute_category,
                                    po_lines_interface_rec.shipment_attribute1,
                                    po_lines_interface_rec.shipment_attribute2,
                                    po_lines_interface_rec.shipment_attribute3,
                                    po_lines_interface_rec.shipment_attribute4,
                                    po_lines_interface_rec.shipment_attribute5,
                                    DECODE (pv_intercompany_flag,
                                            'Y', 'Y',
                                            NULL), -- ver 3.0 shipment lineattr6,
                                    po_lines_interface_rec.shipment_attribute7,
                                    po_lines_interface_rec.shipment_attribute8,
                                    po_lines_interface_rec.shipment_attribute9,
                                    lv_ship_method, --shipment_attribute10 is PO Shipments DFF "Ship Method"  ver 3.0,
                                    po_lines_interface_rec.shipment_attribute11,
                                    po_lines_interface_rec.shipment_attribute12,
                                    po_lines_interface_rec.shipment_attribute13,
                                    po_lines_interface_rec.shipment_attribute14,
                                    po_lines_interface_rec.shipment_attribute15);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   := SQLERRM;
            END;
        END LOOP;

        set_purchasing_context (pn_user_id, ln_org_id, lv_error_flag,
                                lv_error_msg);

        IF lv_error_flag <> 'S'
        THEN
            pv_error_flag      := 'E';
            pv_error_msg       :=
                SUBSTR (
                       'Error while Settting purchasing context '
                    || lv_error_msg,
                    1,
                    2000);
            lv_error_message   := SQLERRM;
            RETURN;
        ELSE
            BEGIN
                apps.po_pdoi_pvt.start_process (
                    p_api_version                  => 1.0,
                    p_init_msg_list                => fnd_api.g_true,
                    p_validation_level             => NULL,
                    p_commit                       => fnd_api.g_false,
                    x_return_status                => lv_return_status,
                    p_gather_intf_tbl_stat         => 'N',
                    p_calling_module               => NULL,
                    p_selected_batch_id            => ln_batch_id,
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
                    p_interface_header_id          => ln_interface_header_id,
                    p_org_id                       => ln_org_id,
                    p_ga_flag                      => NULL,
                    p_submit_dft_flag              => 'N',
                    p_role                         => 'BUYER',
                    p_catalog_to_expire            => NULL,
                    p_err_lines_tolerance          => NULL,
                    p_clm_flag                     => NULL,
                    x_processed_lines_count        => ln_processed_lines_count,
                    x_rejected_lines_count         => ln_rejected_lines_count,
                    x_err_tolerance_exceeded       =>
                        lv_err_tolerance_exceeded);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   := SQLERRM;
            END;



            pn_batch_id   := ln_batch_id;

            IF (lv_return_status = fnd_api.g_ret_sts_success)
            THEN
                BEGIN
                    SELECT pha.segment1, pha.po_header_id
                      INTO lv_new_po_num, lv_new_po_header_id
                      FROM po_headers_all pha, po_headers_interface phi
                     WHERE     pha.po_header_id = phi.po_header_id
                           AND phi.interface_header_id =
                               ln_interface_header_id
                           AND phi.process_code = 'ACCEPTED';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_new_document_num   := NULL;
                        pv_error_flag         := 'E';
                        pv_error_msg          := 'Purchase Order not created';
                END;

                IF lv_new_po_num IS NOT NULL
                THEN
                    po_approval (lv_new_po_num, ln_org_id, lv_error_flag,
                                 lv_error_msg);
                    pv_new_document_num   := lv_new_po_num;
                END IF;
            ELSIF lv_return_status = (fnd_api.g_ret_sts_error)
            THEN
                pv_error_flag   := 'E';

                FOR i IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    pv_error_msg   :=
                        SUBSTR (
                            pv_error_msg || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F'),
                            1,
                            2000);
                END LOOP;

                lv_new_po_country_code   :=
                    xxd_po_pomodify_utils_pkg.get_po_country_code (
                        lv_new_po_header_id);
            ELSIF lv_return_status = fnd_api.g_ret_sts_unexp_error
            THEN
                pv_error_flag   := 'E';

                FOR i IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    pv_error_msg   :=
                        SUBSTR (
                            pv_error_msg || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F'),
                            1,
                            2000);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_flag   := 'E';
            pv_error_msg    := SUBSTR (SQLERRM, 1, 2000);
    END create_po;

    PROCEDURE update_drop_ship (pn_user_id            IN     NUMBER,
                                pn_req_header_id      IN     NUMBER,
                                pn_req_line_id        IN     NUMBER,
                                pn_po_header_id       IN     NUMBER,
                                pn_po_line_id         IN     NUMBER,
                                pn_line_location_id   IN     NUMBER,
                                pv_error_flag            OUT VARCHAR2,
                                pv_error_msg             OUT VARCHAR2)
    IS
        lv_dropship_msg_count       VARCHAR2 (50) := NULL;
        lv_dropship_msg_data        VARCHAR2 (4000) := NULL;
        lv_dropship_return_status   VARCHAR2 (50) := NULL;
    BEGIN
        apps.oe_drop_ship_grp.update_po_info (
            p_api_version        => 1.0,
            p_return_status      => lv_dropship_return_status,
            p_msg_count          => lv_dropship_msg_count,
            p_msg_data           => lv_dropship_msg_data,
            p_req_header_id      => pn_req_header_id,
            p_req_line_id        => pn_req_line_id,
            p_po_header_id       => pn_po_header_id,
            p_po_line_id         => pn_po_line_id,
            p_line_location_id   => pn_line_location_id);

        IF (lv_dropship_return_status <> fnd_api.g_ret_sts_success)
        THEN
            pv_error_flag   := 'E';

            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
                pv_error_msg   :=
                    SUBSTR (
                        pv_error_msg || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F'),
                        1,
                        2000);
            END LOOP;

            ROLLBACK;
        --START of Change 1.2
        ELSE
            BEGIN
                UPDATE po_line_locations_all plla
                   SET ship_to_location_id   =
                           (SELECT DISTINCT porl.deliver_to_location_id
                              FROM po_requisition_headers_all porh, po_requisition_lines_all porl
                             WHERE     1 = 1
                                   AND porh.requisition_header_id =
                                       porl.requisition_header_id
                                   AND plla.line_location_id =
                                       porl.line_location_id
                                   AND porl.line_location_id =
                                       pn_line_location_id)
                 WHERE 1 = 1 AND plla.line_location_id = pn_line_location_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_flag   := 'E';
                    pv_error_msg    :=
                        SUBSTR (
                               'Error in Updating Ship To Location ID in PO Line Locations table. Error is: '
                            || SQLERRM,
                            1,
                            2000);
            END;
        --END of Change 1.2
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_flag   := 'E';
            pv_error_msg    := SUBSTR (SQLERRM, 1, 2000);
    END update_drop_ship;

    PROCEDURE update_po_requisition_line (pn_user_id IN NUMBER, pn_requistion_header_id IN NUMBER, pn_vendor_id IN NUMBER, pn_vendor_site_id IN NUMBER, pn_org_id IN NUMBER, pt_line_det IN xxdo.xxd_po_line_det_type
                                          , pn_req_auto_approval IN VARCHAR2, pv_error_flag OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        ln_req_num           VARCHAR2 (40);
        ln_org_id            NUMBER;
        l_line_tbl           po_requisition_update_pub.req_line_tbl;
        l_dist_tbl           po_requisition_update_pub.req_dist_tbl;
        p_req_line_tbl_out   po_requisition_update_pub.req_line_tbl;
        p_req_line_err_tbl   po_requisition_update_pub.req_line_tbl;
        lv_error_flag        VARCHAR2 (2);
        lv_error_msg         VARCHAR2 (4000);
        ln_ret_status        VARCHAR2 (10);
        ln_msg_count         NUMBER;
        ln_msg_data          VARCHAR2 (4000);
        lv_out_message       VARCHAR2 (5000);
        ln_msg_index_out     NUMBER;
        lv_error_message     VARCHAR2 (4000);
        --    l_ret_status         VARCHAR2 (10);
        --  l_msg_data           VARCHAR2 (4000);
        ln_count             NUMBER := 0;
        lv_cancel_flag       VARCHAR2 (10);
        ln_location_id       NUMBER;
        ln_er_count          NUMBER := 0;

        CURSOR req_lines_det IS
            SELECT prl.*
              FROM po_requisition_lines_all prl, TABLE (pt_line_det) p_po_line_tab
             WHERE     prl.requisition_line_id =
                       p_po_line_tab.requisition_line_id
                   AND requisition_header_id = pn_requistion_header_id;
    BEGIN
        BEGIN
            SELECT segment1, org_id
              INTO ln_req_num, ln_org_id
              FROM po_requisition_headers_all
             WHERE requisition_header_id = pn_requistion_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_flag   := 'E';
                lv_error_msg    := 'Invalid requisition: ' || SQLERRM;
                pv_error_flag   := lv_error_flag;
                pv_error_msg    := SUBSTR (lv_error_msg, 1, 2000);
        END;

        IF pn_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT location_id
                  INTO ln_location_id
                  FROM hr_organization_units
                 WHERE organization_id = pn_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_msg    := SUBSTR (SQLERRM, 1, 2000);
                    pv_error_flag   := 'E';
            END;
        END IF;

        set_purchasing_context (pn_user_id, ln_org_id, lv_error_flag,
                                lv_error_msg);

        FOR req_lines_rec IN req_lines_det
        LOOP
            ln_count                                   := ln_count + 1;
            l_line_tbl (ln_count).requisition_number   := ln_req_num;
            l_line_tbl (ln_count).requisition_header_id   :=
                req_lines_rec.requisition_header_id;
            l_line_tbl (ln_count).requisition_line_num   :=
                req_lines_rec.line_num;
            l_line_tbl (ln_count).requisition_line_id   :=
                req_lines_rec.requisition_line_id;
            l_line_tbl (ln_count).org_id               :=
                req_lines_rec.org_id;

            IF pn_vendor_id IS NOT NULL
            THEN
                l_line_tbl (ln_count).vendor_id        := pn_vendor_id;
                l_line_tbl (ln_count).vendor_site_id   := pn_vendor_site_id;
            END IF;

            IF pn_org_id IS NOT NULL
            THEN
                l_line_tbl (ln_count).destination_organization_id   :=
                    pn_org_id;
                l_line_tbl (ln_count).deliver_to_location_id   :=
                    ln_location_id;
            END IF;
        END LOOP;

        po_requisition_update_pub.update_requisition_line (
            l_line_tbl,
            'T',
            p_req_line_tbl_out,
            p_req_line_err_tbl,
            'N',
            --submit_approval
            ln_ret_status,
            ln_msg_data,
            'Y');

        IF ln_ret_status = 'E' OR ln_ret_status = 'U'
        THEN
            FOR i IN 1 .. p_req_line_err_tbl.COUNT
            LOOP
                lv_error_message   := p_req_line_err_tbl (i).error_message;
            END LOOP;

            pv_error_msg    := SUBSTR (lv_error_message, 1, 2000);
            pv_error_flag   := 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg    := SUBSTR (SQLERRM, 1, 2000);
            pv_error_flag   := 'E';
    END update_po_requisition_line;

    PROCEDURE update_po_req_link (pn_line_id IN NUMBER, pv_error_flag OUT VARCHAR2, pv_error_message OUT VARCHAR2)
    IS
        lv_error_flag   VARCHAR2 (2);
        lv_error_msg    VARCHAR2 (4000);
        l_count         NUMBER;
    BEGIN
        UPDATE po_requisition_lines_all
           SET line_location_id = NULL, reqs_in_pool_flag = 'Y'
         WHERE requisition_line_id =
               (SELECT prla.requisition_line_id
                  FROM po_distributions_all pda, po_req_distributions_all prda, po_requisition_lines_all prla
                 WHERE     pda.po_line_id = pn_line_id
                       AND pda.req_distribution_id = prda.distribution_id
                       AND prla.requisition_line_id =
                           prda.requisition_line_id);

        l_count   := SQL%ROWCOUNT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_message   :=
                   'Error whilE updating the reqs_in_pool_flag / line location id: '
                || SQLERRM;
            pv_error_flag   := 'E';
    END update_po_req_link;

    PROCEDURE approve_requisition (pn_requistion_header_id IN NUMBER, pv_error_flag OUT VARCHAR2, pv_error_message OUT VARCHAR2)
    IS
        lv_error_flag             VARCHAR2 (2);
        lv_error_msg              VARCHAR2 (4000);
        p_document_id             NUMBER := 1000454;
        p_document_type           VARCHAR2 (100) := 'REQUISITION';
        p_document_subtype        VARCHAR2 (100) := 'PURCHASE';
        p_action                  VARCHAR2 (100) := 'APPROVE';
        p_fwd_to_id               NUMBER;
        p_offline_code            VARCHAR2 (100) := '';
        p_approval_path_id        NUMBER;
        p_note                    VARCHAR2 (100) := 'Auto Approved By System';
        p_new_status              VARCHAR2 (100) := 'APPROVED';
        p_notify_action           VARCHAR2 (100) := '';
        p_notify_employee         NUMBER;
        x_return_status           VARCHAR2 (100);
        lv_authorization_status   VARCHAR2 (100);
    BEGIN
        SELECT authorization_status
          INTO lv_authorization_status
          FROM po_requisition_headers_all
         WHERE requisition_header_id = pn_requistion_header_id;

        po_document_action_util.change_doc_auth_state (
            pn_requistion_header_id,
            p_document_type,
            p_document_subtype,
            p_action,
            p_fwd_to_id,
            p_offline_code,
            p_approval_path_id,
            p_note,
            p_new_status,
            p_notify_action,
            p_notify_employee,
            x_return_status);

        IF x_return_status = 'S'
        THEN
            COMMIT;
        ELSE
            pv_error_message   := 'Errorwhile approving purchase requisition';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_message   :=
                'unexpected error while calling REQUISITION Approval API ';
            pv_error_flag   := 'E';
    END approve_requisition;

    FUNCTION get_destination_org (pn_header_id IN NUMBER)
        RETURN VARCHAR2
    AS
        CURSOR get_ir_dtls_c IS
            SELECT mp.organization_code dest_org
              FROM mtl_reservations mr, oe_order_lines_all oola, po_requisition_lines_all prla,
                   mtl_parameters mp
             WHERE     mr.demand_source_line_id = oola.line_id
                   AND oola.source_document_line_id =
                       prla.requisition_line_id
                   AND prla.destination_organization_id = mp.organization_id
                   AND mr.supply_source_header_id = pn_header_id;

        CURSOR get_org_c IS
            SELECT mp.organization_code dest_org
              FROM po_line_locations_all plla, mtl_parameters mp
             WHERE     plla.ship_to_organization_id = mp.organization_id
                   AND plla.quantity - plla.quantity_received > 0
                   AND plla.po_header_id = pn_header_id;

        l_ir_dtls_rec   get_ir_dtls_c%ROWTYPE;
        l_org_rec       get_org_c%ROWTYPE;
        lc_dest_org     VARCHAR2 (100);
    BEGIN
        -- Check if IR-ISO
        OPEN get_ir_dtls_c;

        -- Consider only the first fetch. Avoiding ROWNUM and multiple values
        FETCH get_ir_dtls_c INTO l_ir_dtls_rec.dest_org;

        lc_dest_org   := l_ir_dtls_rec.dest_org;

        CLOSE get_ir_dtls_c;

        IF l_ir_dtls_rec.dest_org IS NULL
        THEN
            lc_dest_org   := NULL;

            -- Non IR-ISO
            OPEN get_org_c;

            -- Consider only the first fetch. Avoiding ROWNUM and multiple values
            FETCH get_org_c INTO l_org_rec.dest_org;

            lc_dest_org   := l_org_rec.dest_org;

            CLOSE get_org_c;
        END IF;

        RETURN lc_dest_org;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_destination_org;

    PROCEDURE create_pr_from_iso (pt_order_header_id IN xxdo.xxd_po_iso_det_type, --ISO to process
                                                                                  pt_line_det IN xxdo.xxd_po_line_det_type, pn_vendor_id IN NUMBER, pn_vedor_site_id IN NUMBER, pn_user_id IN NUMBER, pv_new_req_num OUT VARCHAR2
                                  , pn_request_id OUT NUMBER, --Request ID from REQ Import
                                                              pv_error_flag OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        ln_user_id             NUMBER;
        ln_org_id              NUMBER;
        ln_ship_from_org_id    NUMBER;
        ln_request_id          NUMBER;
        x_ret_stat             VARCHAR2 (1);
        x_error_text           VARCHAR2 (2000);
        ln_req_status          BOOLEAN;
        l_phase                VARCHAR2 (80);
        l_status               VARCHAR2 (80);
        l_dev_phase            VARCHAR2 (80);
        l_dev_status           VARCHAR2 (80);
        l_message              VARCHAR2 (255);
        ln_def_user_id         NUMBER;
        ln_employee_id         NUMBER;
        lv_brand               VARCHAR2 (20);
        ln_order_number        NUMBER;
        lv_organization_code   VARCHAR2 (5);
        ln_rec_count           NUMBER;
        ln_cnt                 NUMBER;
        ex_update              EXCEPTION;
        lv_error_flag          VARCHAR2 (100);
        lv_error_msg           VARCHAR2 (4000);
        ln_batch_id            NUMBER;
        ln_new_req_num         VARCHAR2 (100);
        ln_count               NUMBER := 0;
        ln_uniq_batch_id       NUMBER;

        CURSOR iso_det_cur IS
            SELECT *
              FROM TABLE (pt_order_header_id) p_iso_tab
             WHERE p_iso_tab.iso_header_id IS NOT NULL;
    BEGIN
        --Get employee_id for the user
        BEGIN
            SELECT employee_id
              INTO ln_employee_id
              FROM fnd_user
             WHERE user_id = pn_user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_flag   := 'E';
                pv_error_msg    :=
                    'Employee_id not found for user_id ' || pn_user_id;
                RETURN;
        END;

        FOR iso_rec IN iso_det_cur
        LOOP
            ln_count   := ln_count + 1;

            --Get SO org and organization ID

            BEGIN
                /*  ver 2.0 commented by Gaurav
                  SELECT DISTINCT ooha.org_id, oola.ship_from_org_id,
                                  ooha.attribute5, ooha.order_number,
                                  mp.organization_code, order_number
                             INTO ln_org_id, ln_ship_from_org_id,
                                  lv_brand, ln_order_number,
                                  lv_organization_code, ln_order_number
                             FROM oe_order_headers_all ooha,
                                  oe_order_lines_all oola,
                                  po_requisition_lines_all prla,
                                  mtl_parameters mp
                            WHERE ooha.header_id = oola.header_id
                              AND ooha.header_id = iso_rec.iso_header_id
                              AND oola.source_document_line_id =
                                                            prla.requisition_line_id
                              AND prla.destination_organization_id =
                                                                  mp.organization_id;

                  */
                -- added for ver 2.0
                SELECT DISTINCT ooha.org_id, oola.ship_from_org_id, ooha.attribute5,
                                ooha.order_number, order_number
                  INTO ln_org_id, ln_ship_from_org_id, lv_brand, ln_order_number,
                                ln_order_number
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola
                 WHERE     ooha.header_id = oola.header_id
                       AND ooha.header_id = iso_rec.iso_header_id
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    pv_error_flag   := 'E';
                    pv_error_msg    :=
                        'Order ' || iso_rec.iso_header_id || 'not found';
                    RETURN;
            END;

            set_purchasing_context (pn_user_id, ln_org_id, lv_error_flag,
                                    lv_error_msg);
            --Run Autocreate request to push ISO lines to the requisitions interface
            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'BOM',
                    program       => 'CTOACREQ',
                    argument1     => ln_order_number,
                    argument2     => '',
                    argument3     => '',
                    argument4     => ln_ship_from_org_id,
                    argument5     => ln_ship_from_org_id,
                    argument6     => '');
            COMMIT;
            ln_req_status   :=
                apps.fnd_concurrent.wait_for_request (
                    request_id   => ln_request_id,
                    INTERVAL     => 10,
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
                    pv_error_flag   := 'W';
                ELSE
                    pv_error_msg   := apps.fnd_api.g_ret_sts_error;
                END IF;

                pv_error_msg    :=
                    NVL (
                        l_message,
                           'The ctoareq request ended with a status of '
                        || NVL (l_dev_status, 'ERROR'));
                pv_error_flag   := x_ret_stat;
                pv_error_msg    := SUBSTR (x_error_text, 1, 2000);
            ELSE
                pv_error_flag   := 'S';
            END IF;

            --Find data about created requisition records so we can import only those specific records to a requisition
            BEGIN
                SELECT DISTINCT prla.batch_id
                  INTO ln_batch_id
                  FROM apps.po_requisitions_interface_all prla, oe_order_lines_all oola, oe_order_headers_all ooha
                 WHERE     prla.interface_source_line_id = oola.line_id
                       AND oola.header_id = ooha.header_id
                       AND prla.interface_source_code = 'CTO'       -- ver 2.0
                       AND ooha.order_number = ln_order_number;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_batch_id     := '';
                    pv_error_flag   := 'E';
            END;

            IF ln_batch_id IS NOT NULL
            THEN
                IF ln_count = 1
                THEN
                    ln_uniq_batch_id   := ln_batch_id;
                END IF;

                --Updating REQ interface records with new vendor_id,vendor_site_id
                BEGIN
                    UPDATE apps.po_requisitions_interface_all pri
                       SET pri.suggested_vendor_id       =
                               NVL (pn_vendor_id, suggested_vendor_id),
                           pri.suggested_vendor_site_id   =
                               NVL (pn_vedor_site_id,
                                    suggested_vendor_site_id),
                           pri.preparer_id               = ln_employee_id,
                           pri.deliver_to_requestor_id   = ln_employee_id,
                           pri.autosource_flag           = 'P',
                           pri.batch_id                  = ln_uniq_batch_id,
                           (pri.line_attribute1, pri.line_attribute2)   =
                               (SELECT p_po_line_tab.po_line_id, p_po_line_tab.requisition_line_id
                                  FROM TABLE (pt_line_det) p_po_line_tab, po_line_locations_all pla, oe_order_lines_all ola
                                 WHERE     p_po_line_tab.po_line_id =
                                           pla.po_line_id
                                       AND ola.attribute16 =
                                           TO_CHAR (pla.line_location_id)
                                       AND pri.interface_source_line_id =
                                           ola.line_id)
                     WHERE     pri.interface_source_line_id IN
                                   (SELECT oola.line_id
                                      FROM oe_order_lines_all oola, oe_order_headers_all ooha
                                     WHERE     oola.header_id =
                                               ooha.header_id
                                           AND ooha.order_number =
                                               ln_order_number)
                           AND pri.interface_source_code = 'CTO';  -- ver 2.0;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_msg   :=
                            SUBSTR (
                                   'Error updating requisition interface table '
                                || SQLERRM,
                                2000);
                END;
            END IF;
        END LOOP;

        run_req_import (pv_import_source   => 'CTO', -- VER 2.0  IT WAS getting passed as null causing other interface lines also getting pickedup
                        pn_batch_id        => TO_CHAR (ln_uniq_batch_id),
                        pn_org_id          => ln_org_id,
                        pn_inv_org_id      => ln_ship_from_org_id,
                        pn_user_id         => pn_user_id,
                        pv_status          => lv_error_flag,
                        pv_msg             => lv_error_msg,
                        pn_request_id      => ln_request_id);

        IF lv_error_flag = 'S' OR lv_error_flag = 'W'
        THEN
            NULL;
        ELSE
            pv_error_msg   :=
                'No requisition records were created. Check for records in po_interface_errors';
        END IF;

        IF ln_request_id IS NOT NULL
        THEN
            BEGIN
                  SELECT COUNT (*), prha.segment1
                    INTO ln_cnt, ln_new_req_num
                    FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla
                   WHERE     prha.requisition_header_id =
                             prla.requisition_header_id
                         AND prha.request_id = ln_request_id
                         AND prha.interface_source_code = 'CTO'     -- ver 2.0
                GROUP BY prha.segment1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_new_req_num   := NULL;
                WHEN OTHERS
                THEN
                    ln_new_req_num   := NULL;
            END;

            pv_new_req_num   := ln_new_req_num;
            pn_request_id    := ln_request_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_flag   := 'U';
            pv_error_msg    :=
                SUBSTR ('Unexpected error ' || SQLERRM, 1, 2000);
    END create_pr_from_iso;

    PROCEDURE link_iso_and_po (pn_order_header_id   IN     NUMBER,
                               pv_error_msg            OUT VARCHAR2)
    IS
        ln_count   NUMBER;
    BEGIN
        BEGIN
            UPDATE oe_order_lines_all oola
               SET attribute16   =
                       (SELECT DISTINCT TO_CHAR (pda.line_location_id)
                          FROM apps.po_distributions_all pda, apps.mtl_reservations mr
                         WHERE     mr.demand_source_line_id = oola.line_id
                               AND mr.organization_id = oola.ship_from_org_id
                               AND mr.supply_source_type_id = 1
                               AND pda.line_location_id =
                                   mr.supply_source_line_id)
             WHERE     line_id IN
                           (SELECT demand_source_line_id
                              FROM apps.mtl_reservations
                             WHERE     organization_id IN
                                           (SELECT TO_NUMBER (lookup_code)
                                              FROM fnd_lookup_values
                                             WHERE     lookup_type =
                                                       'XXD_PO_B2B_ORGANIZATIONS'
                                                   AND enabled_flag = 'Y'
                                                   AND LANGUAGE = 'US')
                                   AND supply_source_type_id = 1)
                   AND (   attribute16 IS NULL
                        OR attribute16 <>
                           (SELECT DISTINCT TO_CHAR (pda.line_location_id)
                              FROM apps.po_distributions_all pda, apps.mtl_reservations mr
                             WHERE     mr.demand_source_line_id =
                                       oola.line_id
                                   AND mr.organization_id =
                                       oola.ship_from_org_id
                                   AND mr.supply_source_type_id = 1
                                   AND pda.line_location_id =
                                       mr.supply_source_line_id))
                   AND header_id = pn_order_header_id;

            ln_count   := SQL%ROWCOUNT;

            IF ln_count = 0
            THEN
                pv_error_msg   :=
                    SUBSTR (
                           'Error occured while establishing link between ISO and PO '
                        || SQLERRM,
                        1,
                        2000);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_msg   :=
                    SUBSTR (
                           'Error occured while establishing link between ISO and PO '
                        || SQLERRM,
                        1,
                        2000);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   :=
                SUBSTR ('Unexpected error ' || SQLERRM, 1, 2000);
    END link_iso_and_po;

    --Start changes for CCR0010003
    FUNCTION get_po_country_code (pn_po_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_organization_id   NUMBER := NULL;
        ln_location_id       NUMBER := NULL;
        lv_country           VARCHAR2 (20) := NULL;
        lv_po_type           VARCHAR2 (20) := NULL;
    BEGIN
        lv_country   := NULL;

        BEGIN
            SELECT pha.attribute10                                  -- PO Type
              INTO lv_po_type
              FROM po_headers_all pha
             WHERE pha.po_header_id = pn_po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_po_type   := 'STANDARD';
        END;

        BEGIN
            --ICO and Direct Ship
            SELECT DISTINCT prla.destination_organization_id
              INTO ln_organization_id
              FROM po_requisition_lines_all prla, oe_order_lines_all oola, po_line_locations_all plla,
                   po_headers_all pha
             WHERE     1 = 1
                   AND pha.po_header_id = pn_po_header_id
                   AND plla.po_header_id = pha.po_header_id
                   AND oola.attribute16 = TO_CHAR (plla.line_location_id)
                   AND prla.requisition_line_id =
                       oola.source_document_line_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    --JP TQ
                    SELECT DISTINCT plla_jp.ship_to_organization_id
                      INTO ln_organization_id
                      FROM po_line_locations_all plla_jp, po_lines_all pla_jp, oe_order_lines_all oola,
                           oe_drop_ship_sources dss
                     WHERE     1 = 1
                           AND plla_jp.po_line_id = pla_jp.po_line_id
                           AND pla_jp.attribute5 = TO_CHAR (oola.line_id)
                           AND oola.line_id = dss.line_id
                           AND dss.po_header_id = pn_po_header_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        --Distributor and Direct Procurement (For this POs, ln_transit_days = 0)
                        BEGIN
                            SELECT DISTINCT plla.ship_to_location_id --plla.ship_to_organization_id,
                              INTO ln_location_id
                              FROM po_line_locations_all plla
                             WHERE     1 = 1
                                   AND plla.ship_to_location_id IS NOT NULL -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                                   AND ROWNUM = 1 -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                                   AND plla.po_header_id = pn_po_header_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'get_po_country_code - ln_location_id: '
                                    || SQLCODE
                                    || '-'
                                    || SQLERRM); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                        END;
                END;
        END;

        --Get country
        IF ln_location_id IS NOT NULL
        THEN
            BEGIN
                SELECT country_code
                  INTO lv_country
                  FROM xxdo.xxdoint_po_locations_v
                 WHERE location_id = ln_location_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'get_po_country_code - lv_country: '
                        || SQLCODE
                        || '-'
                        || SQLERRM); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
            END;
        ELSE
            BEGIN
                SELECT hl.country
                  INTO lv_country
                  FROM hr_locations hl, -- po_hr_locations hl,
                                        hr_all_organization_units hou
                 WHERE     hl.location_id = hou.location_id
                       AND hou.organization_id = ln_organization_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'get_po_country_code - lv_country: '
                        || SQLCODE
                        || '-'
                        || SQLERRM); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
            END;
        END IF;

        RETURN lv_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --End changes for CCR0010003

    --Start changes for CCR0010003
    FUNCTION get_pol_transit_days (pv_new_po_num         IN VARCHAR2,
                                   pv_action             IN VARCHAR2,
                                   pn_vendor_id          IN NUMBER,
                                   pn_vendor_site_id     IN NUMBER,
                                   pv_vendor_site_code   IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_po_header_id            NUMBER;
        lv_po_country              VARCHAR2 (10);
        lv_vendor_name             VARCHAR2 (240);
        lv_vendor_site_code        VARCHAR2 (50);
        lv_po_vendor_site_code     VARCHAR2 (50) := NULL;
        ln_transit_days            NUMBER;
        lv_preferred_ship_method   VARCHAR2 (50) := NULL;
    BEGIN
        --Get New PO Header ID
        BEGIN
            SELECT po_header_id
              INTO ln_po_header_id
              FROM po_headers_all
             WHERE segment1 = pv_new_po_num;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_po_header_id   := NULL;
        END;

        --Get PO destination region
        lv_po_country   := get_po_country_code (ln_po_header_id);

        --Get PO Vendor Site Code
        IF pn_vendor_site_id IS NOT NULL
        THEN
            BEGIN
                SELECT apss.vendor_site_code, aps.vendor_name
                  INTO lv_vendor_site_code, lv_vendor_name
                  FROM ap_suppliers aps, ap_supplier_sites_all apss
                 WHERE     aps.vendor_id = apss.vendor_id
                       AND apss.vendor_site_id = pn_vendor_site_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vendor_site_code   := NULL;
                    lv_vendor_name        := NULL;
            END;
        ELSE
            lv_vendor_site_code   := NULL;
        END IF;

        --Lookup transit days from lookup table
        BEGIN
            SELECT DECODE (UPPER (NVL (flv.attribute8, 'OCEAN')),  'AIR', NVL (flv.attribute5, 0),  'OCEAN', NVL (flv.attribute6, 0),  'TRUCK', NVL (flv.attribute7, 0),  -1), attribute8
              INTO ln_transit_days, lv_preferred_ship_method
              FROM fnd_lookup_values flv
             WHERE     flv.language = 'US'
                   AND flv.lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                   AND flv.attribute1 = pn_vendor_id
                   AND flv.attribute2 =
                       DECODE (pv_action,
                               'Change Supplier', lv_vendor_site_code,
                               TRIM (pv_vendor_site_code)) --TRIM(pv_vendor_site_code) --lv_vendor_site_code --
                   AND flv.attribute3 = lv_po_country
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN flv.start_date_active
                                   AND NVL (flv.end_date_active, SYSDATE + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_transit_days            := -1;
                lv_preferred_ship_method   := NULL;
        END;

        IF NVL (ln_transit_days, 0) > 0
        THEN
            RETURN ln_transit_days;
        ELSIF NVL (ln_transit_days, 0) = 0
        THEN
            RETURN 0;
        ELSE
            RETURN -1;
        END IF;

        RETURN ln_transit_days;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_pol_transit_days;

    --End changes for CCR0010003

    --Start changes for CCR0010003
    PROCEDURE update_calc_need_by_date (pn_user_id IN NUMBER, pn_po_number IN VARCHAR2, pn_transit_days IN NUMBER, pn_vendor_id IN NUMBER DEFAULT NULL, pn_vendor_site_id IN NUMBER DEFAULT NULL, pn_source_po_header_id IN NUMBER DEFAULT NULL, pn_source_pr_header_id IN NUMBER DEFAULT NULL, pv_action IN VARCHAR2, pv_error_flag OUT VARCHAR2
                                        , pv_error_msg OUT VARCHAR2)
    IS
        CURSOR cur_po_headers IS
              SELECT poh.segment1
                         po_num,
                     poh.po_header_id,
                     poh.revision_num,
                     poh.vendor_id,
                     poh.vendor_site_id,
                     poh.attribute10
                         po_type,
                     pla.po_line_id,
                     pla.line_num,
                     TRIM (pla.attribute7)
                         po_line_vendor_site,
                     plla.line_location_id,
                     plla.shipment_num,
                     plla.promised_date,
                     plla.need_by_date
                         po_need_by_date,
                     fnd_date.canonical_to_date (plla.attribute4)
                         req_ex_factory_date,          --Added for Version 3.5
                     fnd_date.canonical_to_date (plla.attribute5)
                         ex_factory_date,
                     plla.attribute10
                         ship_method,
                     xxd_po_pomodify_utils_pkg.get_po_country_code (
                         poh.po_header_id)
                         po_country_code,
                     poh.org_id,
                     poh.agent_id,
                     xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                         poh.segment1,
                         pv_action,
                         poh.vendor_id,
                         poh.vendor_site_id,
                         TRIM (pla.attribute7))
                         transit_days
                FROM po_headers_all poh, po_lines_all pla, po_line_locations_all plla,
                     po_distributions_all pda, po_req_distributions_all prda, po_requisition_lines_all prla
               WHERE     poh.segment1 = pn_po_number
                     AND pla.po_header_id = poh.po_header_id
                     AND plla.po_header_id = poh.po_header_id
                     AND plla.po_line_id = pla.po_line_id
                     AND plla.line_location_id = pda.line_location_id
                     AND pda.po_header_id = poh.po_header_id
                     AND prda.distribution_id = pda.req_distribution_id
                     AND prla.requisition_line_id = prda.requisition_line_id
                     AND prla.requisition_header_id =
                         NVL (pn_source_pr_header_id,
                              prla.requisition_header_id)
            ORDER BY poh.segment1, pla.line_num;

        lv_error_flag          VARCHAR2 (3) := NULL;
        lv_error_msg           VARCHAR2 (3000) := NULL;
        ln_org_id              NUMBER;
        ln_revision_num        NUMBER := 0;
        l_api_errors           po_api_errors_rec_type;
        l_result               NUMBER;
        ln_po_header_id        NUMBER;
        ln_calc_transit_days   NUMBER;
        ld_ex_factory_date     DATE;
        ld_promised_date       DATE;
        lb_run_po_update       BOOLEAN := FALSE;
        lv_ship_method         VARCHAR2 (240) := NULL;
        lv_po_type             VARCHAR2 (240) := NULL;
        ex_update              EXCEPTION;
    BEGIN
        BEGIN
            SELECT po_header_id, NVL (revision_num, 0), org_id
              INTO ln_po_header_id, ln_revision_num, ln_org_id
              FROM po_headers_all
             WHERE segment1 = pn_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_flag   := 'E';
                pv_error_msg    :=
                    SUBSTR ('Error While Getting PO Details ' || SQLERRM,
                            1,
                            2000);
                RETURN;
        END;

        --Setting Context
        set_purchasing_context (pn_user_id, ln_org_id, lv_error_flag,
                                lv_error_msg);

        IF lv_error_flag <> 'S'
        THEN
            pv_error_flag   := 'E';
            pv_error_msg    :=
                SUBSTR (
                       'Error while Settting purchasing context '
                    || lv_error_msg,
                    1,
                    2000);
            RETURN;
        ELSE
            FOR rec IN cur_po_headers
            LOOP
                BEGIN
                    SELECT NVL (revision_num, 0)
                      INTO ln_revision_num
                      FROM po_headers_all
                     WHERE segment1 = pn_po_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_revision_num   := 0;
                END;

                --If supplier\site changes and XFDate is passed, then calculate promise date
                --Promise date to recalculate based on the Transit Time in In-Transit Matrix
                --IF rec.ex_factory_date IS NOT NULL AND NVL(rec.transit_days, 0) > 0 --NVL(pn_transit_days, 0) > 0 --Commented for Version 3.5
                IF     NVL (rec.ex_factory_date, rec.req_ex_factory_date)
                           IS NOT NULL
                   AND NVL (rec.transit_days, 0) > 0   --Added for Version 3.5
                THEN
                    --ld_promised_date :=
                    -- rec.ex_factory_date + NVL(rec.transit_days, pn_transit_days); --pn_transit_days;         --Commented for Version 3.5
                    ld_promised_date   :=
                          NVL (rec.ex_factory_date, rec.req_ex_factory_date)
                        + NVL (rec.transit_days, pn_transit_days); --Added for Version 3.5
                    lb_run_po_update   := TRUE; --flag to run PO update process
                --ELSIF rec.ex_factory_date IS NOT NULL                            --Commented for Version 3.5
                ELSIF NVL (rec.ex_factory_date, rec.req_ex_factory_date)
                          IS NOT NULL                  --Added for Version 3.5
                THEN
                    --IF TRUNC(nvl(rec.promised_date, SYSDATE)) = TRUNC(rec.ex_factory_date)                            --Commented for Version 3.5
                    IF TRUNC (NVL (rec.promised_date, SYSDATE)) =
                       TRUNC (
                           NVL (rec.ex_factory_date, rec.req_ex_factory_date)) --Added for Version 3.5
                    THEN
                        ld_promised_date   := NULL;
                        lb_run_po_update   := FALSE;
                    ELSE
                        --ld_promised_date := rec.ex_factory_date;                            --Commented for Version 3.5
                        ld_promised_date   :=
                            NVL (rec.ex_factory_date,
                                 rec.req_ex_factory_date); --Added for Version 3.5
                        lb_run_po_update   := TRUE; --flag to run PO update process
                    END IF;
                ELSE
                    ld_promised_date   := NULL;
                    lb_run_po_update   := FALSE;
                END IF;

                l_api_errors   := NULL;
                l_api_errors   :=
                    po_api_errors_rec_type (NULL, NULL, NULL,
                                            NULL, NULL, NULL,
                                            NULL, NULL);

                IF lb_run_po_update
                THEN
                    --Update po details with calculated promised date
                    l_result   :=
                        po_change_api1_s.update_po (
                            x_po_number             => rec.po_num,
                            x_release_number        => NULL,
                            x_revision_number       => ln_revision_num,
                            x_line_number           => rec.line_num,
                            x_shipment_number       => rec.shipment_num,
                            new_quantity            => NULL,
                            new_price               => NULL,
                            new_promised_date       =>
                                NVL (ld_promised_date, rec.po_need_by_date),
                            new_need_by_date        => rec.po_need_by_date,
                            launch_approvals_flag   => 'N',                 --
                            update_source           => NULL,
                            version                 => '1.0',
                            x_override_date         => NULL,
                            x_api_errors            => l_api_errors,
                            p_buyer_name            => NULL,
                            p_secondary_quantity    => NULL,
                            p_preferred_grade       => NULL,
                            p_org_id                => rec.org_id);

                    IF l_result <> 1                                 -- O OR 1
                    THEN
                        FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                        LOOP
                            pv_error_msg   :=
                                SUBSTR (
                                    pv_error_msg || l_api_errors.MESSAGE_TEXT (i),
                                    1,
                                    2000);
                        END LOOP;

                        pv_error_flag   := 'E';
                    END IF;
                END IF;

                BEGIN
                    lv_ship_method   :=
                        get_ship_method (rec.vendor_id,
                                         rec.vendor_site_id, --added as part of CCR0010003
                                         rec.po_type,
                                         rec.po_country_code,
                                         rec.po_header_id               --NULL
                                                         );

                    UPDATE po_line_locations_all plla
                       SET plla.attribute10   = lv_ship_method
                     WHERE plla.po_line_id = rec.po_line_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'update_calc_need_by_date - Exception: '
                            || SQLCODE
                            || ' - '
                            || SQLERRM);
                END;
            END LOOP;
        END IF;                                      --IF lv_error_flag <> 'S'
    EXCEPTION
        WHEN ex_update
        THEN
            pv_error_flag   := 'E';
            pv_error_msg    :=
                'Error : Promise_Date calc failure- Transit time not defined for change Supplier\Site';
        WHEN OTHERS
        THEN
            pv_error_msg   :=
                SUBSTR ('Unexpected error ' || SQLERRM, 1, 2000);
    END update_calc_need_by_date;

    --End changes for CCR0010003

    /* Added below procedure for change 1.1*/
    PROCEDURE update_po_need_by_date (pn_user_id IN NUMBER, pn_po_number IN VARCHAR2, pv_error_flag OUT VARCHAR2
                                      , pv_error_msg OUT VARCHAR2)
    IS
        CURSOR cur_po_headers IS
              SELECT poh.segment1 po_num, poh.po_header_id, prha.segment1 requisition_num,
                     prla.line_num requisition_line_num, plla.shipment_num, prla.need_by_date req_nbd,
                     plla.need_by_date po_need_by_date, poh.org_id, pla.line_num,
                     poh.agent_id
                FROM po_headers_all poh, po_lines_all pla, po_line_locations_all plla,
                     po_distributions_all pda, po_requisition_headers_all prha, po_requisition_lines_all prla,
                     po_req_distributions_all prda
               WHERE     poh.segment1 = pn_po_number
                     AND pla.po_header_id = poh.po_header_id
                     AND plla.po_header_id = poh.po_header_id
                     AND plla.po_line_id = pla.po_line_id
                     AND plla.line_location_id = pda.line_location_id
                     AND pda.po_header_id = poh.po_header_id
                     AND pda.req_distribution_id = prda.distribution_id
                     AND prda.requisition_line_id = prla.requisition_line_id
                     AND prla.requisition_header_id =
                         prha.requisition_header_id
                     AND prla.need_by_date != plla.need_by_date
            ORDER BY poh.segment1, pla.line_num;

        lv_error_flag     VARCHAR2 (3);
        lv_error_msg      VARCHAR2 (3000);
        ln_org_id         NUMBER;
        ln_revision_num   NUMBER;
        l_api_errors      po_api_errors_rec_type;
        l_result          NUMBER;
    BEGIN
        BEGIN
            SELECT NVL (revision_num, 0), org_id
              INTO ln_revision_num, ln_org_id
              FROM po_headers_all
             WHERE segment1 = pn_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_flag   := 'E';
                pv_error_msg    :=
                    SUBSTR ('Error While Getting PO Details ' || SQLERRM,
                            1,
                            2000);
                RETURN;
        END;

        set_purchasing_context (pn_user_id, ln_org_id, lv_error_flag,
                                lv_error_msg);

        IF lv_error_flag <> 'S'
        THEN
            pv_error_flag   := 'E';
            pv_error_msg    :=
                SUBSTR (
                       'Error while Settting purchasing context '
                    || lv_error_msg,
                    1,
                    2000);
            RETURN;
        ELSE
            FOR rec IN cur_po_headers
            LOOP
                l_result   :=
                    po_change_api1_s.update_po (
                        x_po_number             => rec.po_num,
                        x_release_number        => NULL,
                        x_revision_number       => ln_revision_num,
                        x_line_number           => rec.line_num,
                        x_shipment_number       => rec.shipment_num,
                        new_quantity            => NULL,
                        new_price               => NULL,
                        new_promised_date       => rec.req_nbd,
                        new_need_by_date        => rec.req_nbd,
                        launch_approvals_flag   => 'N',                     --
                        update_source           => NULL,
                        VERSION                 => '1.0',
                        x_override_date         => NULL,
                        x_api_errors            => l_api_errors,
                        p_buyer_name            => NULL,
                        p_secondary_quantity    => NULL,
                        p_preferred_grade       => NULL,
                        p_org_id                => rec.org_id);

                IF l_result <> 1
                THEN
                    FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                    LOOP
                        pv_error_msg   :=
                            SUBSTR (
                                pv_error_msg || l_api_errors.MESSAGE_TEXT (i),
                                1,
                                2000);
                    END LOOP;

                    pv_error_flag   := 'Y';
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   :=
                SUBSTR ('Unexpected error ' || SQLERRM, 1, 2000);
    END update_po_need_by_date;
END XXD_PO_POMODIFY_UTILS_PKG;
/
