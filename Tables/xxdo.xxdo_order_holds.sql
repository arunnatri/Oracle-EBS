--
-- XXDO_ORDER_HOLDS  (Table) 
--
CREATE TABLE XXDO.XXDO_ORDER_HOLDS
(
  HEADER_ID   NUMBER,
  HOLD_COUNT  NUMBER                            DEFAULT 0
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
-- XXDO_ORDER_HOLDS  (Synonym) 
--
--  Dependencies: 
--   XXDO_ORDER_HOLDS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_ORDER_HOLDS FOR XXDO.XXDO_ORDER_HOLDS
/
