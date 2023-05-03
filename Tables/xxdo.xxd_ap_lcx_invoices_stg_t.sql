--
-- XXD_AP_LCX_INVOICES_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_LCX_INVOICES_STG_T
(
  RECORD_ID                      NUMBER         NOT NULL,
  FILE_NAME                      VARCHAR2(500 BYTE),
  FILE_PROCESSED_DATE            VARCHAR2(10 BYTE),
  STATUS                         VARCHAR2(1 BYTE),
  ERROR_MSG                      VARCHAR2(4000 BYTE),
  ERROR_MSG_LINE                 VARCHAR2(4000 BYTE),
  REQUEST_ID                     NUMBER,
  TEMP_INVOICE_HDR_ID            NUMBER,
  TEMP_INVOICE_LINE_ID           NUMBER,
  PO_NUMBER_H                    VARCHAR2(20 BYTE),
  PO_HEADER_ID                   NUMBER,
  INVOICE_NUMBER                 VARCHAR2(100 BYTE),
  INVOICE_ID                     NUMBER,
  LINE_NUMBER                    NUMBER,
  OPERATING_UNIT                 VARCHAR2(240 BYTE),
  ORG_ID                         NUMBER,
  TRADING_PARTNER                VARCHAR2(250 BYTE),
  VENDOR_NUMBER                  NUMBER,
  VENDOR_ID                      NUMBER,
  SUPPLIER_NAME                  VARCHAR2(240 BYTE),
  SUPPLIER_SITE_CODE             VARCHAR2(15 BYTE),
  VENDOR_SITE_ID                 NUMBER,
  INVOICE_DATE                   DATE,
  INVOICE_AMOUNT                 NUMBER,
  CURRENCY_CODE                  VARCHAR2(15 BYTE),
  INVOICE_DESCRIPTION            VARCHAR2(4000 BYTE),
  VENDOR_CHARGED_TAX             NUMBER,
  USER_ENTERED_TAX               VARCHAR2(150 BYTE),
  TAX_CONTROL_AMT                NUMBER,
  FAPIO_RECEIVED                 VARCHAR2(150 BYTE),
  FAPIO_FLAG                     VARCHAR2(3 BYTE),
  LINE_TYPE                      VARCHAR2(25 BYTE),
  LINE_TYPE_ID                   NUMBER,
  LINE_DESCRIPTION               VARCHAR2(4000 BYTE),
  LINE_AMOUNT                    NUMBER,
  DISTRIBUTION_ACCT              VARCHAR2(250 BYTE),
  DIST_ACCOUNT_ID                NUMBER,
  SHIP_TO                        VARCHAR2(100 BYTE),
  SHIP_TO_LOCATION_ID            NUMBER,
  PO_NUMBER                      VARCHAR2(20 BYTE),
  PO_HEADER_L_ID                 NUMBER,
  PO_LINE_ID                     NUMBER,
  PO_LINE_NUMBER                 NUMBER,
  QUANTITY_INVOICED              NUMBER,
  UNIT_PRICE                     NUMBER,
  GL_DATE                        DATE,
  INVOICE_TYPE_LOOKUP_CODE       VARCHAR2(100 BYTE),
  TAX_CLASSIFICATION_CODE        VARCHAR2(100 BYTE),
  INTERCO_EXP_ACCOUNT            VARCHAR2(250 BYTE),
  INTERCO_EXP_ACCOUNT_ID         NUMBER,
  DEFERRED                       VARCHAR2(100 BYTE),
  DEFERRED_FLAG                  VARCHAR2(3 BYTE),
  DEFERRED_START_DATE            DATE,
  DEFERRED_END_DATE              DATE,
  PRORATE_ACCROS_ALL_ITEM_LINES  VARCHAR2(3 BYTE),
  PRORATE_FLAG                   VARCHAR2(3 BYTE),
  TRACK_AS_ASSET                 VARCHAR2(3 BYTE),
  ASSET_FLAG                     VARCHAR2(3 BYTE),
  ASSET_CATEGORY                 VARCHAR2(200 BYTE),
  ASSET_CAT_ID                   NUMBER,
  APPROVER                       VARCHAR2(150 BYTE),
  DATE_SENT_APPROVER             VARCHAR2(150 BYTE),
  MISC_NOTES                     VARCHAR2(150 BYTE),
  CHARGEBACK                     VARCHAR2(150 BYTE),
  INVOICE_NUMBER_D               VARCHAR2(100 BYTE),
  PAYMENT_REF_NUMBER             VARCHAR2(150 BYTE),
  SAMPLE_INVOICE                 VARCHAR2(150 BYTE),
  SAMPLE_INV_FLAG                VARCHAR2(3 BYTE),
  ASSET_BOOK                     VARCHAR2(100 BYTE),
  ASSET_BOOK_CODE                VARCHAR2(100 BYTE),
  DISTRIBUTION_SET               VARCHAR2(250 BYTE),
  DIST_SET_ID                    NUMBER,
  PAYMENT_TERMS                  VARCHAR2(50 BYTE),
  PAYMENT_TERM_ID                NUMBER,
  PAYMENT_METHOD                 VARCHAR2(50 BYTE),
  INVOICE_ADD_INFO               VARCHAR2(150 BYTE),
  PAY_ALONE                      VARCHAR2(3 BYTE),
  PAY_ALONE_FLAG                 VARCHAR2(3 BYTE),
  CREATION_DATE                  DATE,
  CREATED_BY                     NUMBER,
  LAST_UPDATE_DATE               DATE,
  LAST_UPDATED_BY                NUMBER,
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


--
-- RECORD_ID_PK  (Index) 
--
--  Dependencies: 
--   XXD_AP_LCX_INVOICES_STG_T (Table)
--
CREATE UNIQUE INDEX XXDO.RECORD_ID_PK ON XXDO.XXD_AP_LCX_INVOICES_STG_T
(RECORD_ID)
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

ALTER TABLE XXDO.XXD_AP_LCX_INVOICES_STG_T ADD (
  CONSTRAINT RECORD_ID_PK
  UNIQUE (RECORD_ID)
  USING INDEX XXDO.RECORD_ID_PK
  ENABLE VALIDATE)
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_AP_LCX_INVOICES_STG_T TO APPS
/
