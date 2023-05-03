--
-- XXD_WMS_RET_INV_VAL_STG_BL_T  (Table) 
--
CREATE TABLE XXDO.XXD_WMS_RET_INV_VAL_STG_BL_T
(
  SEQ_ID                    NUMBER,
  MONTH_YEAR                VARCHAR2(10 BYTE),
  SOH_DATE                  DATE,
  OPERATING_UNIT_ID         NUMBER,
  OPERATING_UNIT_NAME       VARCHAR2(120 BYTE),
  ORG_UNIT_DESC_RMS         VARCHAR2(120 BYTE),
  ORG_UNIT_ID_RMS           NUMBER,
  STORE_NUMBER              NUMBER,
  STORE_NAME                VARCHAR2(150 BYTE),
  STORE_TYPE                VARCHAR2(30 BYTE),
  STORE_CURRENCY            VARCHAR2(3 BYTE),
  BRAND                     VARCHAR2(30 BYTE),
  STYLE                     VARCHAR2(30 BYTE),
  COLOR_ID                  VARCHAR2(30 BYTE),
  COLOR                     VARCHAR2(30 BYTE),
  STYLE_COLOR               VARCHAR2(60 BYTE),
  SKU                       VARCHAR2(60 BYTE),
  INVENTORY_ITEM_ID         NUMBER,
  CLASS_NAME                VARCHAR2(120 BYTE),
  STOCK_ON_HAND             NUMBER(12,4),
  EXTENDED_COST_AMOUNT      NUMBER(20,4),
  UNIT_COST                 NUMBER(20,4),
  AVG_MARGIN_STORE_CURR     NUMBER(20,4),
  IC_MARGIN_STORE_CURR      NUMBER(20,4),
  AVG_MARGIN_USD            NUMBER(20,4),
  IC_MARGIN_USD             NUMBER(20,4),
  CREATION_DATE             DATE,
  CREATED_BY                NUMBER,
  LAST_UPDATE_DATE          DATE,
  LAST_UPDATED_BY           NUMBER,
  REQUEST_ID                NUMBER              NOT NULL,
  LAST_UPDATE_LOGIN         NUMBER,
  KEY3                      VARCHAR2(50 BYTE),
  KEY4                      VARCHAR2(50 BYTE),
  KEY5                      VARCHAR2(50 BYTE),
  KEY6                      VARCHAR2(50 BYTE),
  KEY7                      VARCHAR2(50 BYTE),
  KEY8                      VARCHAR2(50 BYTE),
  KEY9                      VARCHAR2(50 BYTE),
  KEY10                     VARCHAR2(50 BYTE),
  PERIOD_END_DATE           DATE,
  SUBLEDR_REP_BAL           NUMBER,
  SUBLEDR_ALT_BAL           NUMBER,
  SUBLEDR_ACC_BAL           NUMBER,
  ENTITY_UNIQ_IDENTIFIER    VARCHAR2(50 BYTE),
  ACCOUNT_NUMBER            VARCHAR2(50 BYTE),
  GL_COMPANY                VARCHAR2(10 BYTE),
  GL_BRAND                  VARCHAR2(10 BYTE),
  GL_GEO                    VARCHAR2(10 BYTE),
  GL_CHANNEL                VARCHAR2(10 BYTE),
  GL_COST_CENTER            VARCHAR2(10 BYTE),
  GL_NAT_ACC                VARCHAR2(10 BYTE),
  GL_INTERCO                VARCHAR2(10 BYTE),
  FINAL_EOH_COST            NUMBER,
  INTRANSIT_QTY             NUMBER,
  TOTAL_IC_MARGIN_USD       NUMBER,
  FUNC_CURRENCY             VARCHAR2(10 BYTE),
  FINAL_EOH_COST_FUNC_CURR  NUMBER
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
-- XXD_RET_INV_VAL_IDX  (Index) 
--
--  Dependencies: 
--   XXD_WMS_RET_INV_VAL_STG_BL_T (Table)
--
CREATE INDEX XXDO.XXD_RET_INV_VAL_IDX ON XXDO.XXD_WMS_RET_INV_VAL_STG_BL_T
(REQUEST_ID)
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
