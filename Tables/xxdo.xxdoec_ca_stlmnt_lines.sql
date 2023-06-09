--
-- XXDOEC_CA_STLMNT_LINES  (Table) 
--
CREATE TABLE XXDO.XXDOEC_CA_STLMNT_LINES
(
  STLMNT_LINE_ID        NUMBER,
  STLMNT_HEADER_ID      NUMBER,
  SETTLEMENT_ID         VARCHAR2(40 BYTE),
  TRANSACTION_TYPE      VARCHAR2(40 BYTE),
  SELLER_ORDER_ID       VARCHAR2(120 BYTE),
  MERCHANT_ORDER_ID     VARCHAR2(120 BYTE),
  POSTED_DATE           DATE,
  SELLER_ITEM_CODE      VARCHAR2(120 BYTE),
  MERCHANT_ADJ_ITEM_ID  VARCHAR2(120 BYTE),
  SKU                   VARCHAR2(120 BYTE),
  QUANTITY              NUMBER,
  PRINCIPAL_AMOUNT      NUMBER,
  COMMISSION_AMOUNT     NUMBER,
  FREIGHT_AMOUNT        NUMBER,
  TAX_AMOUNT            NUMBER,
  PROMO_AMOUNT          NUMBER,
  ORDER_LINE_ID         NUMBER,
  CUSTOMER_TRX_ID       NUMBER,
  CASH_RECEIPT_ID       NUMBER,
  INTERFACE_STATUS      VARCHAR2(1 BYTE),
  ERROR_MESSAGE         VARCHAR2(2000 BYTE)
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
-- XXDOEC_CA_STLMNT_LINES_U1  (Index) 
--
--  Dependencies: 
--   XXDOEC_CA_STLMNT_LINES (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOEC_CA_STLMNT_LINES_U1 ON XXDO.XXDOEC_CA_STLMNT_LINES
(STLMNT_LINE_ID)
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
-- XXDOEC_CA_STLMNT_LINES_N1  (Index) 
--
--  Dependencies: 
--   XXDOEC_CA_STLMNT_LINES (Table)
--
CREATE INDEX XXDO.XXDOEC_CA_STLMNT_LINES_N1 ON XXDO.XXDOEC_CA_STLMNT_LINES
(STLMNT_HEADER_ID)
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
-- XXDOEC_CA_STLMNT_LINES  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_CA_STLMNT_LINES (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOEC_CA_STLMNT_LINES FOR XXDO.XXDOEC_CA_STLMNT_LINES
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOEC_CA_STLMNT_LINES TO APPS
/
