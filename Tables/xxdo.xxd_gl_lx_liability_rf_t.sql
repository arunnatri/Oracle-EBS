--
-- XXD_GL_LX_LIABILITY_RF_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_LX_LIABILITY_RF_T
(
  PORTFOLIO                                              VARCHAR2(1000 BYTE),
  CONTRACT_NAME                                          VARCHAR2(1000 BYTE),
  CURRENCY_TYPE                                          VARCHAR2(1000 BYTE),
  FISCAL_PERIOD_YEAR                                     VARCHAR2(1000 BYTE),
  FISCAL_PERIOD                                          VARCHAR2(1000 BYTE),
  CUMULATIVE_PERIOD_NUMBER                               VARCHAR2(1000 BYTE),
  BEGIN_DATE                                             VARCHAR2(1000 BYTE),
  BEGINNING_BALANCE                                      VARCHAR2(1000 BYTE),
  ADDITION                                               VARCHAR2(1000 BYTE),
  REDUCTION                                              VARCHAR2(1000 BYTE),
  PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC             VARCHAR2(1000 BYTE),
  CLOSING_BALANCE                                        VARCHAR2(1000 BYTE),
  SHORT_TERM                                             VARCHAR2(1000 BYTE),
  LONG_TERM                                              VARCHAR2(1000 BYTE),
  PREPAID_AMOUNT                                         VARCHAR2(1000 BYTE),
  CLOSING_BALANCE_LESS_PREPAID                           VARCHAR2(1000 BYTE),
  ATTRIBUTE1                                             VARCHAR2(250 BYTE),
  ATTRIBUTE2                                             VARCHAR2(250 BYTE),
  ATTRIBUTE3                                             VARCHAR2(250 BYTE),
  ATTRIBUTE4                                             VARCHAR2(250 BYTE),
  ATTRIBUTE5                                             VARCHAR2(250 BYTE),
  ATTRIBUTE6                                             VARCHAR2(250 BYTE),
  ATTRIBUTE7                                             VARCHAR2(250 BYTE),
  ATTRIBUTE8                                             VARCHAR2(250 BYTE),
  ATTRIBUTE9                                             VARCHAR2(250 BYTE),
  ATTRIBUTE10                                            VARCHAR2(250 BYTE),
  ATTRIBUTE11                                            VARCHAR2(250 BYTE),
  ATTRIBUTE12                                            VARCHAR2(250 BYTE),
  ATTRIBUTE13                                            VARCHAR2(250 BYTE),
  ATTRIBUTE14                                            VARCHAR2(250 BYTE),
  ATTRIBUTE15                                            VARCHAR2(250 BYTE),
  CREATED_BY                                             NUMBER,
  CREATION_DATE                                          DATE,
  LAST_UPDATED_BY                                        NUMBER,
  LAST_UPDATE_DATE                                       DATE,
  REQUEST_ID                                             NUMBER,
  FILE_NAME                                              VARCHAR2(2000 BYTE),
  DATE_PARAMETER                                         DATE,
  OB_DATE                                                DATE,
  PERIOD_DATE                                            DATE,
  PERIOD_RATE                                            VARCHAR2(50 BYTE),
  BALANCE_RATE                                           VARCHAR2(50 BYTE),
  RATE                                                   NUMBER,
  REPROCESS_FLAG                                         VARCHAR2(10 BYTE),
  PRECISION                                              NUMBER,
  USD_BALANCE_RATE                                       NUMBER,
  USD_PERIOD_RATE                                        NUMBER,
  USD_BEGINNING_BALANCE                                  NUMBER,
  USD_ADDITION                                           NUMBER,
  USD_REDUCTION                                          NUMBER,
  USD_PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC         NUMBER,
  FX_USD                                                 NUMBER,
  USD_CLOSING_BALANCE                                    NUMBER,
  USD_SHORT_TERM                                         NUMBER,
  USD_LONG_TERM                                          NUMBER,
  USD_PREPAID_AMOUNT                                     NUMBER,
  USD_CLOSING_BALANCE_LESS_PREPAID                       NUMBER,
  USD_MONTH_END_BALANCE_RATE                             NUMBER,
  USD_PREV_PPD_AMOUNT                                    NUMBER,
  LOCAL_PREV_PPD_AMOUNT                                  NUMBER,
  PREV_PPD_RATE_AMOUNT                                   NUMBER,
  CURRT_PPD_RATE_AMOUNT                                  NUMBER,
  FUNCTIONAL_CURRENCY_BALANCE_RATE                       NUMBER,
  FUNCTIONAL_CURRENCY_PERIOD_RATE                        NUMBER,
  FUNCTIONAL_CURRENCY_BEGINNING_BALANCE                  NUMBER,
  FUNCTIONAL_CURRENCY_ADDITION                           NUMBER,
  FUNCTIONAL_CURRENCY_REDUCTION                          NUMBER,
  FUNCTIONAL_PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC  NUMBER,
  FUNCTIONAL_FX                                          NUMBER,
  FUNCTIONAL_CURRENCY_CLOSING_BALANCE                    NUMBER,
  FUNCTIONAL_CURRENCY_SHORT_TERM                         NUMBER,
  FUNCTIONAL_CURRENCY_LONG_TERM                          NUMBER,
  FUNCTIONAL_CURRENCY_PREPAID_AMOUNT                     NUMBER,
  FUNCTIONAL_CURRENCY_CLOSING_BALANCE_LESS_PREPAID       NUMBER,
  FUNCTIONAL_TO_CURRENCY                                 VARCHAR2(100 BYTE),
  FUNCTIONAL_CURRENCY_MONTH_END_BALANCE_RATE             NUMBER,
  FUNC_CUR_PREV_PPD_AMOUNT                               NUMBER,
  FUNC_CUR_PREV_PPD_RATE_AMOUNT                          NUMBER,
  FUNC_CUR_CURRT_PPD_RATE_AMOUNT                         NUMBER
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
-- XXD_GL_LX_LIABILITY_RF_T  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_LX_LIABILITY_RF_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_LX_LIABILITY_RF_T FOR XXDO.XXD_GL_LX_LIABILITY_RF_T
/
