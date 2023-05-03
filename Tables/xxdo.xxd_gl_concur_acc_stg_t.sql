--
-- XXD_GL_CONCUR_ACC_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_CONCUR_ACC_STG_T
(
  SEQ_DB_NUM               NUMBER,
  CREATION_DATE            VARCHAR2(10 BYTE),
  CREATED_BY               NUMBER,
  LAST_UPDATE_DATE         VARCHAR2(10 BYTE),
  LAST_UPDATED_BY          NUMBER,
  LAST_UPDATE_LOGIN        NUMBER,
  FILE_NAME                VARCHAR2(500 BYTE),
  FILE_PROCESSED_DATE      VARCHAR2(10 BYTE),
  STATUS                   VARCHAR2(1 BYTE),
  JOURNAL_BATCH_ID         NUMBER,
  JOURNAL_HEADER_ID        NUMBER,
  JOURNAL_LINE_NUM         NUMBER,
  REQUEST_ID               NUMBER,
  EMP_FIRST_NAME           VARCHAR2(240 BYTE),
  EMP_LAST_NAME            VARCHAR2(240 BYTE),
  BAL_SEG                  VARCHAR2(100 BYTE),
  INTERCO_BAL_SEG          VARCHAR2(100 BYTE),
  REPORT_ID                VARCHAR2(240 BYTE),
  COMPANY_SEG              VARCHAR2(100 BYTE),
  BRAND_SEG                VARCHAR2(100 BYTE),
  GEO_SEG                  VARCHAR2(100 BYTE),
  CHANNEL_SEG              VARCHAR2(100 BYTE),
  COST_CENTER_SEG          VARCHAR2(100 BYTE),
  ACCOUNT_CODE_SEG         VARCHAR2(100 BYTE),
  INTERCOMPANY_SEG         VARCHAR2(100 BYTE),
  FUTURE_USE_SEG           VARCHAR2(100 BYTE),
  VENDOR_NAME              VARCHAR2(500 BYTE),
  VENDOR_DESC              VARCHAR2(500 BYTE),
  DESCRIPTION              VARCHAR2(500 BYTE),
  AMOUNT                   NUMBER,
  CURRENCY                 VARCHAR2(100 BYTE),
  PAID_FLAG                VARCHAR2(10 BYTE),
  LEDGER_ID                NUMBER,
  LEDGER_NAME              VARCHAR2(255 BYTE),
  LEDGER_CURRENCY          VARCHAR2(255 BYTE),
  DEBIT_CODE_COMBINATION   VARCHAR2(255 BYTE),
  DEBIT_CCID               NUMBER,
  CREDIT_CODE_COMBINATION  VARCHAR2(255 BYTE),
  CREDIT_CCID              NUMBER,
  ACCOUNTING_DATE          DATE,
  USER_JE_SOURCE_NAME      VARCHAR2(255 BYTE),
  USER_JE_CATEGORY_NAME    VARCHAR2(255 BYTE),
  JE_SOURCE_NAME           VARCHAR2(255 BYTE),
  JE_CATEGORY_NAME         VARCHAR2(255 BYTE),
  PERIOD_NAME              VARCHAR2(255 BYTE),
  PAID_FLAG_VALUE          VARCHAR2(255 BYTE),
  ERROR_MSG                VARCHAR2(4000 BYTE),
  CURRENCY_CODE            VARCHAR2(10 BYTE),
  LINE_DESC                VARCHAR2(500 BYTE),
  PROCESS_MSG              VARCHAR2(4000 BYTE),
  UPD_NATURAL_ACCOUNT      VARCHAR2(255 BYTE),
  REV_DATE                 VARCHAR2(255 BYTE),
  COMP_DEFAULT_ACCOUNT     VARCHAR2(255 BYTE),
  FUTURE_VALUE22           VARCHAR2(255 BYTE),
  FUTURE_VALUE23           VARCHAR2(255 BYTE),
  FUTURE_VALUE24           VARCHAR2(255 BYTE),
  FUTURE_VALUE25           VARCHAR2(255 BYTE),
  FUTURE_VALUE26           VARCHAR2(255 BYTE),
  FUTURE_VALUE27           VARCHAR2(255 BYTE),
  FUTURE_VALUE28           VARCHAR2(255 BYTE),
  FUTURE_VALUE29           VARCHAR2(255 BYTE),
  FUTURE_VALUE30           VARCHAR2(255 BYTE),
  PROCESS_FLAG             VARCHAR2(1 BYTE),
  REV_PERIOD_NAME          VARCHAR2(10 BYTE)
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
-- XXD_GL_CONS_PK2  (Index) 
--
--  Dependencies: 
--   XXD_GL_CONCUR_ACC_STG_T (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_GL_CONS_PK2 ON XXDO.XXD_GL_CONCUR_ACC_STG_T
(SEQ_DB_NUM)
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

ALTER TABLE XXDO.XXD_GL_CONCUR_ACC_STG_T ADD (
  CONSTRAINT XXD_GL_CONS_PK2
  PRIMARY KEY
  (SEQ_DB_NUM)
  USING INDEX XXDO.XXD_GL_CONS_PK2
  ENABLE VALIDATE)
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_GL_CONCUR_ACC_STG_T TO APPS
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_GL_CONCUR_ACC_STG_T TO SOA_INT
/
