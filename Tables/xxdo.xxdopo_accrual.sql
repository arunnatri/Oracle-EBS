--
-- XXDOPO_ACCRUAL  (Table) 
--
CREATE TABLE XXDO.XXDOPO_ACCRUAL
(
  ROW_ID                    NUMBER,
  INVENTORY_ITEM_ID         NUMBER,
  RECEIPT_DATE              DATE,
  RECEIPT_NUM               VARCHAR2(50 BYTE),
  PO_NUM                    VARCHAR2(50 BYTE),
  VENDOR_ID                 NUMBER,
  VENDOR                    VARCHAR2(240 BYTE),
  STYLE                     VARCHAR2(20 BYTE),
  COLOR                     VARCHAR2(20 BYTE),
  RECEIVED_QTY              NUMBER,
  UNIT_PRICE                NUMBER,
  RECEIVED_VALUE            NUMBER,
  FTY_INVC_NUM              VARCHAR2(50 BYTE),
  FTY_INVC_NUM_IN_AP        VARCHAR2(50 BYTE),
  INVC_QTY                  NUMBER,
  UNIT_PRICE_PER_INVOICE    NUMBER,
  INVOICE_VALUE             NUMBER,
  PAYMENT_DATE              DATE,
  TOTAL_INVOICE_AMOUNT      NUMBER,
  FTY_STMNT_INVC_NUM        VARCHAR2(50 BYTE),
  FTY_STMNT_UNIT_PRICE      NUMBER,
  FTY_STMNT_INVC_QTY        NUMBER,
  FTY_STMNT_TOTAL_VALUE     NUMBER,
  FTY_STMNT_TOTAL_INVC_AMT  NUMBER,
  SALES_REGION              VARCHAR2(50 BYTE),
  COST_CENTER               VARCHAR2(50 BYTE),
  COUNTRY                   VARCHAR2(50 BYTE),
  BRAND                     VARCHAR2(50 BYTE),
  ACCRUAL                   NUMBER,
  PREPAID_INV               NUMBER,
  IN_TRANSIT_INV            NUMBER,
  ORG_ID                    NUMBER,
  ORGANIZATION_ID           NUMBER,
  PO_TYPE                   VARCHAR2(50 BYTE),
  AP_TYPE                   VARCHAR2(50 BYTE),
  RECVD_EARLIER             NUMBER,
  RECVD_EARLIER_VALUE       NUMBER,
  PRE_INVC_DATE             DATE,
  PREPAID_INVC              NUMBER,
  CUSTOMER                  VARCHAR2(50 BYTE),
  FTY_INVC                  VARCHAR2(50 BYTE),
  FTY_INVC_QTY              NUMBER,
  FTY_INVC_UNIT_PRICE       NUMBER,
  FTY_INVC_TOTAL_VALUE      NUMBER,
  FTY_INVC_TOTAL_INVC_AMT   NUMBER,
  NON_MATCHED_AP            VARCHAR2(50 BYTE),
  PO_INFO                   VARCHAR2(240 BYTE)
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
-- XXDOPO_ACCRUAL  (Index) 
--
--  Dependencies: 
--   XXDOPO_ACCRUAL (Table)
--
CREATE INDEX XXDO.XXDOPO_ACCRUAL ON XXDO.XXDOPO_ACCRUAL
(ORG_ID, FTY_INVC_NUM, PO_NUM, INVENTORY_ITEM_ID)
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
-- XXDOPO_ACCRUAL1  (Index) 
--
--  Dependencies: 
--   XXDOPO_ACCRUAL (Table)
--
CREATE INDEX XXDO.XXDOPO_ACCRUAL1 ON XXDO.XXDOPO_ACCRUAL
(RECEIPT_NUM, RECEIPT_DATE)
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
-- XXDOPO_ACCRUAL  (Synonym) 
--
--  Dependencies: 
--   XXDOPO_ACCRUAL (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOPO_ACCRUAL FOR XXDO.XXDOPO_ACCRUAL
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDOPO_ACCRUAL TO APPS
/

GRANT SELECT ON XXDO.XXDOPO_ACCRUAL TO APPSRO WITH GRANT OPTION
/
