--
-- XXD_AUTOCREATE_NONTRADE_PO_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AUTOCREATE_NONTRADE_PO_PKG"
AS
    /*******************************************************************************
    * Program Name : xxd_autocreate_nontrade_po_pkd
    * Language     : PL/SQL
    * Description  : This package will autocreate Non Trade PO from requisitions
    *
    * History      :
    *
    * WHO                     WHAT                                                                    Desc                                    WHEN
    * --------------         ---------------                                                     -------------------------------          ---------------
      Tejaswi Gangumalla    Create new package with existing logic from xxd_autocreate_po_pkg       1.0 - Initial Version                  28-Feb-2018
    * Tejaswi Gangumalla    Modified procedure xxd_insert_headers to get agent id based on limit    1.1                                    28-Feb-2018
    * * ------------------------------------------------------------------------------------------------------------------------------------------------------- */
    gv_mo_profile_option_name   CONSTANT VARCHAR2 (240)
                                             := 'MO: Security Profile' ;
    gv_responsibility_name      CONSTANT VARCHAR2 (240)
                                             := 'Deckers Purchasing User' ;
    glookuppoapprovalstatus     CONSTANT NUMBER := 1005639;
    glookuppotype               CONSTANT NUMBER := 1016638;
    gpotypetrade                CONSTANT VARCHAR2 (10) := 'Trade';
    gpotypenontrade             CONSTANT VARCHAR2 (10) := 'Non-Trade';
    gbatchp2p_user              CONSTANT VARCHAR2 (20) := 'BATCH.P2P';

    --Return the buy month as the current Month-Year
    --Input:     NONE
    --Output:    (Varchar2 - Buy Month)
    --
    --   FUNCTION GET_BUY_MONTH
    --      RETURN VARCHAR2
    --   IS
    --   BEGIN
    --      RETURN    UPPER (TO_CHAR (SYSDATE, 'Mon'))
    --             || ' '
    --             || EXTRACT (YEAR FROM SYSDATE);
    --   END;

    --   --Return Buy season based on the current month
    --   --Inout:     None
    --   --Output (Varchar2 - Buy season)
    --   --
    --   FUNCTION GET_BUY_SEASON
    --      RETURN VARCHAR2
    --   IS
    --      V_BUY_MONTH    VARCHAR2 (20) := Get_Buy_Month;
    --      V_BUY_SEASON   VARCHAR2 (20);
    --   BEGIN
    --      SELECT FFV.ATTRIBUTE1
    --        INTO V_BUY_SEASON
    --        FROM FND_FLEX_VALUES FFV, FND_FLEX_VALUE_SETS FFVS
    --       WHERE     FFVS.FLEX_VALUE_SET_ID = FFV.FLEX_VALUE_SET_ID
    --             AND FFVS.FLEX_VALUE_SET_NAME = 'DO_BUY_MONTH_YEAR'
    --             AND VALUE_CATEGORY = 'DO_BUY_MONTH_YEAR'
    --             AND FFV.FLEX_VALUE = V_BUY_MONTH;

    --      RETURN V_BUY_SEASON;
    --   END;

    --Calculate the PCard ID
    --   FUNCTION GET_PCARD_ID (P_PCARD_FLAG       IN VARCHAR2,
    --                          P_PCARD_ID         IN NUMBER,
    --                          P_VENDOR_ID           NUMBER,
    --                          P_VENDOR_SITE_ID      NUMBER)
    --      RETURN NUMBER
    --   IS
    --      N_PCARD_ID   NUMBER;
    --   BEGIN
    --      IF P_PCARD_FLAG = 'Y'
    --      THEN
    --         N_PCARD_ID := P_PCARD_ID;
    --      ELSIF P_PCARD_FLAG = 'S'
    --      THEN
    --         N_PCARD_ID :=
    --            NVL (
    --               (PO_PCARD_PKG.GET_VALID_PCARD_ID (-99999,
    --                                                 P_VENDOR_ID,
    --                                                 P_VENDOR_SITE_ID)),
    --               -99999);
    --      ELSE
    --         N_PCARD_ID := NULL;
    --      END IF;

    --      RETURN N_PCARD_ID;
    --   END;

    ---Vheck if a value is in the designated value set
    --Input: pn_value_set_id - Value Set Identifier
    --       pv_value_set_value - Value set value
    FUNCTION check_for_value_set_value (pn_value_set_id      IN NUMBER,
                                        pv_value_set_value   IN VARCHAR)
        RETURN BOOLEAN
    IS
        ln_cnt   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_flex_values
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
    --   FUNCTION GET_SHIP_METHOD (P_VENDOR_ID          IN NUMBER,
    --                             P_VENDOR_SITE_CODE   IN VARCHAR2,
    --                             P_PO_TYPE            IN VARCHAR2,
    --                             P_DEST_COUNTRY       IN VARCHAR2)
    --      RETURN VARCHAR2
    --   IS
    --      v_territory_short_name    VARCHAR2 (50);
    --      v_preferred_ship_method   VARCHAR2 (20);
    --   BEGIN
    --      IF P_PO_TYPE LIKE 'SAMPLE%'
    --      THEN
    --         RETURN 'Air';
    --      ELSE
    --         BEGIN
    --            --Get the territory short name from the territories lookup
    --            SELECT territory_short_name
    --              INTO v_territory_short_name
    --              FROM fnd_territories_vl
    --             WHERE territory_code = P_DEST_COUNTRY;

    --            --Set the ship method based on the po type and drop ship flag
    --            SELECT flv.attribute8
    --              INTO v_preferred_ship_method
    --              FROM FND_LOOKUP_VALUES FLV
    --             WHERE     FLV.LANGUAGE = 'US'
    --                   AND FLV.LOOKUP_TYPE = 'XXDO_SUPPLIER_INTRANSIT'
    --                   AND FLV.ATTRIBUTE1 = TO_CHAR (p_vendor_id)
    --                   AND FLV.ATTRIBUTE2 = p_vendor_site_code
    --                   AND FLV.ATTRIBUTE4 = v_territory_short_name
    --                   AND SYSDATE BETWEEN flv.start_date_active
    --                                   AND NVL (flv.end_date_active, SYSDATE + 1);

    --            RETURN NVL (v_preferred_ship_method, 'Ocean');
    --         EXCEPTION
    --            WHEN NO_DATA_FOUND
    --            THEN
    --               RETURN 'Ocean';
    --            WHEN OTHERS
    --            THEN
    --               RETURN 'Ocean';
    --         END;
    --      END IF;
    --   END;

    --Get the transit time based on the source vendor/site and destination country
    --Input  p_vendor_id          -Source vendor site
    --       p_vendor_site_id     -Source vendor site code
    --       p_drop_ship_flag     -REQ drop ship flag
    --       p_dest_country       -Destination country
    --Output:    (Number - Number of transit days)
    --   FUNCTION GET_TRANSIT_TIME (P_VENDOR_ID          IN NUMBER,
    --                              P_VENDOR_SITE_CODE   IN VARCHAR2,
    --                              P_DROP_SHIP_FLAG     IN VARCHAR2,
    --                              P_PO_TYPE            IN VARCHAR2, --2/10/17 Added to pass to get_ship_method
    --                              P_DEST_COUNTRY       IN VARCHAR2)
    --      RETURN NUMBER
    --   IS
    --      v_territory_short_name    VARCHAR2 (50);
    --      v_days_air                VARCHAR2 (5);
    --      v_days_ocean              VARCHAR2 (5);
    --      v_days_truck              VARCHAR2 (5);
    --      v_preferred_ship_method   VARCHAR2 (20);
    --      v_tq_po_exists            VARCHAR2 (20);
    --   BEGIN
    --      BEGIN
    --         --Get the territory short name from the territories lookup
    --         SELECT territory_short_name
    --           INTO v_territory_short_name
    --           FROM fnd_territories_vl
    --          WHERE territory_code = P_DEST_COUNTRY;

    --         --Get the transit times  from the transit matrix lookup
    --         SELECT FLV.ATTRIBUTE5,
    --                FLV.attribute6,
    --                FLV.attribute7,
    --                flv.attribute8
    --           INTO v_days_air,
    --                v_days_ocean,
    --                v_days_truck,
    --                v_preferred_ship_method
    --           FROM FND_LOOKUP_VALUES FLV
    --          WHERE     FLV.LANGUAGE = 'US'
    --                AND FLV.LOOKUP_TYPE = 'XXDO_SUPPLIER_INTRANSIT'
    --                AND FLV.ATTRIBUTE1 = TO_CHAR (p_vendor_id)
    --                AND FLV.ATTRIBUTE2 = p_vendor_site_code
    --                -- AND FLV.ATTRIBUTE3 = mp.organization_code
    --                AND FLV.ATTRIBUTE4 = v_territory_short_name
    --                AND SYSDATE BETWEEN flv.start_date_active
    --                                AND NVL (flv.end_date_active, SYSDATE + 1);

    --         --If Preferred ship method not set, get preferred ship method
    --         --NOTE: Do we want to call this to run the above query basically a second time or just default for samples here?
    --         IF v_preferred_ship_method IS NULL
    --         THEN
    --            v_preferred_ship_method :=
    --               get_ship_method (P_VENDOR_ID,
    --                                P_VENDOR_SITE_CODE,
    --                                P_PO_TYPE,
    --                                P_DEST_COUNTRY);
    --         END IF;

    --         --Set the transit days based on the po type and drop ship flag
    --         IF p_drop_ship_flag = 'Y'
    --         THEN
    --            RETURN 0;
    --         ELSE
    --            IF v_preferred_ship_method = 'Air'
    --            THEN
    --               RETURN TO_NUMBER (v_days_air);
    --            ELSIF v_preferred_ship_method = 'Truck'
    --            THEN
    --               RETURN TO_NUMBER (v_days_truck);
    --            ELSE
    --               RETURN TO_NUMBER (v_days_ocean);
    --            END IF;
    --         END IF;

    --         RETURN 0;
    --      EXCEPTION
    --         WHEN NO_DATA_FOUND
    --         THEN
    --            RETURN 0;
    --         WHEN OTHERS
    --         THEN
    --            RETURN 0;
    --      END;
    --   END;

    --Show PO lines created from requisition lines based on the batch ID passed
    --Input: p_batch_id - Batch to process
    PROCEDURE show_batch_po_data (p_batch_id IN NUMBER)
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
        fnd_file.put_line (fnd_file.LOG, '--Show batch PO Data : Enter');

        FOR rec IN cur_po_headers
        LOOP
            fnd_file.put_line (
                fnd_file.output,
                   'Requisition # '
                || rec.requisition_num
                || ' Requisition Line Num '
                || rec.requisition_line_num
                || ' PO # '
                || rec.po_num
                || CHR (10));
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, '--Show batch PO Data : Exit');
    END;

    --Log any POI errors generated for the passed in batch
    --Input: p_batch_id - Batch to process
    PROCEDURE show_batch_poi_errors (p_batch_id IN NUMBER)
    IS
        CURSOR cur_po_errors IS
            SELECT DISTINCT error_message
              FROM (SELECT 'Requisition#: ' || prha.segment1 || '|Requisition line num:' || prla.line_num || '| error_message: ' || poie.error_message || '|Grouped invalid column name and value: ' || poie.column_name || poie.COLUMN_VALUE AS error_message
                      FROM po_interface_errors poie, po_headers_interface phi, po_lines_interface pli,
                           po_requisition_headers_all prha, po_requisition_lines_all prla
                     WHERE     poie.batch_id = p_batch_id
                           AND poie.batch_id = phi.batch_id
                           AND poie.interface_type = 'PO_DOCS_OPEN_INTERFACE'
                           AND phi.interface_header_id =
                               poie.interface_header_id
                           AND phi.interface_header_id =
                               pli.interface_header_id(+)
                           AND pli.requisition_line_id =
                               prla.requisition_line_id
                           AND prla.requisition_header_id =
                               prha.requisition_header_id);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '--Show POI Errors : Enter');

        FOR rec IN cur_po_errors
        LOOP
            fnd_file.put_line (fnd_file.LOG, rec.error_message || CHR (10));
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, '--Show POI Errors : Exit');
    END;

    --Update PO/Requisition data in the drop ship sources table and the po information in the requisition lines
    --table for all records in the given batch
    --Input: p_batch_id - Batch to process
    --   PROCEDURE UPDATE_DROP_SHIP (p_batch_id IN NUMBER)
    --   IS
    --      CURSOR CUR_UPDATE_DROP_SHIP
    --      IS
    --         SELECT DISTINCT PHI.PO_HEADER_ID,
    --                         PLI.PO_LINE_ID,
    --                         PLLI.LINE_LOCATION_ID,
    --                         PORH.REQUISITION_HEADER_ID,
    --                         PORL.REQUISITION_LINE_ID
    --           FROM PO_REQUISITION_HEADERS_ALL PORH,
    --                PO_REQUISITION_LINES_ALL PORL,
    --                PO_LINE_LOCATIONS_INTERFACE PLLI,
    --                PO_LINES_INTERFACE PLI,
    --                PO_HEADERS_INTERFACE PHI,
    --                PO_HEADERS_ALL POH,
    --                OE_DROP_SHIP_SOURCES OEDSS
    --          WHERE     PORH.REQUISITION_HEADER_ID = PORL.REQUISITION_HEADER_ID
    --                AND OEDSS.REQUISITION_LINE_ID = PORL.REQUISITION_LINE_ID
    --                AND PORL.LINE_LOCATION_ID = PLLI.LINE_LOCATION_ID
    --                AND PLLI.INTERFACE_LINE_ID = PLI.INTERFACE_LINE_ID
    --                AND PLI.INTERFACE_HEADER_ID = PHI.INTERFACE_HEADER_ID
    --                AND PHI.PO_HEADER_ID = POH.PO_HEADER_ID
    --                AND PHI.BATCH_ID = P_BATCH_ID;

    --      v_dropship_return_status   VARCHAR2 (50);
    --      v_dropship_Msg_Count       VARCHAR2 (50);
    --      v_dropship_Msg_data        VARCHAR2 (50);
    --   BEGIN
    --      fnd_file.PUT_LINE (fnd_file.LOG, '--Update Drop Ship : Enter');

    --      FOR CUR_UPDATE_DROP_SHIP_REC IN CUR_UPDATE_DROP_SHIP
    --      LOOP
    --         BEGIN
    --            APPS.OE_DROP_SHIP_GRP.Update_PO_Info (
    --               p_api_version        => 1.0,
    --               P_Return_Status      => v_dropship_return_status,
    --               P_Msg_Count          => v_dropship_Msg_Count,
    --               P_MSG_Data           => v_dropship_MSG_Data,
    --               P_Req_Header_ID      => cur_update_drop_ship_rec.requisition_header_id,
    --               P_Req_Line_ID        => cur_update_drop_ship_rec.requisition_line_id,
    --               P_PO_Header_Id       => cur_update_drop_ship_rec.PO_HEADER_ID,
    --               P_PO_Line_Id         => cur_update_drop_ship_rec.PO_LINE_ID,
    --               P_Line_Location_ID   => cur_update_drop_ship_rec.LINE_LOCATION_ID);

    --            IF (v_dropship_return_status = FND_API.g_ret_sts_success)
    --            THEN
    --               fnd_file.PUT_LINE (fnd_file.LOG,
    --                                  'drop ship successs' || CHR (10));

    --               UPDATE PO_LINE_LOCATIONS_ALL PLLA
    --                  SET SHIP_TO_LOCATION_ID =
    --                         (SELECT DISTINCT PORL.DELIVER_TO_LOCATION_ID
    --                            FROM PO_REQUISITION_HEADERS_ALL PORH,
    --                                 PO_REQUISITION_LINES_ALL PORL
    --                           WHERE     PORH.REQUISITION_HEADER_ID =
    --                                        PORL.REQUISITION_HEADER_ID
    --                                 AND PLLA.LINE_LOCATION_ID =
    --                                        PORL.LINE_LOCATION_ID
    --                                 AND PORL.LINE_LOCATION_ID =
    --                                        CUR_UPDATE_DROP_SHIP_REC.LINE_LOCATION_ID)
    --                WHERE PLLA.LINE_LOCATION_ID =
    --                         CUR_UPDATE_DROP_SHIP_REC.LINE_LOCATION_ID;

    --               COMMIT;
    --            ELSIF v_dropship_return_status = (FND_API.G_RET_STS_ERROR)
    --            THEN
    --               FOR i IN 1 .. FND_MSG_PUB.count_msg
    --               LOOP
    --                  fnd_file.PUT_LINE (
    --                     fnd_file.LOG,
    --                        'DROP SHIP api ERROR:'
    --                     || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
    --               END LOOP;
    --            ELSIF v_dropship_return_status = FND_API.G_RET_STS_UNEXP_ERROR
    --            THEN
    --               FOR i IN 1 .. FND_MSG_PUB.count_msg
    --               LOOP
    --                  fnd_file.PUT_LINE (
    --                     fnd_file.LOG,
    --                        'DROP SHIP UNEXPECTED ERROR:'
    --                     || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F'));
    --               END LOOP;
    --            END IF;
    --         EXCEPTION
    --            WHEN OTHERS
    --            THEN
    --               fnd_file.PUT_LINE (fnd_file.LOG, 'drop ship when others');
    --         END;
    --      END LOOP;

    --      fnd_file.PUT_LINE (fnd_file.LOG, '--Update Drop Ship : Exit');
    --   EXCEPTION
    --      WHEN OTHERS
    --      THEN
    --         fnd_file.PUT_LINE (fnd_file.LOG,
    --                            '--Update Drop Ship : Exception ' || SQLERRM);
    --   END;

    --Set the purchasing context
    --Input:     pn_user_ud -User to log in as
    --           pn_org_id  -Org ID to use
    --Output:    pv_error_stat -Error status (E,U,S)
    --           pv_error msg - error message
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
                       gv_mo_profile_option_name
                   --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_id NOT IN (51395, 51398)      --TEMP
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name || '%'
                   --'Deckers Purchasing User%'
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

        fnd_file.put_line (fnd_file.LOG, 'Context Info before');
        fnd_file.put_line (fnd_file.LOG,
                           'Curr ORG: ' || apps.mo_global.get_current_org_id);
        fnd_file.put_line (
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
        mo_global.init ('PO');
        mo_global.set_policy_context ('S', pn_org_id);
        fnd_request.set_org_id (pn_org_id);
        fnd_file.put_line (fnd_file.LOG, 'Context Info after');
        fnd_file.put_line (fnd_file.LOG,
                           'Curr ORG: ' || apps.mo_global.get_current_org_id);
        fnd_file.put_line (
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
    --   PROCEDURE RUN_STD_PO_IMPORT (pn_batch_id     IN     NUMBER,
    --                                pn_org_id       IN     NUMBER,
    --                                pn_user_id      IN     NUMBER,
    --                                pv_status       IN     VARCHAR2 := 'APPROVED',
    --                                pn_request_id      OUT NUMBER,
    --                                pv_error_stat      OUT VARCHAR2,
    --                                pv_error_msg       OUT VARCHAR2)
    --   IS
    --      l_phase          VARCHAR2 (80);
    --      l_req_status     BOOLEAN;
    --      l_status         VARCHAR2 (80);
    --      l_dev_phase      VARCHAR2 (80);
    --      l_dev_status     VARCHAR2 (80);
    --      l_message        VARCHAR2 (255);
    --      l_data           VARCHAR2 (200);

    --      ln_user_id       NUMBER;

    --      ln_req_status    BOOLEAN;

    --      x_ret_stat       VARCHAR2 (1);
    --      x_error_text     VARCHAR2 (20000);
    --      ln_employee_id   NUMBER;
    --      ln_def_user_id   NUMBER;

    --      ex_login         EXCEPTION;
    --   BEGIN
    --      pn_request_id := -1;
    --      fnd_file.PUT_LINE (fnd_file.LOG, 'run_std_po_import - Enter');
    --      fnd_file.PUT_LINE (fnd_file.LOG, 'Batch ID : ' || pn_batch_id);

    --      --If user ID not passed, pull defalt user for this type of transaction
    --      SELECT user_id
    --        INTO ln_def_user_id
    --        FROM fnd_user
    --       WHERE user_name = gBatchP2P_User;

    --      --Check pased in user
    --      BEGIN
    --         SELECT employee_id
    --           INTO ln_employee_id
    --           FROM fnd_user
    --          WHERE user_id = pn_user_id;

    --         fnd_file.PUT_LINE (fnd_file.LOG, 'Emloyee ID : ' || ln_employee_id);

    --         IF ln_employee_id IS NULL
    --         THEN
    --            ln_user_id := ln_def_user_id;
    --         ELSE
    --            ln_user_id := pn_user_id;
    --         END IF;
    --      EXCEPTION
    --         WHEN NO_DATA_FOUND
    --         THEN
    --            ln_user_id := ln_def_user_id;
    --      END;

    --      fnd_file.PUT_LINE (fnd_file.LOG, 'before set_purchasing_context');
    --      fnd_file.PUT_LINE (fnd_file.LOG, '     USER_ID : ' || ln_user_id);
    --      fnd_file.PUT_LINE (fnd_file.LOG, '     ORG_ID : ' || pn_org_id);

    --      set_purchasing_context (ln_user_id,
    --                              pn_org_id,
    --                              pv_error_stat,
    --                              pv_error_msg);

    --      IF pv_error_stat <> 'S'
    --      THEN
    --         RAISE ex_login;
    --      END IF;

    --      pn_request_id :=
    --         apps.fnd_request.submit_request (
    --            application   => 'PO',
    --            program       => 'POXPOPDOI',
    --            argument1     => '',                                    --buyer_id
    --            argument2     => 'STANDARD',                       --Document type
    --            argument3     => '',                            --Document subtype
    --            argument4     => 'N',                               --Create Items
    --            argument5     => '',                  --create sourcing rules flag
    --            argument6     => pv_status,                      --approval status
    --            argument7     => '',                              --rel_gen_method
    --            argument8     => TO_CHAR (pn_batch_id),                 --batch_id
    --            argument9     => TO_CHAR (pn_org_id),                     --org_id
    --            argument10    => '',                                     --ga_flag
    --            argument11    => '',                       --enable_sourcing_level
    --            argument12    => '',                              --sourcing_level
    --            argument13    => '');                             --inv_org_enable
    --      fnd_file.PUT_LINE (fnd_file.LOG, pn_request_id);

    --      COMMIT;
    --      fnd_file.PUT_LINE (
    --         fnd_file.LOG,
    --         'poxpopdoi - wait for request - Request ID :' || pn_request_id);
    --      ln_req_status :=
    --         apps.fnd_concurrent.wait_for_request (request_id   => pn_request_id,
    --                                               interval     => 10,
    --                                               max_wait     => 0,
    --                                               phase        => l_phase,
    --                                               status       => l_status,
    --                                               dev_phase    => l_dev_phase,
    --                                               dev_status   => l_dev_status,
    --                                               MESSAGE      => l_message);

    --      fnd_file.PUT_LINE (
    --         fnd_file.LOG,
    --         'poxpopdoi - after wait for request -  ' || l_dev_status);

    --      IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
    --      THEN
    --         IF NVL (l_dev_status, 'ERROR') = 'WARNING'
    --         THEN
    --            x_ret_stat := 'W';
    --         ELSE
    --            x_ret_stat := apps.fnd_api.g_ret_sts_error;
    --         END IF;

    --         x_error_text :=
    --            NVL (
    --               l_message,
    --                  'The poxpopdoi request ended with a status of '
    --               || NVL (l_dev_status, 'ERROR'));
    --         pv_error_stat := x_ret_stat;
    --         pv_error_msg := x_error_text;
    --      ELSE
    --         x_ret_stat := 'S';
    --      END IF;

    --      fnd_file.PUT_LINE (fnd_file.LOG, 'run_std_po_import - Exit');
    --   EXCEPTION
    --      WHEN ex_login
    --      THEN
    --         pv_error_stat := 'E';
    --         pv_error_msg := 'Unable to set purchasing context';
    --      WHEN OTHERS
    --      THEN
    --         pv_error_stat := 'U';
    --         pv_error_msg :=
    --            'Unexpected error occurred in run_std_po_import.' || SQLERRM;
    --   END;

    --Get the vendor and vendor site based on the sourcing rule for the
    --supplied item and source/destination information
    --Input:     p_org_id            ORG ID of req
    --           p_destrination_organization_id Dest org of REQ
    --           p_item_id            item to check sourcing
    --           p_creation_date     REQ creation date
    --           p_internal_org      Org of Sourcing SO or IR
    --           p_order_type        B2B or Drop Ship
    --Output     p_vendor_id         Sourcing Vendor ID
    --           p_vendor_site_id    Sourcing Vendor site ID
    --   PROCEDURE XXD_REQ_VENDOR_DET (
    --      P_ORG_ID                        IN     NUMBER,
    --      P_destination_organization_id   IN     NUMBER,
    --      P_ITEM_ID                       IN     NUMBER,
    --      P_CREATION_DATE                 IN     DATE,
    --      P_INTERNAL_ORG                  IN     VARCHAR2,
    --      P_ORDER_TYPE                    IN     VARCHAR2,
    --      P_VENDOR_ID                        OUT NUMBER,
    --      P_VENDOR_SITE_ID                   OUT NUMBER)
    --   IS
    --   --Modified 1/18/2017 GJensen. Did extensive query analyasis and re-optimized query for performance.
    --   --Found index hint was no longer needed as the Oracle query plan uses this index
    --   BEGIN
    --      SELECT                         --/*+ index(MSSO MRP_SR_SOURCE_ORG_U2) */
    --            MSSO.VENDOR_ID, MSSO.VENDOR_SITE_ID
    --        INTO P_VENDOR_ID, P_VENDOR_SITE_ID
    --        FROM MRP_ASSIGNMENT_SETS MAS,
    --             MRP_SR_ASSIGNMENTS MSA,
    --             MTL_ITEM_CATEGORIES MIC,
    --             FND_LOOKUP_VALUES FLV,
    --             HR_ALL_ORGANIZATION_UNITS HOU, --changed from HR_OPERATING_UNITS as this resulted in a cartesian join
    --             MRP_SR_RECEIPT_ORG MSRO,
    --             MRP_SR_SOURCE_ORG MSSO
    --       --MTL_CATEGORY_SETS_VL MCS, --removed as where clause was not indexed . Used category_set_id = 1 instead
    --       WHERE     1 = 1
    --             AND MAS.ATTRIBUTE1 = FLV.ATTRIBUTE1
    --             --
    --             AND MSA.ASSIGNMENT_SET_ID = MAS.ASSIGNMENT_SET_ID
    --             AND MSA.ASSIGNMENT_TYPE = 5
    --             AND MSA.ORGANIZATION_ID = P_DESTINATION_ORGANIZATION_ID
    --             AND MSA.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
    --             AND MSA.CATEGORY_ID = MIC.CATEGORY_ID
    --             AND MSA.SOURCING_RULE_TYPE = 1
    --             --
    --             -- AND MIC.INVENTORY_ITEM_ID = MSA.INVENTORY_ITEM_ID
    --             AND MIC.INVENTORY_ITEM_ID = P_ITEM_ID
    --             AND MIC.ORGANIZATION_ID = P_DESTINATION_ORGANIZATION_ID
    --             AND MSA.ASSIGNMENT_TYPE = 5
    --             AND MIC.CATEGORY_SET_ID = 1 --Inventory (replaces link to mtl_category_sets_v
    --             -- AND MCS.CATEGORY_SET_NAME = 'Inventory'
    --             -- AND MCS.CATEGORY_SET_ID = MSA.CATEGORY_SET_ID
    --             AND FLV.LOOKUP_TYPE = 'XXDO_SOURCING_RULE_REGION_MAP'
    --             AND FLV.LANGUAGE = 'US'
    --             AND FLV.ATTRIBUTE2 = 'Operating Unit'
    --             AND FLV.ATTRIBUTE3 = HOU.NAME
    --             AND FLV.ATTRIBUTE1 =
    --                    CASE
    --                       WHEN (    P_INTERNAL_ORG = 'Deckers Europe Ltd OU'
    --                             AND P_ORDER_TYPE = 'DROP SHIP'
    --                             AND FLV.ATTRIBUTE3 = 'Deckers Macau OU')
    --                       THEN
    --                          'EMEA'
    --                       WHEN (    P_INTERNAL_ORG = 'Deckers Asia Pac Ltd OU'
    --                             AND P_ORDER_TYPE = 'DROP SHIP'
    --                             AND FLV.ATTRIBUTE3 = 'Deckers Macau OU')
    --                       THEN
    --                          'APAC'
    --                       WHEN (    P_INTERNAL_ORG = 'Deckers Japan OU'
    --                             AND P_ORDER_TYPE = 'DROP SHIP'
    --                             AND FLV.ATTRIBUTE3 = 'Deckers Macau OU')
    --                       THEN
    --                          'APAC'
    --                       WHEN (    P_INTERNAL_ORG =
    --                                    'Deckers Inventory Consolidation OU'
    --                             AND P_ORDER_TYPE = 'B2B'
    --                             AND FLV.ATTRIBUTE3 = 'Deckers Macau OU')
    --                       THEN
    --                          'EMEA'
    --                       WHEN (    P_INTERNAL_ORG !=
    --                                    'Deckers Inventory Consolidation OU'
    --                             AND P_ORDER_TYPE = 'B2B'
    --                             AND FLV.ATTRIBUTE3 = 'Deckers Macau OU')
    --                       THEN
    --                          'APAC'
    --                       WHEN FLV.ATTRIBUTE3 = 'Deckers US OU'
    --                       THEN
    --                          'US'
    --                       WHEN FLV.ATTRIBUTE3 = 'Deckers Japan OU'
    --                       THEN
    --                          'JP'
    --                       -- Added by Sachin for Canada 3PL - 6/27 -- Start
    --                       WHEN FLV.ATTRIBUTE3 = 'Deckers Canada OU'
    --                       THEN
    --                          'CA'
    --                    -- Added by Sachin for Canada 3PL - 6/27 -- End
    --                    END
    --             AND HOU.ORGANIZATION_ID = P_ORG_ID
    --             AND MSRO.SOURCING_RULE_ID = MSA.SOURCING_RULE_ID
    --             AND MSRO.SR_RECEIPT_ID = MSSO.SR_RECEIPT_ID
    --             AND P_CREATION_DATE BETWEEN NVL (MSRO.EFFECTIVE_DATE, SYSDATE)
    --                                     AND NVL (MSRO.DISABLE_DATE, SYSDATE);
    --   EXCEPTION
    --      WHEN NO_DATA_FOUND
    --      THEN
    --         fnd_file.PUT_LINE (
    --            fnd_file.LOG,
    --               'No vendor found for item id '
    --            || P_ITEM_ID
    --            || ' destination organization id'
    --            || P_destination_organization_id);
    --         --Modification starts as per defect#3379
    --         P_VENDOR_ID := NULL;
    --         P_VENDOR_SITE_ID := NULL;
    --      --Modification ends as per defect#3379
    --      -- RETURN NULL;--commented as per defect#3379
    --      WHEN OTHERS
    --      THEN
    --         fnd_file.PUT_LINE (fnd_file.LOG, 'WHEN OTHERS vendor id' || SQLERRM);
    --   --  RETURN NULL;--commented as per defect#3379
    --   END;

    --Input         p_ou        Org for Req Import
    --              p_interface_source_code Interface source code for REQ import
    --              p_batch_id  BBatch ID for REQ import
    --   PROCEDURE XXD_RUN_REQ_IMPORT (
    --      p_ou                      IN NUMBER,
    --      p_interface_source_code   IN VARCHAR2 := NULL,
    --      p_batch_id                IN NUMBER := NULL)
    --   IS
    --      v_layout           BOOLEAN;
    --      v_request_status   BOOLEAN;
    --      v_phase            VARCHAR2 (2000);
    --      v_wait_status      VARCHAR2 (2000);
    --      v_dev_phase        VARCHAR2 (2000);
    --      v_dev_status       VARCHAR2 (2000);
    --      v_message          VARCHAR2 (2000);
    --      v_req_id           NUMBER;
    --      v_resp_appl_id     NUMBER;
    --      v_resp_id          NUMBER;
    --      v_user_id          NUMBER;
    --      v_count            NUMBER;

    --      v_err_stat         VARCHAR2 (1);
    --      v_err_msg          VARCHAR2 (2000);
    --   BEGIN
    --      ---------REQUISITION IMPORT---------
    --      v_user_id := fnd_global.user_id;

    --      --Set Purchasing context for process
    --      fnd_file.PUT_LINE (fnd_file.LOG, 'Set context');
    --      set_purchasing_context (v_user_id,
    --                              p_ou,
    --                              v_err_stat,
    --                              v_err_msg);

    --      fnd_file.PUT_LINE (fnd_file.LOG,
    --                         'ORG_ID' || mo_global.get_current_org_id);

    --      IF v_err_stat != FND_API.G_RET_STS_SUCCESS
    --      THEN
    --         --Set purchasing context failed
    --         fnd_file.PUT_LINE (fnd_file.LOG, 'Set context failed');
    --         RETURN;
    --      END IF;

    --      -------
    --      v_req_id :=
    --         fnd_request.submit_request (application   => 'PO',
    --                                     program       => 'REQIMPORT',
    --                                     description   => NULL,
    --                                     start_time    => SYSDATE,
    --                                     sub_request   => FALSE,
    --                                     argument1     => p_interface_source_code,
    --                                     argument2     => p_batch_id,
    --                                     argument3     => 'ALL',
    --                                     argument4     => NULL,
    --                                     argument5     => 'N',
    --                                     argument6     => 'Y');

    --      COMMIT;

    --      IF v_req_id = 0
    --      THEN
    --         fnd_file.put_line (
    --            fnd_file.LOG,
    --            'Request Not Submitted due to ?' || fnd_message.get || '?.');
    --      ELSE
    --         fnd_file.put_line (
    --            fnd_file.LOG,
    --               'The Requisition Import Program submitted ? Request id :'
    --            || v_req_id);
    --      END IF;

    --      IF v_req_id > 0
    --      THEN
    --         fnd_file.PUT_LINE (fnd_file.LOG,
    --                            '   Waiting for the Requisition Import Program');

    --         LOOP
    --            v_request_status :=
    --               fnd_concurrent.wait_for_request (request_id   => v_req_id,
    --                                                INTERVAL     => 60,
    --                                                max_wait     => 0,
    --                                                phase        => v_phase,
    --                                                status       => v_wait_status,
    --                                                dev_phase    => v_dev_phase,
    --                                                dev_status   => v_dev_status,
    --                                                MESSAGE      => v_message);

    --            EXIT WHEN    UPPER (v_phase) = 'COMPLETED'
    --                      OR UPPER (v_wait_status) IN
    --                            ('CANCELLED', 'ERROR', 'TERMINATED');
    --         END LOOP;

    --         COMMIT;
    --         FND_FILE.PUT_LINE (
    --            FND_FILE.LOG,
    --               '  Requisition Import Program Request Phase'
    --            || '-'
    --            || v_dev_phase);
    --         fnd_file.PUT_LINE (
    --            fnd_file.LOG,
    --               '  Requisition Import Program Request Dev status'
    --            || '-'
    --            || v_dev_status);

    --         IF UPPER (v_phase) = 'COMPLETED' AND UPPER (v_wait_status) = 'ERROR'
    --         THEN
    --            fnd_file.PUT_LINE (
    --               fnd_file.LOG,
    --               'The Requisition Import prog completed in error. See log for request id');
    --            fnd_file.PUT_LINE (fnd_file.LOG, SQLERRM);

    --            RETURN;
    --         ELSIF     UPPER (v_phase) = 'COMPLETED'
    --               AND UPPER (v_wait_status) = 'NORMAL'
    --         THEN
    --            fnd_file.PUT_LINE (
    --               fnd_file.LOG,
    --                  'The Requisition Import Import successfully completed for request id: '
    --               || v_req_id);
    --         ELSE
    --            fnd_file.PUT_LINE (
    --               fnd_file.LOG,
    --               'The Requisition Import Import request failed.Review log for Oracle request id ');
    --            fnd_file.PUT_LINE (fnd_file.LOG, SQLERRM);

    --            RETURN;
    --         END IF;
    --      END IF;
    --   EXCEPTION
    --      WHEN OTHERS
    --      THEN
    --         fnd_file.PUT_LINE (
    --            fnd_file.LOG,
    --            'WHEN OTHERS REQUISITION IMPORT STANDARD CALL' || SQLERRM);
    --   END;

    --Populate sourcing for back to back  requisitions in the org going back a specific number of days
    --Input          p_ou        Operating Unit
    --               p_num_of_days   Number of days to look back for reqs
    --   PROCEDURE XXD_POPULATE_B2B_SOURCING (p_ou            IN NUMBER,
    --                                        p_num_of_days   IN NUMBER)
    --   IS
    --      --Get listing of B2B requisitions to update sourcing
    --      CURSOR UPDATE_REQ_b2b
    --      IS
    --         --Changed prla.* to a select listing as this removed the TABLE ACCESS STORAGE FULL from the query plan
    --         SELECT PRLA.ORG_ID,
    --                PRLA.DESTINATION_ORGANIZATION_ID,
    --                PRLA.ITEM_ID,
    --                PRHA.CREATION_DATE,
    --                PRLA.VENDOR_ID,
    --                PRLA.VENDOR_SITE_ID,
    --                PRLA.REQUISITION_LINE_ID,
    --                PRLA.SUGGESTED_VENDOR_NAME,
    --                PRLA.SUGGESTED_VENDOR_LOCATION,
    --                HOU.NAME INTERNAL_REQ_ORG,
    --                'B2B' ORDER_TYPE
    --           FROM PO_REQUISITION_HEADERS_ALL PRHA,
    --                PO_REQUISITION_LINES_ALL PRLA,
    --                HR_ALL_ORGANIZATION_UNITS HOU,
    --                HR_ALL_ORGANIZATION_UNITS HOU2,
    --                MTL_RESERVATIONS MTR,
    --                OE_ORDER_LINES_ALL OLA,
    --                OE_ORDER_HEADERS_ALL OHA,
    --                PO_REQUISITION_HEADERS_ALL PORH,
    --                PO_REQUISITION_LINES_ALL PORL
    --          WHERE     1 = 1
    --                AND PRHA.REQUISITION_HEADER_ID = PRLA.REQUISITION_HEADER_ID
    --                AND PRHA.INTERFACE_SOURCE_CODE = 'CTO'
    --                AND PRHA.ORG_ID = HOU2.ORGANIZATION_ID
    --                AND PRLA.CREATION_DATE >=
    --                         SYSDATE
    --                       - NVL (P_NUM_OF_DAYS, SYSDATE - PRLA.CREATION_DATE)
    --                AND PRLA.LINE_LOCATION_ID IS NULL
    --                AND PRLA.ORG_ID = P_OU
    --                AND (   PRLA.VENDOR_ID IS NULL
    --                     OR PRLA.VENDOR_SITE_ID IS NULL
    --                     OR PRLA.SUGGESTED_VENDOR_NAME IS NULL
    --                     OR PRLA.SUGGESTED_VENDOR_LOCATION IS NULL)
    --                AND MTR.SUPPLY_SOURCE_HEADER_ID = PRLA.REQUISITION_HEADER_ID -- SRC_HDR_ID
    --                AND MTR.SUPPLY_SOURCE_LINE_ID = PRLA.REQUISITION_LINE_ID --not using orig_supply_source_line_id as these reservations will
    --                --be in their original state at this point (pointing to requisition line)
    --                AND MTR.SUPPLY_SOURCE_TYPE_ID = 17               --Requisition
    --                AND MTR.DEMAND_SOURCE_LINE_ID = OLA.LINE_ID
    --                AND OHA.HEADER_ID = OLA.HEADER_ID
    --                AND PORH.ORG_ID = HOU.ORGANIZATION_ID
    --                AND OLA.SOURCE_DOCUMENT_ID = PORH.REQUISITION_HEADER_ID
    --                AND OLA.SOURCE_DOCUMENT_LINE_ID = PORL.REQUISITION_LINE_ID
    --                AND PORH.ORG_ID = HOU.ORGANIZATION_ID
    --                AND PORH.REQUISITION_HEADER_ID = PORL.REQUISITION_HEADER_ID;

    --      TYPE UPDATE_REQ_b2b_TYPE IS TABLE OF UPDATE_REQ_b2b%ROWTYPE
    --         INDEX BY BINARY_INTEGER;

    --      REQ_b2b_TAB                  UPDATE_REQ_b2b_TYPE;

    --      V_SUGGESTED_VENDOR_ID        NUMBER;
    --      V_SUGGESTED_VENDOR_SITE_ID   NUMBER;

    --      V_PROFILE_VALUE              VARCHAR2 (100);

    --      v_count                      NUMBER;
    --   BEGIN
    --      fnd_file.PUT_LINE (fnd_file.LOG, 'xxd_populate_b2b_sourcing - enter');

    --      --Open cursor
    --      OPEN UPDATE_REQ_b2b;

    --      v_count := 1;

    --      --
    --      LOOP
    --         FETCH UPDATE_REQ_b2b
    --            BULK COLLECT INTO REQ_b2b_TAB
    --            LIMIT 1000;

    --         EXIT WHEN REQ_b2b_TAB.COUNT = 0;
    --         --Modification starts as per defect#3379
    --         V_SUGGESTED_VENDOR_ID := NULL;
    --         V_SUGGESTED_VENDOR_SITE_ID := NULL;

    --         --Modification ends as per defect#3379
    --         --Populate table with vendor/vendor site data from sourcing function
    --         FOR l_INDEX IN REQ_b2b_TAB.FIRST .. REQ_b2b_TAB.LAST
    --         LOOP
    --            --Modification starts as per defect#3379
    --            XXD_REQ_VENDOR_DET (
    --               REQ_b2b_TAB (l_INDEX).ORG_ID,
    --               REQ_b2b_TAB (l_INDEX).destination_organization_id,
    --               REQ_b2b_TAB (l_INDEX).ITEM_ID,
    --               REQ_b2b_TAB (l_INDEX).CREATION_DATE,
    --               REQ_b2b_TAB (l_INDEX).internal_req_ORG,
    --               REQ_b2b_TAB (l_INDEX).ORDER_TYPE,
    --               V_SUGGESTED_VENDOR_ID,
    --               V_SUGGESTED_VENDOR_SITE_ID);
    --            REQ_b2b_TAB (l_INDEX).VENDOR_SITE_ID := V_SUGGESTED_VENDOR_SITE_ID;
    --            REQ_b2b_TAB (l_INDEX).VENDOR_ID := V_SUGGESTED_VENDOR_ID;

    --            --Modification ends as per defect#3379
    --            /*REQ_b2b_TAB (l_INDEX).VENDOR_SITE_ID :=
    --               XXD_REQ_VENDOR_SITE_ID (
    --                  REQ_b2b_TAB (l_INDEX).ORG_ID,
    --                  REQ_b2b_TAB (l_INDEX).destination_organization_id,
    --                  REQ_b2b_TAB (l_INDEX).ITEM_ID,
    --                  REQ_b2b_TAB (l_INDEX).CREATION_DATE,
    --                  REQ_b2b_TAB (l_INDEX).internal_req_ORG,
    --                  'B2B');*/
    --            --commented as per defect#3379

    --            --get vendor site code
    --            IF REQ_b2b_TAB (l_INDEX).VENDOR_SITE_ID IS NOT NULL
    --            THEN
    --               SELECT VENDOR_SITE_CODE
    --                 INTO REQ_b2b_TAB (l_INDEX).Suggested_vendor_location
    --                 FROM AP_SUPPLIER_SITES_ALL
    --                WHERE VENDOR_SITE_ID = REQ_b2b_TAB (l_INDEX).VENDOR_SITE_ID;
    --            END IF;

    --            /*REQ_b2b_TAB (l_INDEX).VENDOR_ID :=
    --               XXD_REQ_VENDOR_ID (
    --                  REQ_b2b_TAB (l_INDEX).ORG_ID,
    --                  REQ_b2b_TAB (l_INDEX).destination_organization_id,
    --                  REQ_b2b_TAB (l_INDEX).ITEM_ID,
    --                  REQ_b2b_TAB (l_INDEX).CREATION_DATE,
    --                  REQ_b2b_TAB (l_INDEX).internal_req_ORG,
    --                  'B2B');*/
    --            ----commented as per defect#3379

    --            --get vendor name
    --            IF REQ_b2b_TAB (l_INDEX).VENDOR_ID IS NOT NULL
    --            THEN
    --               SELECT VENDOR_NAME
    --                 INTO REQ_b2b_TAB (l_INDEX).Suggested_vendor_name
    --                 FROM AP_SUPPLIERS
    --                WHERE VENDOR_ID = REQ_b2b_TAB (l_INDEX).VENDOR_ID;
    --            END IF;

    --            --Modification starts as per defect#3379
    --            V_SUGGESTED_VENDOR_ID := NULL;
    --            V_SUGGESTED_VENDOR_SITE_ID := NULL;
    --         --Modification ends as per defect#3379
    --         END LOOP;

    --         --Update requisition lines with data from table
    --         FORALL i IN REQ_b2b_TAB.FIRST .. REQ_b2b_TAB.LAST
    --            UPDATE PO_REQUISITION_LINES_ALL
    --               SET VENDOR_ID = REQ_b2b_TAB (i).VENDOR_ID,
    --                   VENDOR_SITE_ID = REQ_b2b_TAB (i).VENDOR_SITE_ID,
    --                   Suggested_vendor_name =
    --                      REQ_b2b_TAB (i).Suggested_vendor_name,
    --                   Suggested_vendor_location =
    --                      REQ_b2b_TAB (i).Suggested_vendor_location
    --             WHERE     REQUISITION_LINE_ID =
    --                          REQ_b2b_TAB (i).REQUISITION_LINE_ID
    --                   AND REQ_b2b_TAB (i).VENDOR_ID IS NOT NULL
    --                   AND REQ_b2b_TAB (i).VENDOR_SITE_ID IS NOT NULL;

    --         fnd_file.PUT_LINE (
    --            fnd_file.LOG,
    --               'No of lines updated for B2B in batch('
    --            || v_count
    --            || '):'
    --            || SQL%ROWCOUNT);

    --         v_count := v_count + 1;
    --      END LOOP;

    --      --close cursor
    --      CLOSE UPDATE_REQ_b2b;

    --      fnd_file.PUT_LINE (fnd_file.LOG, 'xxd_populate_b2b_sourcing - exit');
    --   EXCEPTION
    --      WHEN OTHERS
    --      THEN
    --         IF UPDATE_REQ_b2b%ISOPEN
    --         THEN
    --            CLOSE UPDATE_REQ_b2b;
    --         END IF;
    --   END;

    --Populate sourcing for drop ship requisitions in the org going back a specific number of days
    --Input          p_ou        Operating Unit
    --               p_num_of_days   Number of days to look back for reqs
    --   PROCEDURE XXD_POPULATE_DS_SOURCING (p_ou            IN NUMBER,
    --                                       p_num_of_days   IN NUMBER)
    --   IS
    --      CURSOR UPDATE_REQ_DROP_SHIP
    --      IS
    --         SELECT PRLA.ORG_ID,
    --                PRLA.DESTINATION_ORGANIZATION_ID,
    --                PRLA.ITEM_ID,
    --                PRHA.CREATION_DATE,
    --                PRLA.VENDOR_ID,
    --                PRLA.VENDOR_SITE_ID,
    --                PRLA.REQUISITION_LINE_ID,
    --                PRLA.SUGGESTED_VENDOR_NAME,
    --                PRLA.SUGGESTED_VENDOR_LOCATION,
    --                HOU.NAME SO_ORG,
    --                'DROP SHIP' ORDER_TYPE
    --           FROM PO_REQUISITION_LINES_ALL PRLA,
    --                PO_REQUISITION_HEADERS_ALL PRHA,
    --                OE_DROP_SHIP_SOURCES OEDSS,
    --                oe_order_headers_all oha,
    --                oe_order_LINEs_all ola,
    --                HR_ALL_ORGANIZATION_UNITS hou
    --          --, HR_ALL_ORGANIZATION_UNITS hou2
    --          WHERE     OEDSS.PO_LINE_ID IS NULL
    --                AND OEDSS.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
    --                AND OHA.HEADER_ID = OEDSS.HEADER_ID
    --                AND oha.HEADER_ID = ola.HEADER_ID
    --                AND OLA.LINE_ID = OEDSS.LINE_ID
    --                AND NVL (
    --                       (SELECT PLA.ORG_ID
    --                          FROM PO_LINES_ALL PLA,
    --                               HR_ALL_ORGANIZATION_UNITS hou1
    --                         WHERE     PLA.ATTRIBUTE_CATEGORY =
    --                                      'Intercompany PO Copy'
    --                               -- AND PLA.ATTRIBUTE5 = OLA.LINE_ID --commented as per defect#3379
    --                               AND TO_NUMBER (NVL (pla.attribute5, 1)) =
    --                                      OLA.LINE_ID   --added as per defect#3379
    --                               AND PLA.ORG_ID = HOU1.ORGANIZATION_ID
    --                               AND HOU1.NAME = 'Deckers Japan OU'),
    --                       OHA.ORG_ID) = HOU.ORGANIZATION_ID
    --                AND prha.requisition_header_id = prla.requisition_header_id
    --                AND prha.InterFace_Source_Code = 'ORDER ENTRY'
    --                -- AND PRHA.ORG_ID = HOU2.ORGANIZATION_ID
    --                AND (   PRLA.VENDOR_ID IS NULL
    --                     OR PRLA.VENDOR_SITE_ID IS NULL
    --                     OR prla.suggested_vendor_name IS NULL
    --                     OR prla.suggested_vendor_location IS NULL)
    --                AND PRLA.CREATION_DATE >=
    --                         SYSDATE
    --                       - NVL (p_num_of_days, SYSDATE - PRLA.CREATION_DATE) --added as per defect#3379
    --                AND PRLA.LINE_LOCATION_ID IS NULL         ----ADDED ON 03JUN15
    --                --AND HOU2.NAME = 'Deckers Macau OU' --TO RESTRICT IT FOR MACAU--
    --                AND PRHA.ORG_ID = P_OU;

    --      TYPE UPDATE_REQ_DROP_SHIP_TYPE IS TABLE OF UPDATE_REQ_DROP_SHIP%ROWTYPE
    --         INDEX BY BINARY_INTEGER;

    --      REQ_DROP_SHIP_TAB            UPDATE_REQ_DROP_SHIP_TYPE;

    --      V_SUGGESTED_VENDOR_ID        NUMBER;
    --      V_SUGGESTED_VENDOR_SITE_ID   NUMBER;

    --      V_PROFILE_VALUE              VARCHAR2 (100);

    --      v_count                      NUMBER;
    --   BEGIN
    --      fnd_file.PUT_LINE (fnd_file.LOG, 'xxd_populate_ds_sourcing - enter');

    --      OPEN UPDATE_REQ_DROP_SHIP;

    --      v_count := 1;

    --      LOOP
    --         FETCH UPDATE_REQ_DROP_SHIP
    --            BULK COLLECT INTO REQ_DROP_SHIP_TAB
    --            LIMIT 1000;

    --         EXIT WHEN REQ_DROP_SHIP_TAB.COUNT = 0;
    --         --Modification starts as per defect#3379
    --         V_SUGGESTED_VENDOR_ID := NULL;
    --         V_SUGGESTED_VENDOR_SITE_ID := NULL;

    --         --Modification ends as per defect#3379

    --         FOR l_INDEX IN REQ_DROP_SHIP_TAB.FIRST .. REQ_DROP_SHIP_TAB.LAST
    --         LOOP
    --            --Modification starts as per defect#3379
    --            XXD_REQ_VENDOR_DET (
    --               REQ_DROP_SHIP_TAB (l_INDEX).ORG_ID,
    --               REQ_DROP_SHIP_TAB (l_INDEX).destination_organization_id,
    --               REQ_DROP_SHIP_TAB (l_INDEX).ITEM_ID,
    --               REQ_DROP_SHIP_TAB (l_INDEX).CREATION_DATE,
    --               REQ_DROP_SHIP_TAB (l_INDEX).SO_ORG,
    --               REQ_DROP_SHIP_TAB (l_INDEX).ORDER_TYPE,
    --               V_SUGGESTED_VENDOR_ID,
    --               V_SUGGESTED_VENDOR_SITE_ID);
    --            REQ_DROP_SHIP_TAB (l_INDEX).VENDOR_SITE_ID :=
    --               V_SUGGESTED_VENDOR_SITE_ID;
    --            REQ_DROP_SHIP_TAB (l_INDEX).VENDOR_ID := V_SUGGESTED_VENDOR_ID;

    --            --Modification ends as per defect#3379
    --            /* REQ_DROP_SHIP_TAB (l_INDEX).VENDOR_SITE_ID :=
    --                XXD_REQ_VENDOR_SITE_ID (
    --                   REQ_DROP_SHIP_TAB (l_INDEX).ORG_ID,
    --                   REQ_DROP_SHIP_TAB (l_INDEX).destination_organization_id,
    --                   REQ_DROP_SHIP_TAB (l_INDEX).ITEM_ID,
    --                   REQ_DROP_SHIP_TAB (l_INDEX).CREATION_DATE,
    --                   REQ_DROP_SHIP_TAB (l_INDEX).SO_ORG,
    --                   'DROP SHIP');*/
    --            ---commented as per defect#3379

    --            IF REQ_DROP_SHIP_TAB (l_INDEX).VENDOR_SITE_ID IS NOT NULL
    --            THEN
    --               SELECT VENDOR_SITE_CODE
    --                 INTO REQ_DROP_SHIP_TAB (l_INDEX).Suggested_vendor_location
    --                 FROM AP_SUPPLIER_SITES_ALL
    --                WHERE VENDOR_SITE_ID =
    --                         REQ_DROP_SHIP_TAB (l_INDEX).VENDOR_SITE_ID;
    --            END IF;

    --            /* REQ_DROP_SHIP_TAB (l_INDEX).VENDOR_ID :=
    --                XXD_REQ_VENDOR_ID (
    --                   REQ_DROP_SHIP_TAB (l_INDEX).ORG_ID,
    --                   REQ_DROP_SHIP_TAB (l_INDEX).destination_organization_id,
    --                   REQ_DROP_SHIP_TAB (l_INDEX).ITEM_ID,
    --                   REQ_DROP_SHIP_TAB (l_INDEX).CREATION_DATE,
    --                   REQ_DROP_SHIP_TAB (l_INDEX).SO_ORG,
    --                   'DROP SHIP');*/
    --            ---commented as per defect#3379

    --            IF REQ_DROP_SHIP_TAB (l_INDEX).VENDOR_ID IS NOT NULL
    --            THEN
    --               SELECT VENDOR_NAME
    --                 INTO REQ_DROP_SHIP_TAB (l_INDEX).Suggested_vendor_name
    --                 FROM AP_SUPPLIERS
    --                WHERE VENDOR_ID = REQ_DROP_SHIP_TAB (l_INDEX).VENDOR_ID;
    --            END IF;

    --            --Modification starts as per defect#3379
    --            V_SUGGESTED_VENDOR_ID := NULL;
    --            V_SUGGESTED_VENDOR_SITE_ID := NULL;
    --         --Modification ends as per defect#3379
    --         END LOOP;

    --         FORALL i IN REQ_DROP_SHIP_TAB.FIRST .. REQ_DROP_SHIP_TAB.LAST
    --            UPDATE PO_REQUISITION_LINES_ALL
    --               SET VENDOR_ID = REQ_DROP_SHIP_TAB (i).VENDOR_ID,
    --                   VENDOR_SITE_ID = REQ_DROP_SHIP_TAB (i).VENDOR_SITE_ID,
    --                   Suggested_vendor_name =
    --                      REQ_DROP_SHIP_TAB (i).Suggested_vendor_name,
    --                   Suggested_vendor_location =
    --                      REQ_DROP_SHIP_TAB (i).Suggested_vendor_location
    --             WHERE     REQUISITION_LINE_ID =
    --                          REQ_DROP_SHIP_TAB (i).REQUISITION_LINE_ID
    --                   AND REQ_DROP_SHIP_TAB (i).VENDOR_ID IS NOT NULL
    --                   AND REQ_DROP_SHIP_TAB (i).VENDOR_SITE_ID IS NOT NULL;

    --         fnd_file.PUT_LINE (
    --            fnd_file.LOG,
    --               'No of lines updated for DROP SHIP in batch('
    --            || v_count
    --            || '):'
    --            || SQL%ROWCOUNT);

    --         v_count := v_count + 1;
    --      END LOOP;

    --      fnd_file.PUT_LINE (fnd_file.LOG, 'xxd_populate_ds_sourcing - exit');

    --      CLOSE UPDATE_REQ_DROP_SHIP;
    --   EXCEPTION
    --      WHEN OTHERS
    --      THEN
    --         IF UPDATE_REQ_DROP_SHIP%ISOPEN
    --         THEN
    --            CLOSE UPDATE_REQ_DROP_SHIP;
    --         END IF;
    --   END;

    --Input          p_ou        Operating Unit
    --               p_num_of_days   Number of days to look back for reqs
    --   PROCEDURE XXDOEC_POPULATE_SFS_SOURCING (p_ou            IN NUMBER,
    --                                           p_num_of_days   IN NUMBER)
    --   IS
    --      CURSOR UPDATE_REQ_SFS_DROP_SHIP (
    --         V_PROFILE_VALUE VARCHAR2)
    --      IS
    --         SELECT PRLA.ORG_ID,
    --                PRLA.DESTINATION_ORGANIZATION_ID,
    --                PRLA.ITEM_ID,
    --                PRHA.CREATION_DATE,
    --                PRLA.VENDOR_ID,
    --                PRLA.VENDOR_SITE_ID,
    --                PRLA.REQUISITION_LINE_ID,
    --                PRLA.SUGGESTED_VENDOR_NAME,
    --                PRLA.SUGGESTED_VENDOR_LOCATION,
    --                HOU.NAME SO_ORG,
    --                ssd.unit_price retail_cost
    --           FROM XXDOEC_SFS_SHIPMENT_DTLS_STG SSD,
    --                PO_REQUISITION_LINES_ALL PRLA,
    --                PO_REQUISITION_HEADERS_ALL PRHA,
    --                OE_DROP_SHIP_SOURCES OEDSS,
    --                oe_order_headers_all oha,
    --                oe_order_LINEs_all ola,
    --                HR_ALL_ORGANIZATION_UNITS hou
    --          WHERE     OEDSS.PO_LINE_ID IS NULL
    --                AND OEDSS.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
    --                AND OHA.HEADER_ID = OEDSS.HEADER_ID
    --                AND oha.HEADER_ID = ola.HEADER_ID
    --                AND OLA.LINE_ID = OEDSS.LINE_ID
    --                AND SSD.LINE_ID = OLA.LINE_ID
    --                AND NVL (SSD.PROCESS_FLAG, 'N') = 'N'
    --                AND NVL (
    --                       (SELECT PLA.ORG_ID
    --                          FROM PO_LINES_ALL PLA,
    --                               HR_ALL_ORGANIZATION_UNITS hou1
    --                         WHERE     PLA.ATTRIBUTE_CATEGORY =
    --                                      'Intercompany PO Copy'
    --                               -- AND PLA.ATTRIBUTE5 = OLA.LINE_ID --commented as per defect#3379
    --                               AND TO_NUMBER (NVL (pla.attribute5, 1)) =
    --                                      OLA.LINE_ID   --added as per defect#3379
    --                               AND PLA.ORG_ID = HOU1.ORGANIZATION_ID
    --                               AND HOU1.NAME = 'Deckers Japan OU'),
    --                       OHA.ORG_ID) = HOU.ORGANIZATION_ID
    --                AND prha.requisition_header_id = prla.requisition_header_id
    --                AND prha.InterFace_Source_Code = 'ORDER ENTRY'
    --                AND PRLA.CREATION_DATE >=
    --                         SYSDATE
    --                       - NVL (p_num_of_days, SYSDATE - PRLA.CREATION_DATE) --added as per defect#3379
    --                AND PRLA.LINE_LOCATION_ID IS NULL
    --                AND PRHA.ORG_ID = P_OU;

    --      V_SUGGESTED_VENDOR_ID         NUMBER;
    --      V_SUGGESTED_VENDOR_SITE_ID    NUMBER;
    --      v_suggested_buyer_id          NUMBER;
    --      v_Suggested_vendor_name       VARCHAR2 (120);
    --      v_Suggested_vendor_location   VARCHAR2 (120);
    --      V_PROFILE_VALUE               VARCHAR2 (100);
    --   BEGIN
    --      V_SUGGESTED_VENDOR_ID := NULL;
    --      V_SUGGESTED_VENDOR_SITE_ID := NULL;
    --      v_suggested_buyer_id := NULL;
    --      V_PROFILE_VALUE := NULL;

    --      SELECT profile_option_name
    --        INTO V_PROFILE_VALUE
    --        FROM FND_PROFILE_OPTIONS_vl
    --       WHERE user_profile_option_name = 'MO: Security Profile';

    --      SELECT VENDOR_NAME, VENDOR_ID
    --        INTO v_Suggested_vendor_name, V_SUGGESTED_VENDOR_ID
    --        FROM AP_SUPPLIERS
    --       WHERE VENDOR_NAME = 'Deckers Retail Stores';

    --      SELECT VENDOR_SITE_CODE, VENDOR_SITE_ID
    --        INTO v_Suggested_vendor_location, V_SUGGESTED_VENDOR_SITE_ID
    --        FROM AP_SUPPLIER_SITES_ALL
    --       WHERE     VENDOR_ID = V_SUGGESTED_VENDOR_ID
    --             AND ORG_ID = P_OU
    --             AND VENDOR_SITE_CODE = 'SFS-US';

    --      SELECT AGENT_ID
    --        INTO v_suggested_buyer_id
    --        FROM po_agents_v
    --       WHERE agent_name = 'SFS-US, BUYER';

    --      FOR sfs IN UPDATE_REQ_SFS_DROP_SHIP (V_PROFILE_VALUE)
    --      LOOP
    --         UPDATE PO_REQUISITION_LINES_ALL
    --            SET VENDOR_ID = V_SUGGESTED_VENDOR_ID,
    --                VENDOR_SITE_ID = V_SUGGESTED_VENDOR_SITE_ID,
    --                Suggested_vendor_name = v_Suggested_vendor_name,
    --                Suggested_vendor_location = v_Suggested_vendor_location,
    --                suggested_buyer_id = v_suggested_buyer_id,
    --                unit_price = sfs.retail_cost
    --          WHERE     REQUISITION_LINE_ID = sfs.REQUISITION_LINE_ID
    --                AND NVL (VENDOR_SITE_ID, -99) <> V_SUGGESTED_VENDOR_SITE_ID;
    --      END LOOP;

    --      COMMIT;
    --   EXCEPTION
    --      WHEN OTHERS
    --      THEN
    --         Fnd_File.PUT_LINE (
    --            Fnd_File.output,
    --               'Unable to find SFS Vendor / Vendor Site / Buyer to update SFS Drop ship Reqs '
    --            || SQLERRM);
    --   END xxdoec_populate_sfs_sourcing;

    --Approve a set of POs by batch ID
    --Input     p_batch_id      Batch ID to process
    --          p_po_status     Status to set POs
    --Output    p_errbuf        Error code
    --          p_retcode       Return code
    PROCEDURE xxd_approve_po (p_batch_id IN NUMBER, p_po_status IN VARCHAR2, p_errbuf OUT VARCHAR2
                              , p_retcode OUT NUMBER)
    IS
        v_resp_appl_id    NUMBER;
        v_resp_id         NUMBER;
        v_user_id         NUMBER;
        l_result          NUMBER;
        v_line_num        NUMBER;
        v_shipment_num    NUMBER;
        v_revision_num    NUMBER;
        l_api_errors      po_api_errors_rec_type;

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
                   po_line_locations_all plla, po_lines_all pla, po_req_distributions_all prda,
                   po_document_types_all pdt
             WHERE     phi.batch_id = p_batch_id
                   AND phi.po_header_id = poh.po_header_id
                   AND plit.interface_header_id = phi.interface_header_id
                   AND plit.po_line_id = pla.po_line_id
                   AND prla.need_by_date != plla.need_by_date
                   AND pda.po_header_id = poh.po_header_id
                   AND plla.po_header_id = poh.po_header_id
                   AND pla.po_header_id = poh.po_header_id
                   AND plla.po_line_id = pla.po_line_id
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
        fnd_file.put_line (fnd_file.LOG, '--Approve PO : Enter');

        IF UPPER (p_po_status) = 'APPROVED'
        THEN
            OPEN cur_po_appr;

            LOOP
                FETCH cur_po_appr INTO cur_po_appr_rec;

                EXIT WHEN cur_po_appr%NOTFOUND;
                fnd_file.put_line (fnd_file.LOG, 'PO to approve');
                fnd_file.put_line (
                    fnd_file.LOG,
                    '--PO Number : ' || cur_po_appr_rec.po_num);
                fnd_file.put_line (
                    fnd_file.LOG,
                    '--Agent ID : ' || cur_po_appr_rec.agent_id);
                po_reqapproval_init1.start_wf_process (
                    itemtype                 => 'POAPPRV',
                    itemkey                  => cur_po_appr_rec.wf_item_key,
                    workflowprocess          => 'XXDO_POAPPRV_TOP',
                    actionoriginatedfrom     => 'PO_FORM',
                    documentid               => cur_po_appr_rec.po_header_id-- po_header_id
                                                                            ,
                    documentnumber           => cur_po_appr_rec.po_num-- Purchase Order Number
                                                                      ,
                    preparerid               => cur_po_appr_rec.agent_id-- Buyer/Preparer_id
                                                                        ,
                    documenttypecode         => 'PO'                    --'PO'
                                                    ,
                    documentsubtype          => 'STANDARD'--'STANDARD'
                                                          ,
                    submitteraction          => 'APPROVE',
                    forwardtoid              => NULL,
                    forwardfromid            => NULL,
                    defaultapprovalpathid    => NULL,
                    note                     => NULL,
                    printflag                => 'N',
                    faxflag                  => 'N',
                    faxnumber                => NULL,
                    emailflag                => 'N',
                    emailaddress             => NULL,
                    createsourcingrule       => 'N',
                    releasegenmethod         => 'N',
                    updatesourcingrule       => 'N',
                    massupdatereleases       => 'N',
                    retroactivepricechange   => 'N',
                    orgassignchange          => 'N',
                    communicatepricechange   => 'N',
                    p_background_flag        => 'N',
                    p_initiator              => NULL,
                    p_xml_flag               => NULL,
                    fpdsngflag               => 'N',
                    p_source_type_code       => NULL);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'wf approval success: ' || cur_po_appr_rec.po_num);
            END LOOP;

            CLOSE cur_po_appr;
        END IF;

        fnd_file.put_line (fnd_file.LOG, '--Approve PO : Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_po_appr%ISOPEN
            THEN
                CLOSE cur_po_appr;
            END IF;

            p_retcode   := 1;
            p_errbuf    := p_errbuf || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Approve PO error' || p_errbuf);
    --ROLLBACK;
    END;

    --Input         p_batch_id      batch to proces
    --              p_po_status     PO status status flag
    --Output        p_errbuf        Error code
    --              p_retcode       Return code
    PROCEDURE xxd_update_needby_date (p_batch_id IN NUMBER, p_po_status IN VARCHAR2, p_errbuf OUT VARCHAR2
                                      , p_retcode OUT NUMBER)
    IS
        v_resp_appl_id     NUMBER;
        v_resp_id          NUMBER;
        v_user_id          NUMBER;
        l_result           NUMBER;
        v_line_num         NUMBER;
        v_shipment_num     NUMBER;
        v_revision_num     NUMBER;
        l_api_errors       po_api_errors_rec_type;

        CURSOR cur_po_headers IS
              SELECT poh.segment1 po_num, poh.po_header_id, prha.segment1 requisition_num,
                     prla.line_num requisition_line_num, plla.shipment_num, prla.need_by_date,
                     plla.need_by_date po_need_by_date, poh.org_id, pla.line_num,
                     poh.agent_id, pdt.document_subtype, pdt.document_type_code,
                     poh.wf_item_key
                FROM po_headers_all poh, po_headers_interface phi, po_lines_interface plit,
                     po_requisition_headers_all prha, po_requisition_lines_all prla, po_distributions_all pda,
                     po_line_locations_all plla, po_lines_all pla, po_req_distributions_all prda,
                     po_document_types_all pdt
               WHERE     phi.batch_id = p_batch_id
                     AND phi.po_header_id = poh.po_header_id
                     AND plit.interface_header_id = phi.interface_header_id
                     AND plit.po_line_id = pla.po_line_id
                     AND prla.need_by_date != plla.need_by_date
                     AND pda.po_header_id = poh.po_header_id
                     AND plla.po_header_id = poh.po_header_id
                     AND pla.po_header_id = poh.po_header_id
                     AND plla.po_line_id = pla.po_line_id
                     AND plla.line_location_id = pda.line_location_id
                     AND pda.req_distribution_id = prda.distribution_id
                     AND prda.requisition_line_id = prla.requisition_line_id
                     AND prla.requisition_header_id =
                         prha.requisition_header_id
                     AND pdt.org_id = poh.org_id
                     AND poh.type_lookup_code = pdt.document_subtype
                     AND pdt.document_type_code = 'PO'
            ORDER BY poh.segment1, pla.line_num;

        TYPE cur_po_headers_tab IS TABLE OF cur_po_headers%ROWTYPE
            INDEX BY BINARY_INTEGER;

        cur_po_headers_t   cur_po_headers_tab;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '--Update Need By Date : Enter');

        OPEN cur_po_headers;

        LOOP
            FETCH cur_po_headers
                BULK COLLECT INTO cur_po_headers_t
                LIMIT 5000;

            fnd_file.put_line (fnd_file.LOG, 'after line loop');
            EXIT WHEN cur_po_headers_t.COUNT = 0;
            fnd_file.put_line (fnd_file.LOG, 'after exit');

            -- IF cur_po_headers_T.COUNT >0
            -- THEN
            FOR i IN cur_po_headers_t.FIRST .. cur_po_headers_t.LAST
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                       'PO: Need by date : '
                    || TO_CHAR (cur_po_headers_t (i).po_need_by_date,
                                'MM,dd,yyyy'));
                fnd_file.put_line (
                    fnd_file.LOG,
                       'REQ: Need by date : '
                    || TO_CHAR (cur_po_headers_t (i).need_by_date,
                                'MM,dd,yyyy'));

                SELECT NVL (revision_num, 0)
                  INTO v_revision_num
                  FROM po_headers_all
                 WHERE     segment1 = cur_po_headers_t (i).po_num
                       AND org_id = cur_po_headers_t (i).org_id;

                BEGIN
                    l_result   :=
                        po_change_api1_s.update_po (
                            x_po_number             => cur_po_headers_t (i).po_num,
                            x_release_number        => NULL,
                            x_revision_number       => v_revision_num,
                            x_line_number           =>
                                cur_po_headers_t (i).line_num,
                            x_shipment_number       =>
                                cur_po_headers_t (i).shipment_num,
                            new_quantity            => NULL,
                            new_price               => NULL,
                            new_promised_date       =>
                                cur_po_headers_t (i).need_by_date,
                            new_need_by_date        =>
                                cur_po_headers_t (i).need_by_date,
                            launch_approvals_flag   => 'N',                 --
                            update_source           => NULL,
                            VERSION                 => '1.0',
                            x_override_date         => NULL,
                            x_api_errors            => l_api_errors,
                            p_buyer_name            => NULL,
                            p_secondary_quantity    => NULL,
                            p_preferred_grade       => NULL,
                            p_org_id                =>
                                cur_po_headers_t (i).org_id);

                    IF l_result <> 1
                    THEN
                        FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                        LOOP
                            p_errbuf   :=
                                p_errbuf || l_api_errors.MESSAGE_TEXT (i);
                        -- || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
                        END LOOP;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'update api error PO#'
                            || cur_po_headers_t (i).po_num
                            || ' line_num:'
                            || cur_po_headers_t (i).line_num
                            || p_errbuf);
                        p_retcode   := 1;
                    ELSE
                        -- P_RETCODE := 0;
                        p_errbuf   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'update api success PO#'
                            || cur_po_headers_t (i).po_num
                            || ' line_num:'
                            || cur_po_headers_t (i).line_num);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_errbuf    := 'When others API' || SQLERRM;
                        p_retcode   := 1;
                        fnd_file.put_line (fnd_file.LOG, p_errbuf);
                -- return;
                END;
            END LOOP;
        --       cur_po_headers_t.DELETE;
        --ELSE
        -- EXIT;
        -- END IF;
        END LOOP;

        CLOSE cur_po_headers;

        fnd_file.put_line (fnd_file.LOG, '--Update Need By Date : Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_po_headers%ISOPEN
            THEN
                CLOSE cur_po_headers;
            END IF;

            p_retcode   := 1;
            p_errbuf    := p_errbuf || SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'need by date update error' || p_errbuf);
    --ROLLBACK;
    END xxd_update_needby_date;

    --Modification ends for Defect#3280

    -------------------------------------------

    --Insert into PO Headers interface for nontrade requisitions
    --Input      p_batch_id      batch to process
    --           p_buyer_id      buyer id to check
    --           p_ou            ou to check
    --           p_reqid         req_header_id to check
    --Output     p_errbuff       Error message
    --           p_retcode       return code
    PROCEDURE xxd_insert_headers (p_batch_id   IN     NUMBER,
                                  p_errbuf        OUT VARCHAR2,
                                  p_retcode       OUT NUMBER,
                                  p_buyer_id   IN     NUMBER,
                                  p_ou         IN     NUMBER,
                                  p_req_id     IN     NUMBER)
    IS
        CURSOR cur_po_headers_interface IS
            SELECT DISTINCT
                   'STANDARD' type_lookup_code,
                   prha.org_id,
                   --   MCB.ATTRIBUTE1 agent_id,
                   NVL (
                       (SELECT approver_id FROM TABLE (xxd_po_req_approval_pkg.get_post_apprvrlist (prha.requisition_header_id))),
                       (SELECT pf1.person_id
                          FROM fnd_lookup_values fv, per_people_f pf, per_people_f pf1
                         WHERE     fv.lookup_type =
                                   'XXDO_REQ_BUYER_APPR_LIST'
                               AND fv.LANGUAGE = 'US'
                               AND fv.enabled_flag = 'Y'
                               AND SYSDATE BETWEEN fv.start_date_active
                                               AND NVL (
                                                       fv.end_date_active,
                                                       SYSDATE + 1)
                               AND pf.person_id = mcb.attribute1
                               AND pf.full_name = fv.description
                               AND tag =
                                   (SELECT MIN (tag)
                                      FROM fnd_lookup_values fv1
                                     WHERE     fv1.lookup_type =
                                               'XXDO_REQ_BUYER_APPR_LIST'
                                           AND fv1.LANGUAGE = 'US'
                                           AND fv1.enabled_flag =
                                               'Y'
                                           AND SYSDATE BETWEEN fv1.start_date_active
                                                           AND NVL (
                                                                   fv1.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND pf.full_name =
                                               fv1.description)
                               AND fv.meaning = pf1.full_name)) agent_id,
                   prla.vendor_id vendor_id,
                   prla.vendor_site_id vendor_site_id,
                   NVL (prla.currency_code, leg.currency_code) currency_code,
                   CASE
                       WHEN leg.currency_code != prla.currency_code
                       THEN
                           prla.rate_type
                       ELSE
                           NULL
                   END rate_type,
                   CASE
                       WHEN leg.currency_code != prla.currency_code
                       THEN
                           prla.rate_date
                       ELSE
                           NULL
                   END rate_date,
                   CASE
                       WHEN leg.currency_code != prla.currency_code THEN -- round(PRLA.rate,2)
                                                                         NULL
                       ELSE NULL
                   END rate,
                   DECODE (
                       prla.pcard_flag,
                       'Y', prha.pcard_id,
                       'S', NVL (
                                (po_pcard_pkg.get_valid_pcard_id (-99999, prla.vendor_id, prla.vendor_site_id)),
                                -99999),
                       'N', NULL) pcard_id,
                   --PRLA.deliver_to_location_id SHIP_TO_LOCATION_ID,
                   NULL ship_to_location_id,
                   prha.requisition_header_id requisition_header_id
              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prda,
                   gl_ledgers leg, mtl_categories_b mcb, /*MTL_CATEGORY_SETS_VL MCS,
                                                         mtl_item_categories mic,*/
                                                         ap_suppliers aps,
                   mtl_parameters mp
             WHERE     prha.authorization_status = 'APPROVED'
                   AND prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prda.requisition_line_id = prla.requisition_line_id
                   AND prda.set_of_books_id = leg.ledger_id
                   AND prla.category_id = mcb.category_id
                   /* and PRLA.item_id = mic.inventory_item_id
                    and prla.destination_organization_id = mic.organization_id
       and MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                    AND MCS.CATEGORY_SET_NAME = 'PO Item Category'
                    and mic.category_id = mcb.category_id*/
                   AND mcb.attribute_category = 'PO Mapping Data Elements'
                   AND mcb.attribute1 = NVL (p_buyer_id, mcb.attribute1)
                   AND prla.vendor_id = aps.vendor_id
                   AND aps.enabled_flag = 'Y'
                   AND prla.destination_organization_id = mp.organization_id
                   AND mp.attribute13 = 1
                   AND prla.item_id IS NULL
                   AND prla.line_location_id IS NULL
                   AND (prla.cancel_flag = 'N' OR prla.cancel_flag IS NULL) --use NVL(prla.cancel_flag,'N')='N'
                   AND prha.requisition_header_id =
                       NVL (p_req_id, prha.requisition_header_id)
                   AND prha.org_id = p_ou;

        po_headers_interface_rec   cur_po_headers_interface%ROWTYPE;
        l_ship_to_location_id      NUMBER;
    BEGIN
        OPEN cur_po_headers_interface;

        LOOP
            FETCH cur_po_headers_interface INTO po_headers_interface_rec;

            EXIT WHEN cur_po_headers_interface%NOTFOUND;

            IF cur_po_headers_interface%NOTFOUND
            THEN
                CLOSE cur_po_headers_interface;

                RETURN;
            END IF;

            IF po_headers_interface_rec.ship_to_location_id IS NULL
            THEN
                SELECT deliver_to_location_id
                  INTO l_ship_to_location_id
                  FROM po_requisition_lines_all
                 WHERE     requisition_header_id =
                           po_headers_interface_rec.requisition_header_id
                       AND ROWNUM = 1;
            ELSE
                l_ship_to_location_id   :=
                    po_headers_interface_rec.ship_to_location_id;
            END IF;

            INSERT INTO po_headers_interface (action, process_code, batch_id,
                                              document_type_code, interface_header_id, created_by, document_subtype, agent_id, creation_date, vendor_id, vendor_site_id, currency_code, rate_type, rate_date, rate, pcard_id, ship_to_location_id, org_id
                                              , attribute10, --Added for PO Type
                                                             attribute14)
                     VALUES ('ORIGINAL',
                             NULL,
                             p_batch_id,
                             'STANDARD',
                             po_headers_interface_s.NEXTVAL,
                             fnd_profile.VALUE ('USER_ID'),
                             po_headers_interface_rec.type_lookup_code,
                             po_headers_interface_rec.agent_id,
                             SYSDATE,
                             po_headers_interface_rec.vendor_id,
                             po_headers_interface_rec.vendor_site_id,
                             po_headers_interface_rec.currency_code,
                             po_headers_interface_rec.rate_type,
                             po_headers_interface_rec.rate_date,
                             po_headers_interface_rec.rate,
                             po_headers_interface_rec.pcard_id,
                             l_ship_to_location_id,
                             po_headers_interface_rec.org_id,
                             'NON_TRADE',        --Added for Non-Trade PO type
                             po_headers_interface_rec.requisition_header_id); -- Added by Infosys on 08Aug2016
        END LOOP;

        CLOSE cur_po_headers_interface;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_po_headers_interface%ISOPEN
            THEN
                CLOSE cur_po_headers_interface;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'error is' || SQLERRM || SQLCODE);
    END;

    -- insert lines into PO Lines interface for Non-Trade requisitions
    --Input      p_batch_id      batch to process
    --           p_buyer_id      buyer id to check
    --           p_ou            ou to check
    --           p_reqid         req_header_id to check
    --Output     p_errbuff       Error message
    --           p_retcode       return code
    PROCEDURE xxd_insert_lines (p_batch_id   IN     NUMBER,
                                p_errbuf        OUT VARCHAR2,
                                p_retcode       OUT NUMBER,
                                p_buyer_id   IN     NUMBER,
                                p_ou         IN     NUMBER,
                                p_req_id     IN     NUMBER)
    IS
        CURSOR cur_po_lines_interface IS
            SELECT prla.item_id,
                   -- Prla.currency_unit_price, --commented as per defect#233
                   CASE
                       WHEN prla.line_type_id =
                            (SELECT line_type_id
                               FROM po_line_types
                              WHERE line_type = 'Hourly Services')
                       THEN
                           prla.unit_price
                       ELSE
                           prla.currency_unit_price
                   END currency_unit_price,          --added as per defect#233
                   prla.quantity,
                   prla.item_description,
                   prla.unit_meas_lookup_code,
                   prla.category_id,
                   prla.requisition_line_id,
                   prla.job_id,
                   prla.need_by_date,
                   prla.line_type_id,
                   pohi.interface_header_id
              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, mtl_categories_b mcb,
                   /*MTL_CATEGORY_SETS_VL MCS,
                   mtl_item_categories mic,*/
                   --po_req_distributions_all PRDA,
                   --GL_SETS_OF_BOOKS SOB,
                   ap_suppliers aps, po_headers_interface pohi, mtl_parameters mp
             WHERE     prha.authorization_status = 'APPROVED'
                   AND prha.requisition_header_id =
                       prla.requisition_header_id
                   --AND PRDA.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
                   --AND PRDA.SET_OF_BOOKS_ID = leg.SET_OF_BOOKS_ID
                   AND prla.category_id = mcb.category_id
                   /*   and PRLA.item_id = mic.inventory_item_id
                      and prla.destination_organization_id = mic.organization_id
         and MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                      AND MCS.CATEGORY_SET_NAME = 'PO Item Category'
                      and mic.category_id = mcb.category_id */
                   AND mcb.attribute_category = 'PO Mapping Data Elements'
                   AND mcb.attribute1 = NVL (p_buyer_id, mcb.attribute1)
                   AND prla.vendor_id = aps.vendor_id
                   AND aps.enabled_flag = 'Y'
                   AND prla.destination_organization_id = mp.organization_id
                   AND mp.attribute13 = 1
                   AND pohi.vendor_id = prla.vendor_id
                   AND pohi.vendor_site_id = prla.vendor_site_id
                   AND pohi.agent_id =
                       NVL (
                           (SELECT approver_id FROM TABLE (xxd_po_req_approval_pkg.get_post_apprvrlist (prha.requisition_header_id))),
                           (SELECT pf1.person_id
                              FROM fnd_lookup_values fv, per_people_f pf, per_people_f pf1
                             WHERE     fv.lookup_type =
                                       'XXDO_REQ_BUYER_APPR_LIST'
                                   AND fv.LANGUAGE = 'US'
                                   AND fv.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN fv.start_date_active
                                                   AND NVL (
                                                           fv.end_date_active,
                                                           SYSDATE + 1)
                                   AND pf.person_id = mcb.attribute1
                                   AND pf.full_name = fv.description
                                   AND tag =
                                       (SELECT MIN (tag)
                                          FROM fnd_lookup_values fv1
                                         WHERE     fv1.lookup_type =
                                                   'XXDO_REQ_BUYER_APPR_LIST'
                                               AND fv1.LANGUAGE = 'US'
                                               AND fv1.enabled_flag = 'Y'
                                               AND SYSDATE BETWEEN fv1.start_date_active
                                                               AND NVL (
                                                                       fv1.end_date_active,
                                                                         SYSDATE
                                                                       + 1)
                                               AND pf.full_name =
                                                   fv1.description)
                                   AND fv.meaning = pf1.full_name)) --MCB.ATTRIBUTE1
                   AND pohi.org_id = prha.org_id
                   -- AND pohi.ship_to_location_id = prla.deliver_to_location_id
                   AND pohi.batch_id = p_batch_id
                   --AND pohi.currency_code =
                   --       NVL (prla.currency_code, leg.currency_code)
                   AND pohi.attribute14 =
                       TO_CHAR (prha.requisition_header_id)
                   -- Added by Infosys on 08Aug2016
                   AND prla.item_id IS NULL
                   AND prla.line_location_id IS NULL
                   AND (prla.cancel_flag = 'N' OR prla.cancel_flag IS NULL)
                   AND prha.requisition_header_id =
                       NVL (p_req_id, prha.requisition_header_id);

        po_lines_interface_rec   cur_po_lines_interface%ROWTYPE;
    BEGIN
        OPEN cur_po_lines_interface;

        LOOP
            FETCH cur_po_lines_interface INTO po_lines_interface_rec;

            EXIT WHEN cur_po_lines_interface%NOTFOUND;

            INSERT INTO po_lines_interface (action, interface_line_id, interface_header_id, unit_price, quantity, item_description, unit_of_measure, category_id, job_id, need_by_date, line_type_id, --                                         vendor_product_num,
                                                                                                                                                                                                      ip_category_id
                                            , requisition_line_id)
                 VALUES ('ORIGINAL', po_lines_interface_s.NEXTVAL, po_lines_interface_rec.interface_header_id, po_lines_interface_rec.currency_unit_price, po_lines_interface_rec.quantity, po_lines_interface_rec.item_description, po_lines_interface_rec.unit_meas_lookup_code, po_lines_interface_rec.category_id, po_lines_interface_rec.job_id, po_lines_interface_rec.need_by_date, po_lines_interface_rec.line_type_id, --                      PO_LINES_interface_REC.vendor_product_num,
                                                                                                                                                                                                                                                                                                                                                                                                                                NULL
                         , po_lines_interface_rec.requisition_line_id);
        END LOOP;

        CLOSE cur_po_lines_interface;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_po_lines_interface%ISOPEN
            THEN
                CLOSE cur_po_lines_interface;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'error is' || SQLERRM || SQLCODE);
    END;

    -- Populate Purchase orders interface records for non-trade
    --Input      p_batch_id      batch to process
    --           p_buyer_id      buyer id to check
    --           p_ou            ou to check
    --           p_po_status     Status for created POs
    --           p_reqid         req_header_id to check
    --Output     p_errbuff       Error message
    --           p_retcode       return code
    PROCEDURE xxd_populate_poi_for_nontrade (
        p_batch_id    IN            NUMBER,
        p_errbuf         OUT NOCOPY VARCHAR2,
        p_retcode        OUT NOCOPY NUMBER,
        p_buyer_id    IN            NUMBER,
        p_ou          IN            NUMBER,
        p_po_status   IN            VARCHAR2,
        p_req_id      IN            NUMBER DEFAULT NULL)
    IS
        v_batch_id   NUMBER := p_batch_id;
        v_errbuf     VARCHAR2 (100);
        v_retcode    NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '--Populate POI Non-Trade : Enter');
        xxd_insert_headers (v_batch_id, v_errbuf, v_retcode,
                            p_buyer_id, p_ou, p_req_id);

        BEGIN
            --Check if records were inserted into header. If not then exception is raised
            SELECT DISTINCT batch_id
              INTO v_batch_id
              FROM po_headers_interface
             WHERE batch_id = p_batch_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'No Non Trade requisition selected');
                p_retcode   := 2;
                p_errbuf    := 'No Non Trade requisition selected';
                RETURN;
        END;

        xxd_insert_lines (v_batch_id, v_errbuf, v_retcode,
                          p_buyer_id, p_ou, p_req_id);
        fnd_file.put_line (fnd_file.LOG, '--Populate POI Non-Trade : Exit');
        fnd_file.put_line (fnd_file.LOG, 'v_RETCODE');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                '--Populate POI Non-Trade : Exception ' || SQLERRM);
    END;

    --Main processing routing for creating POs
    PROCEDURE xxd_start_autocreate_po_pvt (
        p_errbuf         OUT NOCOPY VARCHAR2,
        p_retcode        OUT NOCOPY NUMBER,
        p_po_type     IN            VARCHAR2,                            --REQ
        p_buyer_id    IN            VARCHAR2,                            --REQ
        p_ou          IN            NUMBER,                              --REQ
        p_po_status   IN            VARCHAR2,                            --REQ
        p_user_id     IN            NUMBER,
        p_req_id      IN            NUMBER DEFAULT NULL)                 --OPT
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
        v_po_status                VARCHAR2 (50);
        n_header_cnt               NUMBER;
        n_line_cnt                 NUMBER;
        po_header_cnt              NUMBER;
        po_line_cnt                NUMBER;
        po_rejected_cnt            NUMBER;
    BEGIN
        --List parameters called
        fnd_file.put_line (fnd_file.LOG, 'PO_TYPE ' || p_po_type);
        fnd_file.put_line (fnd_file.LOG, 'BUYER_ID ' || p_buyer_id);
        fnd_file.put_line (fnd_file.LOG, 'OU ' || p_ou);
        fnd_file.put_line (fnd_file.LOG, 'P_PO_STATUS ' || p_po_status);
        fnd_file.put_line (fnd_file.LOG, 'REQ_ID ' || p_req_id);
        --Validate parameters
        --PO Type
        fnd_file.put_line (fnd_file.LOG, 'Start validation');

        IF p_po_type IS NULL
        THEN
            p_retcode   := 2;
            p_errbuf    := 'PO type not supplied.';
            RETURN;
        END IF;

        IF NOT check_for_value_set_value (glookuppotype, p_po_type)
        THEN
            p_retcode   := 2;
            p_errbuf    := 'PO Type not a valid value.';
            RETURN;
        END IF;

        --Operating Unit
        IF p_ou IS NULL
        THEN
            p_retcode   := 2;
            p_errbuf    := 'Operating unit not supplied.';
            RETURN;
        END IF;

        --Buyer ID
        --      IF P_BUYER_ID IS NULL AND P_PO_TYPE = gPOTypeTrade
        --      THEN
        --         P_retcode := 2;
        --         p_errbuf := 'Buyer ID not supplied.';
        --         RETURN;
        --      END IF;

        --PO Approval Status
        IF p_po_status IS NULL
        THEN
            p_retcode   := 2;
            p_errbuf    := 'PO Approval Status not supplied.';
            RETURN;
        END IF;

        IF NOT check_for_value_set_value (glookuppoapprovalstatus,
                                          UPPER (p_po_status))
        THEN
            p_retcode   := 2;
            p_errbuf    := 'PO Approval Status not a valid value.';
            RETURN;
        END IF;

        --End validatee parameters

        --Set batch ID for this process
        SELECT po_control_groups_s.NEXTVAL INTO v_batch_id FROM DUAL; --added for defect#2918

        fnd_file.put_line (fnd_file.LOG, 'Set batch ID : ' || v_batch_id);
        --Set Purchasing context for process
        fnd_file.put_line (fnd_file.LOG, 'Set context');
        set_purchasing_context (p_user_id, p_ou, v_err_stat,
                                v_err_msg);
        fnd_file.put_line (fnd_file.LOG,
                           'ORG_ID' || mo_global.get_current_org_id);

        IF v_err_stat != fnd_api.g_ret_sts_success
        THEN
            --Set purchasing context failed
            fnd_file.put_line (fnd_file.LOG, 'Set context failed');
            p_errbuf    := v_err_msg;
            p_retcode   := 2;
            RETURN;
        END IF;

        --End Set Purchasing Context

        --Populate PO Headers Interface and PO Lines Interface
        --Branch here for Trade and Non-Trade
        IF p_po_type = gpotypenontrade
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Populate PO Interface for Non-Trade');
            xxd_populate_poi_for_nontrade (v_batch_id, v_errbuf, v_ret_code,
                                           p_buyer_id, p_ou, p_po_status,
                                           p_req_id);
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Check insert to POI. ret_code' || v_ret_code);

        --Check if records inserted into POI if not then error.
        IF v_ret_code = 2
        THEN
            p_errbuf    := v_errbuf;
            p_retcode   := 0;
            RETURN;
        END IF;

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
        IF fnd_profile.VALUE ('XXD_PO_DATE_UPDATE') = 'Y'
        THEN
            v_po_status   := 'INCOMPLETE';
        ELSE
            v_po_status   := UPPER (p_po_status);
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Set PO status' || v_po_status);
        --Run PO Import(using function call as oposed to concurrent request so we can avoid COMMIT

        --Using this process will create all POs using the same p_batch_id.
        --Option for Drop ship type POs. Use  PO_INTERFACE_S.create_documents. Note: this function would require multiple iterations for multiple
        --PO interface headers tied to the same p_batch_id. The resultant POs would then have unique batch_ids
        --Also  PO_INTERFACE_S.create_documents does not havce a non commit option
        fnd_file.put_line (fnd_file.LOG, 'Start PO import process');
        apps.po_pdoi_pvt.start_process (
            p_api_version                  => 1.0,
            p_init_msg_list                => fnd_api.g_true,
            p_validation_level             => NULL,
            p_commit                       => fnd_api.g_false,
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
            p_approved_status              => v_po_status,
            p_process_code                 => NULL,
            p_interface_header_id          => NULL,
            p_org_id                       => p_ou,
            p_ga_flag                      => NULL,
            p_submit_dft_flag              => 'N',
            p_role                         => 'BUYER',
            p_catalog_to_expire            => NULL,
            p_err_lines_tolerance          => NULL,
            p_group_lines                  => 'N',
            p_group_shipments              => 'N',
            p_clm_flag                     => NULL,
            --CLM PDOI Project
            x_processed_lines_count        => v_processed_lines_count,
            x_rejected_lines_count         => v_rejected_lines_count,
            x_err_tolerance_exceeded       => v_err_tolerance_exceeded);
        fnd_file.put_line (fnd_file.LOG,
                           'Check PO import error ' || v_return_status);

        --Check for process error
        --If this process fails then we need to exit
        IF v_return_status = (fnd_api.g_ret_sts_error)
        THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'CREATE api error:' || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F'));
                p_errbuf   :=
                       p_errbuf
                    || 'CREATE api error:'
                    || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            --Do we rollback inserts to POI?
            ROLLBACK;
            p_retcode   := 2;
            RETURN;
        ELSIF v_return_status = (fnd_api.g_ret_sts_error)
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error = ''E''');
            fnd_file.put_line (fnd_file.LOG,
                               'Count ' || fnd_msg_pub.count_msg);

            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'CREATE API UNEXPECTED ERROR:' || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F'));
                p_errbuf   :=
                    SUBSTR (
                           p_errbuf
                        || 'CREATE API UNEXPECTED ERROR:'
                        || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F'),
                        1,
                        200);
            END LOOP;

            --Do we rollback inserts to POI?
            ROLLBACK;
            p_retcode   := 2;
            RETURN;
        END IF;

        --Log generated PO lines and POI errors to the log file
        fnd_file.put_line (fnd_file.LOG, 'Show PO Data');
        --Show PO Data imported (Log only)
        show_batch_po_data (v_batch_id);
        fnd_file.put_line (fnd_file.LOG, 'Show POI Errors');
        --Show PO Interface Errors (Log only)
        show_batch_poi_errors (v_batch_id);

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

            fnd_file.put_line (
                fnd_file.LOG,
                   v_batch_id
                || ' POs were rejected. See po_interface_errors for details');

            IF po_header_cnt = 0
            THEN
                p_errbuf    := 'All POI records failed to interface to POs';
                p_retcode   := 1;                             --Return warning
                ROLLBACK;
                RETURN;
            END IF;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Update Need by Date');

        --Modification starts for Defect#3280
        IF fnd_profile.VALUE ('XXD_PO_DATE_UPDATE') = 'Y'
        THEN
            --This was aded for a workaround for defect 3280 in Quality Center (BT in Oct 2015). There was a corresponding Oracle-SR raised
            --for this issue. No resolution was found and this workaround added.This was retested extensively in Jan -17 and the problem was not
            --reproduced. Therefore this has been remarked out.

            --Unremarked on 3/29 : Re-occurred on Production:
            --Note POI is correct but the neeed by date is altered during import
            xxd_update_needby_date (v_batch_id, p_po_status, p_errbuf,
                                    p_retcode);
            xxd_approve_po (v_batch_id, p_po_status, p_errbuf,
                            p_retcode);
        END IF;

        --Check error return
        fnd_file.put_line (fnd_file.LOG,
                           'Update Need by Date return ' || p_retcode);
        COMMIT;
        fnd_file.put_line (fnd_file.LOG, 'Update Drop Ship');
        --UPDATE_DROP_SHIP is required for drop_ship POs as APPS.PO_PDOI_PVT.start_process does not populate this data after PO creation
        --The program PO_INTERFACE_S.create_documents (used for AUTOCREATE) was not used as it assumes that a p_batch_id will resolve
        --to a single PO interface header and therefore will create only one PO
        --      IF P_PO_TYPE = gPOTypeTrade
        --      THEN
        --         UPDATE_DROP_SHIP (v_batch_id);
        --      END IF;

        --End of processing . Return any errors raised
        fnd_file.put_line (fnd_file.LOG, 'End Process');
        p_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
            p_retcode   := 2;
    END;

    --Modification starts for Defect#3280
    ---procedure to update need by date of PO line
    PROCEDURE xxd_start_autocreate_po (p_errbuf OUT NOCOPY VARCHAR2, p_retcode OUT NOCOPY NUMBER, p_po_type IN VARCHAR2, --REQ
                                                                                                                         p_buyer_id IN VARCHAR2, --REQ
                                                                                                                                                 p_ou IN NUMBER, --REQ
                                                                                                                                                                 p_po_status IN VARCHAR2
                                       ,                                 --REQ
                                         p_req_id IN NUMBER DEFAULT NULL) --OPT
    IS
        v_user_id   NUMBER := fnd_global.user_id;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '** Autocreate process begin');
        xxd_start_autocreate_po_pvt (p_errbuf, p_retcode, p_po_type,
                                     p_buyer_id, p_ou, p_po_status,
                                     v_user_id, p_req_id);
        fnd_file.put_line (fnd_file.LOG, '** Autocreate process end');
    END;

    --Copy of entry function with DUMMY parameter to accomidate the hidden parameter in the Concurrent request form
    PROCEDURE xxd_start_autocreate_po (
        p_errbuf         OUT NOCOPY VARCHAR2,
        p_retcode        OUT NOCOPY NUMBER,
        p_po_type     IN            VARCHAR2,                            --REQ
        p_dummy       IN            VARCHAR2 := NULL,                    --OPT
        p_buyer_id    IN            VARCHAR2,                            --REQ
        p_ou          IN            NUMBER,                              --REQ
        p_po_status   IN            VARCHAR2,                            --REQ
        p_req_id      IN            NUMBER DEFAULT NULL)                 --OPT
    IS
    BEGIN
        xxd_start_autocreate_po (p_errbuf, p_retcode, p_po_type,
                                 p_buyer_id, p_ou, p_po_status,
                                 p_req_id);
    END;
--Functions for unit testing
END xxd_autocreate_nontrade_po_pkg;
/
