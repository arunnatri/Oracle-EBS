--
-- XXDO_SHIPPING_LABELS  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SHIPPING_LABELS"
AS
    /********************************************************************************************
         Modification History:
        Version   SCN#        By                       Date             Comments

          1.0              BT-Technology Team          22-Nov-2014        Updated for BT
          1.1              Krishna Lavu               15-OCT-2017         CCR0006631 Delivery Download to Pyramid

     ******************************************************************************************/

    lg_package_name   CONSTANT VARCHAR2 (200) := 'APPS.XXDO_SHIPPING_LABELS';
    lg_enable_debug            NUMBER
        := NVL (
               apps.do_get_profile_value (
                   'DO_DEBUG_XXDO_SHIPPING_LABELS_INTERFACE'),
               1);



    /*private*/
    PROCEDURE msg (p_msg VARCHAR2, p_level NUMBER:= 1)
    IS
        l_pn   CONSTANT VARCHAR2 (200) := lg_package_name || '.msg';
    BEGIN
        IF lg_enable_debug = 1 OR g_debug_pick = 1 OR p_level < 1
        THEN
            do_debug_tools.msg (p_msg, p_level);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                do_debug_tools.msg (
                    SUBSTR ('Debug Error: ' || SQLERRM, 1, 200),
                    0);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
    END;

    PROCEDURE debug_on
    IS
        l_pn   CONSTANT VARCHAR2 (200) := lg_package_name || '.debug_on';
    BEGIN
        msg ('+' || l_pn);
        --  do_debug_tools.enable_dbms(1000000);
        do_debug_tools.enable_conc_log (1000000);
        do_debug_tools.enable_table (10000000);
        msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('-' || l_pn);
    END;

    PROCEDURE output_msg (MESSAGE VARCHAR2, p_email_results NUMBER)
    IS
        l_pn   CONSTANT VARCHAR2 (200) := lg_package_name || '.output_msg';
        x               NUMBER;
    BEGIN
        msg (MESSAGE, -1);
        FND_FILE.PUT_LINE (FND_FILE.output, MESSAGE);

        IF p_email_results = 1
        THEN
            do_mail_utils.send_mail_line (MESSAGE, x);
        END IF;
    END;

    PROCEDURE create_maifest_label (p_delivery_id   IN     VARCHAR2,
                                    --p_lang in varchar2,
                                    p_printer              VARCHAR2,
                                    x_ret_Stat         OUT VARCHAR2,
                                    x_message          OUT VARCHAR2,
                                    P_DEBUG_LEVEL          NUMBER := 0)
    IS
        v_request_id          NUMBER;
        w_set_print_options   BOOLEAN;
        l_user_id             NUMBER;
        l_application_id      NUMBER;
        l_responsibility_id   NUMBER;
        l_org_id              NUMBER;
        l_organization_id     NUMBER;
        l_short_prog          VARCHAR2 (50);
        l_descrip             VARCHAR2 (50);
        phase                 VARCHAR2 (240);
        status                VARCHAR2 (1);
        dev_phase             VARCHAR2 (240);
        dev_status            VARCHAR2 (1);
        MESSAGE               VARCHAR2 (240);
        req_status            BOOLEAN;
        xml_layout            BOOLEAN;
        --Start Changes by Bt Technology team on 24-Nov-2014
        l_inv_user_id         NUMBER;
        l_resp_id             NUMBER;
        l_appl_id             NUMBER;
    --End changes by BT Technology Team on 24-Nov-2014
    BEGIN
        --Start Changes by Bt Technology team on 24-Nov-2014
        SELECT user_id
          INTO l_inv_user_id
          FROM fnd_user
         WHERE user_name = 'WMS_BATCH';

        SELECT responsibility_id
          INTO l_resp_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        SELECT responsibility_id, application_id
          INTO l_resp_id, l_appl_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        --End changes by BT Technology Team on 24-Nov-2014
        --apps.fnd_profile.put('MFG_ORGANIZATION_ID', 213);
        --apps.do_apps_initialize(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);                     --Commented by BT Technology Team on 24-Nov-2014
        apps.do_apps_initialize (user_id        => l_inv_user_id,
                                 resp_id        => l_resp_id,
                                 resp_appl_id   => l_appl_id); --Added by BT Technology Team on 24-Nov-2014

        IF NVL (P_DEBUG_LEVEL, 0) > 0
        THEN
            DEBUG_ON;
            do_debug_tools.enable_conc_log (p_debug_level);
            DO_DEBUG_TOOLS.ENABLE_TABLE (P_DEBUG_LEVEL);
            G_DEBUG_PICK   := 1;
        END IF;


        BEGIN
            SELECT MAX (org_id), MAX (organization_id)
              INTO l_org_id, l_organization_id
              FROM apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
             --, apps.oe_order_headers_all ooha
             WHERE     delivery_id IS NOT NULL
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND delivery_id = p_delivery_id;
        -- and ooha.header_id = wdd.source_header_id

        END;

        l_short_prog   := 'XXDOPACK';
        l_descrip      := 'Packing Slip Report - Deckers';
        --end if;


        w_set_print_options   :=
            apps.fnd_request.set_print_options (printer          => p_printer,
                                                style            => 'A4',
                                                copies           => 1,
                                                save_output      => TRUE,
                                                print_together   => 'N');

        IF w_set_print_options
        THEN
            msg ('Printer set');
        ELSE
            msg ('Printer not set' || p_printer || ' , ' || SQLERRM);
        END IF;

        xml_layout     :=
            apps.FND_REQUEST.ADD_LAYOUT ('CUSTOM', l_short_prog, 'EN',
                                         '', 'PDF');

        IF xml_layout
        THEN
            msg ('Layout Set set');
        ELSE
            msg ('Layout not set' || SQLERRM);
        END IF;

        v_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'CUSTOM',
                program       => l_short_prog,
                description   => l_descrip,
                start_time    => NULL,
                sub_request   => FALSE,
                argument1     => l_organization_id,
                argument2     => p_delivery_id,
                argument3     => '',
                argument4     => l_org_id);


        IF v_request_id > 0
        THEN
            COMMIT;
            msg ('Successfully submitted ' || v_request_id);
            x_ret_Stat   := 'S';
        ELSE
            msg (
                   'Not Submitted'
                || ' , '
                || l_short_prog
                || ' , '
                || l_descrip
                || ' , '
                || l_organization_id
                || ' , '
                || p_delivery_id
                || ' , '
                || l_org_id
                || ',  '
                || SQLERRM);
            x_ret_Stat   := 'F';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('others has been raised ' || SQLERRM, -1);
            x_ret_Stat   := 'F';
            x_message    := ' error out' || SQLERRM;
    END;

    PROCEDURE create_ws_manifest_label (p_delivery_id   IN     VARCHAR2,
                                        p_printer              VARCHAR2,
                                        x_ret_Stat         OUT VARCHAR2,
                                        x_message          OUT VARCHAR2,
                                        P_DEBUG_LEVEL          NUMBER := 0)
    IS
        v_request_id          NUMBER;
        w_set_print_options   BOOLEAN;
        l_user_id             NUMBER;
        l_application_id      NUMBER;
        l_responsibility_id   NUMBER;
        l_short_prog          VARCHAR2 (50);
        l_descrip             VARCHAR2 (50);
        phase                 VARCHAR2 (240);
        status                VARCHAR2 (1);
        dev_phase             VARCHAR2 (240);
        dev_status            VARCHAR2 (1);
        MESSAGE               VARCHAR2 (240);
        req_status            BOOLEAN;
        xml_layout            BOOLEAN;
        --Start Changes by Bt Technology team on 24-Nov-2014
        l_inv_user_id         NUMBER;
        l_resp_id             NUMBER;
        l_appl_id             NUMBER;
    --End changes by BT Technology Team on 24-Nov-2014
    BEGIN
        --Start Changes by Bt Technology team on 24-Nov-2014
        SELECT user_id
          INTO l_inv_user_id
          FROM fnd_user
         WHERE user_name = 'WMS_BATCH';

        SELECT responsibility_id
          INTO l_resp_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        SELECT responsibility_id, application_id
          INTO l_resp_id, l_appl_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        --End changes by BT Technology Team on 24-Nov-2014
        --apps.fnd_profile.put('MFG_ORGANIZATION_ID', 213);
        --apps.do_apps_initialize(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);                     --Commented by BT Technology Team on 24-Nov-2014
        apps.do_apps_initialize (user_id        => l_inv_user_id,
                                 resp_id        => l_resp_id,
                                 resp_appl_id   => l_appl_id); --Added by BT Technology Team on 24-Nov-2014

        IF NVL (P_DEBUG_LEVEL, 0) > 0
        THEN
            DEBUG_ON;
            do_debug_tools.enable_conc_log (p_debug_level);
            DO_DEBUG_TOOLS.ENABLE_TABLE (P_DEBUG_LEVEL);
            G_DEBUG_PICK   := 1;
        END IF;


        l_short_prog   := 'XXDOOM007';
        l_descrip      := 'Direct to Consumer Packing Slip - Deckers';
        --end if;


        w_set_print_options   :=
            apps.fnd_request.set_print_options (printer          => p_printer,
                                                style            => 'A4',
                                                copies           => 1,
                                                save_output      => TRUE,
                                                print_together   => 'N');

        IF w_set_print_options
        THEN
            msg ('Printer set');
        ELSE
            msg ('Printer not set' || p_printer || ' , ' || SQLERRM);
        END IF;

        xml_layout     :=
            apps.FND_REQUEST.ADD_LAYOUT ('XXDO', l_short_prog, 'EN',
                                         '', 'PDF');

        IF xml_layout
        THEN
            msg ('Layout Set set');
        ELSE
            msg ('Layout not set' || SQLERRM);
        END IF;

        v_request_id   :=
            apps.fnd_request.submit_request (application   => 'XXDO',
                                             program       => l_short_prog,
                                             description   => l_descrip,
                                             start_time    => NULL,
                                             sub_request   => FALSE,
                                             argument1     => p_delivery_id);


        IF v_request_id > 0
        THEN
            COMMIT;
            msg ('Successfully submitted ' || v_request_id);
            x_ret_Stat   := 'S';
        ELSE
            msg (
                   'Not Submitted'
                || ' , '
                || l_short_prog
                || ' , '
                || l_descrip
                || ' , '
                || p_delivery_id
                || ',  '
                || SQLERRM);
            x_ret_Stat   := 'F';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('others has been raised ' || SQLERRM, -1);
            x_ret_Stat   := 'F';
            x_message    := ' error out' || SQLERRM;
    END;

    PROCEDURE flagstaff_invoice (p_delivery_id   IN     NUMBER,
                                 -- p_lang in varchar2,
                                 p_printer              VARCHAR2,
                                 x_ret_Stat         OUT VARCHAR2,
                                 x_message          OUT VARCHAR2,
                                 P_DEBUG_LEVEL          NUMBER := 0)
    IS
        v_request_id          NUMBER;
        w_set_print_options   BOOLEAN;
        l_user_id             NUMBER;
        l_application_id      NUMBER;
        l_responsibility_id   NUMBER;
        l_order_number        NUMBER;
        l_organization_id     NUMBER;
        l_short_prog          VARCHAR2 (50);
        l_descrip             VARCHAR2 (50);
        phase                 VARCHAR2 (240);
        status                VARCHAR2 (1);
        dev_phase             VARCHAR2 (240);
        dev_status            VARCHAR2 (1);
        MESSAGE               VARCHAR2 (240);
        req_status            BOOLEAN;
        xml_layout            BOOLEAN;
        --Start Changes by Bt Technology team on 24-Nov-2014
        l_inv_user_id         NUMBER;
        l_resp_id             NUMBER;
        l_appl_id             NUMBER;
    --End changes by BT Technology Team on 24-Nov-2014
    BEGIN
        --Start Changes by Bt Technology team on 24-Nov-2014
        SELECT user_id
          INTO l_inv_user_id
          FROM fnd_user
         WHERE user_name = 'WMS_BATCH';

        SELECT responsibility_id
          INTO l_resp_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        SELECT responsibility_id, application_id
          INTO l_resp_id, l_appl_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        --End changes by BT Technology Team on 24-Nov-2014
        --apps.fnd_profile.put('MFG_ORGANIZATION_ID', 213);
        --apps.do_apps_initialize(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);                     --Commented by BT Technology Team on 24-Nov-2014
        apps.do_apps_initialize (user_id        => l_inv_user_id,
                                 resp_id        => l_resp_id,
                                 resp_appl_id   => l_appl_id); --Added by BT Technology Team on 24-Nov-2014

        IF NVL (P_DEBUG_LEVEL, 0) > 0
        THEN
            DEBUG_ON;
            do_debug_tools.enable_conc_log (p_debug_level);
            DO_DEBUG_TOOLS.ENABLE_TABLE (P_DEBUG_LEVEL);
            G_DEBUG_PICK   := 1;
        END IF;

        --begin
        --select order_number into l_order_number from apps.oe_order_headers_all
        --where header_id  =  p_header_id;
        ---end;

        l_short_prog   := 'XXDOOM003';
        l_descrip      := 'US Ecommerce Invoice - Deckers';
        --end if;

        --Landscape,LANDSCAPE
        --PDF Publisher
        w_set_print_options   :=
            apps.fnd_request.set_print_options (printer          => p_printer,
                                                style            => 'LANDSCAPE',
                                                copies           => 1,
                                                save_output      => TRUE,
                                                print_together   => 'N');

        IF w_set_print_options
        THEN
            msg ('Printer set');
        ELSE
            msg ('Printer not set' || p_printer || ' , ' || SQLERRM);
        END IF;

        xml_layout     :=
            apps.FND_REQUEST.ADD_LAYOUT ('XXDO', 'XXDOINV_TEMP', 'EN',
                                         'US', 'PDF');

        IF xml_layout
        THEN
            msg ('Layout Set set');
        ELSE
            msg ('Layout not set' || SQLERRM);
        END IF;

        v_request_id   :=
            apps.fnd_request.submit_request (application   => 'XXDO',
                                             program       => l_short_prog,
                                             description   => l_descrip,
                                             start_time    => NULL,
                                             sub_request   => FALSE,
                                             argument1     => p_delivery_id);


        IF v_request_id > 0
        THEN
            COMMIT;
            msg ('Successfully submitted ' || v_request_id);
            x_ret_Stat   := 'S';
        ELSE
            msg (
                   'Not Submitted'
                || ' , '
                || l_short_prog
                || ' , '
                || l_descrip
                || ' , '
                || p_delivery_id
                || SQLERRM);
            x_ret_Stat   := 'F';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('others has been raised ' || SQLERRM, -1);
            x_ret_Stat   := 'F';
            x_message    := ' error out' || SQLERRM;
    END;

    PROCEDURE webservice_print_manifest (p_delivery IN NUMBER, p_printer IN VARCHAR2, x_ret_Stat OUT VARCHAR2
                                         , x_message OUT VARCHAR2)
    AS
        http_req        UTL_HTTP.req;
        http_resp       UTL_HTTP.resp;
        request_env     VARCHAR2 (1000);
        response_env    VARCHAR2 (1000);
        v_url           VARCHAR2 (256);
        l_delivery_id   NUMBER;
        l_printer       VARCHAR2 (25);
        --Start Changes by Bt Technology team on 24-Nov-2014
        l_inv_user_id   NUMBER;
        l_resp_id       NUMBER;
        l_appl_id       NUMBER;
    --End changes by BT Technology Team on 24-Nov-2014
    BEGIN
        --Start Changes by Bt Technology team on 24-Nov-2014
        SELECT user_id
          INTO l_inv_user_id
          FROM fnd_user
         WHERE user_name = 'WMS_BATCH';

        SELECT responsibility_id
          INTO l_resp_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        SELECT responsibility_id, application_id
          INTO l_resp_id, l_appl_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        --End changes by BT Technology Team on 24-Nov-2014
        --apps.do_apps_initialize(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);                     --Commented by BT Technology Team on 24-Nov-2014
        apps.do_apps_initialize (user_id        => l_inv_user_id,
                                 resp_id        => l_resp_id,
                                 resp_appl_id   => l_appl_id); --Added by BT Technology Team on 24-Nov-2014


        msg ('p_delivery: ' || p_delivery);
        msg ('p_printer code: ' || p_printer);
        --debug
        --v_url := 'http://doapps-beta.corporate.deckers.com/Deck.Web.DC.Printing/ManifestPrinting.aspx?DELIVERY_ID='||p_delivery || '='||p_printer||'';
        --prod
        v_url       :=
               'http://dodcweb.corporate.deckers.com/Printing/ManifestPrinting.aspx?DELIVERY_ID='
            || p_delivery
            || '='
            || p_printer
            || '';
        --dbms_output.put_line('Length of Request:' || length(request_env));
        --dbms_output.put_line ('Request: ' || request_env);
        http_req    := UTL_HTTP.begin_request (url => v_url, method => 'GET');
        --dbms_output.put_line('');
        msg ('v_url: ' || v_url);
        http_resp   := UTL_HTTP.get_response (http_req);
        --dbms_output.put_line('Response Received');
        --dbms_output.put_line('');
        msg ('Status code: ' || http_resp.status_code);
        msg ('Reason phrase: ' || http_resp.reason_phrase);

        IF http_resp.status_code = 200
        THEN
            x_ret_Stat   := g_ret_success;
            x_message    := NULL;
            COMMIT;
        ELSE
            x_message    := http_resp.reason_phrase;
            x_ret_Stat   := g_ret_unexp_error;
            msg (x_message);
        END IF;

        msg ('x_ret_Stat: ' || x_ret_Stat);

        BEGIN
            UTL_HTTP.read_text (http_resp, response_env);
        EXCEPTION
            WHEN UTL_HTTP.end_of_body
            THEN
                NULL;
        END;

        --dbms_output.put_line('Response: ');
        --dbms_output.put_line(response_env);
        UTL_HTTP.end_response (http_resp);
    END;


    PROCEDURE wcs_print_manifest (p_lpn IN VARCHAR2, p_printer_task IN VARCHAR2:= NULL, p_printer_name IN VARCHAR2:= NULL
                                  , x_ret_Stat OUT VARCHAR2, x_message OUT VARCHAR2, P_DEBUG_LEVEL NUMBER:= 0)
    IS
        l_pn                VARCHAR2 (2000) := lg_package_name || '.wcs_print_manifest';
        l_count             NUMBER;
        l_header_id         NUMBER;
        l_order_source_id   VARCHAR2 (20);
        l_printer           VARCHAR2 (20);
        l_delivery          NUMBER;
    BEGIN
        x_ret_stat   := g_ret_unexp_error;
        x_message    := 'No additional information provided';
        msg ('+' || l_pn);
        msg ('wcs_print_manifest called');
        msg ('Parameters:');
        msg (CHR (9) || 'p_lpn:           ' || p_lpn);
        msg (CHR (9) || 'p_printer_task:          ' || p_printer_task);
        msg (CHR (9) || 'p_printer_name:          ' || p_printer_name);


        IF NVL (P_DEBUG_LEVEL, 0) > 0
        THEN
            DEBUG_ON;
            do_debug_tools.enable_conc_log (p_debug_level);
            DO_DEBUG_TOOLS.ENABLE_TABLE (P_DEBUG_LEVEL);
            G_DEBUG_PICK   := 1;
        END IF;


        BEGIN
            SELECT MAX (order_source_id), MAX (header_Id), MAX (delivery_id)
              INTO l_order_source_id, l_header_id, l_delivery
              FROM apps.wsh_delivery_details wdd_cont, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd,
                   apps.oe_order_headers_all ooha
             WHERE     wdd_cont.source_code = 'WSH'
                   AND wdd_cont.delivery_detail_id =
                       wda.parent_delivery_detail_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND ooha.header_id = wdd.source_header_id
                   AND wdd.source_code = 'OE'
                   AND wdd_cont.container_name = p_lpn;

            IF l_header_id IS NULL OR l_delivery IS NULL
            THEN
                x_message    := 'Error locating lpn: (' || p_lpn || ')';
                msg (x_message);
                x_ret_Stat   := g_ret_unexp_error;
                msg ('-' || l_pn);
                RETURN;
            END IF;
        END;

        msg (CHR (9) || 'p_delivery:           ' || l_delivery);

        IF l_order_source_id IS NOT NULL
        THEN
            SELECT COUNT (*)
              INTO l_count
              FROM apps.oe_lookups
             WHERE     lookup_type = 'XXDO_ECOMM_ORDER_SOURCE'
                   AND lookup_code = TO_CHAR (l_order_source_id);
        END IF;

        IF p_printer_task IS NOT NULL
        THEN
            BEGIN
                SELECT meaning
                  INTO l_printer
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'XXDO_WCS_PRINTERS'
                       AND enabled_flag = 'Y'
                       AND lookup_code = p_printer_task
                       AND NVL (end_date_active, SYSDATE + 1) > SYSDATE;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_message    :=
                        'Error locating printer: (' || p_printer_task || ')';
                    msg (x_message);
                    x_ret_Stat   := g_ret_unexp_error;
                    msg ('-' || l_pn);
                    RETURN;
            END;

            msg (CHR (9) || 'p_printer_task:          ' || l_printer);

            IF l_count = 1
            THEN
                flagstaff_invoice (p_delivery_id => l_delivery, p_printer => l_printer, x_ret_Stat => x_ret_Stat
                                   , x_message => x_message);

                IF NVL (x_ret_Stat, g_Ret_error) != g_ret_success
                THEN
                    x_message    := 'flagstaff_invoice failed: ' || x_message;
                    x_ret_Stat   := g_ret_error;
                    msg (x_message);
                    msg ('-' || l_pn);
                END IF;
            ELSE
                create_manifest_US (p_delivery_id => l_delivery, p_printer => l_printer, x_ret_Stat => x_ret_Stat
                                    , x_message => x_message);

                IF NVL (x_ret_Stat, g_Ret_error) != g_ret_success
                THEN
                    x_message    := 'manifest_invoice failed: ' || x_message;
                    x_ret_Stat   := g_ret_error;
                    msg (x_message);
                    msg ('-' || l_pn);
                END IF;
            END IF;

            msg ('x_ret_Stat: ' || x_ret_Stat);
        ELSIF p_printer_name IS NOT NULL
        THEN
            create_manifest_US (p_delivery_id => l_delivery, p_printer => p_printer_name, x_ret_Stat => x_ret_Stat
                                , x_message => x_message);

            IF NVL (x_ret_Stat, g_Ret_error) != g_ret_success
            THEN
                x_message    := 'manifest_invoice failed: ' || x_message;
                x_ret_Stat   := g_ret_error;
                msg (x_message);
                msg ('-' || l_pn);
            END IF;
        ELSE
            x_message    := 'No printer task or printer assigned' || x_message;
            x_ret_Stat   := g_ret_error;
            msg (x_message);
            msg ('-' || l_pn);
        END IF;

        msg ('x_ret_Stat: ' || x_ret_Stat);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_message    := x_message || ' Unhandled exception: ' || SQLERRM;
            msg (x_message);
            x_ret_Stat   := g_ret_unexp_error;
            msg ('-' || l_pn);
            RETURN;
    END;

    PROCEDURE create_manifest_US (p_delivery_id   IN     VARCHAR2,
                                  p_printer              VARCHAR2,
                                  x_ret_Stat         OUT VARCHAR2,
                                  x_message          OUT VARCHAR2,
                                  P_DEBUG_LEVEL          NUMBER := 0)
    IS
        v_request_id          NUMBER;
        w_set_print_options   BOOLEAN;
        l_user_id             NUMBER;
        l_application_id      NUMBER;
        l_responsibility_id   NUMBER;
        l_short_prog          VARCHAR2 (50);
        l_descrip             VARCHAR2 (50);
        phase                 VARCHAR2 (240);
        status                VARCHAR2 (1);
        dev_phase             VARCHAR2 (240);
        dev_status            VARCHAR2 (1);
        MESSAGE               VARCHAR2 (240);
        req_status            BOOLEAN;
        xml_layout            BOOLEAN;
        --Start Changes by Bt Technology team on 24-Nov-2014
        l_inv_user_id         NUMBER;
        l_resp_id             NUMBER;
        l_appl_id             NUMBER;
    --End changes by BT Technology Team on 24-Nov-2014
    BEGIN
        --Start Changes by Bt Technology team on 24-Nov-2014
        SELECT user_id
          INTO l_inv_user_id
          FROM fnd_user
         WHERE user_name = 'WMS_BATCH';

        SELECT responsibility_id
          INTO l_resp_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        SELECT responsibility_id, application_id
          INTO l_resp_id, l_appl_id
          FROM fnd_responsibility_tl
         WHERE     responsibility_name = 'Deckers WMS Inv Control Manager'
               AND language = 'US';

        --End changes by BT Technology Team on 24-Nov-2014
        --apps.fnd_profile.put('MFG_ORGANIZATION_ID', 213);
        --apps.do_apps_initialize(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);                     --Commented by BT Technology Team on 24-Nov-2014
        apps.do_apps_initialize (user_id        => l_inv_user_id,
                                 resp_id        => l_resp_id,
                                 resp_appl_id   => l_appl_id); --Added by BT Technology Team on 24-Nov-2014

        IF NVL (P_DEBUG_LEVEL, 0) > 0
        THEN
            DEBUG_ON;
            do_debug_tools.enable_conc_log (p_debug_level);
            DO_DEBUG_TOOLS.ENABLE_TABLE (P_DEBUG_LEVEL);
            G_DEBUG_PICK   := 1;
        END IF;

        l_short_prog   := 'XXDO_PACKING_SLIP';
        l_descrip      := 'Packing Slip for - Sanuk';

        w_set_print_options   :=
            apps.fnd_request.set_print_options (printer          => p_printer,
                                                style            => 'A4',
                                                copies           => 1,
                                                save_output      => TRUE,
                                                print_together   => 'N');

        IF w_set_print_options
        THEN
            msg ('Printer set manifest US');
        ELSE
            msg (
                   'Printer not set manifest US'
                || p_printer
                || ' , '
                || SQLERRM);
        END IF;

        xml_layout     :=
            apps.FND_REQUEST.ADD_LAYOUT ('XXDO', l_short_prog, 'EN',
                                         '', 'PDF');

        IF xml_layout
        THEN
            msg ('Layout Set set');
        ELSE
            msg ('Layout not set' || SQLERRM);
        END IF;

        v_request_id   :=
            apps.fnd_request.submit_request (application   => 'XXDO',
                                             program       => l_short_prog,
                                             description   => l_descrip,
                                             start_time    => NULL,
                                             sub_request   => FALSE,
                                             argument1     => p_delivery_id);


        IF v_request_id > 0
        THEN
            COMMIT;
            msg ('Successfully submitted manifest US' || v_request_id);
            x_ret_Stat   := 'S';
        ELSE
            msg (
                   'Not Submitted manifest US'
                || ' , '
                || l_short_prog
                || ' , '
                || l_descrip
                || ' , '
                || p_delivery_id
                || ',  '
                || SQLERRM);
            x_ret_Stat   := 'F';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('others has been raised ' || SQLERRM, -1);
            x_ret_Stat   := 'F';
            x_message    := ' error out' || SQLERRM;
    END;


    --Added by Sunera
    PROCEDURE get_packing_slip_details_all (p_delivery_id IN NUMBER, x_packing_slip_type OUT VARCHAR2, x_print_packslip OUT VARCHAR2, x_language_type OUT VARCHAR2, x_ret_Stat OUT VARCHAR2, x_message OUT VARCHAR2
                                            , P_DEBUG_LEVEL NUMBER:= 0)
    IS
        l_packing_slip_type   VARCHAR2 (100);
        l_language_type       VARCHAR2 (100);
        l_cust_id             NUMBER;
        l_org_id              NUMBER;
        --start changes by BT Technology Tem on 26-Nov-2014
        l_ecom_org1           NUMBER;
        l_ecom_org2           NUMBER;
        -- Added for CCR0006631
        lv_brand              VARCHAR2 (100);
        lv_sales_channel      VARCHAR2 (100);
        ln_count              NUMBER;
    --End changes by BT Technology Team on 26-Nov-2014
    --PROCEDURE BEGIN
    BEGIN
        --GET LANGUAGE TYPE
        BEGIN
            SELECT DISTINCT mp.attribute1 country_code
              INTO l_language_type
              FROM apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd, apps.mtl_parameters mp
             WHERE     wdd.delivery_detail_id = wda.delivery_detail_id
                   AND delivery_id = p_delivery_id
                   AND mp.organization_id = wdd.organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_language_type   := NULL;
                msg ('others has been raised ' || SQLERRM, -1);
                x_ret_Stat        := 'F';
                x_message         := ' error out' || SQLERRM;
        END;


        --Check DTC
        l_cust_id             := NULL;

        BEGIN
              SELECT wdd.customer_id
                INTO l_cust_id
                FROM apps.fnd_lookup_values flv, apps.ra_customers rc, apps.wsh_delivery_assignments wda,
                     apps.wsh_delivery_details wdd
               WHERE     flv.lookup_type = 'XXDO_DTC_PACKSLIP_DATA'
                     AND flv.LANGUAGE = 'US'
                     AND flv.enabled_flag = 'Y'
                     AND rc.customer_number = flv.lookup_code
                     AND wda.delivery_id = p_delivery_id
                     AND wda.delivery_detail_id = wdd.delivery_detail_id
                     AND wdd.customer_id = rc.customer_id
            GROUP BY wdd.customer_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_cust_id    := NULL;
                msg ('others has been raised ' || SQLERRM, -1);
                x_ret_Stat   := 'F';
                x_message    := ' error out' || SQLERRM;
        END;

        IF l_cust_id IS NOT NULL
        THEN
            l_packing_slip_type   := 'DTC';
        --IF NOT DTC, CHECK for ECOMM
        ELSE
            BEGIN
                --Start changes by BT Technology Team on 26-Nov-2014
                SELECT organization_id
                  INTO l_ecom_org1
                  FROM hr_operating_units
                 WHERE name IN ('Deckers eCommerce OU');

                SELECT organization_id
                  INTO l_ecom_org2
                  FROM hr_operating_units
                 WHERE name IN ('Deckers Canada eCommerce OU');

                  --End changes by BT Technology Team on 26-Nov-2014
                  --Check EComm
                  SELECT MAX (org_id)
                    INTO l_org_id
                    FROM apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
                   WHERE     wda.delivery_id = p_delivery_id
                         AND wda.delivery_detail_id = wdd.delivery_detail_id
                         AND source_code = 'OE'
                GROUP BY org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_org_id     := NULL;
                    msg ('others has been raised ' || SQLERRM, -1);
                    x_ret_Stat   := 'F';
                    x_message    := ' error out' || SQLERRM;
            END;

            --IF l_org_id IN (472, 593)--ECOMM                     --Commented by BT Technology Team on 26-Nov-2014
            IF l_org_id IN (l_ecom_org1, l_ecom_org2) --Added by BT Technology Team on 26-Nov-2014
            THEN
                l_packing_slip_type   := 'ECOMM';
            ELSE
                l_packing_slip_type   := 'WHOLESALE';
            END IF;
        END IF;

        /* Start CCR0006631 */
        BEGIN
            SELECT DISTINCT DECODE (SUBSTR (otta.attribute12, 1, 9), 'UGG-HEART', 'IHUGG', ooha.attribute5) brand, ooha.sales_channel_code
              INTO lv_brand, lv_sales_channel
              FROM apps.oe_order_headers_all ooha, apps.oe_transaction_types_all otta, apps.wsh_delivery_assignments wda,
                   apps.wsh_delivery_details wdd
             WHERE     wda.delivery_id = p_delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_header_id = ooha.header_id
                   AND ooha.order_type_id = otta.transaction_type_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand           := NULL;
                lv_sales_channel   := NULL;
        END;

        IF l_packing_slip_type = 'DTC'
        THEN
            lv_sales_channel   := 'DTC';
        END IF;

        SELECT COUNT (1)
          INTO ln_count
          FROM apps.fnd_lookup_values flv
         WHERE     lookup_type = 'XXDO_WMS_PACKSLIP_RESTRICT'
               AND language = 'US'
               AND lookup_code = lv_brand
               AND description = lv_sales_channel
               AND TRUNC (SYSDATE) BETWEEN TRUNC (start_date_active)
                                       AND TRUNC (
                                               NVL (end_date_active, SYSDATE));

        IF ln_count > 0
        THEN
            x_print_packslip   := 'N';
        ELSE
            x_print_packslip   := 'Y';
        END IF;

        /* End CCR0006631 */

        x_packing_slip_type   := l_packing_slip_type;
        x_language_type       := l_language_type;
        x_ret_Stat            := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('others has been raised ' || SQLERRM, -1);
            x_ret_Stat   := 'F';
            x_message    := ' error out' || SQLERRM;
    END;


    FUNCTION get_vas_code (p_header_id        IN NUMBER,
                           p_line_id          IN NUMBER,
                           p_gift_wrap_flag      VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_msg       VARCHAR2 (2000);
        v_vas_code   VARCHAR2 (2000);
    BEGIN
        -- Check whether there is any gift message
        SELECT shipping_instructions
          INTO lv_msg                                           --gift message
          FROM apps.oe_order_lines_all
         WHERE header_id = p_header_id AND line_id = p_line_id;

        IF lv_msg IS NOT NULL
        THEN
            --logic to retrieve VAS code + Gift message
            BEGIN
                SELECT (NVL (flv.tag, '109') || DECODE (oola.shipping_instructions, NULL, '', '-M')) GM
                  INTO v_vas_code
                  FROM apps.oe_order_lines_all oola, apps.oe_price_adjustments opa, apps.qp_list_lines qll,
                       apps.fnd_lookup_values_vl flv
                 WHERE     oola.line_id = p_line_id
                       AND opa.header_id = oola.header_id
                       AND opa.line_id = oola.line_id
                       AND opa.list_line_type_code = 'FREIGHT_CHARGE'
                       AND qll.list_line_id = opa.list_line_id
                       AND qll.charge_type_code = 'GIFTWRAP'
                       AND flv.lookup_type = 'XXDOWM_GW_OPTION_VAS_XREF'
                       AND lookup_code = UPPER (opa.attribute2);
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_vas_code   := NULL;
            END;

            IF v_vas_code IS NULL AND p_gift_wrap_flag = 'Y'
            THEN
                v_vas_code   := '109';
            /* IF :CF_GIFT_MSG2 IS NOT NULL
                         THEN
                             v_vas_code:=v_vas_code||'-'||:CF_GIFT_MSG2 (--This is the gift message);
             END IF;*/
            END IF;
        ELSE
            v_vas_code   := NULL;
        END IF;

        RETURN v_vas_code;
    END;

    FUNCTION print_pack_slip (p_delivery_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_packing_slip_type   VARCHAR2 (100);
        l_cust_id             NUMBER;
        lv_brand              VARCHAR2 (100);
        lv_sales_channel      VARCHAR2 (100);
        ln_count              NUMBER;
        lv_print_packslip     VARCHAR2 (1);
    BEGIN
        --Check DTC
        l_cust_id   := NULL;

        BEGIN
              SELECT wdd.customer_id
                INTO l_cust_id
                FROM apps.fnd_lookup_values flv, apps.ra_customers rc, apps.wsh_delivery_assignments wda,
                     apps.wsh_delivery_details wdd
               WHERE     flv.lookup_type = 'XXDO_DTC_PACKSLIP_DATA'
                     AND flv.LANGUAGE = 'US'
                     AND flv.enabled_flag = 'Y'
                     AND rc.customer_number = flv.lookup_code
                     AND wda.delivery_id = p_delivery_id
                     AND wda.delivery_detail_id = wdd.delivery_detail_id
                     AND wdd.customer_id = rc.customer_id
            GROUP BY wdd.customer_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_cust_id   := NULL;
        END;

        IF l_cust_id IS NOT NULL
        THEN
            l_packing_slip_type   := 'DTC';
        END IF;

        BEGIN
            SELECT DISTINCT DECODE (SUBSTR (otta.attribute12, 1, 9), 'UGG-HEART', 'IHUGG', ooha.attribute5) brand, ooha.sales_channel_code
              INTO lv_brand, lv_sales_channel
              FROM apps.oe_order_headers_all ooha, apps.oe_transaction_types_all otta, apps.wsh_delivery_assignments wda,
                   apps.wsh_delivery_details wdd
             WHERE     wda.delivery_id = p_delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_header_id = ooha.header_id
                   AND ooha.order_type_id = otta.transaction_type_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand           := NULL;
                lv_sales_channel   := NULL;
        END;

        IF l_packing_slip_type = 'DTC'
        THEN
            lv_sales_channel   := 'DTC';
        END IF;

        SELECT COUNT (1)
          INTO ln_count
          FROM apps.fnd_lookup_values flv
         WHERE     lookup_type = 'XXDO_WMS_PACKSLIP_RESTRICT'
               AND language = 'US'
               AND lookup_code = lv_brand
               AND description = lv_sales_channel
               AND TRUNC (SYSDATE) BETWEEN TRUNC (start_date_active)
                                       AND TRUNC (
                                               NVL (end_date_active, SYSDATE));

        IF ln_count > 0
        THEN
            lv_print_packslip   := 'N';
        ELSE
            lv_print_packslip   := 'Y';
        END IF;

        /* End CCR0006631 */

        RETURN lv_print_packslip;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_print_packslip   := 'Y';
            RETURN lv_print_packslip;
    END;
END XXDO_SHIPPING_LABELS;
/
