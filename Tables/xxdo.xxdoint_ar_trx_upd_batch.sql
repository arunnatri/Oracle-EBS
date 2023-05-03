--
-- XXDOINT_AR_TRX_UPD_BATCH  (Table) 
--
CREATE TABLE XXDO.XXDOINT_AR_TRX_UPD_BATCH
(
  BATCH_ID         NUMBER                       NOT NULL,
  CUSTOMER_TRX_ID  NUMBER                       NOT NULL,
  BATCH_DATE       DATE                         DEFAULT sysdate               NOT NULL
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
-- XXDOINT_AR_TRX_UPD_BATCH_PK  (Index) 
--
--  Dependencies: 
--   XXDOINT_AR_TRX_UPD_BATCH (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOINT_AR_TRX_UPD_BATCH_PK ON XXDO.XXDOINT_AR_TRX_UPD_BATCH
(BATCH_ID, CUSTOMER_TRX_ID)
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

ALTER TABLE XXDO.XXDOINT_AR_TRX_UPD_BATCH ADD (
  CONSTRAINT XXDOINT_AR_TRX_UPD_BATCH_PK
  PRIMARY KEY
  (BATCH_ID, CUSTOMER_TRX_ID)
  USING INDEX XXDO.XXDOINT_AR_TRX_UPD_BATCH_PK
  ENABLE VALIDATE)
/


--
-- XXDOINT_AR_TRX_UPD_BATCH_N1  (Index) 
--
--  Dependencies: 
--   XXDOINT_AR_TRX_UPD_BATCH (Table)
--
CREATE INDEX XXDO.XXDOINT_AR_TRX_UPD_BATCH_N1 ON XXDO.XXDOINT_AR_TRX_UPD_BATCH
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
