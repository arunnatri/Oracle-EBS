--
-- XXDO_INV_INT_028_STG1  (Table) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XMLTYPE (Type)
--
CREATE TABLE XXDO.XXDO_INV_INT_028_STG1
(
  XML_ID            NUMBER,
  XML_DATA          CLOB,
  STATUS            NUMBER,
  UPDATE_TIMESTAMP  DATE,
  XML_TYPE_DATA     SYS.XMLTYPE
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
LOB (XML_DATA) STORE AS BASICFILE (
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


--
-- XXDO_INV_INT_028_STG1  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_INT_028_STG1 (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_INT_028_STG1 FOR XXDO.XXDO_INV_INT_028_STG1
/


GRANT SELECT ON XXDO.XXDO_INV_INT_028_STG1 TO APPSRO
/
