--
-- XXD_GL_SLEC_REP_GT  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXD_GL_SLEC_REP_GT
(
  QUERY_TYPE             VARCHAR2(60 BYTE),
  LEDGER_ID              NUMBER,
  LEDGER_NAME            VARCHAR2(30 BYTE),
  PERIOD_NAME            VARCHAR2(15 BYTE),
  CODE_COMBINATION_ID    NUMBER,
  CONCATENATED_SEGMENTS  VARCHAR2(250 BYTE),
  CURRENCY_CODE          VARCHAR2(15 BYTE),
  AMOUNT                 NUMBER
)
ON COMMIT DELETE ROWS
NOCACHE
/


--
-- XXD_GL_SLEC_REP_GT  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_SLEC_REP_GT (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_SLEC_REP_GT FOR XXDO.XXD_GL_SLEC_REP_GT
/
