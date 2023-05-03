--
-- XXD_ONT_AUTO_ATP_ORDRS_BKP_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_AUTO_ATP_ORDRS_BKP_T
(
  BATCH_ID                NUMBER,
  SEQ_NUMBER              NUMBER,
  LINE_SEQ_NUMBER         NUMBER,
  INVENTORY_ITEM_ID       NUMBER,
  ITEM_NUMBER             VARCHAR2(100 BYTE),
  BRAND                   VARCHAR2(100 BYTE),
  HEADER_ID               NUMBER,
  LINE_ID                 NUMBER,
  LINE_NUM                VARCHAR2(100 BYTE),
  ATP_POSTIVE_DATE        DATE,
  SOLD_TO_ORG_ID          NUMBER,
  ACCOUNT_NUMBER          VARCHAR2(100 BYTE),
  ORG_ID                  NUMBER,
  SHIP_FROM_ORG_ID        NUMBER,
  WAREHOUSE               VARCHAR2(100 BYTE),
  ORDER_TYPE              VARCHAR2(100 BYTE),
  ORDERED_QUANTITY        NUMBER,
  ORDER_CREATION_DATE     DATE,
  REQUEST_DATE            DATE,
  ORDERED_DATE            DATE,
  SCHEDULE_SHIP_DATE      DATE,
  LATEST_ACCEPTABLE_DATE  DATE,
  CANCEL_DATE             DATE,
  BULK_IDENTIFIER         VARCHAR2(240 BYTE),
  OVERRIDE_ATP_FLAG       VARCHAR2(10 BYTE),
  ORDER_QUANTITY_UOM      VARCHAR2(10 BYTE),
  SAFE_MOVE_DAYS          NUMBER,
  ATRISK_MOVE_DAYS        NUMBER,
  NEW_SSD                 DATE,
  NEW_LAD                 DATE,
  RUNNING_TOTAL_SEQ       NUMBER,
  SF_EL_FLAG              VARCHAR2(10 BYTE),
  SF_EX_FLAG              VARCHAR2(10 BYTE),
  AR_EL_FLAG              VARCHAR2(10 BYTE),
  AR_EX_FLAG              VARCHAR2(10 BYTE),
  UN_EL_FLAG              VARCHAR2(10 BYTE),
  UN_EX_FLAG              VARCHAR2(10 BYTE),
  SPLIT_CASE              VARCHAR2(10 BYTE),
  PROCESS_STATUS          VARCHAR2(100 BYTE),
  ERROR_MESSAGE           VARCHAR2(3000 BYTE),
  REQUEST_ID              NUMBER,
  CHILD_REQ_ID            NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  DEMAND_CLASS_CODE       VARCHAR2(100 BYTE),
  ORDER_SPLIT_TYPE        VARCHAR2(100 BYTE),
  SPLIT_QTY               NUMBER
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