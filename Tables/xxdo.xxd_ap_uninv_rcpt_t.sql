--
-- XXD_AP_UNINV_RCPT_T  (Table) 
--
CREATE TABLE XXDO.XXD_AP_UNINV_RCPT_T
(
  REQUEST_ID             NUMBER,
  PO_NUMBER              VARCHAR2(100 BYTE),
  RELEASE_NUM            NUMBER,
  LINE_TYPE              VARCHAR2(100 BYTE),
  LINE_NUM               NUMBER,
  CATEGORY               VARCHAR2(240 BYTE),
  ITEM_NAME              VARCHAR2(240 BYTE),
  ITEM_DESC              VARCHAR2(240 BYTE),
  VENDOR_NAME            VARCHAR2(240 BYTE),
  ACC_CURRENCY           VARCHAR2(100 BYTE),
  SHIPMENT_NUM           VARCHAR2(100 BYTE),
  QTY_RECEIVED           NUMBER,
  QTY_BILLED             NUMBER,
  PO_UNIT_PRICE          NUMBER,
  FUNC_UNIT_PRICE        NUMBER,
  UOM                    VARCHAR2(50 BYTE),
  DIST_NUM               VARCHAR2(100 BYTE),
  CHARGE_ACCOUNT         VARCHAR2(100 BYTE),
  ACC_ACCOUNT            VARCHAR2(100 BYTE),
  ACC_CCID               VARCHAR2(100 BYTE),
  ACC_AMOUNT             NUMBER,
  FUNC_ACC_AMOUNT        NUMBER,
  CHARGE_BRAND           VARCHAR2(50 BYTE),
  USD_BALANCES           NUMBER,
  AGE                    NUMBER,
  CREATION_DATE          DATE,
  CREATED_BY             NUMBER,
  LAST_UPDATE_DATE       DATE,
  LAST_UPDATED_BY        NUMBER,
  PREPARER               VARCHAR2(50 BYTE),
  LAST_RECEIPT_RECEIVER  VARCHAR2(50 BYTE)
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
-- XXD_AP_UNINV_RCPT_REQID_IDX  (Index) 
--
--  Dependencies: 
--   XXD_AP_UNINV_RCPT_T (Table)
--
CREATE INDEX XXDO.XXD_AP_UNINV_RCPT_REQID_IDX ON XXDO.XXD_AP_UNINV_RCPT_T
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

--
-- XXD_AP_UNINV_RCPT_T  (Synonym) 
--
--  Dependencies: 
--   XXD_AP_UNINV_RCPT_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_AP_UNINV_RCPT_T FOR XXDO.XXD_AP_UNINV_RCPT_T
/
