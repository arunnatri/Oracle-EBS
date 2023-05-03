--
-- XXD_COMMON_MAPPING_HEADERS_TBL  (Table) 
--
CREATE TABLE XXDO.XXD_COMMON_MAPPING_HEADERS_TBL
(
  HEADER_ID         NUMBER,
  PRIORITY          NUMBER,
  CONTEXT_NAME      VARCHAR2(100 BYTE),
  SHORT_NAME        VARCHAR2(100 BYTE),
  DESCRIPTION       VARCHAR2(100 BYTE),
  ENABLED           VARCHAR2(1 BYTE),
  ATTRIBUTE1        VARCHAR2(200 BYTE),
  ATTRIBUTE2        VARCHAR2(200 BYTE),
  ATTRIBUTE3        VARCHAR2(200 BYTE),
  ATTRIBUTE4        VARCHAR2(200 BYTE),
  ATTRIBUTE5        VARCHAR2(200 BYTE),
  ATTRIBUTE6        VARCHAR2(200 BYTE),
  ATTRIBUTE7        VARCHAR2(200 BYTE),
  ATTRIBUTE8        VARCHAR2(200 BYTE),
  ATTRIBUTE9        VARCHAR2(200 BYTE),
  ATTRIBUTE10       VARCHAR2(200 BYTE),
  ATTRIBUTE11       VARCHAR2(200 BYTE),
  ATTRIBUTE12       VARCHAR2(200 BYTE),
  ATTRIBUTE13       VARCHAR2(200 BYTE),
  ATTRIBUTE14       VARCHAR2(200 BYTE),
  ATTRIBUTE15       VARCHAR2(200 BYTE),
  ATTRIBUTE16       NUMBER,
  ATTRIBUTE17       NUMBER,
  ATTRIBUTE18       NUMBER,
  ATTRIBUTE19       NUMBER,
  ATTRIBUTE20       NUMBER,
  ATTRIBUTE21       DATE,
  ATTRIBUTE22       DATE,
  ATTRIBUTE23       DATE,
  ATTRIBUTE24       DATE,
  ATTRIBUTE25       DATE,
  CREATED_BY        NUMBER,
  CREATION_DATE     DATE,
  LAST_UPDATE_BY    NUMBER,
  LAST_UPDATE_DATE  DATE
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


--
-- XXD_COMMON_MAP_HDR_ID_PK  (Index) 
--
--  Dependencies: 
--   XXD_COMMON_MAPPING_HEADERS_TBL (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_COMMON_MAP_HDR_ID_PK ON XXDO.XXD_COMMON_MAPPING_HEADERS_TBL
(HEADER_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

ALTER TABLE XXDO.XXD_COMMON_MAPPING_HEADERS_TBL ADD (
  CONSTRAINT XXD_COMMON_MAP_HDR_ID_PK
  PRIMARY KEY
  (HEADER_ID)
  USING INDEX XXDO.XXD_COMMON_MAP_HDR_ID_PK
  ENABLE VALIDATE)
/


--
-- XXD_COMMON_MAPPING_HEADERS_TBL  (Synonym) 
--
--  Dependencies: 
--   XXD_COMMON_MAPPING_HEADERS_TBL (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_COMMON_MAPPING_HEADERS_TBL FOR XXDO.XXD_COMMON_MAPPING_HEADERS_TBL
/


--
-- XXD_COMMON_MAPPING_HEADERS_TBL  (Synonym) 
--
--  Dependencies: 
--   XXD_COMMON_MAPPING_HEADERS_TBL (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXD_COMMON_MAPPING_HEADERS_TBL FOR XXDO.XXD_COMMON_MAPPING_HEADERS_TBL
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_COMMON_MAPPING_HEADERS_TBL TO APPS WITH GRANT OPTION
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_COMMON_MAPPING_HEADERS_TBL TO APPSRO WITH GRANT OPTION
/
