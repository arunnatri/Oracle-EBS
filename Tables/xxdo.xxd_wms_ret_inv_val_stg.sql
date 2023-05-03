--
-- XXD_WMS_RET_INV_VAL_STG  (Table) 
--
CREATE TABLE XXDO.XXD_WMS_RET_INV_VAL_STG
(
  SEQ_ID                 NUMBER,
  MONTH_YEAR             VARCHAR2(10 BYTE),
  SOH_DATE               DATE,
  OPERATING_UNIT_ID      NUMBER,
  OPERATING_UNIT_NAME    VARCHAR2(120 BYTE),
  ORG_UNIT_DESC_RMS      VARCHAR2(120 BYTE),
  ORG_UNIT_ID_RMS        NUMBER,
  STORE_NUMBER           NUMBER,
  STORE_NAME             VARCHAR2(150 BYTE),
  STORE_TYPE             VARCHAR2(30 BYTE),
  STORE_CURRENCY         VARCHAR2(3 BYTE),
  BRAND                  VARCHAR2(30 BYTE),
  STYLE                  VARCHAR2(30 BYTE),
  COLOR_ID               VARCHAR2(30 BYTE),
  COLOR                  VARCHAR2(30 BYTE),
  STYLE_COLOR            VARCHAR2(60 BYTE),
  SKU                    VARCHAR2(60 BYTE),
  INVENTORY_ITEM_ID      NUMBER,
  CLASS_NAME             VARCHAR2(120 BYTE),
  STOCK_ON_HAND          NUMBER(12,4),
  EXTENDED_COST_AMOUNT   NUMBER(20,4),
  UNIT_COST              NUMBER(20,4),
  AVG_MARGIN_STORE_CURR  NUMBER(20,4),
  IC_MARGIN_STORE_CURR   NUMBER(20,4),
  AVG_MARGIN_USD         NUMBER(20,4),
  IC_MARGIN_USD          NUMBER(20,4),
  CREATION_DATE          DATE,
  CREATED_BY             NUMBER,
  LAST_UPDATE_DATE       DATE,
  LAST_UPDATED_BY        NUMBER,
  REQUEST_ID             NUMBER                 NOT NULL,
  LAST_UPDATE_LOGIN      NUMBER
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


ALTER TABLE XXDO.XXD_WMS_RET_INV_VAL_STG ADD (
  PRIMARY KEY
  (SEQ_ID)
  USING INDEX
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
  ENABLE VALIDATE)
/


--  There is no statement for index XXDO.SYS_C005907468.
--  The object is created when the parent object is created.

--
-- XXD_WMS_RET_INV_VAL_STG_N1  (Index) 
--
--  Dependencies: 
--   XXD_WMS_RET_INV_VAL_STG (Table)
--
CREATE INDEX XXDO.XXD_WMS_RET_INV_VAL_STG_N1 ON XXDO.XXD_WMS_RET_INV_VAL_STG
(REQUEST_ID)
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
-- XXD_WMS_RET_INV_VAL_STG  (Synonym) 
--
--  Dependencies: 
--   XXD_WMS_RET_INV_VAL_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_WMS_RET_INV_VAL_STG FOR XXDO.XXD_WMS_RET_INV_VAL_STG
/
