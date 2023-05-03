--
-- XXD_ONT_ORDER_MODIFY_DETAILS_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_ORDER_MODIFY_DETAILS_T
(
  GROUP_ID                       NUMBER,
  ORG_ID                         NUMBER,
  OPERATION_MODE                 VARCHAR2(50 BYTE),
  SOURCE_HEADER_ID               NUMBER,
  SOURCE_ORDER_NUMBER            NUMBER,
  SOURCE_CUST_ACCOUNT            VARCHAR2(30 BYTE),
  SOURCE_SOLD_TO_ORG_ID          NUMBER,
  SOURCE_CUST_PO_NUMBER          VARCHAR2(100 BYTE),
  SOURCE_ORDER_TYPE              VARCHAR2(30 BYTE),
  SOURCE_HEADER_REQUEST_DATE     DATE,
  BRAND                          VARCHAR2(50 BYTE),
  SOURCE_LINE_ID                 NUMBER,
  SOURCE_LINE_NUMBER             NUMBER,
  SOURCE_ORDERED_ITEM            VARCHAR2(40 BYTE),
  SOURCE_INVENTORY_ITEM_ID       NUMBER,
  SOURCE_ORDERED_QUANTITY        NUMBER,
  SOURCE_LINE_REQUEST_DATE       DATE,
  SOURCE_SCHEDULE_SHIP_DATE      DATE,
  SOURCE_LATEST_ACCEPTABLE_DATE  DATE,
  TARGET_CUSTOMER_NUMBER         VARCHAR2(30 BYTE),
  TARGET_SOLD_TO_ORG_ID          NUMBER,
  TARGET_ORDER_NUMBER            NUMBER,
  TARGET_HEADER_ID               NUMBER,
  TARGET_CUST_PO_NUM             VARCHAR2(100 BYTE),
  TARGET_ORDER_TYPE              VARCHAR2(30 BYTE),
  TARGET_ORDER_TYPE_ID           NUMBER,
  TARGET_HEADER_REQUEST_DATE     DATE,
  TARGET_HEADER_CANCEL_DATE      DATE,
  TARGET_HEADER_DEMAND_CLASS     VARCHAR2(30 BYTE),
  TARGET_HEADER_SHIP_METHOD      VARCHAR2(50 BYTE),
  TARGET_HEADER_FREIGHT_CARRIER  VARCHAR2(50 BYTE),
  TARGET_HEADER_FREIGHT_TERMS    VARCHAR2(50 BYTE),
  TARGET_HEADER_PAYMENT_TERM     VARCHAR2(50 BYTE),
  TARGET_LINE_ID                 NUMBER,
  TARGET_ORDERED_ITEM            VARCHAR2(40 BYTE),
  TARGET_INVENTORY_ITEM_ID       NUMBER,
  TARGET_ORDERED_QUANTITY        NUMBER,
  TARGET_LINE_REQUEST_DATE       DATE,
  TARGET_SCHEDULE_SHIP_DATE      DATE,
  TARGET_LATEST_ACCEPTABLE_DATE  DATE,
  TARGET_LINE_CANCEL_DATE        DATE,
  TARGET_SHIP_FROM_ORG           VARCHAR2(10 BYTE),
  TARGET_SHIP_FROM_ORG_ID        NUMBER,
  TARGET_LINE_DEMAND_CLASS       VARCHAR2(30 BYTE),
  TARGET_LINE_SHIP_METHOD        VARCHAR2(50 BYTE),
  TARGET_LINE_FREIGHT_CARRIER    VARCHAR2(50 BYTE),
  TARGET_LINE_FREIGHT_TERMS      VARCHAR2(50 BYTE),
  TARGET_LINE_PAYMENT_TERM       VARCHAR2(50 BYTE),
  TARGET_CHANGE_REASON           VARCHAR2(80 BYTE),
  TARGET_CHANGE_REASON_CODE      VARCHAR2(30 BYTE),
  ATTRIBUTE1                     VARCHAR2(240 BYTE),
  ATTRIBUTE2                     VARCHAR2(240 BYTE),
  ATTRIBUTE3                     VARCHAR2(240 BYTE),
  ATTRIBUTE4                     VARCHAR2(240 BYTE),
  ATTRIBUTE5                     VARCHAR2(240 BYTE),
  ATTRIBUTE6                     VARCHAR2(240 BYTE),
  ATTRIBUTE7                     VARCHAR2(240 BYTE),
  ATTRIBUTE8                     VARCHAR2(240 BYTE),
  ATTRIBUTE9                     VARCHAR2(240 BYTE),
  ATTRIBUTE10                    VARCHAR2(240 BYTE),
  ATTRIBUTE11                    VARCHAR2(240 BYTE),
  ATTRIBUTE12                    VARCHAR2(240 BYTE),
  ATTRIBUTE13                    VARCHAR2(240 BYTE),
  ATTRIBUTE14                    VARCHAR2(240 BYTE),
  ATTRIBUTE15                    VARCHAR2(240 BYTE),
  BATCH_ID                       NUMBER,
  STATUS                         VARCHAR2(1 BYTE),
  ERROR_MESSAGE                  VARCHAR2(4000 BYTE),
  PARENT_REQUEST_ID              NUMBER,
  REQUEST_ID                     NUMBER,
  CREATION_DATE                  DATE,
  CREATED_BY                     NUMBER,
  LAST_UPDATE_DATE               DATE,
  LAST_UPDATED_BY                NUMBER,
  LAST_UPDATE_LOGIN              NUMBER,
  RECORD_ID                      NUMBER
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
-- XXD_MODIFY_REC_PK  (Index) 
--
--  Dependencies: 
--   XXD_ONT_ORDER_MODIFY_DETAILS_T (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_MODIFY_REC_PK ON XXDO.XXD_ONT_ORDER_MODIFY_DETAILS_T
(RECORD_ID)
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

ALTER TABLE XXDO.XXD_ONT_ORDER_MODIFY_DETAILS_T ADD (
  CONSTRAINT XXD_MODIFY_REC_PK
  PRIMARY KEY
  (RECORD_ID)
  USING INDEX XXDO.XXD_MODIFY_REC_PK
  ENABLE VALIDATE)
/


--
-- XXD_ONT_ORDER_MODIFY_DTLS_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_ORDER_MODIFY_DETAILS_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_ORDER_MODIFY_DTLS_N1 ON XXDO.XXD_ONT_ORDER_MODIFY_DETAILS_T
(GROUP_ID, SOURCE_HEADER_ID, SOURCE_LINE_ID)
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
-- XXD_ONT_ORDER_MODIFY_DTLS_N2  (Index) 
--
--  Dependencies: 
--   XXD_ONT_ORDER_MODIFY_DETAILS_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_ORDER_MODIFY_DTLS_N2 ON XXDO.XXD_ONT_ORDER_MODIFY_DETAILS_T
(GROUP_ID, BATCH_ID)
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
-- XXD_ONT_ORDER_MODIFY_DTLS_N3  (Index) 
--
--  Dependencies: 
--   XXD_ONT_ORDER_MODIFY_DETAILS_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_ORDER_MODIFY_DTLS_N3 ON XXDO.XXD_ONT_ORDER_MODIFY_DETAILS_T
(GROUP_ID, SOURCE_LINE_ID)
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
-- XXD_ONT_ORDER_MODIFY_DETAILS_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_ORDER_MODIFY_DETAILS_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_ORDER_MODIFY_DETAILS_T FOR XXDO.XXD_ONT_ORDER_MODIFY_DETAILS_T
/