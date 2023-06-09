--
-- XXDO_EDI_855_DATA  (Table) 
--
CREATE TABLE XXDO.XXDO_EDI_855_DATA
(
  CUSTOMER_NUMBER   VARCHAR2(30 BYTE),
  ATTRIBUTE1        VARCHAR2(150 BYTE),
  BAM_ORDER_NUMBER  VARCHAR2(150 BYTE),
  BRAND             VARCHAR2(150 BYTE),
  ORDERED_DATE      DATE,
  REQUEST_DATE      DATE,
  CREATION_DATE     DATE,
  CUST_PO_NUMBER    VARCHAR2(50 BYTE),
  INTERFACED        VARCHAR2(1 BYTE),
  APP_TRANS_KEY     VARCHAR2(100 BYTE),
  ORDER_NUMBER      VARCHAR2(100 BYTE),
  PARTNER           VARCHAR2(100 BYTE),
  ISA               VARCHAR2(100 BYTE),
  STATUS            VARCHAR2(100 BYTE),
  MESSAGE_DATE      DATE,
  B2B_CONTROL       VARCHAR2(256 BYTE),
  EXISTS_IN_B2B     VARCHAR2(1 BYTE),
  B2B_ERRORMESSAGE  VARCHAR2(2000 BYTE),
  B2B_STATUS        VARCHAR2(256 BYTE),
  B2B_MESSAGEID     VARCHAR2(256 BYTE),
  INSTANCE_ID       VARCHAR2(100 BYTE)
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
-- XXDO_EDI_855_DATA  (Synonym) 
--
--  Dependencies: 
--   XXDO_EDI_855_DATA (Table)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_EDI_855_DATA FOR XXDO.XXDO_EDI_855_DATA
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXDO_EDI_855_DATA TO APPS
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXDO_EDI_855_DATA TO SOA_INT
/
