--
-- XXDO_INV_ITEM_ENBL_STG  (Table) 
--
CREATE TABLE XXDO.XXDO_INV_ITEM_ENBL_STG
(
  WAREHOUSE_CODE              VARCHAR2(10 BYTE) NOT NULL,
  ITEM_NUMBER                 VARCHAR2(30 BYTE) NOT NULL,
  HOST_DESCRIPTION            VARCHAR2(200 BYTE),
  SERIAL_CONTROL              CHAR(1 BYTE)      NOT NULL,
  UOM                         VARCHAR2(10 BYTE) NOT NULL,
  STYLE_CODE                  VARCHAR2(30 BYTE) NOT NULL,
  STYLE_NAME                  VARCHAR2(250 BYTE) NOT NULL,
  COLOR_CODE                  VARCHAR2(30 BYTE) NOT NULL,
  COLOR_NAME                  VARCHAR2(250 BYTE) NOT NULL,
  SIZE_CODE                   VARCHAR2(30 BYTE) NOT NULL,
  SIZE_NAME                   VARCHAR2(250 BYTE),
  UPC                         VARCHAR2(30 BYTE),
  EACH_WEIGHT                 FLOAT(126)        NOT NULL,
  EACH_LENGTH                 FLOAT(126)        NOT NULL,
  EACH_WIDTH                  FLOAT(126)        NOT NULL,
  EACH_HEIGHT                 FLOAT(126)        NOT NULL,
  BRAND_CODE                  VARCHAR2(100 BYTE),
  COO                         VARCHAR2(2 BYTE),
  INVENTORY_TYPE              VARCHAR2(30 BYTE),
  SHELF_LIFE                  INTEGER,
  ALT_ITEM_NUMBER             VARCHAR2(30 BYTE),
  GENDER                      VARCHAR2(40 BYTE),
  PRODUCT_CLASS               VARCHAR2(40 BYTE),
  PRODUCT_CATEGORY            VARCHAR2(40 BYTE),
  HOST_STATUS                 VARCHAR2(20 BYTE),
  INTRO_SEASON                VARCHAR2(20 BYTE),
  LAST_ACTIVE_SEASON          VARCHAR2(20 BYTE),
  PROCESS_STATUS              VARCHAR2(20 BYTE),
  ERROR_MESSAGE               VARCHAR2(1000 BYTE),
  REQUEST_ID                  NUMBER,
  CREATION_DATE               DATE              DEFAULT SYSDATE               NOT NULL,
  CREATED_BY                  NUMBER            DEFAULT -1                    NOT NULL,
  LAST_UPDATE_DATE            DATE              DEFAULT SYSDATE               NOT NULL,
  LAST_UPDATED_BY             NUMBER            DEFAULT -1                    NOT NULL,
  LAST_UPDATE_LOGIN           NUMBER            DEFAULT -1                    NOT NULL,
  BATCH_ID                    NUMBER,
  INVENTORY_ITEM_ID           NUMBER,
  SUMMARY_FLAG                VARCHAR2(1 BYTE),
  ENABLED_FLAG                VARCHAR2(1 BYTE),
  PURCHASING_ITEM_FLAG        VARCHAR2(1 BYTE),
  SALES_ACCOUNT               NUMBER,
  COST_OF_SALES_ACCOUNT       NUMBER,
  SOURCE                      VARCHAR2(20 BYTE) DEFAULT 'EBS',
  DESTINATION                 VARCHAR2(20 BYTE) DEFAULT 'WMS',
  ATTRIBUTE1                  VARCHAR2(50 BYTE),
  ATTRIBUTE2                  VARCHAR2(50 BYTE),
  ATTRIBUTE3                  VARCHAR2(50 BYTE),
  ATTRIBUTE4                  VARCHAR2(50 BYTE),
  ATTRIBUTE5                  VARCHAR2(50 BYTE),
  ATTRIBUTE6                  VARCHAR2(50 BYTE),
  ATTRIBUTE7                  VARCHAR2(50 BYTE),
  ATTRIBUTE8                  VARCHAR2(50 BYTE),
  ATTRIBUTE9                  VARCHAR2(50 BYTE),
  ATTRIBUTE10                 VARCHAR2(50 BYTE),
  ATTRIBUTE11                 VARCHAR2(50 BYTE),
  ATTRIBUTE12                 VARCHAR2(50 BYTE),
  ATTRIBUTE13                 VARCHAR2(50 BYTE),
  ATTRIBUTE14                 VARCHAR2(50 BYTE),
  ATTRIBUTE15                 VARCHAR2(50 BYTE),
  ATTRIBUTE16                 VARCHAR2(50 BYTE),
  ATTRIBUTE17                 VARCHAR2(50 BYTE),
  ATTRIBUTE18                 VARCHAR2(50 BYTE),
  ATTRIBUTE19                 VARCHAR2(50 BYTE),
  ATTRIBUTE20                 VARCHAR2(50 BYTE),
  RECORD_TYPE                 VARCHAR2(20 BYTE),
  DEST_WH_CODE                VARCHAR2(3 BYTE),
  DEST_WH_ID                  NUMBER,
  EXPENSE_ACCOUNT             NUMBER,
  LIST_PRICE_PER_UNIT         NUMBER,
  PLANNER_CODE                VARCHAR2(25 BYTE),
  BUYER_CODE                  VARCHAR2(25 BYTE),
  FLR_ITEM_TEMPLATE           VARCHAR2(240 BYTE),
  PROD_ITEM_TEMPLATE          VARCHAR2(240 BYTE),
  PREPROCESSING_LEAD_TIME     NUMBER,
  FULL_LEAD_TIME              NUMBER,
  POSTPROCESSING_LEAD_TIME    NUMBER,
  CUMULATIVE_TOTAL_LEAD_TIME  NUMBER,
  PROD_LINE_CATEGORY_ID       NUMBER,
  TARRIF_CODE_CATEGORY_ID     NUMBER
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


--
-- XXDO_INV_ITEM_ENBL_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_ITEM_ENBL_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_ITEM_ENBL_STG FOR XXDO.XXDO_INV_ITEM_ENBL_STG
/
