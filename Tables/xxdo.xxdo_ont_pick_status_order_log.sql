--
-- XXDO_ONT_PICK_STATUS_ORDER_LOG  (Table) 
--
CREATE TABLE XXDO.XXDO_ONT_PICK_STATUS_ORDER_LOG
(
  WH_ID               VARCHAR2(10 BYTE)         NOT NULL,
  ORDER_NUMBER        NUMBER                    NOT NULL,
  TRAN_DATE           DATE,
  STATUS              VARCHAR2(30 BYTE)         NOT NULL,
  SHIPMENT_NUMBER     VARCHAR2(30 BYTE),
  SHIPMENT_STATUS     VARCHAR2(50 BYTE),
  COMMENTS            VARCHAR2(2000 BYTE),
  ERROR_MSG           VARCHAR2(2000 BYTE),
  CREATED_BY          NUMBER                    DEFAULT -1                    NOT NULL,
  CREATION_DATE       DATE                      DEFAULT SYSDATE               NOT NULL,
  LAST_UPDATED_BY     NUMBER                    DEFAULT -1                    NOT NULL,
  LAST_UPDATE_DATE    DATE                      DEFAULT SYSDATE               NOT NULL,
  LAST_UPDATE_LOGIN   NUMBER                    DEFAULT -1                    NOT NULL,
  PROCESS_STATUS      VARCHAR2(20 BYTE)         NOT NULL,
  RECORD_TYPE         VARCHAR2(20 BYTE)         DEFAULT 'INSERT'              NOT NULL,
  SOURCE              VARCHAR2(20 BYTE)         DEFAULT 'WMS',
  DESTINATION         VARCHAR2(20 BYTE)         DEFAULT 'EBS',
  REQUEST_ID          NUMBER,
  ARCHIVE_REQUEST_ID  NUMBER,
  ARCHIVE_DATE        DATE
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
-- XXDO_ONT_PICK_STATUS_ORDER_LOG  (Synonym) 
--
--  Dependencies: 
--   XXDO_ONT_PICK_STATUS_ORDER_LOG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_ONT_PICK_STATUS_ORDER_LOG FOR XXDO.XXDO_ONT_PICK_STATUS_ORDER_LOG
/
