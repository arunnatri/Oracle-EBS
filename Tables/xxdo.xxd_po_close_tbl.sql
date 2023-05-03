--
-- XXD_PO_CLOSE_TBL  (Table) 
--
CREATE TABLE XXDO.XXD_PO_CLOSE_TBL
(
  ID                    NUMBER,
  PO_NUMBER             VARCHAR2(200 BYTE),
  PROCESS_STATUS        VARCHAR2(10 BYTE),
  ERROR_MSG             VARCHAR2(4000 BYTE),
  REQUEST_ID            NUMBER,
  INVOICE_AMT           NUMBER,
  INVOICE_NUM           VARCHAR2(240 BYTE),
  PO_HEADER_ID          NUMBER,
  PO_AMT                NUMBER,
  AUTHORIZATION_STATUS  VARCHAR2(100 BYTE),
  CLOSED_CODE           VARCHAR2(100 BYTE),
  TYPE_LOOKUP_CODE      VARCHAR2(100 BYTE),
  VENDOR_NUMBER         VARCHAR2(100 BYTE),
  VENDOR_NAME           VARCHAR2(500 BYTE),
  VENDOR_ID             NUMBER,
  VENDOR_ID_PARAM       NUMBER,
  PO_LINE_ID            NUMBER,
  PO_LINE_AMOUNT        NUMBER,
  INVOICE_LINE_NUM      NUMBER,
  INVOICE_LINE_AMT      NUMBER,
  PO_LINE_NUM           NUMBER,
  PO_LINE_LOCATION_ID   NUMBER,
  PO_DISTRIBUTION_ID    NUMBER,
  CATEGORY_ID           NUMBER,
  CATEGORY_NAME         VARCHAR2(240 BYTE)
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
-- XXD_PO_CLOSE_TBL_PK_IDX  (Index) 
--
--  Dependencies: 
--   XXD_PO_CLOSE_TBL (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_PO_CLOSE_TBL_PK_IDX ON XXDO.XXD_PO_CLOSE_TBL
(ID)
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
-- XXD_PO_CLOSE_TBL_REQ_IDX  (Index) 
--
--  Dependencies: 
--   XXD_PO_CLOSE_TBL (Table)
--
CREATE INDEX XXDO.XXD_PO_CLOSE_TBL_REQ_IDX ON XXDO.XXD_PO_CLOSE_TBL
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
