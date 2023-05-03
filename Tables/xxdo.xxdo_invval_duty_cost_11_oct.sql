--
-- XXDO_INVVAL_DUTY_COST_11_OCT  (Table) 
--
CREATE TABLE XXDO.XXDO_INVVAL_DUTY_COST_11_OCT
(
  OPERATING_UNIT     NUMBER,
  COUNTRY_OF_ORIGIN  VARCHAR2(150 BYTE),
  PRIMARY_DUTY_FLAG  VARCHAR2(1 BYTE),
  OH_DUTY            NUMBER,
  OH_NONDUTY         NUMBER,
  ADDITIONAL_DUTY    NUMBER,
  INVENTORY_ORG      NUMBER,
  INVENTORY_ITEM_ID  NUMBER,
  DUTY               NUMBER,
  DUTY_START_DATE    DATE,
  DUTY_END_DATE      DATE,
  STYLE_COLOR        VARCHAR2(150 BYTE),
  LAST_UPDATE_DATE   DATE,
  LAST_UPDATED_BY    VARCHAR2(150 BYTE),
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  FREIGHT            NUMBER,
  FREIGHT_DUTY       NUMBER
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
