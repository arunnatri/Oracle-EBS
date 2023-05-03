--
-- XXDOPO_PRICEUPD_ERRORS  (Table) 
--
CREATE TABLE XXDO.XXDOPO_PRICEUPD_ERRORS
(
  STYLE                VARCHAR2(30 BYTE),
  COLOR                VARCHAR2(30 BYTE),
  SIZE_ITEM            VARCHAR2(30 BYTE),
  NEW_PRICE            NUMBER,
  PO_NUMBER            VARCHAR2(30 BYTE),
  PO_LINE              VARCHAR2(30 BYTE),
  PO_BUY_SEASON        VARCHAR2(100 BYTE),
  PO_BUY_MONTH         VARCHAR2(100 BYTE),
  PO_HEADER_ID         NUMBER,
  PO_LINE_ID           NUMBER,
  PO_ITEM_ID           NUMBER,
  PO_LINE_LOCATION_ID  NUMBER,
  ERROR_DETAILS        VARCHAR2(3000 BYTE)
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
-- XXDOPO_PRICEUPD_ERRORS  (Synonym) 
--
--  Dependencies: 
--   XXDOPO_PRICEUPD_ERRORS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOPO_PRICEUPD_ERRORS FOR XXDO.XXDOPO_PRICEUPD_ERRORS
/