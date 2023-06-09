--
-- XXD_ONT_RMA_INTF_HDR_LOG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_RMA_INTF_HDR_LOG_T
(
  WAREHOUSE_CODE      VARCHAR2(10 BYTE)         NOT NULL,
  ORDER_NUMBER        VARCHAR2(30 BYTE)         NOT NULL,
  ORDER_TYPE          VARCHAR2(50 BYTE)         NOT NULL,
  COMPANY             VARCHAR2(50 BYTE)         NOT NULL,
  BRAND_CODE          VARCHAR2(100 BYTE),
  CUSTOMER_CODE       VARCHAR2(30 BYTE)         NOT NULL,
  CUSTOMER_NAME       VARCHAR2(50 BYTE),
  STATUS              VARCHAR2(10 BYTE),
  ORDER_DATE          DATE,
  PROCESS_STATUS      VARCHAR2(20 BYTE),
  ERROR_MESSAGE       VARCHAR2(1000 BYTE),
  SALES_CHANNEL_CODE  VARCHAR2(30 BYTE),
  REQUEST_ID          NUMBER,
  CREATION_DATE       DATE,
  CREATED_BY          NUMBER,
  LAST_UPDATE_DATE    DATE,
  LAST_UPDATED_BY     NUMBER,
  LAST_UPDATE_LOGIN   NUMBER,
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
  SOURCE              VARCHAR2(20 BYTE)         DEFAULT 'EBS',
  DESTINATION         VARCHAR2(20 BYTE)         DEFAULT 'WMS',
  HEADER_ID           NUMBER                    NOT NULL,
  AUTO_RECEIPT_FLAG   NUMBER,
  RETURN_SOURCE       VARCHAR2(100 BYTE),
  BATCH_NUMBER        NUMBER
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
-- XXD_ONT_RMA_INTF_HDR_LOG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_RMA_INTF_HDR_LOG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_RMA_INTF_HDR_LOG_T FOR XXDO.XXD_ONT_RMA_INTF_HDR_LOG_T
/
