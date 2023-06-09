--
-- XXDO_INV_ITEM_INT_STG  (Table) 
--
CREATE TABLE XXDO.XXDO_INV_ITEM_INT_STG
(
  WH_ID              VARCHAR2(10 BYTE)          NOT NULL,
  DATETIME           DATE,
  ITEM_NUMBER        VARCHAR2(30 BYTE)          NOT NULL,
  CASE_LENGTH        FLOAT(126),
  CASE_WIDTH         FLOAT(126),
  CASE_HEIGHT        FLOAT(126),
  CASE_WEIGHT        FLOAT(126),
  EACH_LENGTH        FLOAT(126),
  EACH_WIDTH         FLOAT(126),
  EACH_HEIGHT        FLOAT(126),
  EACH_WEIGHT        FLOAT(126),
  CASES_PER_PALLET   NUMBER,
  UNITS_PER_CASE     NUMBER,
  PROCESS_STATUS     VARCHAR2(20 BYTE),
  ERROR_MESSAGE      VARCHAR2(1000 BYTE),
  REQUEST_ID         NUMBER,
  CREATION_DATE      DATE                       DEFAULT SYSDATE               NOT NULL,
  CREATED_BY         NUMBER                     DEFAULT -1                    NOT NULL,
  LAST_UPDATE_DATE   DATE                       DEFAULT SYSDATE               NOT NULL,
  LAST_UPDATED_BY    NUMBER                     DEFAULT -1                    NOT NULL,
  LAST_UPDATE_LOGIN  NUMBER                     DEFAULT -1                    NOT NULL,
  SOURCE_TYPE        VARCHAR2(20 BYTE),
  ATTRIBUTE1         VARCHAR2(50 BYTE),
  ATTRIBUTE2         VARCHAR2(50 BYTE),
  ATTRIBUTE3         VARCHAR2(50 BYTE),
  ATTRIBUTE4         VARCHAR2(50 BYTE),
  ATTRIBUTE5         VARCHAR2(50 BYTE),
  ATTRIBUTE6         VARCHAR2(50 BYTE),
  ATTRIBUTE7         VARCHAR2(50 BYTE),
  ATTRIBUTE8         VARCHAR2(50 BYTE),
  ATTRIBUTE9         VARCHAR2(50 BYTE),
  ATTRIBUTE10        VARCHAR2(50 BYTE),
  ATTRIBUTE11        VARCHAR2(50 BYTE),
  ATTRIBUTE12        VARCHAR2(50 BYTE),
  ATTRIBUTE13        VARCHAR2(50 BYTE),
  ATTRIBUTE14        VARCHAR2(50 BYTE),
  ATTRIBUTE15        VARCHAR2(50 BYTE),
  ATTRIBUTE16        VARCHAR2(50 BYTE),
  ATTRIBUTE17        VARCHAR2(50 BYTE),
  ATTRIBUTE18        VARCHAR2(50 BYTE),
  ATTRIBUTE19        VARCHAR2(50 BYTE),
  ATTRIBUTE20        VARCHAR2(50 BYTE),
  SOURCE             VARCHAR2(20 BYTE),
  DESTINATION        VARCHAR2(20 BYTE),
  RECORD_TYPE        VARCHAR2(20 BYTE),
  INVENTORY_ITEM_ID  NUMBER,
  ORG_ID             NUMBER,
  INTERFACE_SEQ_ID   NUMBER
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
-- XXDO_INV_ITEM_INT_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_ITEM_INT_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_ITEM_INT_STG FOR XXDO.XXDO_INV_ITEM_INT_STG
/


GRANT INSERT, SELECT, UPDATE ON XXDO.XXDO_INV_ITEM_INT_STG TO SOA_INT
/
