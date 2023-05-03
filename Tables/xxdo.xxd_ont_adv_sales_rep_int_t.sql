--
-- XXD_ONT_ADV_SALES_REP_INT_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_ADV_SALES_REP_INT_T
(
  FILE_NAME          VARCHAR2(200 BYTE),
  SALESREP_ID        NUMBER,
  SALESREP_NUMBER    VARCHAR2(30 BYTE),
  SALESREP_NAME      VARCHAR2(360 BYTE),
  BRAND              VARCHAR2(150 BYTE),
  CUSTOMER_NUMBER    VARCHAR2(100 BYTE),
  ACCOUNT_NAME       VARCHAR2(240 BYTE),
  START_DATE         DATE,
  END_DATE           DATE,
  STATUS             VARCHAR2(100 BYTE),
  ERROR_MESSAGE      VARCHAR2(4000 BYTE),
  ATTRIBUTE1         VARCHAR2(240 BYTE),
  ATTRIBUTE2         VARCHAR2(240 BYTE),
  ATTRIBUTE3         VARCHAR2(240 BYTE),
  ATTRIBUTE4         VARCHAR2(240 BYTE),
  ATTRIBUTE5         VARCHAR2(240 BYTE),
  ATTRIBUTE6         VARCHAR2(240 BYTE),
  ATTRIBUTE7         VARCHAR2(240 BYTE),
  ATTRIBUTE8         VARCHAR2(240 BYTE),
  ATTRIBUTE9         VARCHAR2(240 BYTE),
  ATTRIBUTE10        VARCHAR2(240 BYTE),
  ATTRIBUTE11        VARCHAR2(240 BYTE),
  ATTRIBUTE12        VARCHAR2(240 BYTE),
  ATTRIBUTE13        VARCHAR2(240 BYTE),
  ATTRIBUTE14        VARCHAR2(240 BYTE),
  ATTRIBUTE15        VARCHAR2(240 BYTE),
  REQUEST_ID         NUMBER,
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATED_BY    NUMBER,
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATE_LOGIN  NUMBER
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
-- XXD_ONT_ADV_SALES_REP_INT_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_ADV_SALES_REP_INT_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_ADV_SALES_REP_INT_N1 ON XXDO.XXD_ONT_ADV_SALES_REP_INT_T
(STATUS, REQUEST_ID)
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
-- XXD_ONT_ADV_SALES_REP_INT_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_ADV_SALES_REP_INT_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_ADV_SALES_REP_INT_T FOR XXDO.XXD_ONT_ADV_SALES_REP_INT_T
/