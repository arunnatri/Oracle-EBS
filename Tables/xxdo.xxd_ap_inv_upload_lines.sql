--
-- XXD_AP_INV_UPLOAD_LINES  (Table) 
--
CREATE TABLE XXDO.XXD_AP_INV_UPLOAD_LINES
(
  LINE_TYPE                VARCHAR2(100 BYTE),
  LINE_DESCRIPTION         VARCHAR2(240 BYTE),
  LINE_AMOUNT              NUMBER,
  DISTRIBUTION_ACCOUNT     VARCHAR2(100 BYTE),
  SHIP_TO_LOCATION_CODE    VARCHAR2(100 BYTE),
  DISTRIBUTION_SET         VARCHAR2(100 BYTE),
  DISTRIBUTION_SET_ID      NUMBER,
  DIST_ACCOUNT_CCID        NUMBER,
  SHIP_TO_LOCATION_ID      NUMBER,
  PO_NUMBER_L              VARCHAR2(100 BYTE),
  PO_LINE_NUM              NUMBER,
  QTY_INVOICED             NUMBER,
  UNIT_PRICE               NUMBER,
  INTERCO_EXP_ACCOUNT      VARCHAR2(100 BYTE),
  DEFERRED                 VARCHAR2(100 BYTE),
  DEFERRED_START_DATE      DATE,
  DEFERRED_END_DATE        DATE,
  PRORATE                  VARCHAR2(100 BYTE),
  TRACK_AS_ASSET           VARCHAR2(100 BYTE),
  ASSET_CATEGORY           VARCHAR2(100 BYTE),
  ASSET_BOOK               VARCHAR2(100 BYTE),
  PO_LINE_ID               NUMBER,
  ASSET_ID                 NUMBER,
  ASSET_CAT_ID             NUMBER,
  CREATED_BY               NUMBER,
  LAST_UPDATED_BY          NUMBER,
  LAST_UPDATE_LOGIN        NUMBER,
  CREATION_DATE            DATE,
  LAST_UPDATE_DATE         DATE,
  LINE_NUMBER              NUMBER,
  TEMP_INVOICE_HDR_ID      NUMBER,
  TEMP_INVOICE_LINE_ID     NUMBER,
  ERROR_MESSAGE            VARCHAR2(4000 BYTE),
  PROCESS_FLAG             VARCHAR2(1 BYTE),
  INTERCO_EXP_ACCOUNT_ID   NUMBER,
  INVOICE_LINE_ID          NUMBER,
  PO_SHIPMENT_NUM          NUMBER,
  ASSET_BOOK_CODE          VARCHAR2(100 BYTE),
  PRORATE_FLAG             VARCHAR2(10 BYTE),
  ASSET_FLAG               VARCHAR2(10 BYTE),
  DEFERRED_FLAG            VARCHAR2(10 BYTE),
  TAX_CLASSIFICATION_CODE  VARCHAR2(100 BYTE),
  PO_HEADER_L_ID           NUMBER
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_AP_INV_UPLOAD_LINES TO APPS
/
