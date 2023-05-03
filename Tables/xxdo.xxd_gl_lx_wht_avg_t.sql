--
-- XXD_GL_LX_WHT_AVG_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_LX_WHT_AVG_T
(
  CONTRACT_REC_ID                           VARCHAR2(1000 BYTE),
  CONTRACT_NAME                             VARCHAR2(1000 BYTE),
  CONTRACT_ID                               VARCHAR2(1000 BYTE),
  IS_APPROVED                               VARCHAR2(1000 BYTE),
  PORTFOLIO                                 VARCHAR2(1000 BYTE),
  FACILITY_ID                               VARCHAR2(1000 BYTE),
  CONTRACT_GROUP                            VARCHAR2(1000 BYTE),
  CONTRACT_TYPE                             VARCHAR2(1000 BYTE),
  CONTRACT_CATEGORY                         VARCHAR2(1000 BYTE),
  CONTRACT_STATUS                           VARCHAR2(1000 BYTE),
  ASSET_CLASS                               VARCHAR2(1000 BYTE),
  INTERNAL_ORG_CODE                         VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER_1                          VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER_2                          VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER_3                          VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER_4                          VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER_5                          VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER_6                          VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER_7                          VARCHAR2(1000 BYTE),
  ACCOUNT_NUMBER_8                          VARCHAR2(1000 BYTE),
  ORGANIZATION_NAME                         VARCHAR2(1000 BYTE),
  ASC_842_SCHEDULE                          VARCHAR2(1000 BYTE),
  IFRS_16_SCHEDULE                          VARCHAR2(1000 BYTE),
  ACCOUNTING_METHOD                         VARCHAR2(1000 BYTE),
  ASSET_NAME                                VARCHAR2(1000 BYTE),
  ACCOUNTING_SCHEDULE_BEGIN_DATE            VARCHAR2(1000 BYTE),
  ACCOUNTING_SCHEDULE_END_DATE              VARCHAR2(1000 BYTE),
  REMAIN_LIKELY_DAYS                        VARCHAR2(1000 BYTE),
  PRE_AMOUNT                                VARCHAR2(1000 BYTE),
  CURNT_PERIOD_LIABILITY_BALAN              VARCHAR2(1000 BYTE),
  CURNT_PERIOD_LIABILITY_BALAN_LES_PRE      VARCHAR2(1000 BYTE),
  CURNT_PERIOD_ASSET_BALAN                  VARCHAR2(1000 BYTE),
  CURNT_REMAIN_BALAN_LEASE_PAY              VARCHAR2(1000 BYTE),
  CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE      VARCHAR2(1000 BYTE),
  DISCOUNT_RATE                             VARCHAR2(1000 BYTE),
  INITIAL_ASSET_BALANCE                     VARCHAR2(1000 BYTE),
  INITIAL_LIABILITY_BALANCE                 VARCHAR2(1000 BYTE),
  FACILITY                                  VARCHAR2(1000 BYTE),
  CONTRACT_CURRENCY_TYPE                    VARCHAR2(1000 BYTE),
  LOCATION                                  VARCHAR2(1000 BYTE),
  WEIGHTED_REMAINING_PAYMENT                VARCHAR2(1000 BYTE),
  WEIGHTED_REMAINING_LEASE_TERM             VARCHAR2(1000 BYTE),
  ATTRIBUTE1                                VARCHAR2(250 BYTE),
  ATTRIBUTE2                                VARCHAR2(250 BYTE),
  ATTRIBUTE3                                VARCHAR2(250 BYTE),
  ATTRIBUTE4                                VARCHAR2(250 BYTE),
  ATTRIBUTE5                                VARCHAR2(250 BYTE),
  ATTRIBUTE6                                VARCHAR2(250 BYTE),
  ATTRIBUTE7                                VARCHAR2(250 BYTE),
  ATTRIBUTE8                                VARCHAR2(250 BYTE),
  ATTRIBUTE9                                VARCHAR2(250 BYTE),
  ATTRIBUTE10                               VARCHAR2(250 BYTE),
  ATTRIBUTE11                               VARCHAR2(250 BYTE),
  ATTRIBUTE12                               VARCHAR2(250 BYTE),
  ATTRIBUTE13                               VARCHAR2(250 BYTE),
  ATTRIBUTE14                               VARCHAR2(250 BYTE),
  ATTRIBUTE15                               VARCHAR2(250 BYTE),
  CREATED_BY                                NUMBER,
  CREATION_DATE                             DATE,
  LAST_UPDATED_BY                           NUMBER,
  LAST_UPDATE_DATE                          DATE,
  REQUEST_ID                                NUMBER,
  FILE_NAME                                 VARCHAR2(1000 BYTE),
  BALAN_RATE                                NUMBER,
  USD_PRE_AMOUNT                            NUMBER,
  USD_CURNT_PERIOD_LIABILITY_BALAN          NUMBER,
  USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE  NUMBER,
  USD_CURNT_PERIOD_ASSET_BALAN              NUMBER,
  USD_CURNT_REMAIN_BALAN_LEASE_PAY          NUMBER,
  USD_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE  NUMBER,
  USD_INITIAL_ASSET_BALANCE                 NUMBER,
  USD_INITIAL_LIABILITY_BALANCE             NUMBER,
  USD_WEIGHTED_REMAINING_PAY                NUMBER,
  USD_WEIGHTED_REMAINING_LEASE_TERM         NUMBER,
  UPDATE_VALUE                              VARCHAR2(250 BYTE),
  DATE_PARAMETER                            DATE,
  REPROCESS_FLAG                            VARCHAR2(10 BYTE),
  RATE_TYPE                                 VARCHAR2(20 BYTE),
  PRECISION                                 NUMBER
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
-- XXD_GL_LX_WHT_AVG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_LX_WHT_AVG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_LX_WHT_AVG_T FOR XXDO.XXD_GL_LX_WHT_AVG_T
/
