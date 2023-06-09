--
-- XXD_AP_CONCUR_SAE_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_CONCUR_SAE_T
(
  SEQ_DB_NUM                    NUMBER,
  CREATION_DATE                 VARCHAR2(10 BYTE),
  CREATED_BY                    NUMBER,
  LAST_UPDATE_DATE              VARCHAR2(10 BYTE),
  LAST_UPDATED_BY               NUMBER,
  LAST_UPDATE_LOGIN             NUMBER,
  FILE_NAME                     VARCHAR2(500 BYTE),
  FILE_PROCESSED_DATE           VARCHAR2(10 BYTE),
  CARD_COMPANY_RECORD           VARCHAR2(1 BYTE),
  CARD_PERSONAL_RECORD          VARCHAR2(1 BYTE),
  OPP_RECORD                    VARCHAR2(1 BYTE),
  STATUS                        VARCHAR2(1 BYTE),
  AP_INVOICE_LINE_NUM           NUMBER,
  AP_INVOICE_NUM                VARCHAR2(240 BYTE),
  IDENTIFIER_SRC                VARCHAR2(7 BYTE),
  BATCH_ID                      NUMBER,
  BATCH_DATE                    VARCHAR2(10 BYTE),
  SEQ_NUM                       NUMBER,
  INV_EMP_ORG_COMPANY           VARCHAR2(48 BYTE),
  INV_EMP_NUM                   VARCHAR2(500 BYTE),
  INV_NUM                       VARCHAR2(500 BYTE),
  INV_DATE                      VARCHAR2(10 BYTE),
  INV_CURR_CODE                 VARCHAR2(3 BYTE),
  INV_PAY_CURR                  VARCHAR2(3 BYTE),
  INV_DESC                      VARCHAR2(500 BYTE),
  INV_FAPIO_RECEIVED            VARCHAR2(10 BYTE),
  INV_EXP_REP_TYPE_CC           VARCHAR2(500 BYTE),
  INV_EXP_REP_TYPE_OOP          VARCHAR2(500 BYTE),
  INV_PERSONAL_EXP_FLAG         VARCHAR2(1 BYTE),
  INV_LINE_AMT                  NUMBER,
  INV_LINE_AMT_TAX_EXC          NUMBER,
  INV_LINE_AMT_TAX_INCL         NUMBER,
  INV_LINE_DIST_COMPANY         VARCHAR2(48 BYTE),
  INV_LINE_DIST_BRAND           VARCHAR2(48 BYTE),
  INV_LINE_DIST_GEO             VARCHAR2(48 BYTE),
  INV_LINE_DIST_CHANNEL         VARCHAR2(48 BYTE),
  INV_LINE_DIST_COST_CENTER     VARCHAR2(48 BYTE),
  INV_LINE_DIST_ACCT_CODE       VARCHAR2(48 BYTE),
  INV_LINE_DIST_IC              VARCHAR2(48 BYTE),
  INV_LINE_DIST_FUTURE          VARCHAR2(48 BYTE),
  INV_LINE_EXP_TYPE_NAME        VARCHAR2(500 BYTE),
  INV_LINE_BUSS_PUR             VARCHAR2(500 BYTE),
  INV_LINE_VENDOR_DESC          VARCHAR2(500 BYTE),
  INV_LINE_CURR_CODE            VARCHAR2(3 BYTE),
  INV_LINE_DESC                 VARCHAR2(500 BYTE),
  INV_LINE_DEF_OPTION           VARCHAR2(48 BYTE),
  INV_LINE_DEF_START_DATE       VARCHAR2(48 BYTE),
  INV_LINE_DEF_END_DATE         VARCHAR2(48 BYTE),
  INV_LINE_ASSET_CAT            VARCHAR2(500 BYTE),
  INV_LINE_ASSET_LOC            VARCHAR2(500 BYTE),
  INV_LINE_ASSET_CUSTODIAN      VARCHAR2(500 BYTE),
  INV_LINE_TAX_PERCENT          VARCHAR2(48 BYTE),
  INV_LINE_PRJ_NUM              VARCHAR2(48 BYTE),
  INV_LINE_PRJ_TASK             VARCHAR2(500 BYTE),
  INV_LIN_PRJ_EXPEND_TYPE       VARCHAR2(500 BYTE),
  INV_LIN_PRJ_EXPEND_ITEM_DATE  VARCHAR2(48 BYTE),
  INV_LIN_PRJ_EXPEND_ORG        VARCHAR2(500 BYTE),
  INV_FUTURE_VALUE1             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE2             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE3             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE4             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE5             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE6             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE7             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE8             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE9             VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE10            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE11            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE12            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE13            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE14            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE15            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE16            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE17            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE18            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE19            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE20            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE21            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE22            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE23            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE24            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE25            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE26            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE27            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE28            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE29            VARCHAR2(255 BYTE),
  INV_FUTURE_VALUE30            VARCHAR2(255 BYTE),
  INV_ORG_ID                    NUMBER,
  INV_EMP_SITE                  VARCHAR2(500 BYTE),
  ERROR_MSG                     VARCHAR2(4000 BYTE),
  AP_INVOICE_ID                 NUMBER,
  PCARD_COMPANY_REC             VARCHAR2(1 BYTE),
  PCARD_PERSONAL_REC            VARCHAR2(1 BYTE),
  AP_INVOICE_LINE_ID            NUMBER,
  REQUEST_ID                    NUMBER
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
-- XXD_CONS_PK1  (Index) 
--
--  Dependencies: 
--   XXD_AP_CONCUR_SAE_T (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_CONS_PK1 ON XXDO.XXD_AP_CONCUR_SAE_T
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

ALTER TABLE XXDO.XXD_AP_CONCUR_SAE_T ADD (
  CONSTRAINT XXD_CONS_PK1
  PRIMARY KEY
  (SEQ_DB_NUM)
  USING INDEX XXDO.XXD_CONS_PK1
  ENABLE VALIDATE)
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_AP_CONCUR_SAE_T TO APPS
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_AP_CONCUR_SAE_T TO SOA_INT
/
