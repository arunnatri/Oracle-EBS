--
-- XXD_AP_IC_INV_STG  (Table) 
--
CREATE TABLE XXDO.XXD_AP_IC_INV_STG
(
  INVOICE_ID                                     NUMBER,
  INVOICE_NUMBER                                 VARCHAR2(50 BYTE),
  INVOICE_DATE                                   DATE,
  PAYMENT_DUE_DATE                               DATE,
  PAYMENT_TERM                                   VARCHAR2(240 BYTE),
  INVOICE_CURRENCY_CODE                          VARCHAR2(15 BYTE),
  DOCUMENT_TYPE                                  VARCHAR2(80 BYTE),
  ORG_ID                                         NUMBER,
  SET_OF_BOOKS_ID                                NUMBER,
  COMPANY                                        VARCHAR2(60 BYTE),
  ROUTING_CODE                                   VARCHAR2(50 BYTE),
  INVOICE_DOC_REFERENCE                          VARCHAR2(30 BYTE),
  INV_DOC_REF_DESC                               VARCHAR2(30 BYTE),
  VENDOR_NAME                                    VARCHAR2(240 BYTE),
  VENDOR_VAT_NUMBER                              VARCHAR2(50 BYTE),
  VENDOR_STREET                                  VARCHAR2(240 BYTE),
  VENDOR_POST_CODE                               VARCHAR2(240 BYTE),
  VENDOR_ADDRESS_CITY                            VARCHAR2(60 BYTE),
  VENDOR_ADDRESS_COUNTRY                         VARCHAR2(60 BYTE),
  BUYER_NAME                                     VARCHAR2(50 BYTE),
  BUYER_VAT_NUMBER                               VARCHAR2(30 BYTE),
  BUYER_ADDRESS_STREET                           VARCHAR2(240 BYTE),
  BUYER_ADDRESS_POSTAL_CODE                      VARCHAR2(30 BYTE),
  BUYER_ADDRESS_CITY                             VARCHAR2(30 BYTE),
  BUYER_ADDRESS_PROVINCE                         VARCHAR2(60 BYTE),
  BUYER_ADDRESS_COUNTRY_CODE                     VARCHAR2(60 BYTE),
  H_TOTAL_TAX_AMOUNT                             NUMBER,
  H_TOTAL_NET_AMOUNT                             NUMBER,
  H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES  NUMBER,
  H_INVOICE_TOTAL                                NUMBER,
  VAT_NET_AMOUNT                                 NUMBER,
  VAT_RATE                                       NUMBER,
  VAT_AMOUNT                                     NUMBER,
  TAX_CODE                                       VARCHAR2(150 BYTE),
  TAX_CLASSIFICATION                             VARCHAR2(60 BYTE),
  INVOICE_DESCRIPTION                            VARCHAR2(360 BYTE),
  UNIT_OF_MEASURE_CODE                           VARCHAR2(25 BYTE),
  QUANTITY_INVOICED                              NUMBER,
  UNIT_PRICE                                     NUMBER,
  L_TAX_RATE                                     NUMBER,
  L_TAX_EXEMPTION_CODE                           VARCHAR2(150 BYTE),
  L_NET_AMOUNT                                   NUMBER,
  H_CHARGE_AMOUNT                                NUMBER,
  H_CHARGE_DESCRIPTION                           VARCHAR2(250 BYTE),
  H_CHARGE_TAX_RATE                              NUMBER,
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
-- XXD_AP_IC_INV_STG  (Synonym) 
--
--  Dependencies: 
--   XXD_AP_IC_INV_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_AP_IC_INV_STG FOR XXDO.XXD_AP_IC_INV_STG
/
