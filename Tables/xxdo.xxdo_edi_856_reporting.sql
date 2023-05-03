--
-- XXDO_EDI_856_REPORTING  (Table) 
--
CREATE TABLE XXDO.XXDO_EDI_856_REPORTING
(
  SHIPMENT_ID       VARCHAR2(1000 BYTE),
  PARTNER           VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER    NUMBER(30),
  BATCH_NUMBER      NUMBER(30),
  CURRENT_STATUS    VARCHAR2(100 BYTE),
  CURRENT_DATE      DATE,
  CREATION_DATE     DATE,
  CREATED_BY        NUMBER(20),
  B2BID             VARCHAR2(2000 BYTE),
  B2B_CONTROL       VARCHAR2(2000 BYTE),
  B2B_ERRORMESSAGE  VARCHAR2(2000 BYTE),
  B2B_STATUS        VARCHAR2(2000 BYTE),
  EXISTSIN_B2B      VARCHAR2(2000 BYTE)
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