--
-- XXD_PO_MASS_MOVE_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_MASS_MOVE_STG_T
(
  BATCH_ID         NUMBER,
  BATCH_NAME       VARCHAR2(50 BYTE),
  PO_NUMBER        VARCHAR2(20 BYTE)            NOT NULL,
  STATUS           VARCHAR2(1 BYTE)             DEFAULT 'R'                   NOT NULL,
  CREATION_DATE    DATE                         DEFAULT SYSDATE               NOT NULL,
  CREATED_BY       NUMBER,
  ERROR_MESSAGE    VARCHAR2(2000 BYTE),
  GTN_UPDATE_FLAG  VARCHAR2(1 BYTE),
  REQUEST_ID       NUMBER
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
-- XXD_PO_MASS_MOVE_STG_U1  (Index) 
--
--  Dependencies: 
--   XXD_PO_MASS_MOVE_STG_T (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_PO_MASS_MOVE_STG_U1 ON XXDO.XXD_PO_MASS_MOVE_STG_T
(PO_NUMBER)
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
-- XXD_PO_MASS_MOVE_STG_N1  (Index) 
--
--  Dependencies: 
--   XXD_PO_MASS_MOVE_STG_T (Table)
--
CREATE INDEX XXDO.XXD_PO_MASS_MOVE_STG_N1 ON XXDO.XXD_PO_MASS_MOVE_STG_T
(BATCH_ID)
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
-- XXD_PO_MASS_MOVE_STG_N2  (Index) 
--
--  Dependencies: 
--   XXD_PO_MASS_MOVE_STG_T (Table)
--
CREATE INDEX XXDO.XXD_PO_MASS_MOVE_STG_N2 ON XXDO.XXD_PO_MASS_MOVE_STG_T
(BATCH_NAME)
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

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_PO_MASS_MOVE_STG_T TO APPSRO
/
