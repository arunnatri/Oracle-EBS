--
-- XXD_ONT_PARTNER_RETAILER_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_PARTNER_RETAILER_STG_T
(
  BATCH_ID             NUMBER,
  FILE_TYPE            VARCHAR2(100 BYTE),
  ORG_ID               NUMBER,
  FILE_FREQUENCY       VARCHAR2(100 BYTE),
  ACCOUNT_NUMBER       VARCHAR2(30 BYTE),
  PARTY_NAME           VARCHAR2(360 BYTE),
  STORE_CODE           VARCHAR2(150 BYTE),
  STORE_NAME           VARCHAR2(100 BYTE),
  STORE_TYPE           VARCHAR2(100 BYTE),
  TRANSACTION_DATE     VARCHAR2(100 BYTE),
  TRANSACTION_NUM      VARCHAR2(100 BYTE),
  STYLE_NUMBER         VARCHAR2(100 BYTE),
  COLOR                VARCHAR2(100 BYTE),
  ITEM_SIZE            VARCHAR2(100 BYTE),
  SALES_QTY            NUMBER,
  UNIT_PRICE           NUMBER,
  CUSTOMER_LIST_PRICE  NUMBER,
  ONHAND_QUANTITY      NUMBER,
  INTRANSIT_QUANTITY   NUMBER,
  INVENTORY_DATE       VARCHAR2(100 BYTE),
  SALES_AMOUNT         NUMBER,
  DISCOUNT             NUMBER,
  FILE_NAME            VARCHAR2(100 BYTE),
  NUMBER_ATTRIBUTE1    NUMBER,
  NUMBER_ATTRIBUTE2    NUMBER,
  NUMBER_ATTRIBUTE3    NUMBER,
  NUMBER_ATTRIBUTE4    NUMBER,
  NUMBER_ATTRIBUTE5    NUMBER,
  CHAR_ATTRIBUTE1      VARCHAR2(100 BYTE),
  CHAR_ATTRIBUTE2      VARCHAR2(100 BYTE),
  CHAR_ATTRIBUTE3      VARCHAR2(100 BYTE),
  CHAR_ATTRIBUTE4      VARCHAR2(100 BYTE),
  CHAR_ATTRIBUTE5      VARCHAR2(100 BYTE),
  DATE_ATTRIBUTE1      DATE,
  DATE_ATTRIBUTE2      DATE,
  DATE_ATTRIBUTE3      DATE,
  DATE_ATTRIBUTE4      DATE,
  DATE_ATTRIBUTE5      DATE,
  STORE_STATUS         VARCHAR2(1 BYTE),
  SKU_STATUS           VARCHAR2(1 BYTE),
  DATE_STATUS          VARCHAR2(1 BYTE),
  OVERALL_STATUS       VARCHAR2(1 BYTE),
  ERROR_MESSAGE        VARCHAR2(4000 BYTE),
  CREATION_DATE        DATE,
  CREATED_BY           NUMBER
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
-- XXD_ONT_PART_RETAIL_SKU_IDX  (Index) 
--
--  Dependencies: 
--   XXD_ONT_PARTNER_RETAILER_STG_T (Table)
--
CREATE INDEX APPS.XXD_ONT_PART_RETAIL_SKU_IDX ON XXDO.XXD_ONT_PARTNER_RETAILER_STG_T
("STYLE_NUMBER"||'-'||"COLOR"||'-'||"ITEM_SIZE", BATCH_ID)
LOGGING
TABLESPACE APPS_TS_TX_DATA
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_ONT_PARTNER_RETAILER_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_PARTNER_RETAILER_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_PARTNER_RETAILER_STG_T FOR XXDO.XXD_ONT_PARTNER_RETAILER_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_ONT_PARTNER_RETAILER_STG_T TO SOA_INT
/
