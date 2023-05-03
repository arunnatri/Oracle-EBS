--
-- XXDO_ORDERS_MISSING_FREIGHT  (Table) 
--
CREATE TABLE XXDO.XXDO_ORDERS_MISSING_FREIGHT
(
  ORDER_NUMBER          NUMBER                  NOT NULL,
  HEADER_ID             NUMBER                  NOT NULL,
  CALCULATE_PRICE_FLAG  VARCHAR2(2 BYTE)
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
