--
-- XXD_WMS_EMAIL_OUTPUT_T  (Table) 
--
CREATE TABLE XXDO.XXD_WMS_EMAIL_OUTPUT_T
(
  REQUEST_ID                 NUMBER,
  CONTAINER_NUMBER           VARCHAR2(250 BYTE),
  ORDER_NUMBER               NUMBER,
  CUST_PO_NUMBER             VARCHAR2(250 BYTE),
  DELIVERY_ID                NUMBER,
  NEW_TRIGGERING_EVENT_NAME  VARCHAR2(250 BYTE),
  OLD_TRIGGERING_EVENT_NAME  VARCHAR2(250 BYTE),
  ATTRIBUTE1                 VARCHAR2(240 BYTE),
  ATTRIBUTE2                 VARCHAR2(240 BYTE),
  ATTRIBUTE3                 VARCHAR2(240 BYTE),
  ATTRIBUTE4                 VARCHAR2(240 BYTE),
  ATTRIBUTE5                 VARCHAR2(240 BYTE),
  ATTRIBUTE6                 VARCHAR2(240 BYTE),
  ATTRIBUTE7                 VARCHAR2(240 BYTE),
  ATTRIBUTE8                 VARCHAR2(240 BYTE),
  ATTRIBUTE9                 VARCHAR2(240 BYTE),
  ATTRIBUTE10                VARCHAR2(240 BYTE),
  ATTRIBUTE11                VARCHAR2(240 BYTE),
  ATTRIBUTE12                VARCHAR2(240 BYTE),
  ATTRIBUTE13                VARCHAR2(240 BYTE),
  ATTRIBUTE14                VARCHAR2(240 BYTE),
  ATTRIBUTE15                VARCHAR2(240 BYTE),
  CREATION_DATE              DATE,
  CREATED_BY                 NUMBER,
  LAST_UPDATE_DATE           DATE,
  LAST_UPDATED_BY            NUMBER,
  LAST_UPDATE_LOGIN          NUMBER,
  SOURCE                     VARCHAR2(50 BYTE),
  INV_ORG_CODE               VARCHAR2(50 BYTE),
  SEQ_ID                     NUMBER,
  STATUS                     VARCHAR2(10 BYTE),
  ERROR_MESSAGE              VARCHAR2(4000 BYTE)
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
-- XXD_WMS_EMAIL_OUT_REQID_IDX  (Index) 
--
--  Dependencies: 
--   XXD_WMS_EMAIL_OUTPUT_T (Table)
--
CREATE INDEX XXDO.XXD_WMS_EMAIL_OUT_REQID_IDX ON XXDO.XXD_WMS_EMAIL_OUTPUT_T
(REQUEST_ID)
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
-- XXD_WMS_EMAIL_OUTPUT_T  (Synonym) 
--
--  Dependencies: 
--   XXD_WMS_EMAIL_OUTPUT_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_WMS_EMAIL_OUTPUT_T FOR XXDO.XXD_WMS_EMAIL_OUTPUT_T
/
