--
-- XXD_ONT_GENESIS_HDR_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_GENESIS_HDR_STG_T
(
  BATCH_ID          NUMBER,
  ORG_ID            NUMBER,
  BRAND             VARCHAR2(30 BYTE),
  WAREHOUSE         VARCHAR2(10 BYTE),
  STATUS            VARCHAR2(30 BYTE),
  SALESREP_ID       NUMBER,
  CREATED_BY        NUMBER,
  LAST_UPDATED_BY   NUMBER,
  CREATION_DATE     DATE,
  LAST_UPDATE_DATE  DATE
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_ONT_GENESIS_HDR_STG_T TO APPS
/
