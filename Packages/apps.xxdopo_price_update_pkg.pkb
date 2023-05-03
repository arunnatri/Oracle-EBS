--
-- XXDOPO_PRICE_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOPO_PRICE_UPDATE_PKG"
IS
    /*
    **+-------------------------------------------------------------------------------------------
    **| deckers Outdoor Corporation. PO Price Update Implementation
    **|  Program NAME: PO - Inbound
    **+-------------------------------------------------------------------------------------------
    **| Implemented by: Deckers Outdoor corporation
    **+-------------------------------------------------------------------------------------------
    **| package_name : XXDOPO_PRICE_UPDATE_PKG
    **| file name    : XXDOPO_PRICE_UPDATE_PKG.pkb
    **| type         : package body
    **| creation date: Nov 30 2011
    **| author       :
    **| comments     :The purpose of this api is to process the  new price for the PO Lines based on Style and Color ,
                      validate the contents and completeness of the records and process them. When processed successfully,
                      Purchase Orders are  Updated in Oracle Purchasing  to reflect the new price.
    **+---------------------------------------------------------------------------------------------------------------------------------
    **|Version        Who                       Date                           Comments
    **|1.0             Man Mohan Kummari        30 Nov 2011                    Initial
    **|1.1             BT Technology Team       12-Dec-2014                    Retrofit Changes done for R12.2.3 Upgrade
    **|1.2             GJensen                   1-Nov-2019                    CCR0008186 - APAC CI Invoice
    **+----------------------------------------------------------------------------------------------------------------------------------
    */
    /********************** XXDOPO_PRICE_UPDATE_PKG *******************/
    /* Procedure to load the Price update errors */
    PROCEDURE PRICE_UPDATE_ERRORS (PV_STYLE VARCHAR2, PV_COLOR VARCHAR2, PV_SIZE_ITEM VARCHAR2, PV_NEW_PRICE VARCHAR2, PV_PO_NUMBER VARCHAR2, PV_PO_LINE VARCHAR2, PV_BUY_SEASON VARCHAR2, PV_BUY_MONTH VARCHAR2, PV_PO_HEADER_ID VARCHAR2, PV_PO_LINE_ID VARCHAR2, PV_PO_ITEM_ID VARCHAR2, PV_PO_LINE_LOCATION_ID VARCHAR2
                                   , PV_ERROR_DETAILS VARCHAR2)
    IS
        --PRAGMA AUTONOMOUS_TRANSACTION;  Commented by D.S.Srinivas on 13th April 2012
        lv_sqlcode   VARCHAR2 (300);
        lv_sqlerrm   VARCHAR2 (1000);
    BEGIN
        /* Inserting into the error table when an error is encountered when doing price update in forms*/
        INSERT INTO XXDO.XXDOPO_PRICEUPD_ERRORS
             VALUES (PV_STYLE, PV_COLOR, PV_SIZE_ITEM,
                     PV_NEW_PRICE, PV_PO_NUMBER, PV_PO_LINE,
                     PV_BUY_SEASON, PV_BUY_MONTH, PV_PO_HEADER_ID,
                     PV_PO_LINE_ID, PV_PO_ITEM_ID, PV_PO_LINE_LOCATION_ID,
                     PV_ERROR_DETAILS);

        --
        -- Modification Begin by Srinivas Dumala on 12th April 2012
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_sqlcode   := NULL;
            lv_sqlerrm   := NULL;
            lv_sqlcode   := SUBSTR (SQLCODE, 1, 300);
            lv_sqlerrm   := SUBSTR (SQLERRM, 1, 1000);
            apps.fnd_file.PUT_LINE (
                apps.fnd_file.LOG,
                'SQLCODE - ' || lv_sqlcode || ' SQLERRM - ' || lv_sqlerrm);
    -- Modification End by Srinivas Dumala on 12th April 2012
    --
    END PRICE_UPDATE_ERRORS;

    /* Api to Modify the Price */
    PROCEDURE PRICE_UPDATE_API (PN_RESULT OUT NUMBER, PV_PO_NUMBER VARCHAR2, PV_RELEASE_NUMBER NUMBER, PV_REVISION_NUMBER NUMBER, PV_LINE_NUMBER NUMBER, PV_SHIPMENT_NUMBER VARCHAR2, PV_NEW_QUANTITY NUMBER, PV_NEW_PRICE NUMBER, PV_NEW_PROMISED_DATE DATE, PV_NEW_NEED_BY_DATE DATE, PV_LAUNCH_APPROVALS_FLAG VARCHAR2, PV_UPDATE_SOURCE VARCHAR2, PV_VERSION VARCHAR2, PV_OVERRIDE_DATE DATE, PV_API_ERRORS OUT apps.PO_API_ERRORS_REC_TYPE, PV_BUYER_NAME VARCHAR2, PV_SECONDARY_QUANTITY NUMBER, PV_PREFERRED_GRADE VARCHAR2
                                , PV_ORG_ID NUMBER)
    IS
        --PRAGMA AUTONOMOUS_TRANSACTION; Commented by D.S.Srinivas on 13th April 2012
        lv_result          NUMBER;
        lv_revision_num1   VARCHAR2 (20);
    BEGIN
        /* Getting the revision number for the PO which is getting updated*/
        BEGIN
            SELECT REVISION_NUM
              INTO LV_REVISION_NUM1
              FROM apps.PO_HEADERS_ALL
             WHERE SEGMENT1 = PV_PO_NUMBER AND ORG_ID = PV_ORG_ID;
        EXCEPTION
            WHEN OTHERS
            THEN
                LV_REVISION_NUM1   := PV_REVISION_NUMBER;
        END;

        apps.MO_GLOBAL.SET_POLICY_CONTEXT ('S', PV_ORG_ID);
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG, 'Before calling API');
        /* Calling the API to update the price*/
        lv_result   :=
            apps.PO_CHANGE_API1_S.UPDATE_PO (
                X_PO_NUMBER             => PV_PO_NUMBER,
                X_RELEASE_NUMBER        => PV_RELEASE_NUMBER,
                X_REVISION_NUMBER       => LV_REVISION_NUM1,
                X_LINE_NUMBER           => PV_LINE_NUMBER,
                X_SHIPMENT_NUMBER       => PV_SHIPMENT_NUMBER,
                NEW_QUANTITY            => PV_NEW_QUANTITY,
                NEW_PRICE               => PV_NEW_PRICE,
                NEW_PROMISED_DATE       => PV_NEW_PROMISED_DATE,
                NEW_NEED_BY_DATE        => PV_NEW_NEED_BY_DATE,
                LAUNCH_APPROVALS_FLAG   => PV_LAUNCH_APPROVALS_FLAG,
                UPDATE_SOURCE           => PV_UPDATE_SOURCE,
                VERSION                 => PV_VERSION,
                X_OVERRIDE_DATE         => PV_OVERRIDE_DATE,
                X_API_ERRORS            => PV_API_ERRORS,
                p_BUYER_NAME            => PV_BUYER_NAME,
                p_secondary_quantity    => PV_SECONDARY_QUANTITY,
                p_preferred_grade       => PV_PREFERRED_GRADE,
                p_org_id                => PV_ORG_ID);

        apps.fnd_file.PUT_LINE (
            apps.fnd_file.LOG,
            'After calling API - lv_result - ' || lv_result);

        /* If the result <> 1 then there is an error and that needed to be report out*/
        IF (lv_result <> 1)
        THEN
            FOR i IN 1 .. pv_api_errors.MESSAGE_TEXT.COUNT
            LOOP
                apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                        'INSIDE API ERRORS');
                apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                        pv_API_ERRORS.MESSAGE_TEXT (i));
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       'Error While Updating The Price for PO Number :'
                    || PV_PO_NUMBER
                    || ' and Line Number : '
                    || PV_LINE_NUMBER);
                apps.fnd_file.put_line (apps.fnd_file.output, 'Error Is :');
                apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                        pv_API_ERRORS.MESSAGE_TEXT (i));
            END LOOP;
        ELSE
            UPDATE PO_LINES_ALL
               SET ATTRIBUTE11 = NVL (unit_price, 0) - (NVL (attribute8, 0) + NVL (attribute9, 0))
             WHERE     PO_HEADER_ID =
                       (SELECT PO_HEADER_ID
                          FROM apps.PO_HEADERS_ALL
                         WHERE SEGMENT1 = PV_PO_NUMBER AND ORG_ID = PV_ORG_ID)
                   AND LINE_NUM = PV_LINE_NUMBER; --ADDED BY DIPTI TO UPDATE FOB COST

            --Start CCR0008186
            UPDATE po_line_locations_all
               SET attribute6   = 'Y'
             WHERE po_line_id IN
                       (SELECT po_line_id
                          FROM po_lines_all pla, po_headers_all pha
                         WHERE     pla.po_header_id = pha.po_header_id
                               AND pla.line_num = PV_LINE_NUMBER
                               AND pha.segment1 = PV_PO_NUMBER
                               AND PHA.ORG_ID = PV_ORG_ID);
        --End CCR0008186
        END IF;

        /* Exception Handler*/
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            PRICE_UPDATE_ERRORS (NULL,                             --PV_STYLE,
                                       NULL,                       --PV_COLOR,
                                             NULL,             --PV_SIZE_ITEM,
                                 PV_NEW_PRICE, PV_PO_NUMBER, PV_LINE_NUMBER,
                                 NULL,                        --PV_BUY_SEASON,
                                       NULL,                   --PV_BUY_MONTH,
                                             NULL,          --PV_PO_HEADER_ID,
                                 NULL,                        --PV_PO_LINE_ID,
                                       NULL,                  --PV_PO_ITEM_ID,
                                             NULL,   --PV_PO_LINE_LOCATION_ID,
                                 'Error from the API Call');
    END PRICE_UPDATE_API;

    /* Price Update procedure, this is the main procedure */
    PROCEDURE PRICE_UPDATE (ERRBUFF OUT VARCHAR2, RETCODE OUT NUMBER, PV_STYLE VARCHAR2, PV_COLOR VARCHAR2, PV_BUY_SEASON VARCHAR2, PV_BUY_MONTH VARCHAR2, PV_PO_NUMBER VARCHAR2, PV_NEW_PRICE VARCHAR2, PV_SIZE VARCHAR2
                            , PV_CXFDATE VARCHAR2) -- Added by Srinivas Dumala
    IS
        v_resp_appl_id     NUMBER := APPS.fnd_global.resp_appl_id;
        v_resp_id          NUMBER := APPS.fnd_global.resp_id;
        v_user_id          NUMBER := APPS.fnd_global.user_id;

        /* Cursor to get the style, color etc*/
        CURSOR C_MAIN (LV_STYLE        VARCHAR2,
                       LV_COLOR        VARCHAR2,
                       LV_PO_NUMBER    VARCHAR2,
                       LV_BUY_SEASON   VARCHAR2,
                       LV_BUY_MONTH    VARCHAR2,
                       LV_NEW_PRICE    VARCHAR2)
        IS
            SELECT LV_STYLE
                       STYLE,
                   --LV_COLOR COLOR, -- Commented by Srinivas Dumala on 1st Feb 2012
                   NVL (
                       LV_COLOR,
                       --Start of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                       /* (SELECT SEGMENT2
                           FROM apps.MTL_SYSTEM_ITEMS_B*/
                       --End of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                       --Start of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                       (SELECT color_code
                          FROM apps.XXD_COMMON_ITEMS_V
                         --End of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                         WHERE     organization_id =
                                   --Start of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                                   /*   (select  master_organization_id
                                          from apps.oe_system_parameters)*/
                                   --End of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                                   --Start of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                                   (SELECT DISTINCT master_organization_id
                                      FROM apps.oe_system_parameters)
                               --End of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                               AND INVENTORY_ITEM_ID = POL.ITEM_ID))
                       COLOR,      -- Added by Srinivas Dumala on 1st Feb 2012
                   LV_BUY_SEASON
                       PO_BUY_SEASON,
                   --LV_NEW_PRICE NEW_LINE_PRICE, --Commented on 21Feb14 for MOQ surcharge Enhancement(#ENHC0011840)
                   (NVL (LV_NEW_PRICE, 0) + NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))
                       NEW_LINE_PRICE, --Added on 21Feb14 for for MOQ surcharge Enhancement(#ENHC0011840)
                   poh.authorization_status,
                   poh.revision_num
                       PO_REVISION_NUM,
                   poh.segment1
                       PO_Number,
                   pol.line_num
                       PO_Line,
                   poll.shipment_num
                       PO_Shipment,
                   poh.org_id,
                   pol.item_id
                       Po_item_id,
                   pol.unit_price,
                   poh.PO_HEADER_ID,
                   pol.PO_LINE_ID,
                   poll.LINE_LOCATION_ID,
                   NVL (TRIM (PV_BUY_MONTH), poh.attribute9)
                       PO_BUY_MONTH
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
                           --Start of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                           /*
                           (SELECT inventory_item_id
                               FROM apps.mtl_system_items
                              WHERE TRIM(segment1) = TRIM(LV_STYLE) AND
                                    TRIM(segment2) = NVL(TRIM(LV_COLOR), TRIM(segment2)) -- Added by Srinivas Dumala on 1st feb 2012
                                    AND TRIM(segment3) = NVL(TRIM(PV_SIZE), TRIM(segment3)) -- Added by Srinivas Dumala
                           */
                           --End of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                           --Start of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                           (SELECT inventory_item_id
                              FROM apps.XXD_COMMON_ITEMS_V
                             WHERE     TRIM (style_number) = TRIM (LV_STYLE)
                                   AND TRIM (color_code) =
                                       NVL (TRIM (LV_COLOR),
                                            TRIM (color_code))
                                   AND TRIM (item_size) =
                                       NVL (TRIM (PV_SIZE), TRIM (item_size))
                                   --End of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                                   AND organization_id =
                                       --Start of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                                       /* (select master_organization_id
                                               from apps.oe_system_parameters))*/
                                       --End of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                                       --Start of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                                       (SELECT DISTINCT
                                               master_organization_id
                                          FROM apps.oe_system_parameters))
                   --End of changes by BT Technology Team as per package Ver1.1 on 12-Dec-2014
                   AND                  --Added to filter on passed in CXFDate
                       NVL (
                           TO_DATE (PV_CXFDATE, 'YYYY/MM/DD HH24:MI:SS'),
                           NVL (
                               TO_DATE (poll.attribute5,
                                        'YYYY/MM/DD HH24:MI:SS'),
                               TRUNC (SYSDATE))) =
                       NVL (
                           TO_DATE (poll.attribute5, 'YYYY/MM/DD HH24:MI:SS'),
                           TRUNC (SYSDATE))
                   AND NVL (poh.closed_code, 'OPEN') NOT IN
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

        ln_request_id      NUMBER;
        ln_receipt_count   NUMBER;
        ln_result          NUMBER;
        ln_asn_count       NUMBER;
        lv_api_errors      apps.PO_API_ERRORS_REC_TYPE;
        lv_return_status   VARCHAR2 (1);
        ln_org_id          NUMBER;
    BEGIN
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG, 'Style : ' || PV_STYLE);
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG, 'Color : ' || PV_COLOR);
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                'Buy Season : ' || PV_BUY_SEASON);
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                'Buy Month : ' || PV_BUY_MONTH);
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                'PO NUmber : ' || PV_PO_NUMBER);
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                'New Price : ' || PV_NEW_PRICE);
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG, 'Size : ' || PV_SIZE);
        apps.fnd_file.PUT_LINE (apps.fnd_file.LOG,
                                'CXFDate : ' || PV_CXFDATE);

        IF NVL (PV_NEW_PRICE, 0) = 0 OR NVL (PV_NEW_PRICE, 0) < 0
        THEN
            apps.fnd_file.PUT_LINE (
                apps.fnd_file.LOG,
                'Price should not be either zero or NULL');
            PRICE_UPDATE_ERRORS (
                PV_STYLE,
                PV_COLOR,
                NULL,
                PV_NEW_PRICE,
                NULL,
                NULL,
                PV_BUY_SEASON,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                'Error as price is either zero or less than zero');
        ELSE
            FOR I IN C_MAIN (pv_style, pv_color, pv_po_number,
                             pv_buy_season, pv_buy_month, pv_new_price)
            LOOP
                apps.MO_GLOBAL.INIT ('PO');

                BEGIN
                    PRICE_UPDATE_API (LN_RESULT, I.PO_NUMBER, NULL,
                                      I.PO_REVISION_NUM, I.PO_LINE, NULL, --I.PO_SHIPMENT COMMENTED BY SIVAKUMAR BOOTHATHAN ON 06/26 FOR PASSING THE PRICE AT LINE LEVEL,
                                      NULL, TO_NUMBER (I.NEW_LINE_PRICE), NULL, NULL, 'N', NULL, '1.0', NULL, lv_api_errors, NULL, NULL, NULL
                                      , I.ORG_ID);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.PUT_LINE (
                            apps.fnd_file.LOG,
                               'Exception occured in the api '
                            || SQLCODE
                            || SUBSTR (SQLERRM, 1, 300));
                END;
            END LOOP;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.PUT_LINE (
                apps.fnd_file.LOG,
                   'Exception occured in the main program  '
                || SQLCODE
                || SUBSTR (SQLERRM, 1, 300));
    END;
END;
/
