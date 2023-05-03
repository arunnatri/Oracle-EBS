--
-- XXDO_INV_TRANS_ADJ_DTL_LOG  (Table) 
--
CREATE TABLE XXDO.XXDO_INV_TRANS_ADJ_DTL_LOG
(
  WH_ID                     VARCHAR2(10 BYTE),
  SOURCE_SUBINVENTORY       VARCHAR2(60 BYTE),
  DEST_SUBINVENTORY         VARCHAR2(60 BYTE),
  SOURCE_LOCATOR            VARCHAR2(200 BYTE),
  DESTINATION_LOCATOR       VARCHAR2(200 BYTE),
  TRAN_DATE                 DATE,
  ITEM_NUMBER               VARCHAR2(60 BYTE),
  QTY                       NUMBER,
  UOM                       VARCHAR2(30 BYTE),
  EMPLOYEE_ID               VARCHAR2(10 BYTE),
  EMPLOYEE_NAME             VARCHAR2(100 BYTE),
  REASON_CODE               VARCHAR2(200 BYTE),
  COMMENTS                  VARCHAR2(2000 BYTE),
  ORGANIZATION_ID           NUMBER,
  INVENTORY_ITEM_ID         NUMBER,
  SOURCE_LOCATOR_ID         NUMBER,
  DESTINATION_LOCATOR_ID    NUMBER,
  TRANSACTION_SEQ_ID        NUMBER,
  PROCESS_STATUS            VARCHAR2(20 BYTE),
  ERROR_MESSAGE             VARCHAR2(1000 BYTE),
  REQUEST_ID                NUMBER,
  CREATION_DATE             DATE,
  CREATED_BY                NUMBER,
  LAST_UPDATE_DATE          DATE,
  LAST_UPDATED_BY           NUMBER,
  SOURCE_TYPE               VARCHAR2(20 BYTE),
  ATTRIBUTE1                VARCHAR2(50 BYTE),
  ATTRIBUTE2                VARCHAR2(50 BYTE),
  ATTRIBUTE3                VARCHAR2(50 BYTE),
  ATTRIBUTE4                VARCHAR2(50 BYTE),
  ATTRIBUTE5                VARCHAR2(50 BYTE),
  ATTRIBUTE6                VARCHAR2(50 BYTE),
  ATTRIBUTE7                VARCHAR2(50 BYTE),
  ATTRIBUTE8                VARCHAR2(50 BYTE),
  ATTRIBUTE9                VARCHAR2(50 BYTE),
  ATTRIBUTE10               VARCHAR2(50 BYTE),
  ATTRIBUTE11               VARCHAR2(50 BYTE),
  ATTRIBUTE12               VARCHAR2(50 BYTE),
  ATTRIBUTE13               VARCHAR2(50 BYTE),
  ATTRIBUTE14               VARCHAR2(50 BYTE),
  ATTRIBUTE15               VARCHAR2(50 BYTE),
  ATTRIBUTE16               VARCHAR2(50 BYTE),
  ATTRIBUTE17               VARCHAR2(50 BYTE),
  ATTRIBUTE18               VARCHAR2(50 BYTE),
  ATTRIBUTE19               VARCHAR2(50 BYTE),
  ATTRIBUTE20               VARCHAR2(50 BYTE),
  SOURCE                    VARCHAR2(20 BYTE),
  DESTINATION               VARCHAR2(20 BYTE),
  RECORD_TYPE               VARCHAR2(20 BYTE),
  ARCHIVE_DATE              DATE,
  ARCHIVE_REQUEST_ID        NUMBER,
  INTERFACE_TRANSACTION_ID  NUMBER,
  SESSION_ID                NUMBER,
  SERVER_TRAN_DATE          DATE
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
-- XXDO_INV_TRANS_ADJ_DTL_LOG  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_TRANS_ADJ_DTL_LOG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_TRANS_ADJ_DTL_LOG FOR XXDO.XXDO_INV_TRANS_ADJ_DTL_LOG
/
