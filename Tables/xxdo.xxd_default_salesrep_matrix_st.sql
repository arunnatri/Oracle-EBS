--
-- XXD_DEFAULT_SALESREP_MATRIX_ST  (Table) 
--
CREATE TABLE XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
(
  RECORD_NUMBER      NUMBER,
  OPERATING_UNIT     VARCHAR2(100 BYTE),
  BRAND              VARCHAR2(80 BYTE),
  CUSTOMER_NAME      VARCHAR2(150 BYTE),
  CUSTOMER_NUMBER    VARCHAR2(50 BYTE),
  SALES_REP          VARCHAR2(50 BYTE),
  SALESREP_NAME      VARCHAR2(150 BYTE),
  SITE_CODE          VARCHAR2(50 BYTE),
  SITE_LOCATION      VARCHAR2(50 BYTE),
  DIVISION           VARCHAR2(30 BYTE),
  DEPARTMENT         VARCHAR2(30 BYTE),
  CLASS              VARCHAR2(30 BYTE),
  SUB_CLASS          VARCHAR2(30 BYTE),
  STATUS             VARCHAR2(10 BYTE),
  ERROR_MSG          VARCHAR2(2000 BYTE),
  X_CUSTOMER_ID      NUMBER,
  X_SALESREP_ID      NUMBER,
  X_SALESREP_NUMBER  VARCHAR2(2000 BYTE),
  X_SALESREP_NAME    VARCHAR2(2000 BYTE),
  X_BRAND            VARCHAR2(2000 BYTE),
  X_SITE_USE_ID      NUMBER,
  X_DIVISION         VARCHAR2(2000 BYTE),
  X_DEPARTMENT       VARCHAR2(2000 BYTE),
  X_CLASS            VARCHAR2(2000 BYTE),
  X_SUB_CLASS        VARCHAR2(2000 BYTE),
  X_ORG_ID           NUMBER,
  X_OU_NAME          VARCHAR2(2000 BYTE),
  X_CUSTOMER_NAME    VARCHAR2(2000 BYTE),
  X_CUSTOMER_NUMBER  VARCHAR2(2000 BYTE),
  X_CUSTOMER_SITE    VARCHAR2(2000 BYTE),
  X_SITE_USE_CODE    VARCHAR2(2000 BYTE),
  X_ACCOUNT_NAME     VARCHAR2(2000 BYTE),
  SITE_USE_ID        NUMBER
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST TO APPS WITH GRANT OPTION
/

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST TO XXD_CONV
/
