--
-- XXDO_AR_REPORTS  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AR_REPORTS"
IS
    --03/25/2008 - KWG - V. 1.0.1.1 -- NEW INTL INVOICES COLUMNS (WO #25212) --

    --MODIFIED THE PACKAGE BY VIJAYA REDDY @ SUNERATECH(OFFSHORE) ON 10-MAR-2011 WO # 75555 AND 77177

    -- ADDED P_FROM_DATE AND P_TO_DATE BY VIJAYA REDDY @ SUNERATECH(OFFSHORE) WO # 68966 --
    --MODIFIED CURSOR C3, C4 FOR DEFECT BY MADHAV DHURJATY 5-SEP-14
    -- BT TECH TEAM                     RETROFIT                          01-DEC-2014

    FUNCTION GET_FACTORY_INVOICE (P_CUST_TRX_ID   IN VARCHAR2,
                                  P_STYLE         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        RETVAL     VARCHAR2 (2000);
        L_PO_NUM   VARCHAR2 (100);

        CURSOR C1 (PN_CUSTTRXID VARCHAR2)
        IS
            SELECT DISTINCT
                   DECODE (SHIP_INTL.INVOICE_NUM, NULL, DECODE (SHIP_DC1.INVOICE_NUM, NULL, RSH.PACKING_SLIP, SHIP_DC1.INVOICE_NUM), SHIP_INTL.INVOICE_NUM) AS FACTORY_INVOICE
              FROM APPS.OE_DROP_SHIP_SOURCES DSS, APPS.RCV_SHIPMENT_LINES RSL, APPS.RCV_SHIPMENT_HEADERS RSH,
                   APPS.RA_CUSTOMER_TRX_LINES_ALL RTLA, APPS.OE_ORDER_LINES_ALL OOLA, APPS.MTL_SYSTEM_ITEMS_B MTL,
                   CUSTOM.DO_SHIPMENTS SHIP_DC1, CUSTOM.DO_SHIPMENTS SHIP_INTL, APPS.RCV_TRANSACTIONS RCV
             WHERE     RSL.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
                   AND RSL.PO_LINE_LOCATION_ID =
                       NVL (TO_NUMBER (OOLA.ATTRIBUTE16),
                            DSS.LINE_LOCATION_ID)
                   AND DSS.LINE_ID(+) =
                       TO_NUMBER (RTLA.INTERFACE_LINE_ATTRIBUTE6)
                   AND OOLA.LINE_ID =
                       TO_NUMBER (RTLA.INTERFACE_LINE_ATTRIBUTE6)
                   AND OOLA.INVENTORY_ITEM_ID = MTL.INVENTORY_ITEM_ID
                   AND RTLA.CUSTOMER_TRX_ID = TO_CHAR (PN_CUSTTRXID)
                   -- 10089300
                   AND RCV.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
                   AND SUBSTR (TRIM (RCV.ATTRIBUTE1),
                               1,
                               INSTR (TRIM (RCV.ATTRIBUTE1), '-', 1) - 1) =
                       SHIP_INTL.SHIPMENT_ID(+)
                   AND SUBSTR (TRIM (RSH.SHIPMENT_NUM),
                               1,
                               INSTR (TRIM (RSH.SHIPMENT_NUM), '-', 1) - 1) =
                       SHIP_DC1.SHIPMENT_ID(+);

        CURSOR C2 (PN_CUST_TRX_ID IN VARCHAR2, PV_STYLE IN VARCHAR2)
        IS
            SELECT DISTINCT
                   DECODE (SHIP_INTL.INVOICE_NUM, NULL, DECODE (SHIP_DC1.INVOICE_NUM, NULL, RSH.PACKING_SLIP, SHIP_DC1.INVOICE_NUM), SHIP_INTL.INVOICE_NUM) AS FACTORY_INVOICE
              FROM APPS.OE_DROP_SHIP_SOURCES DSS, APPS.RCV_SHIPMENT_LINES RSL, APPS.RCV_SHIPMENT_HEADERS RSH,
                   APPS.RA_CUSTOMER_TRX_LINES_ALL RTLA, APPS.OE_ORDER_LINES_ALL OOLA, APPS.MTL_SYSTEM_ITEMS_B MTL,
                   CUSTOM.DO_SHIPMENTS SHIP_DC1, CUSTOM.DO_SHIPMENTS SHIP_INTL, APPS.RCV_TRANSACTIONS RCV
             WHERE     RSL.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
                   AND RSL.PO_LINE_LOCATION_ID =
                       NVL (TO_NUMBER (OOLA.ATTRIBUTE16),
                            DSS.LINE_LOCATION_ID)
                   AND DSS.LINE_ID(+) =
                       TO_NUMBER (RTLA.INTERFACE_LINE_ATTRIBUTE6)
                   AND OOLA.LINE_ID =
                       TO_NUMBER (RTLA.INTERFACE_LINE_ATTRIBUTE6)
                   AND OOLA.INVENTORY_ITEM_ID = MTL.INVENTORY_ITEM_ID
                   AND RTLA.CUSTOMER_TRX_ID = TO_CHAR (PN_CUST_TRX_ID)
                   AND MTL.SEGMENT1 = PV_STYLE
                   AND RCV.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
                   AND SUBSTR (TRIM (RCV.ATTRIBUTE1),
                               1,
                               INSTR (TRIM (RCV.ATTRIBUTE1), '-', 1) - 1) =
                       SHIP_INTL.SHIPMENT_ID(+)
                   AND SUBSTR (TRIM (RSH.SHIPMENT_NUM),
                               1,
                               INSTR (TRIM (RSH.SHIPMENT_NUM), '-', 1) - 1) =
                       SHIP_DC1.SHIPMENT_ID(+);

        --ADDED BY MADHAV FOR DEFECT START
        CURSOR C3 (PN_CUST_TRX_ID IN NUMBER)
        IS
              SELECT RSH.PACKING_SLIP FACTORY_INVOICE, SUM (RSL.QUANTITY_RECEIVED) RCVD_QTY
                FROM APPS.RA_CUSTOMER_TRX_ALL CTA, APPS.RA_CUSTOMER_TRX_LINES_ALL CTLA, APPS.RCV_TRANSACTIONS TRX,
                     APPS.MTL_MATERIAL_TRANSACTIONS MT, APPS.RCV_SHIPMENT_HEADERS RSH, APPS.RCV_SHIPMENT_LINES RSL,
                     APPS.MTL_SYSTEM_ITEMS_B MTL, APPS.PO_HEADERS_ALL PHA, APPS.HR_ALL_ORGANIZATION_UNITS HR_DEST
               WHERE     1 = 1
                     AND CTA.CUSTOMER_TRX_ID = CTLA.CUSTOMER_TRX_ID
                     AND TRX.TRANSACTION_ID = MT.RCV_TRANSACTION_ID
                     AND TRX.SHIPMENT_LINE_ID = RSL.SHIPMENT_LINE_ID
                     AND TRX.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
                     AND MT.TRANSACTION_ID =
                         TO_NUMBER (CTLA.INTERFACE_LINE_ATTRIBUTE7)
                     AND TRX.PO_LINE_LOCATION_ID =
                         TO_NUMBER (CTLA.INTERFACE_LINE_ATTRIBUTE6)
                     --CTLA.LINE_LOCATION
                     AND RSL.ITEM_ID = MTL.INVENTORY_ITEM_ID
                     AND RSL.PO_HEADER_ID = PHA.PO_HEADER_ID
                     AND TRX.ORGANIZATION_ID = HR_DEST.ORGANIZATION_ID
                     AND TRX.TRANSACTION_TYPE = 'RECEIVE'
                     AND MT.TRANSACTION_TYPE_ID = 11
                     AND CTLA.INTERFACE_LINE_CONTEXT = 'GLOBAL_PROCUREMENT'
                     AND CTLA.LINE_TYPE = 'LINE'
                     AND CTA.CUSTOMER_TRX_ID = PN_CUST_TRX_ID       --28765965
            --AND MTL.SEGMENT1 = '5815'
            GROUP BY RSH.PACKING_SLIP;

        CURSOR C4 (PN_CUST_TRX_ID IN NUMBER, PV_STYLE IN VARCHAR2)
        IS
              SELECT RSH.PACKING_SLIP FACTORY_INVOICE, TRX.TRANSACTION_DATE PO_RECEIPT_DATE, SUM (RSL.QUANTITY_RECEIVED) RCVD_QTY
                FROM APPS.RA_CUSTOMER_TRX_ALL CTA, APPS.RA_CUSTOMER_TRX_LINES_ALL CTLA, APPS.RCV_TRANSACTIONS TRX,
                     APPS.MTL_MATERIAL_TRANSACTIONS MT, APPS.RCV_SHIPMENT_HEADERS RSH, APPS.RCV_SHIPMENT_LINES RSL,
                     APPS.MTL_SYSTEM_ITEMS_B MTL, APPS.PO_HEADERS_ALL PHA, APPS.HR_ALL_ORGANIZATION_UNITS HR_DEST
               WHERE     1 = 1
                     AND CTA.CUSTOMER_TRX_ID = CTLA.CUSTOMER_TRX_ID
                     AND TRX.TRANSACTION_ID = MT.RCV_TRANSACTION_ID
                     AND TRX.SHIPMENT_LINE_ID = RSL.SHIPMENT_LINE_ID
                     AND TRX.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
                     AND MT.TRANSACTION_ID =
                         TO_NUMBER (CTLA.INTERFACE_LINE_ATTRIBUTE7)
                     AND TRX.PO_LINE_LOCATION_ID =
                         TO_NUMBER (CTLA.INTERFACE_LINE_ATTRIBUTE6)
                     --CTLA.LINE_LOCATION
                     AND RSL.ITEM_ID = MTL.INVENTORY_ITEM_ID
                     AND RSL.PO_HEADER_ID = PHA.PO_HEADER_ID
                     AND TRX.ORGANIZATION_ID = HR_DEST.ORGANIZATION_ID
                     AND TRX.TRANSACTION_TYPE = 'RECEIVE'
                     AND MT.TRANSACTION_TYPE_ID = 11
                     AND CTLA.INTERFACE_LINE_CONTEXT = 'GLOBAL_PROCUREMENT'
                     AND CTLA.LINE_TYPE = 'LINE'
                     AND CTA.CUSTOMER_TRX_ID = PN_CUST_TRX_ID       --28765965
                     AND MTL.SEGMENT1 = PV_STYLE                      --'5815'
            GROUP BY RSH.PACKING_SLIP, TRX.TRANSACTION_DATE;

        --ADDED BY MADHAV FOR DEFECT END

        --COMMENTED BY MADHAV FOR DEFECT START
        /*CURSOR C3 (PN_CUST_TRX_ID IN VARCHAR2)
        IS
           SELECT   POH.SEGMENT1 PO_NUM, RSH.PACKING_SLIP AS FACTORY_INVOICE,
                    SUM (RSL.QUANTITY_RECEIVED) RCVD_QTY
               FROM APPS.RCV_SHIPMENT_LINES RSL,
                    APPS.RCV_SHIPMENT_HEADERS RSH,
                    APPS.RCV_TRANSACTIONS RCV,
                    APPS.MTL_SYSTEM_ITEMS_B MSI,
                    APPS.PO_HEADERS_ALL POH,
                    APPS.RA_CUSTOMER_TRX_ALL RCTA
              WHERE RSH.SHIPMENT_HEADER_ID = RSL.SHIPMENT_HEADER_ID
                AND RSL.SHIPMENT_LINE_ID = RCV.SHIPMENT_LINE_ID
                AND RCV.TRANSACTION_TYPE = 'RECEIVE'
                AND RSL.ITEM_ID = MSI.INVENTORY_ITEM_ID
                AND MSI.ORGANIZATION_ID = 7
                AND RSL.PO_HEADER_ID = POH.PO_HEADER_ID
                AND RCTA.PURCHASE_ORDER = POH.SEGMENT1
                AND RCTA.CUSTOMER_TRX_ID = TO_CHAR (PN_CUST_TRX_ID)
           GROUP BY RCV.TRANSACTION_DATE,
                    POH.SEGMENT1,
                    MSI.SEGMENT1,
                    RSH.PACKING_SLIP;

        CURSOR C4 (PN_CUST_TRX_ID IN VARCHAR2, PV_STYLE IN VARCHAR2)
        IS
           SELECT   POH.SEGMENT1 PO_NUM, RCV.TRANSACTION_DATE PO_RECEIPT_DATE,
                    RSH.PACKING_SLIP AS FACTORY_INVOICE,
                    SUM (RSL.QUANTITY_RECEIVED) RCVD_QTY
               FROM APPS.RCV_SHIPMENT_LINES RSL,
                    APPS.RCV_SHIPMENT_HEADERS RSH,
                    APPS.RCV_TRANSACTIONS RCV,
                    APPS.MTL_SYSTEM_ITEMS_B MSI,
                    APPS.PO_HEADERS_ALL POH,
                    APPS.RA_CUSTOMER_TRX_ALL RCTA
              WHERE RSH.SHIPMENT_HEADER_ID = RSL.SHIPMENT_HEADER_ID
                AND RSL.SHIPMENT_LINE_ID = RCV.SHIPMENT_LINE_ID
                AND RCV.TRANSACTION_TYPE = 'RECEIVE'
                AND RSL.ITEM_ID = MSI.INVENTORY_ITEM_ID
                AND MSI.ORGANIZATION_ID = 7
                AND RSL.PO_HEADER_ID = POH.PO_HEADER_ID
                AND RCTA.PURCHASE_ORDER = POH.SEGMENT1
                AND RCTA.CUSTOMER_TRX_ID = TO_CHAR (PN_CUST_TRX_ID)
                AND MSI.SEGMENT1 = PV_STYLE
           GROUP BY RCV.TRANSACTION_DATE,
                    POH.SEGMENT1,
                    MSI.SEGMENT1,
                    RSH.PACKING_SLIP;*/
        --COMMENTED BY MADHAV FOR DEFECT END
        CURSOR C5 (PN_CUST_TRX_ID   IN VARCHAR2,
                   PV_STYLE         IN VARCHAR2,
                   PO_RCV_DATE         VARCHAR2)
        IS
            SELECT COUNT (DISTINCT RSH.PACKING_SLIP) STYLE_CNT
              FROM APPS.RCV_SHIPMENT_LINES RSL, APPS.RCV_SHIPMENT_HEADERS RSH, APPS.RCV_TRANSACTIONS RCV,
                   APPS.MTL_SYSTEM_ITEMS_B MSI, APPS.PO_HEADERS_ALL POH, APPS.RA_CUSTOMER_TRX_ALL RCTA
             WHERE     RSH.SHIPMENT_HEADER_ID = RSL.SHIPMENT_HEADER_ID
                   AND RSL.SHIPMENT_LINE_ID = RCV.SHIPMENT_LINE_ID
                   AND RCV.TRANSACTION_TYPE = 'RECEIVE'
                   AND RSL.ITEM_ID = MSI.INVENTORY_ITEM_ID
                   AND MSI.ORGANIZATION_ID = 7
                   AND RSL.PO_HEADER_ID = POH.PO_HEADER_ID
                   AND RCTA.PURCHASE_ORDER = POH.SEGMENT1
                   AND RCTA.CUSTOMER_TRX_ID = TO_CHAR (PN_CUST_TRX_ID)
                   AND MSI.SEGMENT1 = PV_STYLE                     --'1003321'
                   AND TRUNC (RCV.TRANSACTION_DATE) =
                       TRUNC (TO_DATE (PO_RCV_DATE, 'DD-MON-YY'));
    BEGIN
        BEGIN
            SELECT PHA.SEGMENT1
              INTO L_PO_NUM
              FROM APPS.RA_CUSTOMER_TRX_ALL RCTA, APPS.PO_HEADERS_ALL PHA
             WHERE     1 = 1
                   AND PHA.SEGMENT1 = RCTA.PURCHASE_ORDER
                   AND RCTA.ORG_ID = PHA.ORG_ID
                   AND RCTA.CUSTOMER_TRX_ID = TO_CHAR (P_CUST_TRX_ID);
        EXCEPTION
            WHEN OTHERS
            THEN
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'Exception in PO is : ' || SUBSTR (SQLERRM, 1, 200));
        END;

        IF L_PO_NUM IS NULL
        THEN
            IF P_STYLE IS NULL
            THEN
                RETVAL   := NULL;

                FOR I IN C1 (TO_CHAR (P_CUST_TRX_ID))
                LOOP
                    IF RETVAL IS NULL
                    THEN
                        RETVAL   := I.FACTORY_INVOICE;
                    ELSE
                        RETVAL   := I.FACTORY_INVOICE || ',' || RETVAL;
                    END IF;
                END LOOP;
            ELSE
                RETVAL   := NULL;

                FOR J IN C2 (TO_CHAR (P_CUST_TRX_ID), P_STYLE)
                LOOP
                    IF RETVAL IS NULL
                    THEN
                        RETVAL   := J.FACTORY_INVOICE;
                    ELSE
                        RETVAL   := J.FACTORY_INVOICE || ',' || RETVAL;
                    END IF;
                END LOOP;
            END IF;
        ELSE
            IF P_STYLE IS NULL
            THEN
                RETVAL   := NULL;

                FOR L IN C3 (TO_CHAR (P_CUST_TRX_ID))
                LOOP
                    IF RETVAL IS NULL
                    THEN
                        RETVAL   := L.FACTORY_INVOICE;
                    ELSE
                        RETVAL   :=
                               L.FACTORY_INVOICE
                            || '('
                            || L.RCVD_QTY
                            || ')'
                            || ','
                            || RETVAL;
                    END IF;
                END LOOP;
            ELSE
                RETVAL   := NULL;

                FOR N IN C4 (TO_CHAR (P_CUST_TRX_ID), P_STYLE)
                LOOP
                    -- APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG,'DATE: '||N.PO_RECEIPT_DATE);
                    FOR Q
                        IN C5 (TO_CHAR (P_CUST_TRX_ID),
                               P_STYLE,
                               N.PO_RECEIPT_DATE)
                    LOOP
                        IF Q.STYLE_CNT <= 1
                        THEN
                            IF RETVAL IS NULL
                            THEN
                                RETVAL   := N.FACTORY_INVOICE;
                            -- APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG,'RECEIVED QUANTITY IF VALUE1111111 : '||N.RCVD_QTY||':::#######'||RETVAL);
                            END IF;
                        ELSE
                            --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG,'COUNT QUANTITY ELSE: '||Q.STYLE_CNT);
                            IF RETVAL IS NULL
                            THEN
                                RETVAL   :=
                                       N.FACTORY_INVOICE
                                    || '('
                                    || N.RCVD_QTY
                                    || ')';
                            ELSE
                                RETVAL   :=
                                       N.FACTORY_INVOICE
                                    || '('
                                    || N.RCVD_QTY
                                    || ')'
                                    || ','
                                    || RETVAL;
                            END IF;
                        END IF;
                    END LOOP;
                END LOOP;
            END IF;
        END IF;

        RETURN RETVAL;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                'In When No Data found exception ' || SQLCODE || SQLERRM);
            RETURN NULL;
        WHEN OTHERS
        THEN
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                   'In When others exception of Get Factory Invoice then p_Cust_Trx_ID : '
                || P_CUST_TRX_ID);
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                   'In When others exception of Get Factory Invoice then p_Style :'
                || P_STYLE);
            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                   'In When others exception of Get Factory Invoice then '
                || SQLCODE
                || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION GET_EMAIL_RECIPS (V_LOOKUP_TYPE VARCHAR2)
        RETURN APPS.DO_MAIL_UTILS.TBL_RECIPS
    IS
        V_DEF_MAIL_RECIPS   APPS.DO_MAIL_UTILS.TBL_RECIPS;

        CURSOR C_RECIPS IS
            SELECT LOOKUP_CODE, MEANING, DESCRIPTION
              FROM APPS.FND_LOOKUP_VALUES
             WHERE     LOOKUP_TYPE = V_LOOKUP_TYPE
                   AND ENABLED_FLAG = 'Y'
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (START_DATE_ACTIVE, SYSDATE))
                                   AND TRUNC (
                                           NVL (END_DATE_ACTIVE, SYSDATE) + 1);
    BEGIN
        V_DEF_MAIL_RECIPS.DELETE;

        FOR C_RECIP IN C_RECIPS
        LOOP
            V_DEF_MAIL_RECIPS (V_DEF_MAIL_RECIPS.COUNT + 1)   :=
                C_RECIP.MEANING;
        END LOOP;

        RETURN V_DEF_MAIL_RECIPS;
    END;

    PROCEDURE INTL_INVOICES (P_D1 OUT VARCHAR2, P_D2 OUT VARCHAR2, -- P_INCLUDE_STYLE IN VARCHAR2 := 'Y',
                                                                   --P_MONTH IN DATE := NULL, -- COMMENTED BY VIJAYA REDDY@SUNERA WO# 68966
                                                                   P_FROM_DATE IN DATE:= NULL
                             , -- ADDED BY VIJAYA REDDY@SUNERA WO# 68966
                               P_TO_DATE IN DATE:= NULL -- ADDED BY VIJAYA REDDY@SUNERA WO# 68966
                                                       --P_BUCKET_TYPE IN NUMBER := 2,
                                                       --V_SEND_NONE_MSG IN VARCHAR2 := 'N'
                                                       )
    IS
        --L_USE_MONTH DATE := NVL(P_MONTH, ADD_MONTHS(SYSDATE, -1)); -- COMMENTED BY VIJAYA REDDY@SUNERA WO# 68966

        --L_USE_FROM_MONTH DATE := NVL(P_FROM_DATE, ADD_MONTHS(SYSDATE, -1)); -- ADDED BY VIJAYA REDDY@SUNERA WO# 68966

        --L_USE_TO_MONTH DATE := NVL(P_TO_DATE, ADD_MONTHS(SYSDATE, -1)); -- ADDED BY VIJAYA REDDY@SUNERA WO# 68966
        L_INCLUDE_STYLE     VARCHAR2 (10) := 'Y';
        L_RET_VAL           NUMBER := 0;
        L_FROM_DATE         DATE;
        L_TO_DATE           DATE;
        V_SUBJECT           VARCHAR2 (100);
        L_STYLE             VARCHAR2 (240);
        L_STYLE_CODE        VARCHAR2 (240);
        V_DEF_MAIL_RECIPS   APPS.DO_MAIL_UTILS.TBL_RECIPS;
        EX_NO_RECIPS        EXCEPTION;
        EX_NO_SENDER        EXCEPTION;
        EX_NO_DATA_FOUND    EXCEPTION;

        /*TYPE C_INV_REC IS RECORD (
         BRAND VARCHAR (150),
         ORG_NAME VARCHAR (50),
         WAREHOUSE_NAME VARCHAR (50),
         INVOICE_NUMBER VARCHAR (20),
         INVOICE_DATE DATE,
         SALES_ORDER VARCHAR (50),
         FACTORY_INV VARCHAR (75),
         SELL_TO_CUSTOMER_NAME VARCHAR (50),
         COUNTRY VARCHAR (60),
         INVOICE_CURRENCY_CODE VARCHAR (15),
         INVOICE_TOTAL NUMBER,
         PRE_CONV_INV_TOTAL NUMBER,
         INVOICED_QTY NUMBER,
         LANDED_COST_OF_GOODS NUMBER,
         SERIES VARCHAR2(80),
         STYLE VARCHAR2(80),
         CUSTOMER_TRX_ID NUMBER
         );*/
        -- COMMENTED BY SRINATH SIRICILLA @ SUNERA TECH. FOR DEFECT DFCT0010920

        -- ADDED BY SRINATH SIRICILLA @ SUNERA TECH. FOR DEFECT DFCT0010920
        TYPE C_INV_REC
            IS RECORD
        (
            --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            --   BRAND                   APPS.RA_CUSTOMER_TRX_ALL.ATTRIBUTE5%TYPE,
            --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            BRAND                    APPS.HZ_CUST_ACCOUNTS.ATTRIBUTE1%TYPE,
            ORG_NAME                 APPS.HR_ALL_ORGANIZATION_UNITS_TL.NAME%TYPE,
            WAREHOUSE_NAME           APPS.HR_ALL_ORGANIZATION_UNITS_TL.NAME%TYPE,
            INVOICE_NUMBER           APPS.RA_CUSTOMER_TRX_ALL.TRX_NUMBER%TYPE,
            INVOICE_DATE             APPS.RA_CUSTOMER_TRX_ALL.TRX_DATE%TYPE,
            SALES_ORDER              APPS.RA_CUSTOMER_TRX_ALL.INTERFACE_HEADER_ATTRIBUTE1%TYPE,
            FACTORY_INV              APPS.RA_CUSTOMER_TRX_LINES_ALL.DESCRIPTION%TYPE,
            --VARCHAR (75),
            -- COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            --SELL_TO_CUSTOMER_NAME   APPS.RA_CUSTOMERS.CUSTOMER_NAME%TYPE,
            -- ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            SELL_TO_CUSTOMER_NAME    APPS.XXD_RA_CUSTOMERS_V.CUSTOMER_NAME%TYPE,
            COUNTRY                  APPS.RA_ADDRESSES_ALL.COUNTRY%TYPE,
            --VARCHAR (60),
            INVOICE_CURRENCY_CODE    APPS.RA_CUSTOMER_TRX_ALL.INVOICE_CURRENCY_CODE%TYPE,
            --VARCHAR (15),
            INVOICE_TOTAL            NUMBER,
            PRE_CONV_INV_TOTAL       NUMBER,
            INVOICED_QTY             NUMBER,
            LANDED_COST_OF_GOODS     NUMBER,
            SERIES                   APPS.RA_CUSTOMER_TRX_LINES_ALL.DESCRIPTION%TYPE,
            STYLE                    APPS.RA_CUSTOMER_TRX_LINES_ALL.DESCRIPTION%TYPE,
            CUSTOMER_TRX_ID          NUMBER
        );

        --- END OF CHANGES
        TYPE C_INV_TBL IS TABLE OF C_INV_REC
            INDEX BY BINARY_INTEGER;

        C_INVOICE_TBL       C_INV_TBL;

        FUNCTION GET_INVOICE_GL_CODE (P_CUSTOMER_TRX_ID   IN NUMBER,
                                      P_STYLE             IN VARCHAR2)
            RETURN VARCHAR2
        IS
            L_GL_ACCT_ID   NUMBER;
            L_RET          VARCHAR2 (400);
        --ADDED FUNCTION BY VIJAYA REDDY @ SUNERATECH ON 28-MAR-2011 WO # 75555 AND 77177
        BEGIN
            SELECT -- DECODE(MIN(RCTLGDA.CODE_COMBINATION_ID), MAX(RCTLGDA.CODE_COMBINATION_ID), MAX(RCTLGDA.CODE_COMBINATION_ID), NULL) AS GL_ACCT_ID
                   -- COMMENTED BY VIJAYA REDDY ON 10-MAR-2011
                   DECODE (MIN (RCTLGDA.CODE_COMBINATION_ID), MAX (RCTLGDA.CODE_COMBINATION_ID), MAX (RCTLGDA.CODE_COMBINATION_ID), MIN (RCTLGDA.CODE_COMBINATION_ID)) AS GL_ACCT_ID
              -- ADDED BY VIJAYA REDDY @ SUNERATECH ON 10-MAR-2011 WO # 75555 AND 77177
              INTO L_GL_ACCT_ID
              FROM APPS.RA_CUSTOMER_TRX_ALL RCTA, APPS.RA_CUSTOMER_TRX_LINES_ALL RCTLA, APPS.RA_CUST_TRX_LINE_GL_DIST_ALL RCTLGDA,
                   -- APPS.MTL_SYSTEM_ITEMS_B MSIB
                   APPS.XXD_COMMON_ITEMS_V MSIB
             WHERE     RCTLA.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
                   AND RCTLA.LINE_TYPE = 'LINE'
                   AND NVL (RCTLA.INTERFACE_LINE_ATTRIBUTE11, '0') = '0'
                   AND RCTLGDA.CUSTOMER_TRX_ID(+) = RCTLA.CUSTOMER_TRX_ID
                   AND RCTLGDA.CUSTOMER_TRX_LINE_ID(+) =
                       RCTLA.CUSTOMER_TRX_LINE_ID
                   AND MSIB.ORGANIZATION_ID(+) = RCTLA.WAREHOUSE_ID
                   AND MSIB.INVENTORY_ITEM_ID(+) = RCTLA.INVENTORY_ITEM_ID
                   AND RCTA.CUSTOMER_TRX_ID = P_CUSTOMER_TRX_ID
                   AND RCTLGDA.ACCOUNT_CLASS = 'REV'
                   AND MSIB.STYLE_DESC(+) = P_STYLE;

            IF L_GL_ACCT_ID IS NOT NULL
            THEN
                BEGIN
                    SELECT GCC.CONCATENATED_SEGMENTS
                      --GCC.SEGMENT1 || '.' || GCC.SEGMENT2 || '.' || GCC.SEGMENT3 || '.' || GCC.SEGMENT4
                      INTO L_RET
                      FROM APPS.GL_CODE_COMBINATIONS_KFV GCC
                     WHERE GCC.CODE_COMBINATION_ID = L_GL_ACCT_ID;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                               'Exception While retrieving Code combination :'
                            || SUBSTR (SQLERRM, 1, 200));
                END;
            ELSE
                L_RET   := NULL;
            END IF;

            RETURN L_RET;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'NO DATA FOUND');
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                       'NO DATA FOUND for Customer_trx_id :'
                    || P_CUSTOMER_TRX_ID);
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'NO DATA FOUND for Style :' || P_STYLE);
                RETURN NULL;
            WHEN OTHERS
            THEN
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                       'Exception in get_invoice_gl_code Function :'
                    || SUBSTR (SQLERRM, 1, 200));
                RETURN NULL;
        END;

        FUNCTION GET_INVOICES (P_STYLE_GROUPING IN VARCHAR2, P_FROM_DATE IN DATE, P_TO_DATE IN DATE)
            RETURN C_INV_TBL
        IS
            P_RET   C_INV_TBL;

            CURSOR C_INVOICES IS
                  --START ADDED BY BT TECHNOLOGY TEAM ON 4-DEC-2014
                  --SELECT   NVL (RT.ATTRIBUTE5, XCI.STYLE_NUMBER) AS BRAND,

                  SELECT NVL (HC.ATTRIBUTE1, XCI.BRAND)
                             AS BRAND,
                         NVL (XCI.STYLE_DESC, ' ')
                             AS STYLE_DESC, -- END ADDED BY BT TECHNOLOGY TEAM ON 4-DEC-2014
                         ORG_NAME.NAME
                             AS ORGANIZATION_NAME,
                         NVL (MAX (WH_NAME.NAME), ' ')
                             AS WAREHOUSE_NAME,
                         NVL (MAX (ADDR.COUNTRY), ' ')
                             AS COUNTRY,
                         RT.CUSTOMER_TRX_ID,
                         RT.TRX_NUMBER
                             AS INVOICE_NUMBER,
                         RT.TRX_DATE
                             AS INVOICE_DATE,
                         NVL (MAX (RT.INTERFACE_HEADER_ATTRIBUTE1), ' ')
                             AS SALES_ORDER,
                         NVL (
                             DECODE (
                                 P_STYLE_GROUPING,
                                 'Y', XXDO_AR_REPORTS.GET_FACTORY_INVOICE (
                                          RT.CUSTOMER_TRX_ID,
                                          DECODE (
                                              P_STYLE_GROUPING,
                                              'Y', NVL /*COMMENTED BY BT TECHNOLOGY TEAM ON 4-DEC-2014
                                                            (MSIB.SEGMENT1,
                                                            ADDED BY BT TECHNOLOGY TEAM ON 4-DEC-2014*/
                                                       (XCI.STYLE_NUMBER,
                                                        RTL.DESCRIPTION),
                                              NULL)),
                                 XXDO_AR_REPORTS.GET_FACTORY_INVOICE (
                                     RT.CUSTOMER_TRX_ID,
                                     NULL)),
                             ' ')
                             AS FACTORY_INV,
                         --PER WO#39915 AND WO#79011(VENKATESH) --
                         CUSTS.CUSTOMER_NAME
                             AS SELL_TO_CUSTOMER_NAME,
                         RT.INVOICE_CURRENCY_CODE,
                         /* COMMENTED BY BT TECHNOLOGY TEAM ON 4-DEC-2014
                          NVL (DECODE (MIN (MCB.SEGMENT2),
                                       MAX (MCB.SEGMENT2), MAX (MCB.SEGMENT2),
                        ADDED BY BT TECHNOLOGY TEAM ON 4-DEC-2014*/
                         NVL (
                             DECODE (
                                 MIN (XCI.COLOR_CODE),
                                 MAX (XCI.COLOR_CODE), MAX (XCI.COLOR_CODE),
                                 'Multiple'),
                             DECODE (
                                 P_STYLE_GROUPING,
                                 /* COMMENTED BY BT TECHNOLOGY TEAM ON 4-DEC-2014
                                          'Y', NVL (MSIB.SEGMENT1, RTL.DESCRIPTION),
                                     ADDED BY BT TECHNOLOGY TEAM ON 4-DEC-2014*/
                                 'Y', NVL (XCI.STYLE_NUMBER, RTL.DESCRIPTION),
                                 NULL))
                             AS SERIES,
                         --SHOW "FRIEGHT" PER WO#39915--
                         /* DECODE (P_STYLE_GROUPING,
                          COMMENTED BY BT TECHNOLOGY TEAM ON 4-DEC-2014
                                  'Y', NVL (MSIB.SEGMENT1, RTL.DESCRIPTION),
                                  ADDED BY BT TECHNOLOGY TEAM ON 4-DEC-2014
                                  'Y', NVL (XCI.STYLE_NUMBER, RTL.DESCRIPTION),
                                  NULL
                                 ) AS STYLE,*/
                         --SHOW "FRIEGHT" PER WO#39915--
                         SUM (
                             NVL (
                                 ROUND (
                                       RTL.EXTENDED_AMOUNT
                                     * (SELECT CONVERSION_RATE
                                          FROM GL_DAILY_RATES
                                         WHERE     FROM_CURRENCY =
                                                   RT.INVOICE_CURRENCY_CODE
                                               AND TO_CURRENCY = 'USD'
                                               AND CONVERSION_DATE =
                                                   RT.TRX_DATE
                                               AND CONVERSION_TYPE =
                                                   (SELECT CROSS_CURRENCY_RATE_TYPE
                                                      FROM AR_SYSTEM_PARAMETERS_ALL
                                                     WHERE ORG_ID = RT.ORG_ID))),
                                 0))
                             AS INVOICE_TOTAL,
                         SUM (NVL (RTL.EXTENDED_AMOUNT, 0))
                             AS PRE_CONV_INV_TOTAL,
                         SUM (
                             DECODE (
                                 RTL.LINE_TYPE,
                                 'LINE', DECODE (
                                             NVL (
                                                 RTL.INTERFACE_LINE_ATTRIBUTE11,
                                                 0),
                                             0, QUANTITY_INVOICED,
                                             0),
                                 0))
                             AS INVOICED_QTY,
                         SUM (
                               NVL (CIC.ITEM_COST, 0)
                             * DECODE (
                                   RTL.LINE_TYPE,
                                   'LINE', DECODE (
                                               NVL (
                                                   RTL.INTERFACE_LINE_ATTRIBUTE11,
                                                   0),
                                               0, QUANTITY_INVOICED,
                                               0),
                                   0))
                             AS LANDED_COST_OF_GOODS
                    FROM APPS.HR_ALL_ORGANIZATION_UNITS_TL WH_NAME, APPS.HR_ALL_ORGANIZATION_UNITS_TL ORG_NAME, /*COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                                                                                  APPS.RA_SITE_USES_ALL RASU,
                                                                                                                  APPS.HZ_CUST_SITE_USES_ALL RASU,
                                                                                                                  APPS.RA_CUSTOMERS CUSTS
                                                                                                                  APPS.RA_ADDRESSES_ALL ADDR,*/
                                                                                                                APPS.XXD_RA_SITE_USES_MORG_V RASU,
                         APPS.XXD_RA_CUSTOMERS_V CUSTS, APPS.XXD_RA_ADDRESSES_MORG_V ADDR, --  ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                                                           /* COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                                                              APPS.MTL_ITEM_CATEGORIES MIC,
                                                                                              APPS.MTL_CATEGORIES_B MCB,
                                                                                              APPS.MTL_SYSTEM_ITEMS_B MSIB, */
                                                                                           APPS.XXD_COMMON_ITEMS_V XCI,
                         APPS.CST_ITEM_COSTS CIC, --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                  APPS.RA_CUST_TRX_TYPES_ALL RTT, APPS.RA_CUSTOMER_TRX_LINES_ALL RTL,
                         APPS.RA_CUSTOMER_TRX_ALL RT, APPS.HZ_CUST_ACCOUNTS HC
                   WHERE     RT.TRX_DATE BETWEEN P_FROM_DATE AND P_TO_DATE
                         --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                         -- AND RT.ORG_ID NOT IN (2, 3, 472)
                         AND ORG_NAME.NAME NOT IN
                                 ('Deckers US OU', 'Deckers eCommerce OU', 'Deckers US Retail OU')
                         AND ADDR.ADDRESS_ID(+) = RASU.ADDRESS_ID
                         AND CIC.INVENTORY_ITEM_ID(+) = RTL.INVENTORY_ITEM_ID
                         AND CIC.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
                         AND CIC.COST_TYPE_ID(+) = 1
                         AND CUSTS.CUSTOMER_ID = RT.BILL_TO_CUSTOMER_ID
                         AND RTL.CUSTOMER_TRX_ID = RT.CUSTOMER_TRX_ID
                         AND RTT.CUST_TRX_TYPE_ID = RT.CUST_TRX_TYPE_ID
                         AND RTT.ORG_ID = RT.ORG_ID
                         AND RTT.TYPE = 'INV'
                         AND RT.COMPLETE_FLAG = 'Y'
                         AND RTL.LINE_TYPE IN ('LINE', 'FREIGHT', 'CHARGES')
                         --REMOVE TAX LINE TYPE PER WO#39915--
                         AND ORG_NAME.LANGUAGE = USERENV ('LANG')
                         AND ORG_NAME.ORGANIZATION_ID = RT.ORG_ID
                         AND WH_NAME.LANGUAGE(+) = USERENV ('LANG')
                         AND WH_NAME.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
                         AND RASU.SITE_USE_ID(+) = RT.SHIP_TO_SITE_USE_ID
                         -- AND OOD.ORGANIZATION_ID(+)=RT.ORG_ID
                         /*COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                          AND MSIB.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
                          AND MSIB.INVENTORY_ITEM_ID(+) = RTL.INVENTORY_ITEM_ID
                          AND MIC.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
                          AND MIC.INVENTORY_ITEM_ID(+) = RTL.INVENTORY_ITEM_ID
                          AND XCI.CATEGORY_SET_ID(+) = 1*/
                         AND XCI.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
                         AND XCI.INVENTORY_ITEM_ID(+) = RTL.INVENTORY_ITEM_ID
                         --   AND XCI.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
                         AND XCI.INVENTORY_ITEM_ID(+) = RTL.INVENTORY_ITEM_ID
                         --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                         AND RT.BILL_TO_CUSTOMER_ID = HC.CUST_ACCOUNT_ID
                /* AND XCI.CATEGORY_ID(+) = XCI.CATEGORY_ID
                   AND (   NVL (RTL.EXTENDED_AMOUNT, 0) != 0
                        OR DECODE
                                 (RTL.LINE_TYPE,
                                  'LINE', DECODE
                                          (NVL (RTL.INTERFACE_LINE_ATTRIBUTE11,
                                                0
                                               ),
                                           0, QUANTITY_INVOICED,
                                           0
                                          ),
                                  0
                                 ) != 0
                       )*/
                GROUP BY ORG_NAME.NAME, /*COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                NVL (RT.ATTRIBUTE5, MCB.SEGMENT1),
                                                   ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014*/
                                        NVL (HC.ATTRIBUTE1, XCI.STYLE_NUMBER), RT.CUSTOMER_TRX_ID,
                         TRX_NUMBER, TRX_DATE, CUSTS.CUSTOMER_NAME,
                         DECODE (P_STYLE_GROUPING, /*COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                           'Y', NVL (MSIB.SEGMENT1, RTL.DESCRIPTION),
                                                                 --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014 */
                                                   'Y', NVL (XCI.STYLE_NUMBER, RTL.DESCRIPTION), NULL), RT.INVOICE_CURRENCY_CODE, NVL (HC.ATTRIBUTE1, XCI.BRAND),
                         XCI.STYLE_DESC
                /*COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                 ORDER BY NVL (RT.ATTRIBUTE5, MCB.SEGMENT1),
              ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014 */
                ORDER BY NVL (HC.ATTRIBUTE1, XCI.STYLE_NUMBER), ORGANIZATION_NAME, WAREHOUSE_NAME,
                         TRX_DATE, TRX_NUMBER, DECODE (P_STYLE_GROUPING, /*COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                                          'Y', NVL (MSIB.SEGMENT1, RTL.DESCRIPTION), */
                                                                         'Y', NVL (XCI.STYLE_NUMBER, RTL.DESCRIPTION), --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                                                                                       NULL);
        /**** CURRENT PROD VERSION****
        --SELECT NVL(RT.ATTRIBUTE5, MCB.SEGMENT1) AS BRAND,
        SELECT NVL(HC.ATTRIBUTE1, MCB.SEGMENT1) AS BRAND,
         ORG_NAME.NAME AS ORGANIZATION_NAME,
         MAX(WH_NAME.NAME) AS WAREHOUSE_NAME,
         MAX(ADDR.COUNTRY) AS COUNTRY,
         RT.CUSTOMER_TRX_ID,
         RT.TRX_NUMBER AS INVOICE_NUMBER,
         RT.TRX_DATE AS INVOICE_DATE,
         MAX(RT.INTERFACE_HEADER_ATTRIBUTE1) AS SALES_ORDER,
         CUSTS.CUSTOMER_NAME AS SELL_TO_CUSTOMER_NAME,
         RT.INVOICE_CURRENCY_CODE,
         DECODE(MIN(MCB.SEGMENT2), MAX(MCB.SEGMENT2), MAX(MCB.SEGMENT2), 'MULTIPLE') AS SERIES,
         DECODE(P_STYLE_GROUPING, 'Y', MSIB.SEGMENT1, NULL) AS STYLE,
         SUM(NVL(RTL.EXTENDED_AMOUNT,0)*NVL(RT.EXCHANGE_RATE, 1)) AS INVOICE_TOTAL,
         SUM(NVL(RTL.EXTENDED_AMOUNT,0)) AS PRE_CONV_INV_TOTAL,
         SUM(DECODE(RTL.LINE_TYPE, 'LINE', DECODE(NVL(RTL.INTERFACE_LINE_ATTRIBUTE11, 0), 0, QUANTITY_INVOICED ,0), 0)) AS INVOICED_QTY,
         SUM(NVL(CIC.ITEM_COST,0)*DECODE(RTL.LINE_TYPE, 'LINE', DECODE(NVL(RTL.INTERFACE_LINE_ATTRIBUTE11, 0), 0, QUANTITY_INVOICED ,0), 0)) AS LANDED_COST_OF_GOODS
         FROM APPS.HR_ALL_ORGANIZATION_UNITS_TL WH_NAME,
         APPS.HR_ALL_ORGANIZATION_UNITS_TL ORG_NAME,
         APPS.RA_SITE_USES_ALL RASU,
        -- APPS.RA_CUSTOMERS CUSTS,
        APPS.XXD_RA_CUSTOMERS_V CUSTS,
         APPS.MTL_ITEM_CATEGORIES MIC,
         APPS.MTL_CATEGORIES_B MCB,
         APPS.MTL_SYSTEM_ITEMS_B MSIB,
         APPS.CST_ITEM_COSTS CIC,
         APPS.RA_ADDRESSES_ALL ADDR,
         APPS.RA_CUST_TRX_TYPES_ALL RTT,
         APPS.RA_CUSTOMER_TRX_LINES_ALL RTL,
         APPS.RA_CUSTOMER_TRX_ALL RT,
         APPS.HZ_CUST_ACCOUNTS HC
         WHERE RT.TRX_DATE BETWEEN P_FROM_DATE AND P_TO_DATE
         AND RT.ORG_ID<>2
         AND ADDR.ADDRESS_ID(+)=RASU.ADDRESS_ID
         AND CIC.INVENTORY_ITEM_ID(+)=RTL.INVENTORY_ITEM_ID
         AND CIC.ORGANIZATION_ID(+)=RTL.WAREHOUSE_ID
         AND CIC.COST_TYPE_ID(+)=1
         AND CUSTS.CUSTOMER_ID=RT.BILL_TO_CUSTOMER_ID
         AND RTL.CUSTOMER_TRX_ID=RT.CUSTOMER_TRX_ID
         AND RTT.CUST_TRX_TYPE_ID = RT.CUST_TRX_TYPE_ID
         AND RTT.ORG_ID = RT.ORG_ID
         AND RTT.TYPE = 'INV'
         AND RT.SOLD_TO_CUSTOMER_ID = HC.CUST_ACCOUNT_ID
         AND RT.COMPLETE_FLAG = 'Y'
         AND RTL.LINE_TYPE IN ('LINE', 'TAX', 'FREIGHT', 'CHARGES')
         AND ORG_NAME.LANGUAGE = USERENV('LANG')
         AND ORG_NAME.ORGANIZATION_ID = RT.ORG_ID
         AND WH_NAME.LANGUAGE(+) = USERENV('LANG')
         AND WH_NAME.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
         AND RASU.SITE_USE_ID(+)=RT.SHIP_TO_SITE_USE_ID
         AND MSIB.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
         AND MSIB.INVENTORY_ITEM_ID(+) = RTL.INVENTORY_ITEM_ID
         AND MIC.ORGANIZATION_ID(+) = RTL.WAREHOUSE_ID
         AND MIC.INVENTORY_ITEM_ID(+) = RTL.INVENTORY_ITEM_ID
         AND MIC.CATEGORY_SET_ID(+) = 1
         AND MCB.CATEGORY_ID(+) = MIC.CATEGORY_ID
         AND (NVL(RTL.EXTENDED_AMOUNT,0) != 0 OR DECODE(RTL.LINE_TYPE, 'LINE', DECODE(NVL(RTL.INTERFACE_LINE_ATTRIBUTE11, 0), 0, QUANTITY_INVOICED ,0), 0) != 0)
         GROUP BY ORG_NAME.NAME,
        -- NVL(RT.ATTRIBUTE5, MCB.SEGMENT1), -- COMMENTED BY BT TECHNOLOGY TEAM ON 4-DEC-2014
        NVL(HC.ATTRIBUTE1, MCB.SEGMENT1), --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
         RT.CUSTOMER_TRX_ID,
         TRX_NUMBER,
         TRX_DATE,
         CUSTS.CUSTOMER_NAME,
         DECODE(P_STYLE_GROUPING, 'Y', MSIB.SEGMENT1, NULL),
         RT.INVOICE_CURRENCY_CODE
        -- ORDER BY NVL(RT.ATTRIBUTE5, MCB.SEGMENT1),
        ORDER BY NVL(HC.ATTRIBUTE1, MCB.SEGMENT1)
         ORGANIZATION_NAME,
         WAREHOUSE_NAME,
         TRX_DATE,
         TRX_NUMBER,
         DECODE(P_STYLE_GROUPING, 'Y', MSIB.SEGMENT1, NULL);
         */
        BEGIN
            FOR C_INVOICE IN C_INVOICES
            LOOP
                BEGIN
                    P_RET (P_RET.COUNT + 1).BRAND   := C_INVOICE.BRAND;
                    P_RET (P_RET.COUNT).ORG_NAME    :=
                        C_INVOICE.ORGANIZATION_NAME;
                    P_RET (P_RET.COUNT).WAREHOUSE_NAME   :=
                        C_INVOICE.WAREHOUSE_NAME;
                    P_RET (P_RET.COUNT).INVOICE_NUMBER   :=
                        C_INVOICE.INVOICE_NUMBER;
                    P_RET (P_RET.COUNT).INVOICE_DATE   :=
                        C_INVOICE.INVOICE_DATE;
                    P_RET (P_RET.COUNT).SALES_ORDER   :=
                        C_INVOICE.SALES_ORDER;
                    P_RET (P_RET.COUNT).FACTORY_INV   :=
                        C_INVOICE.FACTORY_INV;
                    P_RET (P_RET.COUNT).SELL_TO_CUSTOMER_NAME   :=
                        C_INVOICE.SELL_TO_CUSTOMER_NAME;
                    P_RET (P_RET.COUNT).COUNTRY     :=
                        C_INVOICE.COUNTRY;
                    P_RET (P_RET.COUNT).INVOICE_CURRENCY_CODE   :=
                        C_INVOICE.INVOICE_CURRENCY_CODE;
                    P_RET (P_RET.COUNT).INVOICE_TOTAL   :=
                        C_INVOICE.INVOICE_TOTAL;
                    P_RET (P_RET.COUNT).PRE_CONV_INV_TOTAL   :=
                        C_INVOICE.PRE_CONV_INV_TOTAL;
                    P_RET (P_RET.COUNT).INVOICED_QTY   :=
                        C_INVOICE.INVOICED_QTY;
                    P_RET (P_RET.COUNT).LANDED_COST_OF_GOODS   :=
                        C_INVOICE.LANDED_COST_OF_GOODS;
                    P_RET (P_RET.COUNT).SERIES      :=
                        C_INVOICE.SERIES;
                    P_RET (P_RET.COUNT).STYLE       :=
                        C_INVOICE.STYLE_DESC;
                    P_RET (P_RET.COUNT).CUSTOMER_TRX_ID   :=
                        C_INVOICE.CUSTOMER_TRX_ID;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'Exception is : ' || SUBSTR (SQLERRM, 1, 200));
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'Exception Customer Trx ID is : ' || C_INVOICE.CUSTOMER_TRX_ID);
                END;
            END LOOP;

            RETURN P_RET;
        END;
    BEGIN
        L_FROM_DATE   := P_FROM_DATE;
        L_TO_DATE     := P_TO_DATE;
        C_INVOICE_TBL   :=
            GET_INVOICES (L_INCLUDE_STYLE, L_FROM_DATE, L_TO_DATE);
        APPS.DO_DEBUG_UTILS.SET_LEVEL (1);

        IF APPS.FND_PROFILE.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE EX_NO_SENDER;
        END IF;

        /*
         DO_DEBUG_UTILS.WRITE(L_DEBUG_LOC => DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT,
         V_APPLICATION_ID => 'DO_AR_REPORTS.INTL_INVOICES',
         V_DEBUG_TEXT => 'RECIPIENTS...',
         L_DEBUG_LEVEL => 1
         );

         V_DEF_MAIL_RECIPS := GET_EMAIL_RECIPS('DO_AR_INTL_INVOICES_ALERT');
         FOR I IN 1.. V_DEF_MAIL_RECIPS.COUNT LOOP
         DO_DEBUG_UTILS.WRITE(L_DEBUG_LOC => DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT,
         V_APPLICATION_ID => 'DO_AR_REPORTS.INTL_INVOICES',
         V_DEBUG_TEXT => V_DEF_MAIL_RECIPS(I),
         L_DEBUG_LEVEL => 1
         );
         END LOOP;


         IF APPS.V_DEF_MAIL_RECIPS.COUNT < 1 THEN
         RAISE EX_NO_RECIPS;
         END IF;
        */
        IF C_INVOICE_TBL.COUNT < 1
        THEN
            --NO DATA.
            RAISE EX_NO_DATA_FOUND;
        END IF;

        /* E-MAIL HEADER */
        /*
         DO_MAIL_UTILS.SEND_MAIL_HEADER(FND_PROFILE.VALUE('DO_DEF_ALERT_SENDER'),
         V_DEF_MAIL_RECIPS,
         V_SUBJECT,
         L_RET_VAL
         );
        */
        IF NVL (L_INCLUDE_STYLE, 'N') = 'Y'
        THEN
            L_STYLE   := RPAD ('Style', 40) || CHR (9);
        ELSE
            L_STYLE   := '';
        END IF;

        /*
         DO_MAIL_UTILS.SEND_MAIL_LINE('CONTENT-TYPE: MULTIPART/MIXED; BOUNDARY=BOUNDARYSTRING', L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_LINE('--BOUNDARYSTRING', L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_LINE('CONTENT-TYPE: TEXT/PLAIN', L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_LINE('', L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_LINE('SEE ATTACHMENT FOR A LIST OF INTERNATIONAL INVOICES.', L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_LINE('--BOUNDARYSTRING', L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_LINE('CONTENT-TYPE: TEXT/XLS', L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_LINE('CONTENT-DISPOSITION: ATTACHMENT; FILENAME="INTLINV.XLS"', L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_LINE('', L_RET_VAL);

         DO_MAIL_UTILS.SEND_MAIL_LINE('BRAND' || CHR(9) ||
         'ORGANIZATION' || CHR(9) ||
         'WAREHOUSE' || CHR(9) ||
         'INVOICE #' || CHR(9) ||
         'INVOICE DATE' || CHR(9) ||
         'ORDER #' || CHR(9) ||
         'CUSTOMER' || CHR(9) ||
         'COUNTRY' || CHR(9) ||
         L_STYLE ||
         'INVOICE AMOUNT' || CHR(9) ||
         'CURRENCY' || CHR(9) ||
         'AMOUNT IN USD' || CHR(9) ||
         'QUANTITY' || CHR(9) ||
         'LANDED COST OF GOODS' || CHR(9) ||
         'GL ACCOUNT' || CHR(9) ||
         'PRODUCT GROUP'
         , L_RET_VAL);
        */
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
               RPAD ('Brand', 10)
            || CHR (9)
            || RPAD ('Organization', 30)
            || CHR (9)
            || RPAD ('Warehouse', 30)
            || CHR (9)
            || RPAD ('Invoice #', 15)
            || CHR (9)
            || RPAD ('Invoice Date', 20)
            || CHR (9)
            || RPAD ('Order #', 15)
            || CHR (9)
            || RPAD ('Factory Inv #', 20)
            || CHR (9)
            || RPAD ('Customer', 60)
            || CHR (9)
            || RPAD ('Country', 15)
            || CHR (9)
            || L_STYLE
            || RPAD ('Invoice Amount', 20)
            || CHR (9)
            || RPAD ('Currency', 10)
            || CHR (9)
            || RPAD ('Amount In USD', 20)
            || CHR (9)
            || RPAD ('Quantity', 10)
            || CHR (9)
            || RPAD ('Landed Cost of Goods', 20)
            || CHR (9)
            || RPAD ('GL Account', 40)
            || CHR (9)
            || RPAD ('Product Group', 50));

        /* LOOP THROUGH INVOICES */
        FOR I IN 1 .. C_INVOICE_TBL.COUNT
        LOOP
            BEGIN
                IF NVL (L_INCLUDE_STYLE, 'N') = 'Y'
                THEN
                    L_STYLE   :=
                        RPAD (C_INVOICE_TBL (I).STYLE, 40) || CHR (9);
                ELSE
                    L_STYLE   := '';
                END IF;

                /*
                 DO_MAIL_UTILS.SEND_MAIL_LINE(C_INVOICE_TBL(I).BRAND || CHR(9) ||
                 C_INVOICE_TBL(I).ORG_NAME || CHR(9) ||
                 C_INVOICE_TBL(I).WAREHOUSE_NAME || CHR(9) ||
                 C_INVOICE_TBL(I).INVOICE_NUMBER || CHR(9) ||
                 TO_CHAR(C_INVOICE_TBL(I).INVOICE_DATE, 'MM/DD/YYYY') || CHR(9) ||
                 C_INVOICE_TBL(I).SALES_ORDER || CHR(9) ||
                 C_INVOICE_TBL(I).SELL_TO_CUSTOMER_NAME || CHR(9) ||
                 C_INVOICE_TBL(I).COUNTRY || CHR(9) ||
                 L_STYLE ||
                 TO_CHAR(C_INVOICE_TBL(I).PRE_CONV_INV_TOTAL, 'FML999,999,990.00') || CHR(9) ||
                 C_INVOICE_TBL(I).INVOICE_CURRENCY_CODE || CHR(9) ||
                 TO_CHAR(C_INVOICE_TBL(I).INVOICE_TOTAL, 'FML999,999,990.00') || CHR(9) ||
                 C_INVOICE_TBL(I).INVOICED_QTY || CHR(9) ||
                 TO_CHAR(C_INVOICE_TBL(I).LANDED_COST_OF_GOODS, 'FML999,999,990.00') || CHR(9) ||
                 GET_INVOICE_GL_CODE(C_INVOICE_TBL(I).CUSTOMER_TRX_ID) || CHR(9) ||
                 C_INVOICE_TBL(I).SERIES
                 , L_RET_VAL);

                */
                IF NVL (L_INCLUDE_STYLE, 'N') = 'Y'
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                           RPAD (C_INVOICE_TBL (I).BRAND, 10)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).ORG_NAME, 30)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).WAREHOUSE_NAME, 30)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).INVOICE_NUMBER, 15)
                        || CHR (9)
                        || RPAD (
                               TO_CHAR (C_INVOICE_TBL (I).INVOICE_DATE,
                                        'MM/DD/YYYY'),
                               20)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).SALES_ORDER, 15)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).FACTORY_INV, 20)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).SELL_TO_CUSTOMER_NAME, 60)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).COUNTRY, 15)
                        || CHR (9)
                        || L_STYLE
                        || RPAD (
                               CONCAT (
                                   (TO_CHAR (C_INVOICE_TBL (I).PRE_CONV_INV_TOTAL, '999,999,990.00')),
                                   ' '),
                               20)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).INVOICE_CURRENCY_CODE, 10)
                        || CHR (9)
                        || RPAD (
                               TO_CHAR (C_INVOICE_TBL (I).INVOICE_TOTAL,
                                        'FML999,999,990.00'),
                               20)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).INVOICED_QTY, 10)
                        || CHR (9)
                        || RPAD (
                               TO_CHAR (
                                   C_INVOICE_TBL (I).LANDED_COST_OF_GOODS,
                                   'FML999,999,990.00'),
                               20)
                        || CHR (9)
                        || RPAD (
                               GET_INVOICE_GL_CODE (
                                   C_INVOICE_TBL (I).CUSTOMER_TRX_ID,
                                   C_INVOICE_TBL (I).STYLE),
                               40)
                        || CHR (9)
                        || RPAD (C_INVOICE_TBL (I).SERIES, 50));
                /*ELSE
                FND_FILE.PUT_LINE(FND_FILE.OUTPUT,C_INVOICE_TBL(I).BRAND || CHR(9) ||
                C_INVOICE_TBL(I).ORG_NAME || CHR(9) ||
                C_INVOICE_TBL(I).WAREHOUSE_NAME || CHR(9) ||
                C_INVOICE_TBL(I).INVOICE_NUMBER || CHR(9) ||
                TO_CHAR(C_INVOICE_TBL(I).INVOICE_DATE, 'MM/DD/YYYY') || CHR(9) ||
                C_INVOICE_TBL(I).SALES_ORDER || CHR(9) ||
                C_INVOICE_TBL(I).FACTORY_INV || CHR(9) ||
                C_INVOICE_TBL(I).SELL_TO_CUSTOMER_NAME || CHR(9) ||
                C_INVOICE_TBL(I).COUNTRY || CHR(9) ||
                L_STYLE ||
                TO_CHAR(C_INVOICE_TBL(I).PRE_CONV_INV_TOTAL, 'FML999,999,990.00') || CHR(9) ||
                C_INVOICE_TBL(I).INVOICE_CURRENCY_CODE || CHR(9) ||
                --TO_CHAR(C_INVOICE_TBL(I).INVOICE_TOTAL, 'FML999,999,990.00') || CHR(9) ||
                C_INVOICE_TBL(I).INVOICE_TOTAL || CHR(9) ||
                C_INVOICE_TBL(I).INVOICED_QTY || CHR(9) ||
                TO_CHAR(C_INVOICE_TBL(I).LANDED_COST_OF_GOODS, 'FML999,999,990.00') || CHR(9) ||
                GET_INVOICE_GL_CODE(C_INVOICE_TBL(I).CUSTOMER_TRX_ID) || CHR(9) ||
                C_INVOICE_TBL(I).SERIES);*/
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                           'Exception Error in Function get_invoices '
                        || SUBSTR (SQLERRM, 1, 200));
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                           'Exception Error in Function get_invoices, Invoice Number '
                        || C_INVOICE_TBL (I).INVOICE_NUMBER);
            END;
        END LOOP;
    --DO_MAIL_UTILS.SEND_MAIL_LINE('--BOUNDARYSTRING--', L_RET_VAL);
    --DO_MAIL_UTILS.SEND_MAIL_CLOSE(L_RET_VAL);
    EXCEPTION
        WHEN EX_NO_DATA_FOUND
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.INTL_INVOICES', V_DEBUG_TEXT => CHR (10) || 'There are no international invoices for the specified month.'
                                       , L_DEBUG_LEVEL => 1);
        /*
         IF V_SEND_NONE_MSG = 'Y' THEN
         DO_MAIL_UTILS.SEND_MAIL_HEADER(FND_PROFILE.VALUE('DO_DEF_ALERT_SENDER'),
         V_DEF_MAIL_RECIPS,
         V_SUBJECT
         , L_RET_VAL
         );
         DO_MAIL_UTILS.SEND_MAIL_LINE('THERE ARE NO INTERNATIONAL INVOICES FOR THE SPECIFIED MONTH.'
         , L_RET_VAL);
         DO_MAIL_UTILS.SEND_MAIL_CLOSE(L_RET_VAL); --BE SAFE
         END IF;
        */
        WHEN EX_NO_RECIPS
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.INTL_INVOICES', V_DEBUG_TEXT => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , L_DEBUG_LEVEL => 1);
        -- DO_MAIL_UTILS.SEND_MAIL_CLOSE(L_RET_VAL); --BE SAFE
        WHEN EX_NO_SENDER
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.INTL_INVOICES', V_DEBUG_TEXT => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , L_DEBUG_LEVEL => 1);
        -- DO_MAIL_UTILS.SEND_MAIL_CLOSE(L_RET_VAL); --BE SAFE
        WHEN OTHERS
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.INTL_INVOICES', V_DEBUG_TEXT => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , L_DEBUG_LEVEL => 1);
    -- DO_MAIL_UTILS.SEND_MAIL_CLOSE(L_RET_VAL); --BE SAFE
    END;

    PROCEDURE PENDING_EDI_INVOICES (P_D1                 OUT VARCHAR2,
                                    P_D2                 OUT VARCHAR2,
                                    V_SEND_NONE_MSG   IN     VARCHAR2 := 'N')
    IS
        L_WIDTH_BRAND      CONSTANT NUMBER := 8;
        L_WIDTH_TRXNUM     CONSTANT NUMBER := 12;
        L_WIDTH_TRXDATE    CONSTANT NUMBER := 12;
        L_WIDTH_CUSTNAME   CONSTANT NUMBER := 30;
        L_WIDTH_ORDNUM     CONSTANT NUMBER := 10;
        L_WIDTH_PICKNUM    CONSTANT NUMBER := 10;
        L_WIDTH_QTY        CONSTANT NUMBER := 11;
        L_WIDTH_AMT        CONSTANT NUMBER := 13;
        L_RET_VAL                   NUMBER := 0;
        V_DEF_MAIL_RECIPS           APPS.DO_MAIL_UTILS.TBL_RECIPS;
        EX_NO_RECIPS                EXCEPTION;
        EX_NO_SENDER                EXCEPTION;
        EX_NO_DATA_FOUND            EXCEPTION;

        TYPE C_INV_REC
            IS RECORD
        (
            BRAND                 APPS.RA_CUSTOMER_TRX_ALL.ATTRIBUTE5%TYPE,
            --VARCHAR (10),
            TRX_NUMBER            APPS.RA_CUSTOMER_TRX_ALL.TRX_NUMBER%TYPE,
            --VARCHAR (20),
            TRX_DATE              APPS.RA_CUSTOMER_TRX_ALL.TRX_DATE%TYPE, --DATE,
            --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            --         CUSTOMER_NAME        APPS.RA_CUSTOMERS.CUSTOMER_NAME%TYPE,
            -- ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            CUSTOMER_NAME         APPS.XXD_RA_CUSTOMERS_V.CUSTOMER_NAME%TYPE,
            --VARCHAR (50),
            ORDER_NUMBER          APPS.RA_CUSTOMER_TRX_ALL.INTERFACE_HEADER_ATTRIBUTE1%TYPE,
            --VARCHAR (30),
            PICK_TICKET_NUMBER    APPS.RA_CUSTOMER_TRX_ALL.INTERFACE_HEADER_ATTRIBUTE3%TYPE,
            --VARCHAR (30),
            INVOICED_QUANTITY     NUMBER,
            INVOICED_AMOUNT       NUMBER
        );

        TYPE C_INV_TBL IS TABLE OF C_INV_REC
            INDEX BY BINARY_INTEGER;

        C_INVOICE_TBL               C_INV_TBL;

        FUNCTION GET_INVOICES
            RETURN C_INV_TBL
        IS
            P_RET   C_INV_TBL;

            CURSOR C_INVOICES IS
                  --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                  -- SELECT   RTA.ATTRIBUTE5 AS BRAND, CUSTS.CUSTOMER_NAME,
                  ----ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                  SELECT HCA.ATTRIBUTE1 AS BRAND, CUSTS.CUSTOMER_NAME, RTA.TRX_DATE,
                         RTA.TRX_NUMBER, RTA.INTERFACE_HEADER_ATTRIBUTE1 AS ORDER_NUMBER, RTA.INTERFACE_HEADER_ATTRIBUTE3 AS PICK_TICKET_NUMBER,
                         SUM (RTLA.QUANTITY_INVOICED) AS INVOICED_QUANTITY, SUM (EXTENDED_AMOUNT) AS INVOICED_AMOUNT
                    FROM APPS.RA_CUSTOMER_TRX_LINES_ALL RTLA, --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                              --   APPS.RA_CUSTOMERS CUSTS,
                                                              --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                                                              APPS.XXD_RA_CUSTOMERS_V CUSTS, APPS.RA_CUST_TRX_TYPES_ALL RTTA,
                         APPS.RA_CUSTOMER_TRX_ALL RTA, APPS.HZ_CUST_ACCOUNTS HCA
                   WHERE     RTTA.CUST_TRX_TYPE_ID = RTA.CUST_TRX_TYPE_ID
                         AND RTTA.ORG_ID = RTA.ORG_ID
                         AND RTLA.CUSTOMER_TRX_ID = RTA.CUSTOMER_TRX_ID
                         AND RTLA.LINE_TYPE = 'LINE'
                         AND RTA.SOLD_TO_CUSTOMER_ID = HCA.CUST_ACCOUNT_ID
                         AND RTLA.INTERFACE_LINE_ATTRIBUTE11 = 0
                         AND CUSTS.CUSTOMER_ID = RTA.BILL_TO_CUSTOMER_ID
                         AND RTTA.TYPE = 'INV'                 --INVOICES ONLY
                         AND RTA.EDI_PROCESSED_FLAG IS NULL --UNPROCESSED INVOICES
                         AND SUBSTR (CUSTS.ATTRIBUTE9, 2, 1) = '1'
                         --ONLY EXTRACT INVOICES FOR CUSTOMERS WITH EDI INV FLAG SET
                         AND RTA.CUSTOMER_TRX_ID >
                             (--START WITH CUSTOMER_TRX_ID AFTER LAST PROCESSED INVOICE
                              SELECT MAX (CUSTOMER_TRX_ID)
                                FROM APPS.RA_CUSTOMER_TRX_ALL
                               WHERE EDI_PROCESSED_FLAG = 'Y')
                --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                -- GROUP BY RTA.ATTRIBUTE5,
                --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                GROUP BY HCA.ATTRIBUTE1, CUSTS.CUSTOMER_NAME, RTA.TRX_DATE,
                         RTA.TRX_NUMBER, RTA.INTERFACE_HEADER_ATTRIBUTE1, RTA.INTERFACE_HEADER_ATTRIBUTE3;
        BEGIN
            FOR C_INV IN C_INVOICES
            LOOP
                BEGIN
                    P_RET (P_RET.COUNT + 1).BRAND       := C_INV.BRAND;
                    P_RET (P_RET.COUNT).TRX_NUMBER      := C_INV.TRX_NUMBER;
                    P_RET (P_RET.COUNT).TRX_DATE        := C_INV.TRX_DATE;
                    P_RET (P_RET.COUNT).CUSTOMER_NAME   :=
                        C_INV.CUSTOMER_NAME;
                    P_RET (P_RET.COUNT).ORDER_NUMBER    := C_INV.ORDER_NUMBER;
                    P_RET (P_RET.COUNT).PICK_TICKET_NUMBER   :=
                        C_INV.PICK_TICKET_NUMBER;
                    P_RET (P_RET.COUNT).INVOICED_QUANTITY   :=
                        C_INV.INVOICED_QUANTITY;
                    P_RET (P_RET.COUNT).INVOICED_AMOUNT   :=
                        C_INV.INVOICED_AMOUNT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                               'Exception for get Invoices is : '
                            || SUBSTR (SQLERRM, 1, 200));
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                            'Exception for Trx Number is : ' || C_INV.TRX_NUMBER);
                END;
            END LOOP;

            RETURN P_RET;
        END;
    BEGIN
        C_INVOICE_TBL       := GET_INVOICES;
        APPS.DO_DEBUG_UTILS.SET_LEVEL (1);

        IF APPS.FND_PROFILE.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE EX_NO_SENDER;
        END IF;

        APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'APPS.DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => 'Recipients...'
                                   , L_DEBUG_LEVEL => 1);
        V_DEF_MAIL_RECIPS   := GET_EMAIL_RECIPS ('apps.DO_EDI_ALERTS');

        FOR I IN 1 .. V_DEF_MAIL_RECIPS.COUNT
        LOOP
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'APPS.DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => V_DEF_MAIL_RECIPS (I)
                                       , L_DEBUG_LEVEL => 1);
        END LOOP;

        IF V_DEF_MAIL_RECIPS.COUNT < 1
        THEN
            RAISE EX_NO_RECIPS;
        END IF;

        IF C_INVOICE_TBL.COUNT < 1
        THEN
            --NO DATA.
            RAISE EX_NO_DATA_FOUND;
        END IF;

        /* E-MAIL HEADER */
        APPS.DO_MAIL_UTILS.SEND_MAIL_HEADER (APPS.FND_PROFILE.VALUE ('DO_DEF_ALERT_SENDER'), V_DEF_MAIL_RECIPS, 'Invoices Pending EDI Extraction - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                             , L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
               RPAD ('Brand', L_WIDTH_BRAND, ' ')
            || RPAD ('Customer', L_WIDTH_CUSTNAME, ' ')
            || LPAD ('Inv. Date', L_WIDTH_TRXDATE, ' ')
            || LPAD ('Invoice #', L_WIDTH_TRXNUM, ' ')
            || LPAD ('Order #', L_WIDTH_ORDNUM, ' ')
            || LPAD ('Pick #', L_WIDTH_PICKNUM, ' ')
            || LPAD ('Quantity', L_WIDTH_QTY, ' ')
            || LPAD ('Amount', L_WIDTH_AMT, ' '),
            L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
            RPAD (
                '=',
                  L_WIDTH_BRAND
                + L_WIDTH_TRXDATE
                + L_WIDTH_TRXNUM
                + L_WIDTH_CUSTNAME
                + L_WIDTH_ORDNUM
                + L_WIDTH_PICKNUM
                + L_WIDTH_QTY
                + L_WIDTH_AMT,
                '='),
            L_RET_VAL);
        APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => CHR (10) || RPAD ('Brand', L_WIDTH_BRAND, ' ') || RPAD ('Customer', L_WIDTH_CUSTNAME, ' ') || LPAD ('Inv. Date', L_WIDTH_TRXDATE, ' ') || LPAD ('Invoice #', L_WIDTH_TRXNUM, ' ') || LPAD ('Order #', L_WIDTH_ORDNUM, ' ') || LPAD ('Pick #', L_WIDTH_PICKNUM, ' ') || LPAD ('Quantity', L_WIDTH_QTY, ' ') || LPAD ('Amount', L_WIDTH_AMT, ' ')
                                   , L_DEBUG_LEVEL => 100);
        APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => RPAD ('=', L_WIDTH_BRAND + L_WIDTH_TRXDATE + L_WIDTH_TRXNUM + L_WIDTH_CUSTNAME + L_WIDTH_ORDNUM + L_WIDTH_PICKNUM + L_WIDTH_QTY + L_WIDTH_AMT, '=')
                                   , L_DEBUG_LEVEL => 100);

        /* LOOP THROUGH PICK TICKETS */
        FOR I IN 1 .. C_INVOICE_TBL.COUNT
        LOOP
            APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   RPAD (C_INVOICE_TBL (I).BRAND, L_WIDTH_BRAND, ' ')
                || RPAD (C_INVOICE_TBL (I).CUSTOMER_NAME,
                         L_WIDTH_CUSTNAME,
                         ' ')
                || LPAD (TO_CHAR (C_INVOICE_TBL (I).TRX_DATE, 'MM/DD/YYYY'),
                         L_WIDTH_TRXDATE,
                         ' ')
                || LPAD (C_INVOICE_TBL (I).TRX_NUMBER, L_WIDTH_TRXNUM, ' ')
                || LPAD (C_INVOICE_TBL (I).ORDER_NUMBER, L_WIDTH_ORDNUM, ' ')
                || LPAD (C_INVOICE_TBL (I).PICK_TICKET_NUMBER,
                         L_WIDTH_PICKNUM,
                         ' ')
                || LPAD (C_INVOICE_TBL (I).INVOICED_QUANTITY,
                         L_WIDTH_QTY,
                         ' ')
                || LPAD (
                       TO_CHAR (C_INVOICE_TBL (I).INVOICED_AMOUNT,
                                'FML999,999,990.00'),
                       L_WIDTH_AMT,
                       ' '),
                L_RET_VAL);
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'APPS.DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => RPAD (C_INVOICE_TBL (I).BRAND, L_WIDTH_BRAND, ' ') || RPAD (C_INVOICE_TBL (I).CUSTOMER_NAME, L_WIDTH_CUSTNAME, ' ') || LPAD (TO_CHAR (C_INVOICE_TBL (I).TRX_DATE, 'MM/DD/YYYY'), L_WIDTH_TRXDATE, ' ') || LPAD (C_INVOICE_TBL (I).TRX_NUMBER, L_WIDTH_TRXNUM, ' ') || LPAD (C_INVOICE_TBL (I).ORDER_NUMBER, L_WIDTH_ORDNUM, ' ') || LPAD (C_INVOICE_TBL (I).PICK_TICKET_NUMBER, L_WIDTH_PICKNUM, ' ') || LPAD (C_INVOICE_TBL (I).INVOICED_QUANTITY, L_WIDTH_QTY, ' ') || LPAD (TO_CHAR (C_INVOICE_TBL (I).INVOICED_AMOUNT, 'FML999,999,990.00'), L_WIDTH_AMT, ' ')
                                       , L_DEBUG_LEVEL => 100);
        END LOOP;

        APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);
    EXCEPTION
        WHEN EX_NO_DATA_FOUND
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'APPS..DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => CHR (10) || 'There are no invoices pending extraction.'
                                       , L_DEBUG_LEVEL => 1);

            IF V_SEND_NONE_MSG = 'Y'
            THEN
                APPS.DO_MAIL_UTILS.SEND_MAIL_HEADER (APPS.FND_PROFILE.VALUE ('DO_DEF_ALERT_SENDER'), V_DEF_MAIL_RECIPS, 'Invoices Pending EDI Extraction - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                                     , L_RET_VAL);
                APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
                    'There are no invoices pending extraction.',
                    L_RET_VAL);
                APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);      --BE SAFE
            END IF;
        WHEN EX_NO_RECIPS
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , L_DEBUG_LEVEL => 1);
            APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);          --BE SAFE
        WHEN EX_NO_SENDER
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , L_DEBUG_LEVEL => 1);
            APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);          --BE SAFE
        WHEN OTHERS
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'apps.DO_OM_REPORT.PENDING_EDI_INVOICES', V_DEBUG_TEXT => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , L_DEBUG_LEVEL => 1);
            APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);          --BE SAFE
            ROLLBACK;
    END;

    PROCEDURE NEW_ACCOUNTS (P_D1                 OUT VARCHAR2,
                            P_D2                 OUT VARCHAR2,
                            V_SEND_NONE_MSG   IN     VARCHAR2 := 'N')
    IS
        L_WIDTH_CUSTOMER_NAME     CONSTANT NUMBER := 30;
        L_WIDTH_CUSTOMER_NUMBER   CONSTANT NUMBER := 30;
        L_WIDTH_CREATION_DATE     CONSTANT NUMBER := 12;
        L_WIDTH_USER_NAME         CONSTANT NUMBER := 50;
        L_RET_VAL                          NUMBER := 0;
        L_USE_MONTH                        DATE := ADD_MONTHS (SYSDATE, -1);
        L_FROM_DATE                        DATE;
        L_TO_DATE                          DATE;
        V_DEF_MAIL_RECIPS                  APPS.DO_MAIL_UTILS.TBL_RECIPS;
        V_SUBJECT                          VARCHAR2 (100);
        EX_NO_RECIPS                       EXCEPTION;
        EX_NO_SENDER                       EXCEPTION;
        EX_NO_DATA_FOUND                   EXCEPTION;

        TYPE C_NEW_ACCT_REC IS RECORD
        (
            --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            --DO_CUSTOM.DO_AR_NEW_ACCOUNTS_V.CUSTOMER_NAME%TYPE,
            --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            CUSTOMER_NAME      APPS.HZ_CUST_ACCOUNTS.ACCOUNT_NAME%TYPE,
            --VARCHAR (100),
            --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            --DO_CUSTOM.DO_AR_NEW_ACCOUNTS_V.CUSTOMER_NUMBER%TYPE
            --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            CUSTOMER_NUMBER    APPS.HZ_CUST_ACCOUNTS.ACCOUNT_NUMBER%TYPE,
            --VARCHAR (30),
            --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            --DO_CUSTOM.DO_AR_NEW_ACCOUNTS_V.CREATION_DATE%TYPE
            --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            CREATION_DATE      APPS.HZ_CUST_ACCOUNTS.CREATION_DATE%TYPE,
            --DATE,
            --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            --DO_CUSTOM.DO_AR_NEW_ACCOUNTS_V.USER_NAME%TYPE
            --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
            USER_NAME          APPS.FND_USER.DESCRIPTION%TYPE
        --VARCHAR (50)
        );

        TYPE C_NEW_ACCOUNT_TBL IS TABLE OF C_NEW_ACCT_REC
            INDEX BY BINARY_INTEGER;

        C_NEW_ACCT_TBL                     C_NEW_ACCOUNT_TBL;

        FUNCTION GET_NEW_ACCOUNTS (P_FROM_DATE IN DATE, P_TO_DATE IN DATE)
            RETURN C_NEW_ACCOUNT_TBL
        IS
            P_RET   C_NEW_ACCOUNT_TBL;

            CURSOR C_NEW_ACCTS IS
                  --COMMENTED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                  /* SELECT   CUSTOMER_NAME, CUSTOMER_NUMBER, CREATION_DATE,
                            USER_NAME
                       FROM DO_CUSTOM.DO_AR_N EW_ACCOUNTS_V
                      WHERE CREATION_DATE >= P_FROM_DATE
                        AND CREATION_DATE < P_TO_DATE + 1
                   ORDER BY CREATION_DATE, CUSTOMER_ID;*/
                  --ADDED BY BT TECHNOLOGY TEAM ON 26-NOV-2014
                  SELECT NVL (HCA.ACCOUNT_NAME, HP.PARTY_NAME) CUSTOMER_NAME, HCA.ACCOUNT_NUMBER CUSTOMER_NUMBER, HCA.CREATION_DATE,
                         NVL (FU.DESCRIPTION, FU.USER_NAME) USER_NAME
                    FROM APPS.HZ_CUST_ACCOUNTS HCA, APPS.HZ_PARTIES HP, APPS.FND_USER FU
                   WHERE     HP.PARTY_ID = HCA.PARTY_ID
                         AND FU.USER_ID = HCA.CREATED_BY
                         AND HCA.CREATION_DATE >= P_FROM_DATE
                         AND HCA.CREATION_DATE < P_TO_DATE + 1
                ORDER BY HCA.CREATION_DATE, HCA.CUST_ACCOUNT_ID;
        BEGIN
            FOR C_NEW_ACCT IN C_NEW_ACCTS
            LOOP
                BEGIN
                    P_RET (P_RET.COUNT + 1).CUSTOMER_NAME   :=
                        C_NEW_ACCT.CUSTOMER_NAME;
                    P_RET (P_RET.COUNT).CUSTOMER_NUMBER   :=
                        C_NEW_ACCT.CUSTOMER_NUMBER;
                    P_RET (P_RET.COUNT).CREATION_DATE   :=
                        C_NEW_ACCT.CREATION_DATE;
                    P_RET (P_RET.COUNT).USER_NAME   := C_NEW_ACCT.USER_NAME;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                               'Exception in get_new_accounts is : '
                            || SUBSTR (SQLERRM, 1, 200));
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                               'Exception for customer_number is : '
                            || C_NEW_ACCT.CUSTOMER_NUMBER);
                END;
            END LOOP;

            RETURN P_RET;
        END;
    BEGIN
        L_FROM_DATE      := TRUNC (L_USE_MONTH, 'MM');
        L_TO_DATE        := TRUNC (LAST_DAY (L_USE_MONTH));
        V_SUBJECT        :=
               'New Accounts for '
            || TO_CHAR (L_FROM_DATE, 'MM/DD/YYYY')
            || ' to '
            || TO_CHAR (L_TO_DATE, 'MM/DD/YYYY');
        C_NEW_ACCT_TBL   := GET_NEW_ACCOUNTS (L_FROM_DATE, L_TO_DATE);
        APPS.DO_DEBUG_UTILS.SET_LEVEL (1);

        IF APPS.FND_PROFILE.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE EX_NO_SENDER;
        END IF;

        APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.NEW_ACCOUNTS', V_DEBUG_TEXT => 'Recipients...'
                                   , L_DEBUG_LEVEL => 1);
        V_DEF_MAIL_RECIPS   :=
            GET_EMAIL_RECIPS ('apps.DO_AR_NEW_ACCOUNTS_ALERT');

        FOR I IN 1 .. V_DEF_MAIL_RECIPS.COUNT
        LOOP
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.NEW_ACCOUNTS', V_DEBUG_TEXT => V_DEF_MAIL_RECIPS (I)
                                       , L_DEBUG_LEVEL => 1);
        END LOOP;

        IF V_DEF_MAIL_RECIPS.COUNT < 1
        THEN
            RAISE EX_NO_RECIPS;
        END IF;

        /* E-MAIL HEADER */
        APPS.DO_MAIL_UTILS.SEND_MAIL_HEADER (APPS.FND_PROFILE.VALUE ('apps.DO_DEF_ALERT_SENDER'), V_DEF_MAIL_RECIPS, V_SUBJECT
                                             , L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE ('--boundarystring', L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE ('Content-Type: text/plain',
                                           L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE ('', L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
            'See attachment for a list of new accounts.',
            L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE ('--boundarystring', L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE ('Content-Type: text/xls',
                                           L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
            'Content-Disposition: attachment; filename="newaccts.xls"',
            L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE ('', L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
               'Customer Name'
            || CHR (9)
            || 'Customer Number'
            || CHR (9)
            || 'Account Created'
            || CHR (9)
            || 'Created By',
            L_RET_VAL);
        APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.NEW_ACCOUNTS', V_DEBUG_TEXT => CHR (10) || RPAD ('Customer Name', L_WIDTH_CUSTOMER_NAME, ' ') || RPAD ('Customer Number', L_WIDTH_CUSTOMER_NUMBER, ' ') || RPAD ('Account Created', L_WIDTH_CREATION_DATE, ' ') || RPAD ('Created By', L_WIDTH_USER_NAME, ' ')
                                   , L_DEBUG_LEVEL => 100);

        FOR I IN 1 .. C_NEW_ACCT_TBL.COUNT
        LOOP
            APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
                   C_NEW_ACCT_TBL (I).CUSTOMER_NAME
                || CHR (9)
                || C_NEW_ACCT_TBL (I).CUSTOMER_NUMBER
                || CHR (9)
                || TO_CHAR (C_NEW_ACCT_TBL (I).CREATION_DATE, 'MM/DD/YYYY')
                || CHR (9)
                || C_NEW_ACCT_TBL (I).USER_NAME,
                L_RET_VAL);
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.NEW_ACCOUNTS', V_DEBUG_TEXT => RPAD (C_NEW_ACCT_TBL (I).CUSTOMER_NAME, L_WIDTH_CUSTOMER_NAME, ' ') || RPAD (C_NEW_ACCT_TBL (I).CUSTOMER_NUMBER, L_WIDTH_CUSTOMER_NUMBER, ' ') || RPAD (TO_CHAR (C_NEW_ACCT_TBL (I).CREATION_DATE, 'MM/DD/YYYY'), L_WIDTH_CREATION_DATE, ' ') || RPAD (C_NEW_ACCT_TBL (I).USER_NAME, L_WIDTH_USER_NAME, ' ')
                                       , L_DEBUG_LEVEL => 100);
        END LOOP;

        APPS.DO_MAIL_UTILS.SEND_MAIL_LINE ('--boundarystring--', L_RET_VAL);
        APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);
    EXCEPTION
        WHEN EX_NO_DATA_FOUND
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => 'XXDO.XXDO_AR_REPORTS.NEW_ACCOUNTS', V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.INTL_INVOICES', V_DEBUG_TEXT => CHR (10) || 'There are no new accounts for the specified month.'
                                       , L_DEBUG_LEVEL => 1);

            IF V_SEND_NONE_MSG = 'Y'
            THEN
                APPS.DO_MAIL_UTILS.SEND_MAIL_HEADER (APPS.FND_PROFILE.VALUE ('DO_DEF_ALERT_SENDER'), V_DEF_MAIL_RECIPS, V_SUBJECT
                                                     , L_RET_VAL);
                APPS.DO_MAIL_UTILS.SEND_MAIL_LINE (
                    'There are no international invoices for the specified month.',
                    L_RET_VAL);
                APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);      --BE SAFE
            END IF;
        WHEN EX_NO_RECIPS
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.NEW_ACCOUNTS', V_DEBUG_TEXT => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , L_DEBUG_LEVEL => 1);
            APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);          --BE SAFE
        WHEN EX_NO_SENDER
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.NEW_ACCOUNTS', V_DEBUG_TEXT => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , L_DEBUG_LEVEL => 1);
            APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);          --BE SAFE
        WHEN OTHERS
        THEN
            APPS.DO_DEBUG_UTILS.WRITE (L_DEBUG_LOC => APPS.DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, V_APPLICATION_ID => 'XXDO.XXDO_AR_REPORTS.NEW_ACCOUNTS', V_DEBUG_TEXT => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , L_DEBUG_LEVEL => 1);
            APPS.DO_MAIL_UTILS.SEND_MAIL_CLOSE (L_RET_VAL);          --BE SAFE
    END;
END XXDO_AR_REPORTS;
/
