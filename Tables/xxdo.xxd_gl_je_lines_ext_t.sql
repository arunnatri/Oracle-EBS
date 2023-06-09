--
-- XXD_GL_JE_LINES_EXT_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_JE_LINES_EXT_T
(
  JE_HEADER_ID         NUMBER,
  JE_LINE_NUM          NUMBER,
  LEDGER_ID            NUMBER,
  CODE_COMBINATION_ID  NUMBER,
  PERIOD_NAME          VARCHAR2(100 BYTE),
  GLOBAL_ATTRIBUTE1    VARCHAR2(100 BYTE),
  REQUEST_ID           NUMBER,
  CREATION_DATE        DATE
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
