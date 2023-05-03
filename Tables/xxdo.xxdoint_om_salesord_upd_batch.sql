--
-- XXDOINT_OM_SALESORD_UPD_BATCH  (Table) 
--
CREATE TABLE XXDO.XXDOINT_OM_SALESORD_UPD_BATCH
(
  BATCH_ID    NUMBER                            NOT NULL,
  HEADER_ID   NUMBER                            NOT NULL,
  BATCH_DATE  DATE                              DEFAULT sysdate               NOT NULL
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
-- XXDOINT_OM_SO_UPD_BATCH_N1  (Index) 
--
--  Dependencies: 
--   XXDOINT_OM_SALESORD_UPD_BATCH (Table)
--
CREATE INDEX XXDO.XXDOINT_OM_SO_UPD_BATCH_N1 ON XXDO.XXDOINT_OM_SALESORD_UPD_BATCH
(BATCH_ID, HEADER_ID)
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
