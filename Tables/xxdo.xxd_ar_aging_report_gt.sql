--
-- XXD_AR_AGING_REPORT_GT  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXD_AR_AGING_REPORT_GT
(
  BRAND                        VARCHAR2(150 BYTE),
  ORG_NAME                     VARCHAR2(240 BYTE),
  ACCOUNT_NUMBER               VARCHAR2(100 BYTE),
  CUSTOMER_NUMBER              VARCHAR2(100 BYTE),
  CUSTOMER_NAME                VARCHAR2(360 BYTE),
  CUST_ADDRESS1                VARCHAR2(400 BYTE),
  CUST_STATE                   VARCHAR2(300 BYTE),
  CUST_ZIP                     VARCHAR2(300 BYTE),
  COLLECTOR                    VARCHAR2(360 BYTE),
  CREDIT_ANALYST               VARCHAR2(360 BYTE),
  CHARGEBACK_ANALYST           VARCHAR2(360 BYTE),
  PROFILE_CLASS                VARCHAR2(360 BYTE),
  OVERALL_CREDIT_LIMIT         NUMBER,
  TYPE                         VARCHAR2(100 BYTE),
  TRANSACTION_NAME             VARCHAR2(100 BYTE),
  TERM                         VARCHAR2(400 BYTE),
  DESCRIPTION                  VARCHAR2(240 BYTE),
  INVOICE_CURRENCY_CODE        VARCHAR2(100 BYTE),
  DUE_DATE                     DATE,
  GL_DATE                      DATE,
  PAYMENT_SCHEDULE_ID          NUMBER(15),
  CLASS                        VARCHAR2(100 BYTE),
  TRX_RCPT_NUMBER              VARCHAR2(100 BYTE),
  INTERFACE_HEADER_ATTRIBUTE1  VARCHAR2(150 BYTE),
  PURCHASE_ORDER               VARCHAR2(100 BYTE),
  SALESREP_NAME                VARCHAR2(240 BYTE),
  SALESREP_NUMBER              VARCHAR2(50 BYTE),
  TRX_DATE                     DATE,
  AMOUNT_DUE_ORIGINAL          NUMBER,
  AMOUNT_APPLIED               NUMBER,
  AMOUNT_ADJUSTED              NUMBER,
  STATUS                       VARCHAR2(240 BYTE),
  AMOUNT_CREDITED              NUMBER,
  REASON_CODE                  VARCHAR2(4000 BYTE),
  AMOUNT_IN_DISPUTE            NUMBER,
  AMOUNT_DUE                   NUMBER,
  AGING_REPORT_HEADING1        VARCHAR2(100 BYTE),
  AGING_REPORT_HEADING2        VARCHAR2(100 BYTE),
  BUCKET_SEQUENCE_NUM          NUMBER,
  CREATION_DATE                DATE,
  CREATED_BY                   NUMBER,
  LAST_UPDATE_DATE             DATE,
  LAST_UPDATED_BY              NUMBER,
  REQUEST_ID                   NUMBER,
  AGING_BUCKET1                NUMBER,
  AGING_BUCKET2                NUMBER,
  AGING_BUCKET3                NUMBER,
  AGING_BUCKET4                NUMBER,
  AGING_BUCKET5                NUMBER,
  AGING_BUCKET6                NUMBER,
  AGING_BUCKET7                NUMBER,
  AGING_BUCKET8                NUMBER,
  AGING_BUCKET9                NUMBER,
  AGING_BUCKET10               NUMBER,
  DAYS_PAST_DUE                NUMBER,
  SALES_CHANNEL                VARCHAR2(30 BYTE),
  CUST_CLASSIFICATION          VARCHAR2(30 BYTE),
  PAYMENT_TERMS                VARCHAR2(30 BYTE),
  ORG_ID                       NUMBER
)
ON COMMIT PRESERVE ROWS
NOCACHE
/


--
-- XXD_AR_AGING_REPORT_GT  (Synonym) 
--
--  Dependencies: 
--   XXD_AR_AGING_REPORT_GT (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_AR_AGING_REPORT_GT FOR XXDO.XXD_AR_AGING_REPORT_GT
/
