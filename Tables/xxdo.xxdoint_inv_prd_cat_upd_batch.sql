--
-- XXDOINT_INV_PRD_CAT_UPD_BATCH  (Table) 
--
CREATE TABLE XXDO.XXDOINT_INV_PRD_CAT_UPD_BATCH
(
  BATCH_ID           NUMBER                     NOT NULL,
  ORGANIZATION_ID    NUMBER                     NOT NULL,
  INVENTORY_ITEM_ID  NUMBER                     NOT NULL,
  BATCH_DATE         DATE                       DEFAULT sysdate               NOT NULL
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
-- XXDOINT_INV_PRD_CAT_UPD_BCH_N1  (Index) 
--
--  Dependencies: 
--   XXDOINT_INV_PRD_CAT_UPD_BATCH (Table)
--
CREATE INDEX XXDO.XXDOINT_INV_PRD_CAT_UPD_BCH_N1 ON XXDO.XXDOINT_INV_PRD_CAT_UPD_BATCH
(BATCH_DATE)
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
-- XXDOINT_INV_PRD_CAT_UPD_BCH_N2  (Index) 
--
--  Dependencies: 
--   XXDOINT_INV_PRD_CAT_UPD_BATCH (Table)
--
CREATE INDEX XXDO.XXDOINT_INV_PRD_CAT_UPD_BCH_N2 ON XXDO.XXDOINT_INV_PRD_CAT_UPD_BATCH
(BATCH_ID)
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
-- XXDOINT_INV_PRD_CAT_UPD_BCH_N3  (Index) 
--
--  Dependencies: 
--   XXDOINT_INV_PRD_CAT_UPD_BATCH (Table)
--
CREATE INDEX XXDO.XXDOINT_INV_PRD_CAT_UPD_BCH_N3 ON XXDO.XXDOINT_INV_PRD_CAT_UPD_BATCH
(BATCH_ID, ORGANIZATION_ID, INVENTORY_ITEM_ID)
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
-- XXDOINT_INV_PRD_CAT_UPD_BATCH  (Synonym) 
--
--  Dependencies: 
--   XXDOINT_INV_PRD_CAT_UPD_BATCH (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOINT_INV_PRD_CAT_UPD_BATCH FOR XXDO.XXDOINT_INV_PRD_CAT_UPD_BATCH
/
