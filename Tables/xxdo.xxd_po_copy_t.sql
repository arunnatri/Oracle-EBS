--
-- XXD_PO_COPY_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_COPY_T
(
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    VARCHAR2(100 BYTE),
  LAST_UPDATE_LOGIN  VARCHAR2(100 BYTE),
  CREATION_DATE      DATE,
  CREATED_BY         VARCHAR2(100 BYTE),
  OLD_PO_NUM         VARCHAR2(100 BYTE),
  NEW_PO_NUM         VARCHAR2(100 BYTE),
  OLD_PO_LINE_NUM    NUMBER,
  NEW_PO_LINE_NUM    NUMBER
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
-- XXD_PO_COPY_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_COPY_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_COPY_T FOR XXDO.XXD_PO_COPY_T
/


GRANT SELECT ON XXDO.XXD_PO_COPY_T TO APPSRO WITH GRANT OPTION
/
