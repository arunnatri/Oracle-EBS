--
-- XXD_ONT_RMA_INTF_CMT_LN_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_RMA_INTF_CMT_LN_STG_T
(
  WAREHOUSE_CODE     VARCHAR2(10 BYTE)          NOT NULL,
  ORDER_NUMBER       VARCHAR2(30 BYTE)          NOT NULL,
  LINE_NUMBER        VARCHAR2(20 BYTE)          NOT NULL,
  COMMENT_TYPE       VARCHAR2(40 BYTE),
  COMMENT_SEQUENCE   NUMBER,
  COMMENT_TEXT       VARCHAR2(4000 BYTE),
  PROCESS_STATUS     VARCHAR2(20 BYTE),
  ERROR_MESSAGE      VARCHAR2(4000 BYTE),
  REQUEST_ID         NUMBER,
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    NUMBER,
  LAST_UPDATE_LOGIN  NUMBER,
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
  SOURCE             VARCHAR2(20 BYTE)          DEFAULT 'EBS',
  DESTINATION        VARCHAR2(20 BYTE)          DEFAULT 'WMS',
  LINE_ID            NUMBER                     NOT NULL,
  COMMENT_ID         NUMBER                     NOT NULL,
  BATCH_NUMBER       NUMBER
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
-- XXD_ONT_RMA_INTF_CMT_LN_ST_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_RMA_INTF_CMT_LN_STG_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_RMA_INTF_CMT_LN_ST_N1 ON XXDO.XXD_ONT_RMA_INTF_CMT_LN_STG_T
(LINE_ID)
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
-- XXD_ONT_RMA_INTF_CMT_LN_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_RMA_INTF_CMT_LN_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_RMA_INTF_CMT_LN_STG_T FOR XXDO.XXD_ONT_RMA_INTF_CMT_LN_STG_T
/


GRANT SELECT, UPDATE ON XXDO.XXD_ONT_RMA_INTF_CMT_LN_STG_T TO SOA_INT
/
