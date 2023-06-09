--
-- XXD_MSC_DEMANDS_CORRECT_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_MSC_DEMANDS_CORRECT_STG_T
(
  HEADER_ID                NUMBER,
  ORG_ID                   NUMBER,
  ORDER_NUMBER             VARCHAR2(50 BYTE),
  ORDER_TYPE_ID            NUMBER,
  LINE_ID                  NUMBER,
  ORDERED_ITEM             VARCHAR2(50 BYTE),
  OVERRIDE_ATP_DATE_CODE   VARCHAR2(30 BYTE),
  SCHEDULE_SHIP_DATE       DATE,
  PLAN_ID                  NUMBER,
  OVERALL_STATUS           VARCHAR2(2 BYTE),
  RESCHEDULE_STATUS        VARCHAR2(2 BYTE),
  ATP_OVERRIDE_UPD_STATUS  VARCHAR2(2 BYTE),
  REQUEST_ID               NUMBER,
  CREATION_DATE            DATE,
  CREATED_BY               NUMBER,
  SEQ_NUMBER               NUMBER
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
-- XXD_MSC_DEMANDS_CORRECT_STG_N1  (Index) 
--
--  Dependencies: 
--   XXD_MSC_DEMANDS_CORRECT_STG_T (Table)
--
CREATE INDEX XXDO.XXD_MSC_DEMANDS_CORRECT_STG_N1 ON XXDO.XXD_MSC_DEMANDS_CORRECT_STG_T
(OVERALL_STATUS, REQUEST_ID, SEQ_NUMBER)
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
-- XXD_MSC_DEMANDS_CORRECT_STG_N2  (Index) 
--
--  Dependencies: 
--   XXD_MSC_DEMANDS_CORRECT_STG_T (Table)
--
CREATE INDEX XXDO.XXD_MSC_DEMANDS_CORRECT_STG_N2 ON XXDO.XXD_MSC_DEMANDS_CORRECT_STG_T
(HEADER_ID, LINE_ID, REQUEST_ID)
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
