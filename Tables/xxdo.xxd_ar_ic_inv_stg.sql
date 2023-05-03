--
-- XXD_AR_IC_INV_STG  (Table) 
--
CREATE TABLE XXDO.XXD_AR_IC_INV_STG
(
  INVOICE_ID                                     NUMBER,
  INVOICE_NUMBER                                 VARCHAR2(50 BYTE),
  INVOICE_DATE                                   DATE,
  PAYMENT_DUE_DATE                               DATE,
  PAYMENT_TERM                                   VARCHAR2(240 BYTE),
  INVOICE_CURRENCY_CODE                          VARCHAR2(15 BYTE),
  DOCUMENT_TYPE                                  VARCHAR2(80 BYTE),
  DUTY_STAMP                                     VARCHAR2(60 BYTE),
  ORG_ID                                         NUMBER,
  SET_OF_BOOKS_ID                                NUMBER,
  COMPANY                                        VARCHAR2(60 BYTE),
  ROUTING_CODE                                   VARCHAR2(50 BYTE),
  INVOICE_DOC_REFERENCE                          VARCHAR2(30 BYTE),
  INV_DOC_REF_DESC                               VARCHAR2(30 BYTE),
  LEGAL_ENTITY_NAME                              VARCHAR2(240 BYTE),
  LEGAL_ENTITY_ADDRESS_STREET                    VARCHAR2(50 BYTE),
  LEGAL_ENTITY_ADDRESS_POSTAL_CODE               VARCHAR2(240 BYTE),
  LEGAL_ENTITY_ADDRESS_CITY                      VARCHAR2(240 BYTE),
  LEGAL_ENTITY_ADDRESS_PROVINCE                  VARCHAR2(60 BYTE),
  LEGAL_ENTITY_COUNTRY                           VARCHAR2(60 BYTE),
  LEGAL_ENTITY_COUNTRY_CODE                      VARCHAR2(60 BYTE),
  LE_VAT_NUMBER                                  VARCHAR2(60 BYTE),
  LE_REGISTRIATION_NUMBER                        VARCHAR2(60 BYTE),
  PROVINCE_REG_OFFICE                            VARCHAR2(60 BYTE),
  COMPANY_REG_NUMBER                             VARCHAR2(60 BYTE),
  SHARE_CAPITAL                                  VARCHAR2(60 BYTE),
  STATUS_SHAREHOLDERS                            VARCHAR2(60 BYTE),
  LIQUIDATION_STATUS                             VARCHAR2(60 BYTE),
  BUYER_NAME                                     VARCHAR2(50 BYTE),
  BUYER_VAT_NUMBER                               VARCHAR2(30 BYTE),
  BUYER_ADDRESS_STREET                           VARCHAR2(240 BYTE),
  BUYER_ADDRESS_POSTAL_CODE                      VARCHAR2(30 BYTE),
  BUYER_ADDRESS_CITY                             VARCHAR2(30 BYTE),
  BUYER_ADDRESS_PROVINCE                         VARCHAR2(60 BYTE),
  BUYER_ADDRESS_COUNTRY                          VARCHAR2(60 BYTE),
  BUYER_ADDRESS_COUNTRY_CODE                     VARCHAR2(60 BYTE),
  BUYER_BUSINESS_REGISTRATION_NUMBER             VARCHAR2(30 BYTE),
  H_TOTAL_TAX_AMOUNT                             NUMBER,
  H_TOTAL_NET_AMOUNT                             NUMBER,
  H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES  NUMBER,
  H_INVOICE_TOTAL                                NUMBER,
  VAT_NET_AMOUNT                                 NUMBER,
  VAT_RATE                                       NUMBER,
  VAT_AMOUNT                                     NUMBER,
  TAX_CODE                                       VARCHAR2(150 BYTE),
  TAX_EXEMPTION_DESCRIPTION                      VARCHAR2(4000 BYTE),
  INVOICE_DESCRIPTION                            VARCHAR2(240 BYTE),
  UNIT_OF_MEASURE_CODE                           VARCHAR2(25 BYTE),
  QUANTITY_INVOICED                              NUMBER,
  UNIT_PRICE                                     NUMBER,
  L_VAT_AMOUNT                                   NUMBER,
  L_TAX_RATE                                     NUMBER,
  L_TAX_EXEMPTION_CODE                           VARCHAR2(150 BYTE),
  L_NET_AMOUNT                                   NUMBER,
  H_DISCOUNT_AMOUNT                              NUMBER,
  H_DISCOUNT_DESCRIPTION                         VARCHAR2(150 BYTE),
  H_DISCOUNT_TAX_RATE                            NUMBER,
  H_CHARGE_AMOUNT                                NUMBER,
  H_CHARGE_DESCRIPTION                           VARCHAR2(250 BYTE),
  H_CHARGE_TAX_RATE                              NUMBER,
  L_DISCOUNT_AMOUNT                              NUMBER,
  L_DISCOUNT_DESCRIPTION                         VARCHAR2(150 BYTE),
  L_CHARGE_AMOUNT                                NUMBER,
  L_CHARGE_DESCRIPTION                           VARCHAR2(150 BYTE),
  L_DESCRIPTION_GOODS                            VARCHAR2(150 BYTE),
  EXCHANGE_RATE                                  NUMBER,
  EXCHANGE_DATE                                  DATE,
  ORIGINAL_CURRENCY_CODE                         VARCHAR2(30 BYTE),
  CREATED_BY                                     NUMBER,
  CREATION_DATE                                  DATE,
  LAST_UPDATED_BY                                NUMBER,
  LAST_UPDATE_DATE                               DATE,
  LAST_UPDATE_LOGIN                              NUMBER,
  CONC_REQUEST_ID                                NUMBER,
  PROCESS_FLAG                                   VARCHAR2(10 BYTE),
  REPROCESS_FLAG                                 VARCHAR2(10 BYTE),
  EXTRACT_FLAG                                   VARCHAR2(10 BYTE),
  EXTRACT_DATE                                   DATE,
  ERROR_CODE                                     VARCHAR2(4000 BYTE),
  FILE_NAME                                      VARCHAR2(250 BYTE)
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
-- XXD_AR_IC_INV_STG  (Synonym) 
--
--  Dependencies: 
--   XXD_AR_IC_INV_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_AR_IC_INV_STG FOR XXDO.XXD_AR_IC_INV_STG
/
