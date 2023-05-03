--
-- XXD_GL_VT_ICS_GL_YTD_RECON_T  (Table) 
--
CREATE TABLE XXDO.XXD_GL_VT_ICS_GL_YTD_RECON_T
(
  COMPANY                   VARCHAR2(100 BYTE),
  COMPANT_NAME              VARCHAR2(1000 BYTE),
  IC_PARTNERS               VARCHAR2(500 BYTE),
  ACCOUNTED_CURRENCY        VARCHAR2(100 BYTE),
  ENTERED_CURRENCY          VARCHAR2(100 BYTE),
  ACCOUNT_STRING            VARCHAR2(1000 BYTE),
  COM_AR_BAL_IN_ICS         NUMBER,
  COM_AP_BAL_IN_ICS         NUMBER,
  NET_ENTERED_BAL_IN_ICS    NUMBER,
  GL_BALANCE                NUMBER,
  ENTERED_DIFF              NUMBER,
  COM_ACC_AR_BAL_IN_ICS     NUMBER,
  COM_ACC_AP_BAL_IN_ICS     NUMBER,
  NET_ACCOUNTED_BAL_IN_ICS  NUMBER,
  GL_BALANCE_ACCOUNTED      NUMBER,
  FX_RATE                   NUMBER,
  ENTITY_UNIQUE_IDENTIFIER  VARCHAR2(10 BYTE),
  ACCOUNT_NUMBER            VARCHAR2(10 BYTE),
  KEY3                      VARCHAR2(10 BYTE),
  KEY4                      VARCHAR2(10 BYTE),
  KEY5                      VARCHAR2(10 BYTE),
  KEY6                      VARCHAR2(10 BYTE),
  KEY7                      VARCHAR2(10 BYTE),
  KEY8                      VARCHAR2(10 BYTE),
  KEY9                      VARCHAR2(10 BYTE),
  KEY10                     VARCHAR2(10 BYTE),
  PERIOD_END_DATE           VARCHAR2(20 BYTE),
  SUBLEDGER_REP_BAL         NUMBER,
  SUBLEDGER_ALT_BAL         NUMBER,
  SUBLEDGER_ACC_BAL         NUMBER,
  CREATED_BY                NUMBER,
  CREATION_DATE             DATE,
  LAST_UPDATED_BY           NUMBER,
  LAST_UPDATE_DATE          DATE,
  REQUEST_ID                NUMBER
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
