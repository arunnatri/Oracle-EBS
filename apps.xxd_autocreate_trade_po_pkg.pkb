--
-- XXD_AUTOCREATE_TRADE_PO_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AUTOCREATE_TRADE_PO_PKG"
AS
    /*******************************************************************************
     * Program Name : XXD_AUTOCREATE_TRADE_PO_PKG
     * Language     : PL/SQL
     * Description  : This package will autocreate PO from TRADE requisitions ONLY1
     * History      :
     *    WHO                WHAT                                Desc                                          WHEN
     * --------------     ---------------            -------------------------------                      ---------------
     * Infosys               1.0                    New Program to Process Trade Requisitions.               12-Mar-2018
     *                                              Modified for CCR0006820. IDENTIFIED by CCR0006820
     * Infosys               1.1                    Modified for Sequential ordering of SKUs                 12-Mar-2018
     *                                              Changes IDENTIFIED by CCR0007099
     * Infosys               1.2                    Modified to populate Freight Pay Party for               20-Mar-2018
     *                                              Distributor Sales Order
     *                                              Changes IDENTIFIED by CCR0007114
     * Infosys               1.3                    Modified for One PO for one Distributor Sales Order       20-Mar-2018
     *                                              Changes IDENTIFIED by CCR0007154
     * GJensen               1.4                    Modified for US Direct Ship CCR0007687                   7-Jan-2018
     * GJensen               1.5                    Modified for Macau CCR0007979                            8-Aug-2019
     * GJensen               1.6                    Modified for CCR0008186                                  1-Nov-2019
     * Tejaswi Gangumalla    1.7                    Modified for CCR0008787                                  24-Sep-2020
     * GJensen               1.8                    Modified for CCR0009016                                  23-Nov-2020
     * --------------------------------------------------------------------------- */
    gv_mo_profile_option_name   CONSTANT VARCHAR2 (240)
                                             := 'MO: Security Profile' ;
    gv_responsibility_name      CONSTANT VARCHAR2 (240)
                                             := 'Deckers Purchasing User' ;

    gLookupPOApprovalStatus     CONSTANT NUMBER := 1005639;
    gLookupPOType               CONSTANT NUMBER := 1016638;

    gPOTypeTrade                CONSTANT VARCHAR2 (10) := 'Trade';

    gBatchP2P_User              CONSTANT VARCHAR2 (20) := 'BATCH.P2P';

    --Begin CCR0007687
    FUNCTION GET_PO_TYPE (pn_req_header_id IN NUMBER, pv_drop_ship_flag IN VARCHAR2, pv_hrorg IN VARCHAR2
                          , pv_item_type IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_cnt            NUMBER;
        lv_direct_ship   VARCHAR2 (1);
    BEGIN
        --Check drop ship type REQs

        IF NVL (pv_drop_ship_flag, 'N') = 'Y'
        THEN
            IF pv_hrorg = 'Deckers US OU'
            THEN
                RETURN 'SFS';
            ELSIF pv_hrorg = 'Deckers Macau OU'
            THEN
                RETURN 'SFS';
            ELSE
                RETURN 'UNKNOWNDS';
            END IF;
        END IF;

        --Check for non STD PO typee
        IF pv_item_type LIKE 'SAMPLE%'
        THEN
            RETURN 'SAMPLE';
        END IF;

        IF pv_item_type LIKE 'B%GRADE'
        THEN
            RETURN 'B-GRADE';
        END IF;

        --Check for US Direct ship
        BEGIN
            SELECT DISTINCT flv.attribute1 direct_ship
              INTO lv_direct_ship
              FROM fnd_lookup_values flv, po_requisition_lines_all prla
             WHERE     lookup_type = 'XXD_PO_B2B_ORGANIZATIONS'
                   AND enabled_flag = 'Y'
                   AND flv.lookup_code =
                       TO_CHAR (prla.destination_organization_id)
                   AND prla.requisition_header_id = pn_req_header_id
                   AND language = 'US';

            IF lv_direct_ship = 'Y'
            THEN
                RETURN 'DIRECT_SHIP';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        RETURN 'STANDARD';
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'ERR';
    END;

    --End CCR0007687

    --Return the buy month as the current Month-Year
    --Input:     NONE
    --Output:    (Varchar2 - Buy Month)
    --
    FUNCTION GET_BUY_MONTH
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN    UPPER (TO_CHAR (SYSDATE, 'Mon'))
               || ' '
               || EXTRACT (YEAR FROM SYSDATE);
    END;

    --Return Buy season based on the current month
    --Inout:     None
    --Output (Varchar2 - Buy season)
    --
    FUNCTION GET_BUY_SEASON
        RETURN VARCHAR2
    IS
        V_BUY_MONTH    VARCHAR2 (20) := Get_Buy_Month;
        V_BUY_SEASON   VARCHAR2 (20);
    BEGIN
        SELECT FFV.ATTRIBUTE1
          INTO V_BUY_SEASON
          FROM FND_FLEX_VALUES FFV, FND_FLEX_VALUE_SETS FFVS
         WHERE     FFVS.FLEX_VALUE_SET_ID = FFV.FLEX_VALUE_SET_ID
               AND FFVS.FLEX_VALUE_SET_NAME = 'DO_BUY_MONTH_YEAR'
               AND VALUE_CATEGORY = 'DO_BUY_MONTH_YEAR'
               AND FFV.FLEX_VALUE = V_BUY_MONTH;

        RETURN V_BUY_SEASON;
    END;

    --Calculate the PCard ID
    FUNCTION GET_PCARD_ID (P_PCARD_FLAG IN VARCHAR2, P_PCARD_ID IN NUMBER, P_VENDOR_ID NUMBER
                           , P_VENDOR_SITE_ID NUMBER)
        RETURN NUMBER
    IS
        N_PCARD_ID   NUMBER;
    BEGIN
        IF P_PCARD_FLAG = 'Y'
        THEN
            N_PCARD_ID   := P_PCARD_ID;
        ELSIF P_PCARD_FLAG = 'S'
        THEN
            N_PCARD_ID   :=
                NVL (
                    (PO_PCARD_PKG.GET_VALID_PCARD_ID (-99999, P_VENDOR_ID, P_VENDOR_SITE_ID)),
                    -99999);
        ELSE
            N_PCARD_ID   := NULL;
        END IF;

        RETURN N_PCARD_ID;
    END;

    ---Vheck if a value is in the designated value set
    --Input: pn_value_set_id - Value Set Identifier
    --       pv_value_set_value - Value set value
    FUNCTION CHECK_FOR_VALUE_SET_VALUE (pn_value_set_id      IN NUMBER,
                                        pv_value_set_value   IN VARCHAR)
        RETURN BOOLEAN
    IS
        ln_cnt   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO ln_cnt
          FROM FND_FLEX_VALUES
         WHERE     flex_value_set_id = pn_value_set_id
               AND flex_value = pv_value_set_value;


        IF ln_cnt > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END;

    --Get ship method based on vendor/site and desination
    --Input  p_vendor_id          -Source vendor site
    --       p_vendor_site_id     -Source vendor site code
    --       p_drop_ship_flag     -REQ drop ship flag
    --       p_dest_country       -Destination country
    --Output:    (Varchar2 - Ship Method for transit)
    FUNCTION GET_SHIP_METHOD (P_VENDOR_ID IN NUMBER, P_VENDOR_SITE_CODE IN VARCHAR2, P_PO_TYPE IN VARCHAR2
                              , P_DEST_COUNTRY IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_territory_short_name    VARCHAR2 (50);
        v_preferred_ship_method   VARCHAR2 (20);
    BEGIN
        IF P_PO_TYPE LIKE 'SAMPLE%'
        THEN
            RETURN 'Air';
        ELSE
            BEGIN
                --Get the territory short name from the territories lookup
                SELECT territory_short_name
                  INTO v_territory_short_name
                  FROM fnd_territories_vl
                 WHERE territory_code = P_DEST_COUNTRY;

                --Set the ship method based on the po type and drop ship flag
                SELECT flv.attribute8
                  INTO v_preferred_ship_method
                  FROM FND_LOOKUP_VALUES FLV
                 WHERE     FLV.LANGUAGE = 'US'
                       AND FLV.LOOKUP_TYPE = 'XXDO_SUPPLIER_INTRANSIT'
                       AND FLV.ATTRIBUTE1 = TO_CHAR (p_vendor_id)
                       AND FLV.ATTRIBUTE2 = p_vendor_site_code
                       AND FLV.ATTRIBUTE4 = v_territory_short_name
                       AND SYSDATE BETWEEN flv.start_date_active
                                       AND NVL (flv.end_date_active,
                                                SYSDATE + 1);

                RETURN NVL (v_preferred_ship_method, 'Ocean');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    RETURN 'Ocean';
                WHEN OTHERS
                THEN
                    RETURN 'Ocean';
            END;
        END IF;
    END;

    --Get the transit time based on the source vendor/site and destination country
    --Input  p_vendor_id          -Source vendor site
    --       p_vendor_site_id     -Source vendor site code
    --       p_drop_ship_flag     -REQ drop ship flag
    --       p_dest_country       -Destination country
    --Output:    (Number - Number of transit days)
    FUNCTION GET_TRANSIT_TIME (P_VENDOR_ID          IN NUMBER,
                               P_VENDOR_SITE_CODE   IN VARCHAR2,
                               P_DROP_SHIP_FLAG     IN VARCHAR2,
                               P_PO_TYPE            IN VARCHAR2, --2/10/17 Added to pass to get_ship_method
                               P_DEST_COUNTRY       IN VARCHAR2)
        RETURN NUMBER
    IS
        v_territory_short_name    VARCHAR2 (50);
        v_days_air                VARCHAR2 (5);
        v_days_ocean              VARCHAR2 (5);
        v_days_truck              VARCHAR2 (5);
        v_preferred_ship_method   VARCHAR2 (20);
        v_tq_po_exists            VARCHAR2 (20);
    BEGIN
        BEGIN
            --Get the territory short name from the territories lookup
            SELECT territory_short_name
              INTO v_territory_short_name
              FROM fnd_territories_vl
             WHERE territory_code = P_DEST_COUNTRY;


            --Get the transit times  from the transit matrix lookup
            SELECT FLV.ATTRIBUTE5, FLV.attribute6, FLV.attribute7,
                   flv.attribute8
              INTO v_days_air, v_days_ocean, v_days_truck, v_preferred_ship_method
              FROM FND_LOOKUP_VALUES FLV
             WHERE     FLV.LANGUAGE = 'US'
                   AND FLV.LOOKUP_TYPE = 'XXDO_SUPPLIER_INTRANSIT'
                   AND FLV.ATTRIBUTE1 = TO_CHAR (p_vendor_id)
                   AND FLV.ATTRIBUTE2 = p_vendor_site_code
                   -- AND FLV.ATTRIBUTE3 = mp.organization_code
                   AND FLV.ATTRIBUTE4 = v_territory_short_name
                   AND SYSDATE BETWEEN flv.start_date_active
                                   AND NVL (flv.end_date_active, SYSDATE + 1);

            --If Preferred ship method not set, get preferred ship method
            --NOTE: Do we want to call this to run the above query basically a second time or just default for samples here?
            IF v_preferred_ship_method IS NULL
            THEN
                v_preferred_ship_method   :=
                    get_ship_method (P_VENDOR_ID, P_VENDOR_SITE_CODE, P_PO_TYPE
                                     , P_DEST_COUNTRY);
            END IF;

            --Set the transit days based on the po type and drop ship flag
            IF p_drop_ship_flag = 'Y'
            THEN
                RETURN 0;
            ELSE
                IF v_preferred_ship_method = 'Air'
                THEN
                    RETURN TO_NUMBER (v_days_air);
                ELSIF v_preferred_ship_method = 'Truck'
                THEN
                    RETURN TO_NUMBER (v_days_truck);
                ELSE
                    RETURN TO_NUMBER (v_days_ocean);
                END IF;
            END IF;

            RETURN 0;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN 0;
            WHEN OTHERS
            THEN
                RETURN 0;
        END;
    END;

    --Show PO lines created from requisition lines based on the batch ID passed
    --Input: p_batch_id - Batch to process
    PROCEDURE SHOW_BATCH_PO_DATA (p_batch_id IN NUMBER)
    IS
        CURSOR cur_po_headers IS
              SELECT poh.segment1 po_num, prha.segment1 requisition_num, prla.line_num requisition_line_num
                FROM po_headers_all poh, po_headers_interface phi, po_requisition_headers_all prha,
                     po_requisition_lines_all prla, po_distributions_all pda, po_req_distributions_all prda
               WHERE     phi.batch_id = p_batch_id
                     AND phi.po_header_id = poh.po_header_id
                     AND pda.po_header_id = poh.po_header_id
                     AND pda.req_distribution_id = prda.distribution_id
                     AND prda.requisition_line_id = prla.requisition_line_id
                     AND prla.requisition_header_id =
                         prha.requisition_header_id
            ORDER BY poh.segment1, prha.segment1, prla.line_num;
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, '--Show batch PO Data : Enter');

        FOR rec IN cur_po_headers
        LOOP
            fnd_file.PUT_LINE (
                fnd_file.output,
                   'Requisition # '
                || rec.requisition_num
                || ' Requisition Line Num '
                || rec.requisition_line_num
                || ' PO # '
                || rec.po_num
                || CHR (10));
        END LOOP;

        fnd_file.PUT_LINE (fnd_file.LOG, '--Show batch PO Data : Exit');
    END;

    --Log any POI errors generated for the passed in batch
    --Input: p_batch_id - Batch to process
    PROCEDURE SHOW_BATCH_POI_ERRORS (p_batch_id IN NUMBER)
    IS
        CURSOR cur_po_errors IS
            SELECT DISTINCT error_message
              FROM (SELECT 'Requisition#: ' || prha.segment1 || '|Requisition line num:' || prla.line_num || '| error_message: ' || poie.error_message || '|Grouped invalid column name and value: ' || poie.column_name || poie.COLUMN_VALUE AS error_message
                      FROM po_interface_errors poie, po_headers_interface phi, po_lines_interface pli,
                           PO_REQUISITION_HEADERS_ALL PRHA, PO_REQUISITION_LINES_ALL PRlA
                     WHERE     poie.batch_id = p_batch_id
                           AND poie.batch_id = phi.batch_id
                           AND poie.interface_type = 'PO_DOCS_OPEN_INTERFACE'
                           AND phi.interface_header_id =
                               poie.interface_header_id
                           AND phi.interface_header_id =
                               pli.interface_header_id(+)
                           AND PLI.REQUISITION_LINE_ID =
                               PRLA.REQUISITION_LINE_ID
                           AND PRLA.REQUISITION_HEADER_ID =
                               PRHA.REQUISITION_HEADER_ID);
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, '--Show POI Errors : Enter');

        FOR rec IN cur_po_errors
        LOOP
            fnd_file.PUT_LINE (fnd_file.LOG, rec.error_message || CHR (10));
        END LOOP;

        fnd_file.PUT_LINE (fnd_file.LOG, '--Show POI Errors : Exit');
    END;

    --Update PO/Requisition data in the drop ship sources table and the po information in the requisition lines
    --table for all records in the given batch
    --Input: p_batch_id - Batch to process
    PROCEDURE UPDATE_DROP_SHIP (p_batch_id IN NUMBER)
    IS
        CURSOR CUR_UPDATE_DROP_SHIP IS
            SELECT DISTINCT PHI.PO_HEADER_ID, PLI.PO_LINE_ID, PLLI.LINE_LOCATION_ID,
                            PORH.REQUISITION_HEADER_ID, PORL.REQUISITION_LINE_ID
              FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL, PO_LINE_LOCATIONS_INTERFACE PLLI,
                   PO_LINES_INTERFACE PLI, PO_HEADERS_INTERFACE PHI, PO_HEADERS_ALL POH,
                   OE_DROP_SHIP_SOURCES OEDSS
             WHERE     PORH.REQUISITION_HEADER_ID =
                       PORL.REQUISITION_HEADER_ID
                   AND OEDSS.REQUISITION_LINE_ID = PORL.REQUISITION_LINE_ID
                   AND PORL.LINE_LOCATION_ID = PLLI.LINE_LOCATION_ID
                   AND PLLI.INTERFACE_LINE_ID = PLI.INTERFACE_LINE_ID
                   AND PLI.INTERFACE_HEADER_ID = PHI.INTERFACE_HEADER_ID
                   AND PHI.PO_HEADER_ID = POH.PO_HEADER_ID
                   AND PHI.BATCH_ID = P_BATCH_ID;

        v_dropship_return_status   VARCHAR2 (50);
        v_dropship_Msg_Count       VARCHAR2 (50);
        v_dropship_Msg_data        VARCHAR2 (50);
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, '--Update Drop Ship : Enter');

        FOR CUR_UPDATE_DROP_SHIP_REC IN CUR_UPDATE_DROP_SHIP
        LOOP
            BEGIN
                APPS.OE_DROP_SHIP_GRP.Update_PO_Info (
                    p_api_version     => 1.0,
                    P_Return_Status   => v_dropship_return_status,
                    P_Msg_Count       => v_dropship_Msg_Count,
                    P_MSG_Data        => v_dropship_MSG_Data,
                    P_Req_Header_ID   =>
                        cur_update_drop_ship_rec.requisition_header_id,
                    P_Req_Line_ID     =>
                        cur_update_drop_ship_rec.requisition_line_id,
                    P_PO_Header_Id    => cur_update_drop_ship_rec.PO_HEADER_ID,
                    P_PO_Line_Id      => cur_update_drop_ship_rec.PO_LINE_ID,
                    P_Line_Location_ID   =>
                        cur_update_drop_ship_rec.LINE_LOCATION_ID);

                IF (v_dropship_return_status = FND_API.g_ret_sts_success)
                THEN
                    fnd_file.PUT_LINE (fnd_file.LOG,
                                       'drop ship successs' || CHR (10));


                    UPDATE PO_LINE_LOCATIONS_ALL PLLA
                       SET SHIP_TO_LOCATION_ID   =
                               (SELECT DISTINCT PORL.DELIVER_TO_LOCATION_ID
                                  FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL
                                 WHERE     PORH.REQUISITION_HEADER_ID =
                                           PORL.REQUISITION_HEADER_ID
                                       AND PLLA.LINE_LOCATION_ID =
                                           PORL.LINE_LOCATION_ID
                                       AND PORL.LINE_LOCATION_ID =
                                           CUR_UPDATE_DROP_SHIP_REC.LINE_LOCATION_ID)
                     WHERE PLLA.LINE_LOCATION_ID =
                           CUR_UPDATE_DROP_SHIP_REC.LINE_LOCATION_ID;

                    COMMIT;
                ELSIF v_dropship_return_status = (FND_API.G_RET_STS_ERROR)
                THEN
                    FOR i IN 1 .. FND_MSG_PUB.count_msg
                    LOOP
                        fnd_file.PUT_LINE (
                            fnd_file.LOG,
                            'DROP SHIP api ERROR:' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
                    END LOOP;
                ELSIF v_dropship_return_status =
                      FND_API.G_RET_STS_UNEXP_ERROR
                THEN
                    FOR i IN 1 .. FND_MSG_PUB.count_msg
                    LOOP
                        fnd_file.PUT_LINE (
                            fnd_file.LOG,
                            'DROP SHIP UNEXPECTED ERROR:' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
                    END LOOP;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.PUT_LINE (fnd_file.LOG, 'drop ship when others');
            END;
        END LOOP;

        fnd_file.PUT_LINE (fnd_file.LOG, '--Update Drop Ship : Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.PUT_LINE (fnd_file.LOG,
                               '--Update Drop Ship : Exception ' || SQLERRM);
    END;

    --Set the purchasing context
    --Input:     pn_user_ud -User to log in as
    --           pn_org_id  -Org ID to use
    --Output:    pv_error_stat -Error status (E,U,S)
    --           pv_error msg - error message
    PROCEDURE SET_PURCHASING_CONTEXT (pn_user_id NUMBER, pn_org_id NUMBER, pv_error_stat OUT VARCHAR2
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
                       gv_mo_profile_option_name      --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_id NOT IN (51395, 51398)      --TEMP
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name || '%' --'Deckers Purchasing User%'
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

        fnd_file.PUT_LINE (fnd_file.LOG, 'Context Info before');
        fnd_file.PUT_LINE (fnd_file.LOG,
                           'Curr ORG: ' || apps.mo_global.get_current_org_id);
        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'Multi Org Enabled: ' || apps.mo_global.is_multi_org_enabled);

        --do intialize and purchssing setup
        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        /* old way
       apps.mo_global.init ('PO');
       --   apps.mo_global.Set_org_context (pn_org_id, NULL, 'PO');
       apps.mo_global.set_policy_context ('S', pn_org_id);
       */

        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', pn_org_id);
        FND_REQUEST.SET_ORG_ID (pn_org_id);

        fnd_file.PUT_LINE (fnd_file.LOG, 'Context Info after');
        fnd_file.PUT_LINE (fnd_file.LOG,
                           'Curr ORG: ' || apps.mo_global.get_current_org_id);
        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'Multi Org Enabled: ' || apps.mo_global.is_multi_org_enabled);

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_get_resp_id
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Error getting resp_id : ' || SQLERRM;
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
    END;

    --Run standard PO import to create a PO from posted PO interface records
    --Input:     pn_batch_id -   batch to process
    --           pn_org_id -     org_id to process
    --           pn_user_id      User_id for process
    --           pv_status-      imported REQ status
    --Output:    pn_request_id    Request ID of REQ import process
    --           pv_error_stat -Error status (E,U,S)
    --           pv_error msg - error message
    PROCEDURE RUN_STD_PO_IMPORT (pn_batch_id IN NUMBER, pn_org_id IN NUMBER, pn_user_id IN NUMBER, pv_status IN VARCHAR2:= 'APPROVED', pn_request_id OUT NUMBER, pv_error_stat OUT VARCHAR2
                                 , pv_error_msg OUT VARCHAR2)
    IS
        l_phase          VARCHAR2 (80);
        l_req_status     BOOLEAN;
        l_status         VARCHAR2 (80);
        l_dev_phase      VARCHAR2 (80);
        l_dev_status     VARCHAR2 (80);
        l_message        VARCHAR2 (255);
        l_data           VARCHAR2 (200);

        ln_user_id       NUMBER;

        ln_req_status    BOOLEAN;

        x_ret_stat       VARCHAR2 (1);
        x_error_text     VARCHAR2 (20000);
        ln_employee_id   NUMBER;
        ln_def_user_id   NUMBER;

        ex_login         EXCEPTION;
    BEGIN
        pn_request_id   := -1;
        fnd_file.PUT_LINE (fnd_file.LOG, 'run_std_po_import - Enter');
        fnd_file.PUT_LINE (fnd_file.LOG, 'Batch ID : ' || pn_batch_id);

        --If user ID not passed, pull defalt user for this type of transaction
        SELECT user_id
          INTO ln_def_user_id
          FROM fnd_user
         WHERE user_name = gBatchP2P_User;

        --Check pased in user
        BEGIN
            SELECT employee_id
              INTO ln_employee_id
              FROM fnd_user
             WHERE user_id = pn_user_id;

            fnd_file.PUT_LINE (fnd_file.LOG,
                               'Emloyee ID : ' || ln_employee_id);

            IF ln_employee_id IS NULL
            THEN
                ln_user_id   := ln_def_user_id;
            ELSE
                ln_user_id   := pn_user_id;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_user_id   := ln_def_user_id;
        END;


        fnd_file.PUT_LINE (fnd_file.LOG, 'before set_purchasing_context');
        fnd_file.PUT_LINE (fnd_file.LOG, '     USER_ID : ' || ln_user_id);
        fnd_file.PUT_LINE (fnd_file.LOG, '     ORG_ID : ' || pn_org_id);

        set_purchasing_context (ln_user_id, pn_org_id, pv_error_stat,
                                pv_error_msg);

        IF pv_error_stat <> 'S'
        THEN
            RAISE ex_login;
        END IF;

        pn_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'PO',
                program       => 'POXPOPDOI',
                argument1     => '',                                --buyer_id
                argument2     => 'STANDARD',                   --Document type
                argument3     => '',                        --Document subtype
                argument4     => 'N',                           --Create Items
                argument5     => '',              --create sourcing rules flag
                argument6     => pv_status,                  --approval status
                argument7     => '',                          --rel_gen_method
                argument8     => TO_CHAR (pn_batch_id),             --batch_id
                argument9     => TO_CHAR (pn_org_id),                 --org_id
                argument10    => '',                                 --ga_flag
                argument11    => '',                   --enable_sourcing_level
                argument12    => '',                          --sourcing_level
                argument13    => '');                         --inv_org_enable
        fnd_file.PUT_LINE (fnd_file.LOG, pn_request_id);

        COMMIT;
        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'poxpopdoi - wait for request - Request ID :' || pn_request_id);
        ln_req_status   :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => pn_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);


        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'poxpopdoi - after wait for request -  ' || l_dev_status);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text    :=
                NVL (
                    l_message,
                       'The poxpopdoi request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
            pv_error_stat   := x_ret_stat;
            pv_error_msg    := x_error_text;
        ELSE
            x_ret_stat   := 'S';
        END IF;

        fnd_file.PUT_LINE (fnd_file.LOG, 'run_std_po_import - Exit');
    EXCEPTION
        WHEN ex_login
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Unable to set purchasing context';
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    :=
                'Unexpected error occurred in run_std_po_import.' || SQLERRM;
    END;

    --Approve a set of POs by batch ID
    --Input     p_batch_id      Batch ID to process
    --          p_po_status     Status to set POs
    --Output    p_errbuf        Error code
    --          p_retcode       Return code
    PROCEDURE XXD_APPROVE_PO (p_batch_id IN NUMBER, P_PO_STATUS IN VARCHAR2, P_ERRBUF OUT VARCHAR2
                              , P_RETCODE OUT NUMBER)
    IS
        v_resp_appl_id    NUMBER;
        v_resp_id         NUMBER;
        v_user_id         NUMBER;
        l_result          NUMBER;
        V_LINE_NUM        NUMBER;
        V_SHIPMENT_NUM    NUMBER;
        V_REVISION_NUM    NUMBER;
        l_api_errors      PO_API_ERRORS_REC_TYPE;

        CURSOR cur_po_appr IS
            SELECT poh.segment1 po_num, poh.po_header_id, poh.org_id,
                   poh.agent_id, poh.wf_item_key
              FROM po_headers_all poh, po_headers_interface phi
             WHERE     batch_id = p_batch_id
                   AND phi.po_header_id = poh.po_header_id
            MINUS
            SELECT DISTINCT poh.segment1 po_num, poh.po_header_id, poh.org_id,
                            poh.agent_id, poh.wf_item_key
              FROM po_headers_all poh, po_headers_interface phi, po_lines_interface plit,
                   po_requisition_headers_all prha, po_requisition_lines_all prla, po_distributions_all pda,
                   po_line_locations_all plla, PO_LINES_ALL pla, po_req_distributions_all prda,
                   po_document_types_all pdt
             WHERE     phi.batch_id = p_batch_id
                   AND phi.po_header_id = poh.po_header_id
                   AND plit.interface_header_id = phi.interface_header_id
                   AND plit.PO_LINE_ID = pla.PO_LINE_ID
                   AND prla.need_by_date != plla.need_by_date
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
                   AND pdt.document_type_code = 'PO';

        cur_po_appr_rec   cur_po_appr%ROWTYPE;
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, '--Approve PO : Enter');

        IF UPPER (P_PO_STATUS) = 'APPROVED'
        THEN
            OPEN cur_po_appr;

            LOOP
                FETCH cur_po_appr INTO cur_po_appr_rec;

                EXIT WHEN cur_po_appr%NOTFOUND;
                fnd_file.PUT_LINE (fnd_file.LOG, 'PO to approve');
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    '--PO Number : ' || cur_po_appr_rec.po_num);
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    '--Agent ID : ' || cur_po_appr_rec.agent_id);

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
                    DocumentTypeCode         => 'PO'                    --'PO'
                                                    ,
                    DocumentSubtype          => 'STANDARD'        --'STANDARD'
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
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    'wf approval success: ' || cur_po_appr_rec.po_num);
            END LOOP;

            CLOSE cur_po_appr;
        END IF;

        fnd_file.PUT_LINE (fnd_file.LOG, '--Approve PO : Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_po_appr%ISOPEN
            THEN
                CLOSE cur_po_appr;
            END IF;

            P_RETCODE   := 1;
            P_ERRBUF    := P_ERRBUF || SQLERRM;
            fnd_file.PUT_LINE (fnd_file.LOG, 'Approve PO error' || P_ERRBUF);
    --ROLLBACK;
    END;

    --Input         p_batch_id      batch to proces
    --              p_po_status     PO status status flag
    --Output        p_errbuf        Error code
    --              p_retcode       Return code

    PROCEDURE XXD_UPDATE_NEEDBY_DATE (p_batch_id IN NUMBER, P_PO_STATUS IN VARCHAR2, P_ERRBUF OUT VARCHAR2
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
                     plla.need_by_date po_need_by_date, poh.org_id, pla.line_num,
                     poh.agent_id, pdt.document_subtype, pdt.document_type_code,
                     poh.wf_item_key
                FROM po_headers_all poh, po_headers_interface phi, po_lines_interface plit,
                     po_requisition_headers_all prha, po_requisition_lines_all prla, po_distributions_all pda,
                     po_line_locations_all plla, PO_LINES_ALL pla, po_req_distributions_all prda,
                     po_document_types_all pdt
               WHERE     phi.batch_id = p_batch_id
                     AND phi.po_header_id = poh.po_header_id
                     AND plit.interface_header_id = phi.interface_header_id
                     AND plit.PO_LINE_ID = pla.PO_LINE_ID
                     AND prla.need_by_date != plla.need_by_date
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
            ORDER BY poh.segment1, pla.line_num;

        TYPE cur_po_headers_TAB IS TABLE OF cur_po_headers%ROWTYPE
            INDEX BY BINARY_INTEGER;

        cur_po_headers_T   cur_po_headers_TAB;
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, '--Update Need By Date : Enter');

        OPEN cur_po_headers;

        LOOP
            FETCH cur_po_headers
                BULK COLLECT INTO cur_po_headers_T
                LIMIT 5000;

            fnd_file.PUT_LINE (fnd_file.LOG, 'after line loop');
            EXIT WHEN cur_po_headers_T.COUNT = 0;
            fnd_file.PUT_LINE (fnd_file.LOG, 'after exit');

            -- IF cur_po_headers_T.COUNT >0
            -- THEN
            FOR i IN cur_po_headers_T.FIRST .. cur_po_headers_T.LAST
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                       'PO: Need by date : '
                    || TO_CHAR (cur_po_headers_t (i).po_need_by_date,
                                'MM,dd,yyyy'));
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                       'REQ: Need by date : '
                    || TO_CHAR (cur_po_headers_t (i).need_by_date,
                                'MM,dd,yyyy'));

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
                                cur_po_headers_t (i).need_by_date,
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

                        fnd_file.PUT_LINE (
                            fnd_file.LOG,
                               'update api error PO#'
                            || cur_po_headers_t (i).po_num
                            || ' line_num:'
                            || cur_po_headers_t (i).line_num
                            || P_ERRBUF);
                        P_RETCODE   := 1;
                    ELSE
                        -- P_RETCODE := 0;
                        P_ERRBUF   := NULL;
                        fnd_file.PUT_LINE (
                            fnd_file.LOG,
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
                        fnd_file.PUT_LINE (fnd_file.LOG, P_ERRBUF);
                -- return;
                END;
            END LOOP;
        --       cur_po_headers_t.DELETE;
        --ELSE
        -- EXIT;
        -- END IF;
        END LOOP;

        CLOSE cur_po_headers;

        fnd_file.PUT_LINE (fnd_file.LOG, '--Update Need By Date : Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_po_headers%ISOPEN
            THEN
                CLOSE cur_po_headers;
            END IF;

            P_RETCODE   := 1;
            P_ERRBUF    := P_ERRBUF || SQLERRM;
            fnd_file.PUT_LINE (fnd_file.LOG,
                               'need by date update error' || P_ERRBUF);
    --ROLLBACK;
    END XXD_UPDATE_NEEDBY_DATE;

    --This procedure populates the PO headers interface and PO lines interface tables for trade requisitions
    -- Populate Purchase orders interface records for non-trade
    --Input      p_batch_id      batch to process
    --           p_buyer_id      buyer id to check
    --           p_ou            ou to check
    --           p_po_status     Status for created POs
    --           p_user_ud       User to use for new POs
    --           p_reqid         req_header_id to check
    --Output     p_errbuff       Error message
    --           p_retcode       return code

    PROCEDURE XXD_POPULATE_POI_FOR_TRADE (p_batch_id IN NUMBER, P_ERRBUF OUT NOCOPY VARCHAR2, P_RETCODE OUT NOCOPY NUMBER, P_BUYER_ID IN NUMBER, P_OU IN NUMBER, P_PO_STATUS IN VARCHAR2
                                          , P_USER_ID IN NUMBER, P_REQ_ID IN NUMBER DEFAULT NULL, P_DESTINATION_ORGANIZATION_ID IN NUMBER DEFAULT NULL)
    IS
        CURSOR Cur_PO_HEADERS_interface IS
            SELECT DISTINCT
                   'STANDARD'
                       TYPE_LOOKUP_CODE,                            --Constant
                   'PO Data Elements'
                       ATTRIBUTE_CATEGORY,                          --Constant
                   --Header Fields (non grouping)
                   PRHA.INTERFACE_SOURCE_CODE,
                   CASE
                       WHEN APS.ATTRIBUTE2 = 'Y' THEN 'Y'
                       ELSE 'N'
                   END
                       ATTRIBUTE11,                                 --GTN Flag
                   APSS.ATTRIBUTE3
                       ATTRIBUTE12,                               --Prepayment
                   NVL (PRLA.CURRENCY_CODE, GL.CURRENCY_CODE)
                       CURRENCY_CODE,
                   CASE
                       WHEN GL.CURRENCY_CODE != PRLA.CURRENCY_CODE
                       THEN
                           PRLA.RATE_TYPE
                       ELSE
                           NULL
                   END
                       RATE_TYPE,
                   CASE
                       WHEN GL.CURRENCY_CODE != PRLA.CURRENCY_CODE
                       THEN
                           PRLA.RATE_DATE
                       ELSE
                           NULL
                   END
                       RATE_DATE,
                   CASE
                       WHEN GL.CURRENCY_CODE != PRLA.CURRENCY_CODE THEN -- round(PRLA.rate,2)
                                                                        NULL
                       ELSE NULL
                   END
                       RATE,
                   DECODE (
                       PRLA.PCARD_FLAG,
                       'Y', PRHA.PCARD_ID,
                       'S', NVL (
                                (PO_PCARD_PKG.GET_VALID_PCARD_ID (-99999, APS.VENDOR_ID, APSS.VENDOR_SITE_ID)),
                                -99999),
                       'N', NULL)
                       PCARD_ID,
                   --(grouping fields)
                   PRHA.ORG_ID,                                     --Grouping
                   PRLA.SUGGESTED_BUYER_ID
                       AGENT_ID,                                    --Grouping
                   APS.VENDOR_ID,                                   --Grouping
                   APSS.VENDOR_SITE_ID,                             --Grouping
                   CASE
                       WHEN PRLA.DROP_SHIP_FLAG = 'Y' THEN HROU.LOCATION_ID
                       ELSE PRLA.DELIVER_TO_LOCATION_ID
                   END
                       SHIP_TO_LOCATION_ID,                         --Grouping
                   ITEM.SEGMENT1
                       BRAND,                                       --Grouping
                   /* begin CCR0007687
                   CASE
                      WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                      THEN
                         CASE
                            WHEN HRORG.NAME = 'Deckers US OU'
                            THEN
                               'SFS'
                            WHEN HRORG.NAME = 'Deckers Macau OU'
                            THEN
                               'INTL_DIST'
                            ELSE
                               'UNKNOWNDS'
                         END
                      ELSE
                         CASE
                            WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%' THEN 'SAMPLE'
                            WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE' THEN 'B-GRADE'
                            ELSE 'STANDARD'
                         END
                   END
                      ATTRIBUTE10, */
                   --PO Type
                   XXD_AUTOCREATE_TRADE_PO_PKG.GET_PO_TYPE (PRLA.REQUISITION_HEADER_ID, PRLA.DROP_SHIP_FLAG, HRORG.NAME
                                                            , ITEM.ITEM_TYPE)
                       attribute10,
                   --End CCR0007687                                  --Grouping
                   NULL
                       X_FACTORY_DATE, --Writing Need By Date directly       --Grouping
                      ITEM.SEGMENT1
                   || '-'
                   || PRLA.DELIVER_TO_LOCATION_ID
                   || '-'
                   || HROU.ORGANIZATION_ID
                       GROUP_CODE,                                  --Grouping
                   --Category and Need By date are written to POHI to facililiate grouping in the lines query
                   --These will be cleared out before imported to POs
                   CASE
                       WHEN (   PRLA.ORG_ID IN
                                    (SELECT ORGANIZATION_ID
                                       FROM HR_OPERATING_UNITS
                                      WHERE NAME IN
                                                ('Deckers US OU', 'Deckers Macau EMEA OU')) --CCR0007979
                             OR (PRLA.DESTINATION_ORGANIZATION_ID IN
                                     (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                       WHERE name = 'INV_MC1_Macau_Interco'))) --CCR0009016
                       THEN
                           CASE
                               WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                               THEN
                                   NULL
                               ELSE
                                   CASE
                                       WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%'
                                       THEN
                                           NULL
                                       WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE'
                                       THEN
                                           NULL
                                       WHEN ITEM.SEGMENT3 LIKE 'POP'
                                       THEN
                                           NULL
                                       ELSE
                                           ITEM.CATEGORY_ID
                                   END
                           END
                       ELSE
                           NULL
                   END
                       ATTRIBUTE13, --Category                                   --Grouping
                   TO_CHAR (PRLA.NEED_BY_DATE, 'YYYY/MM/DD')
                       ATTRIBUTE14,                                 --Grouping
                   --To facilitate calculation of XFDate
                   NVL (PRLA.DROP_SHIP_FLAG, 'N')
                       DROP_SHIP_FLAG,                              --Grouping
                   NVL (ICO_COPY.TERRITORY_CODE, HL.COUNTRY)
                       DEST_COUNTRY,                                --Grouping
                   APSS.VENDOR_SITE_CODE,
                   TRUNC (PRLA.NEED_BY_DATE)
                       NEED_BY_DATE,
                   PRHA.REQUISITION_HEADER_ID          -- Added for CCR0006402
              FROM PO.PO_REQUISITION_HEADERS_ALL PRHA,
                   PO.PO_REQUISITION_LINES_ALL PRLA,
                   PO_REQ_DISTRIBUTIONS_ALL PRDA,
                   AP.AP_SUPPLIERS APS,
                   AP.AP_SUPPLIER_SITES_ALL APSS,
                   HR_ALL_ORGANIZATION_UNITS HROU,
                   HR_ALL_ORGANIZATION_UNITS HRORG,
                   HR_LOCATIONS HL,
                   INV.MTL_PARAMETERS MP,
                   GL_LEDGERS GL,
                   (SELECT MSIB.INVENTORY_ITEM_ID, MCB.SEGMENT1, MCB.SEGMENT3,
                           MSIB.ATTRIBUTE28 ITEM_TYPE, MCB.CATEGORY_ID
                      FROM MTL_ITEM_CATEGORIES MIC, INV.MTL_CATEGORIES_B MCB, APPLSYS.FND_ID_FLEX_STRUCTURES FFS,
                           MTL_SYSTEM_ITEMS_B MSIB
                     WHERE     1 = 1
                           AND MSIB.INVENTORY_ITEM_ID = MIC.INVENTORY_ITEM_ID
                           AND MSIB.ORGANIZATION_ID = MIC.ORGANIZATION_ID
                           AND MSIB.ORGANIZATION_ID = 106
                           --
                           AND MIC.CATEGORY_ID = MCB.CATEGORY_ID
                           AND MIC.CATEGORY_SET_ID = 1
                           --
                           AND MCB.STRUCTURE_ID = FFS.ID_FLEX_NUM
                           --
                           AND FFS.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                           AND FFS.APPLICATION_ID = 401
                           AND FFS.ID_FLEX_CODE = 'MCAT') ITEM,
                   (SELECT DSS.REQUISITION_LINE_ID, FTV.TERRITORY_SHORT_NAME, FTV.TERRITORY_CODE
                      FROM OE_ORDER_HEADERS_ALL OOHA, ONT.OE_ORDER_LINES_ALL OOLA, ONT.OE_DROP_SHIP_SOURCES DSS,
                           PO.PO_LINES_ALL PLA, HZ_CUST_SITE_USES_ALL HCAS, HZ_CUST_ACCT_SITES_ALL HCASA,
                           HZ_PARTY_SITES HPS, HZ_LOCATIONS HL, FND_TERRITORIES_TL FTV
                     WHERE     OOLA.LINE_ID = DSS.LINE_ID
                           AND OOLA.INVENTORY_ITEM_ID = PLA.ITEM_ID
                           AND OOLA.ORG_ID =
                               (SELECT ORGANIZATION_ID
                                  FROM HR_OPERATING_UNITS
                                 WHERE NAME = 'Deckers Macau OU')
                           AND OOLA.LINE_ID =
                               TO_NUMBER (NVL (PLA.ATTRIBUTE5, '1'))
                           AND PLA.ATTRIBUTE_CATEGORY =
                               'Intercompany PO Copy'
                           AND DSS.HEADER_ID = OOHA.HEADER_ID
                           AND HCASA.CUST_ACCT_SITE_ID =
                               HCAS.CUST_ACCT_SITE_ID
                           AND HPS.PARTY_SITE_ID = HCASA.PARTY_SITE_ID
                           AND HL.LOCATION_ID = HPS.LOCATION_ID
                           AND FTV.TERRITORY_CODE = HL.COUNTRY
                           AND HCAS.SITE_USE_ID = OOHA.SHIP_TO_ORG_ID
                           AND EXISTS
                                   (SELECT NULL
                                      FROM PO_REQUISITION_LINES_ALL PRLA1
                                     WHERE     PRLA1.REQUISITION_LINE_ID =
                                               DSS.REQUISITION_LINE_ID
                                           AND PRLA1.DROP_SHIP_FLAG = 'Y'))
                   ICO_COPY
             WHERE     1 = 1
                   AND PRHA.REQUISITION_HEADER_ID =
                       PRLA.REQUISITION_HEADER_ID
                   AND PRDA.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
                   AND PRHA.AUTHORIZATION_STATUS = 'APPROVED'
                   AND PRLA.ORG_ID = P_OU
                   AND NVL (PRLA.SUGGESTED_BUYER_ID, -999) = P_BUYER_ID
                   AND NVL (PRLA.LINE_LOCATION_ID, -999) = -999
                   AND NVL (PRLA.CANCEL_FLAG, 'N') = 'N'
                   AND PRHA.REQUISITION_HEADER_ID =
                       NVL (P_REQ_ID, PRHA.REQUISITION_HEADER_ID)
                   AND NVL (PRLA.CLOSED_CODE, 'OPEN') <> 'FINALLY CLOSED' -- ADDED CCR0006820
                   AND PRLA.DESTINATION_ORGANIZATION_ID =
                       NVL (P_DESTINATION_ORGANIZATION_ID,
                            PRLA.DESTINATION_ORGANIZATION_ID) -- ADDED CCR0006820
                   --Suppliers
                   AND PRLA.VENDOR_ID = APS.VENDOR_ID
                   AND (PRLA.VENDOR_SITE_ID = APSS.VENDOR_SITE_ID OR PRLA.SUGGESTED_VENDOR_LOCATION = APSS.VENDOR_SITE_CODE)
                   AND PRLA.ORG_ID = APSS.ORG_ID
                   AND APSS.VENDOR_ID = APS.VENDOR_ID
                   --Dest Org
                   AND HROU.ORGANIZATION_ID =
                       NVL (
                           (SELECT PORL.DESTINATION_ORGANIZATION_ID
                              FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL, OE_ORDER_HEADERS_ALL OHA,
                                   OE_ORDER_LINES_ALL OLA, MTL_RESERVATIONS MTR
                             WHERE     OHA.HEADER_ID = OLA.HEADER_ID
                                   AND PORH.REQUISITION_HEADER_ID =
                                       PORL.REQUISITION_HEADER_ID
                                   AND OLA.SOURCE_DOCUMENT_ID =
                                       PORH.REQUISITION_HEADER_ID
                                   AND OLA.SOURCE_DOCUMENT_LINE_ID =
                                       PORL.REQUISITION_LINE_ID
                                   AND PRLA.REQUISITION_LINE_ID =
                                       MTR.SUPPLY_SOURCE_LINE_ID
                                   AND PRLA.REQUISITION_HEADER_ID =
                                       MTR.SUPPLY_SOURCE_HEADER_ID -- SRC_HDR_ID
                                   AND MTR.SUPPLY_SOURCE_TYPE_ID = 17
                                   AND MTR.DEMAND_SOURCE_LINE_ID =
                                       OLA.LINE_ID --  AND PRHA.INTERFACE_SOURCE_CODE = 'CTO'
                                                  ),
                           PRLA.DESTINATION_ORGANIZATION_ID)
                   --Req OU
                   AND PRLA.ORG_ID = HRORG.ORGANIZATION_ID
                   --Dest Location
                   AND HROU.LOCATION_ID = HL.LOCATION_ID
                   --Dest Org
                   AND PRLA.DESTINATION_ORGANIZATION_ID = MP.ORGANIZATION_ID
                   AND (MP.ATTRIBUTE13 = '2' OR MP.ATTRIBUTE13 IS NULL)
                   --General Ledger
                   AND PRDA.SET_OF_BOOKS_ID = GL.LEDGER_ID
                   --Items
                   AND PRLA.ITEM_ID = ITEM.INVENTORY_ITEM_ID
                   --ISO Copy
                   AND PRLA.REQUISITION_LINE_ID =
                       ICO_COPY.REQUISITION_LINE_ID(+);

        CURSOR Cur_PO_LINES_interface IS
              SELECT 'PO Line Locations Elements' SHIPMENT_ATTRIBUTE_CATEGORY,
                     'PO Data Elements' LINE_ATTRIBUTE_CATEGORY,
                     PRLA.ITEM_ID,
                     PRLA.UNIT_PRICE,
                     PRLA.QUANTITY,
                     PRLA.ITEM_DESCRIPTION,
                     PRLA.UNIT_MEAS_LOOKUP_CODE,
                     PRLA.CATEGORY_ID,
                     PRLA.REQUISITION_LINE_ID,
                     PRLA.JOB_ID,
                     PRLA.NEED_BY_DATE - 10 NEED_BY_DATE, --TODO: Significance of need_by_date -10?
                     PRLA.LINE_TYPE_ID,
                     PRLA.DELIVER_TO_LOCATION_ID,
                     POHI.INTERFACE_HEADER_ID,
                     POHI.SHIP_TO_LOCATION_ID,
                     POHI.ATTRIBUTE1 SHIPMENT_ATTRIBUTE4,
                     POHI.ATTRIBUTE10,
                     NULL SHIPMENT_ATTRIBUTE10,        --Need ship method calc
                     TRIM (ITEM.SEGMENT1) LINE_ATTRIBUTE1,
                     TRIM (ITEM.SEGMENT3) LINE_ATTRIBUTE2,
                     'Y' SHIPMENT_ATTRIBUTE6, --Flag for interco price recalc --CCR0008186
                     APS.VENDOR_ID,
                     APSS.VENDOR_SITE_CODE LINE_ATTRIBUTE7,
                     APPS.IID_TO_SKU (PRLA.ITEM_ID) SKU,
                     NVL (PRLA.DROP_SHIP_FLAG, 'N') DROP_SHIP_FLAG,
                     NVL (ICO_COPY.TERRITORY_CODE, HL.COUNTRY) DEST_COUNTRY,
                     CASE
                         WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%' THEN 'SAMPLE'
                         WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE' THEN 'B-GRADE'
                         ELSE ITEM.ITEM_TYPE
                     END ITEM_TYPE,
                     PRLA.NOTE_TO_RECEIVER                       -- CCR0006402
                FROM PO_REQUISITION_HEADERS_ALL PRHA,
                     PO_REQUISITION_LINES_ALL PRLA,
                     AP_SUPPLIERS APS,
                     AP_SUPPLIER_SITES_ALL APSS,
                     PO_HEADERS_INTERFACE POHI,
                     MTL_SYSTEM_ITEMS_B MSB,                     -- CCR0007099
                     MTL_PARAMETERS MP,
                     HR_ALL_ORGANIZATION_UNITS HROU,
                     HR_LOCATIONS HL,
                     HR_ALL_ORGANIZATION_UNITS HRORG,
                     (SELECT MSIB.INVENTORY_ITEM_ID, MCB.SEGMENT1, MCB.SEGMENT3,
                             MSIB.ATTRIBUTE28 ITEM_TYPE, MCB.CATEGORY_ID
                        FROM MTL_ITEM_CATEGORIES MIC, INV.MTL_CATEGORIES_B MCB, APPLSYS.FND_ID_FLEX_STRUCTURES FFS,
                             MTL_SYSTEM_ITEMS_B MSIB
                       WHERE     1 = 1
                             AND MSIB.INVENTORY_ITEM_ID = MIC.INVENTORY_ITEM_ID
                             AND MSIB.ORGANIZATION_ID = MIC.ORGANIZATION_ID
                             AND MSIB.ORGANIZATION_ID = 106
                             --
                             AND MIC.CATEGORY_ID = MCB.CATEGORY_ID
                             AND MIC.CATEGORY_SET_ID = 1
                             --
                             AND MCB.STRUCTURE_ID = FFS.ID_FLEX_NUM
                             --
                             -- AND FFS.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                             AND FFS.APPLICATION_ID = 401
                             AND FFS.ID_FLEX_CODE = 'MCAT') ITEM,
                     (SELECT DSS.REQUISITION_LINE_ID, FTV.TERRITORY_SHORT_NAME, FTV.TERRITORY_CODE
                        FROM OE_ORDER_HEADERS_ALL OOHA, ONT.OE_ORDER_LINES_ALL OOLA, ONT.OE_DROP_SHIP_SOURCES DSS,
                             PO_LINES_ALL PLA, HZ_CUST_SITE_USES_ALL HCAS, HZ_CUST_ACCT_SITES_ALL HCASA,
                             HZ_PARTY_SITES HPS, HZ_LOCATIONS HL, FND_TERRITORIES_VL FTV
                       WHERE     OOLA.LINE_ID = DSS.LINE_ID
                             AND OOLA.INVENTORY_ITEM_ID = PLA.ITEM_ID
                             AND OOLA.ORG_ID =
                                 (SELECT ORGANIZATION_ID
                                    FROM HR_OPERATING_UNITS
                                   WHERE NAME = 'Deckers Macau OU')
                             AND OOLA.LINE_ID = TO_NUMBER (PLA.ATTRIBUTE5)
                             AND PLA.ATTRIBUTE_CATEGORY =
                                 'Intercompany PO Copy'
                             AND DSS.HEADER_ID = OOHA.HEADER_ID
                             AND HCASA.CUST_ACCT_SITE_ID =
                                 HCAS.CUST_ACCT_SITE_ID
                             AND HPS.PARTY_SITE_ID = HCASA.PARTY_SITE_ID
                             AND HL.LOCATION_ID = HPS.LOCATION_ID
                             AND FTV.TERRITORY_CODE = HL.COUNTRY
                             AND HCAS.SITE_USE_ID = OOHA.SHIP_TO_ORG_ID
                             AND EXISTS
                                     (SELECT NULL
                                        FROM PO_REQUISITION_LINES_ALL PRLA1
                                       WHERE     PRLA1.REQUISITION_LINE_ID =
                                                 DSS.REQUISITION_LINE_ID
                                             AND PRLA1.DROP_SHIP_FLAG = 'Y'))
                     ICO_COPY
               WHERE     1 = 1
                     AND PRHA.REQUISITION_HEADER_ID =
                         PRLA.REQUISITION_HEADER_ID
                     AND PRHA.AUTHORIZATION_STATUS = 'APPROVED'
                     AND PRHA.ORG_ID = P_OU
                     AND NVL (PRLA.SUGGESTED_BUYER_ID, -999) = P_BUYER_ID
                     AND NVL (PRLA.LINE_LOCATION_ID, -999) = -999
                     AND NVL (PRLA.CANCEL_FLAG, 'N') = 'N'
                     AND PRHA.REQUISITION_HEADER_ID =
                         NVL (P_REQ_ID, PRHA.REQUISITION_HEADER_ID)
                     AND NVL (PRLA.CLOSED_CODE, 'OPEN') <> 'FINALLY CLOSED' -- ADDED CCR0006820
                     AND PRLA.DESTINATION_ORGANIZATION_ID =
                         NVL (P_DESTINATION_ORGANIZATION_ID,
                              PRLA.DESTINATION_ORGANIZATION_ID) -- ADDED CCR0006820
                     AND PRLA.ITEM_ID = MSB.INVENTORY_ITEM_ID    -- CCR0007099
                     AND PRLA.DESTINATION_ORGANIZATION_ID = MSB.ORGANIZATION_ID -- CCR0007099
                     --Suppliers
                     AND PRLA.VENDOR_ID = APS.VENDOR_ID
                     AND (APSS.VENDOR_SITE_ID = PRLA.VENDOR_SITE_ID OR APSS.VENDOR_SITE_CODE = PRLA.SUGGESTED_VENDOR_LOCATION)
                     AND PRLA.ORG_ID = APSS.ORG_ID
                     AND APS.VENDOR_ID = APSS.VENDOR_ID
                     -- AND APS.ENABLED_FLAG = 'Y' -- 0 records not enabled
                     --Dest Location
                     AND HROU.LOCATION_ID = HL.LOCATION_ID
                     AND HROU.ORGANIZATION_ID =
                         NVL (
                             (SELECT PORL.DESTINATION_ORGANIZATION_ID
                                FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL, OE_ORDER_HEADERS_ALL OHA,
                                     OE_ORDER_LINES_ALL OLA, MTL_RESERVATIONS MTR
                               WHERE     OHA.HEADER_ID = OLA.HEADER_ID
                                     AND PORH.REQUISITION_HEADER_ID =
                                         PORL.REQUISITION_HEADER_ID
                                     AND OLA.SOURCE_DOCUMENT_ID =
                                         PORH.REQUISITION_HEADER_ID
                                     AND OLA.SOURCE_DOCUMENT_LINE_ID =
                                         PORL.REQUISITION_LINE_ID
                                     --  AND OLA.INVENTORY_ITEM_ID = PORL.ITEM_ID
                                     AND PRLA.REQUISITION_LINE_ID =
                                         MTR.SUPPLY_SOURCE_LINE_ID
                                     AND PRLA.REQUISITION_HEADER_ID =
                                         MTR.SUPPLY_SOURCE_HEADER_ID -- SRC_HDR_ID
                                     AND MTR.DEMAND_SOURCE_LINE_ID =
                                         OLA.LINE_ID
                                     AND PRHA.INTERFACE_SOURCE_CODE = 'CTO'),
                             PRLA.DESTINATION_ORGANIZATION_ID)
                     --Items
                     AND PRLA.ITEM_ID = ITEM.INVENTORY_ITEM_ID
                     --Dest Org
                     AND PRLA.DESTINATION_ORGANIZATION_ID = MP.ORGANIZATION_ID
                     AND NVL (MP.ATTRIBUTE13, '2') = '2'
                     --ISO Copy
                     AND PRLA.REQUISITION_LINE_ID =
                         ICO_COPY.REQUISITION_LINE_ID(+)
                     --Req OU
                     AND PRLA.ORG_ID = HRORG.ORGANIZATION_ID
                     --Grouping to POHI
                     AND POHI.ORG_ID = PRHA.ORG_ID
                     AND POHI.AGENT_ID = PRLA.SUGGESTED_BUYER_ID
                     AND POHI.VENDOR_ID = APS.VENDOR_ID
                     AND POHI.VENDOR_SITE_ID = APSS.VENDOR_SITE_ID
                     AND POHI.SHIP_TO_LOCATION_ID =
                         (CASE
                              WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                              THEN
                                  HROU.LOCATION_ID
                              ELSE
                                  PRLA.DELIVER_TO_LOCATION_ID
                          END)
                     AND POHI.BATCH_ID = P_BATCH_ID
                     --begin CCR0007687
                     AND POHI.ATTRIBUTE10 = XXD_AUTOCREATE_TRADE_PO_PKG.GET_PO_TYPE (
                                                PRLA.REQUISITION_HEADER_ID,
                                                PRLA.DROP_SHIP_FLAG,
                                                HRORG.NAME,
                                                ITEM.ITEM_TYPE)
                     /*       CASE
                               WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                               THEN
                                  CASE
                                     WHEN HRORG.NAME = 'Deckers US OU'
                                     THEN
                                        'SFS'
                                     WHEN HRORG.NAME = 'Deckers Macau OU'
                                     THEN
                                        'INTL_DIST'
                                     ELSE
                                        'UNKNOWNDS'
                                  END
                               ELSE
                                  CASE
                                     WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%'
                                     THEN
                                        'SAMPLE'
                                     WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE'
                                     THEN
                                        'B-GRADE'
                                     ELSE
                                        'STANDARD'
                                  END
                            END*/
                     --end CCR0007687
                     AND POHI.GROUP_CODE =
                            ITEM.SEGMENT1
                         || '-'
                         || PRLA.DELIVER_TO_LOCATION_ID
                         || '-'
                         || HROU.ORGANIZATION_ID
                     AND NVL (POHI.ATTRIBUTE13, '-NONE-') =
                         CASE
                             WHEN (   PRLA.ORG_ID IN
                                          (SELECT ORGANIZATION_ID
                                             FROM HR_OPERATING_UNITS
                                            WHERE NAME IN
                                                      ('Deckers US OU', 'Deckers Macau EMEA OU')) --CCR0007979
                                   OR (PRLA.DESTINATION_ORGANIZATION_ID IN
                                           (SELECT ORGANIZATION_ID
                                              FROM HR_ALL_ORGANIZATION_UNITS
                                             WHERE name =
                                                   'INV_MC1_Macau_Interco'))) --CCR0009016
                             THEN
                                 CASE
                                     WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                                     THEN
                                         '-NONE-'
                                     ELSE
                                         CASE
                                             WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%'
                                             THEN
                                                 '-NONE-'
                                             WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE'
                                             THEN
                                                 '-NONE-'
                                             WHEN ITEM.SEGMENT3 LIKE 'POP'
                                             THEN
                                                 '-NONE-'
                                             ELSE
                                                 TO_CHAR (ITEM.CATEGORY_ID)
                                         END
                                 END
                             ELSE
                                 '-NONE-'
                         END
                     AND POHI.ATTRIBUTE14 =
                         TO_CHAR (PRLA.NEED_BY_DATE, 'YYYY/MM/DD')
                     AND POHI.ATTRIBUTE15 = PRHA.REQUISITION_HEADER_ID -- CCR0006820
            ORDER BY POHI.INTERFACE_HEADER_ID, SUBSTR (MSB.SEGMENT1, 1, INSTR (MSB.SEGMENT1, '-', -1)), TO_NUMBER (MSB.ATTRIBUTE10);

        --, APPS.XXDO_IID_SKU_SIZE (PRLA.ITEM_ID); -- CCR0007099

        V_batch_id                 NUMBER := P_BATCH_ID;

        v_buy_month                VARCHAR2 (20);
        v_buy_season               VARCHAR2 (20);

        v_xf_date                  VARCHAR2 (20);
        v_ship_method              VARCHAR2 (20);
        v_tq_po_exists             VARCHAR2 (20);                -- CCR0006402
        v_drop_ship_flag           VARCHAR2 (20);                -- CCR0006402
        v_processed_lines_count    NUMBER := 0;
        v_rejected_lines_count     NUMBER := 0;
        v_err_tolerance_exceeded   VARCHAR2 (100);

        v_return_status            VARCHAR2 (20);

        V_PO_STATUS                VARCHAR2 (50);

        n_header_cnt               NUMBER;
        n_line_cnt                 NUMBER;

        po_header_cnt              NUMBER;
        po_line_cnt                NUMBER;

        po_rejected_cnt            NUMBER;

        n_cnt                      NUMBER := 0;
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, '--Populate POI Trade : Enter');

        fnd_file.PUT_LINE (fnd_file.LOG,
                           'befor header insert ' || P_batch_id);

        --Get buy month and buy season. These are not based on table data and therefore constant
        v_buy_month    := get_buy_month;
        v_buy_season   := get_buy_season;

        fnd_file.PUT_LINE (fnd_file.LOG, 'Buy Month : ' || v_buy_month);
        fnd_file.PUT_LINE (fnd_file.LOG, 'Buy Season : ' || v_buy_season);

        n_cnt          := 0;

        FOR PO_HEADERS_interface_REC IN Cur_PO_HEADERS_interface
        LOOP
            -- START CCR0006402
            v_tq_po_exists   := NULL;

            BEGIN
                SELECT 'Y'
                  INTO v_tq_po_exists
                  FROM apps.oe_drop_ship_sources ods, apps.oe_order_headers_all ooh, apps.po_headers_all pha
                 WHERE     ods.requisition_header_id =
                           po_headers_interface_rec.requisition_header_id
                       AND ods.header_id = ooh.header_id
                       AND ooh.cust_po_number = pha.segment1
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_tq_po_exists   := 'N';
                WHEN OTHERS
                THEN
                    v_tq_po_exists   := 'N';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error in Finding TQ PO Exists for Req Header id :: '
                        || po_headers_interface_rec.requisition_header_id
                        || ' :: '
                        || SQLERRM);
            END;

            BEGIN
                SELECT DECODE (v_tq_po_exists, 'Y', 'T', PO_HEADERS_interface_REC.DROP_SHIP_FLAG)
                  INTO v_drop_ship_flag
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_drop_ship_flag   := NULL;
            END;

            -- END CCR0006402

            --Get XF Date from need by date
            v_xf_date        :=
                TO_CHAR (
                      PO_HEADERS_interface_REC.need_by_date
                    - get_transit_time (
                          PO_HEADERS_interface_REC.VENDOR_ID,
                          PO_HEADERS_interface_REC.VENDOR_SITE_CODE,
                          --PO_HEADERS_interface_REC.DROP_SHIP_FLAG, -- CCR0006402
                          v_drop_ship_flag,                      -- CCR0006402
                          PO_HEADERS_interface_REC.ATTRIBUTE10, --Added as default could vary by po_type
                          PO_HEADERS_interface_REC.DEST_COUNTRY),
                    'YYYY/MM/DD');


            INSERT INTO po_headers_interface (action, process_code, BATCH_ID,
                                              document_type_code, interface_header_id, created_by, document_subtype, agent_id, creation_date, vendor_id, vendor_site_id, currency_code, rate_type, rate_date, rate, pcard_id, group_code, ORG_ID, ship_to_location_id, attribute1, ATTRIBUTE_CATEGORY, ATTRIBUTE9, ATTRIBUTE8, ATTRIBUTE11, ATTRIBUTE10, ATTRIBUTE12, ATTRIBUTE13
                                              , ATTRIBUTE14, -- Added by Anil on 10-Apr-15, as part of GTN Phase II changes
                                                             ATTRIBUTE15) -- CCR0006820
                     VALUES ('ORIGINAL',
                             NULL,
                             P_batch_id,
                             'STANDARD',
                             po_headers_interface_s.NEXTVAL,
                             fnd_profile.VALUE ('USER_ID'),
                             PO_HEADERS_interface_REC.type_lookup_code,
                             PO_HEADERS_interface_REC.agent_id,
                             SYSDATE,
                             PO_HEADERS_interface_REC.vendor_id,
                             PO_HEADERS_interface_REC.vendor_site_id,
                             PO_HEADERS_interface_REC.currency_code,
                             PO_HEADERS_interface_REC.rate_type, --v_rate_type
                             PO_HEADERS_interface_REC.rate_date, --d_rate_date
                             PO_HEADERS_interface_REC.rate,           --n_rate
                             PO_HEADERS_interface_REC.pcard_id,   --n_pcard_id
                             PO_HEADERS_interface_REC.group_code,
                             PO_HEADERS_interface_REC.ORG_ID,
                             PO_HEADERS_interface_REC.ship_to_location_id,
                             v_xf_date,
                             PO_HEADERS_interface_REC.ATTRIBUTE_CATEGORY,
                             v_buy_month,
                             v_buy_season,
                             PO_HEADERS_interface_REC.ATTRIBUTE11,
                             PO_HEADERS_interface_REC.ATTRIBUTE10,
                             PO_HEADERS_interface_REC.ATTRIBUTE12,
                             PO_HEADERS_interface_REC.ATTRIBUTE13,  --Category
                             PO_HEADERS_interface_REC.ATTRIBUTE14, --Need By Date
                             -- Added by Anil on 10-Apr-15, as part of GTN Phase II changes
                             PO_HEADERS_interface_REC.REQUISITION_HEADER_ID -- CCR0006820
                                                                           );

            n_cnt            := n_cnt + 1;
        END LOOP;

        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'after header insert. Reccords inserted : ' || n_cnt);

        BEGIN
            --Check if records were inserted into header. If not then exception is raised
            SELECT DISTINCT batch_id
              INTO v_batch_id
              FROM po_headers_interface
             WHERE batch_id = p_batch_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.PUT_LINE (fnd_file.LOG,
                                   'No Trade requisition selected');
                P_RETCODE   := 2;
                P_ERRBUF    := 'No Trade requisition selected';
                RETURN;
        END;

        n_cnt          := 0;

        FOR PO_LINES_interface_REC IN Cur_PO_LINES_interface
        LOOP
            v_ship_method   :=
                get_ship_method (PO_LINES_interface_REC.VENDOR_ID, PO_LINES_interface_REC.LINE_ATTRIBUTE7, PO_LINES_interface_REC.ATTRIBUTE10
                                 , PO_LINES_interface_REC.DEST_COUNTRY);


            INSERT INTO po_lines_interface (action,
                                            interface_line_id,
                                            interface_header_id,
                                            unit_price,
                                            quantity,
                                            item_description,
                                            unit_OF_MEASURE,
                                            category_id,
                                            job_id,
                                            need_by_date,
                                            line_type_id,
                                            --                                         vendor_product_num,
                                            ip_category_id,
                                            requisition_line_id,
                                            SHIP_TO_LOCATION_ID,
                                            shipment_attribute4,
                                            shipment_attribute10,
                                            shipment_attribute_CATEGORY,
                                            LINE_ATTRIBUTE_CATEGORY_lines,
                                            LINE_ATTRIBUTE1,
                                            LINE_ATTRIBUTE2,
                                            LINE_ATTRIBUTE7,
                                            note_to_receiver,    -- CCR0006402
                                            drop_ship_flag,      -- CCR0006402
                                            SHIPMENT_ATTRIBUTE6  -- CCR0008186
                                                               )
                     VALUES (
                                'ORIGINAL',
                                po_lines_interface_s.NEXTVAL,
                                PO_LINES_interface_REC.interface_header_id,
                                PO_LINES_interface_REC.unit_price,
                                PO_LINES_interface_REC.quantity,
                                PO_LINES_interface_REC.item_description,
                                PO_LINES_interface_REC.unit_meas_lookup_code,
                                PO_LINES_interface_REC.category_id,
                                PO_LINES_interface_REC.job_id,
                                PO_LINES_interface_REC.need_by_date,
                                PO_LINES_interface_REC.line_type_id,
                                --                      PO_LINES_interface_REC.vendor_product_num,
                                NULL,
                                PO_LINES_interface_REC.requisition_line_id,
                                PO_LINES_interface_REC.SHIP_TO_LOCATION_ID,
                                PO_LINES_interface_REC.shipment_attribute4,
                                v_ship_method,
                                PO_LINES_interface_REC.shipment_attribute_CATEGORY,
                                PO_LINES_interface_REC.LINE_ATTRIBUTE_CATEGORY,
                                PO_LINES_interface_REC.LINE_ATTRIBUTE1,
                                PO_LINES_interface_REC.LINE_ATTRIBUTE2,
                                PO_LINES_interface_REC.LINE_ATTRIBUTE7,
                                PO_LINES_interface_REC.note_to_receiver, -- CCR0006402
                                PO_LINES_interface_REC.drop_ship_flag, -- CCR0006402
                                PO_LINES_interface_REC.SHIPMENT_ATTRIBUTE6 -- CCR0008186
                                                                          );

            n_cnt   := n_cnt + 1;
        END LOOP;

        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'after line insert. Reccords inserted : ' || n_cnt);

        fnd_file.PUT_LINE (fnd_file.LOG, 'Clear out attributes');

        --Clear out extra field values added for line grouping
        UPDATE PO_HEADERS_INTERFACE
           SET ATTRIBUTE13 = NULL, ATTRIBUTE14 = NULL, ATTRIBUTE15 = NULL -- ADDED CCR0006820
         WHERE BATCH_ID = P_BATCH_ID;

        -- Start CCR0006820
        --Get POI recordcounts. Use to validate against POs later
        SELECT COUNT (*)
          INTO n_header_cnt
          FROM po_headers_interface phi
         WHERE batch_id = v_batch_id;

        SELECT COUNT (*)
          INTO n_line_cnt
          FROM po_headers_interface phi, po_lines_interface pli
         WHERE     phi.interface_header_id = pli.interface_header_id
               AND batch_id = v_batch_id;


        --Check setting and set PO status if necessary
        IF FND_PROFILE.VALUE ('XXD_PO_DATE_UPDATE') = 'Y'
        THEN
            V_PO_STATUS   := 'INCOMPLETE';
        ELSE
            V_PO_STATUS   := UPPER (P_PO_STATUS);
        END IF;

        fnd_file.PUT_LINE (fnd_file.LOG, 'Set PO status' || V_PO_STATUS);

        --Run PO Import(using function call as oposed to concurrent request so we can avoid COMMIT

        --Using this process will create all POs using the same p_batch_id.
        --Option for Drop ship type POs. Use  PO_INTERFACE_S.create_documents. Note: this function would require multiple iterations for multiple
        --PO interface headers tied to the same p_batch_id. The resultant POs would then have unique batch_ids
        --Also  PO_INTERFACE_S.create_documents does not havce a non commit option
        fnd_file.PUT_LINE (fnd_file.LOG, 'Start PO import process');
        APPS.PO_PDOI_PVT.start_process (
            p_api_version                  => 1.0,
            p_init_msg_list                => FND_API.G_TRUE,
            p_validation_level             => NULL,
            p_commit                       => FND_API.G_FALSE,
            x_return_status                => v_return_status,
            p_gather_intf_tbl_stat         => 'N',
            p_calling_module               => NULL,
            p_selected_batch_id            => v_batch_id,
            p_batch_size                   => NULL,
            p_buyer_id                     => NULL,
            p_document_type                => 'STANDARD',
            p_document_subtype             => NULL,
            p_create_items                 => 'N',
            p_create_sourcing_rules_flag   => 'N',
            p_rel_gen_method               => NULL,
            p_sourcing_level               => NULL,
            p_sourcing_inv_org_id          => NULL,
            p_approved_status              => V_PO_STATUS,
            p_process_code                 => NULL,
            p_interface_header_id          => NULL,
            p_org_id                       => P_OU,
            p_ga_flag                      => NULL,
            p_submit_dft_flag              => 'N',
            p_role                         => 'BUYER',
            p_catalog_to_expire            => NULL,
            p_err_lines_tolerance          => NULL,
            p_group_lines                  => 'N',
            p_group_shipments              => 'N',
            p_clm_flag                     => NULL,         --CLM PDOI Project
            x_processed_lines_count        => v_processed_lines_count,
            x_rejected_lines_count         => v_rejected_lines_count,
            x_err_tolerance_exceeded       => v_err_tolerance_exceeded);

        fnd_file.PUT_LINE (fnd_file.LOG,
                           'Check PO import error ' || v_return_status);

        --Check for process error
        --If this process fails then we need to exit
        IF v_return_status = (FND_API.G_RET_STS_ERROR)
        THEN
            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    'CREATE api error:' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
                P_ERRBUF   :=
                       P_ERRBUF
                    || 'CREATE api error:'
                    || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            --Do we rollback inserts to POI?
            ROLLBACK;

            P_retCODE   := 2;
            RETURN;
        ELSIF v_return_status = (FND_API.G_RET_STS_ERROR)
        THEN
            fnd_file.PUT_LINE (fnd_file.LOG, 'Error = ''E''');
            fnd_file.PUT_LINE (fnd_file.LOG,
                               'Count ' || FND_MSG_PUB.count_msg);

            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    'CREATE API UNEXPECTED ERROR:' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));

                P_ERRBUF   :=
                    SUBSTR (
                           P_ERRBUF
                        || 'CREATE API UNEXPECTED ERROR:'
                        || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'),
                        1,
                        200);
            END LOOP;

            --Do we rollback inserts to POI?
            ROLLBACK;

            P_retCODE   := 2;
            RETURN;
        END IF;

        --Log generated PO lines and POI errors to the log file
        fnd_file.PUT_LINE (fnd_file.LOG, 'Show PO Data');
        --Show PO Data imported (Log only)
        SHOW_BATCH_PO_DATA (v_batch_id);

        fnd_file.PUT_LINE (fnd_file.LOG, 'Show POI Errors');
        --Show PO Interface Errors (Log only)
        SHOW_BATCH_POI_ERRORS (v_batch_id);

        --Check PO record counts after import
        SELECT COUNT (*)
          INTO po_header_cnt
          FROM po_headers_all pha, po_headers_interface phi
         WHERE     pha.po_header_id = phi.po_header_id
               AND phi.batch_id = v_batch_id;

        SELECT COUNT (*)
          INTO po_line_cnt
          FROM po_lines_all pla, po_headers_all pha, po_headers_interface phi
         WHERE     pha.po_header_id = phi.po_header_id
               AND pla.po_header_id = pha.po_header_id
               AND phi.batch_id = v_batch_id;

        --compare PO counts to POI counts
        IF po_header_cnt != n_header_cnt OR po_line_cnt != n_line_cnt
        THEN
            --POs created does not match POI. Check for REJECTED POs
            --Report rejected POs but continue processing.
            SELECT COUNT (*)
              INTO po_rejected_cnt
              FROM po_headers_interface
             WHERE process_code = 'REJECTED' AND batch_id = v_batch_id;

            fnd_file.PUT_LINE (
                fnd_file.LOG,
                   v_batch_id
                || ' POs were rejected. See po_interface_errors for details');

            IF po_header_cnt = 0
            THEN
                P_ERRBUF    := 'All POI records failed to interface to POs';
                P_retCODE   := 1;                             --Return warning
                ROLLBACK;
                RETURN;
            END IF;
        END IF;


        fnd_file.PUT_LINE (fnd_file.LOG, 'Update Need by Date');

        --Modification starts for Defect#3280
        IF FND_PROFILE.VALUE ('XXD_PO_DATE_UPDATE') = 'Y'
        THEN
            --This was aded for a workaround for defect 3280 in Quality Center (BT in Oct 2015). There was a corresponding Oracle-SR raised
            --for this issue. No resolution was found and this workaround added.This was retested extensively in Jan -17 and the problem was not reproduced. Therefore this has been remarked out.

            --Unremarked on 3/29 : Re-occurred on Production:
            --Note POI is correct but the neeed by date is altered during import
            XXD_UPDATE_NEEDBY_DATE (v_batch_id, P_PO_STATUS, P_ERRBUF,
                                    P_retCODE);

            XXD_APPROVE_PO (v_batch_id, P_PO_STATUS, P_ERRBUF,
                            P_retCODE);
        END IF;

        --Check error return
        fnd_file.PUT_LINE (fnd_file.LOG,
                           'Update Need by Date return ' || P_retCODE);

        COMMIT;

        fnd_file.PUT_LINE (fnd_file.LOG, 'Update Drop Ship');

        --UPDATE_DROP_SHIP is required for drop_ship POs as APPS.PO_PDOI_PVT.start_process does not populate this data after PO creation
        UPDATE_DROP_SHIP (v_batch_id);

        --fnd_file.PUT_LINE (fnd_file.LOG, '--Populate POI Non-Trade : Exit');
        fnd_file.PUT_LINE (fnd_file.LOG, '--Populate POI Trade : Exit'); -- MODIFIED CCR0006820  REMOVED NON
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.PUT_LINE (
                fnd_file.LOG, --'--Populate POI Non-Trade : Exception ' || SQLERRM); -- MODIFIED CCR0006820  REMOVED NON
                '--Populate POI Trade : Exception ' || SQLERRM); -- MODIFIED CCR0006820  REMOVED NON
    END XXD_POPULATE_POI_FOR_TRADE;

    -- START CCR0007154
    PROCEDURE xxd_populate_dist_poi_trade (p_batch_id IN NUMBER, P_ERRBUF OUT NOCOPY VARCHAR2, P_RETCODE OUT NOCOPY NUMBER, P_BUYER_ID IN NUMBER, P_OU IN NUMBER, P_PO_STATUS IN VARCHAR2
                                           , P_USER_ID IN NUMBER, P_REQ_ID IN NUMBER DEFAULT NULL, P_DESTINATION_ORGANIZATION_ID IN NUMBER DEFAULT NULL)
    IS
        v_tq_po_exists             VARCHAR2 (20);                -- CCR0006402

        CURSOR Cur_PO_HEADERS_interface IS
            SELECT DISTINCT
                   'STANDARD' TYPE_LOOKUP_CODE,                     --Constant
                   'PO Data Elements' ATTRIBUTE_CATEGORY,           --Constant
                   --Header Fields (non grouping)
                   PRHA.INTERFACE_SOURCE_CODE,
                   CASE
                       WHEN APS.ATTRIBUTE2 = 'Y' THEN 'Y'
                       ELSE 'N'
                   END ATTRIBUTE11,                                 --GTN Flag
                   APSS.ATTRIBUTE3 ATTRIBUTE12,                   --Prepayment
                   NVL (PRLA.CURRENCY_CODE, GL.CURRENCY_CODE) CURRENCY_CODE,
                   CASE
                       WHEN GL.CURRENCY_CODE != PRLA.CURRENCY_CODE
                       THEN
                           PRLA.RATE_TYPE
                       ELSE
                           NULL
                   END RATE_TYPE,
                   CASE
                       WHEN GL.CURRENCY_CODE != PRLA.CURRENCY_CODE
                       THEN
                           PRLA.RATE_DATE
                       ELSE
                           NULL
                   END RATE_DATE,
                   CASE
                       WHEN GL.CURRENCY_CODE != PRLA.CURRENCY_CODE THEN -- round(PRLA.rate,2)
                                                                        NULL
                       ELSE NULL
                   END RATE,
                   DECODE (
                       PRLA.PCARD_FLAG,
                       'Y', PRHA.PCARD_ID,
                       'S', NVL (
                                (PO_PCARD_PKG.GET_VALID_PCARD_ID (-99999, APS.VENDOR_ID, APSS.VENDOR_SITE_ID)),
                                -99999),
                       'N', NULL) PCARD_ID,
                   --(grouping fields)
                   PRHA.ORG_ID,                                     --Grouping
                   PRLA.SUGGESTED_BUYER_ID AGENT_ID,                --Grouping
                   APS.VENDOR_ID,                                   --Grouping
                   APSS.VENDOR_SITE_ID,                             --Grouping
                   CASE
                       WHEN PRLA.DROP_SHIP_FLAG = 'Y' THEN HROU.LOCATION_ID
                       ELSE PRLA.DELIVER_TO_LOCATION_ID
                   END SHIP_TO_LOCATION_ID,                         --Grouping
                   ITEM.SEGMENT1 BRAND,                             --Grouping
                   CASE
                       WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                       THEN
                           CASE
                               WHEN HRORG.NAME = 'Deckers US OU'
                               THEN
                                   'SFS'
                               WHEN HRORG.NAME = 'Deckers Macau OU'
                               THEN
                                   'INTL_DIST'
                               ELSE
                                   'UNKNOWNDS'
                           END
                       ELSE
                           CASE
                               WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%'
                               THEN
                                   'SAMPLE'
                               WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE'
                               THEN
                                   'B-GRADE'
                               ELSE
                                   'STANDARD'
                           END
                   END ATTRIBUTE10, --PO Type                                     --Grouping
                   NULL X_FACTORY_DATE, --Writing Need By Date directly       --Grouping
                      OOH.ORDER_NUMBER
                   || '-'
                   || PRLA.DESTINATION_ORGANIZATION_ID GROUP_CODE, -- CCR0007154--Grouping
                   --Category and Need By date are written to POHI to facililiate grouping in the lines query
                   --These will be cleared out before imported to POs
                   CASE
                       WHEN PRLA.ORG_ID IN
                                (SELECT ORGANIZATION_ID
                                   FROM HR_OPERATING_UNITS
                                  WHERE NAME IN
                                            ('Deckers US OU', 'Deckers Macau EMEA OU')) --CCR0007979
                       THEN
                           CASE
                               WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                               THEN
                                   NULL
                               ELSE
                                   CASE
                                       WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%'
                                       THEN
                                           NULL
                                       WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE'
                                       THEN
                                           NULL
                                       WHEN ITEM.SEGMENT3 LIKE 'POP'
                                       THEN
                                           NULL
                                       ELSE
                                           ITEM.CATEGORY_ID
                                   END
                           END
                       ELSE
                           NULL
                   END ATTRIBUTE13, --Category                                   --Grouping
                   TO_CHAR (PRLA.NEED_BY_DATE, 'YYYY/MM/DD') ATTRIBUTE14, --Grouping
                   --To facilitate calculation of XFDate
                   NVL (PRLA.DROP_SHIP_FLAG, 'N') DROP_SHIP_FLAG,   --Grouping
                   NVL (ICO_COPY.TERRITORY_CODE, HL.COUNTRY) DEST_COUNTRY, --Grouping
                   APSS.VENDOR_SITE_CODE,
                   TRUNC (PRLA.NEED_BY_DATE) NEED_BY_DATE,
                   PRHA.REQUISITION_HEADER_ID,         -- Added for CCR0006402
                   OOH.ORDER_NUMBER                              -- CCR0007154
              FROM PO.PO_REQUISITION_HEADERS_ALL PRHA,
                   PO.PO_REQUISITION_LINES_ALL PRLA,
                   PO_REQ_DISTRIBUTIONS_ALL PRDA,
                   AP.AP_SUPPLIERS APS,
                   AP.AP_SUPPLIER_SITES_ALL APSS,
                   HR_ALL_ORGANIZATION_UNITS HROU,
                   HR_ALL_ORGANIZATION_UNITS HRORG,
                   HR_LOCATIONS HL,
                   INV.MTL_PARAMETERS MP,
                   GL_LEDGERS GL,
                   OE_DROP_SHIP_SOURCES ODS,
                   OE_ORDER_HEADERS_ALL OOH,
                   (SELECT MSIB.INVENTORY_ITEM_ID, MCB.SEGMENT1, MCB.SEGMENT3,
                           MSIB.ATTRIBUTE28 ITEM_TYPE, MCB.CATEGORY_ID
                      FROM MTL_ITEM_CATEGORIES MIC, INV.MTL_CATEGORIES_B MCB, APPLSYS.FND_ID_FLEX_STRUCTURES FFS,
                           MTL_SYSTEM_ITEMS_B MSIB
                     WHERE     1 = 1
                           AND MSIB.INVENTORY_ITEM_ID = MIC.INVENTORY_ITEM_ID
                           AND MSIB.ORGANIZATION_ID = MIC.ORGANIZATION_ID
                           AND MSIB.ORGANIZATION_ID = 106
                           --
                           AND MIC.CATEGORY_ID = MCB.CATEGORY_ID
                           AND MIC.CATEGORY_SET_ID = 1
                           --
                           AND MCB.STRUCTURE_ID = FFS.ID_FLEX_NUM
                           --
                           AND FFS.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                           AND FFS.APPLICATION_ID = 401
                           AND FFS.ID_FLEX_CODE = 'MCAT') ITEM,
                   (SELECT DSS.REQUISITION_LINE_ID, FTV.TERRITORY_SHORT_NAME, FTV.TERRITORY_CODE
                      FROM OE_ORDER_HEADERS_ALL OOHA, ONT.OE_ORDER_LINES_ALL OOLA, ONT.OE_DROP_SHIP_SOURCES DSS,
                           PO.PO_LINES_ALL PLA, HZ_CUST_SITE_USES_ALL HCAS, HZ_CUST_ACCT_SITES_ALL HCASA,
                           HZ_PARTY_SITES HPS, HZ_LOCATIONS HL, FND_TERRITORIES_TL FTV
                     WHERE     OOLA.LINE_ID = DSS.LINE_ID
                           AND OOLA.INVENTORY_ITEM_ID = PLA.ITEM_ID
                           AND OOLA.ORG_ID =
                               (SELECT ORGANIZATION_ID
                                  FROM HR_OPERATING_UNITS
                                 WHERE NAME = 'Deckers Macau OU')
                           AND OOLA.LINE_ID =
                               TO_NUMBER (NVL (PLA.ATTRIBUTE5, '1'))
                           AND PLA.ATTRIBUTE_CATEGORY =
                               'Intercompany PO Copy'
                           AND DSS.HEADER_ID = OOHA.HEADER_ID
                           AND HCASA.CUST_ACCT_SITE_ID =
                               HCAS.CUST_ACCT_SITE_ID
                           AND HPS.PARTY_SITE_ID = HCASA.PARTY_SITE_ID
                           AND HL.LOCATION_ID = HPS.LOCATION_ID
                           AND FTV.TERRITORY_CODE = HL.COUNTRY
                           AND HCAS.SITE_USE_ID = OOHA.SHIP_TO_ORG_ID
                           AND EXISTS
                                   (SELECT NULL
                                      FROM PO_REQUISITION_LINES_ALL PRLA1
                                     WHERE     PRLA1.REQUISITION_LINE_ID =
                                               DSS.REQUISITION_LINE_ID
                                           AND PRLA1.DROP_SHIP_FLAG = 'Y'))
                   ICO_COPY
             WHERE     1 = 1
                   AND PRHA.REQUISITION_HEADER_ID =
                       PRLA.REQUISITION_HEADER_ID
                   AND PRDA.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
                   AND PRHA.AUTHORIZATION_STATUS = 'APPROVED'
                   AND PRLA.ORG_ID = P_OU
                   AND NVL (PRLA.SUGGESTED_BUYER_ID, -999) = P_BUYER_ID
                   AND NVL (PRLA.LINE_LOCATION_ID, -999) = -999
                   AND NVL (PRLA.CANCEL_FLAG, 'N') = 'N'
                   AND PRHA.REQUISITION_HEADER_ID =
                       NVL (P_REQ_ID, PRHA.REQUISITION_HEADER_ID)
                   AND NVL (PRLA.CLOSED_CODE, 'OPEN') <> 'FINALLY CLOSED' -- ADDED CCR0006820
                   AND PRLA.DESTINATION_ORGANIZATION_ID =
                       NVL (P_DESTINATION_ORGANIZATION_ID,
                            PRLA.DESTINATION_ORGANIZATION_ID) -- ADDED CCR0006820
                   AND PRLA.REQUISITION_LINE_ID = ODS.REQUISITION_LINE_ID
                   AND PRLA.REQUISITION_HEADER_ID = ODS.REQUISITION_HEADER_ID
                   AND ODS.HEADER_ID = OOH.HEADER_ID
                   --Suppliers
                   AND PRLA.VENDOR_ID = APS.VENDOR_ID
                   AND (PRLA.VENDOR_SITE_ID = APSS.VENDOR_SITE_ID OR PRLA.SUGGESTED_VENDOR_LOCATION = APSS.VENDOR_SITE_CODE)
                   AND PRLA.ORG_ID = APSS.ORG_ID
                   AND APSS.VENDOR_ID = APS.VENDOR_ID
                   --Dest Org
                   AND HROU.ORGANIZATION_ID =
                       NVL (
                           (SELECT PORL.DESTINATION_ORGANIZATION_ID
                              FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL, OE_ORDER_HEADERS_ALL OHA,
                                   OE_ORDER_LINES_ALL OLA, MTL_RESERVATIONS MTR
                             WHERE     OHA.HEADER_ID = OLA.HEADER_ID
                                   AND PORH.REQUISITION_HEADER_ID =
                                       PORL.REQUISITION_HEADER_ID
                                   AND OLA.SOURCE_DOCUMENT_ID =
                                       PORH.REQUISITION_HEADER_ID
                                   AND OLA.SOURCE_DOCUMENT_LINE_ID =
                                       PORL.REQUISITION_LINE_ID
                                   AND PRLA.REQUISITION_LINE_ID =
                                       MTR.SUPPLY_SOURCE_LINE_ID
                                   AND PRLA.REQUISITION_HEADER_ID =
                                       MTR.SUPPLY_SOURCE_HEADER_ID -- SRC_HDR_ID
                                   AND MTR.SUPPLY_SOURCE_TYPE_ID = 17
                                   AND MTR.DEMAND_SOURCE_LINE_ID =
                                       OLA.LINE_ID --  AND PRHA.INTERFACE_SOURCE_CODE = 'CTO'
                                                  ),
                           PRLA.DESTINATION_ORGANIZATION_ID)
                   --Req OU
                   AND PRLA.ORG_ID = HRORG.ORGANIZATION_ID
                   --Dest Location
                   AND HROU.LOCATION_ID = HL.LOCATION_ID
                   --Dest Org
                   AND PRLA.DESTINATION_ORGANIZATION_ID = MP.ORGANIZATION_ID
                   AND (MP.ATTRIBUTE13 = '2' OR MP.ATTRIBUTE13 IS NULL)
                   --General Ledger
                   AND PRDA.SET_OF_BOOKS_ID = GL.LEDGER_ID
                   --Items
                   AND PRLA.ITEM_ID = ITEM.INVENTORY_ITEM_ID
                   --ISO Copy
                   AND PRLA.REQUISITION_LINE_ID =
                       ICO_COPY.REQUISITION_LINE_ID(+);

        CURSOR Cur_PO_LINES_interface IS
              SELECT 'PO Line Locations Elements' SHIPMENT_ATTRIBUTE_CATEGORY,
                     'PO Data Elements' LINE_ATTRIBUTE_CATEGORY,
                     PRLA.ITEM_ID,
                     PRLA.UNIT_PRICE,
                     PRLA.QUANTITY,
                     PRLA.ITEM_DESCRIPTION,
                     PRLA.UNIT_MEAS_LOOKUP_CODE,
                     PRLA.CATEGORY_ID,
                     PRLA.REQUISITION_LINE_ID,
                     PRLA.JOB_ID,
                     PRLA.NEED_BY_DATE - 10 NEED_BY_DATE, --TODO: Significance of need_by_date -10?
                     PRLA.LINE_TYPE_ID,
                     PRLA.DELIVER_TO_LOCATION_ID,
                     POHI.INTERFACE_HEADER_ID,
                     POHI.SHIP_TO_LOCATION_ID,
                     POHI.ATTRIBUTE1 SHIPMENT_ATTRIBUTE4,
                     POHI.ATTRIBUTE10,
                     NULL SHIPMENT_ATTRIBUTE10,        --Need ship method calc
                     TRIM (ITEM.SEGMENT1) LINE_ATTRIBUTE1,
                     TRIM (ITEM.SEGMENT3) LINE_ATTRIBUTE2,
                     'Y' SHIPMENT_ATTRIBUTE6, --Flag for interco price recalc --CCR0008186
                     APS.VENDOR_ID,
                     APSS.VENDOR_SITE_CODE LINE_ATTRIBUTE7,
                     APPS.IID_TO_SKU (PRLA.ITEM_ID) SKU,
                     NVL (PRLA.DROP_SHIP_FLAG, 'N') DROP_SHIP_FLAG,
                     NVL (ICO_COPY.TERRITORY_CODE, HL.COUNTRY) DEST_COUNTRY,
                     CASE
                         WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%' THEN 'SAMPLE'
                         WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE' THEN 'B-GRADE'
                         ELSE ITEM.ITEM_TYPE
                     END ITEM_TYPE,
                     PRLA.NOTE_TO_RECEIVER                       -- CCR0006402
                FROM PO_REQUISITION_HEADERS_ALL PRHA,
                     PO_REQUISITION_LINES_ALL PRLA,
                     AP_SUPPLIERS APS,
                     AP_SUPPLIER_SITES_ALL APSS,
                     PO_HEADERS_INTERFACE POHI,
                     MTL_SYSTEM_ITEMS_B MSB,                      --CCR0007154
                     MTL_PARAMETERS MP,
                     HR_ALL_ORGANIZATION_UNITS HROU,
                     HR_LOCATIONS HL,
                     HR_ALL_ORGANIZATION_UNITS HRORG,
                     OE_DROP_SHIP_SOURCES ODS,
                     OE_ORDER_HEADERS_ALL OOH,
                     (SELECT MSIB.INVENTORY_ITEM_ID, MCB.SEGMENT1, MCB.SEGMENT3,
                             MSIB.ATTRIBUTE28 ITEM_TYPE, MCB.CATEGORY_ID
                        FROM MTL_ITEM_CATEGORIES MIC, INV.MTL_CATEGORIES_B MCB, APPLSYS.FND_ID_FLEX_STRUCTURES FFS,
                             MTL_SYSTEM_ITEMS_B MSIB
                       WHERE     1 = 1
                             AND MSIB.INVENTORY_ITEM_ID = MIC.INVENTORY_ITEM_ID
                             AND MSIB.ORGANIZATION_ID = MIC.ORGANIZATION_ID
                             AND MSIB.ORGANIZATION_ID = 106
                             AND MIC.CATEGORY_ID = MCB.CATEGORY_ID
                             AND MIC.CATEGORY_SET_ID = 1
                             AND MCB.STRUCTURE_ID = FFS.ID_FLEX_NUM
                             AND FFS.APPLICATION_ID = 401
                             AND FFS.ID_FLEX_CODE = 'MCAT') ITEM,
                     (SELECT DSS.REQUISITION_LINE_ID, FTV.TERRITORY_SHORT_NAME, FTV.TERRITORY_CODE
                        FROM OE_ORDER_HEADERS_ALL OOHA, ONT.OE_ORDER_LINES_ALL OOLA, ONT.OE_DROP_SHIP_SOURCES DSS,
                             PO_LINES_ALL PLA, HZ_CUST_SITE_USES_ALL HCAS, HZ_CUST_ACCT_SITES_ALL HCASA,
                             HZ_PARTY_SITES HPS, HZ_LOCATIONS HL, FND_TERRITORIES_VL FTV
                       WHERE     OOLA.LINE_ID = DSS.LINE_ID
                             AND OOLA.INVENTORY_ITEM_ID = PLA.ITEM_ID
                             AND OOLA.ORG_ID =
                                 (SELECT ORGANIZATION_ID
                                    FROM HR_OPERATING_UNITS
                                   WHERE NAME = 'Deckers Macau OU')
                             AND OOLA.LINE_ID = TO_NUMBER (PLA.ATTRIBUTE5)
                             AND PLA.ATTRIBUTE_CATEGORY =
                                 'Intercompany PO Copy'
                             AND DSS.HEADER_ID = OOHA.HEADER_ID
                             AND HCASA.CUST_ACCT_SITE_ID =
                                 HCAS.CUST_ACCT_SITE_ID
                             AND HPS.PARTY_SITE_ID = HCASA.PARTY_SITE_ID
                             AND HL.LOCATION_ID = HPS.LOCATION_ID
                             AND FTV.TERRITORY_CODE = HL.COUNTRY
                             AND HCAS.SITE_USE_ID = OOHA.SHIP_TO_ORG_ID
                             AND EXISTS
                                     (SELECT NULL
                                        FROM PO_REQUISITION_LINES_ALL PRLA1
                                       WHERE     PRLA1.REQUISITION_LINE_ID =
                                                 DSS.REQUISITION_LINE_ID
                                             AND PRLA1.DROP_SHIP_FLAG = 'Y'))
                     ICO_COPY
               WHERE     1 = 1
                     AND PRHA.REQUISITION_HEADER_ID =
                         PRLA.REQUISITION_HEADER_ID
                     AND PRHA.AUTHORIZATION_STATUS = 'APPROVED'
                     AND PRHA.ORG_ID = P_OU
                     AND NVL (PRLA.SUGGESTED_BUYER_ID, -999) = P_BUYER_ID
                     AND NVL (PRLA.LINE_LOCATION_ID, -999) = -999
                     AND NVL (PRLA.CANCEL_FLAG, 'N') = 'N'
                     AND PRHA.REQUISITION_HEADER_ID =
                         NVL (P_REQ_ID, PRHA.REQUISITION_HEADER_ID)
                     AND NVL (PRLA.CLOSED_CODE, 'OPEN') <> 'FINALLY CLOSED'
                     AND PRLA.DESTINATION_ORGANIZATION_ID =
                         NVL (P_DESTINATION_ORGANIZATION_ID,
                              PRLA.DESTINATION_ORGANIZATION_ID)
                     AND PRLA.ITEM_ID = MSB.INVENTORY_ITEM_ID     --CCR0007154
                     AND PRLA.DESTINATION_ORGANIZATION_ID = MSB.ORGANIZATION_ID -- CCR0007154
                     AND PRLA.REQUISITION_LINE_ID = ODS.REQUISITION_LINE_ID
                     AND PRLA.REQUISITION_HEADER_ID = ODS.REQUISITION_HEADER_ID
                     AND ODS.HEADER_ID = OOH.HEADER_ID
                     --Suppliers
                     AND PRLA.VENDOR_ID = APS.VENDOR_ID
                     AND (APSS.VENDOR_SITE_ID = PRLA.VENDOR_SITE_ID OR APSS.VENDOR_SITE_CODE = PRLA.SUGGESTED_VENDOR_LOCATION)
                     AND PRLA.ORG_ID = APSS.ORG_ID
                     AND APS.VENDOR_ID = APSS.VENDOR_ID
                     --Dest Location
                     AND HROU.LOCATION_ID = HL.LOCATION_ID
                     AND HROU.ORGANIZATION_ID =
                         NVL (
                             (SELECT PORL.DESTINATION_ORGANIZATION_ID
                                FROM PO_REQUISITION_HEADERS_ALL PORH, PO_REQUISITION_LINES_ALL PORL, OE_ORDER_HEADERS_ALL OHA,
                                     OE_ORDER_LINES_ALL OLA, MTL_RESERVATIONS MTR
                               WHERE     OHA.HEADER_ID = OLA.HEADER_ID
                                     AND PORH.REQUISITION_HEADER_ID =
                                         PORL.REQUISITION_HEADER_ID
                                     AND OLA.SOURCE_DOCUMENT_ID =
                                         PORH.REQUISITION_HEADER_ID
                                     AND OLA.SOURCE_DOCUMENT_LINE_ID =
                                         PORL.REQUISITION_LINE_ID
                                     --  AND OLA.INVENTORY_ITEM_ID = PORL.ITEM_ID
                                     AND PRLA.REQUISITION_LINE_ID =
                                         MTR.SUPPLY_SOURCE_LINE_ID
                                     AND PRLA.REQUISITION_HEADER_ID =
                                         MTR.SUPPLY_SOURCE_HEADER_ID -- SRC_HDR_ID
                                     AND MTR.DEMAND_SOURCE_LINE_ID =
                                         OLA.LINE_ID
                                     AND PRHA.INTERFACE_SOURCE_CODE = 'CTO'),
                             PRLA.DESTINATION_ORGANIZATION_ID)
                     --Items
                     AND PRLA.ITEM_ID = ITEM.INVENTORY_ITEM_ID
                     --Dest Org
                     AND PRLA.DESTINATION_ORGANIZATION_ID = MP.ORGANIZATION_ID
                     AND NVL (MP.ATTRIBUTE13, '2') = '2'
                     --ISO Copy
                     AND PRLA.REQUISITION_LINE_ID =
                         ICO_COPY.REQUISITION_LINE_ID(+)
                     --Req OU
                     AND PRLA.ORG_ID = HRORG.ORGANIZATION_ID
                     --Grouping to POHI
                     AND POHI.ORG_ID = PRHA.ORG_ID
                     AND POHI.AGENT_ID = PRLA.SUGGESTED_BUYER_ID
                     AND POHI.VENDOR_ID = APS.VENDOR_ID
                     AND POHI.VENDOR_SITE_ID = APSS.VENDOR_SITE_ID
                     AND POHI.SHIP_TO_LOCATION_ID =
                         (CASE
                              WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                              THEN
                                  HROU.LOCATION_ID
                              ELSE
                                  PRLA.DELIVER_TO_LOCATION_ID
                          END)
                     AND POHI.BATCH_ID = P_BATCH_ID
                     AND POHI.ATTRIBUTE10 =
                         CASE
                             WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                             THEN
                                 CASE
                                     WHEN HRORG.NAME = 'Deckers US OU'
                                     THEN
                                         'SFS'
                                     --Commented below code for change 1.7
                                     /*WHEN HRORG.NAME = 'Deckers Macau OU'
                                      THEN
                                         'INTL_DIST'*/
                                     /* Start of changes for 1.7*/
                                     --Added below code to return po type as 'TQ_FACTORY' if factory PO is for a TQ PO
                                     WHEN     HRORG.NAME = 'Deckers Macau OU'
                                          AND NVL (v_tq_po_exists, 'N') <> 'Y'
                                     THEN
                                         'INTL_DIST'
                                     WHEN     HRORG.NAME = 'Deckers Macau OU'
                                          AND NVL (v_tq_po_exists, 'N') = 'Y'
                                     THEN
                                         'TQ_FACTORY'
                                     /*End of changes for 1,7*/
                                     ELSE
                                         'UNKNOWNDS'
                                 END
                             ELSE
                                 CASE
                                     WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%'
                                     THEN
                                         'SAMPLE'
                                     WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE'
                                     THEN
                                         'B-GRADE'
                                     ELSE
                                         'STANDARD'
                                 END
                         END
                     AND POHI.GROUP_CODE =
                            OOH.ORDER_NUMBER
                         || '-'
                         || PRLA.DESTINATION_ORGANIZATION_ID     -- CCR0007154
                     AND NVL (POHI.ATTRIBUTE13, '-NONE-') =
                         CASE
                             WHEN PRLA.ORG_ID IN
                                      (SELECT ORGANIZATION_ID
                                         FROM HR_OPERATING_UNITS
                                        WHERE NAME IN
                                                  ('Deckers US OU', 'Deckers Macau EMEA OU')) --CCR0007979
                             THEN
                                 CASE
                                     WHEN PRLA.DROP_SHIP_FLAG = 'Y'
                                     THEN
                                         '-NONE-'
                                     ELSE
                                         CASE
                                             WHEN ITEM.ITEM_TYPE LIKE 'SAMPLE%'
                                             THEN
                                                 '-NONE-'
                                             WHEN ITEM.ITEM_TYPE LIKE 'B%GRADE'
                                             THEN
                                                 '-NONE-'
                                             WHEN ITEM.SEGMENT3 LIKE 'POP'
                                             THEN
                                                 '-NONE-'
                                             ELSE
                                                 TO_CHAR (ITEM.CATEGORY_ID)
                                         END
                                 END
                             ELSE
                                 '-NONE-'
                         END
                     AND POHI.ATTRIBUTE14 =
                         TO_CHAR (PRLA.NEED_BY_DATE, 'YYYY/MM/DD')
                     AND POHI.ATTRIBUTE15 = PRHA.REQUISITION_HEADER_ID -- CCR0006820
            ORDER BY POHI.INTERFACE_HEADER_ID, SUBSTR (MSB.SEGMENT1, 1, INSTR (MSB.SEGMENT1, '-', -1)), TO_NUMBER (MSB.ATTRIBUTE10);

        V_batch_id                 NUMBER := P_BATCH_ID;

        v_buy_month                VARCHAR2 (20);
        v_buy_season               VARCHAR2 (20);

        v_xf_date                  VARCHAR2 (20);
        v_ship_method              VARCHAR2 (20);
        v_drop_ship_flag           VARCHAR2 (20);                -- CCR0006402
        v_processed_lines_count    NUMBER := 0;
        v_rejected_lines_count     NUMBER := 0;
        v_err_tolerance_exceeded   VARCHAR2 (100);

        v_return_status            VARCHAR2 (20);

        V_PO_STATUS                VARCHAR2 (50);

        n_header_cnt               NUMBER;
        n_line_cnt                 NUMBER;

        po_header_cnt              NUMBER;
        po_line_cnt                NUMBER;

        po_rejected_cnt            NUMBER;

        n_cnt                      NUMBER := 0;
        lv_po_type                 VARCHAR2 (50);       --Added for change 1.7
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, '--Populate Dist POI Trade : Enter');

        fnd_file.PUT_LINE (fnd_file.LOG,
                           'befor header insert in Dist POI' || P_batch_id);

        --Get buy month and buy season. These are not based on table data and therefore constant
        v_buy_month    := get_buy_month;
        v_buy_season   := get_buy_season;

        fnd_file.PUT_LINE (fnd_file.LOG,
                           'Buy Month in Dist POI : ' || v_buy_month);
        fnd_file.PUT_LINE (fnd_file.LOG,
                           'Buy Season in Dist POI : ' || v_buy_season);

        n_cnt          := 0;

        FOR PO_HEADERS_interface_REC IN Cur_PO_HEADERS_interface
        LOOP
            -- START CCR0006402
            v_tq_po_exists   := NULL;

            BEGIN
                SELECT 'Y'
                  INTO v_tq_po_exists
                  FROM apps.oe_drop_ship_sources ods, apps.oe_order_headers_all ooh, apps.po_headers_all pha
                 WHERE     ods.requisition_header_id =
                           po_headers_interface_rec.requisition_header_id
                       AND ods.header_id = ooh.header_id
                       AND ooh.cust_po_number = pha.segment1
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_tq_po_exists   := 'N';
                WHEN OTHERS
                THEN
                    v_tq_po_exists   := 'N';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error in Finding TQ PO Exists for Req Header id :: '
                        || po_headers_interface_rec.requisition_header_id
                        || ' :: '
                        || SQLERRM);
            END;

            --Start of changes for 1.7
            --If this factory PO is for a TQ PO then PO Type should be "TQ_FACTORY"
            IF NVL (v_tq_po_exists, 'N') = 'Y'
            THEN
                lv_po_type   := 'TQ_FACTORY';
            ELSE
                lv_po_type   := PO_HEADERS_interface_REC.ATTRIBUTE10;
            END IF;

            --End of changes for 1.7
            BEGIN
                SELECT DECODE (v_tq_po_exists, 'Y', 'T', PO_HEADERS_interface_REC.DROP_SHIP_FLAG)
                  INTO v_drop_ship_flag
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_drop_ship_flag   := NULL;
            END;

            -- END CCR0006402

            --Get XF Date from need by date
            v_xf_date        :=
                TO_CHAR (
                      PO_HEADERS_interface_REC.need_by_date
                    - get_transit_time (
                          PO_HEADERS_interface_REC.VENDOR_ID,
                          PO_HEADERS_interface_REC.VENDOR_SITE_CODE,
                          --PO_HEADERS_interface_REC.DROP_SHIP_FLAG, -- CCR0006402
                          v_drop_ship_flag,                      -- CCR0006402
                          PO_HEADERS_interface_REC.ATTRIBUTE10, --Added as default could vary by po_type
                          PO_HEADERS_interface_REC.DEST_COUNTRY),
                    'YYYY/MM/DD');


            INSERT INTO po_headers_interface (action, process_code, BATCH_ID,
                                              document_type_code, interface_header_id, created_by, document_subtype, agent_id, creation_date, vendor_id, vendor_site_id, currency_code, rate_type, rate_date, rate, pcard_id, group_code, ORG_ID, ship_to_location_id, attribute1, ATTRIBUTE_CATEGORY, ATTRIBUTE9, ATTRIBUTE8, ATTRIBUTE11, ATTRIBUTE10, ATTRIBUTE12, ATTRIBUTE13
                                              , ATTRIBUTE14, -- Added by Anil on 10-Apr-15, as part of GTN Phase II changes
                                                             ATTRIBUTE15) -- CCR0006820
                     VALUES ('ORIGINAL',
                             NULL,
                             P_batch_id,
                             'STANDARD',
                             po_headers_interface_s.NEXTVAL,
                             fnd_profile.VALUE ('USER_ID'),
                             PO_HEADERS_interface_REC.type_lookup_code,
                             PO_HEADERS_interface_REC.agent_id,
                             SYSDATE,
                             PO_HEADERS_interface_REC.vendor_id,
                             PO_HEADERS_interface_REC.vendor_site_id,
                             PO_HEADERS_interface_REC.currency_code,
                             PO_HEADERS_interface_REC.rate_type, --v_rate_type
                             PO_HEADERS_interface_REC.rate_date, --d_rate_date
                             PO_HEADERS_interface_REC.rate,           --n_rate
                             PO_HEADERS_interface_REC.pcard_id,   --n_pcard_id
                             PO_HEADERS_interface_REC.group_code,
                             PO_HEADERS_interface_REC.ORG_ID,
                             PO_HEADERS_interface_REC.ship_to_location_id,
                             v_xf_date,
                             PO_HEADERS_interface_REC.ATTRIBUTE_CATEGORY,
                             v_buy_month,
                             v_buy_season,
                             PO_HEADERS_interface_REC.ATTRIBUTE11,
                             --PO_HEADERS_interface_REC.ATTRIBUTE10,--Commented for change 1.7
                             lv_po_type,                --Added for change 1.7
                             PO_HEADERS_interface_REC.ATTRIBUTE12,
                             PO_HEADERS_interface_REC.ATTRIBUTE13,  --Category
                             PO_HEADERS_interface_REC.ATTRIBUTE14, --Need By Date
                             -- Added by Anil on 10-Apr-15, as part of GTN Phase II changes
                             PO_HEADERS_interface_REC.REQUISITION_HEADER_ID -- CCR0006820
                                                                           );

            n_cnt            := n_cnt + 1;
        END LOOP;

        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'after header insert. Reccords inserted in Dist POI : ' || n_cnt);

        BEGIN
            --Check if records were inserted into header. If not then exception is raised
            SELECT DISTINCT batch_id
              INTO v_batch_id
              FROM po_headers_interface
             WHERE batch_id = p_batch_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    'No Trade requisition selected in Dist POI');
                P_RETCODE   := 2;
                P_ERRBUF    := 'No Trade requisition selected in Dist POI';
                RETURN;
        END;

        n_cnt          := 0;

        FOR PO_LINES_interface_REC IN Cur_PO_LINES_interface
        LOOP
            v_ship_method   :=
                get_ship_method (PO_LINES_interface_REC.VENDOR_ID, PO_LINES_interface_REC.LINE_ATTRIBUTE7, PO_LINES_interface_REC.ATTRIBUTE10
                                 , PO_LINES_interface_REC.DEST_COUNTRY);


            INSERT INTO po_lines_interface (action, interface_line_id, interface_header_id, unit_price, quantity, item_description, unit_OF_MEASURE, category_id, job_id, need_by_date, line_type_id, --                                         vendor_product_num,
                                                                                                                                                                                                      ip_category_id, requisition_line_id, SHIP_TO_LOCATION_ID, shipment_attribute4, shipment_attribute7, -- Freight Pay Party CCR0007114
                                                                                                                                                                                                                                                                                                          shipment_attribute10, shipment_attribute_CATEGORY, LINE_ATTRIBUTE_CATEGORY_lines, LINE_ATTRIBUTE1, LINE_ATTRIBUTE2, LINE_ATTRIBUTE7, note_to_receiver, -- CCR0006402
                                                                                                                                                                                                                                                                                                                                                                                                                                                                 drop_ship_flag
                                            ,                    -- CCR0006402
                                              SHIPMENT_ATTRIBUTE6 --CCR0008186
                                                                 )
                 VALUES ('ORIGINAL', po_lines_interface_s.NEXTVAL, PO_LINES_interface_REC.interface_header_id, PO_LINES_interface_REC.unit_price, PO_LINES_interface_REC.quantity, PO_LINES_interface_REC.item_description, PO_LINES_interface_REC.unit_meas_lookup_code, PO_LINES_interface_REC.category_id, PO_LINES_interface_REC.job_id, PO_LINES_interface_REC.need_by_date, PO_LINES_interface_REC.line_type_id, --                      PO_LINES_interface_REC.vendor_product_num,
                                                                                                                                                                                                                                                                                                                                                                                                                       NULL, PO_LINES_interface_REC.requisition_line_id, PO_LINES_interface_REC.SHIP_TO_LOCATION_ID, PO_LINES_interface_REC.shipment_attribute4, 'customer', -- Freight Pay Party  CCR0007114
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             v_ship_method, PO_LINES_interface_REC.shipment_attribute_CATEGORY, PO_LINES_interface_REC.LINE_ATTRIBUTE_CATEGORY, PO_LINES_interface_REC.LINE_ATTRIBUTE1, PO_LINES_interface_REC.LINE_ATTRIBUTE2, PO_LINES_interface_REC.LINE_ATTRIBUTE7, PO_LINES_interface_REC.note_to_receiver, -- CCR0006402
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 PO_LINES_interface_REC.drop_ship_flag
                         ,                                       -- CCR0006402
                           PO_LINES_interface_REC.SHIPMENT_ATTRIBUTE6 -- CCR0008186
                                                                     );

            n_cnt   := n_cnt + 1;
        END LOOP;

        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'after line insert. Reccords inserted in Dist POI : ' || n_cnt);

        fnd_file.PUT_LINE (fnd_file.LOG, 'Clear out attributes in Dist POI');

        --Clear out extra field values added for line grouping
        UPDATE PO_HEADERS_INTERFACE
           SET ATTRIBUTE13 = NULL, ATTRIBUTE14 = NULL, ATTRIBUTE15 = NULL -- ADDED CCR0006820
         WHERE BATCH_ID = P_BATCH_ID;

        -- Start CCR0006820
        --Get POI recordcounts. Use to validate against POs later
        SELECT COUNT (*)
          INTO n_header_cnt
          FROM po_headers_interface phi
         WHERE batch_id = v_batch_id;

        SELECT COUNT (*)
          INTO n_line_cnt
          FROM po_headers_interface phi, po_lines_interface pli
         WHERE     phi.interface_header_id = pli.interface_header_id
               AND batch_id = v_batch_id;


        --Check setting and set PO status if necessary
        IF FND_PROFILE.VALUE ('XXD_PO_DATE_UPDATE') = 'Y'
        THEN
            V_PO_STATUS   := 'INCOMPLETE';
        ELSE
            V_PO_STATUS   := UPPER (P_PO_STATUS);
        END IF;

        fnd_file.PUT_LINE (fnd_file.LOG,
                           'Set PO status in Dist POI' || V_PO_STATUS);

        --Run PO Import(using function call as oposed to concurrent request so we can avoid COMMIT

        --Using this process will create all POs using the same p_batch_id.
        --Option for Drop ship type POs. Use  PO_INTERFACE_S.create_documents. Note: this function would require multiple iterations for multiple
        --PO interface headers tied to the same p_batch_id. The resultant POs would then have unique batch_ids
        --Also  PO_INTERFACE_S.create_documents does not havce a non commit option
        fnd_file.PUT_LINE (fnd_file.LOG,
                           'Start PO import process for Dist POI');
        APPS.PO_PDOI_PVT.start_process (
            p_api_version                  => 1.0,
            p_init_msg_list                => FND_API.G_TRUE,
            p_validation_level             => NULL,
            p_commit                       => FND_API.G_FALSE,
            x_return_status                => v_return_status,
            p_gather_intf_tbl_stat         => 'N',
            p_calling_module               => NULL,
            p_selected_batch_id            => v_batch_id,
            p_batch_size                   => NULL,
            p_buyer_id                     => NULL,
            p_document_type                => 'STANDARD',
            p_document_subtype             => NULL,
            p_create_items                 => 'N',
            p_create_sourcing_rules_flag   => 'N',
            p_rel_gen_method               => NULL,
            p_sourcing_level               => NULL,
            p_sourcing_inv_org_id          => NULL,
            p_approved_status              => V_PO_STATUS,
            p_process_code                 => NULL,
            p_interface_header_id          => NULL,
            p_org_id                       => P_OU,
            p_ga_flag                      => NULL,
            p_submit_dft_flag              => 'N',
            p_role                         => 'BUYER',
            p_catalog_to_expire            => NULL,
            p_err_lines_tolerance          => NULL,
            p_group_lines                  => 'N',
            p_group_shipments              => 'N',
            p_clm_flag                     => NULL,         --CLM PDOI Project
            x_processed_lines_count        => v_processed_lines_count,
            x_rejected_lines_count         => v_rejected_lines_count,
            x_err_tolerance_exceeded       => v_err_tolerance_exceeded);

        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'Check PO import error in Dist POI ' || v_return_status);

        --Check for process error
        --If this process fails then we need to exit
        IF v_return_status = (FND_API.G_RET_STS_ERROR)
        THEN
            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    'CREATE api error in Dist POI :' || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
                P_ERRBUF   :=
                       P_ERRBUF
                    || 'CREATE api error in Dist POI:'
                    || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            --Do we rollback inserts to POI?
            ROLLBACK;

            P_retCODE   := 2;
            RETURN;
        ELSIF v_return_status = (FND_API.G_RET_STS_ERROR)
        THEN
            fnd_file.PUT_LINE (fnd_file.LOG, 'Dist POI Error = ''E''');
            fnd_file.PUT_LINE (fnd_file.LOG,
                               'Count Dist POI ' || FND_MSG_PUB.count_msg);

            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                       'CREATE API UNEXPECTED ERROR in Dist POI :'
                    || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));

                P_ERRBUF   :=
                    SUBSTR (
                           P_ERRBUF
                        || 'CREATE API UNEXPECTED ERROR in Dist POI :'
                        || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'),
                        1,
                        200);
            END LOOP;

            --Do we rollback inserts to POI?
            ROLLBACK;

            P_retCODE   := 2;
            RETURN;
        END IF;

        --Log generated PO lines and POI errors to the log file
        fnd_file.PUT_LINE (fnd_file.LOG, 'Show PO Data Dist POI ');
        --Show PO Data imported (Log only)
        SHOW_BATCH_PO_DATA (v_batch_id);

        fnd_file.PUT_LINE (fnd_file.LOG, 'Show POI Errors Dist POI ');
        --Show PO Interface Errors (Log only)
        SHOW_BATCH_POI_ERRORS (v_batch_id);

        --Check PO record counts after import
        SELECT COUNT (*)
          INTO po_header_cnt
          FROM po_headers_all pha, po_headers_interface phi
         WHERE     pha.po_header_id = phi.po_header_id
               AND phi.batch_id = v_batch_id;

        SELECT COUNT (*)
          INTO po_line_cnt
          FROM po_lines_all pla, po_headers_all pha, po_headers_interface phi
         WHERE     pha.po_header_id = phi.po_header_id
               AND pla.po_header_id = pha.po_header_id
               AND phi.batch_id = v_batch_id;

        --compare PO counts to POI counts
        IF po_header_cnt != n_header_cnt OR po_line_cnt != n_line_cnt
        THEN
            --POs created does not match POI. Check for REJECTED POs
            --Report rejected POs but continue processing.
            SELECT COUNT (*)
              INTO po_rejected_cnt
              FROM po_headers_interface
             WHERE process_code = 'REJECTED' AND batch_id = v_batch_id;

            fnd_file.PUT_LINE (
                fnd_file.LOG,
                   v_batch_id
                || ' POs were rejected. See po_interface_errors for details in Dist POI');

            IF po_header_cnt = 0
            THEN
                P_ERRBUF    :=
                    'All POI records failed to interface to POs in Dist POI';
                P_retCODE   := 1;                             --Return warning
                ROLLBACK;
                RETURN;
            END IF;
        END IF;


        fnd_file.PUT_LINE (fnd_file.LOG, 'Update Need by Date');

        --Modification starts for Defect#3280
        IF FND_PROFILE.VALUE ('XXD_PO_DATE_UPDATE') = 'Y'
        THEN
            --This was aded for a workaround for defect 3280 in Quality Center (BT in Oct 2015). There was a corresponding Oracle-SR raised
            --for this issue. No resolution was found and this workaround added.This was retested extensively in Jan -17 and the problem was not reproduced. Therefore this has been remarked out.

            --Unremarked on 3/29 : Re-occurred on Production:
            --Note POI is correct but the neeed by date is altered during import
            XXD_UPDATE_NEEDBY_DATE (v_batch_id, P_PO_STATUS, P_ERRBUF,
                                    P_retCODE);

            XXD_APPROVE_PO (v_batch_id, P_PO_STATUS, P_ERRBUF,
                            P_retCODE);
        END IF;

        --Check error return
        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'Update Need by Date return Distributor :: ' || P_retCODE);

        COMMIT;

        fnd_file.PUT_LINE (fnd_file.LOG, 'Update Drop Ship Distributor');

        --UPDATE_DROP_SHIP is required for drop_ship POs as APPS.PO_PDOI_PVT.start_process does not populate this data after PO creation
        UPDATE_DROP_SHIP (v_batch_id);

        --fnd_file.PUT_LINE (fnd_file.LOG, '--Populate POI Non-Trade : Exit');
        fnd_file.PUT_LINE (fnd_file.LOG,
                           '--Populate Distributor POI Trade : Exit'); -- MODIFIED CCR0006820  REMOVED NON
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.PUT_LINE (
                fnd_file.LOG, --'--Populate POI Non-Trade : Exception ' || SQLERRM); -- MODIFIED CCR0006820  REMOVED NON
                '--Populate Distributor POI Trade : Exception ' || SQLERRM); -- MODIFIED CCR0006820  REMOVED NON
    END xxd_populate_dist_poi_trade;

    -- END CCR0007154
    --Added below procedure for change 1.7
    PROCEDURE update_so_intercompany
    AS
    BEGIN
        UPDATE oe_order_lines_all oola
           SET attribute16   =
                   (SELECT DISTINCT TO_CHAR (pda.line_location_id)
                      FROM apps.po_distributions_all pda, apps.mtl_reservations mr
                     WHERE     mr.demand_source_line_id = oola.line_id
                           AND mr.organization_id = oola.ship_from_org_id
                           AND mr.supply_source_type_id = 1 --Added by BT Technology Team on 06-Oct-2015 for HPQC 3460, v 1.1
                           AND pda.line_location_id =
                               mr.supply_source_line_id)
         WHERE     line_id IN
                       (SELECT demand_source_line_id
                          FROM apps.mtl_reservations
                         WHERE     organization_id IN
                                       (SELECT TO_NUMBER (lookup_code) --Change for US Direct Ship
                                          FROM fnd_lookup_values
                                         WHERE     lookup_type =
                                                   'XXD_PO_B2B_ORGANIZATIONS'
                                               AND enabled_flag = 'Y'
                                               AND language = 'US')
                               AND supply_source_type_id = 1)
               AND (   attribute16 IS NULL
                    OR attribute16 <>
                       (SELECT DISTINCT TO_CHAR (pda.line_location_id) -- start of change done by Ravi for the DFCT0011409
                          FROM apps.po_distributions_all pda, apps.mtl_reservations mr
                         WHERE     mr.demand_source_line_id = oola.line_id
                               AND mr.organization_id = oola.ship_from_org_id
                               AND mr.supply_source_type_id = 1 --Added by BT Technology Team on 06-Oct-2015 for HPQC 3460, v 1.1
                               AND pda.line_location_id =
                                   mr.supply_source_line_id));
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.PUT_LINE (
                fnd_file.LOG,
                'Error While Update SO with PO Information' || SQLERRM);
    END;

    /*****-Start Externally accessible procedures****
    */

    --Main processing routing for creating POs
    PROCEDURE XXD_START_AUTOCREATE_PO_PVT (
        P_ERRBUF         OUT NOCOPY VARCHAR2,
        P_RETCODE        OUT NOCOPY NUMBER,
        P_PO_TYPE     IN            VARCHAR2,                            --REQ
        P_BUYER_ID    IN            VARCHAR2,                            --REQ
        P_OU          IN            NUMBER,                              --REQ
        P_PO_STATUS   IN            VARCHAR2,                            --REQ
        P_USER_ID     IN            NUMBER,
        P_REQ_ID      IN            NUMBER DEFAULT NULL)                 --OPT
    IS
        v_errbuf                   VARCHAR2 (250);
        v_ret_code                 NUMBER;
        v_errbuf1                  VARCHAR2 (250);
        v_ret_code1                NUMBER;
        v_batch_id                 NUMBER := NULL;

        v_err_stat                 VARCHAR2 (1);
        v_err_msg                  VARCHAR2 (2000);

        v_processed_lines_count    NUMBER := 0;
        v_rejected_lines_count     NUMBER := 0;
        v_err_tolerance_exceeded   VARCHAR2 (100);

        v_return_status            VARCHAR2 (20);

        V_PO_STATUS                VARCHAR2 (50);

        n_header_cnt               NUMBER;
        n_line_cnt                 NUMBER;

        po_header_cnt              NUMBER;
        po_line_cnt                NUMBER;

        po_rejected_cnt            NUMBER;
        lv_org_code                VARCHAR2 (50) := NULL;        -- CCR0007154

        -- START CCR0006820
        CURSOR CUR_APPROVED_REQS IS
            SELECT DISTINCT PRLA.DESTINATION_ORGANIZATION_ID
              FROM PO_REQUISITION_HEADERS_ALL PRHA, PO_REQUISITION_LINES_ALL PRLA
             WHERE     PRHA.REQUISITION_HEADER_ID =
                       PRLA.REQUISITION_HEADER_ID
                   AND PRHA.AUTHORIZATION_STATUS = 'APPROVED'
                   AND PRLA.ORG_ID = P_OU
                   AND NVL (PRLA.SUGGESTED_BUYER_ID, -999) = P_BUYER_ID
                   AND NVL (PRLA.LINE_LOCATION_ID, -999) = -999
                   AND NVL (PRLA.CANCEL_FLAG, 'N') = 'N'
                   AND NVL (PRLA.CLOSED_CODE, 'OPEN') <> 'FINALLY CLOSED'
                   AND PRLA.VENDOR_ID IS NOT NULL
                   AND (PRLA.VENDOR_SITE_ID IS NOT NULL OR PRLA.SUGGESTED_VENDOR_LOCATION IS NOT NULL)
                   AND PRHA.REQUISITION_HEADER_ID =
                       NVL (P_REQ_ID, PRHA.REQUISITION_HEADER_ID);
    -- END CCR0006820

    BEGIN
        --List parameters called
        fnd_file.PUT_LINE (fnd_file.LOG, 'PO_TYPE ' || P_PO_TYPE);
        fnd_file.PUT_LINE (fnd_file.LOG, 'BUYER_ID ' || P_BUYER_ID);
        fnd_file.PUT_LINE (fnd_file.LOG, 'OU ' || P_OU);
        fnd_file.PUT_LINE (fnd_file.LOG, 'P_PO_STATUS ' || P_PO_STATUS);
        fnd_file.PUT_LINE (fnd_file.LOG, 'REQ_ID ' || P_REQ_ID);

        --Validate parameters
        --PO Type
        fnd_file.PUT_LINE (fnd_file.LOG, 'Start validation');

        IF P_PO_TYPE IS NULL
        THEN
            P_retcode   := 2;
            p_errbuf    := 'PO type not supplied.';
            RETURN;
        END IF;

        IF NOT check_for_value_set_value (gLookupPOType, P_PO_TYPE)
        THEN
            P_retcode   := 2;
            p_errbuf    := 'PO Type not a valid value.';
            RETURN;
        END IF;

        --Operating Unit
        IF P_OU IS NULL
        THEN
            P_retcode   := 2;
            p_errbuf    := 'Operating unit not supplied.';
            RETURN;
        END IF;

        --Buyer ID
        IF P_BUYER_ID IS NULL AND P_PO_TYPE = gPOTypeTrade
        THEN
            P_retcode   := 2;
            p_errbuf    := 'Buyer ID not supplied.';
            RETURN;
        END IF;

        --PO Approval Status
        IF P_PO_STATUS IS NULL
        THEN
            P_retcode   := 2;
            p_errbuf    := 'PO Approval Status not supplied.';
            RETURN;
        END IF;

        IF NOT check_for_value_set_value (gLookupPOApprovalStatus,
                                          UPPER (P_PO_STATUS))
        THEN
            P_retcode   := 2;
            p_errbuf    := 'PO Approval Status not a valid value.';
            RETURN;
        END IF;

        --End validatee parameters

        --Set batch ID for this process

        IF P_OU <> 99
        THEN
            SELECT PO_CONTROL_GROUPS_S.NEXTVAL INTO v_batch_id FROM DUAL;

            fnd_file.PUT_LINE (fnd_file.LOG, 'Set batch ID : ' || v_batch_id);

            --Set Purchasing context for process
            fnd_file.PUT_LINE (fnd_file.LOG, 'Set context');
            set_purchasing_context (p_user_id, p_ou, v_err_stat,
                                    v_err_msg);

            fnd_file.PUT_LINE (fnd_file.LOG,
                               'ORG_ID' || mo_global.get_current_org_id);

            IF v_err_stat != FND_API.G_RET_STS_SUCCESS
            THEN
                --Set purchasing context failed
                fnd_file.PUT_LINE (fnd_file.LOG, 'Set context failed');
                P_ERRBUF    := v_err_msg;
                P_RETCODE   := 2;
                RETURN;
            END IF;

            fnd_file.PUT_LINE (fnd_file.LOG,
                               'Populate PO Interface for Trade');
            XXD_POPULATE_POI_FOR_TRADE (v_batch_id, v_errbuf, v_ret_code,
                                        p_buyer_id, p_ou, P_PO_STATUS,
                                        p_user_id, P_REQ_ID, NULL);

            fnd_file.PUT_LINE (fnd_file.LOG,
                               'Check insert to POI. ret_code' || v_ret_code);

            --Check if records inserted into POI if not then error.
            IF v_ret_code = 2
            THEN
                P_ERRBUF    := v_errbuf;
                P_RETCODE   := 0;
                RETURN;
            END IF;
        ELSIF P_OU = 99
        THEN
            FOR REC_APPROVED_REQS IN CUR_APPROVED_REQS
            LOOP
                SELECT PO_CONTROL_GROUPS_S.NEXTVAL INTO v_batch_id FROM DUAL;

                fnd_file.PUT_LINE (fnd_file.LOG,
                                   'Set batch ID : ' || v_batch_id);

                --Set Purchasing context for process
                fnd_file.PUT_LINE (fnd_file.LOG, 'Set context');
                set_purchasing_context (p_user_id, p_ou, v_err_stat,
                                        v_err_msg);

                fnd_file.PUT_LINE (fnd_file.LOG,
                                   'ORG_ID' || mo_global.get_current_org_id);

                IF v_err_stat != FND_API.G_RET_STS_SUCCESS
                THEN
                    --Set purchasing context failed
                    fnd_file.PUT_LINE (fnd_file.LOG, 'Set context failed');
                    P_ERRBUF    := v_err_msg;
                    P_RETCODE   := 2;
                    RETURN;
                END IF;

                -- START CCR0007154
                lv_org_code   := NULL;

                BEGIN
                    SELECT organization_code
                      INTO lv_org_code
                      FROM mtl_parameters
                     WHERE organization_id =
                           rec_approved_reqs.destination_organization_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_org_code   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in Fetching Organization Code for Macau OU :: '
                            || SQLERRM);
                END;

                -- END CCR0007154to

                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    'Populate PO Interface for Trade Macau Reqs ');

                IF lv_org_code = 'MC1'        -- Added IF Condition CCR0007154
                THEN
                    fnd_file.PUT_LINE (fnd_file.LOG, 'IN MC1 ');
                    XXD_POPULATE_POI_FOR_TRADE (
                        v_batch_id,
                        v_errbuf,
                        v_ret_code,
                        p_buyer_id,
                        p_ou,
                        P_PO_STATUS,
                        p_user_id,
                        P_REQ_ID,
                        rec_approved_reqs.destination_organization_id);
                ELSIF lv_org_code = 'MC2'
                THEN
                    fnd_file.PUT_LINE (fnd_file.LOG, 'IN MC2 ');
                    xxd_populate_dist_poi_trade (
                        v_batch_id,
                        v_errbuf,
                        v_ret_code,
                        p_buyer_id,
                        p_ou,
                        p_po_status,
                        p_user_id,
                        p_req_id,
                        rec_approved_reqs.destination_organization_id);
                END IF;    -- End if Condition lv_org_code = 'MC1'  CCR0007154

                fnd_file.PUT_LINE (
                    fnd_file.LOG,
                    'Check insert to POI. ret_code' || v_ret_code);
            END LOOP;                         -- Distinct Dest Orgs Macau Loop
        END IF;                                                -- If P_OU = 99

        --End of processing . Return any errors raised
        --Calling procedure to update SO with PO inforamtion for intercompany
        --Calling below procedure for change 1.7
        update_so_intercompany ();
        fnd_file.PUT_LINE (fnd_file.LOG, 'End Process');
        P_retCODE   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.PUT_LINE (fnd_file.LOG, SQLERRM);
            P_retCODE   := 2;
    END;

    --Modification starts for Defect#3280
    ---procedure to update need by date of PO line
    PROCEDURE XXD_START_AUTOCREATE_PO (
        P_ERRBUF         OUT NOCOPY VARCHAR2,
        P_RETCODE        OUT NOCOPY NUMBER,
        P_PO_TYPE     IN            VARCHAR2,                            --REQ
        P_DUMMY       IN            VARCHAR2 := NULL,                    --OPT
        P_BUYER_ID    IN            VARCHAR2,                            --REQ
        P_OU          IN            NUMBER,                              --REQ
        P_PO_STATUS   IN            VARCHAR2,                            --REQ
        P_REQ_ID      IN            NUMBER DEFAULT NULL)                 --OPT
    IS
        v_user_id   NUMBER := fnd_global.user_id;
    BEGIN
        fnd_file.PUT_LINE (fnd_file.LOG, '** Autocreate process begin');
        XXD_START_AUTOCREATE_PO_PVT (P_ERRBUF, P_RETCODE, P_PO_TYPE,
                                     P_BUYER_ID, P_OU, P_PO_STATUS,
                                     v_user_id, P_REQ_ID);
        fnd_file.PUT_LINE (fnd_file.LOG, '** Autocreate process end');
    END;
END XXD_AUTOCREATE_TRADE_PO_PKG;
/
