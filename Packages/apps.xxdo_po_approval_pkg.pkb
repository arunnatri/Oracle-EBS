--
-- XXDO_PO_APPROVAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdo_po_approval_pkg
IS
    /**********************************************************************************************************
     File Name    : xxdo_po_approval_pkg
     Created On   : 27-March-2012
     Created By   : Sivakumar Boothathan
     Purpose      : This Package is to take a PO as an input and run the PO approval process by calling the API
                    The buyer on the PO is used to approved the PO and initialize the PO
                    The Output of this program will give the output on the list of PO's which has been asked for
                    approval
    ***********************************************************************************************************
    Modification History:
    Version   SCN#   By                         Date             Comments
    1.0              Sivakumar Boothathan    27-March-2012           NA
   v1.1         BT Technology Team         29-DEC-2014         Retrofit for BT project
    *********************************************************************/
    PROCEDURE xxdo_po_approval_prc (errbuf                    OUT VARCHAR2,
                                    retcode                   OUT VARCHAR2,
                                    p_po_number            IN     VARCHAR2,
                                    p_po_line_number       IN     NUMBER,
                                    p_po_shipment_number   IN     NUMBER)
    IS
        ----------------------
        -- Declaring Variables
        ----------------------
        v_user_id          NUMBER := 0;
        v_resp_id          NUMBER := 0;
        v_appl_id          NUMBER := 0;
        lv_result          NUMBER := 0;
        v_revision_num     NUMBER := 0;
        v_po_number        VARCHAR2 (20) := p_po_number;
        v_org_id           NUMBER := 0;
        X_API_ERRORS       apps.PO_API_ERRORS_REC_TYPE;
        v_new_quantity     NUMBER := 0;
        v_line_num         NUMBER := p_po_line_number;
        v_shipment_num     NUMBER := p_po_shipment_number;
        v_quantity         NUMBER := 0;
        v_need_by_date     DATE := NULL;
        v_style            VARCHAR2 (100);
        v_color            VARCHAR2 (100);
        v_season           VARCHAR2 (100);
        v_month            VARCHAR2 (100);
        v_po               VARCHAR2 (100);
        v_price            NUMBER;
        v_size             NUMBER;
        v_drop_ship_flag   VARCHAR2 (1) := 'N';

        ------------------------------------
        -- Cursor to get all the PO's for
        -- which the update has happened
        -- The select statement will pickup
        -- the argument5 which is the PO#
        -- for which the price update has happened
        -- followed by which the PO will be passed
        -- on to approve.
        ------------------------------------
        CURSOR cur_po_arguments IS
            SELECT DISTINCT argument1 style, argument2 color, argument3 season,
                            argument4 month, argument5 PO, argument6 price,
                            argument7 Size1
              FROM apps.fnd_concurrent_requests fcr, apps.fnd_concurrent_programs fcpt
             WHERE     fcr.concurrent_program_id = fcpt.concurrent_program_id
                   AND fcpt.concurrent_program_name = 'XXDOPO001'
                   AND fcr.phase_code = 'C'
                   AND fcr.status_code = 'C'
                   AND fcr.actual_completion_date >=
                       NVL (
                           (SELECT MAX (actual_completion_date)
                              FROM apps.fnd_concurrent_requests fcr, apps.fnd_concurrent_programs fcpt
                             WHERE     fcr.concurrent_program_id =
                                       fcpt.concurrent_program_id
                                   AND fcpt.concurrent_program_name =
                                       'XXDOPO003'
                                   AND fcr.phase_code = 'C'
                                   AND fcr.status_code = 'C'),
                           TRUNC (SYSDATE));

        CURSOR cur_po_extract (LV_STYLE IN VARCHAR2, LV_COLOR IN VARCHAR2, LV_BUY_SEASON IN VARCHAR2
                               , LV_BUY_MONTH IN VARCHAR2, LV_PO_NUMBER IN VARCHAR2, PV_SIZE IN NUMBER)
        IS
            SELECT DISTINCT poh.segment1 po_number, poh.org_id org_id
              FROM apps.po_line_locations_all poll, apps.po_headers_all poh, apps.po_lines_all pol
             WHERE     poll.po_line_id(+) = pol.po_line_id
                   AND poll.po_header_id(+) = pol.po_header_id
                   AND pol.po_header_id = poh.po_header_id
                   AND pol.org_id = poh.org_id
                   AND TRIM (poh.segment1) =
                       NVL (TRIM (LV_PO_NUMBER), TRIM (poh.segment1))
                   AND NVL (TRIM (poh.attribute8), 'XXDO') =
                       NVL (
                           NVL (TRIM (LV_BUY_SEASON), TRIM (poh.attribute8)),
                           'XXDO')
                   AND NVL (TRIM (poh.attribute9), 'XXDO') =
                       NVL (NVL (TRIM (LV_BUY_MONTH), TRIM (poh.attribute9)),
                            'XXDO')
                   AND pol.item_id IN
                           (/*-------------------------------------------------------------------------------------
                            Start Changes by BT Technology Team on 29-DEC-2014 - V 1.1
                            ---------------------------------------------------------------------------------------
                                      SELECT inventory_item_id
                                       FROM apps.xxd_common_items_v
                                      WHERE
                                TRIM(segment1) LIKE  TRIM(:LV_STYLE)-- AND
                                           -- TRIM(segment2) = NVL(TRIM(:LV_COLOR), TRIM(segment2)) -- Added by Srinivas Dumala on 1st feb 2012
                                            --AND TRIM(segment3) = NVL(TRIM(:PV_SIZE), TRIM(segment3)) -- Added by Srinivas Dumala
                            */
                            SELECT DISTINCT inventory_item_id
                              FROM apps.xxd_common_items_v
                             WHERE     TRIM (STYLE_NUMBER) =
                                       NVL (TRIM (LV_STYLE),
                                            TRIM (STYLE_NUMBER))
                                   AND COLOR_CODE =
                                       NVL (TRIM (LV_COLOR), COLOR_CODE)
                                   AND ITEM_SIZE =
                                       NVL (TRIM (PV_SIZE), TRIM (ITEM_SIZE))
                                   AND organization_id IN
                                           (SELECT master_organization_id FROM apps.oe_system_parameters))
                   AND /*-------------------------------------------------------------------------------------------------
                       End changes by BT Technology Team on 29-DEC-2014  - V 1.1
                       ---------------------------------------------------------------------------------------------------*/
                       NVL (poh.closed_code, 'OPEN') NOT IN
                           ('CLOSED', 'CANCELLED', 'FINALLY CLOSED')
                   AND NVL (pol.closed_code, 'OPEN') NOT IN
                           ('CLOSED', 'CANCELLED', 'FINALLY CLOSED')
                   AND pol.closed_date IS NULL
                   AND NVL (poh.authorization_status, 'APPROVED') NOT IN
                           ('FROZEN', 'CANCELED', 'FINALLY CLOSED',
                            'INCOMPLETE', 'IN PROCESS', 'PRE-APPROVED')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.RCV_TRANSACTIONS RCT
                             WHERE     RCT.PO_LINE_LOCATION_ID =
                                       POLL.LINE_LOCATION_ID
                                   AND RCT.PO_HEADER_ID = POLL.PO_HEADER_ID
                                   AND RCT.PO_LINE_ID = POLL.PO_LINE_ID)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.RCV_SHIPMENT_LINES RSL, apps.RCV_SHIPMENT_HEADERS RSH
                             WHERE     RSL.SHIPMENT_HEADER_ID =
                                       RSH.SHIPMENT_HEADER_ID
                                   AND RSL.ASN_LINE_FLAG = 'Y'
                                   AND RSL.PO_LINE_LOCATION_ID =
                                       POLL.LINE_LOCATION_ID
                                   AND RSL.PO_LINE_ID = POLL.PO_LINE_ID
                                   AND RSL.PO_HEADER_ID = POLL.PO_HEADER_ID);
    --------------------------
    -- Begin of the procedure
    --------------------------
    BEGIN
        FOR c_cur_po_arguments IN cur_po_arguments
        LOOP
            v_style    := c_cur_po_arguments.style;
            v_color    := c_cur_po_arguments.color;
            v_season   := c_cur_po_arguments.season;
            v_month    := c_cur_po_arguments.month;
            v_po       := c_cur_po_arguments.po;
            v_price    := c_cur_po_arguments.price;
            v_size     := c_cur_po_arguments.size1;

            ------------------------------------------------
            -- Cursor to get the values : cur_po_extract
            ------------------------------------------------
            FOR c_cur_po_extract IN cur_po_extract (v_style, v_color, v_season
                                                    , v_month, v_po, v_size)
            LOOP
                -------------------------------------
                -- Assigning the values
                -------------------------------------
                v_po_number   := c_cur_po_extract.po_number;
                v_org_id      := c_cur_po_extract.org_id;

                --------------------------
                -- Getting The User ID
                --------------------------
                BEGIN
                    ----------------------------------------------------
                    -- Getting the user ID to initialize for the API
                    ----------------------------------------------------
                    SELECT user_id
                      INTO v_user_id
                      FROM apps.fnd_user fus, apps.po_headers_all poh, apps.po_agents poa
                     WHERE     poh.agent_id = poa.agent_id
                           AND fus.employee_id = poa.agent_id
                           AND poh.segment1 = v_po_number;
                ----------------------
                -- Exception Handler
                ----------------------
                EXCEPTION
                    ------------------------
                    -- When No Data Found
                    ------------------------
                    WHEN NO_DATA_FOUND
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'No Data Found Error While Getting The User ID');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Code');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Message');
                    -------------------------
                    -- When Others Error
                    -------------------------
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Others Error While Getting The User ID');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Code');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Message');
                -------------------------------------------
                -- End Of The Query To Get The User ID
                -------------------------------------------
                END;

                -------------------------------------------------------------
                -- Query to get the responsibility to initialize the API
                -------------------------------------------------------------
                BEGIN
                    -------------------------------------
                    -- Query to get the responsibility
                    -------------------------------------
                    SELECT responsibility_id
                      INTO v_resp_id
                      FROM apps.fnd_responsibility_tl
                     WHERE     language = 'US'
                           AND responsibility_name = 'Purchasing Super User';
                ----------------------
                -- Exception Handler
                ----------------------
                EXCEPTION
                    ------------------------
                    -- When No Data Found
                    ------------------------
                    WHEN NO_DATA_FOUND
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'No Data Found Error While Getting The Responsibility ID');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Code');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Message');
                    -------------------------
                    -- When Others Error
                    -------------------------
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Others Error While Getting The Responsibility  ID');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Code');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Message');
                -------------------------------------------
                -- End Of The Query To Get The User ID
                -------------------------------------------
                END;

                ------------------------------------
                -- Query to get the Application ID
                ------------------------------------
                BEGIN
                    -------------------------------------
                    -- Query to get the Application ID
                    -------------------------------------
                    SELECT application_id
                      INTO v_appl_id
                      FROM apps.fnd_application_tl
                     WHERE     language = 'US'
                           AND application_name = 'Purchasing';
                ----------------------
                -- Exception Handler
                ----------------------
                EXCEPTION
                    ------------------------
                    -- When No Data Found
                    ------------------------
                    WHEN NO_DATA_FOUND
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'No Data Found Error While Getting The Application ID');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Code');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Message');
                    -------------------------
                    -- When Others Error
                    -------------------------
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Others Error While Getting The Application ID');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Code');
                        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                'SQL Error Message');
                -------------------------------------------
                -- End Of The Query To Get The Application ID
                -------------------------------------------
                END;

                --------------------------------------
                -- SQL Query to get the first line
                --------------------------------------
                BEGIN
                    SELECT DISTINCT pha.revision_num, pha.org_id, pla.quantity,
                                    plla.need_by_date, pla.line_num, NVL (plla.drop_ship_flag, 'N'),
                                    plla.shipment_num
                      INTO v_revision_num, v_org_id, v_quantity, v_need_by_date,
                                         v_line_num, v_drop_ship_flag, v_shipment_num
                      FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
                     WHERE     pha.po_header_id = pla.po_header_id
                           AND pla.po_line_id = plla.po_line_id
                           AND pha.po_header_id = plla.po_header_id
                           AND pha.org_id = pla.org_id
                           AND pla.org_id = plla.org_id
                           AND pha.segment1 = v_po_number
                           AND (pla.line_num) =
                               (SELECT MIN (line_num)
                                  FROM apps.po_line_locations_all pll1, apps.po_lines_all pl1
                                 WHERE     pl1.po_line_id = pll1.po_line_id
                                       AND pl1.po_header_id =
                                           pla.po_header_id
                                       AND NVL (pl1.cancel_flag, 'N') <> 'Y'
                                       AND NVL (pll1.cancel_flag, 'N') <> 'Y'
                                       AND EXISTS
                                               (  SELECT pl.line_num
                                                    FROM apps.po_lines_all pl, apps.po_line_locations_all pll
                                                   WHERE     pl.po_line_id =
                                                             pll.po_line_id
                                                         AND pl.po_line_id =
                                                             pl1.po_line_id
                                                GROUP BY pl.line_num
                                                  HAVING COUNT (
                                                             pll.line_location_id) =
                                                         1))
                           AND NVL (pha.cancel_flag, 'N') <> 'Y'
                           AND NOT EXISTS
                                   (  SELECT pll.po_line_id
                                        FROM apps.po_lines_all pl, apps.po_line_locations_all pll
                                       WHERE     pl.po_line_id = pll.po_line_id
                                             AND pl.po_line_id = pla.po_line_id
                                    GROUP BY pll.po_line_id
                                      HAVING COUNT (pll.line_location_id) > 1);
                ---------------------------
                -- Exception Handler
                ---------------------------
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'No Data Found While Getting The Revision Num');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'SQL Error Code :' || SQLCODE);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'SQL Error Message :' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Others Data Found While Getting The Revision Num');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'SQL Error Code :' || SQLCODE);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'SQL Error Message :' || SQLERRM);
                END;

                ------------------------------------
                -- Initialize before calling the API
                ------------------------------------
                apps.fnd_global.apps_initialize (v_user_id,
                                                 v_resp_id,
                                                 v_appl_id);
                apps.MO_GLOBAL.SET_POLICY_CONTEXT ('S', v_org_id);
                apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                        'Before calling API');

                IF (v_drop_ship_flag = 'N')
                THEN
                    ------------------
                    -- Calling the API
                    ------------------
                    lv_result   :=
                        APPS.PO_CHANGE_API1_S.UPDATE_PO (
                            X_PO_NUMBER             => v_po_number,
                            X_RELEASE_NUMBER        => NULL,
                            X_REVISION_NUMBER       => v_revision_num,
                            X_LINE_NUMBER           => v_line_num,
                            X_SHIPMENT_NUMBER       => NULL,
                            NEW_QUANTITY            => v_quantity,
                            NEW_PRICE               => NULL,
                            NEW_PROMISED_DATE       => NULL,
                            NEW_NEED_BY_DATE        => NULL,
                            LAUNCH_APPROVALS_FLAG   => 'Y',
                            UPDATE_SOURCE           => NULL,
                            VERSION                 => '1.0',
                            X_OVERRIDE_DATE         => NULL,
                            X_API_ERRORS            => x_api_errors,
                            p_BUYER_NAME            => NULL,
                            p_secondary_quantity    => NULL,
                            p_preferred_grade       => NULL,
                            p_org_id                => V_ORG_ID);
                ELSIF (v_drop_ship_flag = 'Y')
                THEN
                    lv_result   :=
                        APPS.PO_CHANGE_API1_S.UPDATE_PO (
                            X_PO_NUMBER             => v_po_number,
                            X_RELEASE_NUMBER        => NULL,
                            X_REVISION_NUMBER       => v_revision_num,
                            X_LINE_NUMBER           => v_line_num,
                            X_SHIPMENT_NUMBER       => v_shipment_num,
                            NEW_QUANTITY            => NULL,
                            NEW_PRICE               => NULL,
                            NEW_PROMISED_DATE       => NULL,
                            NEW_NEED_BY_DATE        => v_need_by_date,
                            LAUNCH_APPROVALS_FLAG   => 'Y',
                            UPDATE_SOURCE           => NULL,
                            VERSION                 => '1.0',
                            X_OVERRIDE_DATE         => NULL,
                            X_API_ERRORS            => x_api_errors,
                            p_BUYER_NAME            => NULL,
                            p_secondary_quantity    => NULL,
                            p_preferred_grade       => NULL,
                            p_org_id                => V_ORG_ID);
                END IF;

                ------------------------------------
                -- If there is an Issue with API
                ------------------------------------
                IF (lv_result <> 1)
                THEN
                    -------------------------------------------
                    -- Begin loop to vary value of the cursor
                    -- to get the error message
                    -------------------------------------------
                    FOR i IN x_api_errors.MESSAGE_TEXT.FIRST ..
                             x_api_errors.MESSAGE_TEXT.LAST
                    LOOP
                        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                                'INSIDE API ERRORS');
                        apps.fnd_file.PUT_LINE (
                            apps.fnd_file.LOG,
                            x_api_errors.MESSAGE_TEXT (i));
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               'Error While Updating The Price for PO Number :'
                            || V_PO_NUMBER
                            || ' and Line Number : 1');
                        apps.fnd_file.put_line (apps.fnd_file.output,
                                                'Error Is :');
                        apps.fnd_file.PUT_LINE (
                            apps.fnd_file.output,
                            x_api_errors.MESSAGE_TEXT (i));
                        apps.fnd_file.PUT_LINE (
                            apps.fnd_file.LOG,
                            x_api_errors.MESSAGE_TEXT (i));
                    END LOOP;
                ELSE
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                        'The PO # - ' || v_po_number || '  has been approved');
                END IF;

                COMMIT;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Others Error In The Procedure xxdo_po_approval_prc');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
    END xxdo_po_approval_prc;
END xxdo_po_approval_pkg;
/
