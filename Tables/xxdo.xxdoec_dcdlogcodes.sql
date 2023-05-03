--
-- XXDOEC_DCDLOGCODES  (Table) 
--
CREATE TABLE XXDO.XXDOEC_DCDLOGCODES
(
  CODE          NUMBER                          NOT NULL,
  DESCRIPTION   VARCHAR2(3000 BYTE),
  APPLICATION   VARCHAR2(300 BYTE)              NOT NULL,
  LOGTYPE       NUMBER                          DEFAULT 1,
  ACTIVE        NUMBER                          DEFAULT 1,
  FUNCTIONNAME  VARCHAR2(100 BYTE)
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
-- PK_XXDOEC_DCDLOGCODES  (Index) 
--
--  Dependencies: 
--   XXDOEC_DCDLOGCODES (Table)
--
CREATE UNIQUE INDEX XXDO.PK_XXDOEC_DCDLOGCODES ON XXDO.XXDOEC_DCDLOGCODES
(CODE)
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
-- XXDOEC_DCDLOGCODES_IDX1  (Index) 
--
--  Dependencies: 
--   XXDOEC_DCDLOGCODES (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOEC_DCDLOGCODES_IDX1 ON XXDO.XXDOEC_DCDLOGCODES
(CODE, APPLICATION, LOGTYPE)
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
-- XXDOEC_DCDLOGCODES  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_DCDLOGCODES (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXDOEC_DCDLOGCODES FOR XXDO.XXDOEC_DCDLOGCODES
/
