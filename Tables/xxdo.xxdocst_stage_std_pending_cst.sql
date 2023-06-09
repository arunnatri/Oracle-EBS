--
-- XXDOCST_STAGE_STD_PENDING_CST  (Table) 
--
CREATE TABLE XXDO.XXDOCST_STAGE_STD_PENDING_CST
(
  STYLE             VARCHAR2(150 BYTE),
  STYLE_COLOR       VARCHAR2(150 BYTE),
  INVENTORY_ORG     VARCHAR2(150 BYTE),
  ITEM              VARCHAR2(150 BYTE),
  COUNTY_OF_ORIGIN  VARCHAR2(150 BYTE),
  FILE_DUTY         NUMBER,
  DUTY              NUMBER,
  PRIME_DUTY        VARCHAR2(1 BYTE),
  DUTY_START_DATE   DATE,
  DUTY_END_DATE     DATE,
  FILE_FREIGHT      NUMBER,
  FREIGHT           NUMBER,
  FILE_FREIGHT_DU   NUMBER,
  FREIGHT_DU        NUMBER,
  FILE_OH_DUTY      NUMBER,
  OH_DUTY           NUMBER,
  FILE_OH_NONDUTY   NUMBER,
  OH_NONDUTY        NUMBER,
  FACTORY_COST      NUMBER,
  ADDITIONAL_DUTY   NUMBER,
  ITEM_ID           NUMBER,
  INV_ORG_ID        NUMBER,
  STATUS            VARCHAR2(1 BYTE),
  ERROR_MSG         VARCHAR2(4000 BYTE),
  TARRIF_CODE       VARCHAR2(150 BYTE),
  COUNTRY           VARCHAR2(150 BYTE),
  DEFAULT_CATEGORY  VARCHAR2(150 BYTE),
  STATUS_CATEGORY   VARCHAR2(150 BYTE),
  ERRMSG_CATEGORY   VARCHAR2(4000 BYTE),
  CATEGORY_ID       NUMBER,
  GROUP_ID          NUMBER
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
-- XXDOCST_STAGE_STD_PENDING_N1  (Index) 
--
--  Dependencies: 
--   XXDOCST_STAGE_STD_PENDING_CST (Table)
--
CREATE INDEX XXDO.XXDOCST_STAGE_STD_PENDING_N1 ON XXDO.XXDOCST_STAGE_STD_PENDING_CST
(ITEM_ID)
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
/

--
-- XXDOCST_STAGE_STD_PENDING_N2  (Index) 
--
--  Dependencies: 
--   XXDOCST_STAGE_STD_PENDING_CST (Table)
--
CREATE INDEX XXDO.XXDOCST_STAGE_STD_PENDING_N2 ON XXDO.XXDOCST_STAGE_STD_PENDING_CST
(INV_ORG_ID)
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
/

--
-- XXDOCST_STAGE_STD_PENDING_CST  (Synonym) 
--
--  Dependencies: 
--   XXDOCST_STAGE_STD_PENDING_CST (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDOCST_STAGE_STD_PENDING_CST FOR XXDO.XXDOCST_STAGE_STD_PENDING_CST
/


--
-- XXDOCST_STAGE_STD_PENDING_CST  (Synonym) 
--
--  Dependencies: 
--   XXDOCST_STAGE_STD_PENDING_CST (Table)
--
CREATE OR REPLACE SYNONYM APPSRO.XXDOCST_STAGE_STD_PENDING_CST FOR XXDO.XXDOCST_STAGE_STD_PENDING_CST
/
