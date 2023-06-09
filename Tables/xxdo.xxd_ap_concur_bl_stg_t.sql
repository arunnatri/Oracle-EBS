--
-- XXD_AP_CONCUR_BL_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_CONCUR_BL_STG_T
(
  FIRST_NAME              VARCHAR2(240 BYTE),
  LAST_NAME               VARCHAR2(240 BYTE),
  GL_BAL_SEG              VARCHAR2(50 BYTE),
  GL_INTERCO_SEG          VARCHAR2(50 BYTE),
  REPORT_ID               VARCHAR2(240 BYTE),
  GL_COMPANY              VARCHAR2(50 BYTE),
  GL_BRAND                VARCHAR2(50 BYTE),
  GL_GEO                  VARCHAR2(50 BYTE),
  GL_CHANNEL              VARCHAR2(50 BYTE),
  GL_COST_CENTER          VARCHAR2(50 BYTE),
  GL_ACCOUNT_CODE         VARCHAR2(50 BYTE),
  GL_INTERCO              VARCHAR2(50 BYTE),
  GL_FUTURE               VARCHAR2(50 BYTE),
  VENDOR_NAME             VARCHAR2(240 BYTE),
  VENDOR_ALT_NAME         VARCHAR2(240 BYTE),
  VENDOR_DESC             VARCHAR2(240 BYTE),
  AMOUNT                  VARCHAR2(50 BYTE),
  CURRENCY                VARCHAR2(10 BYTE),
  TRANSACTION_DATE        VARCHAR2(50 BYTE),
  PAID_DATE               VARCHAR2(50 BYTE),
  PAID                    VARCHAR2(10 BYTE),
  STEP_ENTRY_DATE_TIME    VARCHAR2(50 BYTE),
  CUTOFF_DATE             VARCHAR2(50 BYTE),
  ACCRUAL_DATE            VARCHAR2(50 BYTE),
  PAID_FLAG               VARCHAR2(10 BYTE),
  FUTURE_COL1             VARCHAR2(240 BYTE),
  FUTURE_COL2             VARCHAR2(240 BYTE),
  FUTURE_COL3             VARCHAR2(240 BYTE),
  FUTURE_COL4             VARCHAR2(240 BYTE),
  FUTURE_COL5             VARCHAR2(240 BYTE),
  FUTURE_COL6             VARCHAR2(240 BYTE),
  FUTURE_COL7             VARCHAR2(240 BYTE),
  FUTURE_COL8             VARCHAR2(240 BYTE),
  FUTURE_COL9             VARCHAR2(240 BYTE),
  FUTURE_COL10            VARCHAR2(240 BYTE),
  CREATION_DATE           VARCHAR2(50 BYTE),
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        VARCHAR2(50 BYTE),
  LAST_UPDATED_BY         NUMBER,
  REQUEST_ID              NUMBER,
  LAST_UPDATE_LOGIN       NUMBER,
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
  FILE_NAME               VARCHAR2(240 BYTE),
  CREDIT_CC               VARCHAR2(240 BYTE),
  CREDIT_CC_PAID          VARCHAR2(240 BYTE),
  CONVERSION_RATE         NUMBER,
  ENTITY_UNIQ_IDENTIFIER  VARCHAR2(50 BYTE),
  ACCOUNT_NUMBER          VARCHAR2(50 BYTE)
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
-- XXD_AP_CONCUR_BL_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_AP_CONCUR_BL_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_AP_CONCUR_BL_STG_T FOR XXDO.XXD_AP_CONCUR_BL_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_AP_CONCUR_BL_STG_T TO APPS
/
