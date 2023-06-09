--
-- XXDO_DEMAND_CLASS_MAPPING  (Table) 
--
CREATE TABLE XXDO.XXDO_DEMAND_CLASS_MAPPING
(
  OPERATING_UNIT        VARCHAR2(200 BYTE),
  CUSTOMER_NAME         VARCHAR2(200 BYTE),
  CUSTOMER_ACCOUNT      VARCHAR2(200 BYTE),
  BRAND                 VARCHAR2(200 BYTE),
  CUSTOMER_ACCOUNT_NEW  VARCHAR2(200 BYTE),
  DEMANDCCLASS          VARCHAR2(200 BYTE)
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
