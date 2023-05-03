--
-- XXD_GL_JE_RET_IC_ONHAND_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_T
(
  STORE_NUMBER           NUMBER,
  STORE_NAME             VARCHAR2(240 BYTE),
  STORE_TYPE             VARCHAR2(1 BYTE),
  STORE_CURRENCY         VARCHAR2(15 BYTE),
  ITEM_ID                NUMBER,
  ITEM_NUMBER            VARCHAR2(40 BYTE),
  SOH_DATE_TS            DATE,
  ONHAND_QTY             NUMBER,
  IN_TRANSIT_QTY         NUMBER,
  STOCK_ONHAND           NUMBER,
  STOCK_AVG_COST         NUMBER,
  TOTAL_STOCK_COST       NUMBER,
  OH_MRGN_CST_LOCAL      NUMBER,
  OH_MRGN_CST_USD        NUMBER,
  OH_MRGN_VALUE_LOCAL    NUMBER,
  OH_MRGN_VALUE_USD      NUMBER,
  OH_MARKUP_LOCAL        NUMBER,
  OH_MARKUP_USD          NUMBER,
  OH_LEDGER_CURRENCY     VARCHAR2(15 BYTE),
  OH_JOURNAL_CURRENCY    VARCHAR2(3 BYTE),
  MARKUP_TYPE            VARCHAR2(20 BYTE),
  BRAND                  VARCHAR2(40 BYTE),
  STYLE                  VARCHAR2(150 BYTE),
  COLOR                  VARCHAR2(150 BYTE),
  ITEM_SIZE              VARCHAR2(240 BYTE),
  ITEM_TYPE              VARCHAR2(240 BYTE),
  MASTER_STYLE           VARCHAR2(40 BYTE),
  STYLE_DESC             VARCHAR2(40 BYTE),
  ITEM_DESC              VARCHAR2(240 BYTE),
  DEPARTMENT             VARCHAR2(40 BYTE),
  MASTER_CLASS           VARCHAR2(40 BYTE),
  SUB_CLASS              VARCHAR2(40 BYTE),
  DIVISION               VARCHAR2(40 BYTE),
  INTRO_SEASON           VARCHAR2(240 BYTE),
  CURRENT_SEASON         VARCHAR2(240 BYTE),
  OH_COMPANY             VARCHAR2(50 BYTE),
  OH_DR_BRAND            VARCHAR2(50 BYTE),
  OH_DR_GEO              VARCHAR2(50 BYTE),
  OH_DR_CHANNEL          VARCHAR2(50 BYTE),
  OH_DR_ACCOUNT          VARCHAR2(50 BYTE),
  OH_DR_DEPT             VARCHAR2(50 BYTE),
  OH_DR_INTERCOM         VARCHAR2(50 BYTE),
  OH_CR_BRAND            VARCHAR2(50 BYTE),
  OH_CR_GEO              VARCHAR2(50 BYTE),
  OH_CR_CHANNEL          VARCHAR2(50 BYTE),
  OH_CR_ACCOUNT          VARCHAR2(50 BYTE),
  OH_CR_DEPT             VARCHAR2(50 BYTE),
  OH_CR_INTERCOM         VARCHAR2(50 BYTE),
  OH_DEBIT_CODE_COMB     VARCHAR2(50 BYTE),
  OH_CREDIT_CODE_COMB    VARCHAR2(50 BYTE),
  LEDGER_ID              NUMBER,
  LEDGER_NAME            VARCHAR2(30 BYTE),
  OU_ID                  NUMBER,
  OPERATING_UNIT         NUMBER,
  INV_ORG_ID             NUMBER,
  INV_ORG_NAME           VARCHAR2(50 BYTE),
  SHIP_INV_ORG_ID        NUMBER,
  USER_JE_SOURCE_NAME    VARCHAR2(25 BYTE),
  USER_JE_CATEGORY_NAME  VARCHAR2(25 BYTE),
  JOURNAL_BATCH_NAME     VARCHAR2(240 BYTE),
  JOURNAL_NAME           VARCHAR2(240 BYTE),
  RECORD_STATUS          VARCHAR2(1 BYTE),
  ERROR_MSG              VARCHAR2(4000 BYTE),
  REQUEST_ID             NUMBER,
  CHILD_REQUEST_IDS      VARCHAR2(1000 BYTE),
  AS_OF_DATE             DATE,
  ATTRIBUTE1             VARCHAR2(240 BYTE),
  ATTRIBUTE2             VARCHAR2(240 BYTE),
  ATTRIBUTE3             VARCHAR2(240 BYTE),
  ATTRIBUTE4             VARCHAR2(240 BYTE),
  ATTRIBUTE5             VARCHAR2(240 BYTE),
  CREATED_BY             NUMBER,
  CREATION_DATE          DATE,
  LAST_UPDATED_BY        NUMBER,
  LAST_UPDATE_DATE       DATE,
  LAST_UPDATE_LOGIN      NUMBER,
  OH_USDVAL              NUMBER,
  OH_LOCALVAL            NUMBER,
  LAST_UPDATE_TS         DATE
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
-- XXD_GL_JE_RET_IC_ONHAND_STG_N1  (Index) 
--
--  Dependencies: 
--   XXD_GL_JE_RET_IC_ONHAND_STG_T (Table)
--
CREATE INDEX XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_N1 ON XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_T
(STORE_NUMBER)
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
-- XXD_GL_JE_RET_IC_ONHAND_STG_N2  (Index) 
--
--  Dependencies: 
--   XXD_GL_JE_RET_IC_ONHAND_STG_T (Table)
--
CREATE INDEX XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_N2 ON XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_T
(ITEM_ID)
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
-- XXD_GL_JE_RET_IC_ONHAND_STG_N3  (Index) 
--
--  Dependencies: 
--   XXD_GL_JE_RET_IC_ONHAND_STG_T (Table)
--
CREATE INDEX XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_N3 ON XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_T
(RECORD_STATUS)
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
-- XXD_GL_JE_RET_IC_ONHAND_STG_N4  (Index) 
--
--  Dependencies: 
--   XXD_GL_JE_RET_IC_ONHAND_STG_T (Table)
--
CREATE INDEX XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_N4 ON XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_T
(ITEM_ID, STORE_NUMBER)
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
-- XXD_GL_JE_RET_IC_ONHAND_STG_N5  (Index) 
--
--  Dependencies: 
--   XXD_GL_JE_RET_IC_ONHAND_STG_T (Table)
--
CREATE INDEX XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_N5 ON XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_T
(STORE_NUMBER, RECORD_STATUS)
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
-- XXD_GL_JE_RET_IC_ONHAND_STG_N6  (Index) 
--
--  Dependencies: 
--   XXD_GL_JE_RET_IC_ONHAND_STG_T (Table)
--
CREATE INDEX XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_N6 ON XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_T
(MARKUP_TYPE, OPERATING_UNIT)
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
-- XXD_GL_JE_RET_IC_ONHAND_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_JE_RET_IC_ONHAND_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_JE_RET_IC_ONHAND_STG_T FOR XXDO.XXD_GL_JE_RET_IC_ONHAND_STG_T
/
