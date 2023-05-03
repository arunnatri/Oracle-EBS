--
-- XXDO_CIT_ORDER_SEND_HISTORY  (Table) 
--
CREATE TABLE XXDO.XXDO_CIT_ORDER_SEND_HISTORY
(
  CREATION_DATE         DATE,
  FILE_SEQUENCE_NUMBER  NUMBER,
  ORDER_NUMBER          NUMBER,
  CUSTOMER_NUMBER       VARCHAR2(20 BYTE),
  MIN_REQUEST_DATE      DATE,
  MAX_REQUEST_DATE      DATE,
  ORDER_AMOUNT          NUMBER,
  PROCESSED_FLAG        VARCHAR2(1 BYTE)        DEFAULT 'N'
)
TABLESPACE CUSTOM_TX_TS
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDO_CIT_ORDER_SEND_HISTORY TO APPS
/

GRANT SELECT ON XXDO.XXDO_CIT_ORDER_SEND_HISTORY TO APPSRO WITH GRANT OPTION
/
