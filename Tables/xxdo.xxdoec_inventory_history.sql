--
-- XXDOEC_INVENTORY_HISTORY  (Table) 
--
CREATE TABLE XXDO.XXDOEC_INVENTORY_HISTORY
(
  ERP_ORG_ID           NUMBER                   NOT NULL,
  INV_ORG_ID           NUMBER                   NOT NULL,
  FEED_CODE            VARCHAR2(64 BYTE)        NOT NULL,
  BRAND                VARCHAR2(64 BYTE)        NOT NULL,
  INVENTORY_ITEM_ID    NUMBER                   NOT NULL,
  KCO_HDR_ID           NUMBER,
  SKU                  VARCHAR2(64 BYTE)        NOT NULL,
  UPC                  VARCHAR2(64 BYTE)        NOT NULL,
  ATP_QTY              NUMBER,
  ATP_DATE             DATE,
  ATP_BUFFER           NUMBER                   NOT NULL,
  ATP_WHEN_ATR         NUMBER,
  PRE_BACK_ORDER_MODE  CHAR(1 BYTE),
  PRE_BACK_ORDER_QTY   NUMBER,
  PRE_BACK_ORDER_DATE  DATE,
  IS_PERPETUAL         CHAR(1 BYTE),
  CONSUMED_DATE        DATE,
  CONSUMED_DATE_CA     DATE,
  KCO_REMAINING_QTY    NUMBER,
  HISTORY_DATE         DATE
)
TABLESPACE CUSTOM_TX_TS
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
/
