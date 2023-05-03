--
-- XXDO_ONT_RMA_XML_STG  (Table) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XMLTYPE (Type)
--
CREATE TABLE XXDO.XXDO_ONT_RMA_XML_STG
(
  PROCESS_STATUS    VARCHAR2(30 BYTE),
  XML_DOCUMENT      SYS.XMLTYPE,
  FILE_NAME         VARCHAR2(50 BYTE),
  ERROR_MESSAGE     VARCHAR2(2000 BYTE),
  REQUEST_ID        NUMBER                      NOT NULL,
  CREATION_DATE     DATE                        NOT NULL,
  CREATED_BY        NUMBER                      NOT NULL,
  LAST_UPDATE_DATE  DATE                        NOT NULL,
  LAST_UPDATED_BY   NUMBER                      NOT NULL,
  RECORD_TYPE       VARCHAR2(100 BYTE),
  RMA_XML_SEQ_ID    NUMBER,
  MESSAGE_ID        VARCHAR2(50 BYTE)
)
XMLTYPE XML_DOCUMENT STORE AS SECUREFILE BINARY XML (
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
-- XXDO_ONT_RMA_XML_STG_UK1  (Index) 
--
--  Dependencies: 
--   XXDO_ONT_RMA_XML_STG (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_ONT_RMA_XML_STG_UK1 ON XXDO.XXDO_ONT_RMA_XML_STG
(RMA_XML_SEQ_ID)
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
-- XXDO_ONT_RMA_XML_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_ONT_RMA_XML_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_ONT_RMA_XML_STG FOR XXDO.XXDO_ONT_RMA_XML_STG
/


--
-- XXDO_ONT_RMA_XML_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_ONT_RMA_XML_STG (Table)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_ONT_RMA_XML_STG FOR XXDO.XXDO_ONT_RMA_XML_STG
/


GRANT DELETE, INSERT, SELECT, UPDATE ON XXDO.XXDO_ONT_RMA_XML_STG TO SOA_INT
/
