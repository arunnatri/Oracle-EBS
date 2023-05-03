--
-- XXD_AR_AGING_EXTRACT_T  (Table) 
--
CREATE TABLE XXDO.XXD_AR_AGING_EXTRACT_T
(
  REQUEST_ID              NUMBER,
  REPORT_LEVEL            VARCHAR2(100 BYTE),
  BRAND                   VARCHAR2(100 BYTE),
  CUSTOMER_NUMBER         VARCHAR2(100 BYTE),
  CUSTOMER_NAME           VARCHAR2(100 BYTE),
  INVOICE_NUMBER          VARCHAR2(100 BYTE),
  TYPE                    VARCHAR2(100 BYTE),
  TERM_CODE               VARCHAR2(100 BYTE),
  INVOICE_DATE            DATE,
  OUTSTANDING_AMOUNT      NUMBER,
  CREATION_DATE           DATE,
  AGING_BUCKET1           NUMBER,
  AGING_BUCKET2           NUMBER,
  AGING_BUCKET3           NUMBER,
  AGING_BUCKET4           NUMBER,
  AGING_BUCKET5           NUMBER,
  AGING_BUCKET6           NUMBER,
  AGING_BUCKET7           NUMBER,
  AGING_BUCKET8           NUMBER,
  AGING_BUCKET9           NUMBER,
  CODE_COMBINATION_ID     NUMBER,
  ENTITY_UNIQ_IDENTIFIER  VARCHAR2(100 BYTE),
  ACCOUNT_NUMBER          VARCHAR2(100 BYTE),
  KEY3                    VARCHAR2(100 BYTE),
  KEY4                    VARCHAR2(100 BYTE),
  KEY5                    VARCHAR2(100 BYTE),
  KEY6                    VARCHAR2(100 BYTE),
  KEY7                    VARCHAR2(100 BYTE),
  KEY8                    VARCHAR2(100 BYTE),
  KEY9                    VARCHAR2(100 BYTE),
  KEY10                   VARCHAR2(100 BYTE),
  PERIOD_END_DATE         DATE,
  SUBLEDR_REP_BAL         NUMBER,
  SUBLEDR_ALT_BAL         NUMBER,
  SUBLEDR_ACC_BAL         NUMBER
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
