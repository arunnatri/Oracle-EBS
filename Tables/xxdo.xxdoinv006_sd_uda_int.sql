--
-- XXDOINV006_SD_UDA_INT  (Table) 
--
CREATE TABLE XXDO.XXDOINV006_SD_UDA_INT
(
  SLNO               NUMBER,
  SERVICETYPE        VARCHAR2(30 BYTE),
  ITEM_TYPE          VARCHAR2(30 BYTE),
  OPERATION          VARCHAR2(30 BYTE),
  INVENTORY_ITEM_ID  NUMBER,
  ORGANIZATION_ID    NUMBER,
  STYLE              VARCHAR2(40 BYTE),
  COLOR              VARCHAR2(40 BYTE),
  SZE                VARCHAR2(40 BYTE),
  ITEM_STATUS        VARCHAR2(40 BYTE),
  SUB_DIVISION       VARCHAR2(40 BYTE),
  STATUS_FLAG        VARCHAR2(10 BYTE)          DEFAULT 'N',
  PROCESSED_FLAG     VARCHAR2(10 BYTE)          DEFAULT 'N',
  TRANSMISSION_DATE  TIMESTAMP(6),
  ERRORCODE          VARCHAR2(240 BYTE),
  XDATA              CLOB,
  RETVAL             CLOB,
  PARENT_REQUEST_ID  NUMBER,
  CHILD_REQUEST_ID   NUMBER,
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER
)
LOB (RETVAL) STORE AS BASICFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING
  STORAGE    (
              INITIAL          64K
              NEXT             1M
              MINEXTENTS       1
              MAXEXTENTS       UNLIMITED
              PCTINCREASE      0
              BUFFER_POOL      DEFAULT
             ))
LOB (XDATA) STORE AS BASICFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING
  STORAGE    (
              INITIAL          64K
              NEXT             1M
              MINEXTENTS       1
              MAXEXTENTS       UNLIMITED
              PCTINCREASE      0
              BUFFER_POOL      DEFAULT
             ))
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


ALTER TABLE XXDO.XXDOINV006_SD_UDA_INT ADD (
  PRIMARY KEY
  (SLNO)
  USING INDEX
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
  ENABLE VALIDATE)
/


--  There is no statement for index XXDO.SYS_C001083957.
--  The object is created when the parent object is created.

--
-- XXDOINV006_SD_UDA_INT  (Synonym) 
--
--  Dependencies: 
--   XXDOINV006_SD_UDA_INT (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOINV006_SD_UDA_INT FOR XXDO.XXDOINV006_SD_UDA_INT
/
