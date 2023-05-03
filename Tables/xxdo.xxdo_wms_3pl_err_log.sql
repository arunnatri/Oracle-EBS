--
-- XXDO_WMS_3PL_ERR_LOG  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_ERR_LOG
(
  ERR_ID                 NUMBER                 NOT NULL,
  OPERATION_TYPE         VARCHAR2(30 BYTE),
  OPERATION_CODE         VARCHAR2(30 BYTE),
  ERROR_MESSAGE          VARCHAR2(2000 BYTE),
  FILE_NAME              VARCHAR2(2000 BYTE),
  CREATED_BY             NUMBER                 DEFAULT 0,
  CREATION_DATE          DATE                   DEFAULT sysdate,
  LAST_UPDATED_BY        NUMBER                 DEFAULT 0,
  LAST_UPDATE_DATE       DATE                   DEFAULT sysdate,
  PROCESS_STATUS         VARCHAR2(1 BYTE)       DEFAULT 'E',
  PROCESSING_SESSION_ID  NUMBER                 DEFAULT null,
  LOGGING_ID             VARCHAR2(240 BYTE),
  IN_PROCESS_FLAG        VARCHAR2(1 BYTE)       DEFAULT 'N'                   NOT NULL
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
