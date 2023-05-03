--
-- XXDO_FA_BALANCES_REPORT_GT  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXDO_FA_BALANCES_REPORT_GT
(
  ASSET_ID                NUMBER(15),
  DISTRIBUTION_CCID       NUMBER(15),
  ADJUSTMENT_CCID         NUMBER(15),
  CATEGORY_BOOKS_ACCOUNT  VARCHAR2(25 BYTE),
  SOURCE_TYPE_CODE        VARCHAR2(15 BYTE),
  AMOUNT                  NUMBER,
  COST_ACCOUNT            VARCHAR2(25 BYTE),
  COST_BEGIN_BALANCE      NUMBER,
  GROUP_ASSET_ID          NUMBER(15)
)
ON COMMIT DELETE ROWS
NOCACHE
/


--
-- XXDO_FA_BALANCES_REPORT_GT  (Synonym) 
--
--  Dependencies: 
--   XXDO_FA_BALANCES_REPORT_GT (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_FA_BALANCES_REPORT_GT FOR XXDO.XXDO_FA_BALANCES_REPORT_GT
/
