--
-- XXD_GL_MANUAL_REFUNDS_INT_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_MANUAL_REFUNDS_INT_T
(
  RECORD_ID                      NUMBER,
  DATA_TYPE                      VARCHAR2(100 BYTE),
  LEDGER_ID                      NUMBER,
  LEDGER_NAME                    VARCHAR2(30 BYTE),
  LEDGER_CURRENCY_CODE           VARCHAR2(15 BYTE),
  USER_JE_SOURCE_NAME            VARCHAR2(25 BYTE),
  USER_JE_CATEGORY_NAME          VARCHAR2(25 BYTE),
  ACCOUNTING_DATE                DATE,
  REFUND_ID                      NUMBER,
  REFUND_PG_DTL_ID               NUMBER,
  REFUND_REASON                  VARCHAR2(240 BYTE),
  PAYMENT_TENDER_TYPE            VARCHAR2(50 BYTE),
  REFUND_CURRENCY_CODE           VARCHAR2(15 BYTE),
  CURRENCY_CONVERSION_DATE       DATE,
  USER_CURRENCY_CONVERSION_TYPE  VARCHAR2(30 BYTE),
  ENTERED_CR                     NUMBER,
  ENTERED_DR                     NUMBER,
  CREDIT_CONCATENATED_SEGMENTS   VARCHAR2(207 BYTE),
  CREDIT_CCID                    NUMBER,
  DEBIT_CONCATENATED_SEGMENTS    VARCHAR2(207 BYTE),
  DEBIT_CCID                     NUMBER,
  REFERENCE10_LINE_DESCRIPTION   VARCHAR2(240 BYTE),
  REFERENCE21                    VARCHAR2(240 BYTE),
  RECORD_STATUS                  VARCHAR2(1 BYTE),
  REQUEST_ID                     NUMBER,
  CREATED_BY                     NUMBER,
  CREATION_DATE                  DATE,
  LAST_UPDATED_BY                NUMBER,
  LAST_UPDATE_DATE               DATE,
  LAST_UPDATE_LOGIN              NUMBER
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
