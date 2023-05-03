--
-- XXDOEC_GOOGLE_CANCEL_CODES  (Table) 
--
CREATE TABLE XXDO.XXDOEC_GOOGLE_CANCEL_CODES
(
  CANCEL_CODE        VARCHAR2(100 BYTE),
  GTS_CANCEL_REASON  VARCHAR2(100 BYTE)         NOT NULL
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


ALTER TABLE XXDO.XXDOEC_GOOGLE_CANCEL_CODES ADD (
  PRIMARY KEY
  (CANCEL_CODE)
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


--  There is no statement for index XXDO.SYS_C00282708.
--  The object is created when the parent object is created.
