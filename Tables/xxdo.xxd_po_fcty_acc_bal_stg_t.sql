--
-- XXD_PO_FCTY_ACC_BAL_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_FCTY_ACC_BAL_STG_T
(
  BUYER_NAME                VARCHAR2(240 BYTE),
  BUYER_COUNTRY             VARCHAR2(240 BYTE),
  SELLER_NAME               VARCHAR2(240 BYTE),
  INVOICE_NUMBER            VARCHAR2(240 BYTE),
  PAYMENT_INITIATION_TYPE   VARCHAR2(240 BYTE),
  INVOICE_ISSUE_DATE        VARCHAR2(240 BYTE),
  INVOICE_STATUS            VARCHAR2(240 BYTE),
  PO_NUMBER                 VARCHAR2(240 BYTE),
  BRAND                     VARCHAR2(240 BYTE),
  INVOICE_TOTAL_QTY         VARCHAR2(240 BYTE),
  INVOICE_AMOUNT            VARCHAR2(240 BYTE),
  POD_COMPLIANCE_DATE       VARCHAR2(240 BYTE),
  INCOSAT_DATE              VARCHAR2(240 BYTE),
  DESTINATION_NAME          VARCHAR2(240 BYTE),
  DESTINATION_COUNTRY       VARCHAR2(240 BYTE),
  ESTIMATED_DEPARTURE_DATE  VARCHAR2(240 BYTE),
  ESTIMATED_ARRIVAL_DATE    VARCHAR2(240 BYTE),
  FUTURE_ATTR1              VARCHAR2(240 BYTE),
  FUTURE_ATTR2              VARCHAR2(240 BYTE),
  FUTURE_ATTR3              VARCHAR2(240 BYTE),
  FUTURE_ATTR4              VARCHAR2(240 BYTE),
  FUTURE_ATTR5              VARCHAR2(240 BYTE),
  FUTURE_ATTR6              VARCHAR2(240 BYTE),
  FUTURE_ATTR7              VARCHAR2(240 BYTE),
  FUTURE_ATTR8              VARCHAR2(240 BYTE),
  FUTURE_ATTR9              VARCHAR2(240 BYTE),
  FUTURE_ATTR10             VARCHAR2(240 BYTE),
  CREATED_BY                NUMBER,
  CREATION_DATE             DATE,
  LAST_UPDATE_DATE          DATE,
  LAST_UPDATED_BY           NUMBER,
  REQUEST_ID                NUMBER,
  ENTITY_UNIQ_IDENTIFIER    VARCHAR2(50 BYTE),
  ACCOUNT_NUMBER            VARCHAR2(50 BYTE),
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
  FILE_NAME                 VARCHAR2(240 BYTE)
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
-- XXD_PO_FCTY_ACC_BAL_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_FCTY_ACC_BAL_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_FCTY_ACC_BAL_STG_T FOR XXDO.XXD_PO_FCTY_ACC_BAL_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_PO_FCTY_ACC_BAL_STG_T TO APPS
/
