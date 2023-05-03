--
-- XXDO_PO_ASN_POS_LOG  (Table) 
--
CREATE TABLE XXDO.XXDO_PO_ASN_POS_LOG
(
  WAREHOUSE_CODE      VARCHAR2(10 BYTE)         NOT NULL,
  SHIPMENT_NUMBER     VARCHAR2(30 BYTE)         NOT NULL,
  PO_NUMBER           VARCHAR2(30 BYTE)         NOT NULL,
  PO_TYPE             VARCHAR2(30 BYTE)         NOT NULL,
  FACTORY_CODE        VARCHAR2(20 BYTE),
  FACTORY_NAME        VARCHAR2(50 BYTE),
  PROCESS_STATUS      VARCHAR2(20 BYTE),
  ERROR_MESSAGE       VARCHAR2(1000 BYTE),
  REQUEST_ID          NUMBER,
  CREATION_DATE       DATE,
  CREATED_BY          NUMBER,
  LAST_UPDATE_DATE    DATE,
  LAST_UPDATED_BY     NUMBER,
  SOURCE_TYPE         VARCHAR2(20 BYTE),
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
  ATTRIBUTE20         VARCHAR2(50 BYTE),
  SOURCE              VARCHAR2(20 BYTE),
  DESTINATION         VARCHAR2(20 BYTE),
  RECORD_TYPE         VARCHAR2(20 BYTE),
  PO_HEADER_ID        NUMBER,
  ARCHIVE_DATE        DATE                      NOT NULL,
  ARCHIVE_REQUEST_ID  NUMBER                    NOT NULL,
  PO_SEQ_ID           NUMBER,
  ASN_HEADER_SEQ_ID   NUMBER
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
-- XXDO_PO_ASN_POS_LOG  (Synonym) 
--
--  Dependencies: 
--   XXDO_PO_ASN_POS_LOG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_PO_ASN_POS_LOG FOR XXDO.XXDO_PO_ASN_POS_LOG
/