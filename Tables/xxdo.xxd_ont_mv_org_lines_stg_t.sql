--
-- XXD_ONT_MV_ORG_LINES_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_MV_ORG_LINES_STG_T
(
  BATCH_NUMBER                    NUMBER,
  RECORD_ID                       NUMBER,
  LINE_ID                         NUMBER,
  HEADER_ID                       NUMBER,
  ORDER_NUMBER                    NUMBER,
  CUST_PO_NUMBER                  VARCHAR2(300 BYTE),
  DEMAND_CLASS_CODE               VARCHAR2(150 BYTE),
  CANCEL_DATE                     VARCHAR2(40 BYTE),
  ORG_ID                          NUMBER,
  LINE_NUMBER                     NUMBER,
  ORDER_QUANTITY_UOM              VARCHAR2(10 BYTE),
  ORDERED_QUANTITY                NUMBER,
  SHIPPED_QUANTITY                NUMBER,
  CANCELLED_QUANTITY              NUMBER,
  FULFILLED_QUANTITY              NUMBER,
  ORDERED_ITEM                    VARCHAR2(150 BYTE),
  INVENTORY_ITEM_ID               NUMBER,
  ITEM_SEGMENT1                   VARCHAR2(60 BYTE),
  ITEM_SEGMENT2                   VARCHAR2(60 BYTE),
  ITEM_SEGMENT3                   VARCHAR2(60 BYTE),
  UNIT_SELLING_PRICE              NUMBER,
  UNIT_LIST_PRICE                 NUMBER,
  TAX_DATE                        DATE,
  TAX_CODE                        VARCHAR2(230 BYTE),
  TAX_RATE                        NUMBER,
  TAX_VALUE                       NUMBER,
  TAX_EXEMPT_FLAG                 VARCHAR2(1 BYTE),
  TAX_EXEMPT_NUMBER               VARCHAR2(80 BYTE),
  TAX_EXEMPT_REASON_CODE          VARCHAR2(30 BYTE),
  TAX_POINT_CODE                  VARCHAR2(30 BYTE),
  SHIPPING_METHOD_CODE            VARCHAR2(30 BYTE),
  ATTRIBUTE1                      VARCHAR2(240 BYTE),
  ATTRIBUTE2                      VARCHAR2(240 BYTE),
  ATTRIBUTE3                      VARCHAR2(240 BYTE),
  ATTRIBUTE4                      VARCHAR2(240 BYTE),
  ATTRIBUTE5                      VARCHAR2(240 BYTE),
  ATTRIBUTE6                      VARCHAR2(240 BYTE),
  ATTRIBUTE7                      VARCHAR2(240 BYTE),
  ATTRIBUTE8                      VARCHAR2(240 BYTE),
  ATTRIBUTE9                      VARCHAR2(240 BYTE),
  ATTRIBUTE10                     VARCHAR2(240 BYTE),
  ATTRIBUTE11                     VARCHAR2(240 BYTE),
  ATTRIBUTE12                     VARCHAR2(240 BYTE),
  ATTRIBUTE13                     VARCHAR2(240 BYTE),
  ATTRIBUTE14                     VARCHAR2(240 BYTE),
  ATTRIBUTE15                     VARCHAR2(240 BYTE),
  ATTRIBUTE16                     VARCHAR2(240 BYTE),
  ATTRIBUTE17                     VARCHAR2(240 BYTE),
  ATTRIBUTE18                     VARCHAR2(240 BYTE),
  ATTRIBUTE19                     VARCHAR2(240 BYTE),
  ATTRIBUTE20                     VARCHAR2(240 BYTE),
  ITEM_NUMBER                     VARCHAR2(60 BYTE),
  PROMISE_DATE                    DATE,
  ORIG_SYS_DOCUMENT_REF           VARCHAR2(240 BYTE),
  ORIGINAL_SYSTEM_LINE_REFERENCE  VARCHAR2(240 BYTE),
  SCHEDULE_SHIP_DATE              DATE,
  PRICING_DATE                    DATE,
  SHIP_TOLERANCE_ABOVE            NUMBER,
  SHIP_TOLERANCE_BELOW            NUMBER,
  FOB_POINT_CODE                  VARCHAR2(90 BYTE),
  ITEM_TYPE_CODE                  VARCHAR2(90 BYTE),
  LINE_CATEGORY_CODE              VARCHAR2(90 BYTE),
  SOURCE_TYPE_CODE                VARCHAR2(90 BYTE),
  RETURN_REASON_CODE              VARCHAR2(90 BYTE),
  OPEN_FLAG                       VARCHAR2(3 BYTE),
  BOOKED_FLAG                     VARCHAR2(3 BYTE),
  FLOW_STATUS_CODE                VARCHAR2(250 BYTE),
  CUSTOMER_LINE_NUMBER            VARCHAR2(150 BYTE),
  LINE_TYPE                       VARCHAR2(90 BYTE),
  BILL_TO_ORG_ID                  NUMBER,
  SHIP_TO_ORG_ID                  NUMBER,
  SHIP_FROM                       VARCHAR2(10 BYTE),
  NEW_SHIP_FROM                   NUMBER,
  NEW_LINE_TYPE_ID                NUMBER,
  NEW_ORDERED_QUANTITY            NUMBER,
  NEW_INVENTORY_ITEM_ID           NUMBER,
  NEW_ORG_ID                      NUMBER,
  NEW_SHIP_TO_SITE                NUMBER,
  NEW_BILL_TO_SITE                NUMBER,
  CREATED_BY                      NUMBER,
  CREATION_DATE                   DATE,
  LAST_UPDATED_BY                 NUMBER,
  LAST_UPDATE_DATE                DATE,
  REQUEST_ID                      NUMBER,
  RECORD_STATUS                   VARCHAR2(1 BYTE),
  ERROR_MESSAGE                   VARCHAR2(4000 BYTE),
  SHIPMENT_PRIORITY_CODE          VARCHAR2(240 BYTE),
  NEW_SHIP_METHOD_CODE            VARCHAR2(240 BYTE),
  REFERENCE_HEADER_ID             NUMBER,
  REFERENCE_LINE_ID               NUMBER,
  NEW_REFERENCE_HEADER_ID         NUMBER,
  NEW_REFERENCE_LINE_ID           NUMBER,
  RET_ORG_SYS_LINE_REF            VARCHAR2(250 BYTE),
  RET_ORG_SYS_DOC_REF             VARCHAR2(250 BYTE),
  LATEST_ACCEPTABLE_DATE          DATE,
  RETURN_CONTEXT                  VARCHAR2(250 BYTE),
  ACTUAL_SHIPMENT_DATE            DATE,
  OLD_INVENTORY_ITEM_ID           NUMBER,
  REQUEST_DATE                    DATE,
  SHIPPING_INSTRUCTIONS           VARCHAR2(2000 BYTE),
  FULFILLMENT_DATE                DATE,
  NEW_TAX_CODE                    VARCHAR2(230 BYTE),
  NEW_ATTRIBUTE4                  VARCHAR2(240 BYTE),
  SCHEDULE_ARRIVAL_DATE           DATE
)
TABLESPACE APPS_TS_TX_DATA
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
/


--
-- XXD_ONT_MV_ORG_LINES_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_MV_ORG_LINES_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_MV_ORG_LINES_STG_T FOR XXDO.XXD_ONT_MV_ORG_LINES_STG_T
/


--
-- XXD_ONT_MV_ORG_LINES_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_MV_ORG_LINES_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXD_ONT_MV_ORG_LINES_STG_T FOR XXDO.XXD_ONT_MV_ORG_LINES_STG_T
/
