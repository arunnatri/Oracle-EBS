--
-- XXDOAR_INVOICE_DET  (Table) 
--
CREATE TABLE XXDO.XXDOAR_INVOICE_DET
(
  BRAND                       VARCHAR2(150 BYTE),
  ORGANIZATION_NAME           VARCHAR2(240 BYTE) NOT NULL,
  WAREHOUSE_NAME              VARCHAR2(240 BYTE),
  COUNTRY                     VARCHAR2(60 BYTE),
  CUSTOMER_TRX_ID             NUMBER(15)        NOT NULL,
  INVOICE_NUMBER              VARCHAR2(20 BYTE) NOT NULL,
  INVOICE_DATE                DATE              NOT NULL,
  SALES_ORDER                 VARCHAR2(30 BYTE),
  FACTORY_INV                 VARCHAR2(4000 BYTE),
  SELL_TO_CUSTOMER_NAME       VARCHAR2(360 BYTE),
  INVOICE_CURRENCY_CODE       VARCHAR2(15 BYTE),
  SERIES                      VARCHAR2(240 BYTE),
  STYLE                       VARCHAR2(240 BYTE),
  COLOR                       VARCHAR2(40 BYTE),
  INVOICE_TOTAL               NUMBER,
  PRE_CONV_INV_TOTAL          NUMBER,
  INVOICED_QTY                NUMBER,
  TRANS_LANDED_COST_OF_GOODS  NUMBER,
  COGS_ACCT                   VARCHAR2(103 BYTE),
  SHIP_LANDED_COST_OF_GOODS   NUMBER,
  UNIT_SELLING_PRICE          NUMBER,
  UNIT_LIST_PRICE             NUMBER,
  DISCOUNT                    NUMBER,
  EXT_DISCOUNT                NUMBER,
  TAX_RATE_CODE               VARCHAR2(300 BYTE),
  TAX_RATE                    VARCHAR2(150 BYTE),
  PRE_CONV_TAX_AMT            NUMBER,
  PRE_CONV_TOTAL_AMT          NUMBER,
  TOTAL_AMT                   NUMBER,
  ACCOUNT                     VARCHAR2(103 BYTE),
  WHOLESALE_PRICE             NUMBER,
  PURCHASE_ORDER              VARCHAR2(50 BYTE),
  PARTY_SITE_NUMBER           VARCHAR2(30 BYTE),
  ORDER_TYPE                  VARCHAR2(30 BYTE),
  AR_TYPE                     VARCHAR2(20 BYTE),
  USD_REVENUE_TOTAL           NUMBER,
  ADDRESS1                    VARCHAR2(250 BYTE),
  ADDRESS2                    VARCHAR2(250 BYTE),
  STATE                       VARCHAR2(100 BYTE),
  GENDER                      VARCHAR2(100 BYTE),
  ADDRESS_KEY                 VARCHAR2(100 BYTE),
  ORIGINAL_ORDER              VARCHAR2(50 BYTE),
  ORIGINAL_SHIPMENT_DATE      VARCHAR2(50 BYTE),
  COMMODITY_CODE              VARCHAR2(40 BYTE),
  TERM_NAME                   VARCHAR2(40 BYTE),
  ORDER_CLASS                 VARCHAR2(140 BYTE),
  MACAU_COST                  NUMBER,
  MATERIAL_COST               NUMBER,
  CUSTOMER_NUMBER             VARCHAR2(50 BYTE),
  CURRENT_SEASON              VARCHAR2(140 BYTE),
  SUB_GROUP                   VARCHAR2(140 BYTE),
  EMPLOYEE_ORDER              VARCHAR2(30 BYTE),
  DISCOUNT_CODE               VARCHAR2(30 BYTE),
  VAT_NUMBER                  VARCHAR2(240 BYTE),
  ZIP_CODE                    VARCHAR2(30 BYTE),
  SUB_CLASS                   VARCHAR2(140 BYTE),
  ITEM_NUMBER                 VARCHAR2(140 BYTE),
  ITEM_TYPE                   VARCHAR2(140 BYTE),
  ACCOUNT_TYPE                VARCHAR2(140 BYTE),
  CITY                        VARCHAR2(60 BYTE),
  TRANSACTION_NUMBER          VARCHAR2(20 BYTE),
  AVERAGE_MARGIN              NUMBER
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
