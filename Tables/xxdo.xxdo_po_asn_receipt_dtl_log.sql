--
-- XXDO_PO_ASN_RECEIPT_DTL_LOG  (Table) 
--
CREATE TABLE XXDO.XXDO_PO_ASN_RECEIPT_DTL_LOG
(
  WH_ID                  VARCHAR2(10 BYTE)      NOT NULL,
  APPOINTMENT_ID         VARCHAR2(30 BYTE),
  SHIPMENT_NUMBER        VARCHAR2(60 BYTE),
  PO_NUMBER              VARCHAR2(60 BYTE),
  CARTON_ID              VARCHAR2(250 BYTE),
  LINE_NUMBER            VARCHAR2(10 BYTE),
  ITEM_NUMBER            VARCHAR2(60 BYTE),
  RCPT_TYPE              VARCHAR2(30 BYTE),
  QTY                    NUMBER,
  ORDERED_UOM            VARCHAR2(30 BYTE),
  HOST_SUBINVENTORY      VARCHAR2(60 BYTE),
  PROCESS_STATUS         VARCHAR2(20 BYTE)      NOT NULL,
  ERROR_MESSAGE          VARCHAR2(1000 BYTE),
  REQUEST_ID             NUMBER                 NOT NULL,
  CREATION_DATE          DATE                   NOT NULL,
  CREATED_BY             NUMBER                 NOT NULL,
  LAST_UPDATE_DATE       DATE                   NOT NULL,
  LAST_UPDATED_BY        NUMBER                 NOT NULL,
  SOURCE_TYPE            VARCHAR2(20 BYTE),
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
  SOURCE                 VARCHAR2(20 BYTE)      DEFAULT 'ORDER'               NOT NULL,
  DESTINATION            VARCHAR2(20 BYTE)      NOT NULL,
  RECORD_TYPE            VARCHAR2(20 BYTE)      DEFAULT 'EBS'                 NOT NULL,
  SHIPMENT_HEADER_ID     NUMBER,
  PO_HEADER_ID           NUMBER,
  LPN_ID                 NUMBER,
  INVENTORY_ITEM_ID      NUMBER,
  RECEIPT_HEADER_SEQ_ID  NUMBER,
  RECEIPT_DTL_SEQ_ID     NUMBER,
  ARCHIVE_DATE           DATE                   NOT NULL,
  ARCHIVE_REQUEST_ID     NUMBER                 NOT NULL,
  ORGANIZATION_ID        NUMBER,
  RECEIPT_SOURCE_CODE    VARCHAR2(30 BYTE),
  OPEN_QTY               NUMBER,
  PO_LINE_ID             NUMBER,
  SHIPMENT_LINE_ID       NUMBER,
  REQUISITION_HEADER_ID  NUMBER,
  REQUISITION_LINE_ID    NUMBER,
  GROUP_ID               NUMBER,
  ORG_ID                 NUMBER,
  LOCATOR                VARCHAR2(286 BYTE),
  LOCATOR_ID             NUMBER,
  VENDOR_ID              NUMBER
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
-- XXDO_PO_ASN_RECEIPT_DTL_LOG  (Synonym) 
--
--  Dependencies: 
--   XXDO_PO_ASN_RECEIPT_DTL_LOG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_PO_ASN_RECEIPT_DTL_LOG FOR XXDO.XXDO_PO_ASN_RECEIPT_DTL_LOG
/
