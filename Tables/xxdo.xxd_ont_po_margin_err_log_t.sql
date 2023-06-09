--
-- XXD_ONT_PO_MARGIN_ERR_LOG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_PO_MARGIN_ERR_LOG_T
(
  REQUEST_ID        NUMBER,
  ERROR_MESSAGE_1   VARCHAR2(4000 BYTE),
  ERROR_MESSAGE_2   VARCHAR2(4000 BYTE),
  ERROR_MESSAGE_3   VARCHAR2(4000 BYTE),
  ERROR_MESSAGE_4   VARCHAR2(4000 BYTE),
  ERROR_MESSAGE_5   VARCHAR2(4000 BYTE),
  CREATION_DATE     DATE,
  CREATED_BY        NUMBER,
  LAST_UPDATE_DATE  DATE,
  LAST_UPDATED_BY   NUMBER,
  ATTRIBUTE1        VARCHAR2(150 BYTE),
  ATTRIBUTE2        VARCHAR2(150 BYTE),
  ATTRIBUTE3        VARCHAR2(150 BYTE),
  ATTRIBUTE4        VARCHAR2(150 BYTE),
  ATTRIBUTE5        VARCHAR2(150 BYTE),
  ATTRIBUTE6        VARCHAR2(150 BYTE),
  ATTRIBUTE7        VARCHAR2(150 BYTE),
  ATTRIBUTE8        VARCHAR2(150 BYTE),
  ATTRIBUTE9        VARCHAR2(150 BYTE),
  ATTRIBUTE10       VARCHAR2(150 BYTE),
  ATTRIBUTE11       VARCHAR2(150 BYTE),
  ATTRIBUTE12       VARCHAR2(150 BYTE),
  ATTRIBUTE13       VARCHAR2(150 BYTE),
  ATTRIBUTE14       VARCHAR2(150 BYTE),
  ATTRIBUTE15       VARCHAR2(150 BYTE),
  ATTRIBUTE16       VARCHAR2(150 BYTE),
  ATTRIBUTE17       VARCHAR2(150 BYTE),
  ATTRIBUTE18       VARCHAR2(150 BYTE),
  ATTRIBUTE19       VARCHAR2(150 BYTE),
  ATTRIBUTE20       VARCHAR2(150 BYTE)
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
-- XXD_ONT_PO_MARGIN_ERR_LOG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_PO_MARGIN_ERR_LOG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_PO_MARGIN_ERR_LOG_T FOR XXDO.XXD_ONT_PO_MARGIN_ERR_LOG_T
/
