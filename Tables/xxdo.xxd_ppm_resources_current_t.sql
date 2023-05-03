--
-- XXD_PPM_RESOURCES_CURRENT_T  (Table) 
--
CREATE TABLE XXDO.XXD_PPM_RESOURCES_CURRENT_T
(
  RESOURCE_CODE            VARCHAR2(10 BYTE)    NOT NULL,
  SHORT_NAME               VARCHAR2(15 BYTE),
  COST_TYPE                VARCHAR2(1 BYTE),
  COST_VALUE               NUMBER,
  COST_UNIT                VARCHAR2(1 BYTE),
  COST_COEF                NUMBER,
  TYPE                     VARCHAR2(2 BYTE),
  CALENDAR                 VARCHAR2(10 BYTE),
  REPORT_DATE              DATE,
  C_FACTOR                 NUMBER,
  USAGE_MAX                NUMBER,
  NB                       NUMBER,
  LOGON_ID                 VARCHAR2(10 BYTE),
  HOUR_WEEK                NUMBER,
  CUTOFF                   DATE,
  EARLIEST_PERIOD          DATE,
  LATEST_PERIOD            DATE,
  JOB_CODE                 VARCHAR2(10 BYTE),
  LOGS_EXPIRE              NUMBER,
  START_DATE               DATE,
  TERM_DATE                DATE,
  COST_CODE                VARCHAR2(10 BYTE),
  TS_NUM                   NUMBER,
  TS_FIRST                 NUMBER,
  TS_LAST                  NUMBER,
  AP_NEEDED                NUMBER,
  TS_DISAPPROVED           NUMBER,
  REIMBURSE_CURRENCY_CODE  VARCHAR2(10 BYTE),
  TB_CALENDAR              VARCHAR2(10 BYTE),
  ORG_RES_CODE             VARCHAR2(10 BYTE),
  IMAGE_ID                 NUMBER,
  TS_LAST_SIGNED           NUMBER,
  LAST_UPDATED_BY          VARCHAR2(10 BYTE),
  LAST_UPDATED_ON          DATE,
  DELETED_IND              VARCHAR2(1 BYTE)
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
