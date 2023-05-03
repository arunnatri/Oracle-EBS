--
-- XXDOEC_GOOGLE_SHIP_CARRIERS  (Table) 
--
CREATE TABLE XXDO.XXDOEC_GOOGLE_SHIP_CARRIERS
(
  SHIP_METHOD_CODE  VARCHAR2(10 BYTE),
  CARRIER_ID        NUMBER                      NOT NULL
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


ALTER TABLE XXDO.XXDOEC_GOOGLE_SHIP_CARRIERS ADD (
  PRIMARY KEY
  (SHIP_METHOD_CODE)
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


--  There is no statement for index XXDO.SYS_C00282713.
--  The object is created when the parent object is created.
