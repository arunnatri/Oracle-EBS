--
-- XXDOEC_PRODUCT_CUSTOMIZATION_B  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_PRODUCT_CUSTOMIZATION_B"
IS
    FUNCTION PL_TO_SQL0 (
        aPlsqlItem APPS.XXDOEC_PRODUCT_CUSTOMIZATION.INVOICE_REC_TYPE)
        RETURN XXDOEC_PRODUCT_X1450732X4X10
    IS
        aSqlItem   XXDOEC_PRODUCT_X1450732X4X10;
    BEGIN
        -- initialize the object
        aSqlItem                        :=
            XXDOEC_PRODUCT_X1450732X4X10 (NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL);
        aSqlItem.INVOICE_ID             := aPlsqlItem.INVOICE_ID;
        aSqlItem.ORDER_ID               := aPlsqlItem.ORDER_ID;
        aSqlItem.FLUID_RECIPE_ID        := aPlsqlItem.FLUID_RECIPE_ID;
        aSqlItem.ORDER_LINE_NUMBER      := aPlsqlItem.ORDER_LINE_NUMBER;
        aSqlItem.ACTUAL_SHIPMENT_DATE   := aPlsqlItem.ACTUAL_SHIPMENT_DATE;
        aSqlItem.AWB_NUMBER             := aPlsqlItem.AWB_NUMBER;
        aSqlItem.TRACKING_NUMBER        := aPlsqlItem.TRACKING_NUMBER;
        aSqlItem.ITEM_UPC               := aPlsqlItem.ITEM_UPC;
        aSqlItem.ITEM_CODE              := aPlsqlItem.ITEM_CODE;
        aSqlItem.ITEM_DESCRIPTION       := aPlsqlItem.ITEM_DESCRIPTION;
        aSqlItem.QUANTITY               := aPlsqlItem.QUANTITY;
        aSqlItem.UNIT_COST              := aPlsqlItem.UNIT_COST;
        RETURN aSqlItem;
    END PL_TO_SQL0;

    FUNCTION SQL_TO_PL1 (aSqlItem XXDOEC_PRODUCT_X1450732X4X10)
        RETURN APPS.XXDOEC_PRODUCT_CUSTOMIZATION.INVOICE_REC_TYPE
    IS
        aPlsqlItem   APPS.XXDOEC_PRODUCT_CUSTOMIZATION.INVOICE_REC_TYPE;
    BEGIN
        aPlsqlItem.INVOICE_ID             := aSqlItem.INVOICE_ID;
        aPlsqlItem.ORDER_ID               := aSqlItem.ORDER_ID;
        aPlsqlItem.FLUID_RECIPE_ID        := aSqlItem.FLUID_RECIPE_ID;
        aPlsqlItem.ORDER_LINE_NUMBER      := aSqlItem.ORDER_LINE_NUMBER;
        aPlsqlItem.ACTUAL_SHIPMENT_DATE   := aSqlItem.ACTUAL_SHIPMENT_DATE;
        aPlsqlItem.AWB_NUMBER             := aSqlItem.AWB_NUMBER;
        aPlsqlItem.TRACKING_NUMBER        := aSqlItem.TRACKING_NUMBER;
        aPlsqlItem.ITEM_UPC               := aSqlItem.ITEM_UPC;
        aPlsqlItem.ITEM_CODE              := aSqlItem.ITEM_CODE;
        aPlsqlItem.ITEM_DESCRIPTION       := aSqlItem.ITEM_DESCRIPTION;
        aPlsqlItem.QUANTITY               := aSqlItem.QUANTITY;
        aPlsqlItem.UNIT_COST              := aSqlItem.UNIT_COST;
        RETURN aPlsqlItem;
    END SQL_TO_PL1;

    FUNCTION PL_TO_SQL1 (
        aPlsqlItem APPS.XXDOEC_PRODUCT_CUSTOMIZATION.INVOICE_REC_TBL_TYPE)
        RETURN XXDOEC_PRODUCT_CX1450732X4X9
    IS
        aSqlItem   XXDOEC_PRODUCT_CX1450732X4X9;
    BEGIN
        -- initialize the table
        aSqlItem   := XXDOEC_PRODUCT_CX1450732X4X9 ();

        IF aPlsqlItem IS NOT NULL
        THEN
            aSqlItem.EXTEND (aPlsqlItem.COUNT);

            IF aPlsqlItem.COUNT > 0
            THEN
                FOR I IN aPlsqlItem.FIRST .. aPlsqlItem.LAST
                LOOP
                    aSqlItem (I + 1 - aPlsqlItem.FIRST)   :=
                        PL_TO_SQL0 (aPlsqlItem (I));
                END LOOP;
            END IF;
        END IF;

        RETURN aSqlItem;
    END PL_TO_SQL1;

    FUNCTION SQL_TO_PL0 (aSqlItem XXDOEC_PRODUCT_CX1450732X4X9)
        RETURN APPS.XXDOEC_PRODUCT_CUSTOMIZATION.INVOICE_REC_TBL_TYPE
    IS
        aPlsqlItem   APPS.XXDOEC_PRODUCT_CUSTOMIZATION.INVOICE_REC_TBL_TYPE;
    BEGIN
        IF aSqlItem.COUNT > 0
        THEN
            FOR I IN 1 .. aSqlItem.COUNT
            LOOP
                aPlsqlItem (I)   := SQL_TO_PL1 (aSqlItem (I));
            END LOOP;
        END IF;

        RETURN aPlsqlItem;
    END SQL_TO_PL0;

    PROCEDURE xxdoec_product_customization$ (
        P_SENDER_ID                  VARCHAR2,
        P_INVOICE_NUMBER             VARCHAR2,
        P_INVOICE_DATE               DATE,
        P_INVOICE_CURRENCY           VARCHAR2,
        P_PERIOD_START_DATE          DATE,
        P_PERIOD_END_DATE            DATE,
        P_TOTAL_UNITS_SHIPPED        NUMBER,
        P_TOTAL_INVOICE_AMOUNT       NUMBER,
        P_INVOICE_DATA_TBL           XXDOEC_PRODUCT_CX1450732X4X9,
        P_RETCODE                OUT NUMBER,
        P_ERRBUF                 OUT VARCHAR2)
    IS
        P_INVOICE_DATA_TBL_   APPS.XXDOEC_PRODUCT_CUSTOMIZATION.INVOICE_REC_TBL_TYPE;
    BEGIN
        P_INVOICE_DATA_TBL_   :=
            XXDOEC_PRODUCT_CUSTOMIZATION_B.SQL_TO_PL0 (P_INVOICE_DATA_TBL);
        APPS.XXDOEC_PRODUCT_CUSTOMIZATION.INSERT_INVOICE_DATA (
            P_SENDER_ID,
            P_INVOICE_NUMBER,
            P_INVOICE_DATE,
            P_INVOICE_CURRENCY,
            P_PERIOD_START_DATE,
            P_PERIOD_END_DATE,
            P_TOTAL_UNITS_SHIPPED,
            P_TOTAL_INVOICE_AMOUNT,
            P_INVOICE_DATA_TBL_,
            P_RETCODE,
            P_ERRBUF);
    END xxdoec_product_customization$;
END XXDOEC_PRODUCT_CUSTOMIZATION_B;
/


--
-- XXDOEC_PRODUCT_CUSTOMIZATION_B  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDOEC_PRODUCT_CUSTOMIZATION_B FOR APPS.XXDOEC_PRODUCT_CUSTOMIZATION_B
/


GRANT EXECUTE ON APPS.XXDOEC_PRODUCT_CUSTOMIZATION_B TO SOA_INT
/
