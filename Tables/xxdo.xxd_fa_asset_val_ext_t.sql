--
-- XXD_FA_ASSET_VAL_EXT_T  (Table) 
--
CREATE TABLE XXDO.XXD_FA_ASSET_VAL_EXT_T
(
  ASSET_CATEGORY               VARCHAR2(100 BYTE),
  ASSET_COST_ACCOUNT           VARCHAR2(100 BYTE),
  ASSET_NUMBER                 VARCHAR2(50 BYTE),
  ASSET_DESCRIPTION            VARCHAR2(150 BYTE),
  ASSET_SERIAL_NUMBER          VARCHAR2(50 BYTE),
  CUSTODIAN                    VARCHAR2(150 BYTE),
  DATE_PLACED_IN_SERVICE       VARCHAR2(30 BYTE),
  LIFE_YRS_MO                  VARCHAR2(30 BYTE),
  DEPRN_METHOD                 VARCHAR2(50 BYTE),
  COST                         NUMBER,
  BEGIN_YEAR_DEPR_RESERVE      NUMBER,
  CURRENT_PERIOD_DEPRECIATION  NUMBER,
  YTD_DEPRECIATION             NUMBER,
  ENDING_DEPR_RESERVE          NUMBER,
  NET_BOOK_VALUE               NUMBER,
  DEPRECIATION_ACCOUNT         VARCHAR2(50 BYTE),
  LOCATION_FLEXFIELD           VARCHAR2(200 BYTE),
  ASSET_TAG_NUMBER             VARCHAR2(50 BYTE),
  SUPPLIER                     VARCHAR2(150 BYTE),
  ASSET_TYPE                   VARCHAR2(30 BYTE),
  ASSET_RESERVE_ACCOUNT        VARCHAR2(50 BYTE),
  PROJECT_NUMBER               VARCHAR2(50 BYTE),
  IMPAIRMENT_AMOUNT            NUMBER,
  COST_CENTER                  VARCHAR2(50 BYTE),
  BRAND                        VARCHAR2(50 BYTE),
  MAJOR_CATEGORY               VARCHAR2(50 BYTE),
  CURRENT_IMPAIRMENT_AMOUNT    NUMBER,
  ENTITY_UNIQUE_IDENTIFIER     VARCHAR2(10 BYTE),
  ACCOUNT_NUMBER               VARCHAR2(10 BYTE),
  KEY3                         VARCHAR2(10 BYTE),
  KEY                          VARCHAR2(10 BYTE),
  KEY5                         VARCHAR2(10 BYTE),
  KEY6                         VARCHAR2(10 BYTE),
  KEY7                         VARCHAR2(10 BYTE),
  KEY8                         VARCHAR2(10 BYTE),
  KEY9                         VARCHAR2(10 BYTE),
  KEY10                        VARCHAR2(10 BYTE),
  PERIOD_END_DATE              VARCHAR2(20 BYTE),
  SUBLEDGER_REP_BAL            NUMBER,
  SUBLEDGER_ALT_BAL            NUMBER,
  SUBLEDGER_ACC_BAL            NUMBER,
  CREATED_BY                   NUMBER,
  CREATION_DATE                DATE,
  LAST_UPDATED_BY              NUMBER,
  LAST_UPDATE_DATE             DATE,
  REQUEST_ID                   NUMBER,
  LINE_TYPE                    VARCHAR2(20 BYTE),
  BOOK_TYPE                    VARCHAR2(50 BYTE)
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
