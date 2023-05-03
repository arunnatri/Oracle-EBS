--
-- XXD_AP_DEF_EXT_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_DEF_EXT_T
(
  REQUEST_ID              NUMBER,
  OU_NAME                 VARCHAR2(240 BYTE),
  INVOICE_NUM             VARCHAR2(100 BYTE),
  INVOICE_CURR_CODE       VARCHAR2(10 BYTE),
  INVOICE_DATE            DATE,
  VENDOR_NAME             VARCHAR2(240 BYTE),
  VENDOR_SITE_CODE        VARCHAR2(240 BYTE),
  CHARGE_ACCOUNT          VARCHAR2(240 BYTE),
  DISTRIBUTION_AMOUNT     NUMBER,
  LINE_AMOUNT             NUMBER,
  ACCOUNTING_DATE         DATE,
  DEFERRED_ACCTG_FLAG     VARCHAR2(50 BYTE),
  DEF_ACCTG_START_DATE    DATE,
  DEF_ACCTG_END_DATE      DATE,
  ENTERED_AMOUNT          NUMBER,
  ACCOUNTED_AMOUNT        NUMBER,
  DR_SEGMENT1             VARCHAR2(100 BYTE),
  DR_SEGMENT2             VARCHAR2(100 BYTE),
  DR_SEGMENT3             VARCHAR2(100 BYTE),
  DR_SEGMENT4             VARCHAR2(100 BYTE),
  DR_SEGMENT5             VARCHAR2(100 BYTE),
  DR_SEGMENT6             VARCHAR2(100 BYTE),
  DR_SEGMENT7             VARCHAR2(100 BYTE),
  DR_SEGMENT8             VARCHAR2(100 BYTE),
  ENTERED_DR              NUMBER,
  CR_SEGMENT1             VARCHAR2(100 BYTE),
  CR_SEGMENT2             VARCHAR2(100 BYTE),
  CR_SEGMENT3             VARCHAR2(100 BYTE),
  CR_SEGMENT4             VARCHAR2(100 BYTE),
  CR_SEGMENT5             VARCHAR2(100 BYTE),
  CR_SEGMENT6             VARCHAR2(100 BYTE),
  CR_SEGMENT7             VARCHAR2(100 BYTE),
  CR_SEGMENT8             VARCHAR2(100 BYTE),
  ENTERED_CR              NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
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
  ENTITY_UNIQ_IDENTIFIER  VARCHAR2(50 BYTE),
  ACCOUNT_NUMBER          VARCHAR2(50 BYTE),
  LAST_UPDATED_BY         NUMBER
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_AP_DEF_EXT_T TO APPS
/