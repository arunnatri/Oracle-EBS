--
-- XXDOASCP_ITEM_ATTR_UPD_STG  (Table) 
--
CREATE TABLE XXDO.XXDOASCP_ITEM_ATTR_UPD_STG
(
  INV_ORG_CODE               VARCHAR2(100 BYTE),
  ITEM_NUMBER                VARCHAR2(100 BYTE),
  CATEGORY_STRUCTURE         VARCHAR2(100 BYTE),
  CATEGORY_CODE              VARCHAR2(100 BYTE),
  ITEM_TEMPLATE              VARCHAR2(100 BYTE),
  DEFAULT_BUYER              VARCHAR2(100 BYTE),
  LIST_PRICE                 NUMBER(10,2),
  MAKE_BUY                   VARCHAR2(100 BYTE),
  PLANNER_CODE               VARCHAR2(100 BYTE),
  MIN_ORDER_QTY              NUMBER,
  FIXED_ORDER_QTY            NUMBER,
  MRP_PLANNING_METHOD        VARCHAR2(100 BYTE),
  FORECAST_CONTROL_METHOD    VARCHAR2(100 BYTE),
  END_ASSEMBLY_PEGGING       VARCHAR2(100 BYTE),
  PLANNING_TIME_FENCE        VARCHAR2(100 BYTE),
  PLAN_TIME_FENCE_DAYS       NUMBER,
  DEMAND_TIME_FENCE          VARCHAR2(100 BYTE),
  DEMAND_TIME_FENCE_DAYS     NUMBER,
  PRE_PROCESSING_LEAD_TIME   NUMBER,
  PROCESSING_LEAD_TIME       NUMBER,
  POST_PROCESSING_LEAD_TIME  NUMBER,
  CHECK_ATP                  VARCHAR2(100 BYTE),
  ATP_COMPONENTS             VARCHAR2(100 BYTE),
  ATP_RULE                   VARCHAR2(100 BYTE),
  SNO                        NUMBER,
  STATUS                     NUMBER,
  ERROR_MESSAGE              VARCHAR2(4000 BYTE),
  REQUEST_ID                 NUMBER,
  ITEM_IMPORT_REQUEST_ID     NUMBER,
  CREATED_BY                 VARCHAR2(100 BYTE),
  CREATION_DATE              DATE,
  LAST_UPDATED_BY            VARCHAR2(100 BYTE),
  LAST_UPDATE_DATE           DATE,
  ORGANIZATION_ID            NUMBER,
  INVENTORY_ITEM_ID          NUMBER,
  STRUCTURE_ID               NUMBER,
  CATEGORY_ID                NUMBER,
  TEMPLATE_ID                NUMBER,
  BUYER_ID                   NUMBER,
  PLANNING_MAKE_BUY_CODE     NUMBER,
  MRP_PLANNING_CODE          NUMBER,
  ATO_FORECAST_CONTROL_FLAG  NUMBER,
  END_ASSEMBLY_PEGGING_FLAG  VARCHAR2(100 BYTE),
  PLANNING_TIME_FENCE_CODE   NUMBER,
  DEMAND_TIME_FENCE_FLAG     NUMBER,
  CHECK_ATP_FLAG             VARCHAR2(100 BYTE),
  ATP_COMPONENTS_FLAG        VARCHAR2(100 BYTE),
  ATP_RULE_ID                VARCHAR2(100 BYTE),
  SET_PROCESS_ID             NUMBER,
  FILE_NAME                  VARCHAR2(240 BYTE),
  PNO                        NUMBER,
  EX_MESSAGE                 VARCHAR2(4000 BYTE),
  FIXED_DAYS_SUPPLY          NUMBER(10),
  FIXED_LOT_MULTIPLIER       VARCHAR2(100 BYTE),
  ROUND_ORDER_QUANTITIES     VARCHAR2(100 BYTE),
  CREATE_SUPPLY              VARCHAR2(5 BYTE),
  INVENTORY_PLANNING_METHOD  VARCHAR2(100 BYTE),
  MAX_ORDER_QTY              NUMBER,
  SAFETY_STOCK_METHOD        VARCHAR2(100 BYTE),
  SAFETY_STOCK_BUCKET_DAYS   NUMBER,
  SAFETY_STOCK_PERCENT       NUMBER,
  ROUNDING_ORD_TYPE          NUMBER,
  CREATE_SUPPLY_FLAG         VARCHAR2(1 BYTE),
  INVENTORY_PLANNING_CODE    NUMBER,
  SAFETY_STOCK_CODE          NUMBER,
  STYLE_COLOR                VARCHAR2(100 BYTE),
  SUPPLIER                   VARCHAR2(250 BYTE),
  SUPPLIER_SITE              VARCHAR2(250 BYTE),
  PRODUCT_LINE               VARCHAR2(250 BYTE)
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
-- XXDOASCP_ITEM_ATTR_UPD_STG_N1  (Index) 
--
--  Dependencies: 
--   XXDOASCP_ITEM_ATTR_UPD_STG (Table)
--
CREATE INDEX XXDO.XXDOASCP_ITEM_ATTR_UPD_STG_N1 ON XXDO.XXDOASCP_ITEM_ATTR_UPD_STG
(STATUS, ITEM_NUMBER)
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
-- XXDOASCP_ITEM_ATTR_UPD_STG_N2  (Index) 
--
--  Dependencies: 
--   XXDOASCP_ITEM_ATTR_UPD_STG (Table)
--
CREATE INDEX XXDO.XXDOASCP_ITEM_ATTR_UPD_STG_N2 ON XXDO.XXDOASCP_ITEM_ATTR_UPD_STG
(STATUS, ITEM_NUMBER, STYLE_COLOR)
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
-- XXDOASCP_ITEM_ATTR_UPD_STG  (Synonym) 
--
--  Dependencies: 
--   XXDOASCP_ITEM_ATTR_UPD_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOASCP_ITEM_ATTR_UPD_STG FOR XXDO.XXDOASCP_ITEM_ATTR_UPD_STG
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOASCP_ITEM_ATTR_UPD_STG TO APPS
/

GRANT SELECT ON XXDO.XXDOASCP_ITEM_ATTR_UPD_STG TO APPSRO WITH GRANT OPTION
/
