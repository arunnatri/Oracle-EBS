--
-- XXD_GL_LX_WHT_AVG_SUMRY_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_LX_WHT_AVG_SUMRY_T
(
  DATE_REPORT_WAS_RUN                           VARCHAR2(250 BYTE),
  EFFECTIVE_PERIOD_BEGIN_DATE                   VARCHAR2(250 BYTE),
  EFFECTIVE_PERIOD_END_DATE                     VARCHAR2(250 BYTE),
  WEIGHTED_AVG_DISC_RATE                        VARCHAR2(250 BYTE),
  WEIGHTED_AVG_REMAINING_LEASE_TERM_DAYS        VARCHAR2(250 BYTE),
  WEIGHTED_AVG_REMAINING_LEASE_TERM_YEARS       VARCHAR2(250 BYTE),
  ATTRIBUTE1                                    VARCHAR2(250 BYTE),
  ATTRIBUTE2                                    VARCHAR2(250 BYTE),
  ATTRIBUTE3                                    VARCHAR2(250 BYTE),
  ATTRIBUTE4                                    VARCHAR2(250 BYTE),
  ATTRIBUTE5                                    VARCHAR2(250 BYTE),
  ATTRIBUTE6                                    VARCHAR2(250 BYTE),
  ATTRIBUTE7                                    VARCHAR2(250 BYTE),
  ATTRIBUTE8                                    VARCHAR2(250 BYTE),
  ATTRIBUTE9                                    VARCHAR2(250 BYTE),
  ATTRIBUTE10                                   VARCHAR2(250 BYTE),
  ATTRIBUTE11                                   VARCHAR2(250 BYTE),
  ATTRIBUTE12                                   VARCHAR2(250 BYTE),
  ATTRIBUTE13                                   VARCHAR2(250 BYTE),
  ATTRIBUTE14                                   VARCHAR2(250 BYTE),
  ATTRIBUTE15                                   VARCHAR2(250 BYTE),
  USD_WEIGHTED_AVG_DISC_RATE                    NUMBER,
  USD_WEIGHTED_AVG_REMAINING_LEASE_TERM_DAYS    NUMBER,
  USD_WEIGHTED_AVG_REMAINING_LEASE_TERM_YEARS   NUMBER,
  CREATED_BY                                    NUMBER,
  CREATION_DATE                                 DATE,
  LAST_UPDATED_BY                               NUMBER,
  LAST_UPDATE_DATE                              DATE,
  REQUEST_ID                                    NUMBER,
  FILE_NAME                                     VARCHAR2(1000 BYTE),
  REPROCESS_FLAG                                VARCHAR2(10 BYTE),
  DATE_PARAMETER                                DATE,
  SUM_PRE_AMOUNT                                NUMBER,
  SUM_CURNT_PERIOD_LIABILITY_BALAN              NUMBER,
  SUM_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE      NUMBER,
  SUM_CURNT_PERIOD_ASSET_BALAN                  NUMBER,
  SUM_CURNT_REMAIN_BALAN_LEASE_PAY              NUMBER,
  SUM_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE      NUMBER,
  SUM_INITIAL_ASSET_BALANCE                     NUMBER,
  SUM_INITIAL_LIABILITY_BALANCE                 NUMBER,
  SUM_WEIGHTED_REMAINING_PAYMENT                NUMBER,
  SUM_WEIGHTED_REMAINING_LEASE_TERM             NUMBER,
  SUM_USD_PRE_AMOUNT                            NUMBER,
  SUM_USD_CURNT_PERIOD_LIABILITY_BALAN          NUMBER,
  SUM_USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE  NUMBER,
  SUM_USD_CURNT_PERIOD_ASSET_BALAN              NUMBER,
  SUM_USD_CURNT_REMAIN_BALAN_LEASE_PAY          NUMBER,
  SUM_USD_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE  NUMBER,
  SUM_USD_INITIAL_ASSET_BALANCE                 NUMBER,
  SUM_USD_INITIAL_LIABILITY_BALANCE             NUMBER,
  SUM_USD_WEIGHTED_REMAINING_PAY                NUMBER,
  SUM_USD_WEIGHTED_REMAINING_LEASE_TERM         NUMBER
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
-- XXD_GL_LX_WHT_AVG_SUMRY_T  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_LX_WHT_AVG_SUMRY_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_LX_WHT_AVG_SUMRY_T FOR XXDO.XXD_GL_LX_WHT_AVG_SUMRY_T
/
