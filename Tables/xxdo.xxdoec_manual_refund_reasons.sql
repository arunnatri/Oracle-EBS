--
-- XXDOEC_MANUAL_REFUND_REASONS  (Table) 
--
CREATE TABLE XXDO.XXDOEC_MANUAL_REFUND_REASONS
(
  ORG_ID             NUMBER,
  BRAND_NAME         VARCHAR2(30 BYTE),
  COUNTRY_CODE       VARCHAR2(30 BYTE),
  REASON_CODE        VARCHAR2(30 BYTE),
  MEANING            VARCHAR2(120 BYTE),
  DECRIPTION         VARCHAR2(240 BYTE),
  GL_ACCOUNT         VARCHAR2(120 BYTE),
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER,
  LAST_UPDATE_LOGIN  NUMBER,
  RECORD_ID          NUMBER                     NOT NULL
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
-- XXDOEC_MAN_REF_REASONS_PK  (Index) 
--
--  Dependencies: 
--   XXDOEC_MANUAL_REFUND_REASONS (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOEC_MAN_REF_REASONS_PK ON XXDO.XXDOEC_MANUAL_REFUND_REASONS
(RECORD_ID)
LOGGING
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
/
--
-- XXDOEC_REFUND_REASONS_U1  (Index) 
--
--  Dependencies: 
--   XXDOEC_MANUAL_REFUND_REASONS (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOEC_REFUND_REASONS_U1 ON XXDO.XXDOEC_MANUAL_REFUND_REASONS
(ORG_ID, BRAND_NAME, REASON_CODE, COUNTRY_CODE)
LOGGING
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
/

--
-- XXDOEC_MANUAL_REFUND_REASONS  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_MANUAL_REFUND_REASONS (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOEC_MANUAL_REFUND_REASONS FOR XXDO.XXDOEC_MANUAL_REFUND_REASONS
/


GRANT SELECT ON XXDO.XXDOEC_MANUAL_REFUND_REASONS TO APPS WITH GRANT OPTION
/
GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOEC_MANUAL_REFUND_REASONS TO APPS
/

GRANT SELECT ON XXDO.XXDOEC_MANUAL_REFUND_REASONS TO APPSRO
/
