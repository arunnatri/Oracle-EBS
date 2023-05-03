--
-- XXD_FA_RF_INVDET_GT  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXD_FA_RF_INVDET_GT
(
  ASSET_ID                NUMBER(15),
  DISTRIBUTION_CCID       NUMBER(15),
  ADJUSTMENT_CCID         NUMBER(15),
  CATEGORY_BOOKS_ACCOUNT  VARCHAR2(25 BYTE),
  SOURCE_TYPE_CODE        VARCHAR2(15 BYTE),
  AMOUNT                  NUMBER,
  COST_ACCOUNT            VARCHAR2(25 BYTE),
  COST_BEGIN_BALANCE      NUMBER,
  GROUP_ASSET_ID          NUMBER(15),
  REPORT_TYPE             VARCHAR2(30 BYTE),
  AMOUNT_FUN              NUMBER,
  LOCATION                VARCHAR2(154 BYTE),
  AMOUNT_NONF             NUMBER,
  PERIOD_COUNTER          VARCHAR2(30 BYTE),
  PERIOD_NAME             VARCHAR2(30 BYTE),
  IN_CURRENT_PERIOD       VARCHAR2(30 BYTE),
  DISTRIBUTION_CC         VARCHAR2(100 BYTE),
  ADJUSTMENT_CC           VARCHAR2(100 BYTE)
)
ON COMMIT PRESERVE ROWS
NOCACHE
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_FA_RF_INVDET_GT TO APPS
/