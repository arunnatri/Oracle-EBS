--
-- XXDOAR_B2B_RECEIPT_NUM_BKP2  (Table) 
--
CREATE TABLE XXDO.XXDOAR_B2B_RECEIPT_NUM_BKP2
(
  CASH_RECEIPT_ID     NUMBER(15)                NOT NULL,
  RECEIPT_NUMBER      VARCHAR2(30 BYTE),
  NEW_RECEIPT_NUMBER  VARCHAR2(30 BYTE)
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
