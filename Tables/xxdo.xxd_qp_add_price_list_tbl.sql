--
-- XXD_QP_ADD_PRICE_LIST_TBL  (Table) 
--
CREATE TABLE XXDO.XXD_QP_ADD_PRICE_LIST_TBL
(
  SEQUENCE_ID         NUMBER(15),
  PRICE_LIST_NAME     VARCHAR2(400 BYTE)        NOT NULL,
  PRODUCT_CONTEXT     VARCHAR2(400 BYTE)        NOT NULL,
  PRODUCT_ATTRIBUTE   VARCHAR2(300 BYTE)        NOT NULL,
  PRODUCT_VALUE       VARCHAR2(300 BYTE)        NOT NULL,
  UOM                 VARCHAR2(200 BYTE),
  PRICE               NUMBER(20,4)              NOT NULL,
  BRAND               VARCHAR2(100 BYTE),
  SEASON              VARCHAR2(300 BYTE),
  VALID_FROM_DATE     DATE,
  VALID_TO_DATE       DATE,
  RECORD_STATUS       VARCHAR2(300 BYTE)        NOT NULL,
  REQUEST_ID          NUMBER,
  FILE_NAME           VARCHAR2(150 BYTE),
  IMPORT_FLAG         VARCHAR2(5 BYTE),
  EXPORT_FLAG         VARCHAR2(5 BYTE),
  CREATION_DATE       DATE,
  CREATED_BY          VARCHAR2(100 BYTE),
  UPDATE_DATE         DATE,
  LAST_UPDATE_BY      VARCHAR2(100 BYTE),
  APPLICATION_METHOD  VARCHAR2(50 BYTE),
  STATUS              VARCHAR2(10 BYTE),
  ERROR_MESSAGE       VARCHAR2(3000 BYTE)
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
-- XXD_QP_ADD_PRICE_LIST_INDX  (Index) 
--
--  Dependencies: 
--   XXD_QP_ADD_PRICE_LIST_TBL (Table)
--
CREATE INDEX APPS.XXD_QP_ADD_PRICE_LIST_INDX ON XXDO.XXD_QP_ADD_PRICE_LIST_TBL
(PRICE_LIST_NAME, PRODUCT_CONTEXT, PRODUCT_ATTRIBUTE, PRODUCT_VALUE, UOM)
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
-- XXD_QP_ADD_STATUS_IND  (Index) 
--
--  Dependencies: 
--   XXD_QP_ADD_PRICE_LIST_TBL (Table)
--
CREATE INDEX APPS.XXD_QP_ADD_STATUS_IND ON XXDO.XXD_QP_ADD_PRICE_LIST_TBL
(STATUS)
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
-- XXD_QP_ADD_PRICE_LIST_TBL  (Synonym) 
--
--  Dependencies: 
--   XXD_QP_ADD_PRICE_LIST_TBL (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_QP_ADD_PRICE_LIST_TBL FOR XXDO.XXD_QP_ADD_PRICE_LIST_TBL
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_QP_ADD_PRICE_LIST_TBL TO APPS
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_QP_ADD_PRICE_LIST_TBL TO XXD_CONV
/
