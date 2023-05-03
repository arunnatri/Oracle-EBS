--
-- XXD_ONT_SPECIAL_VAS_INFO_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_SPECIAL_VAS_INFO_T
(
  VAS_ID                  NUMBER,
  ORDER_HEADER_ID         NUMBER,
  ORDER_NUMBER            NUMBER,
  ORDER_STATUS            VARCHAR2(100 BYTE),
  ORDERED_DATE            DATE,
  ORG_ID                  NUMBER,
  SHIP_TO_ORG_ID          NUMBER,
  CUSTOMER_NAME           VARCHAR2(240 BYTE),
  BRAND                   VARCHAR2(100 BYTE),
  ORDER_LINE_ID           NUMBER,
  ORDER_LINE_NUM          NUMBER,
  SUPPLY_IDENTIFIER       NUMBER,
  INVENTORY_ITEM_ID       NUMBER,
  ORDERED_ITEM            VARCHAR2(100 BYTE),
  ORDERED_QUANTITY        NUMBER,
  ORDER_QUANTITY_UOM      VARCHAR2(25 BYTE),
  LIST_PRICE_PER_UNIT     NUMBER,
  INVENTORY_ORG_CODE      VARCHAR2(25 BYTE),
  INVENTORY_ORG_ID        NUMBER,
  REQUEST_DATE            DATE,
  SCHEDULE_SHIP_DATE      DATE,
  ORDER_LINE_STATUS       VARCHAR2(100 BYTE),
  SHIP_TO_LOCATION_ID     NUMBER,
  RESERVATION_ID          NUMBER,
  PO_HEADER_ID            NUMBER,
  PO_NUMBER               VARCHAR2(50 BYTE),
  VENDOR_ID               NUMBER,
  VENDOR_NAME             VARCHAR2(240 BYTE),
  VENDOR_SITE_ID          NUMBER,
  VENDOR_SITE             VARCHAR2(240 BYTE),
  BUYER_ID                NUMBER,
  BUYER_NAME              VARCHAR2(240 BYTE),
  XFACTORY_DATE           DATE,
  PO_LINE_ID              NUMBER,
  PO_LINE_NUM             NUMBER,
  PO_ORDERED_QTY          NUMBER,
  NEED_BY_DATE            DATE,
  ATTACHMENTS_COUNT       NUMBER,
  DEMAND_SUBINVENTORY     VARCHAR2(100 BYTE),
  DEMAND_LOCATOR_ID       NUMBER,
  DEMAND_LOCATOR          VARCHAR2(100 BYTE),
  CURRENCY_CODE           VARCHAR2(3 BYTE),
  CATEGORY_ID             NUMBER,
  CANCELLED_STATUS        VARCHAR2(100 BYTE),
  ORDER_LINE_CANCEL_DATE  DATE,
  VAS_STATUS              VARCHAR2(1 BYTE),
  ERROR_MESSAGE           VARCHAR2(2000 BYTE),
  REQUEST_ID              NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER
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


ALTER TABLE XXDO.XXD_ONT_SPECIAL_VAS_INFO_T ADD (
  PRIMARY KEY
  (VAS_ID)
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


--  There is no statement for index XXDO.SYS_C00282983.
--  The object is created when the parent object is created.

--
-- XXD_ONT_SPECIAL_VAS_INFO_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_SPECIAL_VAS_INFO_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_SPECIAL_VAS_INFO_N1 ON XXDO.XXD_ONT_SPECIAL_VAS_INFO_T
(ORDER_HEADER_ID, ORDER_LINE_ID, VAS_STATUS)
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
-- XXD_ONT_SPECIAL_VAS_INFO_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_SPECIAL_VAS_INFO_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_SPECIAL_VAS_INFO_T FOR XXDO.XXD_ONT_SPECIAL_VAS_INFO_T
/
