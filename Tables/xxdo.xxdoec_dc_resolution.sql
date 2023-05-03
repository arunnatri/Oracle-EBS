--
-- XXDOEC_DC_RESOLUTION  (Table) 
--
CREATE TABLE XXDO.XXDOEC_DC_RESOLUTION
(
  FEED_CODE       VARCHAR2(64 BYTE)             NOT NULL,
  ERP_ORG_ID      NUMBER                        NOT NULL,
  BRAND           VARCHAR2(64 BYTE)             NOT NULL,
  PRODUCT_GENDER  VARCHAR2(64 BYTE)             NOT NULL,
  PRODUCT_GROUP   VARCHAR2(255 BYTE)            NOT NULL,
  INV_ORG_ID      NUMBER                        NOT NULL
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
