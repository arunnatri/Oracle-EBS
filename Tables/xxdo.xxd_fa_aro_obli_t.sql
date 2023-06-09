--
-- XXD_FA_ARO_OBLI_T  (Table) 
--
CREATE TABLE XXDO.XXD_FA_ARO_OBLI_T
(
  ASSET_NUMBER             VARCHAR2(30 BYTE),
  ASSET_ID                 NUMBER,
  MAJOR_CATEGORY           VARCHAR2(50 BYTE),
  ASSET_DESCRIPTION        VARCHAR2(500 BYTE),
  BOOK_TYPE_CODE           VARCHAR2(30 BYTE),
  CURRENT_COST             NUMBER,
  ASSET_LIFE               NUMBER,
  PV_ARO_AT_ESTABLISHMENT  NUMBER,
  PER_MONTH_COST           NUMBER,
  MONTHS_PRE               NUMBER,
  MONTHS_CURR              NUMBER,
  PV_ARO_ADDITION          NUMBER,
  ACCRETION_BALANCE_TYPE   VARCHAR2(100 BYTE),
  TOTAL_TARGET_ARO         NUMBER,
  EXTRA_MONTHS_AFTER       NUMBER,
  DATE_PLACED_IN_SERVICE   DATE,
  ASSET_DATE_RETIRED       DATE,
  YEAR_START_DATE          VARCHAR2(20 BYTE),
  YEAR_END_DATE            VARCHAR2(30 BYTE),
  PERIOD_YEAR              NUMBER,
  PERIOD_NUM               NUMBER,
  ASSET_PERIOD_NUM         NUMBER,
  NBV_PERIOD_NAME          VARCHAR2(30 BYTE),
  PERIOD_NAME              VARCHAR2(30 BYTE),
  CURRENT_YR               NUMBER,
  REGION                   VARCHAR2(30 BYTE),
  VS_BOOK_TYPE_CODE        VARCHAR2(30 BYTE),
  COST_CENTER              VARCHAR2(30 BYTE),
  CREATED_BY               NUMBER,
  CREATION_DATE            DATE,
  LAST_UPDATED_BY          NUMBER,
  LAST_UPDATE_DATE         DATE,
  REQUEST_ID               NUMBER,
  ORIGINAL_COST            NUMBER,
  RETIREMENT_COUNTER       NUMBER
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
