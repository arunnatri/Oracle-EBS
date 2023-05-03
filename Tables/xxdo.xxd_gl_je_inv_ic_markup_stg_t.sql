--
-- XXD_GL_JE_INV_IC_MARKUP_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_JE_INV_IC_MARKUP_STG_T
(
  ORGANIZATION_NAME      VARCHAR2(240 BYTE),
  ORGANIZATION_ID        NUMBER,
  ITEM_NUMBER            VARCHAR2(40 BYTE),
  INVENTORY_ITEM_ID      NUMBER,
  ONHAND_QTY             NUMBER,
  INTRANSIT_QTY          NUMBER,
  TOTAL_QTY              NUMBER,
  AS_OF_DATE             DATE,
  ITEM_COST              NUMBER,
  MATERIAL_COST          NUMBER,
  NON_MATERIAL_COST      NUMBER,
  DUTY_RATE              NUMBER,
  DUTY                   NUMBER,
  FREIGHT_DU_COST        NUMBER,
  FREIGHT_COST           NUMBER,
  OVERHEAD_DU_COST       NUMBER,
  OH_NONDU_COST          NUMBER,
  OH_DR_COMPANY          VARCHAR2(50 BYTE),
  OH_DR_BRAND            VARCHAR2(50 BYTE),
  OH_DR_GEO              VARCHAR2(50 BYTE),
  OH_DR_CHANNEL          VARCHAR2(50 BYTE),
  OH_DR_DEPT             VARCHAR2(50 BYTE),
  OH_DR_ACCOUNT          VARCHAR2(50 BYTE),
  OH_DR_INTERCOM         VARCHAR2(50 BYTE),
  OH_DR_FUTURE           VARCHAR2(50 BYTE),
  OH_CR_COMPANY          VARCHAR2(50 BYTE),
  OH_CR_BRAND            VARCHAR2(50 BYTE),
  OH_CR_GEO              VARCHAR2(50 BYTE),
  OH_CR_CHANNEL          VARCHAR2(50 BYTE),
  OH_CR_DEPT             VARCHAR2(50 BYTE),
  OH_CR_ACCOUNT          VARCHAR2(50 BYTE),
  OH_CR_INTERCOM         VARCHAR2(50 BYTE),
  OH_CR_FUTURE           VARCHAR2(50 BYTE),
  OH_DEBIT_CODE_COMB     VARCHAR2(50 BYTE),
  OH_CREDIT_CODE_COMB    VARCHAR2(50 BYTE),
  OH_MRGN_CST_LOCAL      NUMBER,
  OH_MRGN_CST_USD        NUMBER,
  OH_MRGN_VALUE_LOCAL    NUMBER,
  OH_MRGN_VALUE_USD      NUMBER,
  OH_MARKUP_LOCAL        NUMBER,
  OH_MARKUP_USD          NUMBER,
  BRAND                  VARCHAR2(40 BYTE),
  STYLE                  VARCHAR2(150 BYTE),
  COLOR                  VARCHAR2(150 BYTE),
  ITEM_SIZE              VARCHAR2(240 BYTE),
  LEDGER_ID              NUMBER,
  LEDGER_NAME            VARCHAR2(30 BYTE),
  OU_ID                  NUMBER,
  REGION                 VARCHAR2(30 BYTE),
  INV_ORG_ID             NUMBER,
  INV_ORG_NAME           VARCHAR2(50 BYTE),
  OH_JOURNAL_CURRENCY    VARCHAR2(10 BYTE),
  ORG_CURRENCY           VARCHAR2(10 BYTE),
  LEDGER_CURRENCY        VARCHAR2(10 BYTE),
  PERIOD_NAME            VARCHAR2(10 BYTE),
  USER_JE_SOURCE_NAME    VARCHAR2(25 BYTE),
  USER_JE_CATEGORY_NAME  VARCHAR2(25 BYTE),
  JOURNAL_BATCH_NAME     VARCHAR2(240 BYTE),
  JOURNAL_NAME           VARCHAR2(240 BYTE),
  RECORD_STATUS          VARCHAR2(1 BYTE),
  ERROR_MSG              VARCHAR2(4000 BYTE),
  REQUEST_ID             NUMBER,
  ATTRIBUTE1             VARCHAR2(240 BYTE),
  ATTRIBUTE2             VARCHAR2(240 BYTE),
  ATTRIBUTE3             VARCHAR2(240 BYTE),
  ATTRIBUTE4             VARCHAR2(240 BYTE),
  ATTRIBUTE5             VARCHAR2(240 BYTE),
  CREATED_BY             NUMBER,
  CREATION_DATE          DATE,
  LAST_UPDATED_BY        NUMBER,
  LAST_UPDATE_DATE       DATE,
  LAST_UPDATE_LOGIN      NUMBER
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
-- XXD_GL_JE_INV_IC_MARKUP_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_JE_INV_IC_MARKUP_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_JE_INV_IC_MARKUP_STG_T FOR XXDO.XXD_GL_JE_INV_IC_MARKUP_STG_T
/
