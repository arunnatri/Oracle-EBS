--
-- XXD_ONT_D2B_BULK_ORDR_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_D2B_BULK_ORDR_STG_T
(
  HEADER_ID               NUMBER,
  LINE_ID                 NUMBER,
  REQUEST_ID              NUMBER,
  BATCH_NAME              VARCHAR2(50 BYTE),
  ORDER_NUMBER            NUMBER,
  ORG_ID                  NUMBER,
  SHIP_FROM_ORG_ID        NUMBER,
  BRAND                   VARCHAR2(40 BYTE),
  ORDER_TYPE_ID           NUMBER,
  SOLD_TO_ORG_ID          NUMBER,
  SKU                     VARCHAR2(40 BYTE),
  INVENTORY_ITEM_ID       NUMBER,
  CHANNEL                 VARCHAR2(30 BYTE),
  FCST_REGION             VARCHAR2(150 BYTE),
  RQST_MM                 VARCHAR2(40 BYTE),
  ORIGINAL_QUANTITY       NUMBER,
  REQUEST_DATE            DATE,
  HDR_CREATION_DATE       DATE,
  LNE_CREATION_DATE       DATE,
  LATEST_ACCEPTABLE_DATE  DATE,
  SCHEDULE_SHIP_DATE      DATE,
  OPERATION               VARCHAR2(1 BYTE),
  QTY_UPDATE              NUMBER,
  LINE_NUMBER             VARCHAR2(30 BYTE),
  PROCESS_MODE            VARCHAR2(30 BYTE),
  STATUS                  VARCHAR2(1 BYTE),
  MESSAGE                 VARCHAR2(240 BYTE),
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER,
  BATCH_NUM               NUMBER
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
-- XXD_ONT_D2B_BLK_IDX1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_D2B_BULK_ORDR_STG_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_D2B_BLK_IDX1 ON XXDO.XXD_ONT_D2B_BULK_ORDR_STG_T
(LINE_ID, REQUEST_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
PARALLEL ( DEGREE 3 INSTANCES 2 )
/

--
-- XXD_ONT_D2B_BLK_IDX2  (Index) 
--
--  Dependencies: 
--   XXD_ONT_D2B_BULK_ORDR_STG_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_D2B_BLK_IDX2 ON XXDO.XXD_ONT_D2B_BULK_ORDR_STG_T
(BATCH_NAME)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
PARALLEL ( DEGREE 3 INSTANCES 2 )
/

--
-- XXD_ONT_D2B_BLK_IDX3  (Index) 
--
--  Dependencies: 
--   XXD_ONT_D2B_BULK_ORDR_STG_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_D2B_BLK_IDX3 ON XXDO.XXD_ONT_D2B_BULK_ORDR_STG_T
(INVENTORY_ITEM_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
PARALLEL ( DEGREE 3 INSTANCES 2 )
/
