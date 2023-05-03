--
-- XXDOEC_INVENTORY  (Table) 
--
CREATE TABLE XXDO.XXDOEC_INVENTORY
(
  ERP_ORG_ID           NUMBER                   NOT NULL,
  INV_ORG_ID           NUMBER                   NOT NULL,
  FEED_CODE            VARCHAR2(64 BYTE)        NOT NULL,
  BRAND                VARCHAR2(64 BYTE)        NOT NULL,
  INVENTORY_ITEM_ID    NUMBER                   NOT NULL,
  KCO_HDR_ID           NUMBER,
  SKU                  VARCHAR2(64 BYTE)        NOT NULL,
  UPC                  VARCHAR2(64 BYTE)        NOT NULL,
  ATP_QTY              NUMBER                   DEFAULT 0,
  ATP_DATE             DATE,
  ATP_BUFFER           NUMBER                   DEFAULT 0                     NOT NULL,
  ATP_WHEN_ATR         NUMBER                   DEFAULT 0,
  PRE_BACK_ORDER_MODE  CHAR(1 BYTE)             DEFAULT '0',
  PRE_BACK_ORDER_QTY   NUMBER                   DEFAULT 0,
  PRE_BACK_ORDER_DATE  DATE,
  IS_PERPETUAL         CHAR(1 BYTE)             DEFAULT '0',
  CONSUMED_DATE        DATE,
  CONSUMED_DATE_CA     DATE,
  KCO_REMAINING_QTY    NUMBER                   DEFAULT 0,
  FILETYPE             VARCHAR2(10 BYTE),
  SUPPLEMENTAL LOG GROUP GGS_3152633 (ERP_ORG_ID,INV_ORG_ID,FEED_CODE,INVENTORY_ITEM_ID) ALWAYS,
  SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS,
  SUPPLEMENTAL LOG DATA (UNIQUE) COLUMNS,
  SUPPLEMENTAL LOG DATA (FOREIGN KEY) COLUMNS
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
-- XXDOEC_INVENTORY_IDX  (Index) 
--
--  Dependencies: 
--   XXDOEC_INVENTORY (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOEC_INVENTORY_IDX ON XXDO.XXDOEC_INVENTORY
(INVENTORY_ITEM_ID, ERP_ORG_ID, INV_ORG_ID, FEED_CODE)
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
