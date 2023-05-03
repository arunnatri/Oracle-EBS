--
-- XXDOEC_RETURN_HEADER_STAGING  (Table) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XMLTYPE (Type)
--
CREATE TABLE XXDO.XXDOEC_RETURN_HEADER_STAGING
(
  ID                    NUMBER                  NOT NULL,
  ORDER_ID              VARCHAR2(50 BYTE)       NOT NULL,
  ORIGINAL_DW_ORDER_ID  VARCHAR2(50 BYTE),
  ORDER_DATE            DATE                    NOT NULL,
  CURRENCY              VARCHAR2(15 BYTE),
  DW_CUSTOMER_ID        VARCHAR2(50 BYTE)       NOT NULL,
  ORACLE_CUSTOMER_ID    NUMBER                  NOT NULL,
  BILL_TO_ADDR_ID       NUMBER                  NOT NULL,
  SHIP_TO_ADDR_ID       NUMBER                  NOT NULL,
  ORDER_TOTAL           NUMBER,
  NET_ORDER_TOTAL       NUMBER,
  TOTAL_ORDER_TAX       NUMBER,
  SITE_ID               VARCHAR2(100 BYTE)      NOT NULL,
  RETURN_TYPE           VARCHAR2(25 BYTE)       NOT NULL,
  XMLPAYLOAD            SYS.XMLTYPE
)
XMLTYPE XMLPAYLOAD STORE AS SECUREFILE BINARY XML (
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
-- PK_ID  (Index) 
--
--  Dependencies: 
--   XXDOEC_RETURN_HEADER_STAGING (Table)
--
CREATE UNIQUE INDEX XXDO.PK_ID ON XXDO.XXDOEC_RETURN_HEADER_STAGING
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

ALTER TABLE XXDO.XXDOEC_RETURN_HEADER_STAGING ADD (
  CONSTRAINT PK_ID
  PRIMARY KEY
  (ID)
  USING INDEX XXDO.PK_ID
  ENABLE VALIDATE)
/


--
-- XXDOEC_ORDER_ID_IDX1  (Index) 
--
--  Dependencies: 
--   XXDOEC_RETURN_HEADER_STAGING (Table)
--
CREATE INDEX XXDO.XXDOEC_ORDER_ID_IDX1 ON XXDO.XXDOEC_RETURN_HEADER_STAGING
(ORDER_ID)
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
