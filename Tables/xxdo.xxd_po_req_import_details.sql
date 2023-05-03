--
-- XXD_PO_REQ_IMPORT_DETAILS  (Table) 
--
CREATE TABLE XXDO.XXD_PO_REQ_IMPORT_DETAILS
(
  REQUEST_SET_REQUEST_ID        NUMBER,
  CUSTOM_REQ_IMPORT_REQUEST_ID  NUMBER,
  REQ_IMPORT_REQUEST_ID         NUMBER,
  ORG_ID                        NUMBER,
  CREATED_BY                    NUMBER,
  CREATION_DATE                 DATE,
  LAST_UPDATED_BY               NUMBER,
  LAST_UPDATE_DATE              DATE
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
-- XXD_PO_REQ_IMPORT_DETAILS  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_REQ_IMPORT_DETAILS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_REQ_IMPORT_DETAILS FOR XXDO.XXD_PO_REQ_IMPORT_DETAILS
/