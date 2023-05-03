--
-- XXD_AP_CONCUR_SAE_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_CONCUR_SAE_STG_T
(
  FILE_NAME                       VARCHAR2(500 BYTE),
  FILE_PROCESSED_DATE             VARCHAR2(10 BYTE),
  IDENTIFIER_SRC                  VARCHAR2(500 BYTE),
  BATCH_ID                        NUMBER,
  BATCH_DATE                      VARCHAR2(10 BYTE),
  CREATED_BY                      NUMBER,
  CREATION_DATE                   DATE,
  LAST_UPDATE_BY                  NUMBER,
  LAST_UPDATED_DATE               DATE,
  LAST_UPDATE_LOGIN               NUMBER,
  STATUS                          VARCHAR2(10 BYTE),
  ERROR_MSG                       VARCHAR2(4000 BYTE),
  SEQ_NUM                         NUMBER,
  INV_EMP_ORG_COMPANY             VARCHAR2(240 BYTE),
  INV_EXP_REP_TYPE_CC             VARCHAR2(500 BYTE),
  INV_EXP_REP_TYPE_OOP            VARCHAR2(500 BYTE),
  INV_PERSONAL_EXP_FLAG           VARCHAR2(1 BYTE),
  OPERATING_UNIT                  VARCHAR2(500 BYTE),
  INVOICE_TYPE                    VARCHAR2(100 BYTE),
  VENDOR_NAME                     VARCHAR2(500 BYTE),
  VENDOR_NUM                      VARCHAR2(500 BYTE),
  SUPPLIER_SITE                   VARCHAR2(500 BYTE),
  INV_DATE                        VARCHAR2(10 BYTE),
  INV_NUM                         VARCHAR2(500 BYTE),
  INV_CURR_CODE                   VARCHAR2(100 BYTE),
  INV_AMT                         NUMBER,
  INV_DESC                        VARCHAR2(500 BYTE),
  INV_GL_DATE                     VARCHAR2(10 BYTE),
  INV_PAY_CURR                    VARCHAR2(100 BYTE),
  INV_TERMS                       VARCHAR2(100 BYTE),
  INV_PAY_METHOD                  VARCHAR2(100 BYTE),
  INV_PAY_GROUP                   VARCHAR2(100 BYTE),
  INV_LINE_NUM                    NUMBER,
  INV_LINE_TYPE                   VARCHAR2(100 BYTE),
  INV_LINE_AMT                    NUMBER,
  INV_LINE_DESC                   VARCHAR2(500 BYTE),
  INV_LINE_COMPANY                VARCHAR2(100 BYTE),
  INV_LINE_BRAND                  VARCHAR2(100 BYTE),
  INV_LINE_GEO                    VARCHAR2(100 BYTE),
  INV_LINE_CHANNEL                VARCHAR2(100 BYTE),
  INV_LINE_COST_CENTER            VARCHAR2(100 BYTE),
  INV_LINE_ACCT_CODE              VARCHAR2(100 BYTE),
  INV_LINE_IC                     VARCHAR2(100 BYTE),
  INV_LINE_FUTURE                 VARCHAR2(100 BYTE),
  INV_LINE_DIST_ACCOUNT           VARCHAR2(100 BYTE),
  INV_LINE_DEF_OPTION             VARCHAR2(10 BYTE),
  INV_LINE_DEF_START_DATE         VARCHAR2(10 BYTE),
  INV_LINE_DEF_END_DATE           VARCHAR2(10 BYTE),
  INV_LINE_TRACK_ASSET            VARCHAR2(10 BYTE),
  INV_LINE_ASSET_BOOK             VARCHAR2(500 BYTE),
  INV_LINE_ASSET_CAT              VARCHAR2(500 BYTE),
  INV_LINE_ASSET_LOC              VARCHAR2(500 BYTE),
  INV_LINE_ASST_CUST              VARCHAR2(500 BYTE),
  INV_LINE_TAX_PERCENT            VARCHAR2(100 BYTE),
  INV_LINE_TAX_CODE               VARCHAR2(100 BYTE),
  INV_LINE_SHIP_TO                VARCHAR2(500 BYTE),
  INV_LINE_PROJ_NUM               VARCHAR2(100 BYTE),
  INV_LINE_PROJ_TASK              VARCHAR2(500 BYTE),
  INV_LINE_PROJ_EXP_DATE          VARCHAR2(10 BYTE),
  INV_LINE_PROJ_EXP_TYPE          VARCHAR2(500 BYTE),
  INV_LINE_PROJ_EXP_ORG           VARCHAR2(500 BYTE),
  INV_LINE_INTERCO_EXP_ACCT       VARCHAR2(100 BYTE),
  OU_ID                           NUMBER,
  INVOICE_TYPE_CODE               VARCHAR2(100 BYTE),
  VENDOR_ID                       NUMBER,
  VENDOR_SITE_ID                  NUMBER,
  INV_TERM_ID                     NUMBER,
  INV_LINE_DIST_CCID              NUMBER,
  INV_LINE_CAT_ID                 NUMBER,
  INV_LINE_ASSET_LOC_ID           NUMBER,
  INV_LINE_TAX                    VARCHAR2(100 BYTE),
  INV_LINE_SHIP_TO_LOC_ID         NUMBER,
  INV_LINE_PROJ_ID                NUMBER,
  INV_LINE_PROJ_TASK_ID           NUMBER,
  INV_LINE_PROJ_EXP_ORG_ID        NUMBER,
  INV_LINE_INTERCO_EXP_ACCT_CCID  NUMBER,
  SEQ_DB_NUM                      NUMBER,
  INV_MERCH_STATE                 VARCHAR2(500 BYTE),
  INV_MERCH_CITY                  VARCHAR2(500 BYTE),
  INV_MERCH_NAME                  VARCHAR2(500 BYTE),
  INV_PAY_TYPE_CODE               VARCHAR2(500 BYTE),
  INV_CARD_PROG_CODE              VARCHAR2(500 BYTE),
  PCARD_COMPANY_REC               VARCHAR2(1 BYTE),
  PCARD_PERSONAL_REC              VARCHAR2(1 BYTE),
  OOP_REC                         VARCHAR2(1 BYTE),
  CCARD_PERSONAL_REC              VARCHAR2(1 BYTE),
  CCARD_COMPANY_REC               VARCHAR2(1 BYTE),
  GROUP_BY_TYPE                   VARCHAR2(10 BYTE),
  GROUP_BY_TYPE_FLAG              VARCHAR2(1 BYTE),
  CONS_TAX_RATE                   VARCHAR2(10 BYTE),
  CONS_TAX_RATE_FLAG              VARCHAR2(1 BYTE),
  MOD_INV_NUM                     VARCHAR2(500 BYTE),
  EMP_NUM                         VARCHAR2(500 BYTE),
  HEADER_INTERFACED               VARCHAR2(20 BYTE),
  LINE_INTERFACED                 VARCHAR2(20 BYTE),
  TEMP_INV_ID                     NUMBER,
  TEMP_INV_LINE_ID                NUMBER,
  LINE_CREATED                    VARCHAR2(1 BYTE),
  INV_CREATED                     VARCHAR2(1 BYTE),
  INVOICE_ID                      NUMBER,
  INVOICE_LINE_ID                 NUMBER,
  INV_FLAG_VALID                  VARCHAR2(1 BYTE),
  PROCESS_MSG                     VARCHAR2(4000 BYTE),
  DATA_MSG                        VARCHAR2(4000 BYTE),
  INV_LINE_DEF_FLAG               VARCHAR2(1 BYTE),
  INV_LINE_DEF_ST_DATE            VARCHAR2(10 BYTE),
  INV_LINE_DEF_ED_DATE            VARCHAR2(10 BYTE),
  AP_INVOICE_LINE_ID              NUMBER,
  REQUEST_ID                      NUMBER,
  INV_LINE_EXP_DATE               VARCHAR2(10 BYTE),
  INVOICE_DATE                    VARCHAR2(10 BYTE),
  CREDIT_CARD_ACC_NUM             VARCHAR2(255 BYTE),
  FAPIO_NUMBER                    VARCHAR2(255 BYTE),
  FINAL_MATCH_VALUE_REC           VARCHAR2(100 BYTE),
  FINAL_MATCH_RESULT_REC          VARCHAR2(500 BYTE),
  EXT_BANK_ACCOUNT_ID             NUMBER,
  EXT_BANK_ACCOUNT_NUM            VARCHAR2(100 BYTE)
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
-- XXD_CONS_PK2  (Index) 
--
--  Dependencies: 
--   XXD_AP_CONCUR_SAE_STG_T (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_CONS_PK2 ON XXDO.XXD_AP_CONCUR_SAE_STG_T
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

ALTER TABLE XXDO.XXD_AP_CONCUR_SAE_STG_T ADD (
  CONSTRAINT XXD_CONS_PK2
  PRIMARY KEY
  (SEQ_DB_NUM)
  USING INDEX XXDO.XXD_CONS_PK2
  ENABLE VALIDATE)
/


--
-- XXD_AP_CONCUR_INV_IDX  (Index) 
--
--  Dependencies: 
--   XXD_AP_CONCUR_SAE_STG_T (Table)
--
CREATE INDEX XXDO.XXD_AP_CONCUR_INV_IDX ON XXDO.XXD_AP_CONCUR_SAE_STG_T
(TEMP_INV_ID, TEMP_INV_LINE_ID)
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

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_AP_CONCUR_SAE_STG_T TO APPS
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_AP_CONCUR_SAE_STG_T TO SOA_INT
/
