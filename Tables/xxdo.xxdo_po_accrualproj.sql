--
-- XXDO_PO_ACCRUALPROJ  (Table) 
--
CREATE TABLE XXDO.XXDO_PO_ACCRUALPROJ
(
  OU                      VARCHAR2(40 BYTE),
  VENDOR                  VARCHAR2(240 BYTE),
  RECEIVED_QTY            NUMBER,
  RECVD_EARLIER           NUMBER,
  UNIT_PRICE              NUMBER,
  RECEIVED_VALUE          NUMBER,
  RECVD_EARLIER_VALUE     NUMBER,
  FTY_INVC_NUM            VARCHAR2(50 BYTE),
  FTY_INVC_NUM_IN_AP      VARCHAR2(50 BYTE),
  INVOICE_QTY             NUMBER,
  UNIT_PRICE_PER_INVOICE  NUMBER,
  INVOICE_VALUE           NUMBER,
  PAYMENT_DATE            DATE,
  TOTAL_INVOICE_AMOUNT    NUMBER,
  TRADELINK_INVC          VARCHAR2(50 BYTE),
  FTY_INVC_QTY            NUMBER,
  FTY_INVC_TOTAL_VALUE    NUMBER,
  COUNTRY                 VARCHAR2(50 BYTE),
  COST_CENTER             VARCHAR2(50 BYTE),
  BRAND                   VARCHAR2(50 BYTE),
  ACCRUAL                 NUMBER,
  PREPAID                 NUMBER,
  INTRANSIT               NUMBER,
  PRE_INVC_DATE           DATE,
  PREPAID_INVOICE_AMT     NUMBER,
  QTY_DIFF_CURR           NUMBER,
  NON_MATCHED_AP          VARCHAR2(50 BYTE),
  PO_INFO                 VARCHAR2(240 BYTE)
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
-- XXDO_PO_ACCRUALPROJ  (Synonym) 
--
--  Dependencies: 
--   XXDO_PO_ACCRUALPROJ (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_PO_ACCRUALPROJ FOR XXDO.XXDO_PO_ACCRUALPROJ
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXDO_PO_ACCRUALPROJ TO APPS
/

GRANT SELECT ON XXDO.XXDO_PO_ACCRUALPROJ TO APPSRO WITH GRANT OPTION
/
