--
-- XXDO_AR_CUSTOMER_EXTRACT_LOG  (Table) 
--
CREATE TABLE XXDO.XXDO_AR_CUSTOMER_EXTRACT_LOG
(
  CUSTOMER_CODE          VARCHAR2(30 BYTE),
  CUSTOMER_NAME          VARCHAR2(360 BYTE),
  STATUS                 VARCHAR2(10 BYTE),
  CUSTOMER_ADDR1         VARCHAR2(240 BYTE),
  CUSTOMER_ADDR2         VARCHAR2(240 BYTE),
  CUSTOMER_ADDR3         VARCHAR2(240 BYTE),
  CUSTOMER_CITY          VARCHAR2(60 BYTE),
  CUSTOMER_STATE         VARCHAR2(60 BYTE),
  CUSTOMER_ZIP           VARCHAR2(60 BYTE),
  CUSTOMER_COUNTRY_CODE  VARCHAR2(60 BYTE),
  CUSTOMER_COUNTRY_NAME  VARCHAR2(80 BYTE),
  CUSTOMER_PHONE         VARCHAR2(60 BYTE),
  CUSTOMER_EMAIL         VARCHAR2(2000 BYTE),
  CUSTOMER_CATEGORY      VARCHAR2(30 BYTE),
  PROCESS_STATUS         VARCHAR2(20 BYTE),
  ERROR_MESSAGE          VARCHAR2(1000 BYTE),
  REQUEST_ID             NUMBER,
  CREATION_DATE          DATE,
  CREATED_BY             NUMBER,
  LAST_UPDATE_DATE       DATE,
  LAST_UPDATED_BY        NUMBER,
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
  CUST_ACCOUNT_ID        NUMBER,
  ACCOUNT_NUMBER         VARCHAR2(30 BYTE),
  PARTY_ID               NUMBER,
  PARTY_SITE_ID          NUMBER,
  CUST_ACCT_SITE_ID      NUMBER,
  CUST_ACCT_SITE_USE_ID  NUMBER,
  LOCATION_ID            NUMBER,
  OPERATING_UNIT_ID      NUMBER,
  EXTRACT_SEQ_ID         NUMBER,
  ARCHIVE_DATE           DATE                   NOT NULL,
  ARCHIVE_REQUEST_ID     NUMBER                 NOT NULL
)
TABLESPACE CUSTOM_TX_TS
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
/


--
-- XXDO_AR_CUSTOMER_EXTRACT_LOG  (Synonym) 
--
--  Dependencies: 
--   XXDO_AR_CUSTOMER_EXTRACT_LOG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_AR_CUSTOMER_EXTRACT_LOG FOR XXDO.XXDO_AR_CUSTOMER_EXTRACT_LOG
/
