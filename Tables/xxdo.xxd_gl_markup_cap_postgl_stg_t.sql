--
-- XXD_GL_MARKUP_CAP_POSTGL_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_MARKUP_CAP_POSTGL_STG_T
(
  TRANSACTION_ID                 NUMBER,
  ORGANIZATION_ID                NUMBER,
  STATUS                         VARCHAR2(10 BYTE),
  LEDGER_ID                      NUMBER,
  ACCOUNTING_DATE                DATE,
  CURRENCY_CODE                  VARCHAR2(5 BYTE),
  DATE_CREATED                   DATE,
  CREATED_BY                     NUMBER,
  ACTUAL_FLAG                    VARCHAR2(10 BYTE),
  REFERENCE10                    VARCHAR2(240 BYTE),
  ENTERED_CR                     NUMBER,
  ENTERED_DR                     NUMBER,
  USER_JE_SOURCE_NAME            VARCHAR2(50 BYTE),
  USER_JE_CATEGORY_NAME          VARCHAR2(50 BYTE),
  GROUP_ID                       NUMBER,
  REFERENCE1                     VARCHAR2(240 BYTE),
  REFERENCE4                     VARCHAR2(240 BYTE),
  PERIOD_NAME                    VARCHAR2(30 BYTE),
  SEGMENT1                       VARCHAR2(50 BYTE),
  SEGMENT2                       VARCHAR2(50 BYTE),
  SEGMENT3                       VARCHAR2(50 BYTE),
  SEGMENT4                       VARCHAR2(50 BYTE),
  SEGMENT5                       VARCHAR2(50 BYTE),
  SEGMENT6                       VARCHAR2(50 BYTE),
  SEGMENT7                       VARCHAR2(50 BYTE),
  SEGMENT8                       VARCHAR2(50 BYTE),
  CURRENCY_CONVERSION_DATE       DATE,
  USER_CURRENCY_CONVERSION_TYPE  VARCHAR2(30 BYTE),
  REQUEST_ID                     NUMBER
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
-- XXD_GL_MARKUP_CAP_POSTGL_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_MARKUP_CAP_POSTGL_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_MARKUP_CAP_POSTGL_STG_T FOR XXDO.XXD_GL_MARKUP_CAP_POSTGL_STG_T
/
