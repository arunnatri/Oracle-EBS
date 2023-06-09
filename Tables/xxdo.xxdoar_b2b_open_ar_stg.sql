--
-- XXDOAR_B2B_OPEN_AR_STG  (Table) 
--
CREATE TABLE XXDO.XXDOAR_B2B_OPEN_AR_STG
(
  INVOICE_NUMBER               VARCHAR2(30 BYTE),
  INVOICE_AMOUNT               NUMBER,
  OPEN_AMOUNT                  NUMBER,
  DISCOUNT_AMOUNT              NUMBER,
  FREIGHT_AMOUNT               NUMBER,
  TAX_AMOUNT                   NUMBER,
  INVOICE_DATE                 DATE,
  PO_NUMBER                    VARCHAR2(50 BYTE),
  STATEMENT_NUMBER             VARCHAR2(50 BYTE),
  STATEMENT_AMOUNT             NUMBER,
  NONBRAND_CUSTOMER_NUMBER     VARCHAR2(30 BYTE),
  BILL_TO_CUSTOMER_NUMBER      VARCHAR2(30 BYTE),
  BILL_TO_CUSTOMER_NAME        VARCHAR2(360 BYTE),
  BILL_TO_ADDRESS1             VARCHAR2(240 BYTE),
  BILL_TO_ADDRESS2             VARCHAR2(240 BYTE),
  BILL_TO_ADDRESS3             VARCHAR2(240 BYTE),
  BILL_TO_ADDRESS4             VARCHAR2(240 BYTE),
  BILL_TO_CITY                 VARCHAR2(60 BYTE),
  BILL_TO_STATE_OR_PROV        VARCHAR2(60 BYTE),
  BILL_TO_ZIP_CODE             VARCHAR2(60 BYTE),
  BILL_TO_COUNTRY              VARCHAR2(50 BYTE),
  DISCOUNTED_AMOUNT            NUMBER,
  DOCUMENT_TYPE                VARCHAR2(50 BYTE),
  SALES_ORDER_NUMBER           VARCHAR2(240 BYTE),
  BILL_OF_LADING               VARCHAR2(50 BYTE),
  BUYING_AGENT_GROUP_NUM       VARCHAR2(120 BYTE),
  BUYING_MEMBERSHIP_NUM        VARCHAR2(120 BYTE),
  OPERATING_UNIT               VARCHAR2(240 BYTE),
  SHIP_TO_CUSTOMER_NUMBER      VARCHAR2(30 BYTE),
  SHIP_TO_CUSTOMER_NAME        VARCHAR2(360 BYTE),
  SHIP_TO_ADDRESS1             VARCHAR2(240 BYTE),
  SHIP_TO_ADDRESS2             VARCHAR2(240 BYTE),
  SHIP_TO_ADDRESS3             VARCHAR2(240 BYTE),
  SHIP_TO_ADDRESS4             VARCHAR2(240 BYTE),
  SHIP_TO_CITY                 VARCHAR2(60 BYTE),
  SHIP_TO_STATE_OR_PROV        VARCHAR2(60 BYTE),
  SHIP_TO_ZIP_CODE             VARCHAR2(60 BYTE),
  SHIP_TO_COUNTRY              VARCHAR2(50 BYTE),
  INVOICE_CURRENCY_CODE        VARCHAR2(10 BYTE),
  PAYMENT_TERM                 VARCHAR2(15 BYTE),
  CONSOLIDATED_INVOICE_NUMBER  VARCHAR2(50 BYTE),
  RECORD_IDENTIFIER            VARCHAR2(50 BYTE),
  PROCESS_FLAG                 VARCHAR2(1 BYTE),
  ERROR_MESSAGE                VARCHAR2(4000 BYTE),
  FILE_DATE_TIME               VARCHAR2(30 BYTE),
  CREATION_DATE                DATE,
  CREATED_BY                   NUMBER,
  LAST_UPDATE_DATE             DATE,
  LAST_UPDATED_BY              NUMBER,
  REQUEST_ID                   NUMBER,
  ORG_ID                       NUMBER,
  CUSTOMER_TRX_ID              NUMBER,
  CUST_TRX_TYPE_ID             NUMBER,
  CASH_RECEIPT_ID              NUMBER,
  BILL_TO_CUSTOMER_ID          NUMBER,
  BILL_TO_SITE_USE_ID          NUMBER,
  SHIP_TO_SITE_USE_ID          NUMBER,
  PAYMENT_TERM_ID              NUMBER,
  REPROCESS_FLAG               VARCHAR2(1 BYTE)
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
-- XXDOAR_B2B_OPEN_AR_STG_N1  (Index) 
--
--  Dependencies: 
--   XXDOAR_B2B_OPEN_AR_STG (Table)
--
CREATE INDEX XXDO.XXDOAR_B2B_OPEN_AR_STG_N1 ON XXDO.XXDOAR_B2B_OPEN_AR_STG
(REQUEST_ID, PROCESS_FLAG)
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

--
-- XXDOAR_B2B_OPEN_AR_STG  (Synonym) 
--
--  Dependencies: 
--   XXDOAR_B2B_OPEN_AR_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOAR_B2B_OPEN_AR_STG FOR XXDO.XXDOAR_B2B_OPEN_AR_STG
/


--
-- XXDOAR_B2B_OPEN_AR_STG  (Synonym) 
--
--  Dependencies: 
--   XXDOAR_B2B_OPEN_AR_STG (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXDOAR_B2B_OPEN_AR_STG FOR XXDO.XXDOAR_B2B_OPEN_AR_STG
/
