--
-- XXDO_ONT_RMA_LINE_SERL_STG_LOG  (Table) 
--
CREATE TABLE XXDO.XXDO_ONT_RMA_LINE_SERL_STG_LOG
(
  WH_ID                  VARCHAR2(10 BYTE),
  RMA_NUMBER             VARCHAR2(30 BYTE),
  LINE_NUMBER            NUMBER,
  ITEM_NUMBER            VARCHAR2(30 BYTE),
  SERIAL_NUMBER          VARCHAR2(30 BYTE),
  RMA_REFERENCE          VARCHAR2(30 BYTE),
  REQUEST_ID             NUMBER,
  CREATION_DATE          DATE,
  CREATED_BY             NUMBER,
  LAST_UPDATE_DATE       DATE,
  LAST_UPDATED_BY        NUMBER,
  LAST_UPDATE_LOGIN      NUMBER,
  SOURCE                 VARCHAR2(20 BYTE)      DEFAULT 'WMS',
  DESTINATION            VARCHAR2(20 BYTE)      DEFAULT 'EBS',
  RECORD_TYPE            VARCHAR2(20 BYTE),
  HEADER_ID              NUMBER,
  LINE_ID                NUMBER,
  LINE_SERIAL_ID         NUMBER,
  ATTRIBUTE1             VARCHAR2(50 BYTE),
  ATTRIBUTE2             VARCHAR2(50 BYTE),
  ATTRIBUTE3             VARCHAR2(50 BYTE),
  ATTRIBUTE4             VARCHAR2(50 BYTE),
  ATTRIBUTE5             VARCHAR2(50 BYTE),
  ATTRIBUTE6             VARCHAR2(50 BYTE),
  ATTRIBUTE7             VARCHAR2(50 BYTE),
  ATTRIBUTE8             VARCHAR2(50 BYTE),
  ATTRIBUTE9             VARCHAR2(50 BYTE),
  ATTRIBUTE10            VARCHAR2(50 BYTE),
  ATTRIBUTE11            VARCHAR2(50 BYTE),
  ATTRIBUTE12            VARCHAR2(50 BYTE),
  ATTRIBUTE13            VARCHAR2(50 BYTE),
  ATTRIBUTE14            VARCHAR2(50 BYTE),
  ATTRIBUTE15            VARCHAR2(50 BYTE),
  ATTRIBUTE16            VARCHAR2(50 BYTE),
  ATTRIBUTE17            VARCHAR2(50 BYTE),
  ATTRIBUTE18            VARCHAR2(50 BYTE),
  ATTRIBUTE19            VARCHAR2(50 BYTE),
  ATTRIBUTE20            VARCHAR2(50 BYTE),
  PROCESS_STATUS         VARCHAR2(30 BYTE),
  ERROR_MESSAGE          VARCHAR2(2000 BYTE),
  RECEIPT_HEADER_SEQ_ID  NUMBER,
  RECEIPT_LINE_SEQ_ID    NUMBER,
  RECEIPT_SERIAL_SEQ_ID  NUMBER,
  RESULT_CODE            VARCHAR2(2 BYTE),
  RETCODE                VARCHAR2(2 BYTE),
  INVENTORY_ITEM_ID      NUMBER,
  ORGANIZATION_ID        NUMBER,
  ARCHIVE_DATE           DATE,
  ARCHIVE_REQUEST_ID     NUMBER
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
-- XXDO_ONT_RMA_LINE_SERL_STG_LOG  (Synonym) 
--
--  Dependencies: 
--   XXDO_ONT_RMA_LINE_SERL_STG_LOG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_ONT_RMA_LINE_SERL_STG_LOG FOR XXDO.XXDO_ONT_RMA_LINE_SERL_STG_LOG
/
