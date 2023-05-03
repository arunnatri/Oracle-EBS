--
-- XXD_WMS_ASN_INTR_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_ASN_INTR_CONV_PKG"
AS
    /******************************************************************************************
     * Package      : XXD_ASN_INTRANSIT_CONV
     * Design       : This package is used for receiving an ASN then scheduling/shipping the corresponding IRISO
     * Notes        :
     * Modification :
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 03-SEP-2019  1.0        Greg Jensen           Initial Version
    ******************************************************************************************/

    gn_resp_id                              NUMBER := apps.fnd_global.resp_id;
    gn_resp_appl_id                         NUMBER := apps.fnd_global.resp_appl_id;

    gv_mo_profile_option_name_po   CONSTANT VARCHAR2 (240)
                                                := 'MO: Security Profile' ;
    gv_mo_profile_option_name_so   CONSTANT VARCHAR2 (240)
                                                := 'MO: Operating Unit' ;
    gv_responsibility_name_po      CONSTANT VARCHAR2 (240)
                                                := 'Deckers Purchasing User' ;
    gv_responsibility_name_so      CONSTANT VARCHAR2 (240)
        := 'Deckers Order Management Super User' ;
    gv_US_OU                       CONSTANT VARCHAR2 (50) := 'Deckers US OU';

    gn_org_id                               NUMBER := fnd_global.org_id;
    gn_user_id                              NUMBER := fnd_global.user_id;
    gn_login_id                             NUMBER := fnd_global.login_id;
    gn_request_id                           NUMBER
                                                := fnd_global.conc_request_id;
    gn_employee_id                          NUMBER := fnd_global.employee_id;

    /**********************
    Logging
    **********************/
    PROCEDURE insert_message (pv_message_type   IN VARCHAR2,
                              pv_message        IN VARCHAR2)
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_message);
        END IF;

        IF UPPER (pv_message_type) IN ('OUTPUT', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, pv_message);
        END IF;

        IF UPPER (pv_message_type) = 'DATABASE'
        THEN
            DBMS_OUTPUT.put_line (pv_message);
        END IF;
    END insert_message;

    /*******************
    Responsibility initialization
    ********************/

    PROCEDURE set_purchasing_context (pn_user_id NUMBER, pn_org_id NUMBER, pv_error_stat OUT VARCHAR2
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
                       gv_mo_profile_option_name_po   --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_id NOT IN (51395, 51398)      --TEMP
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name_po || '%' --'Deckers Purchasing User%'
                   AND fpov.profile_option_value IN
                           (SELECT security_profile_id
                              FROM apps.per_security_organizations
                             WHERE organization_id = pn_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE ex_get_resp_id;
        END;

        --do intialize and purchssing setup
        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);

        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', pn_org_id);
        FND_REQUEST.SET_ORG_ID (pn_org_id);

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_get_resp_id
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error getting Purchasing context resp_id : ' || SQLERRM;
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
    END;

    --Wrapper around executing con current request with wait for completion
    PROCEDURE exec_conc_request (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_request_id OUT NUMBER, pv_application IN VARCHAR2 DEFAULT NULL, pv_program IN VARCHAR2 DEFAULT NULL, pv_argument1 IN VARCHAR2 DEFAULT CHR (0), pv_argument2 IN VARCHAR2 DEFAULT CHR (0), pv_argument3 IN VARCHAR2 DEFAULT CHR (0), pv_argument4 IN VARCHAR2 DEFAULT CHR (0), pv_argument5 IN VARCHAR2 DEFAULT CHR (0), pv_argument6 IN VARCHAR2 DEFAULT CHR (0), pv_argument7 IN VARCHAR2 DEFAULT CHR (0), pv_argument8 IN VARCHAR2 DEFAULT CHR (0), pv_argument9 IN VARCHAR2 DEFAULT CHR (0), pv_argument10 IN VARCHAR2 DEFAULT CHR (0), pv_argument11 IN VARCHAR2 DEFAULT CHR (0), pv_argument12 IN VARCHAR2 DEFAULT CHR (0), pv_argument13 IN VARCHAR2 DEFAULT CHR (0), pv_argument14 IN VARCHAR2 DEFAULT CHR (0), pv_argument15 IN VARCHAR2 DEFAULT CHR (0), pv_argument16 IN VARCHAR2 DEFAULT CHR (0), pv_argument17 IN VARCHAR2 DEFAULT CHR (0), pv_argument18 IN VARCHAR2 DEFAULT CHR (0), pv_argument19 IN VARCHAR2 DEFAULT CHR (0), pv_argument20 IN VARCHAR2 DEFAULT CHR (0), pv_argument21 IN VARCHAR2 DEFAULT CHR (0), pv_argument22 IN VARCHAR2 DEFAULT CHR (0), pv_argument23 IN VARCHAR2 DEFAULT CHR (0), pv_argument24 IN VARCHAR2 DEFAULT CHR (0), pv_argument25 IN VARCHAR2 DEFAULT CHR (0), pv_argument26 IN VARCHAR2 DEFAULT CHR (0), pv_argument27 IN VARCHAR2 DEFAULT CHR (0), pv_argument28 IN VARCHAR2 DEFAULT CHR (0), pv_argument29 IN VARCHAR2 DEFAULT CHR (0), pv_argument30 IN VARCHAR2 DEFAULT CHR (0), pv_argument31 IN VARCHAR2 DEFAULT CHR (0), pv_argument32 IN VARCHAR2 DEFAULT CHR (0), pv_argument33 IN VARCHAR2 DEFAULT CHR (0), pv_argument34 IN VARCHAR2 DEFAULT CHR (0), pv_argument35 IN VARCHAR2 DEFAULT CHR (0), pv_argument36 IN VARCHAR2 DEFAULT CHR (0), pv_argument37 IN VARCHAR2 DEFAULT CHR (0), pv_argument38 IN VARCHAR2 DEFAULT CHR (0), pv_wait_for_request IN VARCHAR2 DEFAULT 'Y', pn_interval IN NUMBER DEFAULT 60
                                 , pn_max_wait IN NUMBER DEFAULT 0)
    IS
        l_req_status   BOOLEAN;
        l_request_id   NUMBER;

        l_phase        VARCHAR2 (120 BYTE);
        l_status       VARCHAR2 (120 BYTE);
        l_dev_phase    VARCHAR2 (120 BYTE);
        l_dev_status   VARCHAR2 (120 BYTE);
        l_message      VARCHAR2 (2000 BYTE);
    BEGIN
        l_request_id   :=
            apps.fnd_request.submit_request (application   => pv_application,
                                             program       => pv_program,
                                             start_time    => SYSDATE,
                                             sub_request   => FALSE,
                                             argument1     => pv_argument1,
                                             argument2     => pv_argument2,
                                             argument3     => pv_argument3,
                                             argument4     => pv_argument4,
                                             argument5     => pv_argument5,
                                             argument6     => pv_argument6,
                                             argument7     => pv_argument7,
                                             argument8     => pv_argument8,
                                             argument9     => pv_argument9,
                                             argument10    => pv_argument10,
                                             argument11    => pv_argument11,
                                             argument12    => pv_argument12,
                                             argument13    => pv_argument13,
                                             argument14    => pv_argument14,
                                             argument15    => pv_argument15,
                                             argument16    => pv_argument16,
                                             argument17    => pv_argument17,
                                             argument18    => pv_argument18,
                                             argument19    => pv_argument19,
                                             argument20    => pv_argument20,
                                             argument21    => pv_argument21,
                                             argument22    => pv_argument22,
                                             argument23    => pv_argument23,
                                             argument24    => pv_argument24,
                                             argument25    => pv_argument25,
                                             argument26    => pv_argument26,
                                             argument27    => pv_argument27,
                                             argument28    => pv_argument28,
                                             argument29    => pv_argument29,
                                             argument30    => pv_argument30,
                                             argument31    => pv_argument31,
                                             argument32    => pv_argument32,
                                             argument33    => pv_argument33,
                                             argument34    => pv_argument34,
                                             argument35    => pv_argument35,
                                             argument36    => pv_argument36,
                                             argument37    => pv_argument37,
                                             argument38    => pv_argument38);
        COMMIT;

        IF l_request_id <> 0
        THEN
            IF pv_wait_for_request = 'Y'
            THEN
                l_req_status   :=
                    apps.fnd_concurrent.wait_for_request (
                        request_id   => l_request_id,
                        interval     => pn_interval,
                        max_wait     => pn_max_wait,
                        phase        => l_phase,
                        status       => l_status,
                        dev_phase    => l_dev_phase,
                        dev_status   => l_dev_status,
                        MESSAGE      => l_message);



                IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
                THEN
                    IF NVL (l_dev_status, 'ERROR') = 'WARNING'
                    THEN
                        pv_error_stat   := 'W';
                    ELSE
                        pv_error_stat   := apps.fnd_api.g_ret_sts_error;
                    END IF;

                    pv_error_msg   :=
                        NVL (
                            l_message,
                               'The request ended with a status of '
                            || NVL (l_dev_status, 'ERROR'));
                ELSE
                    pv_error_stat   := 'S';
                END IF;
            ELSE
                pv_error_stat   := 'S';
            END IF;
        ELSE
            pv_error_stat   := 'E';
            pv_error_msg    := 'No request launched';
            pn_request_id   := NULL;
            RETURN;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Unexpected error : ' || SQLERRM;
    END;



    PROCEDURE relieve_atp (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        l_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        l_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl                 OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl               OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec                  OE_ORDER_PUB.Request_Rec_Type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values                VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit                VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_old_header_rec               OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_old_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_old_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_old_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_old_Header_Price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_old_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_old_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_old_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_old_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_old_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_old_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_old_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_old_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_old_Line_Price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_old_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_old_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_old_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_old_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_old_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_old_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_REQUEST_TBL;
        x_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        x_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        X_DEBUG_FILE                   VARCHAR2 (500);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);


        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;

        CURSOR c_order_number IS
              SELECT DISTINCT ooha.order_number,
                              ooha.header_id,
                              ooha.org_id,
                              (SELECT DISTINCT oola.ship_from_org_id
                                 FROM oe_order_lines_all oola
                                WHERE ooha.header_id = oola.header_id) ship_from_org_id
                FROM apps.oe_order_headers_all ooha
               WHERE ooha.order_number = pn_order_number
            ORDER BY ooha.order_number;

        CURSOR c_line_details (pv_order_number VARCHAR2)
        IS
              SELECT oola.line_id, oola.header_id, oola.ordered_quantity,
                     oola.ordered_item, oola.request_date
                FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
               WHERE     1 = 1
                     AND ooha.order_number = pv_order_number
                     AND ooha.header_id = oola.header_id
                     AND oola.open_flag = 'Y'
            ORDER BY oola.ordered_quantity DESC;

        ln_ordered_quantity            NUMBER;
        ln_total_sum                   NUMBER;
        ln_initial_quantity            NUMBER;
    BEGIN
        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Manager - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_resp_id        := 50746;
                gn_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);



        FOR r_order_number IN c_order_number
        LOOP
            mo_global.Set_org_context (r_order_number.org_id, NULL, 'ONT');

            oe_debug_pub.initialize;
            oe_msg_pub.initialize;
            l_line_tbl_index         := 1;
            l_line_tbl.delete ();

            l_header_rec             := OE_ORDER_PUB.G_MISS_HEADER_REC;
            l_header_rec.header_id   := r_order_number.header_id;
            l_header_rec.operation   := OE_GLOBALS.G_OPR_UPDATE;

            FOR r_line_details
                IN c_line_details (r_order_number.order_number)
            LOOP
                ln_ordered_quantity                                    :=
                    GREATEST (r_line_details.ordered_quantity, 0);

                -- Changed attributes
                l_line_tbl (l_line_tbl_index)                          :=
                    OE_ORDER_PUB.G_MISS_LINE_REC;
                l_line_tbl (l_line_tbl_index).operation                :=
                    OE_GLOBALS.G_OPR_UPDATE;
                l_line_tbl (l_line_tbl_index).header_id                :=
                    r_line_details.header_id;        -- header_id of the order
                l_line_tbl (l_line_tbl_index).line_id                  :=
                    r_line_details.line_id;       -- line_id of the order line
                l_line_tbl (l_line_tbl_index).ordered_quantity         :=
                    ln_ordered_quantity;               -- new ordered quantity
                l_line_tbl (l_line_tbl_index).Override_atp_date_code   := 'Y';
                l_line_tbl (l_line_tbl_index).change_reason            := '1'; -- change reason code
                l_line_tbl (l_line_tbl_index).schedule_arrival_date    :=
                    r_line_details.request_date;
                l_line_tbl_index                                       :=
                    l_line_tbl_index + 1;
            END LOOP;

            IF l_line_tbl.COUNT > 0
            THEN
                -- CALL TO PROCESS ORDER
                OE_ORDER_PUB.process_order (
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_false,
                    x_return_status            => l_return_status,
                    x_msg_count                => l_msg_count,
                    x_msg_data                 => l_msg_data,
                    p_header_rec               => l_header_rec,
                    p_line_tbl                 => l_line_tbl,
                    p_action_request_tbl       => l_action_request_tbl,
                    x_header_rec               => p_header_rec,
                    x_header_val_rec           => x_header_val_rec,
                    x_Header_Adj_tbl           => x_Header_Adj_tbl,
                    x_Header_Adj_val_tbl       => x_Header_Adj_val_tbl,
                    x_Header_price_Att_tbl     => x_Header_price_Att_tbl,
                    x_Header_Adj_Att_tbl       => x_Header_Adj_Att_tbl,
                    x_Header_Adj_Assoc_tbl     => x_Header_Adj_Assoc_tbl,
                    x_Header_Scredit_tbl       => x_Header_Scredit_tbl,
                    x_Header_Scredit_val_tbl   => x_Header_Scredit_val_tbl,
                    x_line_tbl                 => p_line_tbl,
                    x_line_val_tbl             => x_line_val_tbl,
                    x_Line_Adj_tbl             => x_Line_Adj_tbl,
                    x_Line_Adj_val_tbl         => x_Line_Adj_val_tbl,
                    x_Line_price_Att_tbl       => x_Line_price_Att_tbl,
                    x_Line_Adj_Att_tbl         => x_Line_Adj_Att_tbl,
                    x_Line_Adj_Assoc_tbl       => x_Line_Adj_Assoc_tbl,
                    x_Line_Scredit_tbl         => x_Line_Scredit_tbl,
                    x_Line_Scredit_val_tbl     => x_Line_Scredit_val_tbl,
                    x_Lot_Serial_tbl           => x_Lot_Serial_tbl,
                    x_Lot_Serial_val_tbl       => x_Lot_Serial_val_tbl,
                    x_action_request_tbl       => p_action_request_tbl);

                -- Check the return status
                IF l_return_status = FND_API.G_RET_STS_SUCCESS
                THEN
                    COMMIT;
                ELSE
                    -- Retrieve messages
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        insert_message (
                            'BOTH',
                            'message index is: ' || l_msg_index_out);
                        insert_message ('BOTH', 'message is: ' || l_msg_data);
                    END LOOP;
                END IF;
            END IF;

            COMMIT;
        END LOOP;

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE run_om_schedule_orders (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        ln_org_id           NUMBER;
        ln_req_request_id   NUMBER;
    BEGIN
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM oe_order_headers_all
             WHERE order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Order not found';
        END;


        exec_conc_request (pv_error_stat => pv_error_stat, pv_error_msg => pv_error_msg, pn_request_id => ln_req_request_id, pv_application => 'ONT', -- application short name
                                                                                                                                                      pv_program => 'SCHORD', -- program short name
                                                                                                                                                                              pv_wait_for_request => 'Y', pv_argument1 => ln_org_id, -- Operating Unit
                                                                                                                                                                                                                                     pv_argument2 => pn_order_number, -- Internal Order
                                                                                                                                                                                                                                                                      pv_argument3 => pn_order_number, pv_argument4 => '', pv_argument5 => '', pv_argument6 => '', pv_argument7 => '', pv_argument8 => '', pv_argument9 => '', pv_argument10 => '', pv_argument11 => '', pv_argument12 => '', pv_argument13 => '', pv_argument14 => '', pv_argument15 => '', pv_argument16 => '', pv_argument17 => '', pv_argument18 => '', pv_argument19 => '', pv_argument20 => '', pv_argument21 => '', pv_argument22 => '', pv_argument23 => '', pv_argument24 => '', pv_argument25 => '', pv_argument26 => '', pv_argument27 => '', pv_argument28 => '', pv_argument29 => '', pv_argument30 => '', pv_argument31 => '', pv_argument32 => '', pv_argument33 => '', pv_argument34 => '', pv_argument35 => '', pv_argument36 => 'Y'
                           , pv_argument37 => '1000', pv_argument38 => ''); -- Orig Sys Document Ref
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE schedule_order (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (4000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (4000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
        test_line                      oe_order_pub.Line_Rec_Type;
        v_line_tbl                     oe_order_pub.line_tbl_type;
        v_action_request_tbl           oe_order_pub.request_tbl_type;
        v_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;

        -- OUT Variables --
        v_header_rec_out               oe_order_pub.header_rec_type;
        v_header_val_rec_out           oe_order_pub.header_val_rec_type;
        v_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        v_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        v_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        v_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        v_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        v_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        v_line_tbl_out                 oe_order_pub.line_tbl_type;
        v_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        v_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        v_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        v_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        v_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        v_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        v_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        v_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        v_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        v_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        v_action_request_tbl_out       oe_order_pub.request_tbl_type;

        v_msg_index                    NUMBER;
        v_data                         VARCHAR2 (2000);
        v_loop_count                   NUMBER;
        v_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);
        i                              NUMBER := 0;
        j                              NUMBER := 0;

        ln_user_id                     NUMBER := fnd_global.user_id;
        ln_resp_id                     NUMBER := fnd_global.resp_id;
        ln_resp_appl_id                NUMBER := fnd_global.resp_appl_id;

        CURSOR line_cur (n_header_id NUMBER)
        IS
            SELECT line_id, request_date
              FROM oe_order_lines_all
             WHERE header_id = n_header_id;

        ln_header_id                   NUMBER;
        ln_org_id                      NUMBER;

        exProcessError                 EXCEPTION;
    BEGIN
        BEGIN
            SELECT DISTINCT ooha.header_id, ooha.org_id
              INTO ln_header_id, ln_org_id
              FROM oe_order_headers_all ooha
             WHERE ooha.order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg    := 'Order not found';
                pv_error_stat   := 'E';
                RETURN;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => ln_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        mo_global.init ('ONT');
        mo_global.Set_org_context (ln_org_id, NULL, 'ONT');

        v_line_tbl.delete ();

        FOR line_rec IN line_cur (ln_header_id)
        LOOP
            j                                       := j + 1;

            v_line_tbl (j)                          := OE_ORDER_PUB.G_MISS_LINE_REC;
            v_line_tbl (j).header_id                := ln_header_id;
            v_line_tbl (j).line_id                  := line_rec.line_id;
            v_line_tbl (j).operation                := oe_globals.G_OPR_UPDATE;
            v_line_tbl (j).OVERRIDE_ATP_DATE_CODE   := 'Y';
            v_line_tbl (j).schedule_arrival_date    := line_rec.request_date;
        --   v_line_tbl (j).schedule_ship_date := line_rec.request_date;
        -- v_line_tbl(j).schedule_action_code := oe_order_sch_util.oesch_act_schedule;
        END LOOP;

        IF j > 0
        THEN
            OE_ORDER_PUB.PROCESS_ORDER (
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_header_rec,
                p_line_tbl                 => v_line_tbl,
                p_action_request_tbl       => v_action_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl,
                x_header_rec               => v_header_rec_out,
                x_header_val_rec           => v_header_val_rec_out,
                x_header_adj_tbl           => v_header_adj_tbl_out,
                x_header_adj_val_tbl       => v_header_adj_val_tbl_out,
                x_header_price_att_tbl     => v_header_price_att_tbl_out,
                x_header_adj_att_tbl       => v_header_adj_att_tbl_out,
                x_header_adj_assoc_tbl     => v_header_adj_assoc_tbl_out,
                x_header_scredit_tbl       => v_header_scredit_tbl_out,
                x_header_scredit_val_tbl   => v_header_scredit_val_tbl_out,
                x_line_tbl                 => v_line_tbl_out,
                x_line_val_tbl             => v_line_val_tbl_out,
                x_line_adj_tbl             => v_line_adj_tbl_out,
                x_line_adj_val_tbl         => v_line_adj_val_tbl_out,
                x_line_price_att_tbl       => v_line_price_att_tbl_out,
                x_line_adj_att_tbl         => v_line_adj_att_tbl_out,
                x_line_adj_assoc_tbl       => v_line_adj_assoc_tbl_out,
                x_line_scredit_tbl         => v_line_scredit_tbl_out,
                x_line_scredit_val_tbl     => v_line_scredit_val_tbl_out,
                x_lot_serial_tbl           => v_lot_serial_tbl_out,
                x_lot_serial_val_tbl       => v_lot_serial_val_tbl_out,
                x_action_request_tbl       => v_action_request_tbl_out,
                x_return_status            => v_return_status,
                x_msg_count                => v_msg_count,
                x_msg_data                 => v_msg_data);


            IF v_return_status = fnd_api.g_ret_sts_success
            THEN
                pv_error_stat   := 'S';
                COMMIT;
            ELSE
                ROLLBACK;

                FOR i IN 1 .. v_msg_count
                LOOP
                    v_msg_data   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                pv_error_stat   := 'E';
                pv_error_msg    := SUBSTR (v_msg_data, 1, 2000);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE reprice_sales_order (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        l_api_version_number       NUMBER := 1;
        l_init_msg_list            VARCHAR2 (30) := fnd_api.g_false;
        l_return_values            VARCHAR2 (30) := fnd_api.g_false;
        l_action_commit            VARCHAR2 (30) := fnd_api.g_false;
        l_line_tab                 oe_order_pub.line_tbl_type;
        x_line_tab                 oe_order_pub.line_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_return_status            VARCHAR2 (10);
        x_msg_count                NUMBER;
        x_msg_data                 VARCHAR2 (2000);
        lc_error_msg               VARCHAR2 (2000);
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
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
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_action_request_tbl_out   oe_order_pub.request_tbl_type;
        ln_record_count            NUMBER := 0;


        ln_header_id               NUMBER;
        ln_org_id                  NUMBER;
        ln_inv_org_id              NUMBER;
        ln_user_id                 NUMBER := fnd_global.user_id;
        ln_resp_id                 NUMBER := fnd_global.resp_id;
        ln_resp_appl_id            NUMBER := fnd_global.resp_appl_id;
    BEGIN
        BEGIN
            SELECT DISTINCT ooha.header_id, ooha.org_id, oola.ship_from_org_id
              INTO ln_header_id, ln_org_id, ln_inv_org_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     ooha.header_id = oola.header_id
                   AND ooha.order_number = pn_order_number
                   AND oola.flow_status_code NOT IN ('CANCELLED', 'ENTERED');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg    := 'Order not found';
                pv_error_stat   := 'E';
                RETURN;
            WHEN TOO_MANY_ROWS
            THEN
                pv_error_msg    := 'Multiple ship from for order';
                pv_error_stat   := 'E';
                RETURN;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => ln_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        apps.fnd_profile.put ('MFG_ORGANIZATION_ID', ln_inv_org_id);
        mo_global.init ('ONT');

        l_action_request_tbl (1)                := oe_order_pub.g_miss_request_rec;
        l_action_request_tbl (1).entity_id      := ln_header_id;
        l_action_request_tbl (1).entity_code    := oe_globals.g_entity_header;
        l_action_request_tbl (1).request_type   := oe_globals.g_price_order;

        oe_order_pub.process_order (
            p_org_id                   => ln_org_id,
            p_operating_unit           => NULL,
            p_api_version_number       => l_api_version_number,
            p_init_msg_list            => l_init_msg_list,
            p_return_values            => l_return_values,
            p_action_commit            => l_action_commit,
            x_return_status            => x_return_status,
            x_msg_count                => x_msg_count,
            x_msg_data                 => x_msg_data,
            p_line_tbl                 => l_line_tab,
            p_line_adj_tbl             => l_line_adj_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            x_header_rec               => x_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => l_header_adj_tbl,
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
            x_action_request_tbl       => l_action_request_tbl_out);

        IF x_return_status != fnd_api.g_ret_sts_success
        THEN
            FOR i IN 1 .. x_msg_count
            LOOP
                lc_error_msg   :=
                    oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        ELSE
            pv_error_stat   := 'E';
            pv_error_msg    := SUBSTR (lc_error_msg, 1, 2000);
        END IF;

        pv_error_stat                           := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE pick_release_order (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_order_number IN NUMBER)
    IS
        lv_err_stat          VARCHAR2 (1);
        lv_err_msg           VARCHAR2 (2000);
        ln_user_id           NUMBER := 28227;                --JONATHAN.PETROU
        l_batch_info_rec     WSH_PICKING_BATCHES_PUB.BATCH_INFO_REC;

        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (2000);
        lv_return_status     VARCHAR2 (1);
        ln_batch_prefix      VARCHAR2 (10);
        ln_new_batch_id      NUMBER;

        ln_count             NUMBER;
        ln_request_id        NUMBER;

        lb_bol_result        BOOLEAN;
        lv_chr_phase         VARCHAR2 (250) := NULL;
        lv_chr_status        VARCHAR2 (250) := NULL;
        lv_chr_dev_phase     VARCHAR2 (250) := NULL;
        lv_chr_dev_status    VARCHAR2 (250) := NULL;
        lv_chr_message       VARCHAR2 (250) := NULL;

        ln_header_id         NUMBER;
        ln_org_id            NUMBER;
        ln_order_type_id     NUMBER;
        ln_organization_id   NUMBER;
    BEGIN
        -- do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_app_id);

        BEGIN
            SELECT header_id,
                   org_id,
                   order_type_id,
                   (SELECT DISTINCT ship_from_org_id
                      FROM oe_order_lines_all oola
                     WHERE ooha.header_id = oola.header_id) organization_id
              INTO ln_header_id, ln_org_id, ln_order_type_id, ln_organization_id
              FROM oe_order_headers_all ooha
             WHERE order_number = pn_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Order does not exist';
                RETURN;
        END;

        --  apps.fnd_profile.put ('MFG_ORGANIZATION_ID', ln_organization_id);
        -- mo_global.init ('ONT');

        lv_return_status                              := wsh_util_core.g_ret_sts_success;

        l_batch_info_rec                              := NULL;
        insert_message ('BOTH', 'User ID : ' || gn_user_id);
        insert_message ('BOTH', 'Resp ID : ' || gn_resp_id);
        insert_message ('BOTH', 'Resp App ID : ' || gn_resp_appl_id);

        insert_message ('BOTH', 'Order Number : ' || pn_order_number);
        insert_message ('BOTH', 'Order Type ID : ' || ln_order_type_id);
        insert_message ('BOTH', 'Organization_id : ' || ln_organization_id);

        l_batch_info_rec.order_number                 := pn_order_number;
        l_batch_info_rec.order_type_id                := ln_order_type_id;
        l_batch_info_rec.Autodetail_Pr_Flag           := 'Y';
        l_batch_info_rec.organization_id              := ln_organization_id;
        l_batch_info_rec.autocreate_delivery_flag     := 'Y';
        l_batch_info_rec.Backorders_Only_Flag         := 'I';
        l_batch_info_rec.allocation_method            := 'I';
        l_batch_info_rec.auto_pick_confirm_flag       := 'Y';
        l_batch_info_rec.autopack_flag                := 'N';
        l_batch_info_rec.append_flag                  := 'N';
        l_batch_info_rec.Pick_From_Subinventory       := 'RECEIVING';
        l_batch_info_rec.Default_Stage_Subinventory   := 'RECEIVING';
        ln_batch_prefix                               := NULL;
        ln_new_batch_id                               := NULL;

        WSH_PICKING_BATCHES_PUB.CREATE_BATCH (
            p_api_version     => 1.0,
            p_init_msg_list   => fnd_api.g_true,
            p_commit          => fnd_api.g_true,
            x_return_status   => lv_return_status,
            x_msg_count       => ln_msg_count,
            x_msg_data        => lv_msg_data,
            p_rule_id         => NULL,
            p_rule_name       => NULL,
            p_batch_rec       => l_batch_info_rec,
            p_batch_prefix    => ln_batch_prefix,
            x_batch_id        => ln_new_batch_id);

        IF lv_return_status <> 'S'
        THEN
            insert_message (
                'BOTH',
                'CREATE_BATCH: lv_return_status ' || lv_return_status);
            insert_message ('BOTH', 'Message count ' || ln_msg_count);

            IF ln_msg_count = 1
            THEN
                insert_message ('BOTH', 'lv_msg_data ' || lv_msg_data);
            ELSIF ln_msg_count > 1
            THEN
                LOOP
                    ln_count   := ln_count + 1;
                    lv_msg_data   :=
                        FND_MSG_PUB.Get (FND_MSG_PUB.G_NEXT, FND_API.G_FALSE);

                    IF lv_msg_data IS NULL
                    THEN
                        EXIT;
                    END IF;

                    insert_message (
                        'BOTH',
                        'Message' || ln_count || '---' || lv_msg_data);
                END LOOP;
            END IF;

            pv_error_stat   := lv_return_status;
            RETURN;
        ELSE
            -- Release the batch Created Above
            WSH_PICKING_BATCHES_PUB.RELEASE_BATCH (
                P_API_VERSION     => 1.0,
                P_INIT_MSG_LIST   => fnd_api.g_true,
                P_COMMIT          => fnd_api.g_true,
                X_RETURN_STATUS   => lv_return_status,
                X_MSG_COUNT       => ln_msg_count,
                X_MSG_DATA        => lv_msg_data,
                P_BATCH_ID        => ln_new_batch_id,
                P_BATCH_NAME      => NULL,
                P_LOG_LEVEL       => 1,
                P_RELEASE_MODE    => 'ONLINE',       -- (ONLINE or CONCURRENT)
                X_REQUEST_ID      => ln_request_id);



            IF ln_request_id <> 0
            THEN
                lb_bol_result   :=
                    fnd_concurrent.wait_for_request (ln_request_id,
                                                     15,
                                                     0,
                                                     lv_chr_phase,
                                                     lv_chr_status,
                                                     lv_chr_dev_phase,
                                                     lv_chr_dev_status,
                                                     lv_chr_message);
            END IF;
        END IF;

        pv_error_stat                                 := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE ship_confirm_delivery (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_delivery_id IN NUMBER)
    IS
        --Standard Parameters
        p_api_version               NUMBER;
        p_init_msg_list             VARCHAR2 (30);
        p_commit                    VARCHAR2 (30);
        --Parameters for WSH_DELIVERIES_PUB.Delivery_Action.
        p_action_code               VARCHAR2 (15);
        p_delivery_id               NUMBER;
        p_delivery_name             VARCHAR2 (30);
        p_asg_trip_id               NUMBER;
        p_asg_trip_name             VARCHAR2 (30);
        p_asg_pickup_stop_id        NUMBER;
        p_asg_pickup_loc_id         NUMBER;
        p_asg_pickup_loc_code       VARCHAR2 (30);
        p_asg_pickup_arr_date       DATE;
        p_asg_pickup_dep_date       DATE;
        p_asg_dropoff_stop_id       NUMBER;
        p_asg_dropoff_loc_id        NUMBER;
        p_asg_dropoff_loc_code      VARCHAR2 (30);
        p_asg_dropoff_arr_date      DATE;
        p_asg_dropoff_dep_date      DATE;
        p_sc_action_flag            VARCHAR2 (10);
        p_sc_close_trip_flag        VARCHAR2 (10);
        p_sc_create_bol_flag        VARCHAR2 (10);
        p_sc_stage_del_flag         VARCHAR2 (10);
        p_sc_trip_ship_method       VARCHAR2 (30);
        p_sc_actual_dep_date        VARCHAR2 (30);
        p_sc_report_set_id          NUMBER;
        p_sc_report_set_name        VARCHAR2 (60);
        p_wv_override_flag          VARCHAR2 (10);
        p_sc_defer_interface_flag   VARCHAR2 (1);
        x_trip_id                   VARCHAR2 (30);
        x_trip_name                 VARCHAR2 (30);
        --out parameters
        x_return_status             VARCHAR2 (10);
        x_msg_count                 NUMBER;
        x_msg_data                  VARCHAR2 (4000);
        x_msg_details               VARCHAR2 (4000);
        x_msg_summary               VARCHAR2 (4000);
        -- Handle exceptions
        vapierrorexception          EXCEPTION;

        l_sqlerrm                   VARCHAR2 (4000);
        l_confirm_date              wsh_new_deliveries.confirm_date%TYPE;
        l_result                    VARCHAR2 (10);


        ln_count                    NUMBER;


        ln_inv_org_id               NUMBER;

        ln_user_id                  NUMBER := fnd_global.user_id;
        ln_resp_id                  NUMBER := fnd_global.resp_id;
        ln_resp_appl_id             NUMBER := fnd_global.resp_appl_id;

        l_chr_errbuf                VARCHAR2 (2000);
        l_chr_ret_code              VARCHAR2 (30);
        l_result                    VARCHAR2 (240);
    BEGIN
        BEGIN
            SELECT organization_id
              INTO ln_inv_org_id
              FROM wsh_new_deliveries wnd
             WHERE wnd.delivery_id = pn_delivery_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Delivery not found';
                RETURN;
        END;

        SAVEPOINT begin_process;


        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => ln_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        -- Values for Ship Confirming the delivery
        p_action_code               := 'CONFIRM'; -- The action code for ship confirm
        p_delivery_id               := pn_delivery_id; -- The delivery that needs to be confirmed
        p_sc_action_flag            := 'S';          -- Ship entered quantity.
        p_sc_close_trip_flag        := 'Y'; -- Close the trip after ship confirm
        p_sc_defer_interface_flag   := 'N';                                 --

        -- Call to WSH_DELIVERIES_PUB.Delivery_Action.
        BEGIN
            wsh_deliveries_pub.delivery_action (
                p_api_version_number        => 1.0,
                p_init_msg_list             => p_init_msg_list,
                x_return_status             => x_return_status,
                x_msg_count                 => x_msg_count,
                x_msg_data                  => x_msg_data,
                p_action_code               => p_action_code,
                p_delivery_id               => p_delivery_id,
                p_delivery_name             => p_delivery_name,
                p_asg_trip_id               => p_asg_trip_id,
                p_asg_trip_name             => p_asg_trip_name,
                p_asg_pickup_stop_id        => p_asg_pickup_stop_id,
                p_asg_pickup_loc_id         => p_asg_pickup_loc_id,
                p_asg_pickup_loc_code       => p_asg_pickup_loc_code,
                p_asg_pickup_arr_date       => p_asg_pickup_arr_date,
                p_asg_pickup_dep_date       => p_asg_pickup_dep_date,
                p_asg_dropoff_stop_id       => p_asg_dropoff_stop_id,
                p_asg_dropoff_loc_id        => p_asg_dropoff_loc_id,
                p_asg_dropoff_loc_code      => p_asg_dropoff_loc_code,
                p_asg_dropoff_arr_date      => p_asg_dropoff_arr_date,
                p_asg_dropoff_dep_date      => p_asg_dropoff_dep_date,
                p_sc_action_flag            => p_sc_action_flag,
                p_sc_close_trip_flag        => p_sc_close_trip_flag,
                p_sc_create_bol_flag        => p_sc_create_bol_flag,
                p_sc_stage_del_flag         => p_sc_stage_del_flag,
                p_sc_trip_ship_method       => p_sc_trip_ship_method,
                p_sc_actual_dep_date        => p_sc_actual_dep_date,
                p_sc_report_set_id          => p_sc_report_set_id,
                p_sc_report_set_name        => p_sc_report_set_name,
                p_wv_override_flag          => p_wv_override_flag,
                p_sc_defer_interface_flag   => p_sc_defer_interface_flag,
                x_trip_id                   => x_trip_id,
                x_trip_name                 => x_trip_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO begin_process;

                RAISE;
        END;

        IF x_return_status NOT IN ('S', 'W')
        THEN
            insert_message ('BOTH',
                            'DELIVERY_ACTION: RETSTAT ' || x_return_status);
            insert_message ('BOTH', 'Message count ' || x_msg_count);

            IF x_msg_count = 1
            THEN
                insert_message ('BOTH', 'lv_msg_data ' || x_msg_data);
            ELSIF x_msg_count > 1
            THEN
                LOOP
                    ln_count   := ln_count + 1;
                    x_msg_data   :=
                        FND_MSG_PUB.Get (FND_MSG_PUB.G_NEXT, FND_API.G_FALSE);

                    IF x_msg_data IS NULL
                    THEN
                        EXIT;
                    END IF;

                    insert_message (
                        'BOTH',
                        'Message' || ln_count || '---' || x_msg_data);
                END LOOP;
            END IF;


            pv_error_stat   := x_return_status;
            pv_error_msg    := x_msg_data;
        ELSE
            insert_message ('BOTH', 'Confirm complete');
            insert_message ('BOTH', 'x_trip_id  ' || x_trip_id);
            insert_message ('BOTH', 'x_trip_name ' || x_trip_name);
        END IF;

        COMMIT;

        /*
  Need to initiate Interface Trip stop API and then also launch OM Workflow program
  */
        BEGIN
            IF x_return_status IN ('S', 'W')
            THEN
                --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, Before calling ITS..');
                wsh_ship_confirm_actions.interface_all_wrp (
                    errbuf          => l_chr_errbuf,
                    retcode         => l_chr_ret_code,
                    p_mode          => 'ALL',
                    p_delivery_id   => p_delivery_id);
            --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, After calling ITS..');
            --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, ITS completed, l_chr_ret_code..'||l_chr_ret_code);
            END IF;
        -- end for loop
        EXCEPTION
            WHEN OTHERS
            THEN
                insert_message ('BOTH', 'Error message: ' || SQLERRM);
        --x_retstat := 'U';
        END;


        pv_error_stat               := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    PROCEDURE create_reservation (
        pn_so_line_id       IN     NUMBER,
        pn_supply_line_id   IN     NUMBER,
        pn_supply_type_id   IN     NUMBER,
        pn_quantity         IN     NUMBER,
        pv_subinventory     IN     VARCHAR2 := NULL,
        pn_reservation_id      OUT NUMBER,
        pv_error_stat          OUT VARCHAR,
        pv_err_msg             OUT VARCHAR)
    IS
        lv_return_status        VARCHAR2 (1) := FND_API.G_RET_STS_SUCCESS;
        ln_msg_count            NUMBER;
        lv_msg_data             VARCHAR2 (3000);


        lr_orig_rsv_rec         inv_reservation_global.mtl_reservation_rec_type;
        l_rsv_rec               inv_reservation_global.mtl_reservation_rec_type;
        lr_orig_serial_number   inv_reservation_global.serial_number_tbl_type;
        x_serial_number         INV_RESERVATION_GLOBAL.SERIAL_NUMBER_TBL_TYPE;
        l_serial_number         INV_RESERVATION_GLOBAL.SERIAL_NUMBER_TBL_TYPE;
        ln_msg_index            NUMBER;
        l_init_msg_list         VARCHAR2 (2) := FND_API.G_TRUE;
        ln_quantity_reserved    NUMBER := 0;
        x_return_status         VARCHAR2 (1);
        x_msg_count             NUMBER;
        lc_message              VARCHAR2 (2000);

        ln_organization_id      NUMBER;
        ln_inventory_item_id    NUMBER;
        ld_request_date         DATE;
        ln_ordered_quantity     NUMBER;
        lv_order_quantity_uom   VARCHAR2 (20);
        ln_header_id            NUMBER;
        ln_supply_header_id     NUMBER := NULL;
    BEGIN
        BEGIN
            SELECT oola.ship_from_org_id, oola.inventory_item_id, oola.request_date,
                   oola.ordered_quantity, oola.order_quantity_uom, mso.sales_order_id
              INTO ln_organization_id, ln_inventory_item_id, ld_request_date, ln_ordered_quantity,
                                     lv_order_quantity_uom, ln_header_id
              FROM oe_order_lines_all oola, oe_order_headers_all ooha, mtl_sales_orders mso
             WHERE     line_id = pn_so_line_id
                   AND oola.header_id = ooha.header_id
                   AND ooha.order_number = mso.segment1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_err_msg      := 'Order line not found';
                RETURN;
        END;


        IF pn_supply_type_id = inv_reservation_global.g_source_type_po
        THEN
            BEGIN
                SELECT po_header_id
                  INTO ln_supply_header_id
                  FROM po_line_locations_all
                 WHERE line_location_id = pn_supply_line_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    pv_error_stat   := 'E';
                    pv_err_msg      := 'po shipment not found';
                    RETURN;
            END;
        ELSIF pn_supply_type_id = inv_reservation_global.g_source_type_inv
        THEN
            ln_supply_header_id   := NULL;
        ELSE
            pv_error_stat   := 'E';
            pv_err_msg      := 'Not a valid source type';
            RETURN;
        END IF;

        l_rsv_rec.organization_id                := ln_organization_id;
        l_rsv_rec.inventory_item_id              := ln_inventory_item_id;
        l_rsv_rec.requirement_date               := ld_request_date;
        l_rsv_rec.demand_source_type_id          :=
            inv_reservation_global.g_source_type_oe;
        l_rsv_rec.supply_source_type_id          := pn_supply_type_id;
        l_rsv_rec.demand_source_name             := NULL;
        l_rsv_rec.primary_reservation_quantity   := pn_quantity;
        l_rsv_rec.primary_uom_code               := lv_order_quantity_uom;
        l_rsv_rec.subinventory_code              := pv_subinventory;
        l_rsv_rec.demand_source_header_id        := ln_header_id;
        l_rsv_rec.demand_source_line_id          := pn_so_line_id;
        l_rsv_rec.reservation_uom_code           := lv_order_quantity_uom;
        l_rsv_rec.reservation_quantity           := pn_quantity; ----l_reservation_qty;
        -- l_rsv_rec.secondary_reservation_quantity := 100;
        l_rsv_rec.supply_source_header_id        := ln_supply_header_id;
        l_rsv_rec.supply_source_line_id          := pn_supply_line_id;
        l_rsv_rec.supply_source_name             := NULL;
        l_rsv_rec.supply_source_line_detail      := NULL;
        l_rsv_rec.lot_number                     := NULL;
        l_rsv_rec.serial_number                  := NULL;
        l_rsv_rec.ship_ready_flag                := NULL;
        l_rsv_rec.attribute15                    := NULL;
        l_rsv_rec.attribute14                    := NULL;
        l_rsv_rec.attribute13                    := NULL;
        l_rsv_rec.attribute12                    := NULL;
        l_rsv_rec.attribute11                    := NULL;
        l_rsv_rec.attribute10                    := NULL;
        l_rsv_rec.attribute9                     := NULL;
        l_rsv_rec.attribute8                     := NULL;
        l_rsv_rec.attribute7                     := NULL;
        l_rsv_rec.attribute6                     := NULL;
        l_rsv_rec.attribute5                     := NULL;
        l_rsv_rec.attribute4                     := NULL;
        l_rsv_rec.attribute3                     := NULL;
        l_rsv_rec.attribute2                     := NULL;
        l_rsv_rec.attribute1                     := NULL;
        l_rsv_rec.attribute_category             := NULL;
        l_rsv_rec.lpn_id                         := NULL;
        l_rsv_rec.pick_slip_number               := NULL;
        l_rsv_rec.lot_number_id                  := NULL;
        l_rsv_rec.locator_id                     := NULL; ---inventory_location_id ;-- NULL ;
        l_rsv_rec.subinventory_id                := NULL;
        l_rsv_rec.revision                       := NULL;
        l_rsv_rec.external_source_line_id        := NULL;
        l_rsv_rec.external_source_code           := NULL;
        l_rsv_rec.autodetail_group_id            := NULL;
        l_rsv_rec.reservation_uom_id             := NULL;
        l_rsv_rec.primary_uom_id                 := NULL;
        l_rsv_rec.demand_source_delivery         := NULL;
        l_rsv_rec.crossdock_flag                 := NULL;
        l_rsv_rec.secondary_uom_code             := NULL;
        l_rsv_rec.detailed_quantity              := NULL; --lrec_batch_details.shipped_quantity;
        l_rsv_rec.secondary_detailed_quantity    := NULL; --ln_shipped_quantity;--lrec_batch_details.shipped_quantity;
        ln_msg_count                             := NULL;
        lv_msg_data                              := NULL;
        lv_return_status                         := NULL;

        INV_RESERVATION_PUB.Create_Reservation (
            P_API_VERSION_NUMBER         => 1.0,
            P_INIT_MSG_LST               => l_init_msg_list,
            P_RSV_REC                    => l_rsv_rec,
            P_SERIAL_NUMBER              => l_serial_number,
            P_PARTIAL_RESERVATION_FLAG   => FND_API.G_FALSE,
            P_FORCE_RESERVATION_FLAG     => FND_API.G_FALSE,
            P_PARTIAL_RSV_EXISTS         => FALSE,
            P_VALIDATION_FLAG            => FND_API.G_TRUE,
            X_SERIAL_NUMBER              => x_serial_number,
            X_RETURN_STATUS              => lv_return_status,
            X_MSG_COUNT                  => ln_msg_count,
            X_MSG_DATA                   => lv_msg_data,
            X_QUANTITY_RESERVED          => ln_quantity_reserved,
            X_RESERVATION_ID             => pn_reservation_id);

        IF x_return_status != fnd_api.g_ret_sts_success
        THEN
            FOR i IN 1 .. (x_msg_count)
            LOOP
                lc_message      := fnd_msg_pub.get (i, 'F');
                lc_message      := REPLACE (lc_message, CHR (0), ' ');
                pv_err_msg      := pv_err_msg || lc_message;
                pv_error_stat   := 'E';
            END LOOP;

            RETURN;
        END IF;

        pv_error_stat                            := 'S';
        pv_err_msg                               := '';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_err_msg      := SQLERRM;
    END;

    /********************************************
    Run Receive Transaction Processor for given group ID
    *********************************************/
    PROCEDURE run_rcv_transaction_processor (
        p_group_id     IN     NUMBER,
        p_wait         IN     VARCHAR2 := 'Y',
        p_request_id      OUT NUMBER,
        x_ret_stat        OUT VARCHAR2,
        x_error_text      OUT VARCHAR2)
    IS
        l_req_id       NUMBER;
        l_req_status   BOOLEAN;
        l_phase        VARCHAR2 (80);
        l_status       VARCHAR2 (80);
        l_dev_phase    VARCHAR2 (80);
        l_dev_status   VARCHAR2 (80);
        l_message      VARCHAR2 (255);
        l_org_id       NUMBER;
    BEGIN
        x_ret_stat     := fnd_api.g_ret_sts_success;
        x_error_text   := NULL;

        --Get org for group
        BEGIN
            SELECT DISTINCT org_id
              INTO l_org_id
              FROM rcv_headers_interface
             WHERE GROUP_ID = p_group_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_org_id   := NULL;
        END;

        --If this is not in the group get the US ORG or USER org
        IF l_org_id IS NULL
        THEN
            BEGIN
                SELECT organization_id
                  INTO l_org_id
                  FROM hr_all_organization_units
                 WHERE name = gv_US_OU;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_org_id   := gn_org_id;
            END;
        END IF;


        --Set purchasing context
        set_purchasing_context (gn_user_id, l_org_id, x_ret_stat,
                                x_error_text);

        IF x_ret_stat != 'S'
        THEN
            x_error_text   :=
                'Unable to set purchasing context : ' || x_error_text;
            RETURN;
        END IF;

        l_req_id       :=
            fnd_request.submit_request (application   => 'PO',
                                        program       => 'RVCTP',
                                        argument1     => 'BATCH',
                                        argument2     => TO_CHAR (p_group_id),
                                        argument3     => NULL);
        COMMIT;

        IF NVL (p_wait, 'Y') = 'Y'
        THEN
            l_req_status   :=
                fnd_concurrent.wait_for_request (request_id   => l_req_id,
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
                    x_ret_stat   := 'W';          --fnd_api.g_ret_sts_warning;
                ELSE
                    x_ret_stat   := fnd_api.g_ret_sts_error;
                END IF;

                x_error_text   :=
                    NVL (
                        l_message,
                           'The receiving transaction processor request ended with a status of '
                        || NVL (l_dev_status, 'ERROR'));
                RETURN;
            END IF;
        END IF;

        p_request_id   := l_req_id;
        x_ret_stat     := 'S';
        x_error_text   := '';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat     := fnd_api.g_ret_sts_unexp_error;
            x_error_text   := SQLERRM;
    END;

    PROCEDURE receive_asn (pv_err_stat                OUT VARCHAR2,
                           pv_err_msg                 OUT VARCHAR2,
                           pn_shipment_header_id   IN     NUMBER)
    IS
        CURSOR c_header IS
            SELECT RSH.SHIPMENT_NUM, RSH.SHIP_TO_ORG_ID TO_ORGANIZATION_ID, RSH.EXPECTED_RECEIPT_DATE,
                   RSH.RECEIPT_SOURCE_CODE
              FROM RCV_SHIPMENT_HEADERS RSH
             WHERE SHIPMENT_HEADER_ID = PN_SHIPMENT_HEADER_ID;

        CURSOR c_line IS
            SELECT RSL.SHIPMENT_HEADER_ID, RSL.SHIPMENT_LINE_ID, RSL.REQUISITION_LINE_ID,
                   RSL.ITEM_ID, RSL.QUANTITY_SHIPPED, RSL.QUANTITY_RECEIVED,
                   RSL.TO_ORGANIZATION_ID RECEIVING_ORGANIZATION_ID, NVL (RSL.TO_SUBINVENTORY, HR.ATTRIBUTE2) TO_SUBINVENTORY, RSL.SOURCE_DOCUMENT_CODE,
                   PRLA.DELIVER_TO_LOCATION_ID, PRLA.ORG_ID
              FROM RCV_SHIPMENT_LINES RSL, PO_REQUISITION_LINES_ALL PRLA, HR_ALL_ORGANIZATION_UNITS HR
             WHERE     RSL.SHIPMENT_HEADER_ID = PN_SHIPMENT_HEADER_ID
                   AND RSL.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
                   AND RSL.TO_ORGANIZATION_ID = HR.ORGANIZATION_ID
                   AND RSL.QUANTITY_SHIPPED - RSL.QUANTITY_RECEIVED > 0;

        ln_header_interface_id   NUMBER;
        ln_rcv_group_id          NUMBER;
        ln_created_by            NUMBER := gn_user_id; --apps.fnd_global.user_id; --1876;                     --BATCH.P2P
        ln_employee_id           NUMBER := gn_employee_id; --apps.fnd_global.employee_id;--134
        ln_cnt                   NUMBER;
        lv_trx_type              VARCHAR2 (10);
        lv_receipt_source_code   VARCHAR2 (20);

        ln_request_id            NUMBER;
        ln_err_stat              VARCHAR2 (10);
        ln_err_msg               VARCHAR2 (2000);

        ln_processed_lines       NUMBER := 0;
    BEGIN
        FOR h_rec IN c_header
        LOOP
            ln_header_interface_id   := rcv_headers_interface_s.NEXTVAL;
            ln_rcv_group_id          := rcv_interface_groups_s.NEXTVAL;

            INSERT INTO apps.rcv_headers_interface (header_interface_id, GROUP_ID, processing_status_code, receipt_source_code, transaction_type, auto_transact_code, last_update_date, last_updated_by, last_update_login, creation_date, created_by, shipment_num, ship_to_organization_id, expected_receipt_date, employee_id
                                                    , validation_flag)
                 VALUES (ln_header_interface_id          --header_interface_id
                                               , ln_rcv_group_id    --group_id
                                                                , 'PENDING' --processing_status_code
                                                                           ,
                         h_rec.receipt_source_code       --receipt_source_code
                                                  , 'NEW'   --transaction_type
                                                         , 'DELIVER' --auto_transact_code
                                                                    ,
                         SYSDATE                            --last_update_date
                                , ln_created_by               --last_update_by
                                               , USERENV ('SESSIONID') --last_update_login
                                                                      ,
                         SYSDATE                               --creation_date
                                , ln_created_by                   --created_by
                                               , h_rec.shipment_num --shipment_num
                                                                   ,
                         h_rec.to_organization_id    --ship_to_organization_id
                                                 , NVL (h_rec.expected_receipt_date, SYSDATE + 1) --expected_receipt_date
                                                                                                 , ln_employee_id --employee_id
                         , 'Y'                               --validation_flag
                              );

            FOR l_rec IN c_line
            LOOP
                SELECT COUNT (1)
                  INTO ln_cnt
                  FROM apps.rcv_shipment_lines rsl, apps.po_line_locations_all plla, apps.fnd_lookup_values flv
                 WHERE     rsl.shipment_line_id = l_rec.shipment_line_id
                       AND plla.line_location_id = rsl.po_line_location_id
                       AND flv.lookup_type = 'RCV_ROUTING_HEADERS'
                       AND flv.LANGUAGE = 'US'
                       AND flv.lookup_code =
                           TO_CHAR (plla.receiving_routing_id)
                       AND flv.view_application_id = 0
                       AND flv.security_group_id = 0
                       AND flv.meaning = 'Standard Receipt';

                IF ln_cnt = 1
                THEN
                    lv_trx_type   := 'DELIVER';
                ELSE
                    lv_trx_type   := 'RECEIVE';
                END IF;

                INSERT INTO apps.rcv_transactions_interface (
                                interface_transaction_id,
                                GROUP_ID,
                                org_id,
                                last_update_date,
                                last_updated_by,
                                creation_date,
                                created_by,
                                last_update_login,
                                transaction_type,
                                transaction_date,
                                processing_status_code,
                                processing_mode_code,
                                transaction_status_code,
                                quantity,
                                -- unit_of_measure,
                                interface_source_code,
                                item_id,
                                employee_id,
                                auto_transact_code,
                                shipment_header_id,
                                shipment_line_id,
                                ship_to_location_id,
                                receipt_source_code,
                                to_organization_id,
                                source_document_code,
                                -- requisition_line_id,
                                -- req_distribution_id,
                                destination_type_code,
                                -- deliver_to_person_id,
                                --location_id,
                                --deliver_to_location_id,
                                subinventory,
                                shipment_num,
                                -- expected_receipt_date,
                                header_interface_id,
                                validation_flag)
                     VALUES (apps.rcv_transactions_interface_s.NEXTVAL -- interface_transaction_id
                                                                      , ln_rcv_group_id --group_id
                                                                                       , l_rec.org_id, SYSDATE --last_update_date
                                                                                                              , ln_created_by --last_updated_by
                                                                                                                             , SYSDATE --creation_date
                                                                                                                                      , ln_created_by --created_by
                                                                                                                                                     , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                                            , lv_trx_type --transaction_type
                                                                                                                                                                                         , --Added as per CCR0006788
                                                                                                                                                                                           SYSDATE --transaction_date
                                                                                                                                                                                                  , --End for CCR0006788
                                                                                                                                                                                                    'PENDING' --processing_status_code
                                                                                                                                                                                                             , 'BATCH' --processing_mode_code
                                                                                                                                                                                                                      , 'PENDING' --transaction_status_code
                                                                                                                                                                                                                                 , l_rec.quantity_shipped - NVL (l_rec.quantity_received, 0) --quantity
                                                                                                                                                                                                                                                                                            , -- p_uom                                    --unit_of_measure
                                                                                                                                                                                                                                                                                              --      ,
                                                                                                                                                                                                                                                                                              'RCV' --interface_source_code
                                                                                                                                                                                                                                                                                                   , l_rec.item_id --item_id
                                                                                                                                                                                                                                                                                                                  , ln_employee_id --employee_id
                                                                                                                                                                                                                                                                                                                                  , 'DELIVER' --auto_transact_code
                                                                                                                                                                                                                                                                                                                                             , l_rec.shipment_header_id --shipment_header_id
                                                                                                                                                                                                                                                                                                                                                                       , l_rec.shipment_line_id --shipment_line_id
                                                                                                                                                                                                                                                                                                                                                                                               , l_rec.deliver_to_location_id --ship_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                             , h_rec.receipt_source_code --receipt_source_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                        , l_rec.receiving_organization_id --to_organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , l_rec.source_document_code --source_document_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     -- l_rec.requisition_line_id            --requisition_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , -- l_rec.requisition_distribution_id    --req_distribution_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       'INVENTORY' --destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , -- l_rec.deliver_to_person_id          --deliver_to_person_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    --                          ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    -- l_rec.location_id                            --location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    --                  ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    --l_rec.deliver_to_location_id      --deliver_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    --                            ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    l_rec.to_subinventory --subinventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , h_rec.shipment_num --shipment_num
                             , -- h_rec.expected_receipt_date       --expected_receipt_date,
                               --                            ,
                               ln_header_interface_id    --header_interface_id
                                                     , 'Y'   --validation_flag
                                                          );

                ln_processed_lines   := ln_processed_lines + 1;
            END LOOP;

            COMMIT;

            --Run RCV Transaction Processor if records posted
            IF ln_processed_lines > 0
            THEN
                run_rcv_transaction_processor (ln_rcv_group_id, 'Y', ln_request_id
                                               , ln_err_stat, ln_err_msg);
                COMMIT;
            END IF;
        END LOOP;

        pv_err_stat   := ln_err_stat;
        pv_err_msg    := ln_err_msg;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
    END;

    PROCEDURE receive_asn (pv_err_stat          OUT VARCHAR2,
                           pv_err_msg           OUT VARCHAR2,
                           pv_shipment_num   IN     VARCHAR2)
    IS
        ln_shipment_header_id   NUMBER;
    BEGIN
        SELECT shipment_header_id
          INTO ln_shipment_header_id
          FROM rcv_shipment_headers
         WHERE shipment_num = pv_shipment_num;

        pv_err_stat   := 'S';
        pv_err_msg    := '';
        receive_asn (pv_err_stat, pv_err_msg, ln_shipment_header_id);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := 'shipment num is invalid';
        WHEN OTHERS
        THEN
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
    END;

    PROCEDURE validate_asn (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_shipment_header_id IN NUMBER)
    IS
        ln_order_number   NUMBER;
        ln_header_id      NUMBER;
        ln_asn_balance    NUMBER;
        ln_asn_item_cnt   NUMBER;
        ln_so_balance     NUMBER;
        ln_so_item_cnt    NUMBER;
        ln_cnt            NUMBER;
    BEGIN
        BEGIN
            --First check if passed in ASN is in Lookup
            SELECT meaning
              INTO ln_order_number
              FROM fnd_lookup_values flv, rcv_shipment_headers rsh
             WHERE     lookup_type = 'XXD_WMS_INTRANSIT_ASN_IR_MAP'
                   AND lookup_code = rsh.shipment_num
                   AND rsh.shipment_header_id = pn_shipment_header_id
                   AND language = 'US'
                   AND enabled_flag = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg    := 'ASN/ISO not in lookup mapping';
                pv_error_stat   := 'E';
                RETURN;
        END;

        --Check for partially received ASN
        BEGIN
            SELECT COUNT (*)
              INTO ln_cnt
              FROM rcv_shipment_lines rsl
             WHERE     rsl.shipment_header_id = pn_shipment_header_id
                   AND rsl.shipment_line_status_code IN
                           ('FULLY RECEIVED', 'PARTIALLY RECEIVED');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg    := 'ASN not found';
                pv_error_stat   := 'E';
                RETURN;
        END;

        IF ln_cnt > 0
        THEN
            pv_error_msg    := 'ASN contains fully/partially received lines';
            pv_error_stat   := 'E';
            RETURN;
        END IF;


        --Validate existince of Future ISO
        BEGIN
            SELECT header_id
              INTO ln_header_id
              FROM oe_order_headers_all
             WHERE order_number = ln_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_msg    := 'Order Number in lookup does not exist';
                pv_error_stat   := 'E';
                RETURN;
        END;

        --Get quantity/line count from ASN
        SELECT SUM (quantity_shipped) - SUM (quantity_received) asn_bal, COUNT (DISTINCT item_id) asn_item_cnt
          INTO ln_asn_balance, ln_asn_item_cnt
          FROM rcv_shipment_lines rsl
         WHERE     rsl.shipment_header_id = pn_shipment_header_id
               AND rsl.shipment_line_status_code IN ('EXPECTED');


        --Get quantity/Line count from SO
        SELECT SUM (ordered_quantity) so_balance, COUNT (DISTINCT inventory_item_id) so_item_count
          INTO ln_so_balance, ln_so_item_cnt
          FROM oe_order_lines_all oola
         WHERE oola.header_id = ln_header_id;

        --Get quantity /line count from ISO


        IF    ln_asn_balance != ln_so_balance
           OR ln_asn_item_cnt != ln_so_item_cnt
        THEN
            pv_error_msg    := 'ASN balance does not match ISO balance';
            pv_error_stat   := 'E';
            RETURN;
        END IF;

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg    := 'Other error occurred : ' || SQLERRM;
            pv_error_stat   := 'E';
    END;

    PROCEDURE update_lookup_record (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pv_shipment_num IN VARCHAR2
                                    , pv_enabled_val IN VARCHAR2)
    IS
        l_lookup_type           VARCHAR2 (250);
        l_lookup_code           VARCHAR2 (250);
        l_enabled_flag          VARCHAR2 (250);
        l_security_group_id     NUMBER;
        l_view_application_id   NUMBER;
        l_tag                   VARCHAR2 (250);
        l_meaning               VARCHAR2 (250);

        CURSOR c1 IS
            SELECT lookup_type, lookup_code, enabled_flag,
                   security_group_id, view_application_id, tag,
                   meaning, description, start_date_active
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'XXD_WMS_INTRANSIT_ASN_IR_MAP'
                   AND lookup_code = pv_shipment_num;
    BEGIN
        IF pv_enabled_val NOT IN ('Y', 'N')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                pv_shipment_num || ' - invalid setting for enabled value';
        END IF;


        FOR i IN c1
        LOOP
            BEGIN
                fnd_lookup_values_pkg.update_row (
                    x_lookup_type           => i.lookup_type,
                    x_security_group_id     => i.security_group_id,
                    x_view_application_id   => i.view_application_id,
                    x_lookup_code           => i.lookup_code,
                    x_tag                   => i.tag,
                    x_attribute_category    => NULL,
                    x_attribute1            => NULL,
                    x_attribute2            => NULL,
                    x_attribute3            => NULL,
                    x_attribute4            => NULL,
                    x_enabled_flag          => pv_enabled_val,
                    x_start_date_active     => i.start_date_active,
                    x_end_date_active       => NULL,
                    x_territory_code        => NULL,
                    x_attribute5            => NULL,
                    x_attribute6            => NULL,
                    x_attribute7            => NULL,
                    x_attribute8            => NULL,
                    x_attribute9            => NULL,
                    x_attribute10           => NULL,
                    x_attribute11           => NULL,
                    x_attribute12           => NULL,
                    x_attribute13           => NULL,
                    x_attribute14           => NULL,
                    x_attribute15           => NULL,
                    x_meaning               => i.meaning,
                    x_description           => i.description,
                    x_last_update_date      => TRUNC (SYSDATE),
                    x_last_updated_by       => gn_user_id,
                    x_last_update_login     => gn_user_id);

                COMMIT;
                pv_error_stat   := 'S';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_stat   := 'E';
                    pv_error_msg    :=
                        pv_shipment_num || ' - Inner Exception - ' || SQLERRM;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                pv_shipment_num || ' - Inner Exception - ' || SQLERRM;
    END;



    PROCEDURE run_process_output (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_shipment_header_id IN NUMBER)
    IS
        CURSOR c_rec IS
            SELECT *
              FROM XXD_WMS_ASN_CONV_REC_STATUS_V
             WHERE shipment_header_id = pn_shipment_header_id;
    BEGIN
        -- Output header cols
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Factory PO#', 15, ' ')
            || RPAD ('Container #', 12, ' ')
            || RPAD ('Intransit ASN #', 15, ' ')
            || RPAD ('Intransit ASN Organzation', 35, ' ')
            || RPAD ('Intransit ASN SKU', 20, ' ')
            || RPAD ('Intransit ASN SKU Qty', 30, ' ')
            || RPAD ('Intransit ASN Ex. Rcpt. Dt.', 35, ' ')
            || RPAD ('Future DC-DC Xfer IR REQ', 35, ' ')
            || RPAD ('Future DC-DC Xfer IR SO', 35, ' ')
            || RPAD ('ASN # in Dest ORG', 35, ' ')
            || RPAD ('ASN Org', 30, ' ')
            || RPAD ('EPO#', 15, ' ')
            || RPAD ('BRAND', 12, ' ')
            || RPAD ('Dest ASN SKU', 20, ' ')
            || RPAD ('Dest ASN Qty', 20, ' ')
            || RPAD ('Status Message', 50, ' ')
            || CHR (13)
            || CHR (10));

        FOR rec IN c_rec
        LOOP
            --output line data
            fnd_file.put_line (
                fnd_file.output,
                   RPAD (rec.po_number, 15, ' ')
                || RPAD (rec.container_num, 12, ' ')
                || RPAD (rec.shipment_num, 15, ' ')
                || RPAD (rec.source_org, 35, ' ')
                || RPAD (rec.in_transit_asn_sku, 20, ' ')
                || RPAD (rec.in_transit_asn_qty, 30, ' ')
                || RPAD (rec.in_transit_asn_exp_rcpt_dt, 35, ' ')
                || RPAD (rec.future_dc_dc_xfer_ir_no, 35, ' ')
                || RPAD (rec.future_dc_dc_xfer_iso_no, 35, ' ')
                || RPAD (rec.future_dc_dc_xfer_asn, 35, ' ')
                || RPAD (rec.destination_organization, 30, ' ')
                || RPAD (rec.pa_number, 15, ' ')
                || RPAD (rec.brand, 12, ' ')
                || RPAD (rec.dest_sku, 20, ' ')
                || RPAD (rec.destination_qty, 20, ' ')
                || RPAD (rec.record_status, 50, ' ')
                || CHR (13)
                || CHR (10));
        END LOOP;

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;

    /**********************************************************
    Public access procedures
    ************************************************************/


    --Main call for process
    PROCEDURE Process_intr_asn (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_shipment_header_id IN NUMBER)
    IS
        lv_error_stat                 VARCHAR2 (10);
        lv_error_msg                  VARCHAR2 (2000);

        ln_ir_org_id                  NUMBER;
        lv_shipment_number            VARCHAR2 (40);
        lv_so_number                  VARCHAR2 (40);
        ln_ir_srv_inv_org             NUMBER;
        ln_ir_dest_inv_org            NUMBER;
        lv_ir_interface_source_code   VARCHAR2 (50);
        ln_req_header_id              NUMBER;
        ln_delivery_id                NUMBER;
        ln_atp_cnt                    NUMBER;

        ln_so_header_id               NUMBER;
        ln_so_order_number            NUMBER;
        ln_so_org_id                  NUMBER;
        ln_so_organization_id         NUMBER;

        ln_unschedule_cnt             NUMBER;
        ln_booked_cnt                 NUMBER;

        ln_count                      NUMBER;

        exProcessError                EXCEPTION;
    BEGIN
        insert_message ('BOTH', 'Procedure Enter');
        insert_message ('BOTH', 'Validate');

        --Do ASN validation
        validate_asn (pv_error_stat           => lv_error_stat,
                      pv_error_msg            => lv_error_msg,
                      pn_shipment_header_id   => pn_shipment_header_id);

        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Validation failed : ' || lv_error_msg;
            RETURN;
        END IF;


        --Purchasing user tasks
        insert_message ('BOTH', 'Receive');


        --Receive ASN
        receive_asn (pv_err_stat             => lv_error_stat,
                     pv_err_msg              => lv_error_msg,
                     pn_shipment_header_id   => pn_shipment_header_id);


        IF pv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Receive failed : ' || lv_error_msg;
            RAISE exProcessError;
        END IF;

        ---Check for records in RTI
        SELECT COUNT (*)
          INTO ln_count
          FROM rcv_transactions_interface
         WHERE shipment_header_id = pn_shipment_header_id;

        IF ln_count > 0
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Records for ASN receipt are stuck in interface';
            RAISE exProcessError;
        END IF;


        --Get linked SO via Lookup
        --Assumption this will succeed as this is checked in validation step
        SELECT flv.meaning, flv.lookup_code
          INTO lv_so_number, lv_shipment_number
          FROM fnd_lookup_values flv, rcv_shipment_headers rsh
         WHERE     flv.lookup_type = 'XXD_WMS_INTRANSIT_ASN_IR_MAP'
               AND flv.lookup_code = rsh.shipment_num
               AND rsh.shipment_header_id = pn_shipment_header_id
               AND flv.language = 'US'
               AND flv.enabled_flag = 'Y';

        BEGIN
            --Get SO information from REQ
            SELECT DISTINCT ooha.header_id, ooha.order_number, ooha.org_id,
                            oola.ship_from_org_id
              INTO ln_so_header_id, ln_so_order_number, ln_so_org_id, ln_so_organization_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     ooha.header_id = oola.header_id
                   AND ooha.order_number = TO_NUMBER (lv_so_number);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Internal SO does not exist';
                RAISE exProcessError;
        END;

        --Set override ATP Date Code
        insert_message ('BOTH', 'Relieve ATP');
        relieve_atp (pv_error_stat     => lv_error_stat,
                     pv_error_msg      => lv_error_msg,
                     pn_order_number   => ln_so_order_number);

        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Relieve ATP failed : ' || lv_error_msg;
            RAISE exProcessError;
        END IF;

        SELECT COUNT (*)
          INTO ln_atp_cnt
          FROM oe_order_headers_all ooha, oe_order_lines_all oola
         WHERE     oola.header_id = ooha.header_id
               AND order_number = ln_so_order_number
               AND NVL (Override_atp_date_code, 'N') = 'Y';

        insert_message (
            'BOTH',
               'Count of records with Override_atp_date_code = Y: '
            || ln_atp_cnt);


        --Check for unscheduled lines and schedule
        SELECT COUNT (1)
          INTO ln_unschedule_cnt
          FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
         WHERE     ooha.order_number = ln_so_order_number
               AND ooha.header_id = oola.header_id
               AND (schedule_ship_date IS NULL OR schedule_status_code IS NULL)
               AND NVL (oola.open_flag, 'N') = 'Y'
               AND NVL (oola.cancelled_flag, 'N') = 'N'
               AND oola.line_category_code = 'ORDER'
               AND oola.flow_status_code IN ('BOOKED', 'AWAITING_SHIPPING');

        insert_message ('BOTH', 'Count unscheduled ' || ln_unschedule_cnt);

        IF ln_unschedule_cnt > 0
        THEN
            insert_message ('BOTH', 'Run schedule orders');
            --Schedule order
            -- 'Deckers Order Management Manager - US'
            schedule_order (pv_error_stat     => lv_error_stat,
                            pv_error_msg      => lv_error_msg,
                            pn_order_number   => ln_so_order_number);
        END IF;

        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := ' Schedule orders failed : ' || lv_error_msg;
            RAISE exProcessError;
        END IF;

        --Check for lines in booked status
        SELECT SUM (DECODE (oola.flow_status_code, 'BOOKED', 1, 0))
          INTO ln_booked_cnt
          FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
         WHERE     ooha.order_number = ln_so_order_number
               AND ooha.header_id = oola.header_id
               AND NVL (oola.open_flag, 'N') = 'Y'
               AND NVL (oola.cancelled_flag, 'N') = 'N'
               AND oola.line_category_code = 'ORDER'
               AND oola.flow_status_code IN ('BOOKED', 'AWAITING_SHIPPING');

        insert_message ('BOTH', 'Count booked ' || ln_booked_cnt);


        --Progress BOOKED lines to AWAITING_SHIPPING
        IF ln_booked_cnt > 0
        THEN
            insert_message ('BOTH', 'Run OM Schedule orders');
            run_om_schedule_orders (pv_error_stat     => lv_error_stat,
                                    pv_error_msg      => lv_error_msg,
                                    pn_order_number   => ln_so_order_number);


            IF lv_error_stat != 'S'
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    :=
                    'Run OM Schedule orders : ' || lv_error_msg;
                RAISE exProcessError;
            END IF;
        END IF;

        insert_message ('BOTH', 'Reprice Order');

        --Reprice SO
        /*     reprice_sales_order (pv_error_stat     => lv_error_stat,
                                  pv_error_msg      => lv_error_msg,
                                  pn_order_number   => ln_so_order_number);

             IF lv_error_stat != 'S'
             THEN
                -- pv_error_stat := 'E';
                pv_error_msg := 'reprice sales order failed : ' || lv_error_msg;
             END IF;*/

        --Shipping user tasks

        --Set shipping responsibility
        SELECT responsibility_id, application_id
          INTO gn_resp_id, gn_resp_appl_id
          FROM fnd_responsibility_vl
         WHERE responsibility_name = 'Order Management Super User';

        do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);

        insert_message ('BOTH', 'Release Order');
        --Pick Release order
        pick_release_order (pv_error_stat     => lv_error_stat,
                            pv_error_msg      => lv_error_msg,
                            pn_order_number   => ln_so_order_number);

        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'pick release failed : ' || lv_error_msg;
            RAISE exProcessError;
        END IF;

        BEGIN
            --Get confirmed delivery/Assumption that 1 delivery is created
            SELECT DISTINCT wnd.delivery_id
              INTO ln_delivery_id
              FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
             WHERE     wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_header_id = ln_so_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'No delivery created';
                RAISE exProcessError;
        END;

        insert_message ('BOTH', 'Delivery Created : ' || ln_delivery_id);

        --Set shipping user for ship confirm
        BEGIN
            SELECT responsibility_id, application_id
              INTO gn_resp_id, gn_resp_appl_id
              FROM fnd_responsibility_vl
             WHERE responsibility_name = 'Deckers WMS Shipping User';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;                              --Use active responsibility
        END;

        do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);

        insert_message ('BOTH', 'Confirm Delivery');

        --Ship confirm
        ship_confirm_delivery (pv_error_stat    => lv_error_stat,
                               pv_error_msg     => lv_error_msg,
                               pn_delivery_id   => ln_delivery_id);


        IF lv_error_stat != 'S'
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'ship confirm failed : ' || lv_error_msg;
            RAISE exProcessError;
        END IF;

        insert_message ('BOTH', 'Run output report');
        --Run output report
        run_process_output (pv_error_stat           => lv_error_stat,
                            pv_error_msg            => lv_error_msg,
                            pn_shipment_header_id   => pn_shipment_header_id);



        --Update the lookup disabling the mapping as this is now complete
        update_lookup_record (pv_error_stat => lv_error_stat, pv_error_msg => lv_error_msg, pv_shipment_num => lv_shipment_number
                              , pv_enabled_val => 'N');

        insert_message ('BOTH', 'Procedure end');
        pv_error_stat   := 'S';
    EXCEPTION
        WHEN exProcessError
        THEN
            --process error occurred. run report to show status

            run_process_output (
                pv_error_stat           => lv_error_stat,
                pv_error_msg            => lv_error_msg,
                pn_shipment_header_id   => pn_shipment_header_id);
        WHEN OTHERS
        THEN
            insert_message ('BOTH', 'Error');
            pv_error_stat   := 'E';
            pv_error_msg    := SQLERRM;
    END;
END XXD_WMS_ASN_INTR_CONV_PKG;
/
