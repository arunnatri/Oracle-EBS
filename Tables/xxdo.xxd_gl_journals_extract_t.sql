--
-- XXD_GL_JOURNALS_EXTRACT_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_JOURNALS_EXTRACT_T
(
  CCID                        NUMBER,
  COMPANY                     VARCHAR2(240 BYTE),
  ACCOUNT                     VARCHAR2(240 BYTE),
  BRAND                       VARCHAR2(240 BYTE),
  GEO                         VARCHAR2(240 BYTE),
  CHANNEL                     VARCHAR2(240 BYTE),
  COSTCENTER                  VARCHAR2(240 BYTE),
  INTERCOMPANY                VARCHAR2(240 BYTE),
  FUTUREUSE                   VARCHAR2(240 BYTE),
  KEY9                        VARCHAR2(240 BYTE),
  KEY10                       VARCHAR2(240 BYTE),
  STATUARY_LEDGER             VARCHAR2(1 BYTE),
  UNIQUE_IDENTIFIER           VARCHAR2(240 BYTE),
  ORIGINATION_DATE            VARCHAR2(20 BYTE),
  OPEN_DATE                   VARCHAR2(20 BYTE),
  CLOSE_DATE                  VARCHAR2(20 BYTE),
  ITEM_TYPE                   VARCHAR2(50 BYTE),
  ITEM_SUB_TYPES              VARCHAR2(50 BYTE),
  ITEM_SUMMARY                VARCHAR2(50 BYTE),
  ITEM_IMPACT_CODE            VARCHAR2(50 BYTE),
  ITEM_CLASS                  VARCHAR2(50 BYTE),
  ADJUSTMENT_DESTINATION      VARCHAR2(50 BYTE),
  ITEM_EDITABLE_BY_PREPARERS  VARCHAR2(50 BYTE),
  DESCRIPTION                 VARCHAR2(4000 BYTE),
  REFERENCE                   VARCHAR2(50 BYTE),
  ITEM_TOTAL                  VARCHAR2(50 BYTE),
  REFERENCE_FIELD1            VARCHAR2(50 BYTE),
  REFERENCE_FIELD2            VARCHAR2(50 BYTE),
  REFERENCE_FIELD3            VARCHAR2(50 BYTE),
  REFERENCE_FIELD4            VARCHAR2(50 BYTE),
  REFERENCE_FIELD5            VARCHAR2(50 BYTE),
  ALTERNATE_CURRENCY_AMOUNT   NUMBER,
  REPORTING_CURRENCY_AMOUNT   NUMBER,
  GLACCOUNT_CURRENCY_AMOUNT   NUMBER,
  TRANSACT_CURRENCY_AMOUNT    NUMBER,
  ITEM_CURRENCY               VARCHAR2(10 BYTE),
  REQUEST_ID                  NUMBER,
  LAST_UPDATE_DATE            DATE,
  LAST_UPDATED_BY             NUMBER,
  CREATION_DATE               DATE,
  CREATED_BY                  NUMBER,
  PERIOD_NAME                 VARCHAR2(10 BYTE),
  LEDGER_ID                   NUMBER,
  ALT_CURRENCY                VARCHAR2(10 BYTE),
  CLOSE_METHOD                VARCHAR2(10 BYTE),
  SENT_TO_BLACKLINE           VARCHAR2(1 BYTE),
  FILE_NAME                   VARCHAR2(240 BYTE),
  REPORT_TYPE                 VARCHAR2(20 BYTE)
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
-- XXD_GL_JL_EXT_TBL_N1  (Index) 
--
--  Dependencies: 
--   XXD_GL_JOURNALS_EXTRACT_T (Table)
--
CREATE INDEX XXDO.XXD_GL_JL_EXT_TBL_N1 ON XXDO.XXD_GL_JOURNALS_EXTRACT_T
(CCID, PERIOD_NAME)
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
