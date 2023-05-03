--
-- XXD_PO_MODIFY_DETAILS_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_MODIFY_DETAILS_T
(
  RECORD_ID                     NUMBER,
  BATCH_ID                      NUMBER,
  ORG_ID                        NUMBER,
  SOURCE_PO_HEADER_ID           NUMBER,
  STYLE_COLOR                   VARCHAR2(50 BYTE),
  OPEN_QTY                      NUMBER,
  ACTION_TYPE                   VARCHAR2(2000 BYTE),
  MOVE_INV_ORG_ID               NUMBER,
  SUPPLIER_ID                   NUMBER,
  SUPPLIER_SITE_ID              NUMBER,
  MOVE_PO                       VARCHAR2(100 BYTE),
  MOVE_PO_HEADER_ID             NUMBER,
  SOURCE_PO_LINE_ID             NUMBER,
  SOURCE_PR_HEADER_ID           NUMBER,
  SOURCE_PR_LINE_ID             NUMBER,
  SOURCE_ISO_HEADER_ID          NUMBER,
  SOURCE_ISO_LINE_ID            NUMBER,
  SOURCE_IR_HEADER_ID           NUMBER,
  SOURCE_IR_LINE_ID             NUMBER,
  DROP_SHIP_SOURCE_ID           NUMBER,
  ITEM_NUMBER                   VARCHAR2(50 BYTE),
  MOVE_ORG_OPERATING_UNIT_FLAG  VARCHAR2(1 BYTE),
  CANCEL_PO_HEADER_FLAG         VARCHAR2(1 BYTE),
  CANCEL_ISO_HEADER_FLAG        VARCHAR2(1 BYTE),
  INTERCOMPANY_PO_FLAG          VARCHAR2(1 BYTE),
  PO_CANCELLED_FLAG             VARCHAR2(2 BYTE),
  PR_CANCELLED_FLAG             VARCHAR2(2 BYTE),
  ISO_CANCELLED_FLAG            VARCHAR2(2 BYTE),
  IR_CANCELLED_FLAG             VARCHAR2(2 BYTE),
  NEW_PR_NUMBER                 NUMBER,
  NEW_PR_HEADER_ID              NUMBER,
  NEW_PR_LINE_NUM               NUMBER,
  NEW_PR_LINE_ID                NUMBER,
  NEW_PO_NUMBER                 NUMBER,
  NEW_PO_HEADER_ID              NUMBER,
  NEW_PO_LINE_NUM               NUMBER,
  NEW_PO_LINE_ID                NUMBER,
  PO_MODIFY_SOURCE              VARCHAR2(10 BYTE),
  REQUEST_ID                    NUMBER,
  STATUS                        VARCHAR2(15 BYTE),
  ERROR_MESSAGE                 VARCHAR2(4000 BYTE),
  CREATION_DATE                 DATE,
  CREATED_BY                    NUMBER,
  LAST_UPDATED_DATE             DATE,
  LAST_UPDATED_BY               NUMBER
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
-- XXD_PO_MODIFY_DETAILS_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_MODIFY_DETAILS_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_MODIFY_DETAILS_T FOR XXDO.XXD_PO_MODIFY_DETAILS_T
/
