--
-- XXDOAP_COMMISSIONS_STG  (Table) 
--
CREATE TABLE XXDO.XXDOAP_COMMISSIONS_STG
(
  REQUEST_ID                    NUMBER,
  PROCESS_FLAG                  VARCHAR2(1 BYTE),
  STATUS_MESSAGE                VARCHAR2(4000 BYTE),
  SOURCE_TRX_ORG_ID             NUMBER,
  SOURCE_TRX_ORG_NAME           VARCHAR2(100 BYTE),
  SOURCE_TRX_TYPE               VARCHAR2(50 BYTE),
  SOURCE_TRX_DATE               DATE,
  SOURCE_TRX_NUMBER             VARCHAR2(50 BYTE),
  SOURCE_SUPPLIER_NAME          VARCHAR2(360 BYTE),
  SOURCE_SUPPLIER_SITE_CODE     VARCHAR2(50 BYTE),
  SOURCE_SUPPLIER_ID            NUMBER,
  SOURCE_SUPPLIER_SITE_ID       NUMBER,
  SAMPLE_INVOICE                VARCHAR2(1 BYTE),
  CUTOFF_DATE                   DATE,
  COMMISSION_PERCENTAGE         NUMBER,
  TARGET_AR_ORG_NAME            VARCHAR2(50 BYTE),
  TARGET_AR_ORG_ID              NUMBER,
  TARGET_AP_ORG_NAME            VARCHAR2(50 BYTE),
  TARGET_AP_ORG_ID              NUMBER,
  TARGET_CUSTOMER_ID            NUMBER,
  TARGET_CUSTOMER_NAME          VARCHAR2(50 BYTE),
  TARGET_CUSTOMER_SITE_ID       NUMBER,
  TARGET_CUSTOMER_SITE_USE_ID   NUMBER,
  TARGET_CUSTOMER_SITE_NAME     VARCHAR2(50 BYTE),
  TARGET_SUPPLIER_ID            NUMBER,
  TARGET_SUPPLIER_NAME          VARCHAR2(50 BYTE),
  TARGET_SUPPLIER_SITE_ID       NUMBER,
  TARGET_SUPPLIER_SITE_CODE     VARCHAR2(50 BYTE),
  TARGET_SUPPLIER_SITE_ADDRESS  VARCHAR2(100 BYTE),
  TARGET_AP_TRX_NUMBER          NUMBER,
  TARGET_AP_TRX_ID              NUMBER,
  TARGET_AR_TRX_NUMBER          NUMBER,
  TARGET_AR_TRX_ID              NUMBER,
  TARGET_AP_TRX_AMOUNT          NUMBER,
  TARGET_AR_TRX_AMOUNT          NUMBER,
  TARGET_AR_TRX_DATE            DATE,
  TARGET_AP_TRX_DATE            DATE,
  LINKED_PO_NUMBER              VARCHAR2(50 BYTE),
  CREATED_BY                    NUMBER,
  CREATION_DATE                 DATE,
  LAST_UPDATE_DATE              DATE,
  LAST_UPDATED_BY               NUMBER,
  LAST_UPDATE_LOGIN             NUMBER,
  TARGET_CUSTOMER_NUM           VARCHAR2(30 BYTE),
  SOURCE_TRX_ID                 NUMBER,
  EXCHANGE_RATE                 NUMBER,
  EXCHANGE_RATE_TYPE            VARCHAR2(30 BYTE),
  CURRENCY_CODE                 VARCHAR2(30 BYTE),
  SOURCE_TRX_AMOUNT             NUMBER,
  BRAND                         VARCHAR2(30 BYTE),
  CURRENT_STATUS_FLAG           VARCHAR2(5 BYTE),
  CURRENT_STATUS_MSG            VARCHAR2(50 BYTE)
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOAP_COMMISSIONS_STG TO APPS
/