--
-- XXDO_WMS_3PL_UPDATE_HIST  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_UPDATE_HIST
(
  HIST_ID           NUMBER                      NOT NULL,
  HIST_CREATE_DATE  DATE                        DEFAULT sysdate               NOT NULL,
  HIST_UPDATED_BY   NUMBER                      NOT NULL,
  UPDATE_TYPE       VARCHAR2(50 BYTE)           NOT NULL,
  UPDATE_TABLE      VARCHAR2(50 BYTE)           NOT NULL,
  UPDATE_ID         NUMBER,
  UPDATE_ROWID      VARCHAR2(18 BYTE)           NOT NULL,
  COMMENTS          VARCHAR2(2000 BYTE)
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
-- XXDO_WMS_3PL_UPDATE_HIST_PK  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_UPDATE_HIST (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_UPDATE_HIST_PK ON XXDO.XXDO_WMS_3PL_UPDATE_HIST
(HIST_ID)
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

ALTER TABLE XXDO.XXDO_WMS_3PL_UPDATE_HIST ADD (
  CONSTRAINT XXDO_WMS_3PL_UPDATE_HIST_PK
  PRIMARY KEY
  (HIST_ID)
  USING INDEX XXDO.XXDO_WMS_3PL_UPDATE_HIST_PK
  ENABLE VALIDATE)
/


--
-- XXDO_WMS_3PL_UPDATE_HIST_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_UPDATE_HIST (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_UPDATE_HIST_N1 ON XXDO.XXDO_WMS_3PL_UPDATE_HIST
(UPDATE_TABLE, UPDATE_ID)
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
