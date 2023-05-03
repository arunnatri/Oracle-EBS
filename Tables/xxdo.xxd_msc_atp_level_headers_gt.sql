--
-- XXD_MSC_ATP_LEVEL_HEADERS_GT  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXD_MSC_ATP_LEVEL_HEADERS_GT
(
  XXD_SEQ_NUM                    NUMBER,
  XXD_BRAND                      VARCHAR2(50 BYTE),
  XXD_STYLE                      VARCHAR2(50 BYTE),
  XXD_STYLE_DESC                 VARCHAR2(500 BYTE),
  XXD_COLOR                      VARCHAR2(50 BYTE),
  XXD_TOTAL_ATP                  NUMBER,
  ACTION                         NUMBER,
  CALLING_MODULE                 NUMBER,
  SESSION_ID                     NUMBER,
  ORDER_HEADER_ID                NUMBER,
  ORDER_LINE_ID                  NUMBER,
  INVENTORY_ITEM_ID              NUMBER,
  ORGANIZATION_ID                NUMBER,
  SR_INSTANCE_ID                 NUMBER,
  ORGANIZATION_CODE              VARCHAR2(7 BYTE),
  ORDER_NUMBER                   NUMBER,
  SOURCE_ORGANIZATION_ID         NUMBER,
  CUSTOMER_ID                    NUMBER,
  CUSTOMER_SITE_ID               NUMBER,
  DESTINATION_TIME_ZONE          VARCHAR2(30 BYTE),
  QUANTITY_ORDERED               NUMBER,
  UOM_CODE                       VARCHAR2(3 BYTE),
  REQUESTED_SHIP_DATE            DATE,
  REQUESTED_ARRIVAL_DATE         DATE,
  LATEST_ACCEPTABLE_DATE         DATE,
  DELIVERY_LEAD_TIME             NUMBER,
  FREIGHT_CARRIER                VARCHAR2(30 BYTE),
  SHIP_METHOD                    VARCHAR2(30 BYTE),
  DEMAND_CLASS                   VARCHAR2(30 BYTE),
  SHIP_SET_NAME                  VARCHAR2(30 BYTE),
  SHIP_SET_ID                    NUMBER,
  ARRIVAL_SET_NAME               VARCHAR2(30 BYTE),
  ARRIVAL_SET_ID                 NUMBER,
  OVERRIDE_FLAG                  VARCHAR2(1 BYTE),
  SCHEDULED_SHIP_DATE            DATE,
  SCHEDULED_ARRIVAL_DATE         DATE,
  AVAILABLE_QUANTITY             NUMBER,
  REQUESTED_DATE_QUANTITY        NUMBER,
  GROUP_SHIP_DATE                DATE,
  GROUP_ARRIVAL_DATE             DATE,
  VENDOR_ID                      NUMBER,
  VENDOR_SITE_ID                 NUMBER,
  INSERT_FLAG                    NUMBER,
  ERROR_CODE                     VARCHAR2(240 BYTE),
  ERROR_MESSAGE                  VARCHAR2(240 BYTE),
  SEQUENCE_NUMBER                NUMBER,
  FIRM_FLAG                      NUMBER,
  INVENTORY_ITEM_NAME            VARCHAR2(250 BYTE),
  SOURCE_ORGANIZATION_CODE       VARCHAR2(7 BYTE),
  INSTANCE_ID1                   NUMBER,
  ORDER_LINE_NUMBER              NUMBER,
  SHIPMENT_NUMBER                NUMBER,
  OPTION_NUMBER                  NUMBER,
  PROMISE_DATE                   DATE,
  CUSTOMER_NAME                  VARCHAR2(255 BYTE),
  CUSTOMER_LOCATION              VARCHAR2(40 BYTE),
  OLD_LINE_SCHEDULE_DATE         DATE,
  OLD_SOURCE_ORGANIZATION_CODE   VARCHAR2(7 BYTE),
  SCENARIO_ID                    NUMBER,
  VENDOR_NAME                    VARCHAR2(80 BYTE),
  VENDOR_SITE_NAME               VARCHAR2(240 BYTE),
  STATUS_FLAG                    NUMBER,
  MDI_ROWID                      VARCHAR2(30 BYTE),
  DEMAND_SOURCE_TYPE             NUMBER,
  DEMAND_SOURCE_DELIVERY         VARCHAR2(30 BYTE),
  ATP_LEAD_TIME                  NUMBER,
  OE_FLAG                        VARCHAR2(1 BYTE),
  ITEM_DESC                      VARCHAR2(240 BYTE),
  INTRANSIT_LEAD_TIME            NUMBER,
  SHIP_METHOD_TEXT               VARCHAR2(240 BYTE),
  END_PEGGING_ID                 NUMBER,
  PROJECT_ID                     NUMBER,
  TASK_ID                        NUMBER,
  PROJECT_NUMBER                 VARCHAR2(25 BYTE),
  TASK_NUMBER                    VARCHAR2(25 BYTE),
  EXCEPTION1                     NUMBER,
  EXCEPTION2                     NUMBER,
  EXCEPTION3                     NUMBER,
  EXCEPTION4                     NUMBER,
  EXCEPTION5                     NUMBER,
  EXCEPTION6                     NUMBER,
  EXCEPTION7                     NUMBER,
  EXCEPTION8                     NUMBER,
  EXCEPTION9                     NUMBER,
  EXCEPTION10                    NUMBER,
  EXCEPTION11                    NUMBER,
  EXCEPTION12                    NUMBER,
  EXCEPTION13                    NUMBER,
  EXCEPTION14                    NUMBER,
  EXCEPTION15                    NUMBER,
  FIRM_SOURCE_ORG_ID             NUMBER,
  FIRM_SOURCE_ORG_CODE           VARCHAR2(7 BYTE),
  FIRM_SHIP_DATE                 DATE,
  FIRM_ARRIVAL_DATE              DATE,
  OLD_SOURCE_ORGANIZATION_ID     NUMBER,
  OLD_DEMAND_CLASS               VARCHAR2(30 BYTE),
  ATTRIBUTE_06                   VARCHAR2(30 BYTE),
  REQUEST_ITEM_ID                NUMBER,
  REQUEST_ITEM_NAME              VARCHAR2(250 BYTE),
  REQ_ITEM_AVAILABLE_DATE        DATE,
  REQ_ITEM_AVAILABLE_DATE_QTY    NUMBER,
  REQ_ITEM_REQ_DATE_QTY          NUMBER,
  SALES_REP                      VARCHAR2(255 BYTE),
  CUSTOMER_CONTACT               VARCHAR2(255 BYTE),
  SUBST_FLAG                     NUMBER,
  SUBSTITUTION_TYP_CODE          NUMBER,
  REQ_ITEM_DETAIL_FLAG           NUMBER,
  OLD_INVENTORY_ITEM_ID          NUMBER,
  COMPILE_DESIGNATOR             VARCHAR2(10 BYTE),
  CREATION_DATE                  DATE,
  CREATED_BY                     NUMBER,
  LAST_UPDATE_DATE               DATE,
  LAST_UPDATED_BY                NUMBER,
  LAST_UPDATE_LOGIN              NUMBER,
  FLOW_STATUS_CODE               VARCHAR2(30 BYTE),
  ASSIGNMENT_SET_ID              NUMBER,
  DIAGNOSTIC_ATP_FLAG            NUMBER,
  TOP_MODEL_LINE_ID              NUMBER,
  ATO_PARENT_MODEL_LINE_ID       NUMBER,
  ATO_MODEL_LINE_ID              NUMBER,
  PARENT_LINE_ID                 NUMBER,
  MATCH_ITEM_ID                  NUMBER,
  VALIDATION_ORG                 NUMBER,
  COMPONENT_SEQUENCE_ID          NUMBER,
  COMPONENT_CODE                 VARCHAR2(1000 BYTE),
  INCLUDED_ITEM_FLAG             NUMBER,
  LINE_NUMBER                    VARCHAR2(255 BYTE),
  BOM_ITEM_TYPE                  NUMBER,
  CONFIG_ITEM_LINE_ID            NUMBER,
  OSS_ERROR_CODE                 NUMBER,
  SOURCE_DOC_ID                  NUMBER,
  PICK_COMPONENTS_FLAG           VARCHAR2(1 BYTE),
  MATCHED_ITEM_NAME              VARCHAR2(255 BYTE),
  ATP_FLAG                       VARCHAR2(1 BYTE),
  ATP_COMPONENTS_FLAG            VARCHAR2(1 BYTE),
  WIP_SUPPLY_TYPE                NUMBER,
  FIXED_LT                       NUMBER,
  VARIABLE_LT                    NUMBER,
  MANDATORY_ITEM_FLAG            NUMBER,
  CASCADE_MODEL_INFO_TO_COMP     NUMBER,
  ORIGINAL_REQUEST_DATE          DATE,
  PLAN_ID                        NUMBER,
  INTERNAL_ORG_ID                NUMBER,
  FIRST_VALID_SHIP_ARRIVAL_DATE  DATE,
  PART_OF_SET                    VARCHAR2(1 BYTE),
  PARTY_SITE_ID                  NUMBER,
  CUSTOMER_COUNTRY               VARCHAR2(60 BYTE),
  CUSTOMER_STATE                 VARCHAR2(120 BYTE),
  CUSTOMER_CITY                  VARCHAR2(240 BYTE),
  CUSTOMER_POSTAL_CODE           VARCHAR2(60 BYTE)
)
ON COMMIT PRESERVE ROWS
NOCACHE
/


--
-- XXD_MSC_ATP_LEVEL_HEADERS_GT  (Synonym) 
--
--  Dependencies: 
--   XXD_MSC_ATP_LEVEL_HEADERS_GT (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_MSC_ATP_LEVEL_HEADERS_GT FOR XXDO.XXD_MSC_ATP_LEVEL_HEADERS_GT
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_MSC_ATP_LEVEL_HEADERS_GT TO APPS
/