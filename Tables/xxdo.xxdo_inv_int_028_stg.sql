--
-- XXDO_INV_INT_028_STG  (Table) 
--
CREATE TABLE XXDO.XXDO_INV_INT_028_STG
(
  XML_ID            NUMBER,
  XML_DATA          CLOB,
  STATUS            NUMBER,
  UPDATE_TIMESTAMP  DATE
)
LOB (XML_DATA) STORE AS BASICFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING
  STORAGE    (
              INITIAL          64K
              NEXT             1M
              MINEXTENTS       1
              MAXEXTENTS       UNLIMITED
              PCTINCREASE      0
              BUFFER_POOL      DEFAULT
             ))
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


ALTER TABLE XXDO.XXDO_INV_INT_028_STG ADD (
  PRIMARY KEY
  (XML_ID)
  USING INDEX
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
  ENABLE VALIDATE)
/


--  There is no statement for index XXDO.SYS_C00282918.
--  The object is created when the parent object is created.

--
-- XXDO_INV_INT_028_TRG  (Trigger) 
--
--  Dependencies: 
--   XXDO_INV_INT_028_STG (Table)
--
CREATE OR REPLACE TRIGGER XXDO.XXDO_INV_INT_028_TRG 
AFTER INSERT
ON XXDO.XXDO_INV_INT_028_STG 
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
DECLARE
tmpVar NUMBER;
/******************************************************************************
   NAME:       XXDO_INV_INT_028_TRG
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        5/7/2012    Sivakumar Bhoothan       1. Created this trigger.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     XXDO_INIV_INT_028_TRG

******************************************************************************/
BEGIN
   tmpVar := 0;

   
  BEGIN
  
        INSERT INTO XXDO.XXDO_INV_INT_028_STG1 (XML_ID, XML_DATA, STATUS, UPDATE_TIMESTAMP)   
        VALUES (:NEW.XML_ID, :NEW.XML_DATA, :NEW.STATUS, :NEW.UPDATE_TIMESTAMP);
        
        
   EXCEPTION WHEN OTHERS THEN 
     
       NULL;
         
  END;   

   EXCEPTION
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END XXDO_INV_INT_028_TRG;
/


--
-- XXDO_INV_INT_028_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_INT_028_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_INT_028_STG FOR XXDO.XXDO_INV_INT_028_STG
/


--
-- XXDO_INV_INT_028_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_INT_028_STG (Table)
--
CREATE OR REPLACE SYNONYM DO_RIB.XXDO_INV_INT_028_STG FOR XXDO.XXDO_INV_INT_028_STG
/


GRANT SELECT ON XXDO.XXDO_INV_INT_028_STG TO APPSRO
/

GRANT DELETE, INSERT, SELECT ON XXDO.XXDO_INV_INT_028_STG TO DO_RIB
/
