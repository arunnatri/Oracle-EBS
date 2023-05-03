--
-- XXD_WMS_OPEN_RET_EXT_T  (Table) 
--
CREATE TABLE XXDO.XXD_WMS_OPEN_RET_EXT_T
(
  REQUEST_ID              NUMBER,
  RA_NBR                  NUMBER,
  STORE_LOCATION          VARCHAR2(240 BYTE),
  CREATED                 VARCHAR2(15 BYTE),
  STYLE                   VARCHAR2(150 BYTE),
  COLOR_CODE              VARCHAR2(150 BYTE),
  SIZE_CODE               VARCHAR2(150 BYTE),
  ORIGINAL_QUANTITY       NUMBER,
  RECEIVED_QUANTITY       NUMBER,
  CANCELLED_QUANTITY      NUMBER,
  OPEN_QUANTITY           NUMBER,
  EXTD_PRICE              NUMBER,
  CURRENCY                VARCHAR2(15 BYTE),
  WAREHOUSE               VARCHAR2(3 BYTE),
  BRAND                   VARCHAR2(240 BYTE),
  CUST_ACCT_NUM           VARCHAR2(50 BYTE),
  KEY3                    VARCHAR2(50 BYTE),
  KEY4                    VARCHAR2(50 BYTE),
  KEY5                    VARCHAR2(50 BYTE),
  KEY6                    VARCHAR2(50 BYTE),
  KEY7                    VARCHAR2(50 BYTE),
  KEY8                    VARCHAR2(50 BYTE),
  KEY9                    VARCHAR2(50 BYTE),
  KEY10                   VARCHAR2(50 BYTE),
  PERIOD_END_DATE         DATE,
  SUBLEDR_REP_BAL         NUMBER,
  SUBLEDR_ALT_BAL         NUMBER,
  SUBLEDR_ACC_BAL         NUMBER,
  ENTITY_UNIQ_IDENTIFIER  VARCHAR2(50 BYTE),
  ACCOUNT_NUMBER          VARCHAR2(50 BYTE),
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER
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
-- XXD_WMS_OPEN_RET_EXT_IDX1  (Index) 
--
--  Dependencies: 
--   XXD_WMS_OPEN_RET_EXT_T (Table)
--
CREATE INDEX XXDO.XXD_WMS_OPEN_RET_EXT_IDX1 ON XXDO.XXD_WMS_OPEN_RET_EXT_T
(REQUEST_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/
