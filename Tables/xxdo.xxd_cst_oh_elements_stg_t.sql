--
-- XXD_CST_OH_ELEMENTS_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_CST_OH_ELEMENTS_STG_T
(
  STYLE_NUMBER        VARCHAR2(1000 BYTE),
  STYLE_COLOR         VARCHAR2(1000 BYTE),
  ITEM_SIZE           VARCHAR2(1000 BYTE),
  ITEM_NUMBER         VARCHAR2(1000 BYTE),
  INVENTORY_ITEM_ID   VARCHAR2(1000 BYTE),
  DEPARTMENT          VARCHAR2(1000 BYTE),
  ORGANIZATION_ID     NUMBER,
  ORGANIZATION_CODE   VARCHAR2(1000 BYTE),
  COUNTRY             VARCHAR2(1000 BYTE),
  BRAND               VARCHAR2(1000 BYTE),
  REGION              VARCHAR2(1000 BYTE),
  DUTY                VARCHAR2(1000 BYTE),
  PRIMARY_DUTY_FLAG   VARCHAR2(1 BYTE),
  DUTY_START_DATE     DATE,
  DUTY_END_DATE       DATE,
  FREIGHT             VARCHAR2(1000 BYTE),
  FREIGHT_DUTY        VARCHAR2(1000 BYTE),
  OH_DUTY             VARCHAR2(1000 BYTE),
  OH_NONDUTY          VARCHAR2(1000 BYTE),
  FACTORY_COST        VARCHAR2(1000 BYTE),
  ADDL_DUTY           VARCHAR2(1000 BYTE),
  TARRIF_CODE         VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD1   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD2   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD3   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD4   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD5   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD6   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD7   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD8   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD9   VARCHAR2(1000 BYTE),
  ADDITIONAL_FIELD10  VARCHAR2(1000 BYTE),
  REC_STATUS          VARCHAR2(1 BYTE),
  ERROR_MSG           VARCHAR2(1000 BYTE),
  CREATED_BY          VARCHAR2(1000 BYTE),
  CREATION_DATE       DATE,
  LAST_UPDATE_DATE    DATE,
  LAST_UPDATED_BY     VARCHAR2(1000 BYTE),
  REQUEST_ID          NUMBER,
  GROUP_ID            NUMBER
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
-- XXD_CST_OH_ELEMENTS_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_CST_OH_ELEMENTS_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_CST_OH_ELEMENTS_STG_T FOR XXDO.XXD_CST_OH_ELEMENTS_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_CST_OH_ELEMENTS_STG_T TO APPS
/
