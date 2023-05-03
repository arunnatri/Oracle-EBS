--
-- XXD_BPEL_EXTRACTATP  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_BPEL_EXTRACTATP
IS
    FUNCTION PL_TO_SQL1 (aPlsqlItem APPS.ATP_INTEGRATION_PKG.ATPTABLEDATA)
        RETURN ATP_INTEGRATION_X3553062X1X4
    IS
        aSqlItem   ATP_INTEGRATION_X3553062X1X4;
    BEGIN
        -- initialize the object
        aSqlItem                               :=
            ATP_INTEGRATION_X3553062X1X4 (NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL);
        aSqlItem.SKU                           := aPlsqlItem.SKU;
        aSqlItem.SEGMENT1                      := aPlsqlItem.SEGMENT1;
        aSqlItem.SEGMENT2                      := aPlsqlItem.SEGMENT2;
        aSqlItem.SEGMENT3                      := aPlsqlItem.SEGMENT3;
        aSqlItem.SEGMENT4                      := aPlsqlItem.SEGMENT4;
        aSqlItem.SEGMENT5                      := aPlsqlItem.SEGMENT5;
        aSqlItem.SEGMENT6                      := aPlsqlItem.SEGMENT6;
        aSqlItem.SEGMENT7                      := aPlsqlItem.SEGMENT7;
        aSqlItem.SEGMENT8                      := aPlsqlItem.SEGMENT8;
        aSqlItem.ATTRIBUTE6                    := aPlsqlItem.ATTRIBUTE6;
        aSqlItem.ATTRIBUTE7                    := aPlsqlItem.ATTRIBUTE7;
        aSqlItem.ATTRIBUTE8                    := aPlsqlItem.ATTRIBUTE8;
        aSqlItem.ITEM_TYPE                     := aPlsqlItem.ITEM_TYPE;
        aSqlItem.CUSTOMER_ORDER_ENABLED_FLAG   :=
            aPlsqlItem.CUSTOMER_ORDER_ENABLED_FLAG;
        aSqlItem.UPC                           := aPlsqlItem.UPC;
        aSqlItem.DEMAND_CLASS_CODE             :=
            aPlsqlItem.DEMAND_CLASS_CODE;
        aSqlItem.INVENTORY_ITEM_ID             :=
            aPlsqlItem.INVENTORY_ITEM_ID;
        aSqlItem.ATP                           := aPlsqlItem.ATP;
        aSqlItem.ATR                           := aPlsqlItem.ATR;
        aSqlItem.LEAST_ATP_ATR                 := aPlsqlItem.LEAST_ATP_ATR;
        RETURN aSqlItem;
    END PL_TO_SQL1;

    FUNCTION SQL_TO_PL1 (aSqlItem ATP_INTEGRATION_X3553062X1X4)
        RETURN APPS.ATP_INTEGRATION_PKG.ATPTABLEDATA
    IS
        aPlsqlItem   APPS.ATP_INTEGRATION_PKG.ATPTABLEDATA;
    BEGIN
        aPlsqlItem.SKU                           := aSqlItem.SKU;
        aPlsqlItem.SEGMENT1                      := aSqlItem.SEGMENT1;
        aPlsqlItem.SEGMENT2                      := aSqlItem.SEGMENT2;
        aPlsqlItem.SEGMENT3                      := aSqlItem.SEGMENT3;
        aPlsqlItem.SEGMENT4                      := aSqlItem.SEGMENT4;
        aPlsqlItem.SEGMENT5                      := aSqlItem.SEGMENT5;
        aPlsqlItem.SEGMENT6                      := aSqlItem.SEGMENT6;
        aPlsqlItem.SEGMENT7                      := aSqlItem.SEGMENT7;
        aPlsqlItem.SEGMENT8                      := aSqlItem.SEGMENT8;
        aPlsqlItem.ATTRIBUTE6                    := aSqlItem.ATTRIBUTE6;
        aPlsqlItem.ATTRIBUTE7                    := aSqlItem.ATTRIBUTE7;
        aPlsqlItem.ATTRIBUTE8                    := aSqlItem.ATTRIBUTE8;
        aPlsqlItem.ITEM_TYPE                     := aSqlItem.ITEM_TYPE;
        aPlsqlItem.CUSTOMER_ORDER_ENABLED_FLAG   :=
            aSqlItem.CUSTOMER_ORDER_ENABLED_FLAG;
        aPlsqlItem.UPC                           := aSqlItem.UPC;
        aPlsqlItem.DEMAND_CLASS_CODE             :=
            aSqlItem.DEMAND_CLASS_CODE;
        aPlsqlItem.INVENTORY_ITEM_ID             :=
            aSqlItem.INVENTORY_ITEM_ID;
        aPlsqlItem.ATP                           := aSqlItem.ATP;
        aPlsqlItem.ATR                           := aSqlItem.ATR;
        aPlsqlItem.LEAST_ATP_ATR                 := aSqlItem.LEAST_ATP_ATR;
        RETURN aPlsqlItem;
    END SQL_TO_PL1;

    FUNCTION PL_TO_SQL0 (aPlsqlItem APPS.ATP_INTEGRATION_PKG.ATPTABLE)
        RETURN ATP_INTEGRATION_PKG_ATPTABLE
    IS
        aSqlItem   ATP_INTEGRATION_PKG_ATPTABLE;
    BEGIN
        -- initialize the table
        aSqlItem   := ATP_INTEGRATION_PKG_ATPTABLE ();

        IF aPlsqlItem IS NOT NULL
        THEN
            aSqlItem.EXTEND (aPlsqlItem.COUNT);

            IF aPlsqlItem.COUNT > 0
            THEN
                FOR I IN aPlsqlItem.FIRST .. aPlsqlItem.LAST
                LOOP
                    aSqlItem (I + 1 - aPlsqlItem.FIRST)   :=
                        PL_TO_SQL1 (aPlsqlItem (I));
                END LOOP;
            END IF;
        END IF;

        RETURN aSqlItem;
    END PL_TO_SQL0;

    FUNCTION SQL_TO_PL0 (aSqlItem ATP_INTEGRATION_PKG_ATPTABLE)
        RETURN APPS.ATP_INTEGRATION_PKG.ATPTABLE
    IS
        aPlsqlItem   APPS.ATP_INTEGRATION_PKG.ATPTABLE;
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

    PROCEDURE atp_integration_pkg$atp_integ (DEMANDCLASS VARCHAR2, ORGANIZATIONCODE VARCHAR2, ATPTABLEPARAM OUT ATP_INTEGRATION_PKG_ATPTABLE)
    IS
        ATPTABLEPARAM_   APPS.ATP_INTEGRATION_PKG.ATPTABLE;
    BEGIN
        APPS.ATP_INTEGRATION_PKG.ATP_INTEGRATION_PRC (DEMANDCLASS,
                                                      ORGANIZATIONCODE,
                                                      ATPTABLEPARAM_);
        ATPTABLEPARAM   := XXD_BPEL_EXTRACTATP.PL_TO_SQL0 (ATPTABLEPARAM_);
    END atp_integration_pkg$atp_integ;
END XXD_BPEL_EXTRACTATP;
/


--
-- XXD_BPEL_EXTRACTATP  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_BPEL_EXTRACTATP FOR APPS.XXD_BPEL_EXTRACTATP
/


GRANT EXECUTE ON APPS.XXD_BPEL_EXTRACTATP TO SOA_INT
/
