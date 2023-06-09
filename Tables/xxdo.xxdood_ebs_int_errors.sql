--
-- XXDOOD_EBS_INT_ERRORS  (Table) 
--
CREATE TABLE XXDO.XXDOOD_EBS_INT_ERRORS
(
  ERROR_CODE     VARCHAR2(120 BYTE),
  RETURN_STATUS  VARCHAR2(1 BYTE),
  MSG_COUNT      NUMBER,
  MSG_DATA       VARCHAR2(2000 BYTE),
  CREATION_DATE  DATE,
  CREATED_BY     VARCHAR2(120 BYTE)
)
TABLESPACE APPS_TS_TX_DATA
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
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
-- XXDOOD_EBS_INT_ERRORS  (Synonym) 
--
--  Dependencies: 
--   XXDOOD_EBS_INT_ERRORS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOOD_EBS_INT_ERRORS FOR XXDO.XXDOOD_EBS_INT_ERRORS
/


--
-- XXDOOD_EBS_INT_ERRORS  (Synonym) 
--
--  Dependencies: 
--   XXDOOD_EBS_INT_ERRORS (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXDOOD_EBS_INT_ERRORS FOR XXDO.XXDOOD_EBS_INT_ERRORS
/


GRANT SELECT ON XXDO.XXDOOD_EBS_INT_ERRORS TO APPSRO
/
