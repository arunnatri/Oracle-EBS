--
-- XXD_AR_TRX_HDR_STG  (Table) 
--
CREATE TABLE XXDO.XXD_AR_TRX_HDR_STG
(
  INVOICE_ID                                     NUMBER,
  INVOICE_NUMBER                                 VARCHAR2(30 BYTE),
  INVOICE_DATE                                   DATE,
  PAYMENT_DUE_DATE                               DATE,
  PAYMENT_TERM                                   VARCHAR2(240 BYTE),
  INVOICE_CURRENCY_CODE                          VARCHAR2(15 BYTE),
  TRANSACTION_TYPE                               VARCHAR2(150 BYTE),
  ORG_ID                                         NUMBER,
  SET_OF_BOOKS_ID                                NUMBER,
  DUTY_STAMP                                     VARCHAR2(30 BYTE),
  DOCUMENT_TYPE                                  VARCHAR2(80 BYTE),
  LEGAL_ENTITY_NAME                              VARCHAR2(240 BYTE),
  LEGAL_ENTITY_ADDRESS_STREET                    VARCHAR2(240 BYTE),
  LEGAL_ENTITY_ADDRESS_POSTAL_CODE               VARCHAR2(10 BYTE),
  LEGAL_ENTITY_ADDRESS_CITY                      VARCHAR2(60 BYTE),
  LEGAL_ENTITY_ADDRESS_PROVINCE                  VARCHAR2(60 BYTE),
  LEGAL_ENTITY_COUNTRY                           VARCHAR2(60 BYTE),
  LEGAL_ENTITY_COUNTRY_CODE                      VARCHAR2(60 BYTE),
  LE_VAT_NUMBER                                  VARCHAR2(50 BYTE),
  LE_REGISTRIATION_NUMBER                        VARCHAR2(50 BYTE),
  SELLER_CONTACT_TEL                             VARCHAR2(240 BYTE),
  SELLER_CONTACT_FAX                             VARCHAR2(240 BYTE),
  SELLER_CONTACT_EMAIL                           VARCHAR2(240 BYTE),
  BANK_ACCOUNT_NUM                               VARCHAR2(240 BYTE),
  BANK_SWFIT_BIC                                 VARCHAR2(240 BYTE),
  BANK_IBAN                                      VARCHAR2(240 BYTE),
  PROVINCE_REG_OFFICE                            VARCHAR2(50 BYTE),
  COMPANY_REG_NUMBER                             VARCHAR2(50 BYTE),
  SHARE_CAPITAL                                  VARCHAR2(50 BYTE),
  STATUS_SHAREHOLDERS                            VARCHAR2(50 BYTE),
  LIQUIDATION_STATUS                             VARCHAR2(50 BYTE),
  BILL_TO_CUSTOMER_NUM                           VARCHAR2(60 BYTE),
  BILL_TO_CUSTOMER_NAME                          VARCHAR2(240 BYTE),
  BILL_TO_ADDRESS_STREET                         VARCHAR2(240 BYTE),
  BILL_TO_ADDRESS_POSTAL_CODE                    VARCHAR2(30 BYTE),
  BILL_TO_ADDRESS_CITY                           VARCHAR2(30 BYTE),
  BILL_TO_ADDRESS_PROVINCE                       VARCHAR2(30 BYTE),
  BILL_TO_ADDRESS_COUNTRY                        VARCHAR2(60 BYTE),
  BILL_TO_ADDRESS_COUNTRY_CODE                   VARCHAR2(60 BYTE),
  BILL_TO_VAT_NUMBER                             VARCHAR2(30 BYTE),
  BILL_TO_BUSINESS_REGISTRATION_NUMBER           VARCHAR2(30 BYTE),
  BILL_TO_UNIQUE_RECIPIENT_IDENTIFIER            VARCHAR2(240 BYTE),
  BILL_TO_ROUTING_CODE                           VARCHAR2(30 BYTE),
  BILL_TO_EMAIL                                  VARCHAR2(240 BYTE),
  BILL_TO_TELPHONE                               VARCHAR2(240 BYTE),
  PRINTING_PENDING                               VARCHAR2(10 BYTE),
  H_TOTAL_TAX_AMOUNT                             NUMBER,
  H_TOTAL_NET_AMOUNT                             NUMBER,
  H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES  NUMBER,
  H_INVOICE_TOTAL                                NUMBER,
  H_ROUNDING_AMT                                 NUMBER,
  TAX_CHG_CODE                                   VARCHAR2(150 BYTE),
  H_DISCOUNT_AMOUNT                              NUMBER,
  H_DISCOUNT_DESCRIPTION                         VARCHAR2(150 BYTE),
  H_DISCOUNT_TAX_RATE                            NUMBER,
  H_CHARGE_AMOUNT                                NUMBER,
  H_CHARGE_DESCRIPTION                           VARCHAR2(150 BYTE),
  H_CHARGE_TAX_RATE                              NUMBER,
  INVOICE_DOC_REFERENCE                          VARCHAR2(150 BYTE),
  INV_DOC_REF_DESC                               VARCHAR2(150 BYTE),
  H_TENDER_REF                                   VARCHAR2(150 BYTE),
  H_PROJECT_REF                                  VARCHAR2(150 BYTE),
  H_CUST_PO                                      VARCHAR2(150 BYTE),
  H_SALES_ORDER                                  VARCHAR2(150 BYTE),
  H_INCO_TERM                                    VARCHAR2(150 BYTE),
  H_DELIVERY_NUM                                 VARCHAR2(150 BYTE),
  CUST_ACCT_NUM                                  VARCHAR2(150 BYTE),
  CREATED_BY                                     NUMBER,
  CREATION_DATE                                  DATE,
  LAST_UPDATED_BY                                NUMBER,
  LAST_UPDATE_DATE                               DATE,
  LAST_UPDATE_LOGIN                              NUMBER,
  CONC_REQUEST_ID                                NUMBER,
  PROCESS_FLAG                                   VARCHAR2(10 BYTE),
  REPROCESS_FLAG                                 VARCHAR2(10 BYTE),
  SEND_TO_PGR                                    VARCHAR2(10 BYTE),
  EXTRACT_FLAG                                   VARCHAR2(10 BYTE),
  EXTRACT_DATE                                   DATE,
  ERROR_CODE                                     VARCHAR2(250 BYTE)
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
-- XXD_AR_TRX_HDR_STG  (Synonym) 
--
--  Dependencies: 
--   XXD_AR_TRX_HDR_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_AR_TRX_HDR_STG FOR XXDO.XXD_AR_TRX_HDR_STG
/
