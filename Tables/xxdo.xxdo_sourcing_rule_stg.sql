--
-- XXDO_SOURCING_RULE_STG  (Table) 
--
CREATE TABLE XXDO.XXDO_SOURCING_RULE_STG
(
  STYLE               VARCHAR2(40 BYTE),
  COLOR               VARCHAR2(40 BYTE),
  ORACLE_REGION       VARCHAR2(20 BYTE),
  ORG_ID              NUMBER,
  ASSIGNMENT_SET_ID   NUMBER,
  START_DATE          DATE,
  END_DATE            DATE,
  SUPPLIER_NAME       VARCHAR2(240 BYTE),
  VENDOR_ID           NUMBER,
  SUPPLIER_SITE_CODE  VARCHAR2(15 BYTE),
  VENDOR_SITE_ID      NUMBER,
  SOURCING_RULE_ID    NUMBER,
  RECORD_STATUS       VARCHAR2(40 BYTE),
  ERROR_MESSAGE       VARCHAR2(4000 BYTE),
  SEQ_ID              NUMBER,
  RUN_ID              NUMBER,
  PLM_REGION          VARCHAR2(20 BYTE),
  SOURCE              VARCHAR2(20 BYTE),
  CREATION_DATE       DATE,
  CREATED_BY          NUMBER,
  LAST_UPDATE_DATE    DATE,
  LAST_UPDATED_BY     NUMBER,
  LAST_UPDATE_LOGIN   NUMBER,
  REQUEST_ID          NUMBER,
  ATTRIBUTE1          VARCHAR2(50 BYTE),
  ATTRIBUTE2          VARCHAR2(50 BYTE),
  ATTRIBUTE3          VARCHAR2(50 BYTE),
  ATTRIBUTE4          VARCHAR2(50 BYTE),
  ATTRIBUTE5          VARCHAR2(50 BYTE),
  ATTRIBUTE6          VARCHAR2(50 BYTE),
  ATTRIBUTE7          VARCHAR2(50 BYTE),
  ATTRIBUTE8          VARCHAR2(50 BYTE),
  ATTRIBUTE9          VARCHAR2(50 BYTE),
  ATTRIBUTE10         VARCHAR2(50 BYTE),
  ATTRIBUTE11         VARCHAR2(50 BYTE),
  ATTRIBUTE12         VARCHAR2(50 BYTE),
  ATTRIBUTE13         VARCHAR2(50 BYTE),
  ATTRIBUTE14         VARCHAR2(50 BYTE),
  ATTRIBUTE15         VARCHAR2(50 BYTE),
  ATTRIBUTE16         VARCHAR2(50 BYTE),
  ATTRIBUTE17         VARCHAR2(50 BYTE),
  ATTRIBUTE18         VARCHAR2(50 BYTE),
  ATTRIBUTE19         VARCHAR2(50 BYTE),
  ATTRIBUTE20         VARCHAR2(50 BYTE)
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
-- XXDO_SOURCING_RULE_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_SOURCING_RULE_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_SOURCING_RULE_STG FOR XXDO.XXDO_SOURCING_RULE_STG
/
