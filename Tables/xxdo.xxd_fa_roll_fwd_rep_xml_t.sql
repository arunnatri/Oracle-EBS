--
-- XXD_FA_ROLL_FWD_REP_XML_T  (Table) 
--
CREATE TABLE XXDO.XXD_FA_ROLL_FWD_REP_XML_T
(
  ROWNUMBER               NUMBER,
  BOOK                    VARCHAR2(1000 BYTE),
  PERIOD_FROM             VARCHAR2(1000 BYTE),
  PERIOD_TO               VARCHAR2(1000 BYTE),
  CURRENCY                VARCHAR2(1000 BYTE),
  ASSET_CATEGORY          VARCHAR2(1000 BYTE),
  ASSET_COST_ACCOUNT      VARCHAR2(1000 BYTE),
  ASSET_COST_COMB         VARCHAR2(1000 BYTE),
  COST_CENTER             VARCHAR2(1000 BYTE),
  BRAND                   VARCHAR2(1000 BYTE),
  ASSET_NUMBER            VARCHAR2(1000 BYTE),
  DESCRIPTION             VARCHAR2(1000 BYTE),
  CUSTODIAN               VARCHAR2(1000 BYTE),
  LOCATION                VARCHAR2(1000 BYTE),
  DATE_PLACED_IN_SERVICE  VARCHAR2(1000 BYTE),
  DEPRN_METHOD            VARCHAR2(1000 BYTE),
  LIFE_YR_MO              VARCHAR2(1000 BYTE),
  BEGIN_YEAR_FUN          NUMBER,
  BEGIN_YEAR_SPOT         NUMBER,
  ADDITION                NUMBER,
  ADJUSTMENT              NUMBER,
  RETIREMENT              NUMBER,
  CAPITALIZATION          NUMBER,
  REVALUATION             NUMBER,
  RECLASS                 NUMBER,
  TRANSFER                NUMBER,
  END_YEAR_FUN            NUMBER,
  END_YEAR_SPOT           NUMBER,
  NET_TRANS               NUMBER
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
-- XXD_FA_ROLL_FWD_REP_XML_T  (Synonym) 
--
--  Dependencies: 
--   XXD_FA_ROLL_FWD_REP_XML_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_FA_ROLL_FWD_REP_XML_T FOR XXDO.XXD_FA_ROLL_FWD_REP_XML_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_FA_ROLL_FWD_REP_XML_T TO APPS
/
