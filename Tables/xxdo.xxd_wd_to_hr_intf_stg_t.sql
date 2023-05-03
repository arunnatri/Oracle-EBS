--
-- XXD_WD_TO_HR_INTF_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_WD_TO_HR_INTF_STG_T
(
  RECORD_ID               NUMBER,
  LEGAL_FIRST_NAME        VARCHAR2(150 BYTE),
  LEGAL_LAST_NAME         VARCHAR2(150 BYTE),
  EMPLOYEE_ID             VARCHAR2(30 BYTE),
  SUPERVISOR_EMP_ID       VARCHAR2(30 BYTE),
  DEPARTMENT_NAME         VARCHAR2(150 BYTE),
  POSITION_TITLE          VARCHAR2(150 BYTE),
  SUPERVISOR_FIRST_NAME   VARCHAR2(150 BYTE),
  SUPERVISOR_LAST_NAME    VARCHAR2(150 BYTE),
  LOCATION_NAME           VARCHAR2(150 BYTE),
  PER_PHONE_COUNTRY       VARCHAR2(30 BYTE),
  PER_PHONE_AREA          VARCHAR2(30 BYTE),
  PER_PHONE_NUM           VARCHAR2(30 BYTE),
  PER_PHONE_EXT           VARCHAR2(30 BYTE),
  WORK_PHONE_COUNTRY      VARCHAR2(30 BYTE),
  WORK_PHONE_AREA         VARCHAR2(30 BYTE),
  WORK_PHONE_NUM          VARCHAR2(60 BYTE),
  WORK_PHONE_EXT          VARCHAR2(30 BYTE),
  PREF_FIRST_NAME         VARCHAR2(150 BYTE),
  PREF_LAST_NAME          VARCHAR2(150 BYTE),
  EMP_TYPE                VARCHAR2(30 BYTE),
  POS_TIME_TYPE           VARCHAR2(30 BYTE),
  WORKER_TYPE             VARCHAR2(30 BYTE),
  LATEST_BUS_PROC_NAME    VARCHAR2(100 BYTE),
  TRANSACTION_REASON      VARCHAR2(150 BYTE),
  TRANSACTION_DATE        DATE,
  COUNTRY                 VARCHAR2(30 BYTE),
  EMPLOYEE_START_DATE     DATE,
  EMPLOYMENT_END_DATE     DATE,
  EMPLOYEE_EMAIL_ADDRESS  VARCHAR2(240 BYTE),
  MANAGEMENT_LEVEL        VARCHAR2(30 BYTE),
  COST_CENTER             VARCHAR2(30 BYTE),
  ADDRESS_LINE_1          VARCHAR2(240 BYTE),
  ADDRESS_LINE_2          VARCHAR2(240 BYTE),
  ADDRESS_LINE_3          VARCHAR2(240 BYTE),
  CITY                    VARCHAR2(30 BYTE),
  COUNTY                  VARCHAR2(30 BYTE),
  STATE_PROVINCE          VARCHAR2(30 BYTE),
  ZIPCODE                 VARCHAR2(30 BYTE),
  RECORD_STATUS           VARCHAR2(30 BYTE),
  ORACLE_ERR_MSG          VARCHAR2(4000 BYTE),
  WORKDAY_ERR_MSG         VARCHAR2(4000 BYTE),
  IT_ERR_MSG              VARCHAR2(4000 BYTE),
  SUCCESS_MESSAGE         VARCHAR2(4000 BYTE),
  REQUEST_ID              NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              VARCHAR2(200 BYTE),
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  LOCAL_NAME              VARCHAR2(320 BYTE)
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
-- RECORD_ID_U  (Index) 
--
--  Dependencies: 
--   XXD_WD_TO_HR_INTF_STG_T (Table)
--
CREATE UNIQUE INDEX XXDO.RECORD_ID_U ON XXDO.XXD_WD_TO_HR_INTF_STG_T
(RECORD_ID)
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

ALTER TABLE XXDO.XXD_WD_TO_HR_INTF_STG_T ADD (
  CONSTRAINT RECORD_ID_U
  UNIQUE (RECORD_ID)
  USING INDEX XXDO.RECORD_ID_U
  ENABLE VALIDATE)
/


--
-- XXD_WD_TO_HR_INTF_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_WD_TO_HR_INTF_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_WD_TO_HR_INTF_STG_T FOR XXDO.XXD_WD_TO_HR_INTF_STG_T
/


--
-- XXD_WD_TO_HR_INTF_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_WD_TO_HR_INTF_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXD_WD_TO_HR_INTF_STG_T FOR XXDO.XXD_WD_TO_HR_INTF_STG_T
/


--
-- XXD_WD_TO_HR_INTF_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_WD_TO_HR_INTF_STG_T (Table)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_WD_TO_HR_INTF_STG_T FOR XXDO.XXD_WD_TO_HR_INTF_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_WD_TO_HR_INTF_STG_T TO APPS WITH GRANT OPTION
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_WD_TO_HR_INTF_STG_T TO APPSRO WITH GRANT OPTION
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_WD_TO_HR_INTF_STG_T TO SOA_INT WITH GRANT OPTION
/