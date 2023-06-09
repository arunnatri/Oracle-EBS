--
-- XXD_IEX_COLLECT_FORM_JOB_ID_T  (Table) 
--
CREATE TABLE XXDO.XXD_IEX_COLLECT_FORM_JOB_ID_T
(
  PROCEDURE_NAME     VARCHAR2(100 BYTE),
  JOB_ID             NUMBER,
  PARTY_ID           NUMBER,
  CUST_ACCOUNT_ID    NUMBER,
  SESSION_ID         NUMBER,
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATED_DATE  DATE,
  LAST_UPDATED_BY    NUMBER
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
-- XXD_IEX_COLLECT_FORM_JOB_ID_T  (Synonym) 
--
--  Dependencies: 
--   XXD_IEX_COLLECT_FORM_JOB_ID_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_IEX_COLLECT_FORM_JOB_ID_T FOR XXDO.XXD_IEX_COLLECT_FORM_JOB_ID_T
/
