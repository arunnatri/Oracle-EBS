--
-- XXD_FND_CONCURRENT_REQUESTS  (Table) 
--
CREATE TABLE XXDO.XXD_FND_CONCURRENT_REQUESTS
(
  REQUEST_ID                     NUMBER(15)     NOT NULL,
  LAST_UPDATE_DATE               DATE           NOT NULL,
  LAST_UPDATED_BY                NUMBER(15)     NOT NULL,
  REQUEST_DATE                   DATE           NOT NULL,
  REQUESTED_BY                   NUMBER(15)     NOT NULL,
  PHASE_CODE                     VARCHAR2(1 BYTE) NOT NULL,
  STATUS_CODE                    VARCHAR2(1 BYTE) NOT NULL,
  PRIORITY_REQUEST_ID            NUMBER(15)     NOT NULL,
  PRIORITY                       NUMBER(15)     NOT NULL,
  REQUESTED_START_DATE           DATE           NOT NULL,
  HOLD_FLAG                      VARCHAR2(1 BYTE) NOT NULL,
  ENFORCE_SERIALITY_FLAG         VARCHAR2(1 BYTE) NOT NULL,
  SINGLE_THREAD_FLAG             VARCHAR2(1 BYTE) NOT NULL,
  HAS_SUB_REQUEST                VARCHAR2(1 BYTE) NOT NULL,
  IS_SUB_REQUEST                 VARCHAR2(1 BYTE) NOT NULL,
  IMPLICIT_CODE                  VARCHAR2(1 BYTE) NOT NULL,
  UPDATE_PROTECTED               VARCHAR2(1 BYTE) NOT NULL,
  QUEUE_METHOD_CODE              VARCHAR2(1 BYTE) NOT NULL,
  ARGUMENT_INPUT_METHOD_CODE     VARCHAR2(1 BYTE) NOT NULL,
  ORACLE_ID                      NUMBER(15)     NOT NULL,
  PROGRAM_APPLICATION_ID         NUMBER(15)     NOT NULL,
  CONCURRENT_PROGRAM_ID          NUMBER(15)     NOT NULL,
  RESPONSIBILITY_APPLICATION_ID  NUMBER(15)     NOT NULL,
  RESPONSIBILITY_ID              NUMBER(15)     NOT NULL,
  NUMBER_OF_ARGUMENTS            NUMBER(3)      NOT NULL,
  NUMBER_OF_COPIES               NUMBER(15)     NOT NULL,
  SAVE_OUTPUT_FLAG               VARCHAR2(1 BYTE) NOT NULL,
  NLS_COMPLIANT                  VARCHAR2(1 BYTE) NOT NULL,
  LAST_UPDATE_LOGIN              NUMBER(15),
  NLS_LANGUAGE                   VARCHAR2(30 BYTE),
  NLS_TERRITORY                  VARCHAR2(30 BYTE),
  PRINTER                        VARCHAR2(30 BYTE),
  PRINT_STYLE                    VARCHAR2(30 BYTE),
  PRINT_GROUP                    VARCHAR2(1 BYTE),
  REQUEST_CLASS_APPLICATION_ID   NUMBER(15),
  CONCURRENT_REQUEST_CLASS_ID    NUMBER(15),
  PARENT_REQUEST_ID              NUMBER(15),
  CONC_LOGIN_ID                  NUMBER(15),
  LANGUAGE_ID                    NUMBER(15),
  DESCRIPTION                    VARCHAR2(240 BYTE),
  REQ_INFORMATION                VARCHAR2(240 BYTE),
  RESUBMIT_INTERVAL              NUMBER(15,10),
  RESUBMIT_INTERVAL_UNIT_CODE    VARCHAR2(30 BYTE),
  RESUBMIT_INTERVAL_TYPE_CODE    VARCHAR2(30 BYTE),
  RESUBMIT_TIME                  VARCHAR2(8 BYTE),
  RESUBMIT_END_DATE              DATE,
  RESUBMITTED                    VARCHAR2(1 BYTE),
  CONTROLLING_MANAGER            NUMBER(15),
  ACTUAL_START_DATE              DATE,
  ACTUAL_COMPLETION_DATE         DATE,
  COMPLETION_TEXT                VARCHAR2(240 BYTE),
  OUTCOME_PRODUCT                VARCHAR2(20 BYTE),
  OUTCOME_CODE                   NUMBER(15),
  CPU_SECONDS                    NUMBER(15,3),
  LOGICAL_IOS                    NUMBER(15),
  PHYSICAL_IOS                   NUMBER(15),
  LOGFILE_NAME                   VARCHAR2(255 BYTE),
  LOGFILE_NODE_NAME              VARCHAR2(256 BYTE),
  OUTFILE_NAME                   VARCHAR2(255 BYTE),
  OUTFILE_NODE_NAME              VARCHAR2(256 BYTE),
  ARGUMENT_TEXT                  VARCHAR2(240 BYTE),
  ARGUMENT1                      VARCHAR2(240 BYTE),
  ARGUMENT2                      VARCHAR2(240 BYTE),
  ARGUMENT3                      VARCHAR2(240 BYTE),
  ARGUMENT4                      VARCHAR2(240 BYTE),
  ARGUMENT5                      VARCHAR2(240 BYTE),
  ARGUMENT6                      VARCHAR2(240 BYTE),
  ARGUMENT7                      VARCHAR2(240 BYTE),
  ARGUMENT8                      VARCHAR2(240 BYTE),
  ARGUMENT9                      VARCHAR2(240 BYTE),
  ARGUMENT10                     VARCHAR2(240 BYTE),
  ARGUMENT11                     VARCHAR2(240 BYTE),
  ARGUMENT12                     VARCHAR2(240 BYTE),
  ARGUMENT13                     VARCHAR2(240 BYTE),
  ARGUMENT14                     VARCHAR2(240 BYTE),
  ARGUMENT15                     VARCHAR2(240 BYTE),
  ARGUMENT16                     VARCHAR2(240 BYTE),
  ARGUMENT17                     VARCHAR2(240 BYTE),
  ARGUMENT18                     VARCHAR2(240 BYTE),
  ARGUMENT19                     VARCHAR2(240 BYTE),
  ARGUMENT20                     VARCHAR2(240 BYTE),
  ARGUMENT21                     VARCHAR2(240 BYTE),
  ARGUMENT22                     VARCHAR2(240 BYTE),
  ARGUMENT23                     VARCHAR2(240 BYTE),
  ARGUMENT24                     VARCHAR2(240 BYTE),
  ARGUMENT25                     VARCHAR2(240 BYTE),
  CRM_THRSHLD                    NUMBER(15),
  CRM_TSTMP                      DATE,
  CRITICAL                       VARCHAR2(1 BYTE),
  REQUEST_TYPE                   VARCHAR2(1 BYTE),
  ORACLE_PROCESS_ID              VARCHAR2(30 BYTE),
  ORACLE_SESSION_ID              NUMBER(15),
  OS_PROCESS_ID                  VARCHAR2(240 BYTE),
  PRINT_JOB_ID                   VARCHAR2(240 BYTE),
  OUTPUT_FILE_TYPE               VARCHAR2(4 BYTE),
  RELEASE_CLASS_APP_ID           NUMBER,
  RELEASE_CLASS_ID               NUMBER,
  STALE_DATE                     DATE,
  CANCEL_OR_HOLD                 VARCHAR2(1 BYTE),
  NOTIFY_ON_PP_ERROR             VARCHAR2(255 BYTE),
  CD_ID                          NUMBER,
  REQUEST_LIMIT                  VARCHAR2(1 BYTE),
  CRM_RELEASE_DATE               DATE,
  POST_REQUEST_STATUS            VARCHAR2(1 BYTE),
  COMPLETION_CODE                VARCHAR2(30 BYTE),
  INCREMENT_DATES                VARCHAR2(1 BYTE),
  RESTART                        VARCHAR2(1 BYTE),
  ENABLE_TRACE                   VARCHAR2(1 BYTE),
  RESUB_COUNT                    NUMBER,
  NLS_CODESET                    VARCHAR2(30 BYTE),
  OFILE_SIZE                     NUMBER(15),
  LFILE_SIZE                     NUMBER(15),
  STALE                          VARCHAR2(1 BYTE),
  SECURITY_GROUP_ID              NUMBER,
  RESOURCE_CONSUMER_GROUP        VARCHAR2(30 BYTE),
  EXP_DATE                       DATE,
  QUEUE_APP_ID                   NUMBER(15),
  QUEUE_ID                       NUMBER(15),
  OPS_INSTANCE                   NUMBER(15)     NOT NULL,
  INTERIM_STATUS_CODE            VARCHAR2(1 BYTE),
  ROOT_REQUEST_ID                NUMBER(15),
  ORIGIN                         VARCHAR2(1 BYTE),
  NLS_NUMERIC_CHARACTERS         VARCHAR2(2 BYTE),
  PP_START_DATE                  DATE,
  PP_END_DATE                    DATE,
  ORG_ID                         NUMBER(15),
  RUN_NUMBER                     NUMBER(5),
  NODE_NAME1                     VARCHAR2(256 BYTE),
  NODE_NAME2                     VARCHAR2(256 BYTE),
  CONNSTR1                       VARCHAR2(255 BYTE),
  CONNSTR2                       VARCHAR2(255 BYTE),
  EDITION_NAME                   VARCHAR2(30 BYTE),
  RECALC_PARAMETERS              VARCHAR2(1 BYTE),
  NLS_SORT                       VARCHAR2(30 BYTE)
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
-- XXD_FND_CONCURRENT_REQUESTS  (Synonym) 
--
--  Dependencies: 
--   XXD_FND_CONCURRENT_REQUESTS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_FND_CONCURRENT_REQUESTS FOR XXDO.XXD_FND_CONCURRENT_REQUESTS
/
