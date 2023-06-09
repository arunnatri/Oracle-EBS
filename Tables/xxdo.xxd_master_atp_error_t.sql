--
-- XXD_MASTER_ATP_ERROR_T  (Table) 
--
CREATE TABLE XXDO.XXD_MASTER_ATP_ERROR_T
(
  SLNO                 NUMBER,
  INVENTORY_ITEM_ID    NUMBER,
  INV_ORGANIZATION_ID  NUMBER,
  DEMAND_CLASS_CODE    VARCHAR2(30 BYTE),
  APPLICATION          VARCHAR2(30 BYTE),
  BRAND                VARCHAR2(30 BYTE),
  UOM_CODE             VARCHAR2(3 BYTE),
  ERROR_CODE           VARCHAR2(30 BYTE),
  ERROR_MESSAGE        VARCHAR2(1000 BYTE),
  CREATION_DATE        DATE,
  CREATED_BY           NUMBER
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


--
-- XXD_MASTER_ATP_ERROR_T  (Synonym) 
--
--  Dependencies: 
--   XXD_MASTER_ATP_ERROR_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_MASTER_ATP_ERROR_T FOR XXDO.XXD_MASTER_ATP_ERROR_T
/
