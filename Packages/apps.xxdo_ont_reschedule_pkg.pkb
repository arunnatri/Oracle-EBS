--
-- XXDO_ONT_RESCHEDULE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDO_ONT_RESCHEDULE_PKG
IS
    /*******************************************************************************
    * $Header$
    * Program Name : XXDO_ONT_RESCHEDULE_PKG.pkb
    * Language     : PL/SQL
    * Description  :
    * History      :
    *
    * WHO            WHAT                                    WHEN
    * -------------- --------------------------------------- ---------------
    * Eric.Lu        Original version.                       21-Apr-2015
    *
    *
    *******************************************************************************/

    PROCEDURE IMPORT_SO_DATA (ERRBUF OUT VARCHAR2, RETCODE OUT VARCHAR2, P_ORG_ID IN NUMBER
                              , X_STATUS OUT VARCHAR2, X_ERROR OUT VARCHAR2)
    IS
        /*=============================================================================+
        | PROCEDURE: IMPORT_SO_DATA
        |
        | DESCRIPTION: Import Sales Order Data to customized history table
        |
        | PARAMETERS:
        |   IN:  p_org_id
        |   OUT: errbuf,  retcode,  x_status,  x_error
        |
        | HISTORY:
        |  WHO            WHAT                                    WHEN
        |  -------------- --------------------------------------- ---------------
        |  Eric.Lu        Original version.                       21-Apr-2015
        |
        +============================================================================*/

        V_STATUS   VARCHAR2 (2);
        V_ERROR    VARCHAR2 (2000);
    BEGIN
        BEGIN
            DELETE FROM XXDO_ONT_SCHEDULE_HIS_T
                  WHERE OU_ID = P_ORG_ID;

            INSERT INTO XXDO_ONT_SCHEDULE_HIS_T
                SELECT XXDO.XXDO_ONT_SCHEDULE_HIS_T_S.NEXTVAL, OOLA.ORG_ID, HOU.NAME,
                       OOLA.SHIP_FROM_ORG_ID, MP.ORGANIZATION_CODE, OOHA.ORDER_NUMBER,
                       OOHA.HEADER_ID, OOLA.LINE_NUMBER || '.' || OOLA.SHIPMENT_NUMBER, OOLA.LINE_ID,
                       OOLA.INVENTORY_ITEM_ID, OOLA.ORDERED_ITEM, OOLA.ORDERED_QUANTITY,
                       OOHA.ORDERED_DATE, OOLA.REQUEST_DATE, OOLA.SCHEDULE_SHIP_DATE,
                       SYSDATE, -1, SYSDATE,
                       -1, -1
                  FROM OE_ORDER_HEADERS_ALL OOHA, OE_ORDER_LINES_ALL OOLA, HR_OPERATING_UNITS HOU,
                       MTL_PARAMETERS MP
                 WHERE     OOHA.HEADER_ID = OOLA.HEADER_ID
                       AND OOHA.FLOW_STATUS_CODE = 'BOOKED'
                       AND OOLA.FLOW_STATUS_CODE = 'AWAITING_SHIPPING'
                       AND OOLA.ORG_ID = HOU.ORGANIZATION_ID
                       AND OOLA.SHIP_FROM_ORG_ID = MP.ORGANIZATION_ID
                       AND OOLA.ORG_ID = P_ORG_ID;

            --COMMIT;
            V_STATUS   := 'S';
            V_ERROR    := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                V_STATUS   := 'E';
                V_ERROR    := 'Import SO Schedule Error' || SQLERRM;
                DBMS_OUTPUT.PUT_LINE (
                    'Import SO Schedule Error,the Error is:' || SQLERRM);
        END;
    END IMPORT_SO_DATA;

    PROCEDURE PURGE_SO_HIS_DATE (ERRBUF        OUT VARCHAR2,
                                 RETCODE       OUT VARCHAR2,
                                 P_ORG_ID   IN     NUMBER,
                                 X_STATUS      OUT VARCHAR2,
                                 X_ERROR       OUT VARCHAR2)
    IS
        /*=============================================================================+
        | PROCEDURE: PURGE_SO_HIS_DATE
        |
        | DESCRIPTION: Purge Sales Order Data in customized history table
        |
        | PARAMETERS:
        |   IN:  p_org_id
        |   OUT: errbuf,  retcode,  x_status,  x_error
        |
        | HISTORY:
        |  WHO            WHAT                                    WHEN
        |  -------------- --------------------------------------- ---------------
        |  Eric.Lu        Original version.                       21-Apr-2015
        |
        +============================================================================*/

        V_STATUS   VARCHAR2 (2);
        V_ERROR    VARCHAR2 (2000);
    BEGIN
        BEGIN
            DELETE FROM XXDO_ONT_SCHEDULE_HIS_T
                  WHERE OU_ID = P_ORG_ID;

            --COMMIT;
            V_STATUS   := 'S';
            V_ERROR    := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                V_STATUS   := 'E';
                V_ERROR    :=
                    'Purge SO Schedule History Data Error' || SQLERRM;
                DBMS_OUTPUT.PUT_LINE (
                       'Purge SO Schedule History Data Error,the Error is:'
                    || SQLERRM);
        END;
    END PURGE_SO_HIS_DATE;

    FUNCTION GET_ITEM_BRAND (P_INVENTORY_ITEM_ID   IN NUMBER,
                             P_INV_ORG_ID          IN NUMBER)
        RETURN VARCHAR2
    IS
        /*=============================================================================+
        | PROCEDURE: GET_ITEM_BRAND
        |
        | DESCRIPTION: Get Item Brand by Inventory_Item_Id and Inventory_Organization_Id
        |
        | PARAMETERS:
        |   IN:  P_INVENTORY_ITEM_ID,  P_INV_ORG_ID
        |
        | HISTORY:
        |  WHO            WHAT                                    WHEN
        |  -------------- --------------------------------------- ---------------
        |  Eric.Lu        Original version.                       21-Apr-2015
        |
        +============================================================================*/

        V_ITEM_BRAND   VARCHAR2 (40);
    BEGIN
        BEGIN
            SELECT SEGMENT1
              INTO V_ITEM_BRAND
              FROM MTL_ITEM_CATEGORIES_V
             WHERE     INVENTORY_ITEM_ID = P_INVENTORY_ITEM_ID
                   AND ORGANIZATION_ID = P_INV_ORG_ID
                   AND CATEGORY_SET_ID =
                       (SELECT CATEGORY_SET_ID
                          FROM MTL_CATEGORY_SETS_V
                         WHERE CATEGORY_SET_NAME = 'Inventory');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                V_ITEM_BRAND   := NULL;
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE (
                       'Exception in GET_ITEM_BRAND for Item:'
                    || P_INVENTORY_ITEM_ID
                    || ' in Org:'
                    || P_INV_ORG_ID
                    || SQLERRM);
                V_ITEM_BRAND   := NULL;
        END;

        RETURN V_ITEM_BRAND;
    END GET_ITEM_BRAND;

    FUNCTION GET_ITEM_STYLE (P_INVENTORY_ITEM_ID   IN NUMBER,
                             P_INV_ORG_ID          IN NUMBER)
        RETURN VARCHAR2
    IS
        /*=============================================================================+
        | PROCEDURE: GET_ITEM_STYLE
        |
        | DESCRIPTION: Get Item Style by Inventory_Item_Id and Inventory_Organization_Id
        |
        | PARAMETERS:
        |   IN:  P_INVENTORY_ITEM_ID,  P_INV_ORG_ID
        |
        | HISTORY:
        |  WHO            WHAT                                    WHEN
        |  -------------- --------------------------------------- ---------------
        |  Eric.Lu        Original version.                       21-Apr-2015
        |
        +============================================================================*/

        V_ITEM_STYLE   VARCHAR2 (40);
    BEGIN
        BEGIN
            SELECT SEGMENT7
              INTO V_ITEM_STYLE
              FROM MTL_ITEM_CATEGORIES_V
             WHERE     INVENTORY_ITEM_ID = P_INVENTORY_ITEM_ID
                   AND ORGANIZATION_ID = P_INV_ORG_ID
                   AND CATEGORY_SET_ID =
                       (SELECT CATEGORY_SET_ID
                          FROM MTL_CATEGORY_SETS_V
                         WHERE CATEGORY_SET_NAME = 'Inventory');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                V_ITEM_STYLE   := NULL;
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE (
                       'Exception in GET_ITEM_STYLE for Item:'
                    || P_INVENTORY_ITEM_ID
                    || ' in Org:'
                    || P_INV_ORG_ID
                    || SQLERRM);
                V_ITEM_STYLE   := NULL;
        END;

        RETURN V_ITEM_STYLE;
    END GET_ITEM_STYLE;

    FUNCTION GET_ITEM_COLOR (P_INVENTORY_ITEM_ID   IN NUMBER,
                             P_INV_ORG_ID          IN NUMBER)
        RETURN VARCHAR2
    IS
        /*=============================================================================+
        | PROCEDURE: GET_ITEM_COLOR
        |
        | DESCRIPTION: Get Item Color by Inventory_Item_Id and Inventory_Organization_Id
        |
        | PARAMETERS:
        |   IN:  P_INVENTORY_ITEM_ID,  P_INV_ORG_ID
        |
        | HISTORY:
        |  WHO            WHAT                                    WHEN
        |  -------------- --------------------------------------- ---------------
        |  Eric.Lu        Original version.                       21-Apr-2015
        |
        +============================================================================*/

        V_ITEM_COLOR   VARCHAR2 (40);
    BEGIN
        BEGIN
            SELECT SEGMENT8
              INTO V_ITEM_COLOR
              FROM MTL_ITEM_CATEGORIES_V
             WHERE     INVENTORY_ITEM_ID = P_INVENTORY_ITEM_ID
                   AND ORGANIZATION_ID = P_INV_ORG_ID
                   AND CATEGORY_SET_ID =
                       (SELECT CATEGORY_SET_ID
                          FROM MTL_CATEGORY_SETS_V
                         WHERE CATEGORY_SET_NAME = 'Inventory');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                V_ITEM_COLOR   := NULL;
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE (
                       'Exception in GET_ITEM_COLOR for Item:'
                    || P_INVENTORY_ITEM_ID
                    || ' in Org:'
                    || P_INV_ORG_ID
                    || SQLERRM);
                V_ITEM_COLOR   := NULL;
        END;

        RETURN V_ITEM_COLOR;
    END GET_ITEM_COLOR;

    FUNCTION GET_SO_SUBTOTAL (P_HEADER_ID IN NUMBER)
        RETURN NUMBER
    IS
        /*=============================================================================+
        | PROCEDURE: GET_SO_SUBTOTAL
        |
        | DESCRIPTION: Get SubTotal of Sales Order by Sale_Header_Id
        |
        | PARAMETERS:
        |   IN:  P_HEADER_ID
        |
        | HISTORY:
        |  WHO            WHAT                                    WHEN
        |  -------------- --------------------------------------- ---------------
        |  Eric.Lu        Original version.                       21-Apr-2015
        |
        +============================================================================*/

        V_SO_SUBTOTAL   NUMBER;
    BEGIN
        BEGIN
            SELECT SUM (UNIT_SELLING_PRICE * ORDERED_QUANTITY)
              INTO V_SO_SUBTOTAL
              FROM OE_ORDER_LINES_ALL
             WHERE HEADER_ID = P_HEADER_ID;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE (
                       'Exception in GET_SO_SUBTOTAL for Header_Id:'
                    || P_HEADER_ID
                    || SQLERRM);
                V_SO_SUBTOTAL   := NULL;
        END;

        RETURN V_SO_SUBTOTAL;
    END GET_SO_SUBTOTAL;

    FUNCTION GET_ATP_ERROR_MSG (P_ORDER_NUMBER    IN NUMBER,
                                P_ORDER_LINE_ID   IN NUMBER)
        RETURN VARCHAR2
    IS
        /*=============================================================================+
        | PROCEDURE: GET_ATP_ERROR_MSG
        |
        | DESCRIPTION: Get ATP Error Message by Sale_Order and Sale_Line_Id
        |
        | PARAMETERS:
        |   IN:  P_ORDER_NUMBER,  P_ORDER_LINE_ID
        |
        | HISTORY:
        |  WHO            WHAT                                    WHEN
        |  -------------- --------------------------------------- ---------------
        |  Eric.Lu        Original version.                       21-Apr-2015
        |
        +============================================================================*/

        V_ERROR_MSG   VARCHAR2 (80);
    BEGIN
        BEGIN
            SELECT MLV.MEANING
              INTO V_ERROR_MSG
              FROM MRP_ATP_SCHEDULE_TEMP MAST, MFG_LOOKUPS_V MLV
             WHERE     MAST.ACTION = 120
                   AND MAST.ORDER_NUMBER = P_ORDER_NUMBER
                   AND MAST.ORDER_LINE_ID = P_ORDER_LINE_ID
                   AND MAST.ERROR_CODE = MLV.LOOKUP_CODE
                   AND MLV.LOOKUP_TYPE = 'MTL_DEMAND_INTERFACE_ERRORS'
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                V_ERROR_MSG   := NULL;
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE (
                       'Exception in GET_ATP_ERROR_MSG for ORDER_NUMBER/ORDER_LINE_ID:'
                    || P_ORDER_NUMBER
                    || ' / '
                    || P_ORDER_LINE_ID
                    || SQLERRM);
        END;

        RETURN V_ERROR_MSG;
    END GET_ATP_ERROR_MSG;

    FUNCTION GET_PAST_CANCEL (P_SCHEDULE_SHIP_DATE      IN DATE,
                              P_ORDER_LINE_ATTRIBUTE1   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        /*=============================================================================+
        | PROCEDURE: GET_PAST_CANCEL
        |
        | DESCRIPTION: Get Past Cancel Flag by P_SCHEDULE_SHIP_DATE and P_ORDER_LINE_ATTRIBUTE1
        |
        | PARAMETERS:
        |   IN:  P_SCHEDULE_SHIP_DATE,  P_ORDER_LINE_ATTRIBUTE1
        |
        | HISTORY:
        |  WHO            WHAT                                    WHEN
        |  -------------- --------------------------------------- ---------------
        |  Eric.Lu        Original version.                       21-Apr-2015
        |
        +============================================================================*/

        V_PAST_CANCEL   VARCHAR2 (10);
    BEGIN
        BEGIN
            IF P_SCHEDULE_SHIP_DATE >
               TO_DATE (P_ORDER_LINE_ATTRIBUTE1, 'DD-MON-YYYY')
            THEN
                V_PAST_CANCEL   := 'Yes';
            ELSE
                V_PAST_CANCEL   := 'No';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                BEGIN
                    IF P_SCHEDULE_SHIP_DATE >
                       TO_DATE (P_ORDER_LINE_ATTRIBUTE1,
                                'YYYY/MM/DD HH24:MI:SS')
                    THEN
                        V_PAST_CANCEL   := 'Yes';
                    ELSE
                        V_PAST_CANCEL   := 'No';
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        V_PAST_CANCEL   := 'Error';
                END;
        /*DBMS_OUTPUT.PUT_LINE('Exception in GET_PAST_CANCEL for P_SCHEDULE_SHIP_DATE/P_ORDER_LINE_ATTRIBUTE1:' ||
        P_SCHEDULE_SHIP_DATE || ' / ' ||
        P_ORDER_LINE_ATTRIBUTE1 || SQLERRM);*/
        END;

        RETURN V_PAST_CANCEL;
    END GET_PAST_CANCEL;

    FUNCTION SUBMIT_BURSTING (P_REQUEST_ID IN INTEGER)
        RETURN BOOLEAN
    IS
        N_REQUEST_ID   NUMBER;
        LAY            BOOLEAN;
    BEGIN
        LAY   :=
            FND_REQUEST.ADD_LAYOUT ('XDO', 'BURST_STATUS_REPORT', 'en',
                                    'US', 'PDF');

        N_REQUEST_ID   :=
            FND_REQUEST.SUBMIT_REQUEST ('XDO', 'XDOBURSTREP', NULL,
                                        NULL, FALSE, NVL (P_REQUEST_ID, FND_GLOBAL.CONC_REQUEST_ID)
                                        , 'Y');

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'XDO Program Request ID =' || N_REQUEST_ID);
        COMMIT;

        IF N_REQUEST_ID = 0
        THEN
            RETURN (FALSE);
        ELSE
            RETURN (TRUE);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'ORA exception occurred while '
                || 'executing the XDO Program - '
                || SQLERRM);
            RETURN (FALSE);
    END SUBMIT_BURSTING;
END XXDO_ONT_RESCHEDULE_PKG;
/
