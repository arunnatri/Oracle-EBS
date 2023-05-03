--
-- XXDO_INV_INT_028_STG2  (Table) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XMLTYPE (Type)
--
CREATE TABLE XXDO.XXDO_INV_INT_028_STG2
(
  XML_ID             NUMBER,
  SEQ_NO             NUMBER,
  TO_LOCATION        NUMBER,
  FROM_LOCATION      NUMBER,
  ASN_NBR            NUMBER,
  ASN_TYPE           VARCHAR2(20 BYTE),
  H_CONTAINER_QTY    NUMBER,
  BOL_NBR            VARCHAR2(100 BYTE),
  SHIPMENT_DATE      VARCHAR2(100 BYTE),
  SHIPMENT_ADDRESS1  VARCHAR2(100 BYTE),
  SHIPMENT_ADDRESS2  VARCHAR2(100 BYTE),
  SHIPMENT_ADDRESS3  VARCHAR2(100 BYTE),
  SHIPMENT_ADDRESS4  VARCHAR2(100 BYTE),
  SHIPMENT_ADDRESS5  VARCHAR2(100 BYTE),
  SHIP_CITY          VARCHAR2(100 BYTE),
  SHIP_STATE         VARCHAR2(100 BYTE),
  SHIP_ZIP           VARCHAR2(100 BYTE),
  SHIP_COUNTRY_ID    VARCHAR2(100 BYTE),
  TRAILER_NBR        VARCHAR2(100 BYTE),
  SEAL_NBR           VARCHAR2(100 BYTE),
  CARRIER_CODE       VARCHAR2(100 BYTE),
  VENDOR_NBR         VARCHAR2(100 BYTE),
  PO_NBR             VARCHAR2(100 BYTE),
  DOC_TYPE           VARCHAR2(100 BYTE),
  FINAL_LOCATION     VARCHAR2(100 BYTE),
  ITEM_ID            NUMBER,
  UNIT_QTY           NUMBER,
  PRIORITY_LEVEL     NUMBER,
  ORDER_LINE_NBR     VARCHAR2(10 BYTE),
  LOT_NBR            VARCHAR2(100 BYTE),
  DISTRO_NBR         VARCHAR2(100 BYTE),
  DISTRO_DOC_TYPE    VARCHAR2(100 BYTE),
  L_CONTAINER_QTY    NUMBER,
  REQUEST_ID         NUMBER,
  STATUS             NUMBER,
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER,
  BRAND              VARCHAR2(20 BYTE),
  ERROR_MESSAGE      VARCHAR2(2000 BYTE),
  XML_TYPE_DATA      SYS.XMLTYPE,
  CONTAINER_ID       VARCHAR2(100 BYTE),
  CONTAINER_WEIGHT   NUMBER,
  CONTAINER_LENGTH   NUMBER,
  CONTAINER_WIDTH    NUMBER,
  CONTAINER_HEIGHT   NUMBER,
  CONTAINER_CUBE     NUMBER,
  EXPEDITE_FLAG      VARCHAR2(20 BYTE),
  RMA_NBR            NUMBER,
  TRACKING_NBR       NUMBER,
  FREIGHT_CHARGE     NUMBER,
  DC_VW_ID           NUMBER
)
XMLTYPE XML_TYPE_DATA STORE AS SECUREFILE BINARY XML (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING
  STORAGE    (
              INITIAL          104K
              NEXT             1M
              MINEXTENTS       1
              MAXEXTENTS       UNLIMITED
              PCTINCREASE      0
              BUFFER_POOL      DEFAULT
             ))
ALLOW NONSCHEMA
DISALLOW ANYSCHEMA
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
-- XXDO_INV_INT_028_STG2  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_INT_028_STG2 (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_INT_028_STG2 FOR XXDO.XXDO_INV_INT_028_STG2
/


GRANT SELECT ON XXDO.XXDO_INV_INT_028_STG2 TO APPSRO
/