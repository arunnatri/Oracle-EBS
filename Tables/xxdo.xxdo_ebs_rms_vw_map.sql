--
-- XXDO_EBS_RMS_VW_MAP  (Table) 
--
CREATE TABLE XXDO.XXDO_EBS_RMS_VW_MAP
(
  VIRTUAL_WAREHOUSE  VARCHAR2(100 BYTE),
  ORGANIZATION       NUMBER,
  ORGANIZATION_CODE  VARCHAR2(100 BYTE),
  DESCRIPTION        VARCHAR2(100 BYTE),
  KCO_HEADER_ID      NUMBER,
  KCO_HEADER_NAME    VARCHAR2(100 BYTE),
  FREE_ATP           VARCHAR2(1 BYTE),
  CHANNEL            VARCHAR2(240 BYTE),
  SALESREP_ID        NUMBER,
  SALESREP_NAME      VARCHAR2(100 BYTE),
  ORG_ID             NUMBER,
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER,
  LAST_UPDATE_LOGIN  NUMBER,
  RECORD_ID          NUMBER                     NOT NULL,
  SUPPLEMENTAL LOG GROUP GGS_3154405 (VIRTUAL_WAREHOUSE,CHANNEL,SALESREP_ID) ALWAYS,
  SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS,
  SUPPLEMENTAL LOG DATA (UNIQUE) COLUMNS,
  SUPPLEMENTAL LOG DATA (FOREIGN KEY) COLUMNS
)
TABLESPACE APPS_TS_TX_DATA
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
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
-- XXDO_EBS_RMS_VW_MAP_PK  (Index) 
--
--  Dependencies: 
--   XXDO_EBS_RMS_VW_MAP (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_EBS_RMS_VW_MAP_PK ON XXDO.XXDO_EBS_RMS_VW_MAP
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
-- XXDO_EBS_RMS_VW_PK  (Index) 
--
--  Dependencies: 
--   XXDO_EBS_RMS_VW_MAP (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_EBS_RMS_VW_PK ON XXDO.XXDO_EBS_RMS_VW_MAP
(VIRTUAL_WAREHOUSE, CHANNEL, SALESREP_ID)
LOGGING
TABLESPACE APPS_TS_TX_DATA
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

ALTER TABLE XXDO.XXDO_EBS_RMS_VW_MAP ADD (
  CONSTRAINT XXDO_EBS_RMS_VW_PK
  PRIMARY KEY
  (VIRTUAL_WAREHOUSE, CHANNEL, SALESREP_ID)
  USING INDEX XXDO.XXDO_EBS_RMS_VW_PK
  ENABLE VALIDATE)
/


--
-- XXDO_EBS_RMS_VW_MAP  (Synonym) 
--
--  Dependencies: 
--   XXDO_EBS_RMS_VW_MAP (Table)
--
CREATE OR REPLACE PUBLIC SYNONYM XXDO_EBS_RMS_VW_MAP FOR XXDO.XXDO_EBS_RMS_VW_MAP
/


GRANT SELECT ON XXDO.XXDO_EBS_RMS_VW_MAP TO APPS WITH GRANT OPTION
/
GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDO_EBS_RMS_VW_MAP TO APPS
/

GRANT SELECT ON XXDO.XXDO_EBS_RMS_VW_MAP TO APPSRO
/

GRANT SELECT ON XXDO.XXDO_EBS_RMS_VW_MAP TO SOA_INT
/
