--
-- XXDO_WMS_ASN_CARTONS  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_ASN_CARTONS
(
  ASN_CARTON_ID                NUMBER           NOT NULL,
  SOURCE_TYPE_ID               NUMBER,
  SOURCE_HEADER_ID             NUMBER,
  SOURCE_LINE_ID               NUMBER,
  SOURCE_ORGANIZATION_ID       NUMBER,
  STATUS_FLAG                  VARCHAR2(10 BYTE),
  CARTON_NUMBER                VARCHAR2(30 BYTE),
  QUANTITY                     NUMBER           NOT NULL,
  ITEM_ID                      NUMBER           NOT NULL,
  DESTINATION_ORGANIZATION_ID  NUMBER,
  DESTINATION_TYPE_ID          NUMBER,
  DESTINATION_HEADER_ID        NUMBER,
  DESTINATION_LINE_ID          NUMBER,
  QUANTITY_RECEIVED            NUMBER,
  RECEIVE_DATE                 DATE,
  RCV_TRANSACTION_ID           NUMBER,
  QUANTITY_CANCELLED           NUMBER,
  CREATED_BY                   NUMBER,
  CREATION_DATE                DATE             DEFAULT SYSDATE,
  LAST_UPDATED_BY              NUMBER,
  LAST_UPDATE_DATE             DATE             DEFAULT SYSDATE,
  PO_HEADER_ID                 NUMBER,
  PO_LINE_ID                   NUMBER,
  CUSTOMER_ID                  NUMBER,
  DESTINATION_LOCATION_ID      NUMBER,
  DELIVERY_ID                  NUMBER
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
-- XXDO_WMS_ASN_CARTONS_UK1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_ASN_CARTONS (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_ASN_CARTONS_UK1 ON XXDO.XXDO_WMS_ASN_CARTONS
(ASN_CARTON_ID)
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
-- XXDO_WMS_ASN_CARTONS_IDX1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_ASN_CARTONS (Table)
--
CREATE INDEX XXDO.XXDO_WMS_ASN_CARTONS_IDX1 ON XXDO.XXDO_WMS_ASN_CARTONS
(SOURCE_HEADER_ID, SOURCE_LINE_ID, SOURCE_TYPE_ID)
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
-- XXDO_WMS_ASN_CARTONS_IDX2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_ASN_CARTONS (Table)
--
CREATE INDEX XXDO.XXDO_WMS_ASN_CARTONS_IDX2 ON XXDO.XXDO_WMS_ASN_CARTONS
(CARTON_NUMBER, ITEM_ID)
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
-- XXDO_WMS_ASN_CARTONS_IDX3  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_ASN_CARTONS (Table)
--
CREATE INDEX XXDO.XXDO_WMS_ASN_CARTONS_IDX3 ON XXDO.XXDO_WMS_ASN_CARTONS
(DESTINATION_HEADER_ID)
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
-- XXDO_WMS_ASN_CARTONS_IDX4  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_ASN_CARTONS (Table)
--
CREATE INDEX XXDO.XXDO_WMS_ASN_CARTONS_IDX4 ON XXDO.XXDO_WMS_ASN_CARTONS
(DESTINATION_LINE_ID)
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
