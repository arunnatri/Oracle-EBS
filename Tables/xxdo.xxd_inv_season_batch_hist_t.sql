--
-- XXD_INV_SEASON_BATCH_HIST_T  (Table) 
--
CREATE TABLE XXDO.XXD_INV_SEASON_BATCH_HIST_T
(
  BATCH_ID           NUMBER,
  ORGANIZATION_ID    NUMBER,
  INVENTORY_ITEM_ID  NUMBER,
  BATCH_DATE         DATE
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
