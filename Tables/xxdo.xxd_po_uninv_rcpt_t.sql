--
-- XXD_PO_UNINV_RCPT_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_UNINV_RCPT_T
(
  REQUEST_ID              NUMBER,
  PO_NUMBER               VARCHAR2(100 BYTE),
  RELEASE_NUM             NUMBER,
  LINE_TYPE               VARCHAR2(100 BYTE),
  LINE_NUM                NUMBER,
  CATEGORY                VARCHAR2(240 BYTE),
  ITEM_NAME               VARCHAR2(240 BYTE),
  ITEM_DESC               VARCHAR2(240 BYTE),
  VENDOR_NAME             VARCHAR2(240 BYTE),
  ACC_CURRENCY            VARCHAR2(100 BYTE),
  SHIPMENT_NUM            VARCHAR2(100 BYTE),
  QTY_RECEIVED            NUMBER,
  QTY_BILLED              NUMBER,
  PO_UNIT_PRICE           NUMBER,
  FUNC_UNIT_PRICE         NUMBER,
  UOM                     VARCHAR2(50 BYTE),
  DIST_NUM                VARCHAR2(100 BYTE),
  CHARGE_ACCOUNT          VARCHAR2(100 BYTE),
  ACC_ACCOUNT             VARCHAR2(100 BYTE),
  ACC_CCID                VARCHAR2(100 BYTE),
  ACC_AMOUNT              NUMBER,
  FUNC_ACC_AMOUNT         NUMBER,
  ENTITY_UNIQ_IDENTIFIER  VARCHAR2(100 BYTE),
  ACCOUNT_NUMBER          VARCHAR2(100 BYTE),
  KEY3                    VARCHAR2(100 BYTE),
  KEY4                    VARCHAR2(100 BYTE),
  KEY5                    VARCHAR2(100 BYTE),
  KEY6                    VARCHAR2(100 BYTE),
  KEY7                    VARCHAR2(100 BYTE),
  KEY8                    VARCHAR2(100 BYTE),
  KEY9                    VARCHAR2(100 BYTE),
  KEY10                   VARCHAR2(100 BYTE),
  PERIOD_END_DATE         DATE,
  SUBLEDR_REP_BAL         NUMBER,
  SUBLEDR_ALT_BAL         NUMBER,
  SUBLEDR_ACC_BAL         NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  CHARGE_BRAND            VARCHAR2(50 BYTE),
  USD_BALANCES            NUMBER,
  AGE                     NUMBER,
  PREPARER                VARCHAR2(50 BYTE),
  LAST_RECEIPT_RECEIVER   VARCHAR2(50 BYTE)
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_PO_UNINV_RCPT_T TO APPS
/