--
-- XXD_3PL_LC_INT_DEBUG_T  (Table) 
--
CREATE TABLE XXDO.XXD_3PL_LC_INT_DEBUG_T
(
  CREATION_DATE  DATE,
  LOG_MESSAGE    VARCHAR2(4000 BYTE),
  CREATED_BY     NUMBER,
  SESSION_ID     NUMBER,
  SEQ_NUMBER     VARCHAR2(2000 BYTE)
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