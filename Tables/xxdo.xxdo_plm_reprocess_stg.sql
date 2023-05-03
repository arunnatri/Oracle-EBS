--
-- XXDO_PLM_REPROCESS_STG  (Table) 
--
CREATE TABLE XXDO.XXDO_PLM_REPROCESS_STG
(
  PARENT_RECORD_ID   NUMBER(10)                 NOT NULL,
  SEQUENCE_NUM       NUMBER(10),
  STYLE              VARCHAR2(100 BYTE),
  BRAND              VARCHAR2(100 BYTE),
  ITEM_NUMBER        VARCHAR2(100 BYTE),
  ITEM_ID            NUMBER,
  ORG_ID             VARCHAR2(100 BYTE),
  ORGANIZATION_CODE  VARCHAR2(100 BYTE),
  UOM                VARCHAR2(100 BYTE),
  TEMPLATE_ID        NUMBER,
  DESCRIPTION        VARCHAR2(100 BYTE),
  CURRENT_SEASON     VARCHAR2(100 BYTE),
  LIFE_CYCLE         VARCHAR2(100 BYTE),
  VERRCODE           VARCHAR2(3000 BYTE),
  REC_STATUS         VARCHAR2(10 BYTE),
  VERRMSG            VARCHAR2(1000 BYTE),
  CREATION_DATE      DATE                       DEFAULT SYSDATE,
  UPDATE_DATE        DATE                       DEFAULT SYSDATE,
  REQUEST_ID         NUMBER
)
TABLESPACE APPS_TS_TX_DATA
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
/