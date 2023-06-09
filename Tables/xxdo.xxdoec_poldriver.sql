--
-- XXDOEC_POLDRIVER  (Table) 
--
CREATE TABLE XXDO.XXDOEC_POLDRIVER
(
  ID                 INTEGER                    NOT NULL,
  EVENT_DRIVER       VARCHAR2(10 BYTE),
  STATUS_CODE        VARCHAR2(10 BYTE),
  DESCRIPTION        VARCHAR2(200 BYTE),
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER,
  LAST_UPDATE_LOGIN  NUMBER,
  RECORD_ID          NUMBER                     NOT NULL
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
-- PK_XXDOEC_POLDRIVER  (Index) 
--
--  Dependencies: 
--   XXDOEC_POLDRIVER (Table)
--
CREATE UNIQUE INDEX XXDO.PK_XXDOEC_POLDRIVER ON XXDO.XXDOEC_POLDRIVER
(ID)
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
-- XXDO_POL_RECID_UNIQUE  (Index) 
--
--  Dependencies: 
--   XXDOEC_POLDRIVER (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_POL_RECID_UNIQUE ON XXDO.XXDOEC_POLDRIVER
(RECORD_ID)
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

ALTER TABLE XXDO.XXDOEC_POLDRIVER ADD (
  CONSTRAINT PK_XXDOEC_POLDRIVER
  PRIMARY KEY
  (ID)
  USING INDEX XXDO.PK_XXDOEC_POLDRIVER
  ENABLE VALIDATE
,  CONSTRAINT XXDO_POL_RECID_UNIQUE
  UNIQUE (RECORD_ID)
  USING INDEX XXDO.XXDO_POL_RECID_UNIQUE
  ENABLE VALIDATE)
/


--
-- XXDOEC_POLDRIVER_IDX1  (Index) 
--
--  Dependencies: 
--   XXDOEC_POLDRIVER (Table)
--
CREATE INDEX XXDO.XXDOEC_POLDRIVER_IDX1 ON XXDO.XXDOEC_POLDRIVER
(EVENT_DRIVER, STATUS_CODE)
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
-- XXDOEC_POLDRIVER  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_POLDRIVER (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOEC_POLDRIVER FOR XXDO.XXDOEC_POLDRIVER
/


GRANT SELECT ON XXDO.XXDOEC_POLDRIVER TO APPS WITH GRANT OPTION
/
GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOEC_POLDRIVER TO APPS
/

GRANT SELECT ON XXDO.XXDOEC_POLDRIVER TO APPSRO
/
