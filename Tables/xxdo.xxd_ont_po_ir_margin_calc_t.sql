--
-- XXD_ONT_PO_IR_MARGIN_CALC_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_PO_IR_MARGIN_CALC_T
(
  SEQUENCE_NUMBER              NUMBER,
  REQUEST_ID                   NUMBER,
  UPDATE_REQUEST_ID            NUMBER,
  SOURCE                       VARCHAR2(100 BYTE),
  ORDER_NUMBER                 NUMBER,
  RCV_TRANSACTION_ID           NUMBER,
  MMT_TRANSACTION_ID           NUMBER,
  HEADER_ID                    NUMBER,
  LINE_ID                      NUMBER,
  ORDERED_QUANTITY             NUMBER,
  TRANSACTION_QUANTITY         NUMBER,
  INVOICED_QUANTITY            NUMBER,
  ON_HAND_QUANTITY             NUMBER,
  INVENTORY_ITEM_ID            NUMBER,
  DELIVERY_DETAIL_ID           NUMBER,
  DELIVERY_ID                  NUMBER,
  TRANSACTION_DATE             DATE,
  MMT_CREATION_DATE            DATE,
  UNIT_SELLING_PRICE           NUMBER,
  UNIT_SELLING_PRICE_USD       NUMBER,
  SOURCE_ORGANIZATION_ID       NUMBER,
  DESTINATION_ORGANIZATION_ID  NUMBER,
  REQUISITION_LINE_ID          NUMBER,
  PO_LINE_ID                   NUMBER,
  SOURCE_CURRENCY              VARCHAR2(15 BYTE),
  DESTINATION_CURRENCY         VARCHAR2(15 BYTE),
  CONVERSION_RATE_LOCAL        NUMBER,
  CONVERSION_RATE_USD          NUMBER,
  SOURCE_COST                  NUMBER,
  SOURCE_COST_USD              NUMBER,
  TRX_MRGN_CST_USD             NUMBER,
  TRX_MRGN_CST_LOCAL           NUMBER,
  AVG_MRGN_CST_USD             NUMBER,
  AVG_MRGN_CST_LOCAL           NUMBER,
  ON_HAND_QTY_DESTN            NUMBER,
  PROCESS_FLAG                 VARCHAR2(3 BYTE),
  CREATION_DATE                DATE,
  CREATED_BY                   NUMBER,
  LAST_UPDATED_DATE            DATE,
  LAST_UPDATED_BY              NUMBER,
  LAST_LOGIN                   NUMBER,
  CST_ORG                      NUMBER,
  OVER_HEAD_COST               NUMBER,
  OVER_HEAD_COST_PCNT          NUMBER,
  SOURCE_OPERATING_UNIT        NUMBER,
  DSTN_OEPRATING_UNIT          NUMBER,
  TRX_RELATIONSHIP             VARCHAR2(50 BYTE),
  ATTRIBUTE1                   VARCHAR2(150 BYTE),
  ATTRIBUTE2                   VARCHAR2(150 BYTE),
  ATTRIBUTE3                   VARCHAR2(150 BYTE),
  ATTRIBUTE4                   VARCHAR2(150 BYTE),
  ATTRIBUTE5                   VARCHAR2(150 BYTE),
  ATTRIBUTE6                   VARCHAR2(150 BYTE),
  ATTRIBUTE7                   VARCHAR2(150 BYTE),
  ATTRIBUTE8                   VARCHAR2(150 BYTE),
  ATTRIBUTE9                   VARCHAR2(150 BYTE),
  ATTRIBUTE10                  VARCHAR2(150 BYTE),
  ATTRIBUTE11                  VARCHAR2(150 BYTE),
  ATTRIBUTE12                  VARCHAR2(150 BYTE),
  ATTRIBUTE13                  VARCHAR2(150 BYTE),
  ATTRIBUTE14                  VARCHAR2(150 BYTE),
  ATTRIBUTE15                  VARCHAR2(150 BYTE),
  ATTRIBUTE16                  VARCHAR2(150 BYTE),
  ATTRIBUTE17                  VARCHAR2(150 BYTE),
  ATTRIBUTE18                  VARCHAR2(150 BYTE),
  ATTRIBUTE19                  VARCHAR2(150 BYTE),
  ATTRIBUTE20                  VARCHAR2(150 BYTE)
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


ALTER TABLE XXDO.XXD_ONT_PO_IR_MARGIN_CALC_T ADD (
  PRIMARY KEY
  (SEQUENCE_NUMBER)
  USING INDEX
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
  ENABLE VALIDATE)
/


--  There is no statement for index XXDO.SYS_C003301503.
--  The object is created when the parent object is created.

--
-- XXD_ONT_PO_IR_MARGIN_CALC_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_PO_IR_MARGIN_CALC_T (Table)
--
CREATE INDEX APPS.XXD_ONT_PO_IR_MARGIN_CALC_N1 ON XXDO.XXD_ONT_PO_IR_MARGIN_CALC_T
(INVENTORY_ITEM_ID, DESTINATION_ORGANIZATION_ID)
LOGGING
TABLESPACE APPS_TS_TX_DATA
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_ONT_PO_IR_MARGIN_CALC_N2  (Index) 
--
--  Dependencies: 
--   XXD_ONT_PO_IR_MARGIN_CALC_T (Table)
--
CREATE BITMAP INDEX APPS.XXD_ONT_PO_IR_MARGIN_CALC_N2 ON XXDO.XXD_ONT_PO_IR_MARGIN_CALC_T
(SOURCE)
LOGGING
TABLESPACE APPS_TS_TX_DATA
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_ONT_PO_IR_MARGIN_CALC_N3  (Index) 
--
--  Dependencies: 
--   XXD_ONT_PO_IR_MARGIN_CALC_T (Table)
--
CREATE INDEX APPS.XXD_ONT_PO_IR_MARGIN_CALC_N3 ON XXDO.XXD_ONT_PO_IR_MARGIN_CALC_T
(TRANSACTION_DATE)
LOGGING
TABLESPACE APPS_TS_TX_DATA
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_ONT_PO_IR_MARGIN_CALC_N4  (Index) 
--
--  Dependencies: 
--   XXD_ONT_PO_IR_MARGIN_CALC_T (Table)
--
CREATE INDEX APPS.XXD_ONT_PO_IR_MARGIN_CALC_N4 ON XXDO.XXD_ONT_PO_IR_MARGIN_CALC_T
(INVENTORY_ITEM_ID, DESTINATION_ORGANIZATION_ID, TRANSACTION_DATE)
LOGGING
TABLESPACE APPS_TS_TX_DATA
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_ONT_PO_IR_MARGIN_CALC_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_PO_IR_MARGIN_CALC_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_PO_IR_MARGIN_CALC_T FOR XXDO.XXD_ONT_PO_IR_MARGIN_CALC_T
/
