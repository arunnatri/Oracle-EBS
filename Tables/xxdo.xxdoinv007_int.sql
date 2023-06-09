--
-- XXDOINV007_INT  (Table) 
--
CREATE TABLE XXDO.XXDOINV007_INT
(
  SLNO               NUMBER,
  SERVICETYPE        VARCHAR2(30 BYTE),
  ITEM_TYPE          VARCHAR2(30 BYTE),
  STYLE_VALUE        VARCHAR2(40 BYTE),
  ITEM_STATUS        VARCHAR2(40 BYTE),
  ITEM_DESCRIPTION   VARCHAR2(240 BYTE),
  INVENTORY_ITEM_ID  NUMBER,
  ORGANIZATION_ID    NUMBER,
  STORE_WAREHOUSE    VARCHAR2(25 BYTE),
  OPERATION          VARCHAR2(30 BYTE),
  STATUS_FLAG        VARCHAR2(10 BYTE)          DEFAULT 'N',
  PROCESSED_FLAG     VARCHAR2(10 BYTE)          DEFAULT 'N',
  TRANSMISSION_DATE  TIMESTAMP(6)               DEFAULT SYSDATE,
  REGION             VARCHAR2(30 BYTE),
  ERRORCODE          VARCHAR2(240 BYTE),
  XDATA              CLOB,
  RETVAL             CLOB
)
LOB (RETVAL) STORE AS BASICFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING)
LOB (XDATA) STORE AS BASICFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING)
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
-- XXDOINV007_INT_N1  (Index) 
--
--  Dependencies: 
--   XXDOINV007_INT (Table)
--
CREATE INDEX XXDO.XXDOINV007_INT_N1 ON XXDO.XXDOINV007_INT
(INVENTORY_ITEM_ID, ORGANIZATION_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXDOINV007_INT_N4  (Index) 
--
--  Dependencies: 
--   XXDOINV007_INT (Table)
--
CREATE INDEX XXDO.XXDOINV007_INT_N4 ON XXDO.XXDOINV007_INT
(STYLE_VALUE)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXDOINV007_INT_U1  (Index) 
--
--  Dependencies: 
--   XXDOINV007_INT (Table)
--
CREATE INDEX XXDO.XXDOINV007_INT_U1 ON XXDO.XXDOINV007_INT
(SLNO)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXDOINV007_INT  (Synonym) 
--
--  Dependencies: 
--   XXDOINV007_INT (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOINV007_INT FOR XXDO.XXDOINV007_INT
/


--
-- XXDOINV007_INT  (Synonym) 
--
--  Dependencies: 
--   XXDOINV007_INT (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXDOINV007_INT FOR XXDO.XXDOINV007_INT
/
