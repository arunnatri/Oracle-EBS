--
-- XXDO_GTN_PO_COLLAB_STG  (Table) 
--
CREATE TABLE XXDO.XXDO_GTN_PO_COLLAB_STG
(
  GTN_PO_COLLAB_STG_ID      NUMBER,
  BATCH_ID                  NUMBER,
  BATCH_CODE                VARCHAR2(100 BYTE),
  CREATION_DATE             DATE                DEFAULT SYSDATE               NOT NULL,
  CREATED_BY                NUMBER              NOT NULL,
  USER_ID                   NUMBER              NOT NULL,
  SPLIT_FLAG                VARCHAR2(1 BYTE)    NOT NULL,
  SHIP_METHOD               VARCHAR2(50 BYTE)   NOT NULL,
  QUANTITY                  NUMBER,
  EX_FACTORY_DATE           DATE,
  UNIT_PRICE                NUMBER,
  CURRENCY_CODE             VARCHAR2(10 BYTE),
  NEW_PROMISED_DATE         DATE,
  FREIGHT_PAY_PARTY         VARCHAR2(10 BYTE),
  ORIGINAL_LINE_FLAG        VARCHAR2(1 BYTE)    NOT NULL,
  PO_HEADER_ID              NUMBER,
  ORG_ID                    NUMBER,
  PO_NUMBER                 VARCHAR2(20 BYTE),
  SRC_PO_TYPE_ID            NUMBER,
  REVISION_NUM              NUMBER,
  PO_LINE_ID                NUMBER,
  LINE_NUM                  NUMBER,
  PO_LINE_LOCATION_ID       NUMBER,
  SHIPMENT_NUM              NUMBER,
  PO_DISTRIBUTION_ID        NUMBER,
  DISTRIBUTION_NUM          NUMBER,
  PO_TYPE                   VARCHAR2(20 BYTE),
  CANCEL_LINE               VARCHAR2(1 BYTE),
  CHANGE_TYPE               VARCHAR2(10 BYTE),
  APPROVED_FLAG             VARCHAR2(1 BYTE),
  CLOSED_CODE               VARCHAR2(25 BYTE),
  CANCEL_FLAG               VARCHAR2(1 BYTE),
  ITEM_ID                   NUMBER,
  PREPARER_ID               NUMBER,
  SHIP_TO_ORGANIZATION_ID   NUMBER,
  SHIP_TO_LOCATION_ID       NUMBER,
  DROP_SHIP_FLAG            VARCHAR2(1 BYTE),
  PROCESSING_STATUS_CODE    VARCHAR2(20 BYTE),
  ERROR_MESSAGE             VARCHAR2(2000 BYTE),
  OE_USER_ID                NUMBER,
  OE_HEADER_ID              NUMBER,
  OE_LINE_ID                NUMBER,
  DROP_SHIP_SOURCE_ID       NUMBER,
  RESERVATION_ID            NUMBER,
  REQ_HEADER_ID             NUMBER,
  REQ_LINE_ID               NUMBER,
  BRAND                     VARCHAR2(20 BYTE),
  FROM_PO_NUMBER            NUMBER,
  FROM_OE_HEADER_ID         NUMBER,
  FROM_OE_LINE_ID           NUMBER,
  FROM_PO_HEADER_ID         NUMBER,
  FROM_PO_LINE_ID           NUMBER,
  FROM_PO_LINE_LOCATION_ID  NUMBER,
  FROM_REQ_HEADER_ID        NUMBER,
  FROM_REQ_LINE_ID          NUMBER,
  FROM_IR_HEADER_ID         NUMBER,
  FROM_IR_LINE_ID           NUMBER,
  CREATE_REQ                VARCHAR2(1 BYTE),
  REQ_TYPE                  VARCHAR2(20 BYTE),
  REQ_CREATED               VARCHAR2(1 BYTE),
  NEW_REQ_HEADER_ID         NUMBER,
  NEW_REQ_LINE_ID           NUMBER,
  VENDOR_ID                 NUMBER,
  VENDOR_SITE_ID            NUMBER,
  REQUEST_ID                NUMBER,
  REQUEST_USER_ID           NUMBER,
  REQUEST_DATE              NUMBER,
  COMMENTS1                 VARCHAR2(320 BYTE),
  COMMENTS2                 VARCHAR2(320 BYTE),
  COMMENTS3                 VARCHAR2(320 BYTE),
  COMMENTS4                 VARCHAR2(320 BYTE),
  PO_LINE_KEY               VARCHAR2(20 BYTE),
  SUPPLIER_SITE_CODE        VARCHAR2(15 BYTE),
  DELAY_REASON              VARCHAR2(2000 BYTE)
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
-- XXDO_GTN_PO_COLLAB_STG_IDX1  (Index) 
--
--  Dependencies: 
--   XXDO_GTN_PO_COLLAB_STG (Table)
--
CREATE INDEX XXDO.XXDO_GTN_PO_COLLAB_STG_IDX1 ON XXDO.XXDO_GTN_PO_COLLAB_STG
(BATCH_ID)
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
-- XXDO_GTN_PO_COLLAB_STG_IDX2  (Index) 
--
--  Dependencies: 
--   XXDO_GTN_PO_COLLAB_STG (Table)
--
CREATE INDEX XXDO.XXDO_GTN_PO_COLLAB_STG_IDX2 ON XXDO.XXDO_GTN_PO_COLLAB_STG
(GTN_PO_COLLAB_STG_ID)
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
-- XXDO_GTN_PO_COLLAB_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_GTN_PO_COLLAB_STG (Table)
--
CREATE OR REPLACE SYNONYM SOA_RO.XXDO_GTN_PO_COLLAB_STG FOR XXDO.XXDO_GTN_PO_COLLAB_STG
/


GRANT SELECT ON XXDO.XXDO_GTN_PO_COLLAB_STG TO SOA_RO
/
