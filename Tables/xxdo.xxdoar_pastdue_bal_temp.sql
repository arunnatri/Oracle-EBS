--
-- XXDOAR_PASTDUE_BAL_TEMP  (Table) 
--
CREATE TABLE XXDO.XXDOAR_PASTDUE_BAL_TEMP
(
  CUSTOMER_ID  NUMBER,
  ORG_ID       NUMBER,
  PASTDUE_BAL  NUMBER,
  REQUEST_ID   NUMBER
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOAR_PASTDUE_BAL_TEMP TO APPS
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOAR_PASTDUE_BAL_TEMP TO APPSRO
/
