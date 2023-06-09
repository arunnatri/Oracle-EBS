--
-- XXD_ONT_COMMERCIAL_INV_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_COMMERCIAL_INV_T
(
  SHIPMENT_TYPE       VARCHAR2(100 BYTE),
  INV_NUM             VARCHAR2(100 BYTE),
  RUN_DATE            VARCHAR2(100 BYTE),
  FACTORY_INV_NUM     VARCHAR2(20 BYTE),
  SHIPMENT_HEADER_ID  NUMBER,
  SHIPMENT_ID         NUMBER,
  SALES_ORDER         NUMBER,
  HEADER_ID           NUMBER,
  VESSEL_NAME         VARCHAR2(30 BYTE),
  EST_DEP_DATE        VARCHAR2(20 BYTE),
  MODE_OF_TRANS       VARCHAR2(30 BYTE),
  CURR_CODE           VARCHAR2(30 BYTE),
  ITEM_DESC           VARCHAR2(240 BYTE),
  STYLE_NUMBER        VARCHAR2(150 BYTE),
  COLOR_CODE          VARCHAR2(150 BYTE),
  QUANTITY            NUMBER,
  PRICE               NUMBER,
  TOTAL               NUMBER,
  FACTORY_PO          VARCHAR2(20 BYTE),
  COUNTRY_OF_ORIGIN   VARCHAR2(60 BYTE),
  HTS_COMM_CODE       VARCHAR2(200 BYTE),
  SOLD_BY             VARCHAR2(200 BYTE),
  SOLD_BY_LINE1       VARCHAR2(2000 BYTE),
  SOLD_BY_LINE2       VARCHAR2(2000 BYTE),
  SOLD_BY_LINE3       VARCHAR2(2000 BYTE),
  SOLD_BY_LINE4       VARCHAR2(2000 BYTE),
  SOLD_TO             VARCHAR2(200 BYTE),
  SOLD_TO_LINE1       VARCHAR2(2000 BYTE),
  SOLD_TO_LINE2       VARCHAR2(2000 BYTE),
  SOLD_TO_LINE3       VARCHAR2(2000 BYTE),
  SOLD_TO_LINE4       VARCHAR2(2000 BYTE),
  SHIP_TO_LINE1       VARCHAR2(200 BYTE),
  SHIP_TO_LINE2       VARCHAR2(2000 BYTE),
  SHIP_TO_LINE3       VARCHAR2(2000 BYTE),
  SHIP_TO_LINE4       VARCHAR2(200 BYTE),
  SHIP_TO_LINE5       VARCHAR2(200 BYTE),
  VAT                 VARCHAR2(200 BYTE),
  COMP_REG            VARCHAR2(200 BYTE),
  SHIPPING_TERMS      VARCHAR2(200 BYTE),
  EMAIL_ADDRESS       VARCHAR2(100 BYTE),
  SEND_EMAIL          VARCHAR2(10 BYTE),
  PROGRAM_FROM_DATE   DATE,
  PROGRAM_TO_DATE     DATE,
  PROGRAM_MODE        VARCHAR2(20 BYTE),
  RECORD_STATUS       VARCHAR2(1 BYTE),
  ORG_ID              NUMBER,
  REQUEST_ID          NUMBER,
  CREATION_DATE       DATE,
  CREATED_BY          NUMBER,
  LAST_UPDATE_DATE    DATE,
  LAST_UPDATED_BY     NUMBER,
  SHIP_FROM           VARCHAR2(200 BYTE),
  SHIP_FROM_LINE1     VARCHAR2(2000 BYTE),
  SHIP_FROM_LINE2     VARCHAR2(2000 BYTE),
  SHIP_FROM_LINE3     VARCHAR2(2000 BYTE),
  SHIP_FROM_LINE4     VARCHAR2(2000 BYTE),
  SHIP_FROM_LINE5     VARCHAR2(2000 BYTE),
  SOLD_BY_VAT         VARCHAR2(200 BYTE),
  SOLD_TO_VAT         VARCHAR2(200 BYTE),
  SHIP_FROM_VAT       VARCHAR2(200 BYTE),
  SHIP_TO             VARCHAR2(200 BYTE),
  SHIP_TO_VAT         VARCHAR2(200 BYTE),
  TAX_CODE            VARCHAR2(200 BYTE),
  TAX_RATE            NUMBER,
  TAX_AMT             NUMBER,
  TAX_STMT            VARCHAR2(2000 BYTE)
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
-- XXD_ONT_COMMERCIAL_INV_T_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_COMMERCIAL_INV_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_COMMERCIAL_INV_T_N1 ON XXDO.XXD_ONT_COMMERCIAL_INV_T
(RECORD_STATUS, SHIPMENT_HEADER_ID)
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
