--
-- XXDOEC_ORDER_STATUS_LOG  (Table) 
--
CREATE TABLE XXDO.XXDOEC_ORDER_STATUS_LOG
(
  ORDER_NUMBER     VARCHAR2(50 BYTE),
  CUSTOMER_NUMBER  VARCHAR2(25 BYTE),
  CALLED_WITH      VARCHAR2(500 BYTE),
  CREATEDATE       DATE,
  STAMP            TIMESTAMP(6)                 DEFAULT CURRENT_TIMESTAMP
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
-- ORDER_STATUS_LOG_CREATEDATE_IX  (Index) 
--
--  Dependencies: 
--   XXDOEC_ORDER_STATUS_LOG (Table)
--
CREATE INDEX XXDO.ORDER_STATUS_LOG_CREATEDATE_IX ON XXDO.XXDOEC_ORDER_STATUS_LOG
('createdate')
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
-- ORDER_STATUS_LOG_STAMP_IX  (Index) 
--
--  Dependencies: 
--   XXDOEC_ORDER_STATUS_LOG (Table)
--
CREATE INDEX XXDO.ORDER_STATUS_LOG_STAMP_IX ON XXDO.XXDOEC_ORDER_STATUS_LOG
('stamp')
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
