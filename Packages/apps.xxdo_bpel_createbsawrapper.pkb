--
-- XXDO_BPEL_CREATEBSAWRAPPER  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_BPEL_CREATEBSAWRAPPER"
IS
    FUNCTION PL_TO_SQL0 (aPlsqlItem APPS.OE_BLANKET_PUB.LINE_REC_TYPE)
        RETURN XXDO_BK_BSA_CREX3548687X1X10
    IS
        aSqlItem   XXDO_BK_BSA_CREX3548687X1X10;
    BEGIN
        -- initialize the object
        aSqlItem                             :=
            XXDO_BK_BSA_CREX3548687X1X10 (NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL, NULL,
                                          NULL, NULL);
        aSqlItem.ACCOUNTING_RULE_ID          := aPlsqlItem.ACCOUNTING_RULE_ID;
        aSqlItem.AGREEMENT_ID                := aPlsqlItem.AGREEMENT_ID;
        aSqlItem.ATTRIBUTE1                  := aPlsqlItem.ATTRIBUTE1;
        aSqlItem.ATTRIBUTE10                 := aPlsqlItem.ATTRIBUTE10;
        aSqlItem.ATTRIBUTE11                 := aPlsqlItem.ATTRIBUTE11;
        aSqlItem.ATTRIBUTE12                 := aPlsqlItem.ATTRIBUTE12;
        aSqlItem.ATTRIBUTE13                 := aPlsqlItem.ATTRIBUTE13;
        aSqlItem.ATTRIBUTE14                 := aPlsqlItem.ATTRIBUTE14;
        aSqlItem.ATTRIBUTE15                 := aPlsqlItem.ATTRIBUTE15;
        aSqlItem.ATTRIBUTE16                 := aPlsqlItem.ATTRIBUTE16;
        aSqlItem.ATTRIBUTE17                 := aPlsqlItem.ATTRIBUTE17;
        aSqlItem.ATTRIBUTE18                 := aPlsqlItem.ATTRIBUTE18;
        aSqlItem.ATTRIBUTE19                 := aPlsqlItem.ATTRIBUTE19;
        aSqlItem.ATTRIBUTE20                 := aPlsqlItem.ATTRIBUTE20;
        aSqlItem.ATTRIBUTE2                  := aPlsqlItem.ATTRIBUTE2;
        aSqlItem.ATTRIBUTE3                  := aPlsqlItem.ATTRIBUTE3;
        aSqlItem.ATTRIBUTE4                  := aPlsqlItem.ATTRIBUTE4;
        aSqlItem.ATTRIBUTE5                  := aPlsqlItem.ATTRIBUTE5;
        aSqlItem.ATTRIBUTE6                  := aPlsqlItem.ATTRIBUTE6;
        aSqlItem.ATTRIBUTE7                  := aPlsqlItem.ATTRIBUTE7;
        aSqlItem.ATTRIBUTE8                  := aPlsqlItem.ATTRIBUTE8;
        aSqlItem.ATTRIBUTE9                  := aPlsqlItem.ATTRIBUTE9;
        aSqlItem.CONTEXT                     := aPlsqlItem.CONTEXT;
        aSqlItem.CREATED_BY                  := aPlsqlItem.CREATED_BY;
        aSqlItem.CREATION_DATE               := aPlsqlItem.CREATION_DATE;
        aSqlItem.CUST_PO_NUMBER              := aPlsqlItem.CUST_PO_NUMBER;
        aSqlItem.DELIVER_TO_ORG_ID           := aPlsqlItem.DELIVER_TO_ORG_ID;
        aSqlItem.FREIGHT_TERMS_CODE          := aPlsqlItem.FREIGHT_TERMS_CODE;
        aSqlItem.GLOBAL_ATTRIBUTE_CATEGORY   :=
            aPlsqlItem.GLOBAL_ATTRIBUTE_CATEGORY;
        aSqlItem.HEADER_ID                   := aPlsqlItem.HEADER_ID;
        aSqlItem.INVENTORY_ITEM_ID           := aPlsqlItem.INVENTORY_ITEM_ID;
        aSqlItem.INVOICE_TO_ORG_ID           := aPlsqlItem.INVOICE_TO_ORG_ID;
        aSqlItem.INVOICING_RULE_ID           := aPlsqlItem.INVOICING_RULE_ID;
        aSqlItem.ORDERED_ITEM                := aPlsqlItem.ORDERED_ITEM;
        aSqlItem.ORDERED_ITEM_ID             := aPlsqlItem.ORDERED_ITEM_ID;
        aSqlItem.LAST_UPDATED_BY             := aPlsqlItem.LAST_UPDATED_BY;
        aSqlItem.LAST_UPDATE_DATE            := aPlsqlItem.LAST_UPDATE_DATE;
        aSqlItem.LAST_UPDATE_LOGIN           := aPlsqlItem.LAST_UPDATE_LOGIN;
        aSqlItem.LINE_TYPE_ID                := aPlsqlItem.LINE_TYPE_ID;
        aSqlItem.LINE_ID                     := aPlsqlItem.LINE_ID;
        aSqlItem.LINE_NUMBER                 := aPlsqlItem.LINE_NUMBER;
        aSqlItem.ORDER_NUMBER                := aPlsqlItem.ORDER_NUMBER;
        aSqlItem.ORDER_QUANTITY_UOM          := aPlsqlItem.ORDER_QUANTITY_UOM;
        aSqlItem.ORG_ID                      := aPlsqlItem.ORG_ID;
        aSqlItem.PAYMENT_TERM_ID             := aPlsqlItem.PAYMENT_TERM_ID;
        aSqlItem.PREFERRED_GRADE             := aPlsqlItem.PREFERRED_GRADE;
        aSqlItem.PRICE_LIST_ID               := aPlsqlItem.PRICE_LIST_ID;
        aSqlItem.REQUEST_ID                  := aPlsqlItem.REQUEST_ID;
        aSqlItem.PROGRAM_ID                  := aPlsqlItem.PROGRAM_ID;
        aSqlItem.PROGRAM_APPLICATION_ID      :=
            aPlsqlItem.PROGRAM_APPLICATION_ID;
        aSqlItem.PROGRAM_UPDATE_DATE         :=
            aPlsqlItem.PROGRAM_UPDATE_DATE;
        aSqlItem.SHIPPING_METHOD_CODE        :=
            aPlsqlItem.SHIPPING_METHOD_CODE;
        aSqlItem.SHIP_FROM_ORG_ID            := aPlsqlItem.SHIP_FROM_ORG_ID;
        aSqlItem.SHIP_TO_ORG_ID              := aPlsqlItem.SHIP_TO_ORG_ID;
        aSqlItem.SOLD_TO_ORG_ID              := aPlsqlItem.SOLD_TO_ORG_ID;
        aSqlItem.RETURN_STATUS               := aPlsqlItem.RETURN_STATUS;
        aSqlItem.DB_FLAG                     := aPlsqlItem.DB_FLAG;
        aSqlItem.OPERATION                   := aPlsqlItem.OPERATION;
        aSqlItem.ITEM_IDENTIFIER_TYPE        :=
            aPlsqlItem.ITEM_IDENTIFIER_TYPE;
        aSqlItem.ITEM_TYPE_CODE              := aPlsqlItem.ITEM_TYPE_CODE;
        aSqlItem.SHIPPING_INSTRUCTIONS       :=
            aPlsqlItem.SHIPPING_INSTRUCTIONS;
        aSqlItem.PACKING_INSTRUCTIONS        :=
            aPlsqlItem.PACKING_INSTRUCTIONS;
        aSqlItem.SALESREP_ID                 := aPlsqlItem.SALESREP_ID;
        aSqlItem.UNIT_LIST_PRICE             := aPlsqlItem.UNIT_LIST_PRICE;
        aSqlItem.PRICING_UOM                 := aPlsqlItem.PRICING_UOM;
        aSqlItem.LOCK_CONTROL                := aPlsqlItem.LOCK_CONTROL;
        aSqlItem.ENFORCE_PRICE_LIST_FLAG     :=
            aPlsqlItem.ENFORCE_PRICE_LIST_FLAG;
        aSqlItem.ENFORCE_SHIP_TO_FLAG        :=
            aPlsqlItem.ENFORCE_SHIP_TO_FLAG;
        aSqlItem.ENFORCE_INVOICE_TO_FLAG     :=
            aPlsqlItem.ENFORCE_INVOICE_TO_FLAG;
        aSqlItem.ENFORCE_FREIGHT_TERM_FLAG   :=
            aPlsqlItem.ENFORCE_FREIGHT_TERM_FLAG;
        aSqlItem.ENFORCE_SHIPPING_METHOD_FLAG   :=
            aPlsqlItem.ENFORCE_SHIPPING_METHOD_FLAG;
        aSqlItem.ENFORCE_PAYMENT_TERM_FLAG   :=
            aPlsqlItem.ENFORCE_PAYMENT_TERM_FLAG;
        aSqlItem.ENFORCE_ACCOUNTING_RULE_FLAG   :=
            aPlsqlItem.ENFORCE_ACCOUNTING_RULE_FLAG;
        aSqlItem.ENFORCE_INVOICING_RULE_FLAG   :=
            aPlsqlItem.ENFORCE_INVOICING_RULE_FLAG;
        aSqlItem.OVERRIDE_BLANKET_CONTROLS_FLAG   :=
            aPlsqlItem.OVERRIDE_BLANKET_CONTROLS_FLAG;
        aSqlItem.OVERRIDE_RELEASE_CONTROLS_FLAG   :=
            aPlsqlItem.OVERRIDE_RELEASE_CONTROLS_FLAG;
        aSqlItem.QP_LIST_LINE_ID             :=
            aPlsqlItem.QP_LIST_LINE_ID;
        aSqlItem.FULFILLED_QUANTITY          :=
            aPlsqlItem.FULFILLED_QUANTITY;
        aSqlItem.BLANKET_MIN_QUANTITY        :=
            aPlsqlItem.BLANKET_MIN_QUANTITY;
        aSqlItem.BLANKET_MAX_QUANTITY        :=
            aPlsqlItem.BLANKET_MAX_QUANTITY;
        aSqlItem.BLANKET_MIN_AMOUNT          :=
            aPlsqlItem.BLANKET_MIN_AMOUNT;
        aSqlItem.BLANKET_MAX_AMOUNT          :=
            aPlsqlItem.BLANKET_MAX_AMOUNT;
        aSqlItem.MIN_RELEASE_QUANTITY        :=
            aPlsqlItem.MIN_RELEASE_QUANTITY;
        aSqlItem.MAX_RELEASE_QUANTITY        :=
            aPlsqlItem.MAX_RELEASE_QUANTITY;
        aSqlItem.MIN_RELEASE_AMOUNT          :=
            aPlsqlItem.MIN_RELEASE_AMOUNT;
        aSqlItem.MAX_RELEASE_AMOUNT          :=
            aPlsqlItem.MAX_RELEASE_AMOUNT;
        aSqlItem.RELEASED_AMOUNT             :=
            aPlsqlItem.RELEASED_AMOUNT;
        aSqlItem.FULFILLED_AMOUNT            :=
            aPlsqlItem.FULFILLED_AMOUNT;
        aSqlItem.RELEASED_QUANTITY           :=
            aPlsqlItem.RELEASED_QUANTITY;
        aSqlItem.RETURNED_AMOUNT             :=
            aPlsqlItem.RETURNED_AMOUNT;
        aSqlItem.RETURNED_QUANTITY           :=
            aPlsqlItem.RETURNED_QUANTITY;
        aSqlItem.START_DATE_ACTIVE           :=
            aPlsqlItem.START_DATE_ACTIVE;
        aSqlItem.END_DATE_ACTIVE             :=
            aPlsqlItem.END_DATE_ACTIVE;
        aSqlItem.SOURCE_DOCUMENT_TYPE_ID     :=
            aPlsqlItem.SOURCE_DOCUMENT_TYPE_ID;
        aSqlItem.SOURCE_DOCUMENT_ID          :=
            aPlsqlItem.SOURCE_DOCUMENT_ID;
        aSqlItem.SOURCE_DOCUMENT_LINE_ID     :=
            aPlsqlItem.SOURCE_DOCUMENT_LINE_ID;
        aSqlItem.TRANSACTION_PHASE_CODE      :=
            aPlsqlItem.TRANSACTION_PHASE_CODE;
        aSqlItem.SOURCE_DOCUMENT_VERSION_NUMBER   :=
            aPlsqlItem.SOURCE_DOCUMENT_VERSION_NUMBER;
        aSqlItem.MODIFIER_LIST_LINE_ID       :=
            aPlsqlItem.MODIFIER_LIST_LINE_ID;
        aSqlItem.DISCOUNT_PERCENT            :=
            aPlsqlItem.DISCOUNT_PERCENT;
        aSqlItem.DISCOUNT_AMOUNT             :=
            aPlsqlItem.DISCOUNT_AMOUNT;
        aSqlItem.REVISION_CHANGE_COMMENTS    :=
            aPlsqlItem.REVISION_CHANGE_COMMENTS;
        aSqlItem.REVISION_CHANGE_DATE        :=
            aPlsqlItem.REVISION_CHANGE_DATE;
        aSqlItem.REVISION_CHANGE_REASON_CODE   :=
            aPlsqlItem.REVISION_CHANGE_REASON_CODE;
        RETURN aSqlItem;
    END PL_TO_SQL0;

    FUNCTION SQL_TO_PL1 (aSqlItem XXDO_BK_BSA_CREX3548687X1X10)
        RETURN APPS.OE_BLANKET_PUB.LINE_REC_TYPE
    IS
        aPlsqlItem   APPS.OE_BLANKET_PUB.LINE_REC_TYPE;
    BEGIN
        aPlsqlItem.ACCOUNTING_RULE_ID          := aSqlItem.ACCOUNTING_RULE_ID;
        aPlsqlItem.AGREEMENT_ID                := aSqlItem.AGREEMENT_ID;
        aPlsqlItem.ATTRIBUTE1                  := aSqlItem.ATTRIBUTE1;
        aPlsqlItem.ATTRIBUTE10                 := aSqlItem.ATTRIBUTE10;
        aPlsqlItem.ATTRIBUTE11                 := aSqlItem.ATTRIBUTE11;
        aPlsqlItem.ATTRIBUTE12                 := aSqlItem.ATTRIBUTE12;
        aPlsqlItem.ATTRIBUTE13                 := aSqlItem.ATTRIBUTE13;
        aPlsqlItem.ATTRIBUTE14                 := aSqlItem.ATTRIBUTE14;
        aPlsqlItem.ATTRIBUTE15                 := aSqlItem.ATTRIBUTE15;
        aPlsqlItem.ATTRIBUTE16                 := aSqlItem.ATTRIBUTE16;
        aPlsqlItem.ATTRIBUTE17                 := aSqlItem.ATTRIBUTE17;
        aPlsqlItem.ATTRIBUTE18                 := aSqlItem.ATTRIBUTE18;
        aPlsqlItem.ATTRIBUTE19                 := aSqlItem.ATTRIBUTE19;
        aPlsqlItem.ATTRIBUTE20                 := aSqlItem.ATTRIBUTE20;
        aPlsqlItem.ATTRIBUTE2                  := aSqlItem.ATTRIBUTE2;
        aPlsqlItem.ATTRIBUTE3                  := aSqlItem.ATTRIBUTE3;
        aPlsqlItem.ATTRIBUTE4                  := aSqlItem.ATTRIBUTE4;
        aPlsqlItem.ATTRIBUTE5                  := aSqlItem.ATTRIBUTE5;
        aPlsqlItem.ATTRIBUTE6                  := aSqlItem.ATTRIBUTE6;
        aPlsqlItem.ATTRIBUTE7                  := aSqlItem.ATTRIBUTE7;
        aPlsqlItem.ATTRIBUTE8                  := aSqlItem.ATTRIBUTE8;
        aPlsqlItem.ATTRIBUTE9                  := aSqlItem.ATTRIBUTE9;
        aPlsqlItem.CONTEXT                     := aSqlItem.CONTEXT;
        aPlsqlItem.CREATED_BY                  := aSqlItem.CREATED_BY;
        aPlsqlItem.CREATION_DATE               := aSqlItem.CREATION_DATE;
        aPlsqlItem.CUST_PO_NUMBER              := aSqlItem.CUST_PO_NUMBER;
        aPlsqlItem.DELIVER_TO_ORG_ID           := aSqlItem.DELIVER_TO_ORG_ID;
        aPlsqlItem.FREIGHT_TERMS_CODE          := aSqlItem.FREIGHT_TERMS_CODE;
        aPlsqlItem.GLOBAL_ATTRIBUTE_CATEGORY   :=
            aSqlItem.GLOBAL_ATTRIBUTE_CATEGORY;
        aPlsqlItem.HEADER_ID                   := aSqlItem.HEADER_ID;
        aPlsqlItem.INVENTORY_ITEM_ID           := aSqlItem.INVENTORY_ITEM_ID;
        aPlsqlItem.INVOICE_TO_ORG_ID           := aSqlItem.INVOICE_TO_ORG_ID;
        aPlsqlItem.INVOICING_RULE_ID           := aSqlItem.INVOICING_RULE_ID;
        aPlsqlItem.ORDERED_ITEM                := aSqlItem.ORDERED_ITEM;
        aPlsqlItem.ORDERED_ITEM_ID             := aSqlItem.ORDERED_ITEM_ID;
        aPlsqlItem.LAST_UPDATED_BY             := aSqlItem.LAST_UPDATED_BY;
        aPlsqlItem.LAST_UPDATE_DATE            := aSqlItem.LAST_UPDATE_DATE;
        aPlsqlItem.LAST_UPDATE_LOGIN           := aSqlItem.LAST_UPDATE_LOGIN;
        aPlsqlItem.LINE_TYPE_ID                := aSqlItem.LINE_TYPE_ID;
        aPlsqlItem.LINE_ID                     := aSqlItem.LINE_ID;
        aPlsqlItem.LINE_NUMBER                 := aSqlItem.LINE_NUMBER;
        aPlsqlItem.ORDER_NUMBER                := aSqlItem.ORDER_NUMBER;
        aPlsqlItem.ORDER_QUANTITY_UOM          := aSqlItem.ORDER_QUANTITY_UOM;
        aPlsqlItem.ORG_ID                      := aSqlItem.ORG_ID;
        aPlsqlItem.PAYMENT_TERM_ID             := aSqlItem.PAYMENT_TERM_ID;
        aPlsqlItem.PREFERRED_GRADE             := aSqlItem.PREFERRED_GRADE;
        aPlsqlItem.PRICE_LIST_ID               := aSqlItem.PRICE_LIST_ID;
        aPlsqlItem.REQUEST_ID                  := aSqlItem.REQUEST_ID;
        aPlsqlItem.PROGRAM_ID                  := aSqlItem.PROGRAM_ID;
        aPlsqlItem.PROGRAM_APPLICATION_ID      :=
            aSqlItem.PROGRAM_APPLICATION_ID;
        aPlsqlItem.PROGRAM_UPDATE_DATE         :=
            aSqlItem.PROGRAM_UPDATE_DATE;
        aPlsqlItem.SHIPPING_METHOD_CODE        :=
            aSqlItem.SHIPPING_METHOD_CODE;
        aPlsqlItem.SHIP_FROM_ORG_ID            := aSqlItem.SHIP_FROM_ORG_ID;
        aPlsqlItem.SHIP_TO_ORG_ID              := aSqlItem.SHIP_TO_ORG_ID;
        aPlsqlItem.SOLD_TO_ORG_ID              := aSqlItem.SOLD_TO_ORG_ID;
        aPlsqlItem.RETURN_STATUS               := aSqlItem.RETURN_STATUS;
        aPlsqlItem.DB_FLAG                     := aSqlItem.DB_FLAG;
        aPlsqlItem.OPERATION                   := aSqlItem.OPERATION;
        aPlsqlItem.ITEM_IDENTIFIER_TYPE        :=
            aSqlItem.ITEM_IDENTIFIER_TYPE;
        aPlsqlItem.ITEM_TYPE_CODE              := aSqlItem.ITEM_TYPE_CODE;
        aPlsqlItem.SHIPPING_INSTRUCTIONS       :=
            aSqlItem.SHIPPING_INSTRUCTIONS;
        aPlsqlItem.PACKING_INSTRUCTIONS        :=
            aSqlItem.PACKING_INSTRUCTIONS;
        aPlsqlItem.SALESREP_ID                 := aSqlItem.SALESREP_ID;
        aPlsqlItem.UNIT_LIST_PRICE             := aSqlItem.UNIT_LIST_PRICE;
        aPlsqlItem.PRICING_UOM                 := aSqlItem.PRICING_UOM;
        aPlsqlItem.LOCK_CONTROL                := aSqlItem.LOCK_CONTROL;
        aPlsqlItem.ENFORCE_PRICE_LIST_FLAG     :=
            aSqlItem.ENFORCE_PRICE_LIST_FLAG;
        aPlsqlItem.ENFORCE_SHIP_TO_FLAG        :=
            aSqlItem.ENFORCE_SHIP_TO_FLAG;
        aPlsqlItem.ENFORCE_INVOICE_TO_FLAG     :=
            aSqlItem.ENFORCE_INVOICE_TO_FLAG;
        aPlsqlItem.ENFORCE_FREIGHT_TERM_FLAG   :=
            aSqlItem.ENFORCE_FREIGHT_TERM_FLAG;
        aPlsqlItem.ENFORCE_SHIPPING_METHOD_FLAG   :=
            aSqlItem.ENFORCE_SHIPPING_METHOD_FLAG;
        aPlsqlItem.ENFORCE_PAYMENT_TERM_FLAG   :=
            aSqlItem.ENFORCE_PAYMENT_TERM_FLAG;
        aPlsqlItem.ENFORCE_ACCOUNTING_RULE_FLAG   :=
            aSqlItem.ENFORCE_ACCOUNTING_RULE_FLAG;
        aPlsqlItem.ENFORCE_INVOICING_RULE_FLAG   :=
            aSqlItem.ENFORCE_INVOICING_RULE_FLAG;
        aPlsqlItem.OVERRIDE_BLANKET_CONTROLS_FLAG   :=
            aSqlItem.OVERRIDE_BLANKET_CONTROLS_FLAG;
        aPlsqlItem.OVERRIDE_RELEASE_CONTROLS_FLAG   :=
            aSqlItem.OVERRIDE_RELEASE_CONTROLS_FLAG;
        aPlsqlItem.QP_LIST_LINE_ID             :=
            aSqlItem.QP_LIST_LINE_ID;
        aPlsqlItem.FULFILLED_QUANTITY          :=
            aSqlItem.FULFILLED_QUANTITY;
        aPlsqlItem.BLANKET_MIN_QUANTITY        :=
            aSqlItem.BLANKET_MIN_QUANTITY;
        aPlsqlItem.BLANKET_MAX_QUANTITY        :=
            aSqlItem.BLANKET_MAX_QUANTITY;
        aPlsqlItem.BLANKET_MIN_AMOUNT          :=
            aSqlItem.BLANKET_MIN_AMOUNT;
        aPlsqlItem.BLANKET_MAX_AMOUNT          :=
            aSqlItem.BLANKET_MAX_AMOUNT;
        aPlsqlItem.MIN_RELEASE_QUANTITY        :=
            aSqlItem.MIN_RELEASE_QUANTITY;
        aPlsqlItem.MAX_RELEASE_QUANTITY        :=
            aSqlItem.MAX_RELEASE_QUANTITY;
        aPlsqlItem.MIN_RELEASE_AMOUNT          :=
            aSqlItem.MIN_RELEASE_AMOUNT;
        aPlsqlItem.MAX_RELEASE_AMOUNT          :=
            aSqlItem.MAX_RELEASE_AMOUNT;
        aPlsqlItem.RELEASED_AMOUNT             :=
            aSqlItem.RELEASED_AMOUNT;
        aPlsqlItem.FULFILLED_AMOUNT            :=
            aSqlItem.FULFILLED_AMOUNT;
        aPlsqlItem.RELEASED_QUANTITY           :=
            aSqlItem.RELEASED_QUANTITY;
        aPlsqlItem.RETURNED_AMOUNT             :=
            aSqlItem.RETURNED_AMOUNT;
        aPlsqlItem.RETURNED_QUANTITY           :=
            aSqlItem.RETURNED_QUANTITY;
        aPlsqlItem.START_DATE_ACTIVE           :=
            aSqlItem.START_DATE_ACTIVE;
        aPlsqlItem.END_DATE_ACTIVE             :=
            aSqlItem.END_DATE_ACTIVE;
        aPlsqlItem.SOURCE_DOCUMENT_TYPE_ID     :=
            aSqlItem.SOURCE_DOCUMENT_TYPE_ID;
        aPlsqlItem.SOURCE_DOCUMENT_ID          :=
            aSqlItem.SOURCE_DOCUMENT_ID;
        aPlsqlItem.SOURCE_DOCUMENT_LINE_ID     :=
            aSqlItem.SOURCE_DOCUMENT_LINE_ID;
        aPlsqlItem.TRANSACTION_PHASE_CODE      :=
            aSqlItem.TRANSACTION_PHASE_CODE;
        aPlsqlItem.SOURCE_DOCUMENT_VERSION_NUMBER   :=
            aSqlItem.SOURCE_DOCUMENT_VERSION_NUMBER;
        aPlsqlItem.MODIFIER_LIST_LINE_ID       :=
            aSqlItem.MODIFIER_LIST_LINE_ID;
        aPlsqlItem.DISCOUNT_PERCENT            :=
            aSqlItem.DISCOUNT_PERCENT;
        aPlsqlItem.DISCOUNT_AMOUNT             :=
            aSqlItem.DISCOUNT_AMOUNT;
        aPlsqlItem.REVISION_CHANGE_COMMENTS    :=
            aSqlItem.REVISION_CHANGE_COMMENTS;
        aPlsqlItem.REVISION_CHANGE_DATE        :=
            aSqlItem.REVISION_CHANGE_DATE;
        aPlsqlItem.REVISION_CHANGE_REASON_CODE   :=
            aSqlItem.REVISION_CHANGE_REASON_CODE;
        RETURN aPlsqlItem;
    END SQL_TO_PL1;

    FUNCTION PL_TO_SQL1 (aPlsqlItem APPS.OE_BLANKET_PUB.LINE_TBL_TYPE)
        RETURN XXDO_BK_BSA_CREAX3548687X1X9
    IS
        aSqlItem   XXDO_BK_BSA_CREAX3548687X1X9;
    BEGIN
        -- initialize the table
        aSqlItem   := XXDO_BK_BSA_CREAX3548687X1X9 ();

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

    FUNCTION SQL_TO_PL0 (aSqlItem XXDO_BK_BSA_CREAX3548687X1X9)
        RETURN APPS.OE_BLANKET_PUB.LINE_TBL_TYPE
    IS
        aPlsqlItem   APPS.OE_BLANKET_PUB.LINE_TBL_TYPE;
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

    PROCEDURE xxdo_bk_bsa_create$bsa_create (P_CUST_NAME VARCHAR2, P_BRAND VARCHAR2, P_ORG_ID NUMBER, P_CUST_PO_NUMBER VARCHAR2, P_END_DATE_ACTIVE VARCHAR2, P_BSA_NAME VARCHAR2, P_REQUESTED_DATE VARCHAR2, P_ORDERED_DATE VARCHAR2, P_LINE_TBL XXDO_BK_BSA_CREAX3548687X1X9
                                             , P_RET_CODE OUT NUMBER, P_ERR_MSG OUT VARCHAR2, P_BSA_NUMBER OUT NUMBER)
    IS
        P_LINE_TBL_   APPS.OE_BLANKET_PUB.LINE_TBL_TYPE;
    BEGIN
        P_LINE_TBL_   := XXDO_BPEL_CREATEBSAWRAPPER.SQL_TO_PL0 (P_LINE_TBL);
        APPS.XXDO_BK_BSA_CREATE.BSA_CREATE (P_CUST_NAME,
                                            P_BRAND,
                                            P_ORG_ID,
                                            P_CUST_PO_NUMBER,
                                            P_END_DATE_ACTIVE,
                                            P_BSA_NAME,
                                            P_REQUESTED_DATE,
                                            P_ORDERED_DATE,
                                            P_LINE_TBL_,
                                            P_RET_CODE,
                                            P_ERR_MSG,
                                            P_BSA_NUMBER);
    END xxdo_bk_bsa_create$bsa_create;
END XXDO_BPEL_CREATEBSAWRAPPER;
/


--
-- XXDO_BPEL_CREATEBSAWRAPPER  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_BPEL_CREATEBSAWRAPPER FOR APPS.XXDO_BPEL_CREATEBSAWRAPPER
/


GRANT EXECUTE ON APPS.XXDO_BPEL_CREATEBSAWRAPPER TO SOA_INT
/
