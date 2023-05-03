--
-- XXD_ORDER_IMPORT_REQUESTS  (Table) 
--
CREATE TABLE XXDO.XXD_ORDER_IMPORT_REQUESTS
(
  MAIN_REQUEST_ID  NUMBER,
  REQUEST_ID       NUMBER,
  ORDER_TYPE       VARCHAR2(10 BYTE)
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
-- XXD_ORDER_IMPORT_REQUESTS  (Synonym) 
--
--  Dependencies: 
--   XXD_ORDER_IMPORT_REQUESTS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ORDER_IMPORT_REQUESTS FOR XXDO.XXD_ORDER_IMPORT_REQUESTS
/