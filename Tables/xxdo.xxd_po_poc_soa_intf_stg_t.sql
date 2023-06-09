--
-- XXD_PO_POC_SOA_INTF_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_POC_SOA_INTF_STG_T
(
  POC_SOA_INTF_STG_ID     NUMBER,
  BATCH_ID                NUMBER,
  EVENT_TYPE_CODE         VARCHAR2(50 BYTE),
  PO_NUMBER               VARCHAR2(20 BYTE),
  LINE_NUMBER             NUMBER,
  POC_LINE_STATUS         VARCHAR2(20 BYTE),
  SHIP_METHOD             VARCHAR2(50 BYTE),
  ITEM_NUMBER             VARCHAR2(50 BYTE),
  QUANTITY                NUMBER,
  SUPPLIER_SITE           VARCHAR2(15 BYTE),
  CONF_XF_DATE            DATE,
  PROMISED_DATE_OVERRIDE  DATE,
  FREIGHT_PAY_PARTY       VARCHAR2(10 BYTE),
  COMMENTS1               VARCHAR2(320 BYTE),
  COMMENTS2               VARCHAR2(320 BYTE),
  COMMENTS3               VARCHAR2(320 BYTE),
  COMMENTS4               VARCHAR2(320 BYTE),
  DELAY_REASON            VARCHAR2(2000 BYTE),
  SPLIT_QTY_1             NUMBER,
  SPLIT_DATE_1            DATE,
  SPLIT_SHIP_METHOD_1     VARCHAR2(50 BYTE),
  SPLIT_FRT_PAY_PARTY_1   VARCHAR2(10 BYTE),
  SPLIT_QTY_2             NUMBER,
  SPLIT_DATE_2            DATE,
  SPLIT_SHIP_METHOD_2     VARCHAR2(50 BYTE),
  SPLIT_FRT_PAY_PARTY_2   VARCHAR2(10 BYTE),
  PROCESS_STATUS          VARCHAR2(20 BYTE),
  ERROR_MESSAGE           VARCHAR2(2000 BYTE),
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  REQUEST_ID              NUMBER
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
-- XXD_PO_POC_SOA_INTF_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_POC_SOA_INTF_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_POC_SOA_INTF_STG_T FOR XXDO.XXD_PO_POC_SOA_INTF_STG_T
/


--
-- XXD_PO_POC_SOA_INTF_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_POC_SOA_INTF_STG_T (Table)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_PO_POC_SOA_INTF_STG_T FOR XXDO.XXD_PO_POC_SOA_INTF_STG_T
/


GRANT INSERT, SELECT, UPDATE ON XXDO.XXD_PO_POC_SOA_INTF_STG_T TO SOA_INT
/
