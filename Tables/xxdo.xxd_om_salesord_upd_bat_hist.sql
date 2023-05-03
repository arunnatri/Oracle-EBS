--
-- XXD_OM_SALESORD_UPD_BAT_HIST  (Table) 
--
CREATE TABLE XXDO.XXD_OM_SALESORD_UPD_BAT_HIST
(
  BATCH_ID    NUMBER                            NOT NULL,
  HEADER_ID   NUMBER                            NOT NULL,
  BATCH_DATE  DATE                              NOT NULL
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
-- XXD_OM_SO_UPD_BAT_H_IDX1  (Index) 
--
--  Dependencies: 
--   XXD_OM_SALESORD_UPD_BAT_HIST (Table)
--
CREATE INDEX XXDO.XXD_OM_SO_UPD_BAT_H_IDX1 ON XXDO.XXD_OM_SALESORD_UPD_BAT_HIST
(HEADER_ID)
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
