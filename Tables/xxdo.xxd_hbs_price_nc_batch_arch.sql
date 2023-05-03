--
-- XXD_HBS_PRICE_NC_BATCH_ARCH  (Table) 
--
CREATE TABLE XXDO.XXD_HBS_PRICE_NC_BATCH_ARCH
(
  BATCH_ID               VARCHAR2(100 BYTE),
  LIST_HEADER_ID         NUMBER,
  BATCH_DATE             DATE,
  STYLE_NAME             VARCHAR2(100 BYTE),
  SKU                    VARCHAR2(100 BYTE),
  CREATION_DATE          DATE,
  CREATED_BY             NUMBER,
  BRAND                  VARCHAR2(50 BYTE),
  UOM                    VARCHAR2(50 BYTE),
  HUBSOFT_PRICE_LIST_ID  VARCHAR2(100 BYTE)
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
