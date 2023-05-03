--
-- XXDOEC_ORDER_PAYMENT_DETAILS  (Table) 
--
CREATE TABLE XXDO.XXDOEC_ORDER_PAYMENT_DETAILS
(
  PAYMENT_ID           NUMBER,
  HEADER_ID            NUMBER,
  LINE_GROUP_ID        VARCHAR2(30 BYTE),
  PAYMENT_TRX_ID       NUMBER,
  PAYMENT_TYPE         VARCHAR2(30 BYTE),
  PAYMENT_NUMBER       VARCHAR2(30 BYTE),
  PAYMENT_DATE         DATE,
  PAYMENT_AMOUNT       NUMBER,
  PG_REFERENCE_NUM     VARCHAR2(120 BYTE),
  COMMENTS             VARCHAR2(240 BYTE),
  UNAPPLIED_AMOUNT     NUMBER,
  STATUS               VARCHAR2(30 BYTE),
  WEB_ORDER_NUMBER     VARCHAR2(50 BYTE),
  PG_ACTION            VARCHAR2(10 BYTE),
  PREPAID_FLAG         VARCHAR2(1 BYTE),
  PAYMENT_TENDER_TYPE  VARCHAR2(50 BYTE),
  TRANSACTION_REF_NUM  VARCHAR2(120 BYTE)
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
-- XXDOEC_ORDER_PAYMENT_DTLS_U1  (Index) 
--
--  Dependencies: 
--   XXDOEC_ORDER_PAYMENT_DETAILS (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOEC_ORDER_PAYMENT_DTLS_U1 ON XXDO.XXDOEC_ORDER_PAYMENT_DETAILS
(PAYMENT_ID)
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
-- XXDOEC_ORDER_PAYMENT_DTLS_N1  (Index) 
--
--  Dependencies: 
--   XXDOEC_ORDER_PAYMENT_DETAILS (Table)
--
CREATE INDEX XXDO.XXDOEC_ORDER_PAYMENT_DTLS_N1 ON XXDO.XXDOEC_ORDER_PAYMENT_DETAILS
(HEADER_ID)
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
-- XXDOEC_ORDER_PAYMENT_DETAILS  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_ORDER_PAYMENT_DETAILS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOEC_ORDER_PAYMENT_DETAILS FOR XXDO.XXDOEC_ORDER_PAYMENT_DETAILS
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOEC_ORDER_PAYMENT_DETAILS TO APPS
/
