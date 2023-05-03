--
-- XXD_AR_EXT_COLL_CUST_TRX_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_AR_EXT_COLL_CUST_TRX_STG_T
(
  CUSTOMER_TRX_ID                    NUMBER,
  UNIQUE_TRX_ID                      NUMBER,
  INVOICE_NUMBER                     VARCHAR2(50 BYTE),
  TRX_DATE                           DATE,
  DUE_DATE                           DATE,
  INVOICE_AMOUNT                     NUMBER,
  INVOICE_CURRENCY_CODE              VARCHAR2(30 BYTE),
  ORIGINAL_CURRENCY                  VARCHAR2(30 BYTE),
  BASE_CURRENCY                      VARCHAR2(30 BYTE),
  DENOMINATION_IN_BASE_CURRENCY      NUMBER,
  DENOMINATION_IN_ORIGINAL_CURRENCY  NUMBER,
  ORIG_DENOM_ORIG_CURRENCY           NUMBER,
  ORIG_DENOM_BASE_CURRENCY           NUMBER,
  CUST_TRX_TYPE_ID                   NUMBER,
  OPEN_AMOUNT                        NUMBER,
  PO_NUMBER                          VARCHAR2(60 BYTE),
  PAYMENT_TERM                       VARCHAR2(240 BYTE),
  PAYMENT_TERM_ID                    NUMBER,
  PARTY_ID                           NUMBER,
  NB_CUST_ACCOUNT_ID                 NUMBER,
  NB_CUSTOMER_NUMBER                 VARCHAR2(60 BYTE),
  NB_PARTY_NAME                      VARCHAR2(240 BYTE),
  NB_CURRENCY                        VARCHAR2(20 BYTE),
  NB_ADDRESS_LINES                   VARCHAR2(2000 BYTE),
  NB_CITY                            VARCHAR2(150 BYTE),
  NB_ZIP_CODE                        VARCHAR2(60 BYTE),
  NB_COUNTRY                         VARCHAR2(60 BYTE),
  NB_BILL_TO_SITE_USE_ID             NUMBER,
  BILL_TO_CUSTOMER_ID                NUMBER,
  BILL_TO_CUSTOMER_NUM               VARCHAR2(60 BYTE),
  BILL_TO_CUSTOMER_NAME              VARCHAR2(360 BYTE),
  BILL_TO_ADDRESS1                   VARCHAR2(240 BYTE),
  BILL_TO_ADDRESS2                   VARCHAR2(240 BYTE),
  BILL_TO_ADDRESS3                   VARCHAR2(240 BYTE),
  BILL_TO_ADDRESS4                   VARCHAR2(240 BYTE),
  BILL_TO_CITY                       VARCHAR2(60 BYTE),
  BILL_TO_STATE                      VARCHAR2(60 BYTE),
  BILL_TO_ZIP_CODE                   VARCHAR2(60 BYTE),
  BILL_TO_COUNTRY                    VARCHAR2(60 BYTE),
  DOCUMENT_TYPE                      VARCHAR2(150 BYTE),
  SO_NUMBER                          VARCHAR2(60 BYTE),
  BOL                                VARCHAR2(150 BYTE),
  DELIVERY                           VARCHAR2(60 BYTE),
  WAYBILL_NUMBER                     VARCHAR2(60 BYTE),
  DISPUTE_DATE                       DATE,
  DISPUTE_AMOUNT                     NUMBER,
  COMMENTS                           VARCHAR2(2000 BYTE),
  BRAND                              VARCHAR2(30 BYTE),
  SALES_REP                          VARCHAR2(150 BYTE),
  INTERFACE_HEADER_CONTEXT           VARCHAR2(150 BYTE),
  CLAIM_NUMBER                       VARCHAR2(150 BYTE),
  CLAIM_REASON                       VARCHAR2(150 BYTE),
  CLAIM_OWNER                        VARCHAR2(150 BYTE),
  BUYING_AGENT_GROUP_NUM             VARCHAR2(150 BYTE),
  BUYING_MEMBERSHIP_NUM              VARCHAR2(150 BYTE),
  BUYING_GROUP_VAT_NUM               VARCHAR2(150 BYTE),
  OPERATING_UNIT                     VARCHAR2(240 BYTE),
  ORG_ID                             NUMBER,
  SHIP_TO_CUSTOMER_NUM               VARCHAR2(60 BYTE),
  SHIP_TO_CUSTOMER_NAME              VARCHAR2(360 BYTE),
  SHIP_TO_ADDRESS1                   VARCHAR2(240 BYTE),
  SHIP_TO_ADDRESS2                   VARCHAR2(240 BYTE),
  SHIP_TO_ADDRESS3                   VARCHAR2(240 BYTE),
  SHIP_TO_ADDRESS4                   VARCHAR2(240 BYTE),
  SHIP_TO_CITY                       VARCHAR2(60 BYTE),
  SHIP_TO_STATE                      VARCHAR2(60 BYTE),
  SHIP_TO_ZIP_CODE                   VARCHAR2(60 BYTE),
  SHIP_TO_COUNTRY                    VARCHAR2(60 BYTE),
  BILL_TO_SITE_USE_ID                NUMBER,
  SHIP_TO_SITE_USE_ID                NUMBER,
  LANGUAGE                           VARCHAR2(60 BYTE),
  TEL                                VARCHAR2(40 BYTE),
  MOBILE_PHONE                       VARCHAR2(40 BYTE),
  FAX                                VARCHAR2(100 BYTE),
  EMAIL_ADDRESS                      VARCHAR2(360 BYTE),
  CREDIT_LIMIT                       NUMBER,
  PROFILE_CLASS                      VARCHAR2(150 BYTE),
  ULTIMATE_PARENT                    VARCHAR2(150 BYTE),
  COLLECTOR_NAME                     VARCHAR2(250 BYTE),
  RESEARCHER                         VARCHAR2(250 BYTE),
  CREDIT_ANALYST                     VARCHAR2(250 BYTE),
  PARENT_NUMBER                      VARCHAR2(150 BYTE),
  ALIAS                              VARCHAR2(240 BYTE),
  CUSTOMER_SINCE                     DATE,
  LAST_PAYMENT_PAID_ON               DATE,
  LAST_PAYMENT_DUE_ON                DATE,
  LAST_PAYMENT_AMOUNT                NUMBER,
  LAST_CREDIT_REVIEW                 DATE,
  NEXT_CREDIT_REVIEW                 DATE,
  CONC_REQUEST_ID                    NUMBER,
  CREATED_BY                         NUMBER,
  CREATION_DATE                      DATE,
  LAST_UPDATED_BY                    NUMBER,
  LAST_UPDATE_DATE                   DATE,
  FILE_NAME                          VARCHAR2(360 BYTE),
  EXTRACT_STATUS                     VARCHAR2(2 BYTE)
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
-- XXD_AR_EXT_COLL_CUST_TRX_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_AR_EXT_COLL_CUST_TRX_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_AR_EXT_COLL_CUST_TRX_STG_T FOR XXDO.XXD_AR_EXT_COLL_CUST_TRX_STG_T
/
