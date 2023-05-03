--
-- XXDOAUTORELCRDHOLD  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAUTORELCRDHOLD"
IS
    V_DEF_MAIL_RECIPS   DO_MAIL_UTILS.TBL_RECIPS;
    NO_RECIPS           EXCEPTION;

    FUNCTION EMAIL_RECIPS (V_PROFILE_OPTION_NAME VARCHAR2)
        RETURN DO_MAIL_UTILS.TBL_RECIPS
    IS
        V_DEF_MAIL_RECIPS   DO_MAIL_UTILS.TBL_RECIPS;
    BEGIN
        V_DEF_MAIL_RECIPS.DELETE;

        BEGIN
            IF V_PROFILE_OPTION_NAME IS NOT NULL
            THEN
                FOR I IN 1 ..
                           LENGTH (V_PROFILE_OPTION_NAME)
                         - LENGTH (REPLACE (V_PROFILE_OPTION_NAME, ';', ''))
                         + 1
                LOOP
                    V_DEF_MAIL_RECIPS (I)   :=
                        SUBSTR (';' || V_PROFILE_OPTION_NAME || ';',
                                  INSTR (';' || V_PROFILE_OPTION_NAME || ';', ';', 1
                                         , I)
                                + 1,
                                  INSTR (';' || V_PROFILE_OPTION_NAME || ';', ';', 1
                                         , I + 1)
                                - INSTR (';' || V_PROFILE_OPTION_NAME || ';', ';', 1
                                         , I)
                                - 1);

                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                           'Email Addresses  in function '
                        || V_DEF_MAIL_RECIPS (I));
                END LOOP;
            END IF;

            RETURN V_DEF_MAIL_RECIPS;
        END EMAIL_RECIPS;
    END;


    PROCEDURE HOLD_RELEASE (ERRBUF        OUT VARCHAR2,
                            RETCODE       OUT VARCHAR2-- Start code change on 25-Jul-2016
                                                      ,
                            p_org_id   IN     NUMBER-- End code change on 25-Jul-2016
                                                    )
    AS
        LN_COUNT1             NUMBER;
        -- Commented on 25-Jul-2016
        --      LN_COUNT2             NUMBER;
        LN_COUNT3             NUMBER;
        -- End of comment on 25-Jul-2016
        -- Commented on 25-Jul-2016
        --      LN_COUNT4             NUMBER;
        -- End of comment on 25-Jul-2016
        LN_COUNT5             NUMBER;
        LN_COUNT              NUMBER;
        L_RELEASE_HOLD_FLAG   VARCHAR2 (5);
        LN_ORDER_TBL          APPS.OE_HOLDS_PVT.ORDER_TBL_TYPE;
        LV_RETURN_STATUS      VARCHAR2 (30);
        LV_MSG_DATA           VARCHAR2 (4000);
        LN_MSG_COUNT          NUMBER;
        V_OUT_LINE            VARCHAR2 (1000);
        L_COUNTER             NUMBER := 0;
        L_RET_VAL             NUMBER := 0;

        CURSOR C_MAIN_DATA IS
              SELECT OOHA.HEADER_ID, OHD1.HOLD_ID, MAX (OOHA1.LAST_UPDATE_DATE) RELEASED_DATE,
                     OOH.ORDER_NUMBER
                FROM OE_ORDER_HOLDS_ALL OOHA, OE_HOLD_SOURCES_ALL OHSA, OE_HOLD_DEFINITIONS OHD,
                     OE_ORDER_HEADERS_ALL OOH, OE_TRANSACTION_TYPES_TL OT, OE_ORDER_HOLDS_ALL OOHA1,
                     OE_HOLD_SOURCES_ALL OHSA1, OE_HOLD_DEFINITIONS OHD1, OE_ORDER_HEADERS_ALL OOH1,
                     OE_HOLD_RELEASES OHR1, FND_USER FU1, OE_TRANSACTION_TYPES_TL OT1
               WHERE     OHSA.HOLD_SOURCE_ID = OOHA.HOLD_SOURCE_ID
                     AND OHSA.HOLD_ID = OHD.HOLD_ID
                     AND OOHA.HEADER_ID = OOH.HEADER_ID
                     AND OOH.ORDER_TYPE_ID = OT.TRANSACTION_TYPE_ID
                     AND OHD.NAME IN FND_PROFILE.VALUE ('XXDO_CREDIT_HOLD')
                     AND OOHA.RELEASED_FLAG = 'N'
                     AND OHSA1.HOLD_SOURCE_ID = OOHA1.HOLD_SOURCE_ID
                     AND OHSA1.HOLD_ID = OHD1.HOLD_ID
                     AND OOHA1.HEADER_ID = OOH1.HEADER_ID
                     AND OOHA1.HOLD_RELEASE_ID = OHR1.HOLD_RELEASE_ID
                     AND OHR1.CREATED_BY = FU1.USER_ID
                     AND OOH1.ORDER_TYPE_ID = OT1.TRANSACTION_TYPE_ID
                     AND FU1.USER_NAME <> 'AUTOINSTALL'
                     AND OHR1.RELEASE_REASON_CODE <> 'PASS_CREDIT'
                     AND OHD1.NAME IN FND_PROFILE.VALUE ('XXDO_CREDIT_HOLD')
                     AND OOHA1.RELEASED_FLAG = 'Y'
                     AND OOHA1.HEADER_ID = OOHA.HEADER_ID
                     -- Code change on 25-Jul-2016
                     AND OOH.ORG_ID = p_org_id
                     -- End of code change
                     AND OT1.NAME NOT IN
                             (SELECT FLV.MEANING
                                FROM FND_LOOKUP_VALUES FLV
                               WHERE     FLV.LOOKUP_TYPE =
                                         'XXDO_ORDER_TYPE_CREDIT_HOLD'
                                     AND FLV.LANGUAGE = 'US'
                                     AND FLV.ENABLED_FLAG = 'Y')
                     AND OOH1.FLOW_STATUS_CODE = 'BOOKED'
            GROUP BY OOHA.HEADER_ID, OHD1.HOLD_ID, OOH.ORDER_NUMBER;

        ---------------------------------------------------------------------------------
        -- CURSOR TO RETRIVE THE LINE INFORMATION
        ---------------------------------------------------------------------------------
        CURSOR C_ORDER_LINES (P_HEADER_ID IN NUMBER)
        IS
            SELECT LINE_ID, ORDERED_QUANTITY, SCHEDULE_SHIP_DATE,
                   UNIT_SELLING_PRICE, REQUEST_DATE, UNIT_SELLING_PRICE * ORDERED_QUANTITY
              FROM OE_ORDER_LINES_ALL
             WHERE HEADER_ID = P_HEADER_ID;

        ---------------------------------------------------------------------------------
        -- CURSOR TO RETRIVE THE LINE HISTORY INFORMATION
        ---------------------------------------------------------------------------------
        CURSOR C_LINES_HISTORY (P_LINE_ID IN NUMBER)
        IS
            SELECT LINE_ID, ORDERED_QUANTITY, SCHEDULE_SHIP_DATE,
                   UNIT_SELLING_PRICE, REQUEST_DATE, UNIT_SELLING_PRICE * ORDERED_QUANTITY
              FROM OE_ORDER_LINES_HISTORY
             WHERE LINE_ID = P_LINE_ID;

        ---------------------------------------------------------------------------------
        -- CURSOR TO RETRIVE THE ORDER AND HOLD INFORAMTION REQUIRED FOR REPORT OUTPUT
        ---------------------------------------------------------------------------------

        CURSOR C_REPORT_DATA (P_HEADER_ID IN NUMBER, P_HOLD_ID IN NUMBER)
        IS
            SELECT OOH.ORDER_NUMBER, HP.PARTY_NAME CUSTOMER_NAME, HP.PARTY_NUMBER CUSTOMER_NUMBER,
                   HOU.NAME OPERATING_UNIT, OHD.NAME HOLD_NAME, FU.USER_NAME HOLD_RELEASED_BY,
                   OOHA.CREATION_DATE HOLD_APPLIED_DATE, OOHA.LAST_UPDATE_DATE HOLD_RELEASED_DATE, OOL.UNIT_SELLING_PRICE * ORDERED_QUANTITY ORDERED_AMOUNT,
                   OOL.LINE_NUMBER || '.' || OOL.SHIPMENT_NUMBER AS LINE_NUMBER, MSIB.SEGMENT1 ITEM_CODE, OOL.REQUEST_DATE REQUESTED_DATE,
                   OOL.SCHEDULE_SHIP_DATE
              FROM OE_ORDER_HEADERS_ALL OOH, HZ_CUST_SITE_USES_ALL HSA, HZ_CUST_ACCT_SITES_ALL HAA,
                   HZ_CUST_ACCOUNTS HCA, HZ_PARTIES HP, HR_OPERATING_UNITS HOU,
                   OE_ORDER_HOLDS_ALL OOHA, OE_HOLD_SOURCES_ALL OHSA, OE_HOLD_DEFINITIONS OHD,
                   OE_HOLD_RELEASES OHR, OE_ORDER_LINES_ALL OOL, MTL_SYSTEM_ITEMS_B MSIB,
                   FND_USER FU
             WHERE     OOHA.RELEASED_FLAG = 'Y'
                   AND OOH.SHIP_TO_ORG_ID = HSA.SITE_USE_ID
                   AND HSA.CUST_ACCT_SITE_ID = HAA.CUST_ACCT_SITE_ID
                   AND HAA.CUST_ACCOUNT_ID = HCA.CUST_ACCOUNT_ID
                   AND HCA.PARTY_ID = HP.PARTY_ID
                   AND OOH.ORG_ID = HOU.ORGANIZATION_ID
                   AND OOH.HEADER_ID = OOHA.HEADER_ID
                   AND OOHA.HOLD_SOURCE_ID = OHSA.HOLD_SOURCE_ID
                   AND OHSA.HOLD_ID = OHD.HOLD_ID
                   AND OOHA.HOLD_RELEASE_ID = OHR.HOLD_RELEASE_ID
                   AND OHR.CREATED_BY = FU.USER_ID
                   AND OOH.HEADER_ID = OOL.HEADER_ID
                   AND OOL.INVENTORY_ITEM_ID = MSIB.INVENTORY_ITEM_ID
                   AND OOL.SHIP_FROM_ORG_ID = MSIB.ORGANIZATION_ID
                   AND OOHA.LAST_UPDATE_DATE =
                       (SELECT MAX (LAST_UPDATE_DATE)
                          FROM OE_ORDER_HOLDS_ALL OOHS
                         WHERE OOHS.HEADER_ID = OOHA.HEADER_ID)
                   AND OOH.HEADER_ID = P_HEADER_ID
                   AND OHD.HOLD_ID = P_HOLD_ID;

        ---------------------------------------------------------------------------------
        -- TYPE DECLARATIONS TO STORE THE FETCHED RECORDS
        ---------------------------------------------------------------------------------

        TYPE T_MAIN_DATA_REC IS TABLE OF C_MAIN_DATA%ROWTYPE
            INDEX BY PLS_INTEGER;

        L_MAIN_DATA_REC       T_MAIN_DATA_REC;

        TYPE T_ORDER_LINES IS TABLE OF C_ORDER_LINES%ROWTYPE
            INDEX BY PLS_INTEGER;

        L_ORDER_LINES         T_ORDER_LINES;

        TYPE T_LINES_HISTORY IS TABLE OF C_LINES_HISTORY%ROWTYPE
            INDEX BY PLS_INTEGER;

        L_LINES_HISTORY       T_LINES_HISTORY;

        TYPE T_REPORT_DATA IS TABLE OF C_REPORT_DATA%ROWTYPE
            INDEX BY PLS_INTEGER;

        L_REPORT_DATA         T_REPORT_DATA;
    ---------------------------------------------------------------------------------
    --BEGIN
    ---------------------------------------------------------------------------------
    BEGIN
        OPEN C_MAIN_DATA;

        FETCH C_MAIN_DATA BULK COLLECT INTO L_MAIN_DATA_REC;

        CLOSE C_MAIN_DATA;

        IF L_MAIN_DATA_REC.COUNT > 0
        THEN
            FND_GLOBAL.APPS_INITIALIZE (APPS.FND_GLOBAL.USER_ID,
                                        APPS.FND_GLOBAL.RESP_ID,
                                        APPS.FND_GLOBAL.RESP_APPL_ID);

            DO_DEBUG_UTILS.SET_LEVEL (1);

            V_DEF_MAIL_RECIPS   :=
                EMAIL_RECIPS (FND_PROFILE.VALUE ('XXDO_EMAIL_ADDRESS'));

            IF V_DEF_MAIL_RECIPS.COUNT < 1
            THEN
                RAISE NO_RECIPS;
            END IF;

            DO_MAIL_UTILS.SEND_MAIL_HEADER ('do-not-reply@deckers.com', V_DEF_MAIL_RECIPS, 'Deckers - Auto release credit hold' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                            , L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE ('--boundarystring', L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE ('Content-Type: text/plain',
                                          L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE ('', L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE (
                'See attachment for report details.',
                L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE ('--boundarystring', L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE ('Content-Type: text/xls',
                                          L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE (
                'Content-Disposition: attachment; filename="Deckers - Sales Order Non-Credit Change Process.xls"',
                L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE ('', L_RET_VAL);
            DO_MAIL_UTILS.SEND_MAIL_LINE (
                   'ORDER_NUMBER'
                || CHR (9)
                || 'CUSTOMER_NAME'
                || CHR (9)
                || 'CUSTOMER_NUMBER'
                || CHR (9)
                || 'OPERATING_UNIT'
                || CHR (9)
                || 'HOLD_NAME'
                || CHR (9)
                || 'HOLD_RELEASED_BY'
                || CHR (9)
                || 'HOLD_APPLIED_DATE'
                || CHR (9)
                || 'HOLD_RELEASED_DATE'
                || CHR (9)
                || 'ORDERED_AMOUNT'
                || CHR (9)
                || 'LINE_NUMBER'
                || CHR (9)
                || 'ITEM_CODE'
                || CHR (9)
                || 'REQUESTED_DATE'
                || CHR (9)
                || 'SCHEDULE_SHIP_DATE'
                || CHR (9),
                L_RET_VAL);
            FND_FILE.PUT_LINE (
                FND_FILE.OUTPUT,
                   'ORDER_NUMBER'
                || CHR (9)
                || 'CUSTOMER_NAME'
                || CHR (9)
                || 'CUSTOMER_NUMBER'
                || CHR (9)
                || 'OPERATING_UNIT'
                || CHR (9)
                || 'HOLD_NAME'
                || CHR (9)
                || 'HOLD_RELEASED_BY'
                || CHR (9)
                || 'HOLD_APPLIED_DATE'
                || CHR (9)
                || 'HOLD_RELEASED_DATE'
                || CHR (9)
                || 'ORDERED_AMOUNT'
                || CHR (9)
                || 'LINE_NUMBER'
                || CHR (9)
                || 'ITEM_CODE'
                || CHR (9)
                || 'REQUESTED_DATE'
                || CHR (9)
                || 'SCHEDULE_SHIP_DATE'
                || CHR (9));


            FOR L_MAIN_DATA IN 1 .. L_MAIN_DATA_REC.COUNT
            LOOP
                L_RELEASE_HOLD_FLAG   := 'Y';
                APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                        'Loop inside the L_MAIN_DATA ');
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                       'Header ID is '
                    || L_MAIN_DATA_REC (L_MAIN_DATA).HEADER_ID);


                OPEN C_ORDER_LINES (L_MAIN_DATA_REC (L_MAIN_DATA).HEADER_ID);

                FETCH C_ORDER_LINES BULK COLLECT INTO L_ORDER_LINES;

                CLOSE C_ORDER_LINES;



                IF L_ORDER_LINES.COUNT > 0
                THEN
                    FOR L_ORDER IN 1 .. L_ORDER_LINES.COUNT
                    LOOP
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'Loop inside the L_ORDER_LINES ');
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'Line  ID is ' || L_ORDER_LINES (L_ORDER).LINE_ID);


                        OPEN C_LINES_HISTORY (
                            L_ORDER_LINES (L_ORDER).LINE_ID);

                        FETCH C_LINES_HISTORY
                            BULK COLLECT INTO L_LINES_HISTORY;

                        CLOSE C_LINES_HISTORY;

                        IF L_LINES_HISTORY.COUNT > 0
                        THEN
                            FOR L_LINE IN 1 .. L_LINES_HISTORY.COUNT
                            LOOP
                                APPS.FND_FILE.PUT_LINE (
                                    APPS.FND_FILE.LOG,
                                    'Loop inside the L_LINE_HISTORY ');
                                APPS.FND_FILE.PUT_LINE (
                                    APPS.FND_FILE.LOG,
                                       'Line  ID in History '
                                    || L_ORDER_LINES (L_ORDER).LINE_ID);


                                SELECT COUNT (*)
                                  INTO LN_COUNT1
                                  FROM OE_ORDER_LINES_HISTORY OOLH
                                 WHERE     OOLH.LINE_ID =
                                           L_ORDER_LINES (L_ORDER).LINE_ID
                                       AND L_ORDER_LINES (L_ORDER).ORDERED_QUANTITY >
                                           OOLH.ORDERED_QUANTITY
                                       AND OOLH.HIST_CREATION_DATE >
                                           L_MAIN_DATA_REC (L_MAIN_DATA).RELEASED_DATE;

                                IF LN_COUNT1 > 0
                                THEN
                                    L_RELEASE_HOLD_FLAG   := 'N';
                                END IF;

                                APPS.FND_FILE.PUT_LINE (
                                    APPS.FND_FILE.LOG,
                                    'Tmp logging LN_COUNT1 ' || LN_COUNT1);

                                /* Commented on 25-Jul-2016
                                                        SELECT COUNT (*)
                                                          INTO LN_COUNT2
                                                          FROM OE_ORDER_LINES_HISTORY OOLH
                                                         WHERE     OOLH.LINE_ID =
                                                                      L_ORDER_LINES (L_ORDER).LINE_ID
                                                               AND L_ORDER_LINES (L_ORDER).SCHEDULE_SHIP_DATE >
                                                                      OOLH.SCHEDULE_SHIP_DATE
                                                               AND OOLH.HIST_CREATION_DATE >
                                                                      L_MAIN_DATA_REC (L_MAIN_DATA).RELEASED_DATE;

                                                        IF LN_COUNT2 > 0
                                                        THEN
                                                           L_RELEASE_HOLD_FLAG := 'N';
                                                           APPS.FND_FILE.PUT_LINE (
                                                              APPS.FND_FILE.LOG,
                                                                 'FLAG is sCHEDULE SHIP  '
                                                              || L_RELEASE_HOLD_FLAG);
                                                        END IF;
                                */

                                SELECT COUNT (*)
                                  INTO LN_COUNT3
                                  FROM OE_ORDER_LINES_HISTORY OOLH
                                 WHERE     OOLH.LINE_ID =
                                           L_ORDER_LINES (L_ORDER).LINE_ID
                                       AND L_ORDER_LINES (L_ORDER).UNIT_SELLING_PRICE >
                                           OOLH.UNIT_SELLING_PRICE
                                       AND OOLH.HIST_CREATION_DATE >
                                           L_MAIN_DATA_REC (L_MAIN_DATA).RELEASED_DATE;

                                IF LN_COUNT3 > 0
                                THEN
                                    L_RELEASE_HOLD_FLAG   := 'N';
                                END IF;

                                APPS.FND_FILE.PUT_LINE (
                                    APPS.FND_FILE.LOG,
                                    'Tmp logging LN_COUNT3 ' || LN_COUNT3);

                                /* Commented on 25-Jul-2016
                                                        SELECT COUNT (*)
                                                          INTO LN_COUNT4
                                                          FROM OE_ORDER_LINES_HISTORY OOLH
                                                         WHERE     OOLH.LINE_ID =
                                                                      L_ORDER_LINES (L_ORDER).LINE_ID
                                                               AND L_ORDER_LINES (L_ORDER).REQUEST_DATE >
                                                                      OOLH.REQUEST_DATE
                                                               AND OOLH.HIST_CREATION_DATE >
                                                                      L_MAIN_DATA_REC (L_MAIN_DATA).RELEASED_DATE;

                                                        IF LN_COUNT4 > 0
                                                        THEN
                                                           L_RELEASE_HOLD_FLAG := 'N';
                                                        END IF;
                                */

                                SELECT COUNT (*)
                                  INTO LN_COUNT5
                                  FROM OE_ORDER_LINES_HISTORY OOLH
                                 WHERE     OOLH.LINE_ID =
                                           L_ORDER_LINES (L_ORDER).LINE_ID
                                       AND   L_ORDER_LINES (L_ORDER).UNIT_SELLING_PRICE
                                           * L_ORDER_LINES (L_ORDER).ORDERED_QUANTITY >
                                             OOLH.UNIT_SELLING_PRICE
                                           * OOLH.ORDERED_QUANTITY
                                       AND OOLH.HIST_CREATION_DATE >
                                           L_MAIN_DATA_REC (L_MAIN_DATA).RELEASED_DATE;

                                IF LN_COUNT5 > 0
                                THEN
                                    L_RELEASE_HOLD_FLAG   := 'N';

                                    APPS.FND_FILE.PUT_LINE (
                                        APPS.FND_FILE.LOG,
                                           'Release hold flag FOR ORDER_TOTAL '
                                        || L_RELEASE_HOLD_FLAG);
                                END IF;

                                APPS.FND_FILE.PUT_LINE (
                                    APPS.FND_FILE.LOG,
                                    'Tmp logging LN_COUNT5 ' || LN_COUNT5);
                            END LOOP;
                        END IF;
                    END LOOP;
                END IF;



                SELECT COUNT (*)
                  INTO LN_COUNT
                  FROM OE_ORDER_LINES_ALL OOL
                 WHERE     OOL.CREATION_DATE >
                           L_MAIN_DATA_REC (L_MAIN_DATA).RELEASED_DATE
                       AND L_MAIN_DATA_REC (L_MAIN_DATA).HEADER_ID =
                           OOL.HEADER_ID;

                IF LN_COUNT > 0
                THEN
                    L_RELEASE_HOLD_FLAG   := 'N';
                END IF;

                IF L_RELEASE_HOLD_FLAG = 'Y'
                THEN
                    APPS.MO_GLOBAL.SET_POLICY_CONTEXT (
                        'S',
                        FND_PROFILE.VALUE ('ORG_ID'));

                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                           'Release hold flag inside Releasing hold API '
                        || L_RELEASE_HOLD_FLAG);

                    FND_MSG_PUB.Initialize ();

                    LN_ORDER_TBL (1).HEADER_ID   :=
                        L_MAIN_DATA_REC (L_MAIN_DATA).HEADER_ID;
                    LV_RETURN_STATUS   := NULL;
                    LV_MSG_DATA        := NULL;
                    LN_MSG_COUNT       := NULL;

                    APPS.OE_HOLDS_PUB.RELEASE_HOLDS (
                        P_API_VERSION           => 1.0,
                        P_ORDER_TBL             => LN_ORDER_TBL,
                        P_HOLD_ID               =>
                            L_MAIN_DATA_REC (L_MAIN_DATA).HOLD_ID,
                        --ln_hold_id,
                        P_RELEASE_REASON_CODE   => 'AUTO_NON_CREDIT_CHANGES',
                        X_RETURN_STATUS         => LV_RETURN_STATUS,
                        X_MSG_COUNT             => LN_MSG_COUNT,
                        X_MSG_DATA              => LV_MSG_DATA);
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'Message Count' || LN_MSG_COUNT);
                END IF;

                IF LV_RETURN_STATUS = APPS.FND_API.G_RET_STS_SUCCESS
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                           'Hold released for Sales Order Num: '
                        || L_MAIN_DATA_REC (L_MAIN_DATA).ORDER_NUMBER);


                    DBMS_OUTPUT.PUT_LINE (
                           'Hold released for Sales Order'
                        || L_MAIN_DATA_REC (L_MAIN_DATA).ORDER_NUMBER);
                    COMMIT;
                ELSIF LV_RETURN_STATUS IS NULL
                THEN
                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'Status is null');
                    DBMS_OUTPUT.PUT_LINE ('Status is null');
                ELSE
                    FOR I IN 1 .. LN_MSG_COUNT
                    LOOP
                        LV_MSG_DATA   :=
                            SUBSTR (
                                FND_MSG_PUB.GET (P_MSG_INDEX   => I,
                                                 P_ENCODED     => 'F'),
                                1,
                                3000);
                        FND_FILE.PUT_LINE (FND_FILE.LOG,
                                           'LV_MSG_DATA:' || LV_MSG_DATA);
                    END LOOP;

                    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                            'Failed: ' || LV_MSG_DATA);
                    DBMS_OUTPUT.PUT_LINE ('Failed: ' || LV_MSG_DATA);
                END IF;

                IF L_RELEASE_HOLD_FLAG = 'Y'
                THEN
                    OPEN C_REPORT_DATA (
                        L_MAIN_DATA_REC (L_MAIN_DATA).HEADER_ID,
                        L_MAIN_DATA_REC (L_MAIN_DATA).HOLD_ID);

                    FETCH C_REPORT_DATA BULK COLLECT INTO L_REPORT_DATA;

                    CLOSE C_REPORT_DATA;

                    DBMS_OUTPUT.PUT_LINE (
                        L_MAIN_DATA_REC (L_MAIN_DATA).HEADER_ID);
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                           'Release hold flag inside report L_REPORT_DATA  '
                        || L_RELEASE_HOLD_FLAG);

                    IF L_REPORT_DATA.COUNT > 0
                    THEN
                        FOR R_REPORT_DATA IN 1 .. L_REPORT_DATA.COUNT
                        LOOP
                            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                                    'INSIDE R_REPORT_DATA:');
                            V_OUT_LINE   := NULL;
                            V_OUT_LINE   :=
                                   L_REPORT_DATA (R_REPORT_DATA).ORDER_NUMBER
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).CUSTOMER_NAME
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).CUSTOMER_NUMBER
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).OPERATING_UNIT
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).HOLD_NAME
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).HOLD_RELEASED_BY
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).HOLD_APPLIED_DATE
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).HOLD_RELEASED_DATE
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).ORDERED_AMOUNT
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).LINE_NUMBER
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).ITEM_CODE
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).REQUESTED_DATE
                                || CHR (9)
                                || L_REPORT_DATA (R_REPORT_DATA).SCHEDULE_SHIP_DATE
                                || CHR (9);
                            DO_MAIL_UTILS.SEND_MAIL_LINE (V_OUT_LINE,
                                                          L_RET_VAL);
                            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, V_OUT_LINE);
                            L_COUNTER    := L_COUNTER + 1;
                        END LOOP;
                    END IF;
                END IF;
            END LOOP;

            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                   'Release hold flag after the main loop '
                || L_RELEASE_HOLD_FLAG);

            IF L_RELEASE_HOLD_FLAG = 'Y'
            THEN
                DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);
            END IF;
        END IF;
    EXCEPTION
        WHEN NO_RECIPS
        THEN
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                'There were no recipients configured in profile option');
            RETCODE   := 2;
    END HOLD_RELEASE;
END XXDOAUTORELCRDHOLD;
/
