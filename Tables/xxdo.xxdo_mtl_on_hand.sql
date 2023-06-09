--
-- XXDO_MTL_ON_HAND  (Table) 
--
CREATE TABLE XXDO.XXDO_MTL_ON_HAND
(
  BRAND              VARCHAR2(40 BYTE),
  ORGANIZATION_ID    NUMBER,
  INVENTORY_ITEM_ID  NUMBER,
  INTRO_SEASON       VARCHAR2(40 BYTE),
  SERIES             VARCHAR2(40 BYTE),
  ITEM_COST          NUMBER,
  TOTAL_UNITS        NUMBER,
  TOTAL_COST         NUMBER,
  QTR_SALES_QTY      NUMBER,
  SO_SHIPPED_QTY     NUMBER,
  SO_OPEN_QTY        NUMBER,
  SO_OPEN_AMT        NUMBER,
  FTZ_UNITS          NUMBER
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
