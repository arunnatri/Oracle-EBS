--
-- XXD_PO_PROJ_FC_REV_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_PROJ_FC_REV_STG_T
(
  RUN_DATE                       VARCHAR2(1000 BYTE),
  PO_TYPE                        VARCHAR2(1000 BYTE),
  SUBTYPE                        VARCHAR2(1000 BYTE),
  REQ_NUMBER                     VARCHAR2(1000 BYTE),
  REQUISITION_HEADER_ID          NUMBER,
  REQUISITION_LINE_ID            NUMBER,
  OE_LINE_ID                     NUMBER,
  PO_NUMBER                      VARCHAR2(1000 BYTE),
  PO_HEADER_ID                   NUMBER,
  PO_LINE_ID                     NUMBER,
  PO_LINE_LOCATION_ID            NUMBER,
  SHIPMENT_NUMBER                VARCHAR2(1000 BYTE),
  SHIPMENT_HEADER_ID             NUMBER,
  SHIPMENT_LINE_ID               NUMBER,
  BRAND                          VARCHAR2(1000 BYTE),
  DEPARTMENT                     VARCHAR2(1000 BYTE),
  ITEM_CATEGORY                  VARCHAR2(1000 BYTE),
  ITEM_SKU                       VARCHAR2(1000 BYTE),
  FROM_PERIOD_IDENTIFIER         VARCHAR2(1000 BYTE),
  TO_PERIOD_IDENTIFIER           VARCHAR2(1000 BYTE),
  FROM_PERIOD_DATE               DATE,
  TO_PERIOD_DATE                 DATE,
  SOURCE_ORG                     VARCHAR2(1000 BYTE),
  REQUESTED_XF_DATE              DATE,
  ORIG_CONFIRMED_XF_DATE         DATE,
  CONFIRMED_XF_DATE              DATE,
  ASN_CREATION_DATE              DATE,
  XF_SHIPMENT_DATE               DATE,
  DESTINATION_ORG                VARCHAR2(1000 BYTE),
  NEED_BY_DATE                   DATE,
  PROMISED_DATE                  DATE,
  EXPECTED_RECEIPT_DATE          DATE,
  PROMISE_EXPECTED_RECEIPT_DATE  DATE,
  ORIGINAL_PROMISE_DATE          DATE,
  INTRANSIT_RECEIPT_DATE         DATE,
  ORIG_INTRANSIT_RECEIPT_DATE    DATE,
  ASN_TYPE                       VARCHAR2(1000 BYTE),
  FOB_VALUE                      VARCHAR2(1000 BYTE),
  QUANTITY                       VARCHAR2(1000 BYTE),
  SHIP_METHOD                    VARCHAR2(1000 BYTE),
  PO_CURRENCY                    VARCHAR2(1000 BYTE),
  FOB_VALUE_IN_USD               VARCHAR2(1000 BYTE),
  CALCULATED_FLAG                VARCHAR2(1 BYTE),
  OVERRIDE_STATUS                VARCHAR2(1000 BYTE),
  SOURCE                         VARCHAR2(1000 BYTE),
  REC_STATUS                     VARCHAR2(1 BYTE),
  CREATED_BY                     VARCHAR2(1000 BYTE),
  CREATION_DATE                  DATE,
  LAST_UPDATED_BY                VARCHAR2(1000 BYTE),
  LAST_UPDATE_DATE               DATE,
  REQUEST_ID                     NUMBER
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
-- XXD_PO_PROJ_FC_REV_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_PROJ_FC_REV_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_PROJ_FC_REV_STG_T FOR XXDO.XXD_PO_PROJ_FC_REV_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_PO_PROJ_FC_REV_STG_T TO APPS
/
