--
-- XXD_ONT_XFER_REQ_IR_ADI_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_XFER_REQ_IR_ADI_STG_T
(
  RECORD_ID          NUMBER,
  ORG_ID             NUMBER,
  SRC_ORG_ID         NUMBER,
  DEST_ORG_ID        NUMBER,
  SKU                VARCHAR2(40 BYTE),
  INVENTORY_ITEM_ID  NUMBER,
  QUANTITY           NUMBER,
  GROUP_NO           NUMBER,
  STATUS             VARCHAR2(1 BYTE),
  MESSAGE            VARCHAR2(200 BYTE),
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER,
  REQUEST_ID         NUMBER,
  BRAND              VARCHAR2(40 BYTE)
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
