--
-- XXD_GL_BL_REPORT_LINK_EXT_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_BL_REPORT_LINK_EXT_T
(
  REQUEST_ID              NUMBER,
  BL_LINK                 VARCHAR2(50 BYTE),
  ENTITY_NAME             VARCHAR2(150 BYTE),
  ENTITY_UNIQ_IDENTIFIER  VARCHAR2(50 BYTE),
  ACCOUNT_NUMBER          VARCHAR2(50 BYTE),
  KEY3                    VARCHAR2(50 BYTE),
  KEY4                    VARCHAR2(50 BYTE),
  KEY5                    VARCHAR2(50 BYTE),
  KEY6                    VARCHAR2(50 BYTE),
  KEY7                    VARCHAR2(50 BYTE),
  KEY8                    VARCHAR2(50 BYTE),
  KEY9                    VARCHAR2(50 BYTE),
  KEY10                   VARCHAR2(50 BYTE),
  PERIOD_END_DATE         DATE,
  SUBLEDR_REP_BAL         NUMBER,
  SUBLEDR_ALT_BAL         NUMBER,
  SUBLEDR_ACC_BAL         NUMBER,
  REF_ID                  NUMBER,
  REF_ATTR                VARCHAR2(150 BYTE),
  CREATION_DATE           DATE,
  CREATED_BY              NUMBER,
  LAST_UPDATE_DATE        DATE,
  LAST_UPDATED_BY         NUMBER
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
-- XXD_GL_BL_REPORT_LINK_IDX1  (Index) 
--
--  Dependencies: 
--   XXD_GL_BL_REPORT_LINK_EXT_T (Table)
--
CREATE INDEX XXDO.XXD_GL_BL_REPORT_LINK_IDX1 ON XXDO.XXD_GL_BL_REPORT_LINK_EXT_T
(REQUEST_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/
