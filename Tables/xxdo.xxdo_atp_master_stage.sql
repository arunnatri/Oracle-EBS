--
-- XXDO_ATP_MASTER_STAGE  (Table) 
--
CREATE TABLE XXDO.XXDO_ATP_MASTER_STAGE
(
  SLNO                 NUMBER,
  SKU                  VARCHAR2(40 BYTE),
  INVENTORY_ITEM_ID    NUMBER,
  INV_ORGANIZATION_ID  NUMBER,
  DEMAND_CLASS_CODE    VARCHAR2(30 BYTE),
  APPLICATION          VARCHAR2(30 BYTE),
  BRAND                VARCHAR2(30 BYTE),
  UOM_CODE             VARCHAR2(3 BYTE),
  REQUESTED_SHIP_DATE  DATE,
  AVAILABLE_QUANTITY   NUMBER,
  AVAILABLE_DATE       DATE,
  CREATION_DATE        DATE,
  CREATED_BY           NUMBER,
  LAST_UPDATE_LOGIN    NUMBER,
  LAST_UPDATE_DATE     DATE,
  LAST_UPDATED_BY      NUMBER,
  STORE_TYPE           VARCHAR2(20 BYTE)
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
NOLOGGING 
NOCOMPRESS 
NOCACHE
/


--
-- XXDO_ATP_MASTER_STAGE_N1  (Index) 
--
--  Dependencies: 
--   XXDO_ATP_MASTER_STAGE (Table)
--
CREATE INDEX XXDO.XXDO_ATP_MASTER_STAGE_N1 ON XXDO.XXDO_ATP_MASTER_STAGE
(INVENTORY_ITEM_ID, DEMAND_CLASS_CODE, INV_ORGANIZATION_ID, AVAILABLE_DATE)
NOLOGGING
TABLESPACE APPS_TS_TX_IDX
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
PARALLEL ( DEGREE 6 INSTANCES 2 )
/

--
-- XXDO_ATP_MASTER_STAGE_N2  (Index) 
--
--  Dependencies: 
--   XXDO_ATP_MASTER_STAGE (Table)
--
CREATE INDEX XXDO.XXDO_ATP_MASTER_STAGE_N2 ON XXDO.XXDO_ATP_MASTER_STAGE
(INVENTORY_ITEM_ID, INV_ORGANIZATION_ID, DEMAND_CLASS_CODE)
NOLOGGING
TABLESPACE APPS_TS_TX_IDX
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
PARALLEL ( DEGREE 6 INSTANCES 2 )
/

--
-- XXDO_ATP_MASTER_STAGE_N5  (Index) 
--
--  Dependencies: 
--   XXDO_ATP_MASTER_STAGE (Table)
--
CREATE INDEX XXDO.XXDO_ATP_MASTER_STAGE_N5 ON XXDO.XXDO_ATP_MASTER_STAGE
(AVAILABLE_QUANTITY)
NOLOGGING
TABLESPACE APPS_TS_TX_IDX
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
PARALLEL ( DEGREE 6 INSTANCES 2 )
/

--
-- XXDO_ATP_MASTER_STAGE_N6  (Index) 
--
--  Dependencies: 
--   XXDO_ATP_MASTER_STAGE (Table)
--
CREATE INDEX XXDO.XXDO_ATP_MASTER_STAGE_N6 ON XXDO.XXDO_ATP_MASTER_STAGE
(APPLICATION)
NOLOGGING
TABLESPACE APPS_TS_TX_IDX
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
PARALLEL ( DEGREE 6 INSTANCES 2 )
/
