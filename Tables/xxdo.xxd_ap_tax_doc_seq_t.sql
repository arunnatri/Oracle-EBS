--
-- XXD_AP_TAX_DOC_SEQ_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_TAX_DOC_SEQ_T
(
  INVOICE_NUM        VARCHAR2(50 BYTE),
  INVOICE_DATE       DATE,
  GL_DATE            DATE,
  INV_CREATION_DATE  DATE,
  VOUCHER_NUMBER     VARCHAR2(50 BYTE),
  GAPLESS_SEQ_NO     NUMBER,
  ACCOUNTING_PERIOD  VARCHAR2(20 BYTE),
  SORT_BY            VARCHAR2(30 BYTE),
  ACCOUNTED          VARCHAR2(10 BYTE),
  CREATED_BY         NUMBER,
  CREATION_DATE      DATE,
  REQUEST_ID         NUMBER,
  EMAIL_ADDRESS      VARCHAR2(4000 BYTE)
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