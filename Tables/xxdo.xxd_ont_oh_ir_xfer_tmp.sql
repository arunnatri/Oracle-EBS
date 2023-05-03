--
-- XXD_ONT_OH_IR_XFER_TMP  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_OH_IR_XFER_TMP
(
  RECORD_ID               NUMBER,
  ORG_ID                  NUMBER,
  ORGANIZATION_ID         NUMBER,
  SUBINVENTORY_CODE       VARCHAR2(40 BYTE),
  DEST_ORG_ID             NUMBER,
  DEST_ORGANIZATION_ID    NUMBER,
  DEST_LOCATION_ID        NUMBER,
  DEST_SUBINVENTORY_CODE  VARCHAR2(40 BYTE),
  NEED_BY_DATE            DATE,
  BRAND                   VARCHAR2(20 BYTE),
  STYLE                   VARCHAR2(20 BYTE),
  SKU                     VARCHAR2(40 BYTE),
  INVENTORY_ITEM_ID       NUMBER,
  UNIT_PRICE              NUMBER,
  UOM_CODE                VARCHAR2(10 BYTE),
  GROUP_NO                NUMBER,
  QUANTITY                NUMBER,
  AGING_DATE              DATE,
  CHARGE_ACCOUNT_ID       NUMBER,
  REQ_HEADER_ID           NUMBER,
  REQ_LINE_ID             NUMBER,
  REQUISITION_NUMBER      NUMBER,
  ISO_NUMBER              NUMBER,
  DELIVERY_LINE_STATUS    VARCHAR2(1 BYTE),
  DELIVERY_ID             NUMBER,
  STATUS                  VARCHAR2(1 BYTE),
  MESSAGE                 VARCHAR2(200 BYTE),
  REQUEST_ID              NUMBER,
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  LOCATOR_NAME            VARCHAR2(200 BYTE),
  LOCATOR_ID              NUMBER,
  CPQ                     NUMBER,
  OLD_QTY                 NUMBER
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
