--
-- XXD_HYP_INB_FORECAST_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_HYP_INB_FORECAST_STG_T
(
  FISCAL_YEAR            VARCHAR2(1000 BYTE),
  CURRENCY               VARCHAR2(1000 BYTE),
  SCENARIO               VARCHAR2(1000 BYTE),
  VERSION                VARCHAR2(1000 BYTE),
  COMPANY                VARCHAR2(1000 BYTE),
  BRAND                  VARCHAR2(1000 BYTE),
  CHANNEL                VARCHAR2(1000 BYTE),
  REGION                 VARCHAR2(1000 BYTE),
  DEPARTMENT             VARCHAR2(1000 BYTE),
  ACCOUNT                VARCHAR2(1000 BYTE),
  INTER_COMPANY          VARCHAR2(1000 BYTE),
  PERIOD_NAME            VARCHAR2(1000 BYTE),
  BUDGET_AMOUNT          VARCHAR2(1000 BYTE),
  FUTURE_SEGMENT         VARCHAR2(1000 BYTE)    DEFAULT '1000',
  CONCATENATED_SEGMENTS  VARCHAR2(1000 BYTE),
  CODE_COMBINATION_ID    NUMBER,
  ADDITIONAL_FIELD1      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD2      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD3      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD4      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD5      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD6      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD7      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD8      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD9      VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD10     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD11     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD12     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD13     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD14     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD15     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD16     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD17     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD18     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD19     VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD20     VARCHAR2(1000 BYTE),
  ACTIVE_FLAG            VARCHAR2(1 BYTE)       DEFAULT 'Y',
  CONSUMED_FLAG          VARCHAR2(1 BYTE)       DEFAULT 'N',
  PERIOD_START_DATE      DATE,
  REC_STATUS             VARCHAR2(1 BYTE)       DEFAULT 'N',
  ERROR_MSG              VARCHAR2(4000 BYTE),
  CREATED_BY             NUMBER,
  CREATION_DATE          DATE,
  LAST_UPDATE_DATE       DATE,
  LAST_UPDATED_BY        NUMBER,
  REQUEST_ID             NUMBER,
  FILENAME               VARCHAR2(1000 BYTE)
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
-- XXD_HYP_INB_FORECAST_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_HYP_INB_FORECAST_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_HYP_INB_FORECAST_STG_T FOR XXDO.XXD_HYP_INB_FORECAST_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_HYP_INB_FORECAST_STG_T TO APPS
/
