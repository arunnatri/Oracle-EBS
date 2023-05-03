--
-- XXD_ONT_AUTO_ATP_SPLY_DMAND_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_AUTO_ATP_SPLY_DMAND_T
(
  BATCH_ID           NUMBER,
  INVENTORY_ITEM_ID  NUMBER,
  ORGANIZATION_ID    NUMBER,
  ALLOC_DATE         DATE,
  SUPPLY             NUMBER,
  DEMAND             NUMBER,
  NET_QTY            NUMBER,
  POH                NUMBER,
  ATP                NUMBER,
  REQUEST_ID         NUMBER,
  PROCESS_STATUS     VARCHAR2(100 BYTE),
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER
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
