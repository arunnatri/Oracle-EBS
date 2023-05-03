--
-- XXDOAR020_TEMP_GT  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXDOAR020_TEMP_GT
(
  ORG_ID                 NUMBER(15),
  CUSTOMER_ID            NUMBER(15),
  CUSTOMER_SITE_USE_ID   NUMBER(15),
  CUSTOMER_TRX_ID        NUMBER(15),
  TRX_NUMBER             VARCHAR2(30 BYTE),
  TRX_DATE               DATE,
  AMOUNT_DUE_REMAINING   NUMBER,
  TERMS_SEQUENCE_NUMBER  NUMBER
)
ON COMMIT PRESERVE ROWS
NOCACHE
/


GRANT SELECT ON XXDO.XXDOAR020_TEMP_GT TO APPSRO
/