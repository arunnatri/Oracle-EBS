--
-- XXDO_INV_INT_026_STG  (Table) 
--
CREATE TABLE XXDO.XXDO_INV_INT_026_STG
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


--
-- XXDO_INV_INT_026_TRG  (Trigger) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG (Table)
--
CREATE OR REPLACE TRIGGER XXDO.XXDO_INV_INT_026_TRG 
AFTER INSERT
ON XXDO.XXDO_INV_INT_026_STG 
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
DECLARE
tmpVar NUMBER;
/******************************************************************************
   NAME:       XXDO_INIV_INT_026_TRG1
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author                 Description
   ---------  ----------  ---------------        ------------------------------------
   1.0        5/7/2012    Sivakumar Bhoothathan  1. Created this trigger.

   NOTES:

   Automatically available Auto Replace Keywords:
      Table Name:      XXDO_INV_INT_026_STG (set in the "New PL/SQL Object" dialog)
      Trigger Options:  (set in the "New PL/SQL Object" dialog)
******************************************************************************/
BEGIN
   tmpVar := 0;

   
  BEGIN
  
        INSERT INTO XXDO_INV_INT_026_STG1 (XML_ID, XML_DATA, STATUS, UPDATE_TIMESTAMP)   
        VALUES (:NEW.XML_ID, :NEW.XML_DATA, :NEW.STATUS, :NEW.UPDATE_TIMESTAMP);
        
        
   EXCEPTION WHEN OTHERS THEN 
     
       NULL;
         
  END;   

   EXCEPTION
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END XXDO_INV_INT_026_TRG;
/


--
-- XXDO_INV_INT_026_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_INT_026_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_INT_026_STG FOR XXDO.XXDO_INV_INT_026_STG
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDO_INV_INT_026_STG TO APPS
/

GRANT SELECT ON XXDO.XXDO_INV_INT_026_STG TO APPSRO
/

GRANT DELETE, INSERT, SELECT ON XXDO.XXDO_INV_INT_026_STG TO DO_RIB
/
