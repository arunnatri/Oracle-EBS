--
-- XXD_GL_FASB_MIN_LX_OBLIG_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T
(
  CONTRACT_TYPE                     VARCHAR2(1000 BYTE),
  ACCOUNTING_METHOD                 VARCHAR2(1000 BYTE),
  PORTFOLIO                         VARCHAR2(1000 BYTE),
  CONTRACT_NAME                     VARCHAR2(1000 BYTE),
  CONTRACT_NUMBER                   VARCHAR2(1000 BYTE),
  ASC_842_SCHEDULE                  VARCHAR2(1000 BYTE),
  EQUIPMENT                         VARCHAR2(1000 BYTE),
  BEGIN_DATE                        VARCHAR2(1000 BYTE),
  END_DATE                          VARCHAR2(1000 BYTE),
  YEAR_1                            VARCHAR2(1000 BYTE),
  YEAR_2                            VARCHAR2(1000 BYTE),
  YEAR_3                            VARCHAR2(1000 BYTE),
  YEAR_4                            VARCHAR2(1000 BYTE),
  YEAR_5                            VARCHAR2(1000 BYTE),
  YEAR_6_PLUS                       VARCHAR2(1000 BYTE),
  TOTAL_REMAINING_OBLIGATION        VARCHAR2(1000 BYTE),
  IMPUTED_INTEREST                  VARCHAR2(1000 BYTE),
  LEASE_LIABILITY_RX                VARCHAR2(1000 BYTE),
  CURRENCY_TYPE                     VARCHAR2(1000 BYTE),
  PREPAID_AMOUNT                    VARCHAR2(1000 BYTE),
  LEASE_LIABILITY_LESS_PREPAID      VARCHAR2(1000 BYTE),
  ATTRIBUTE1                        VARCHAR2(250 BYTE),
  ATTRIBUTE2                        VARCHAR2(250 BYTE),
  ATTRIBUTE3                        VARCHAR2(250 BYTE),
  ATTRIBUTE4                        VARCHAR2(250 BYTE),
  ATTRIBUTE5                        VARCHAR2(250 BYTE),
  ATTRIBUTE6                        VARCHAR2(250 BYTE),
  ATTRIBUTE7                        VARCHAR2(250 BYTE),
  ATTRIBUTE8                        VARCHAR2(250 BYTE),
  ATTRIBUTE9                        VARCHAR2(250 BYTE),
  ATTRIBUTE10                       VARCHAR2(250 BYTE),
  ATTRIBUTE11                       VARCHAR2(250 BYTE),
  ATTRIBUTE12                       VARCHAR2(250 BYTE),
  ATTRIBUTE13                       VARCHAR2(250 BYTE),
  ATTRIBUTE14                       VARCHAR2(250 BYTE),
  ATTRIBUTE15                       VARCHAR2(250 BYTE),
  CREATED_BY                        NUMBER,
  CREATION_DATE                     DATE,
  LAST_UPDATED_BY                   NUMBER,
  LAST_UPDATE_DATE                  DATE,
  REQUEST_ID                        NUMBER,
  FILE_NAME                         VARCHAR2(2000 BYTE),
  RATE_TYPE                         VARCHAR2(100 BYTE),
  DATE_PARAMETER                    DATE,
  RATE                              NUMBER,
  REPROCESS_FLAG                    VARCHAR2(10 BYTE),
  PRECISION                         NUMBER,
  USD_YEAR_1                        NUMBER,
  USD_YEAR_2                        NUMBER,
  USD_YEAR_3                        NUMBER,
  USD_YEAR_4                        NUMBER,
  USD_YEAR_5                        NUMBER,
  USD_YEAR_6_PLUS                   NUMBER,
  USD_TOTAL_REMAINING_OBLIGATION    NUMBER,
  USD_IMPUTED_INTEREST              NUMBER,
  USD_LEASE_LIABILITY_RX            NUMBER,
  USD_PREPAID_AMOUNT                NUMBER,
  USD_LEASE_LIABILITY_LESS_PREPAID  NUMBER
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
-- XXD_GL_FASB_MIN_LX_OBLIG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_FASB_MIN_LX_OBLIG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_FASB_MIN_LX_OBLIG_T FOR XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T
/
