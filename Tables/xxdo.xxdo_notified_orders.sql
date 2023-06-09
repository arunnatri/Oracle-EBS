--
-- XXDO_NOTIFIED_ORDERS  (Table) 
--
CREATE TABLE XXDO.XXDO_NOTIFIED_ORDERS
(
  CUSTOMER_PO_NUMBER  VARCHAR2(100 BYTE)
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
-- XXDO_NOTIFIED_ORDERS  (Synonym) 
--
--  Dependencies: 
--   XXDO_NOTIFIED_ORDERS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_NOTIFIED_ORDERS FOR XXDO.XXDO_NOTIFIED_ORDERS
/


--
-- XXDO_NOTIFIED_ORDERS  (Synonym) 
--
--  Dependencies: 
--   XXDO_NOTIFIED_ORDERS (Table)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_NOTIFIED_ORDERS FOR XXDO.XXDO_NOTIFIED_ORDERS
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXDO_NOTIFIED_ORDERS TO APPS
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXDO_NOTIFIED_ORDERS TO SOA_INT
/
