--
-- XXD_RMS_LMT_RET_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_RMS_LMT_RET_STG_T
(
  PORTFOLIO               VARCHAR2(240 BYTE),
  NAME                    VARCHAR2(240 BYTE),
  EFFECTIVE_DATE          VARCHAR2(100 BYTE),
  DUE_DATE                VARCHAR2(100 BYTE),
  COVERAGE_BEGIN_DATE     VARCHAR2(100 BYTE),
  COVERAGE_END_DATE       VARCHAR2(100 BYTE),
  CURRENCY_TYPE           VARCHAR2(20 BYTE),
  EXPENSE_GROUP           VARCHAR2(240 BYTE),
  EXPENSE_TYPE            VARCHAR2(240 BYTE),
  EXPENSE_CATEGORY        VARCHAR2(240 BYTE),
  AR_TRACKING             VARCHAR2(20 BYTE),
  INVOICE_AMOUNT          VARCHAR2(100 BYTE),
  VENDOR                  VARCHAR2(500 BYTE),
  APPROVAL_STATUS         VARCHAR2(50 BYTE),
  PROCESSED               VARCHAR2(10 BYTE),
  FUTURE_ATTR1            VARCHAR2(240 BYTE),
  FUTURE_ATTR2            VARCHAR2(240 BYTE),
  FUTURE_ATTR3            VARCHAR2(240 BYTE),
  FUTURE_ATTR4            VARCHAR2(240 BYTE),
  FUTURE_ATTR5            VARCHAR2(240 BYTE),
  FUTURE_ATTR6            VARCHAR2(240 BYTE),
  FUTURE_ATTR7            VARCHAR2(240 BYTE),
  FUTURE_ATTR8            VARCHAR2(240 BYTE),
  FUTURE_ATTR9            VARCHAR2(240 BYTE),
  FUTURE_ATTR10           VARCHAR2(240 BYTE),
  CREATED_BY              NUMBER,
  CREATION_DATE           DATE,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  REQUEST_ID              NUMBER,
  ENTITY_UNIQ_IDENTIFIER  VARCHAR2(50 BYTE),
  ACCOUNT_NUMBER          VARCHAR2(50 BYTE),
  KEY3                    VARCHAR2(50 BYTE),
  KEY4                    VARCHAR2(50 BYTE),
  KEY5                    VARCHAR2(50 BYTE),
  KEY6                    VARCHAR2(50 BYTE),
  KEY7                    VARCHAR2(50 BYTE),
  KEY8                    VARCHAR2(50 BYTE),
  KEY9                    VARCHAR2(50 BYTE),
  KEY10                   VARCHAR2(50 BYTE),
  PERIOD_END_DATE         DATE,
  SUBLEDR_REP_BAL         NUMBER,
  SUBLEDR_ALT_BAL         NUMBER,
  SUBLEDR_ACC_BAL         NUMBER,
  FILE_NAME               VARCHAR2(240 BYTE)
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
-- XXD_RMS_LMT_RET_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_RMS_LMT_RET_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_RMS_LMT_RET_STG_T FOR XXDO.XXD_RMS_LMT_RET_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_RMS_LMT_RET_STG_T TO APPS
/
