--
-- XXDO_CLOSE_PO_TEMP  (Table) 
--
CREATE TABLE XXDO.XXDO_CLOSE_PO_TEMP
(
  PO_NUMBER            VARCHAR2(10 BYTE),
  LINE_NUMBER          VARCHAR2(10 BYTE),
  ORG_DESCRIPTION      VARCHAR2(80 BYTE),
  NEW_SHIPMENT_STATUS  VARCHAR2(100 BYTE)
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
-- XXDO_CLOSE_PO_TEMP  (Synonym) 
--
--  Dependencies: 
--   XXDO_CLOSE_PO_TEMP (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_CLOSE_PO_TEMP FOR XXDO.XXDO_CLOSE_PO_TEMP
/