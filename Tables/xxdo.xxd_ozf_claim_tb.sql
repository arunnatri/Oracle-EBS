--
-- XXD_OZF_CLAIM_TB  (Table) 
--
CREATE TABLE XXDO.XXD_OZF_CLAIM_TB
(
  CLAIM_ID               NUMBER,
  CLAIM_NUMBER           VARCHAR2(100 BYTE),
  OWNER_ID               NUMBER,
  STATUS                 VARCHAR2(2 BYTE),
  ORG_ID                 NUMBER,
  OBJECT_VERSION_NUMBER  NUMBER
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
-- XXD_OZF_CLAIM_TB  (Synonym) 
--
--  Dependencies: 
--   XXD_OZF_CLAIM_TB (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_OZF_CLAIM_TB FOR XXDO.XXD_OZF_CLAIM_TB
/
