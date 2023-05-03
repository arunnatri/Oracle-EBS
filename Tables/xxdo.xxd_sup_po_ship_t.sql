--
-- XXD_SUP_PO_SHIP_T  (Table) 
--
CREATE TABLE XXDO.XXD_SUP_PO_SHIP_T
(
  LAST_UPDATED_BY           VARCHAR2(100 BYTE),
  LAST_UPDATE_LOGIN         VARCHAR2(100 BYTE),
  CREATION_DATE             DATE,
  CREATED_BY                VARCHAR2(100 BYTE),
  DELAY_CODE                VARCHAR2(100 BYTE),
  COMMENTS_1                VARCHAR2(500 BYTE),
  COMMENTS_2                VARCHAR2(500 BYTE),
  COMMENTS_3                VARCHAR2(500 BYTE),
  COMMENTS_4                VARCHAR2(500 BYTE),
  COMMENTS_5                VARCHAR2(500 BYTE),
  PACKING                   VARCHAR2(100 BYTE),
  REQUESTED_AIR_QUANTITY    VARCHAR2(100 BYTE),
  AIR_FREIGHT_EXPENSE       VARCHAR2(100 BYTE),
  INSPECTOR                 VARCHAR2(100 BYTE),
  PO_HEADER_ID              NUMBER,
  OU                        NUMBER,
  INVENTORY_CATEGORY_ID     NUMBER,
  PO_CATEGORY_ID            NUMBER,
  SHIP_TO_LOCATION_ID       NUMBER,
  HEADER_ID                 NUMBER,
  DESTINATION_INVENTORY_ID  NUMBER,
  CONF_XFACTORY_DATE        DATE
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
-- XXD_SUP_PO_SHIP_IND  (Index) 
--
--  Dependencies: 
--   XXD_SUP_PO_SHIP_T (Table)
--
CREATE INDEX XXDO.XXD_SUP_PO_SHIP_IND ON XXDO.XXD_SUP_PO_SHIP_T
(HEADER_ID, PO_HEADER_ID)
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
-- XXD_SUP_PO_SHIP_T  (Synonym) 
--
--  Dependencies: 
--   XXD_SUP_PO_SHIP_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_SUP_PO_SHIP_T FOR XXDO.XXD_SUP_PO_SHIP_T
/
