--
-- XXD_CE_CASHFLOW_DATA_T  (Table) 
--
CREATE TABLE XXDO.XXD_CE_CASHFLOW_DATA_T
(
  CASHFLOW_ID       NUMBER,
  REQUEST_ID        NUMBER,
  CREATION_DATE     DATE,
  CREATED_BY        NUMBER,
  LAST_UPDATE_DATE  DATE,
  LAST_UPDATED_BY   NUMBER
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
