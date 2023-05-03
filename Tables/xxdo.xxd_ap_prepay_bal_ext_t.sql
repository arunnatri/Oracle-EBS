--
-- XXD_AP_PREPAY_BAL_EXT_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_PREPAY_BAL_EXT_T
(
  REQUEST_ID                    NUMBER,
  OPERATING_UNIT                VARCHAR2(240 BYTE),
  SOURCE                        VARCHAR2(25 BYTE),
  SUPPLIER_NUMBER               VARCHAR2(30 BYTE),
  SUPPLIER_NAME                 VARCHAR2(240 BYTE),
  INVOICE_NUM                   VARCHAR2(50 BYTE),
  INVOICE_CURRENCY_CODE         VARCHAR2(15 BYTE),
  DESCRIPTION                   VARCHAR2(240 BYTE),
  INVOICE_DATE                  DATE,
  INVOICE_AMOUNT                NUMBER,
  AMOUNT_PAID                   NUMBER,
  AMOUNT_APPLIED                NUMBER,
  PREPAY_AMOUNT_REMAINING       NUMBER,
  KEY3                          VARCHAR2(50 BYTE),
  KEY4                          VARCHAR2(50 BYTE),
  KEY5                          VARCHAR2(50 BYTE),
  KEY6                          VARCHAR2(50 BYTE),
  KEY7                          VARCHAR2(50 BYTE),
  KEY8                          VARCHAR2(50 BYTE),
  KEY9                          VARCHAR2(50 BYTE),
  KEY10                         VARCHAR2(50 BYTE),
  PERIOD_END_DATE               DATE,
  SUBLEDR_REP_BAL               NUMBER,
  SUBLEDR_ALT_BAL               NUMBER,
  SUBLEDR_ACC_BAL               NUMBER,
  ENTITY_UNIQ_IDENTIFIER        VARCHAR2(50 BYTE),
  ACCOUNT_NUMBER                VARCHAR2(50 BYTE),
  CREATION_DATE                 DATE,
  CREATED_BY                    NUMBER,
  LAST_UPDATE_DATE              DATE,
  LAST_UPDATED_BY               NUMBER,
  ORIG_PREPAY_AMOUNT_REMAINING  NUMBER
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
-- XXD_AP_PREPAY_BAL_EXT_IDX  (Index) 
--
--  Dependencies: 
--   XXD_AP_PREPAY_BAL_EXT_T (Table)
--
CREATE INDEX XXDO.XXD_AP_PREPAY_BAL_EXT_IDX ON XXDO.XXD_AP_PREPAY_BAL_EXT_T
(REQUEST_ID)
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
