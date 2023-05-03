--
-- XXDOINT_AR_CUST_UPD_BATCH_IMG  (Table) 
--
CREATE TABLE XXDO.XXDOINT_AR_CUST_UPD_BATCH_IMG
(
  BATCH_ID     NUMBER,
  CUSTOMER_ID  NUMBER,
  ORG_ID       NUMBER,
  BATCH_DATE   DATE
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
-- XXD_AR_CUST_UPD_BAT_H_IDX1  (Index) 
--
--  Dependencies: 
--   XXDOINT_AR_CUST_UPD_BATCH_IMG (Table)
--
CREATE INDEX XXDO.XXD_AR_CUST_UPD_BAT_H_IDX1 ON XXDO.XXDOINT_AR_CUST_UPD_BATCH_IMG
(CUSTOMER_ID, ORG_ID)
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
