--
-- XXD_NEG_ATP_ITEMS_TMP_ARCH  (Table) 
--
CREATE TABLE XXDO.XXD_NEG_ATP_ITEMS_TMP_ARCH
(
  BATCH_ID           NUMBER,
  PLAN_ID            NUMBER,
  PLAN_DATE          DATE,
  EBS_ITEM_ID        NUMBER,
  ORGANIZATION_ID    NUMBER                     NOT NULL,
  INVENTORY_ITEM_ID  NUMBER,
  DEMAND_CLASS       VARCHAR2(150 BYTE),
  NEGATIVITY         NUMBER,
  REQUEST_ID         NUMBER,
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER
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
-- XXD_NEG_ATP_ITEMS_TMP_ARCH  (Synonym) 
--
--  Dependencies: 
--   XXD_NEG_ATP_ITEMS_TMP_ARCH (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_NEG_ATP_ITEMS_TMP_ARCH FOR XXDO.XXD_NEG_ATP_ITEMS_TMP_ARCH
/
