--
-- XXDO_INV_INT_008_ARCHIVE  (Table) 
--
CREATE TABLE XXDO.XXDO_INV_INT_008_ARCHIVE
(
  DC_DEST_ID              VARCHAR2(100 BYTE),
  ITEM_ID                 VARCHAR2(225 BYTE),
  ADJUSTMENT_REASON_CODE  NUMBER,
  UNIT_QTY                NUMBER(12,4),
  TRANSSHIPMENT_NBR       VARCHAR2(230 BYTE),
  FROM_DISPOSITION        VARCHAR2(24 BYTE),
  TO_DISPOSITION          VARCHAR2(24 BYTE),
  FROM_TROUBLE_CODE       VARCHAR2(29 BYTE),
  TO_TROUBLE_CODE         VARCHAR2(29 BYTE),
  FROM_WIP_CODE           VARCHAR2(29 BYTE),
  TO_WIP_CODE             VARCHAR2(29 BYTE),
  TRANSACTION_CODE        NUMBER(4),
  USER_ID                 VARCHAR2(230 BYTE),
  CREATE_DATE             DATE,
  PO_NBR                  VARCHAR2(210 BYTE),
  DOC_TYPE                VARCHAR2(21 BYTE),
  AUX_REASON_CODE         VARCHAR2(24 BYTE),
  WEIGHT                  NUMBER(12,4),
  WEIGHT_UOM              VARCHAR2(24 BYTE),
  UNIT_COST               NUMBER(20,4),
  STATUS                  VARCHAR2(24 BYTE)     DEFAULT 'N',
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATE_BY          NUMBER,
  SKU                     VARCHAR2(100 BYTE),
  ITEM_DESCRIPTION        VARCHAR2(100 BYTE),
  FREE_ATP_Q              NUMBER,
  NO_FREE_ATP_Q           NUMBER,
  LOAD_TYPE               VARCHAR2(100 BYTE),
  SEQ_NO                  NUMBER,
  PROCESSED_FLAG          VARCHAR2(240 BYTE),
  TRANSMISSION_DATE       DATE,
  ERRORCODE               VARCHAR2(240 BYTE),
  XMLDATA                 CLOB,
  RETVAL                  CLOB,
  REQUEST_LEG             NUMBER,
  REQUEST_ID              NUMBER
)
LOB (RETVAL) STORE AS SECUREFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING
  STORAGE    (
              INITIAL          104K
              NEXT             1M
              MINEXTENTS       1
              MAXEXTENTS       UNLIMITED
              PCTINCREASE      0
              BUFFER_POOL      DEFAULT
             ))
LOB (XMLDATA) STORE AS SECUREFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING
  STORAGE    (
              INITIAL          104K
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


--
-- XXDO_INV_INT_008_ARCHIVE_U1  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_008_ARCHIVE (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_INV_INT_008_ARCHIVE_U1 ON XXDO.XXDO_INV_INT_008_ARCHIVE
(SEQ_NO)
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
-- XXDO_INV_INT_008_ARCHIVE_INDX  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_008_ARCHIVE (Table)
--
CREATE INDEX XXDO.XXDO_INV_INT_008_ARCHIVE_INDX ON XXDO.XXDO_INV_INT_008_ARCHIVE
(DC_DEST_ID)
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
-- XXDO_INV_INT_008_ARCHIVE_N1  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_008_ARCHIVE (Table)
--
CREATE INDEX APPS.XXDO_INV_INT_008_ARCHIVE_N1 ON XXDO.XXDO_INV_INT_008_ARCHIVE
(DC_DEST_ID, ITEM_ID)
LOGGING
TABLESPACE APPS_TS_TX_DATA
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXDO_INV_INT_008_ARCHIVE_N51  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_008_ARCHIVE (Table)
--
CREATE INDEX XXDO.XXDO_INV_INT_008_ARCHIVE_N51 ON XXDO.XXDO_INV_INT_008_ARCHIVE
(REQUEST_ID)
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
-- XXDO_INV_INT_008_ARCHIVE_N6  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_008_ARCHIVE (Table)
--
CREATE INDEX XXDO.XXDO_INV_INT_008_ARCHIVE_N6 ON XXDO.XXDO_INV_INT_008_ARCHIVE
(REQUEST_LEG)
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
