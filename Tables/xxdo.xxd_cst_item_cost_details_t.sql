--
-- XXD_CST_ITEM_COST_DETAILS_T  (Table) 
--
CREATE TABLE XXDO.XXD_CST_ITEM_COST_DETAILS_T
(
  ROW_ID                         ROWID,
  INVENTORY_ITEM_ID              NUMBER         NOT NULL,
  ORGANIZATION_ID                NUMBER         NOT NULL,
  COST_TYPE_ID                   NUMBER         NOT NULL,
  LAST_UPDATE_DATE               DATE           NOT NULL,
  LAST_UPDATED_BY                NUMBER         NOT NULL,
  CREATION_DATE                  DATE           NOT NULL,
  CREATED_BY                     NUMBER         NOT NULL,
  LAST_UPDATE_LOGIN              NUMBER,
  OPERATION_SEQUENCE_ID          NUMBER,
  OPERATION_SEQ_NUM              NUMBER,
  DEPARTMENT_ID                  NUMBER,
  LEVEL_TYPE                     NUMBER         NOT NULL,
  LEVEL_TYPE_DSP                 VARCHAR2(80 BYTE) NOT NULL,
  ACTIVITY_ID                    NUMBER,
  ACTIVITY                       VARCHAR2(10 BYTE),
  RESOURCE_SEQ_NUM               NUMBER,
  RESOURCE_ID                    NUMBER,
  RESOURCE_CODE                  VARCHAR2(10 BYTE),
  UNIT_OF_MEASURE                VARCHAR2(3 BYTE),
  RESOURCE_RATE                  NUMBER,
  ITEM_UNITS                     NUMBER,
  ACTIVITY_UNITS                 NUMBER,
  USAGE_RATE_OR_AMOUNT           NUMBER         NOT NULL,
  BASIS_TYPE                     NUMBER         NOT NULL,
  BASIS_TYPE_DSP                 VARCHAR2(80 BYTE) NOT NULL,
  BASIS_RESOURCE_ID              NUMBER,
  BASIS_FACTOR                   NUMBER         NOT NULL,
  NET_YIELD_OR_SHRINKAGE_FACTOR  NUMBER         NOT NULL,
  ITEM_COST                      NUMBER         NOT NULL,
  COST_ELEMENT_ID                NUMBER,
  COST_ELEMENT                   VARCHAR2(50 BYTE) NOT NULL,
  SOURCE_TYPE                    VARCHAR2(80 BYTE) NOT NULL,
  ROLLUP_SOURCE_TYPE             NUMBER         NOT NULL,
  ACTIVITY_CONTEXT               VARCHAR2(30 BYTE),
  REQUEST_ID                     NUMBER,
  PROGRAM_APPLICATION_ID         NUMBER,
  PROGRAM_ID                     NUMBER,
  PROGRAM_UPDATE_DATE            DATE,
  ATTRIBUTE_CATEGORY             VARCHAR2(30 BYTE),
  ATTRIBUTE1                     VARCHAR2(150 BYTE),
  ATTRIBUTE2                     VARCHAR2(150 BYTE),
  ATTRIBUTE3                     VARCHAR2(150 BYTE),
  ATTRIBUTE4                     VARCHAR2(150 BYTE),
  ATTRIBUTE5                     VARCHAR2(150 BYTE),
  ATTRIBUTE6                     VARCHAR2(150 BYTE),
  ATTRIBUTE7                     VARCHAR2(150 BYTE),
  ATTRIBUTE8                     VARCHAR2(150 BYTE),
  ATTRIBUTE9                     VARCHAR2(150 BYTE),
  ATTRIBUTE10                    VARCHAR2(150 BYTE),
  ATTRIBUTE11                    VARCHAR2(150 BYTE),
  ATTRIBUTE12                    VARCHAR2(150 BYTE),
  ATTRIBUTE13                    VARCHAR2(150 BYTE),
  ATTRIBUTE14                    VARCHAR2(150 BYTE),
  ATTRIBUTE15                    VARCHAR2(150 BYTE),
  YIELDED_COST                   NUMBER,
  TRANSACTION_ID                 NUMBER,
  TRANSACTION_DATE               DATE,
  SNAP_CREATED_BY                NUMBER,
  SNAPSHOT_DATE                  DATE
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
-- XXD_CST_ITEM_DTLS_N1  (Index) 
--
--  Dependencies: 
--   XXD_CST_ITEM_COST_DETAILS_T (Table)
--
CREATE INDEX XXDO.XXD_CST_ITEM_DTLS_N1 ON XXDO.XXD_CST_ITEM_COST_DETAILS_T
(INVENTORY_ITEM_ID, ORGANIZATION_ID)
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

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_CST_ITEM_COST_DETAILS_T TO APPS
/
