--
-- XXDO_INV_INT_026_STG2  (Table) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XMLTYPE (Type)
--
CREATE TABLE XXDO.XXDO_INV_INT_026_STG2
(
  SEQ_NO                NUMBER,
  DISTRO_NUMBER         VARCHAR2(100 BYTE),
  DOCUMENT_TYPE         VARCHAR2(100 BYTE),
  DC_DEST_ID            NUMBER,
  ORDER_TYPE            VARCHAR2(100 BYTE),
  PICK_NOT_BEFORE_DATE  DATE,
  PICK_NOT_AFTER_DATE   DATE,
  DEST_ID               NUMBER,
  ITEM_ID               NUMBER,
  REQUESTED_QTY         NUMBER,
  RETAIL_PRICE          NUMBER,
  SELLING_UOM           VARCHAR2(20 BYTE),
  STORE_ID_MULTI        VARCHAR2(100 BYTE),
  EXPENDITURE_FLAG      VARCHAR2(100 BYTE),
  PRIORITY              NUMBER,
  NOT_AFTER_DATE        DATE,
  DISTRO_PARENT_NBR     VARCHAR2(10 BYTE),
  EXP_DC_DATE           DATE,
  INV_TYPE              VARCHAR2(1 BYTE),
  STATUS                NUMBER,
  DELIVERY_DATE         DATE,
  CREATED_BY            NUMBER,
  CREATION_DATE         DATE,
  LAST_UPDATE_BY        NUMBER,
  LAST_UPDATE_DATE      DATE,
  ERROR_MESSAGE         VARCHAR2(4000 BYTE),
  REQUEST_ID            NUMBER,
  BRAND                 VARCHAR2(20 BYTE),
  XML_ID                NUMBER,
  SCHEDULE_CHECK        VARCHAR2(1 BYTE),
  XML_TYPE_DATA         SYS.XMLTYPE,
  CONTEXT_CODE          VARCHAR2(240 BYTE),
  CONTEXT_VALUE         VARCHAR2(240 BYTE),
  DC_VW_ID              NUMBER,
  CLASS                 VARCHAR2(1000 BYTE),
  GENDER                VARCHAR2(1000 BYTE)
)
XMLTYPE XML_TYPE_DATA STORE AS SECUREFILE BINARY XML (
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
ALLOW NONSCHEMA
DISALLOW ANYSCHEMA
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
-- INV_INT_026_STG2_STS_IDX1  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG2 (Table)
--
CREATE INDEX XXDO.INV_INT_026_STG2_STS_IDX1 ON XXDO.XXDO_INV_INT_026_STG2
(STATUS)
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
-- XXDOINV_CLASS_COL_IX1  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG2 (Table)
--
CREATE INDEX APPS.XXDOINV_CLASS_COL_IX1 ON XXDO.XXDO_INV_INT_026_STG2
(CLASS)
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
-- XXDOINV_GENDER_COL_IX1  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG2 (Table)
--
CREATE INDEX APPS.XXDOINV_GENDER_COL_IX1 ON XXDO.XXDO_INV_INT_026_STG2
(GENDER)
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
-- XXDO_INV_INT_26_U1  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG2 (Table)
--
CREATE INDEX XXDO.XXDO_INV_INT_26_U1 ON XXDO.XXDO_INV_INT_026_STG2
(SEQ_NO, DISTRO_NUMBER, XML_ID, ITEM_ID)
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
-- XXDO_INV_INT_26_U2  (Index) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG2 (Table)
--
CREATE INDEX XXDO.XXDO_INV_INT_26_U2 ON XXDO.XXDO_INV_INT_026_STG2
(ITEM_ID)
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
-- XXDO_INV_INT_026_STG2  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG2 (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_INT_026_STG2 FOR XXDO.XXDO_INV_INT_026_STG2
/


--
-- XXDO_INV_INT_026_STG2  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG2 (Table)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_INV_INT_026_STG2 FOR XXDO.XXDO_INV_INT_026_STG2
/


GRANT SELECT ON XXDO.XXDO_INV_INT_026_STG2 TO APPSRO
/

GRANT INSERT, SELECT, UPDATE ON XXDO.XXDO_INV_INT_026_STG2 TO SOA_INT
/
