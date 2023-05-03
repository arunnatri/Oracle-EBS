--
-- XXD_ONT_ADV_SALES_ORDER_INT_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_ADV_SALES_ORDER_INT_T
(
  FILE_NAME                     VARCHAR2(200 BYTE),
  ORDER_NUMBER                  NUMBER,
  LINE_NUMBER                   VARCHAR2(100 BYTE),
  ITEM                          VARCHAR2(2000 BYTE),
  SALES_REP_NAME                VARCHAR2(360 BYTE),
  SALES_CHANNEL_CODE            VARCHAR2(240 BYTE),
  ORDER_TYPE                    VARCHAR2(60 BYTE),
  ACCOUNT_NUMBER_COUNTRY_STATE  VARCHAR2(152 BYTE),
  ACCOUNT_NUMBER                VARCHAR2(30 BYTE),
  COUNTRY                       VARCHAR2(60 BYTE),
  STATE_PROVINCE                VARCHAR2(60 BYTE),
  REGION                        VARCHAR2(150 BYTE),
  SUB_REGION                    VARCHAR2(150 BYTE),
  ORDER_QUANTITY                NUMBER,
  UNIT_SELLING_PRICE            NUMBER,
  ORDER_AMOUNT                  NUMBER,
  SALES_DATE                    DATE,
  INTERFACE_TYPE                VARCHAR2(40 BYTE),
  STATUS                        VARCHAR2(100 BYTE),
  ERROR_MESSAGE                 VARCHAR2(4000 BYTE),
  ATTRIBUTE1                    VARCHAR2(240 BYTE),
  ATTRIBUTE2                    VARCHAR2(240 BYTE),
  ATTRIBUTE3                    VARCHAR2(240 BYTE),
  ATTRIBUTE4                    VARCHAR2(240 BYTE),
  ATTRIBUTE5                    VARCHAR2(240 BYTE),
  ATTRIBUTE6                    VARCHAR2(240 BYTE),
  ATTRIBUTE7                    VARCHAR2(240 BYTE),
  ATTRIBUTE8                    VARCHAR2(240 BYTE),
  ATTRIBUTE9                    VARCHAR2(240 BYTE),
  ATTRIBUTE10                   VARCHAR2(240 BYTE),
  ATTRIBUTE11                   VARCHAR2(240 BYTE),
  ATTRIBUTE12                   VARCHAR2(240 BYTE),
  ATTRIBUTE13                   VARCHAR2(240 BYTE),
  ATTRIBUTE14                   VARCHAR2(240 BYTE),
  ATTRIBUTE15                   VARCHAR2(240 BYTE),
  REQUEST_ID                    NUMBER,
  CREATION_DATE                 DATE,
  CREATED_BY                    NUMBER,
  LAST_UPDATED_BY               NUMBER,
  LAST_UPDATE_DATE              DATE,
  LAST_UPDATE_LOGIN             NUMBER,
  ORGANIZATION_CODE             VARCHAR2(10 BYTE),
  CURRENCY                      VARCHAR2(15 BYTE),
  UNIT_SELLING_PRICE_USD        NUMBER,
  AMOUNT_USD                    NUMBER,
  SCHEDULE_SHIP_DATE            DATE
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
-- XXD_ONT_ADV_SALES_ORDER_INT_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_ADV_SALES_ORDER_INT_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_ADV_SALES_ORDER_INT_N1 ON XXDO.XXD_ONT_ADV_SALES_ORDER_INT_T
(STATUS, REQUEST_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_ONT_ADV_SALES_ORDER_INT_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_ADV_SALES_ORDER_INT_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_ADV_SALES_ORDER_INT_T FOR XXDO.XXD_ONT_ADV_SALES_ORDER_INT_T
/
