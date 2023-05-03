--
-- XXD_ONT_SPLIT_SCH_BLK_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_SPLIT_SCH_BLK_STG_T
(
  ORG_ID                  NUMBER,
  SHIP_FROM_ORG_ID        NUMBER,
  HDR_ID                  NUMBER,
  LNE_ID                  NUMBER,
  REQUEST_ID              NUMBER,
  BRAND                   VARCHAR2(40 BYTE),
  ORDER_TYPE_ID           NUMBER,
  SOLD_TO_ORG_ID          NUMBER,
  SALES_CHANNEL_CODE      VARCHAR2(30 BYTE),
  SKU                     VARCHAR2(40 BYTE),
  INVENTORY_ITEM_ID       NUMBER,
  REQUEST_DATE            DATE,
  LATEST_ACCEPTABLE_DATE  DATE,
  SPLIT_LNE_ID            NUMBER,
  ORIGINAL_QUANTITY       NUMBER,
  NEW_QUANTITY            NUMBER,
  SPLIT_QUANTITY          NUMBER,
  SCHEDULE_SHIP_DATE      DATE,
  NEW_SSD                 DATE,
  PROCESS_MODE            VARCHAR2(30 BYTE),
  SCH_STATUS              VARCHAR2(1 BYTE),
  SCH_MESSAGE             VARCHAR2(240 BYTE),
  SPLIT_STATUS            VARCHAR2(1 BYTE),
  SPLIT_MESSAGE           VARCHAR2(240 BYTE),
  STATUS                  VARCHAR2(1 BYTE),
  MESSAGE                 VARCHAR2(240 BYTE),
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  AVAILABLE_QUANTITY      NUMBER,
  LNE_CREATION_DATE       DATE,
  DEMAND_CLASS_CODE       VARCHAR2(30 BYTE),
  ORDER_QUANTITY_UOM      VARCHAR2(3 BYTE),
  ORDER_NUMBER            NUMBER,
  LINE_NUMBER             NUMBER,
  AVAILABLE_DATE          DATE
)
TABLESPACE CUSTOM_TX_TS
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
/
