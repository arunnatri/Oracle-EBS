--
-- XXD_ONT_CONSUMPTION_RULES_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_CONSUMPTION_RULES_T
(
  RULE_ID                         NUMBER,
  ORG_ID                          NUMBER,
  CALLOFF_ORDER_TYPE_ID           NUMBER,
  SALESREP_FLAG                   VARCHAR2(1 BYTE),
  SALESREP_VALUE                  NUMBER,
  CUSTOMER_FLAG                   VARCHAR2(1 BYTE),
  CUSTOMER_VALUE                  NUMBER,
  CUST_PO_FLAG                    VARCHAR2(1 BYTE),
  CUST_PO_VALUE                   VARCHAR2(50 BYTE),
  WAREHOUSE_FLAG                  VARCHAR2(1 BYTE),
  WAREHOUSE_VALUE                 NUMBER,
  ORDER_SOURCE_FLAG               VARCHAR2(1 BYTE),
  ORDER_SOURCE_VALUE              NUMBER,
  SALES_CHANNEL_FLAG              VARCHAR2(1 BYTE),
  SALES_CHANNEL_VALUE             VARCHAR2(30 BYTE),
  ORDER_CURRENCY_FLAG             VARCHAR2(1 BYTE),
  ORDER_CURRENCY_VALUE            VARCHAR2(15 BYTE),
  BILL_TO_FLAG                    VARCHAR2(1 BYTE),
  BILL_TO_VALUE                   NUMBER,
  SHIP_TO_FLAG                    VARCHAR2(1 BYTE),
  SHIP_TO_VALUE                   NUMBER,
  DEMAND_CLASS_FLAG               VARCHAR2(1 BYTE),
  DEMAND_CLASS_VALUE              VARCHAR2(30 BYTE),
  VIRTUAL_WHSE_FLAG               VARCHAR2(1 BYTE),
  VIRTUAL_WHSE_VALUE              NUMBER,
  SHIP_FROM_WHSE_FLAG             VARCHAR2(1 BYTE),
  SHIP_FROM_WHSE_VALUE            NUMBER,
  SHIP_TO_WHSE_FLAG               VARCHAR2(1 BYTE),
  SHIP_TO_WHSE_VALUE              NUMBER,
  TRANSFER_TYPE_FLAG              VARCHAR2(1 BYTE),
  TRANSFER_TYPE_VALUE             VARCHAR2(20 BYTE),
  BULK_ORD_TYPE_DIRECTION_COLUMN  VARCHAR2(10 BYTE),
  BULK_ORD_TYPE_ID1               NUMBER,
  BULK_ORD_TYPE_ID1_PRIORITY      NUMBER,
  BULK_ORD_TYPE_ID1_SSD           VARCHAR2(10 BYTE),
  BULK_ORD_TYPE_ID2               NUMBER,
  BULK_ORD_TYPE_ID2_PRIORITY      NUMBER,
  BULK_ORD_TYPE_ID2_SSD           VARCHAR2(10 BYTE),
  BULK_ORD_TYPE_ID3               NUMBER,
  BULK_ORD_TYPE_ID3_PRIORITY      NUMBER,
  BULK_ORD_TYPE_ID3_SSD           VARCHAR2(10 BYTE),
  BULK_ORD_TYPE_ID4               NUMBER,
  BULK_ORD_TYPE_ID4_PRIORITY      NUMBER,
  BULK_ORD_TYPE_ID4_SSD           VARCHAR2(10 BYTE),
  CREATED_BY                      NUMBER,
  CREATION_DATE                   DATE,
  LAST_UPDATED_BY                 NUMBER,
  LAST_UPDATE_DATE                DATE,
  LAST_UPDATE_LOGIN               NUMBER
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
-- XXD_ONT_CONSUMPTION_RULES_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_CONSUMPTION_RULES_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_CONSUMPTION_RULES_N1 ON XXDO.XXD_ONT_CONSUMPTION_RULES_T
(CALLOFF_ORDER_TYPE_ID)
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
