--
-- XXD_RMS_ITEM_MASTER_STG  (Table) 
--
CREATE TABLE XXDO.XXD_RMS_ITEM_MASTER_STG
(
  SLNO                    NUMBER,
  SERVICETYPE             VARCHAR2(30 BYTE),
  ITEM_TYPE               VARCHAR2(30 BYTE),
  OPERATION               VARCHAR2(30 BYTE),
  INVENTORY_ITEM_ID       NUMBER,
  ORGANIZATION_ID         NUMBER,
  STYLE                   VARCHAR2(40 BYTE),
  COLOR                   VARCHAR2(40 BYTE),
  SZE                     VARCHAR2(40 BYTE),
  ITEM_NUMBER             VARCHAR2(40 BYTE),
  BRAND                   VARCHAR2(40 BYTE),
  GENDER                  VARCHAR2(40 BYTE),
  ITEM_STATUS             VARCHAR2(40 BYTE),
  ITEM_DESCRIPTION        VARCHAR2(240 BYTE),
  SCALE_CODE_ID           NUMBER,
  DEPARTMENT              VARCHAR2(240 BYTE),
  UNIT_WEIGHT             NUMBER,
  UNIT_HEIGHT             NUMBER,
  UNIT_WIDTH              NUMBER,
  UNIT_LENGTH             VARCHAR2(40 BYTE),
  DIMENSION_UOM_CODE      VARCHAR2(40 BYTE),
  WEIGHT_UOM_CODE         VARCHAR2(40 BYTE),
  SUB_DIVISION            VARCHAR2(150 BYTE),
  CLASS                   VARCHAR2(40 BYTE),
  SUBCLASS                VARCHAR2(40 BYTE),
  SUBCLASS_CREATION_DATE  VARCHAR2(40 BYTE),
  SUBCLASS_UPDATE_DATE    VARCHAR2(40 BYTE),
  SUBCLASS_UPDATEDBY      VARCHAR2(40 BYTE),
  VERTEX_TAX              VARCHAR2(40 BYTE),
  VERTEX_CREATION_DATE    VARCHAR2(40 BYTE),
  VERTEX_UPDATE_DATE      VARCHAR2(40 BYTE),
  VERTEX_UPDATEDBY        VARCHAR2(40 BYTE),
  US_REGION_COST          NUMBER,
  US_REGION_PRICE         NUMBER,
  UK_REGION_COST          NUMBER,
  UK_REGION_PRICE         NUMBER,
  CA_REGION_COST          NUMBER,
  CA_REGION_PRICE         NUMBER,
  CN_REGION_COST          NUMBER,
  CN_REGION_PRICE         NUMBER,
  JP_REGION_COST          NUMBER,
  JP_REGION_PRICE         NUMBER,
  UPC_VALUE               VARCHAR2(100 BYTE),
  PROCESS_STATUS          VARCHAR2(100 BYTE),
  TRANSMISSION_DATE       DATE,
  CREATION_DATE           DATE,
  LAST_UPDATE_DATE        DATE,
  ORACLE_ERROR_MESSAGE    VARCHAR2(2000 BYTE),
  RESPONSE_MESSAGE        VARCHAR2(2000 BYTE),
  ERRORCODE               VARCHAR2(240 BYTE),
  FR_REGION_COST          NUMBER(10,2),
  FR_REGION_PRICE         NUMBER(10,2),
  HK_REGION_COST          NUMBER,
  HK_REGION_PRICE         NUMBER,
  REQUEST_ID              NUMBER
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
-- XXD_RMS_ITEM_MASTER_STG  (Synonym) 
--
--  Dependencies: 
--   XXD_RMS_ITEM_MASTER_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_RMS_ITEM_MASTER_STG FOR XXDO.XXD_RMS_ITEM_MASTER_STG
/


--
-- XXD_RMS_ITEM_MASTER_STG  (Synonym) 
--
--  Dependencies: 
--   XXD_RMS_ITEM_MASTER_STG (Table)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_RMS_ITEM_MASTER_STG FOR XXDO.XXD_RMS_ITEM_MASTER_STG
/


GRANT DELETE, INSERT, SELECT, UPDATE ON XXDO.XXD_RMS_ITEM_MASTER_STG TO SOA_INT
/