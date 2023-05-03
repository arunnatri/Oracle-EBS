--
-- XXD_AP_AGING_EXTRACT_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_AGING_EXTRACT_T
(
  VENDOR_NUMBER             VARCHAR2(20 BYTE),
  VENDOR_NAME               VARCHAR2(240 BYTE),
  INVOICE_NUMBER            VARCHAR2(100 BYTE),
  INVOICE_DATE              VARCHAR2(20 BYTE),
  ACCOUNTED                 VARCHAR2(15 BYTE),
  CURRENCY                  VARCHAR2(10 BYTE),
  ENTERED_AMOUNT            NUMBER,
  AMOUNT_REMAINING          NUMBER,
  CURRENT_BUCKET            NUMBER,
  BUCKET1                   NUMBER,
  BUCKET2                   NUMBER,
  BUCKET3                   NUMBER,
  BUCKET4                   NUMBER,
  ENTITY_UNIQUE_IDENTIFIER  VARCHAR2(10 BYTE),
  ACCOUNT_NUMBER            VARCHAR2(10 BYTE),
  KEY3                      VARCHAR2(10 BYTE),
  KEY4                      VARCHAR2(10 BYTE),
  KEY5                      VARCHAR2(10 BYTE),
  KEY6                      VARCHAR2(10 BYTE),
  KEY7                      VARCHAR2(10 BYTE),
  KEY8                      VARCHAR2(10 BYTE),
  KEY9                      VARCHAR2(10 BYTE),
  KEY10                     VARCHAR2(10 BYTE),
  PERIOD_END_DATE           VARCHAR2(20 BYTE),
  SUBLEDGER_REP_BAL         NUMBER,
  SUBLEDGER_ALT_BAL         NUMBER,
  SUBLEDGER_ACC_BAL         NUMBER,
  CREATED_BY                NUMBER,
  CREATION_DATE             DATE,
  LAST_UPDATED_BY           NUMBER,
  LAST_UPDATE_DATE          DATE,
  REQUEST_ID                NUMBER,
  EXCHANGE_RATE             NUMBER,
  INVOICE_TYPE              VARCHAR2(20 BYTE),
  DUE_DAYS                  NUMBER,
  CITY                      VARCHAR2(50 BYTE),
  STATE                     VARCHAR2(50 BYTE),
  VENDOR_STATE              VARCHAR2(50 BYTE),
  ORG_ID                    NUMBER
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
