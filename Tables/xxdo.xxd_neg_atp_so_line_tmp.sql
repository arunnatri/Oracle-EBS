--
-- XXD_NEG_ATP_SO_LINE_TMP  (Table) 
--
CREATE TABLE XXDO.XXD_NEG_ATP_SO_LINE_TMP
(
  BATCH_ID             NUMBER,
  ORGANIZATION_ID      NUMBER,
  BRAND                VARCHAR2(40 BYTE),
  ALLOC_DATE           DATE,
  SALES_ORDER_LINE_ID  NUMBER,
  SUPPLY_QTY           NUMBER,
  DEMAND_QTY           NUMBER,
  NET_QTY              NUMBER,
  POH                  NUMBER,
  DEMAND_CLASS         VARCHAR2(120 BYTE),
  EBS_ITEM_ID          NUMBER,
  INVENTORY_ITEM_ID    NUMBER,
  REQUEST_ID           NUMBER,
  CREATION_DATE        DATE,
  CREATED_BY           NUMBER,
  LAST_UPDATE_DATE     DATE,
  LAST_UPDATED_BY      NUMBER
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
-- XXD_NEG_ATP_SO_LINE_TMP_N1  (Index) 
--
--  Dependencies: 
--   XXD_NEG_ATP_SO_LINE_TMP (Table)
--
CREATE INDEX XXDO.XXD_NEG_ATP_SO_LINE_TMP_N1 ON XXDO.XXD_NEG_ATP_SO_LINE_TMP
(BATCH_ID, ORGANIZATION_ID, BRAND)
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
-- XXD_NEG_ATP_SO_LINE_TMP_N2  (Index) 
--
--  Dependencies: 
--   XXD_NEG_ATP_SO_LINE_TMP (Table)
--
CREATE INDEX XXDO.XXD_NEG_ATP_SO_LINE_TMP_N2 ON XXDO.XXD_NEG_ATP_SO_LINE_TMP
(BATCH_ID, SALES_ORDER_LINE_ID)
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
-- XXD_NEG_ATP_SO_LINE_TMP  (Synonym) 
--
--  Dependencies: 
--   XXD_NEG_ATP_SO_LINE_TMP (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_NEG_ATP_SO_LINE_TMP FOR XXDO.XXD_NEG_ATP_SO_LINE_TMP
/
