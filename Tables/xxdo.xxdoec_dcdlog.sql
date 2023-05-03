--
-- XXDOEC_DCDLOG  (Table) 
--
CREATE TABLE XXDO.XXDOEC_DCDLOG
(
  ID                NUMBER                      NOT NULL,
  CODE              NUMBER,
  MESSAGE           VARCHAR2(4000 BYTE)         NOT NULL,
  SERVER            VARCHAR2(50 BYTE),
  APPLICATION       VARCHAR2(300 BYTE)          NOT NULL,
  FUNCTIONNAME      VARCHAR2(100 BYTE),
  LOGEVENTTYPE      NUMBER                      NOT NULL,
  DTLOGGED          TIMESTAMP(6)                DEFAULT CURRENT_TIMESTAMP,
  RESOLUTIONSTATUS  VARCHAR2(50 BYTE)           DEFAULT 'Unresolved',
  SEVERITY          NUMBER                      NOT NULL,
  PARENTID          NUMBER,
  SITEID            VARCHAR2(25 BYTE),
  REPL_FLAG         NUMBER                      DEFAULT 0
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
-- PK_XXDOEC_DCDLOG  (Index) 
--
--  Dependencies: 
--   XXDOEC_DCDLOG (Table)
--
CREATE UNIQUE INDEX XXDO.PK_XXDOEC_DCDLOG ON XXDO.XXDOEC_DCDLOG
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
-- XXDOEC_DCDLOG_IDX1  (Index) 
--
--  Dependencies: 
--   XXDOEC_DCDLOG (Table)
--
CREATE INDEX XXDO.XXDOEC_DCDLOG_IDX1 ON XXDO.XXDOEC_DCDLOG
(CODE, APPLICATION, LOGEVENTTYPE)
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
-- XXDOEC_DCDLOG_IDX2  (Index) 
--
--  Dependencies: 
--   XXDOEC_DCDLOG (Table)
--
CREATE INDEX XXDO.XXDOEC_DCDLOG_IDX2 ON XXDO.XXDOEC_DCDLOG
(DTLOGGED)
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
-- XXDOEC_DCDLOG_IDX3  (Index) 
--
--  Dependencies: 
--   XXDOEC_DCDLOG (Table)
--
CREATE INDEX XXDO.XXDOEC_DCDLOG_IDX3 ON XXDO.XXDOEC_DCDLOG
(REPL_FLAG, DTLOGGED)
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
-- XXDOEC_DCDLOG_IDX4  (Index) 
--
--  Dependencies: 
--   XXDOEC_DCDLOG (Table)
--
CREATE INDEX XXDO.XXDOEC_DCDLOG_IDX4 ON XXDO.XXDOEC_DCDLOG
(PARENTID)
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
-- XXDOEC_DCDLOG  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_DCDLOG (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXDOEC_DCDLOG FOR XXDO.XXDOEC_DCDLOG
/
