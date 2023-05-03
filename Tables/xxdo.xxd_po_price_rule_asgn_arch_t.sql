--
-- XXD_PO_PRICE_RULE_ASGN_ARCH_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_PRICE_RULE_ASGN_ARCH_T
(
  PO_PRC_RUL_ASGN_ARC_ID    NUMBER,
  TARGET_ITEM_ORG_ID        NUMBER,
  TARGET_ITEM_ORGANIZATION  VARCHAR2(50 BYTE),
  PO_PRICE_RULE             VARCHAR2(30 BYTE),
  ITEM_SEGMENT1             VARCHAR2(40 BYTE),
  ITEM_SEGMENT2             VARCHAR2(40 BYTE),
  ITEM_SEGMENT3             VARCHAR2(40 BYTE),
  NEW_PO_PRICE_RULE         VARCHAR2(30 BYTE),
  ACTIVE_START_DATE         DATE,
  ACTIVE_END_DATE           DATE,
  COMMENTS                  VARCHAR2(180 BYTE),
  CREATED_BY                NUMBER,
  CREATION_DATE             DATE,
  LAST_UPDATED_BY           NUMBER,
  LAST_UPDATE_DATE          DATE,
  VENDOR_NAME               VARCHAR2(100 BYTE),
  LAST_UPDATE_LOGIN         NUMBER,
  ATTRIBUTE1                VARCHAR2(240 BYTE),
  ATTRIBUTE2                VARCHAR2(240 BYTE),
  ATTRIBUTE3                VARCHAR2(240 BYTE),
  ATTRIBUTE4                VARCHAR2(240 BYTE),
  ATTRIBUTE5                VARCHAR2(240 BYTE),
  ATTRIBUTE6                VARCHAR2(240 BYTE),
  ATTRIBUTE7                VARCHAR2(240 BYTE),
  ATTRIBUTE8                VARCHAR2(240 BYTE),
  ATTRIBUTE9                VARCHAR2(240 BYTE),
  ATTRIBUTE10               VARCHAR2(240 BYTE),
  ATTRIBUTE11               VARCHAR2(240 BYTE),
  ATTRIBUTE12               VARCHAR2(240 BYTE),
  ATTRIBUTE13               VARCHAR2(240 BYTE),
  ATTRIBUTE14               VARCHAR2(240 BYTE),
  ATTRIBUTE15               VARCHAR2(240 BYTE),
  FILE_ID                   NUMBER,
  FILE_NAME                 VARCHAR2(200 BYTE)
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
-- XXD_PO_PRICE_RULE_ASGN_ARCH_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_PRICE_RULE_ASGN_ARCH_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_PRICE_RULE_ASGN_ARCH_T FOR XXDO.XXD_PO_PRICE_RULE_ASGN_ARCH_T
/
