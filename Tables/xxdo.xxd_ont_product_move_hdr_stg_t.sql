--
-- XXD_ONT_PRODUCT_MOVE_HDR_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_PRODUCT_MOVE_HDR_STG_T
(
  BATCH_ID          NUMBER,
  BATCH_MODE        VARCHAR2(15 BYTE),
  ORGANIZATION_ID   NUMBER,
  BRAND             VARCHAR2(40 BYTE),
  SKU               VARCHAR2(2000 BYTE),
  STYLE             VARCHAR2(150 BYTE),
  COLOR             VARCHAR2(150 BYTE),
  STATUS            VARCHAR2(30 BYTE),
  CREATED_BY        NUMBER,
  LAST_UPDATED_BY   NUMBER,
  CREATION_DATE     DATE,
  LAST_UPDATE_DATE  DATE,
  BATCH_PROCESSING  VARCHAR2(5 BYTE)
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_ONT_PRODUCT_MOVE_HDR_STG_T TO APPS
/
