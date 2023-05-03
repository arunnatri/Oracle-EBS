--
-- XXD_INV_INTRANSIT_EXTRACT_T  (Table) 
--
CREATE TABLE XXDO.XXD_INV_INTRANSIT_EXTRACT_T
(
  ORGANIZATION_CODE         VARCHAR2(50 BYTE),
  BRAND                     VARCHAR2(50 BYTE),
  STYLE                     VARCHAR2(50 BYTE),
  COLOR                     VARCHAR2(50 BYTE),
  ITEM_TYPE                 VARCHAR2(50 BYTE),
  QUANTITY                  NUMBER,
  ITEM_COST                 NUMBER,
  MATERIAL_COST             NUMBER,
  DUTY_COST                 NUMBER,
  FREIGHT_COST              NUMBER,
  FREIGHT_DU_COST           NUMBER,
  OH_DUTY_CST               NUMBER,
  OH_NON_DUTY_CST           NUMBER,
  INTRANSIT_TYPE            VARCHAR2(50 BYTE),
  VENDOR                    VARCHAR2(500 BYTE),
  VENDOR_REFERENCE          VARCHAR2(100 BYTE),
  FACTORY_INVOICE_NUM       VARCHAR2(100 BYTE),
  TRX_DATE                  DATE,
  EXT_ITEM_COST             NUMBER,
  EXT_MATERIAL_COST         NUMBER,
  EXT_DUTY_COST             NUMBER,
  EXT_FREIGHT_COST          NUMBER,
  EXT_FREIGHT_DU_COST       NUMBER,
  EXT_OH_DUTY_CST           NUMBER,
  EXT_OH_NON_DUTY_CST       NUMBER,
  ENTITY_UNIQUE_IDENTIFIER  VARCHAR2(10 BYTE),
  ACCOUNT_NUMBER            VARCHAR2(10 BYTE),
  KEY3                      VARCHAR2(10 BYTE),
  KEY                       VARCHAR2(10 BYTE),
  KEY5                      VARCHAR2(10 BYTE),
  KEY6                      VARCHAR2(10 BYTE),
  KEY7                      VARCHAR2(10 BYTE),
  KEY8                      VARCHAR2(10 BYTE),
  KEY9                      VARCHAR2(10 BYTE),
  KEY10                     VARCHAR2(10 BYTE),
  PERIOD_END_DATE           VARCHAR2(20 BYTE),
  SUBLEDGER_REP_BAL         NUMBER,
  SUBLEDGER_ALT_BAL         NUMBER,
  SUBLEDGER_ACC_BAL         NUMBER,
  CREATED_BY                NUMBER,
  CREATION_DATE             DATE,
  LAST_UPDATED_BY           NUMBER,
  LAST_UPDATE_DATE          DATE,
  REQUEST_ID                NUMBER
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
