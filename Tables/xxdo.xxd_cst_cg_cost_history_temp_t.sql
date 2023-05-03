--
-- XXD_CST_CG_COST_HISTORY_TEMP_T  (Table) 
--
CREATE TABLE XXDO.XXD_CST_CG_COST_HISTORY_TEMP_T
(
  NEW_COST                 NUMBER,
  NEW_MATERIAL             NUMBER,
  NEW_MATERIAL_OVERHEAD    NUMBER,
  TRANSACTION_ID           NUMBER,
  ORGANIZATION_ID          NUMBER,
  INVENTORY_ITEM_ID        NUMBER,
  TRANSACTION_DATE         DATE,
  TRANSACTION_COSTED_DATE  DATE,
  REQUEST_ID               NUMBER,
  ATTRIBUTE1               VARCHAR2(240 BYTE),
  ATTRIBUTE2               VARCHAR2(240 BYTE),
  ATTRIBUTE3               VARCHAR2(240 BYTE),
  ATTRIBUTE4               VARCHAR2(240 BYTE),
  ATTRIBUTE5               VARCHAR2(240 BYTE),
  ATTRIBUTE6               VARCHAR2(240 BYTE),
  ATTRIBUTE7               VARCHAR2(240 BYTE),
  ATTRIBUTE8               VARCHAR2(240 BYTE),
  ATTRIBUTE9               VARCHAR2(240 BYTE),
  ATTRIBUTE10              VARCHAR2(240 BYTE),
  ATTRIBUTE11              VARCHAR2(240 BYTE),
  ATTRIBUTE12              VARCHAR2(240 BYTE),
  ATTRIBUTE13              VARCHAR2(240 BYTE),
  ATTRIBUTE14              VARCHAR2(240 BYTE),
  ATTRIBUTE15              VARCHAR2(240 BYTE),
  CREATION_DATE            DATE,
  CREATED_BY               NUMBER,
  LAST_UPDATED_BY          NUMBER,
  LAST_UPDATE_DATE         DATE,
  LAST_UPDATE_LOGIN        NUMBER
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
-- XXD_CST_CG_COST_HIST_TEMP_N1  (Index) 
--
--  Dependencies: 
--   XXD_CST_CG_COST_HISTORY_TEMP_T (Table)
--
CREATE INDEX XXDO.XXD_CST_CG_COST_HIST_TEMP_N1 ON XXDO.XXD_CST_CG_COST_HISTORY_TEMP_T
(REQUEST_ID, ORGANIZATION_ID, INVENTORY_ITEM_ID, TRUNC("TRANSACTION_DATE"))
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
COMPRESS 2
/