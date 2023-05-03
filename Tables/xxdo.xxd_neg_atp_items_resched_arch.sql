--
-- XXD_NEG_ATP_ITEMS_RESCHED_ARCH  (Table) 
--
CREATE TABLE XXDO.XXD_NEG_ATP_ITEMS_RESCHED_ARCH
(
  BATCH_ID                NUMBER,
  ORG_ID                  NUMBER,
  OPERATING_UNIT          VARCHAR2(150 BYTE),
  SHIP_FROM_ORG_ID        NUMBER,
  SHIP_FROM_ORG           VARCHAR2(10 BYTE),
  BRAND                   VARCHAR2(40 BYTE),
  STYLE                   VARCHAR2(40 BYTE),
  COLOR                   VARCHAR2(40 BYTE),
  SKU                     VARCHAR2(150 BYTE),
  INVENTORY_ITEM_ID       NUMBER,
  ORDER_NUMBER            NUMBER,
  CUSTOMER_NAME           VARCHAR2(360 BYTE),
  CUSTOMER_ID             NUMBER,
  HEADER_ID               NUMBER,
  LINE_ID                 NUMBER,
  LINE_NUM                VARCHAR2(10 BYTE),
  DEMAND_CLASS_CODE       VARCHAR2(150 BYTE),
  ORDERED_QUANTITY        NUMBER,
  REQUEST_DATE            DATE,
  SCHEDULE_SHIP_DATE      DATE,
  NEW_SCHEDULE_SHIP_DATE  DATE,
  LATEST_ACCEPTABLE_DATE  DATE,
  CANCEL_DATE             DATE,
  OVERRIDE_ATP_FLAG       VARCHAR2(1 BYTE),
  STATUS                  VARCHAR2(10 BYTE),
  ERROR_MESSAGE           VARCHAR2(2000 BYTE),
  CREATED_BY              NUMBER,
  CREATION_DATE           DATE,
  LAST_UPDATED_BY         NUMBER,
  LAST_UPDATE_DATE        DATE,
  REQUEST_ID              NUMBER,
  SEQ_NO                  NUMBER,
  CHILD_REQUEST_ID        NUMBER,
  SORT_BY_DATE            DATE
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
-- XXD_NEG_ATP_ITEMS_RESCHED_ARCH  (Synonym) 
--
--  Dependencies: 
--   XXD_NEG_ATP_ITEMS_RESCHED_ARCH (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_NEG_ATP_ITEMS_RESCHED_ARCH FOR XXDO.XXD_NEG_ATP_ITEMS_RESCHED_ARCH
/
