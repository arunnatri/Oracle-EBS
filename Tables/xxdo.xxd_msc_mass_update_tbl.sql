--
-- XXD_MSC_MASS_UPDATE_TBL  (Table) 
--
CREATE TABLE XXDO.XXD_MSC_MASS_UPDATE_TBL
(
  TRANSACTION_ID            NUMBER,
  ORDER_NUMBER              VARCHAR2(4000 BYTE),
  LAST_UPDATE_DATE          DATE,
  LAST_UPDATED_BY           NUMBER,
  CREATION_DATE             DATE,
  CREATED_BY                NUMBER,
  LAST_UPDATE_LOGIN         NUMBER,
  INVENTORY_ITEM_ID         NUMBER,
  ORGANIZATION_ID           NUMBER,
  ORGANIZATION_CODE         VARCHAR2(7 BYTE),
  PLAN_ID                   NUMBER,
  NEW_DUE_DATE              DATE,
  OLD_DUE_DATE              DATE,
  NEW_START_DATE            DATE,
  ORDER_TYPE                NUMBER,
  ORDER_TYPE_TEXT           VARCHAR2(4000 BYTE),
  QUANTITY_RATE             NUMBER,
  OLD_ORDER_QUANTITY        NUMBER,
  NEW_ORDER_DATE            DATE,
  FIRM_PLANNED_TYPE         NUMBER,
  RESCHEDULED_FLAG          NUMBER,
  IMPLEMENTED_QUANTITY      NUMBER,
  NEW_DOCK_DATE             DATE,
  QUANTITY_IN_PROCESS       NUMBER,
  FIRM_QUANTITY             NUMBER,
  FIRM_DATE                 DATE,
  ITEM_SEGMENTS             VARCHAR2(250 BYTE),
  IMPLEMENT_DATE            DATE,
  IMPLEMENT_FIRM            NUMBER,
  CATEGORY_ID               NUMBER,
  SOURCE_ORGANIZATION_ID    NUMBER,
  SOURCE_ORGANIZATION_CODE  VARCHAR2(4000 BYTE),
  VENDOR_ID                 NUMBER,
  SUPPLIER_NAME             VARCHAR2(4000 BYTE),
  SUPPLIER_SITE_CODE        VARCHAR2(4000 BYTE),
  PROJECT_ID                NUMBER(15),
  TASK_ID                   NUMBER(15),
  STATUS                    NUMBER,
  APPLIED                   NUMBER,
  QUANTITY                  NUMBER,
  FIRM_DUE_DATE             DATE,
  IMPLEMENT_DUE_DATE        DATE,
  AMOUNT                    NUMBER,
  RELEASE_STATUS            NUMBER(5),
  EXPORT_FLAG               VARCHAR2(1 BYTE),
  POST_FLAG                 NUMBER
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
-- XXD_MSC_MASS_UPDATE_TBL  (Synonym) 
--
--  Dependencies: 
--   XXD_MSC_MASS_UPDATE_TBL (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_MSC_MASS_UPDATE_TBL FOR XXDO.XXD_MSC_MASS_UPDATE_TBL
/
