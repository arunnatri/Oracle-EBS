--
-- XXD_ONT_SO_CORRECTION_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_SO_CORRECTION_T
(
  ORG_ID                  NUMBER,
  OPERATING_UNIT          VARCHAR2(240 BYTE),
  BRAND                   VARCHAR2(20 BYTE),
  SHIP_FROM_ORG_ID        NUMBER,
  SHIP_FROM_ORG           VARCHAR2(3 BYTE),
  DIVISION                VARCHAR2(50 BYTE),
  DEPARTMENT              VARCHAR2(50 BYTE),
  STYLE                   VARCHAR2(30 BYTE),
  COLOR                   VARCHAR2(30 BYTE),
  ITEM_SIZE               VARCHAR2(30 BYTE),
  SKU                     VARCHAR2(50 BYTE),
  INVENTORY_ITEM_ID       NUMBER,
  ORDER_NUMBER            NUMBER,
  HEADER_ID               NUMBER,
  ORDERED_DATE            DATE,
  CUSTOMER_NAME           VARCHAR2(360 BYTE),
  CUSTOMER_NUMBER         VARCHAR2(30 BYTE),
  CUSTOMER_ID             NUMBER,
  ORDER_SOURCE_ID         NUMBER,
  ORDER_SOURCE            VARCHAR2(240 BYTE),
  ORDER_TYPE_ID           NUMBER,
  ORDER_TYPE              VARCHAR2(30 BYTE),
  CUSTOMER_PO_NUMBER      VARCHAR2(50 BYTE),
  LINE_NUMBER             VARCHAR2(10 BYTE),
  LINE_ID                 NUMBER,
  ORDERED_QUANTITY        NUMBER,
  DEMAND_CLASS            VARCHAR2(30 BYTE),
  HEADER_CANCEL_DATE      DATE,
  LINE_CANCEL_DATE        DATE,
  LATEST_ACCEPTABLE_DATE  DATE,
  OVERRIDE_ATP_FLAG       VARCHAR2(1 BYTE),
  REQUEST_DATE            DATE,
  SCHEDULE_SHIP_DATE      DATE,
  NEW_SCHEDULE_SHIP_DATE  DATE,
  STATUS                  VARCHAR2(30 BYTE),
  ERROR_MESSAGE           VARCHAR2(4000 BYTE),
  NEXT_SUPPLY_DATE        DATE,
  CANCEL_DATE_UPDATED     VARCHAR2(3 BYTE),
  REQUEST_ID              NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  LAST_UPDATE_LOGIN       NUMBER
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
-- XXD_ONT_SO_CORRECTION_T_U1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_SO_CORRECTION_T (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_ONT_SO_CORRECTION_T_U1 ON XXDO.XXD_ONT_SO_CORRECTION_T
(REQUEST_ID, LINE_ID)
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
-- XXD_ONT_SO_CORRECTION_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_SO_CORRECTION_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_SO_CORRECTION_T FOR XXDO.XXD_ONT_SO_CORRECTION_T
/
