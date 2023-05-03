--
-- XXD_ONT_BULK_ORDERS_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_BULK_ORDERS_T
(
  BULK_ID                         NUMBER,
  ORG_ID                          NUMBER,
  LINK_TYPE                       VARCHAR2(50 BYTE),
  STATUS                          VARCHAR2(1 BYTE),
  CALLOFF_HEADER_ID               NUMBER,
  CALLOFF_ORDER_NUMBER            NUMBER,
  CALLOFF_SOLD_TO_ORG_ID          NUMBER,
  CALLOFF_CUST_PO_NUMBER          VARCHAR2(50 BYTE),
  CALLOFF_REQUEST_DATE            DATE,
  CALLOFF_ORDER_BRAND             VARCHAR2(50 BYTE),
  BULK_HEADER_ID                  NUMBER,
  BULK_ORDER_NUMBER               NUMBER,
  BULK_SOLD_TO_ORG_ID             NUMBER,
  BULK_CUST_PO_NUMBER             VARCHAR2(50 BYTE),
  BULK_REQUEST_DATE               DATE,
  BULK_ORDER_BRAND                VARCHAR2(50 BYTE),
  CALLOFF_LINE_ID                 NUMBER,
  CALLOFF_LINE_NUMBER             NUMBER,
  CALLOFF_SHIPMENT_NUMBER         NUMBER,
  CALLOFF_ORDERED_ITEM            VARCHAR2(2000 BYTE),
  CALLOFF_INVENTORY_ITEM_ID       NUMBER,
  CALLOFF_ORDERED_QUANTITY        NUMBER,
  NEW_CALLOFF_ORDERED_QUANTITY    NUMBER,
  CALLOFF_LINE_REQUEST_DATE       DATE,
  CALLOFF_SCHEDULE_SHIP_DATE      DATE,
  CALLOFF_LATEST_ACCEPTABLE_DATE  DATE,
  CALLOFF_LINE_DEMAND_CLASS_CODE  VARCHAR2(30 BYTE),
  BULK_LINE_ID                    NUMBER,
  BULK_LINE_NUMBER                NUMBER,
  BULK_SHIPMENT_NUMBER            NUMBER,
  BULK_ORDERED_ITEM               VARCHAR2(2000 BYTE),
  BULK_INVENTORY_ITEM_ID          NUMBER,
  BULK_ORDERED_QUANTITY           NUMBER,
  BULK_LINE_REQUEST_DATE          DATE,
  BULK_SCHEDULE_SHIP_DATE         DATE,
  BULK_LATEST_ACCEPTABLE_DATE     DATE,
  BULK_LINE_DEMAND_CLASS_CODE     VARCHAR2(30 BYTE),
  LINKED_QTY                      NUMBER,
  ATP_QTY                         NUMBER,
  ERROR_MESSAGE                   VARCHAR2(2000 BYTE),
  REQUEST_ID                      NUMBER,
  CREATION_DATE                   DATE,
  CREATED_BY                      NUMBER,
  LAST_UPDATE_DATE                DATE,
  LAST_UPDATED_BY                 NUMBER,
  LAST_UPDATE_LOGIN               NUMBER,
  NUMBER_ATTRIBUTE1               NUMBER,
  NUMBER_ATTRIBUTE2               NUMBER,
  NUMBER_ATTRIBUTE3               NUMBER,
  NUMBER_ATTRIBUTE4               NUMBER,
  NUMBER_ATTRIBUTE5               NUMBER,
  VARCHAR_ATTRIBUTE1              VARCHAR2(2000 BYTE),
  VARCHAR_ATTRIBUTE2              VARCHAR2(2000 BYTE),
  VARCHAR_ATTRIBUTE3              VARCHAR2(2000 BYTE),
  VARCHAR_ATTRIBUTE4              VARCHAR2(2000 BYTE),
  VARCHAR_ATTRIBUTE5              VARCHAR2(2000 BYTE),
  DATE_ATTRIBUTE1                 DATE,
  DATE_ATTRIBUTE2                 DATE,
  DATE_ATTRIBUTE3                 DATE,
  DATE_ATTRIBUTE4                 DATE,
  DATE_ATTRIBUTE5                 DATE,
  LINE_STATUS                     VARCHAR2(100 BYTE),
  PARENT_REQUEST_ID               NUMBER,
  CUSTOMER_BATCH_ID               NUMBER,
  BULK_BATCH_ID                   NUMBER,
  CALLOFF_BATCH_ID                NUMBER,
  CANCEL_QTY                      NUMBER,
  CANCEL_STATUS                   VARCHAR2(1 BYTE),
  SCHEDULE_STATUS                 VARCHAR2(1 BYTE),
  SUPPLEMENTAL LOG GROUP GGS_9570832 (BULK_ID) ALWAYS,
  SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS,
  SUPPLEMENTAL LOG DATA (UNIQUE) COLUMNS,
  SUPPLEMENTAL LOG DATA (FOREIGN KEY) COLUMNS
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


ALTER TABLE XXDO.XXD_ONT_BULK_ORDERS_T ADD (
  PRIMARY KEY
  (BULK_ID)
  USING INDEX
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
  ENABLE VALIDATE)
/


--  There is no statement for index XXDO.SYS_C003829984.
--  The object is created when the parent object is created.

--
-- XXD_ONT_BULK_ORDERS_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_BULK_ORDERS_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_BULK_ORDERS_N1 ON XXDO.XXD_ONT_BULK_ORDERS_T
(CALLOFF_LINE_ID, LINK_TYPE)
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
-- XXD_ONT_BULK_ORDERS_N2  (Index) 
--
--  Dependencies: 
--   XXD_ONT_BULK_ORDERS_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_BULK_ORDERS_N2 ON XXDO.XXD_ONT_BULK_ORDERS_T
(BULK_LINE_ID, PARENT_REQUEST_ID)
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
-- XXD_ONT_BULK_ORDERS_N3  (Index) 
--
--  Dependencies: 
--   XXD_ONT_BULK_ORDERS_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_BULK_ORDERS_N3 ON XXDO.XXD_ONT_BULK_ORDERS_T
(CALLOFF_HEADER_ID, CALLOFF_LINE_ID, LINK_TYPE)
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
-- XXD_ONT_BULK_ORDERS_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_BULK_ORDERS_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_BULK_ORDERS_T FOR XXDO.XXD_ONT_BULK_ORDERS_T
/
