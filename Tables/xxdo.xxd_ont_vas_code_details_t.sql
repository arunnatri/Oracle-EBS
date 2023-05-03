--
-- XXD_ONT_VAS_CODE_DETAILS_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_VAS_CODE_DETAILS_T
(
  DOCUMENT_ID        NUMBER,
  VAS_CODE           VARCHAR2(10 BYTE),
  DESCRIPTION        VARCHAR2(240 BYTE),
  ENABLE_FLAG        VARCHAR2(1 BYTE),
  ATTRIBUTE1         VARCHAR2(240 BYTE),
  ATTRIBUTE2         VARCHAR2(240 BYTE),
  ATTRIBUTE3         VARCHAR2(240 BYTE),
  ATTRIBUTE4         VARCHAR2(240 BYTE),
  ATTRIBUTE5         VARCHAR2(240 BYTE),
  ATTRIBUTE6         VARCHAR2(240 BYTE),
  ATTRIBUTE7         VARCHAR2(240 BYTE),
  ATTRIBUTE8         VARCHAR2(240 BYTE),
  ATTRIBUTE9         VARCHAR2(240 BYTE),
  ATTRIBUTE10        VARCHAR2(240 BYTE),
  ATTRIBUTE11        VARCHAR2(240 BYTE),
  ATTRIBUTE12        VARCHAR2(240 BYTE),
  ATTRIBUTE13        VARCHAR2(240 BYTE),
  ATTRIBUTE14        VARCHAR2(240 BYTE),
  ATTRIBUTE15        VARCHAR2(240 BYTE),
  CREATED_BY         NUMBER,
  CREATION_DATE      DATE,
  LAST_UPDATED_BY    NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATE_LOGIN  NUMBER,
  SUPPLEMENTAL LOG GROUP GGS_16375325 (DOCUMENT_ID,VAS_CODE,DESCRIPTION,ENABLE_FLAG,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,ATTRIBUTE6,ATTRIBUTE7,ATTRIBUTE8,ATTRIBUTE9,ATTRIBUTE10,ATTRIBUTE11,ATTRIBUTE12,ATTRIBUTE13,ATTRIBUTE14,ATTRIBUTE15,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_LOGIN) ALWAYS,
  SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS,
  SUPPLEMENTAL LOG DATA (UNIQUE) COLUMNS,
  SUPPLEMENTAL LOG DATA (FOREIGN KEY) COLUMNS
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
-- XXD_ONT_VAS_CODE_DETAILS_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_VAS_CODE_DETAILS_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_VAS_CODE_DETAILS_T FOR XXDO.XXD_ONT_VAS_CODE_DETAILS_T
/