--
-- XXD_FA_TEAR_DOWN_DATA_T  (Table) 
--
CREATE TABLE XXDO.XXD_FA_TEAR_DOWN_DATA_T
(
  SHIP_TO_LOCATION_ID  NUMBER,
  LOCATION_NAME        VARCHAR2(240 BYTE),
  ASSET_NUMBER         VARCHAR2(50 BYTE),
  COMPANY              NUMBER,
  COST_CENTER          NUMBER,
  ACCOUNT              NUMBER,
  INVOICE_AMOUNT       NUMBER,
  MAPPED_FLAG          VARCHAR2(1 BYTE)
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
