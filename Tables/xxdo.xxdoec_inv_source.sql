--
-- XXDOEC_INV_SOURCE  (Table) 
--
CREATE TABLE XXDO.XXDOEC_INV_SOURCE
(
  ERP_ORG_ID           NUMBER,
  INV_ORG_ID           NUMBER,
  BRAND_NAME           VARCHAR2(10 BYTE),
  KCO_HEADER_ID        NUMBER,
  DEFAULT_ATP_BUFFER   NUMBER,
  INV_SOURCE_ID        NUMBER,
  START_DATE           DATE,
  END_DATE             DATE,
  LAST_UPDATE_DATE     DATE,
  LAST_UPDATED_BY      NUMBER,
  LAST_UPDATE_NOTE     VARCHAR2(128 BYTE),
  PRE_BACK_ORDER_DAYS  NUMBER                   DEFAULT 90                    NOT NULL,
  PUT_AWAY_DAYS        NUMBER,
  CUSTOMER_ID          NUMBER,
  CREATION_DATE        DATE,
  CREATED_BY           NUMBER,
  LAST_UPDATE_LOGIN    NUMBER,
  RECORD_ID            NUMBER                   NOT NULL
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
-- XXDOEC_INV_SOURCE_PK  (Index) 
--
--  Dependencies: 
--   XXDOEC_INV_SOURCE (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOEC_INV_SOURCE_PK ON XXDO.XXDOEC_INV_SOURCE
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
-- XXDOEC_INV_SOURCE  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_INV_SOURCE (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOEC_INV_SOURCE FOR XXDO.XXDOEC_INV_SOURCE
/


GRANT SELECT ON XXDO.XXDOEC_INV_SOURCE TO APPS WITH GRANT OPTION
/
GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOEC_INV_SOURCE TO APPS
/

GRANT SELECT ON XXDO.XXDOEC_INV_SOURCE TO APPSRO
/