--
-- XXDO_ONT_SHIP_CONF_CARTON_LOG  (Table) 
--
CREATE TABLE XXDO.XXDO_ONT_SHIP_CONF_CARTON_LOG
(
  WH_ID               VARCHAR2(10 BYTE)         NOT NULL,
  SHIPMENT_NUMBER     VARCHAR2(30 BYTE)         NOT NULL,
  ORDER_NUMBER        VARCHAR2(30 BYTE)         NOT NULL,
  CARTON_NUMBER       VARCHAR2(22 BYTE)         NOT NULL,
  TRACKING_NUMBER     VARCHAR2(30 BYTE),
  FREIGHT_LIST        VARCHAR2(30 BYTE),
  FREIGHT_ACTUAL      NUMBER,
  WEIGHT              NUMBER,
  LENGTH              NUMBER,
  WIDTH               NUMBER,
  HEIGHT              NUMBER,
  ARCHIVE_DATE        DATE                      NOT NULL,
  ARCHIVE_REQUEST_ID  NUMBER                    NOT NULL,
  PROCESS_STATUS      VARCHAR2(20 BYTE)         NOT NULL,
  ERROR_MESSAGE       VARCHAR2(1000 BYTE),
  REQUEST_ID          NUMBER                    NOT NULL,
  CREATION_DATE       DATE                      NOT NULL,
  CREATED_BY          NUMBER                    NOT NULL,
  LAST_UPDATE_DATE    DATE                      NOT NULL,
  LAST_UPDATED_BY     NUMBER                    NOT NULL,
  SOURCE_TYPE         VARCHAR2(20 BYTE),
  ATTRIBUTE1          VARCHAR2(50 BYTE),
  ATTRIBUTE2          VARCHAR2(50 BYTE),
  ATTRIBUTE3          VARCHAR2(50 BYTE),
  ATTRIBUTE4          VARCHAR2(50 BYTE),
  ATTRIBUTE5          VARCHAR2(50 BYTE),
  ATTRIBUTE6          VARCHAR2(50 BYTE),
  ATTRIBUTE7          VARCHAR2(50 BYTE),
  ATTRIBUTE8          VARCHAR2(50 BYTE),
  ATTRIBUTE9          VARCHAR2(50 BYTE),
  ATTRIBUTE10         VARCHAR2(50 BYTE),
  ATTRIBUTE11         VARCHAR2(50 BYTE),
  ATTRIBUTE12         VARCHAR2(50 BYTE),
  ATTRIBUTE13         VARCHAR2(50 BYTE),
  ATTRIBUTE14         VARCHAR2(50 BYTE),
  ATTRIBUTE15         VARCHAR2(50 BYTE),
  ATTRIBUTE16         VARCHAR2(50 BYTE),
  ATTRIBUTE17         VARCHAR2(50 BYTE),
  ATTRIBUTE18         VARCHAR2(50 BYTE),
  ATTRIBUTE19         VARCHAR2(50 BYTE),
  ATTRIBUTE20         VARCHAR2(50 BYTE),
  SOURCE              VARCHAR2(20 BYTE)         DEFAULT 'ORDER'               NOT NULL,
  DESTINATION         VARCHAR2(20 BYTE)         NOT NULL,
  RECORD_TYPE         VARCHAR2(20 BYTE)         DEFAULT 'EBS'                 NOT NULL,
  FREIGHT_CHARGED     NUMBER
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
-- XXDO_ONT_SHIP_CONF_CARTON_LOG  (Synonym) 
--
--  Dependencies: 
--   XXDO_ONT_SHIP_CONF_CARTON_LOG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_ONT_SHIP_CONF_CARTON_LOG FOR XXDO.XXDO_ONT_SHIP_CONF_CARTON_LOG
/
