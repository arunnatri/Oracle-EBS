--
-- XXDO_DO_REP_CUST_DUP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_DO_REP_CUST_DUP_PKG"
/****************************************************************************************
* Package      : XXDO_DO_REP_CUST_DUP_PKG
* Description  : This is package for salesrep maintance page validation
* Notes        :
* Modification :
-- ===========  ========    ======================= =====================================
-- Date         Version#    Name                    Comments
-- ===========  ========    ======================= =======================================
-- 15-Sep-2022   1.0         gaurav Joshi           CCR0010034
******************************************************************************************/
IS
    PROCEDURE XXDO_DO_REP_CUST_DUP_ACT_REC (SALESREPROW DO_CUSTOM.DO_REP_CUST_ASSIGNMENT_TBLTYPE, STATUS OUT VARCHAR2, ERROR_MESSAGE OUT VARCHAR2)
    IS
        LN_START_DATE   DATE;
        LN_END_DATE     DATE;
        ROW_COUNT       NUMBER := 0;
        V_COUNT         NUMBER := 0;
    BEGIN
        V_COUNT   := SALESREPROW.COUNT;

        IF V_COUNT > 0
        THEN
            FOR i IN SALESREPROW.FIRST .. SALESREPROW.LAST
            LOOP
                SELECT COUNT (1)
                  INTO ROW_COUNT
                  FROM DO_CUSTOM.DO_REP_CUST_ASSIGNMENT
                 WHERE     CUSTOMER_ID = SALESREPROW (i).CUSTOMER_ID
                       AND BRAND = SALESREPROW (i).BRAND
                       AND NVL (SITE_USE_ID, 0) =
                           NVL (SALESREPROW (i).SITE_USE_ID, 0)
                       AND NVL (DIVISION, 'X') =
                           NVL (SALESREPROW (i).DIVISION, 'X')
                       AND NVL (DEPARTMENT, 'X') =
                           NVL (SALESREPROW (i).DEPARTMENT, 'X')
                       AND NVL (CLASS, 'X') =
                           NVL (SALESREPROW (i).MASTER_CLASS, 'X')
                       AND NVL (SUB_CLASS, 'X') =
                           NVL (SALESREPROW (i).SUB_CLASS, 'X')
                       AND ORG_ID = SALESREPROW (i).ORG_ID
                       AND CUSTOMER_NUMBER = SALESREPROW (i).CUSTOMER_NUMBER
                       AND CUSTOMER_SITE = SALESREPROW (i).CUSTOMER_SITE
                       AND NVL (STYLE_NUMBER, 'X') =
                           NVL (SALESREPROW (i).STYLE_NUMBER, 'X')
                       AND NVL (COLOR_CODE, 'X') =
                           NVL (SALESREPROW (i).COLOR_CODE, 'X')
                       AND (SALESREPROW (i).ROW_ID IS NULL OR ROWIDTOCHAR (ROWID) <> SALESREPROW (i).ROW_ID)
                       AND ((END_DATE IS NULL AND NOT (START_DATE > SALESREPROW (i).START_DATE AND START_DATE > SALESREPROW (i).END_DATE)) OR (END_DATE IS NULL AND SALESREPROW (i).END_DATE IS NULL) OR SALESREPROW (i).START_DATE BETWEEN START_DATE AND END_DATE OR (SALESREPROW (i).END_DATE IS NULL AND (START_DATE >= SALESREPROW (i).START_DATE OR END_DATE >= SALESREPROW (i).START_DATE)) OR (SALESREPROW (i).END_DATE IS NOT NULL AND (SALESREPROW (i).END_DATE BETWEEN START_DATE AND END_DATE OR (START_DATE BETWEEN SALESREPROW (i).START_DATE AND SALESREPROW (i).END_DATE AND (START_DATE >= SYSDATE)) OR END_DATE BETWEEN SALESREPROW (i).START_DATE AND SALESREPROW (i).END_DATE AND (end_DATE >= SYSDATE))));

                EXIT WHEN ROW_COUNT > 0;
            END LOOP;

            IF ROW_COUNT > 0
            THEN
                STATUS   := 'TRUE';
                ERROR_MESSAGE   :=
                    'Duplicate active records for Operating Unit, Customer Account, Customer site, Brand, Division, Department, Class, Sub-Class, Style and Color code combination already exists.';
            ELSIF ROW_COUNT = 0
            THEN
                STATUS          := 'FALSE';
                ERROR_MESSAGE   := ' ';
            END IF;
        ELSIF V_COUNT = 0
        THEN
            STATUS          := 'TRUE';
            ERROR_MESSAGE   := 'Please select a record before saving.';
        END IF;
    END XXDO_DO_REP_CUST_DUP_ACT_REC;
END XXDO_DO_REP_CUST_DUP_PKG;
/
