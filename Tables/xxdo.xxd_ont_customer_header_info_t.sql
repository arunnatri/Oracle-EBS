--
-- XXD_ONT_CUSTOMER_HEADER_INFO_T  (Table) 
--
CREATE TABLE XXDO.XXD_ONT_CUSTOMER_HEADER_INFO_T
(
  ACCOUNT_NAME                    VARCHAR2(360 BYTE),
  CUST_ACCOUNT_ID                 NUMBER,
  ACCOUNT_NUMBER                  VARCHAR2(30 BYTE),
  BRAND                           VARCHAR2(30 BYTE),
  CUSTOMER_CLASS                  VARCHAR2(30 BYTE),
  SHIP_METHOD                     VARCHAR2(100 BYTE),
  FREIGHT_TERMS                   VARCHAR2(100 BYTE),
  FREIGHT_ACCOUNT                 VARCHAR2(30 BYTE),
  SHIPPING_INSTRUCTIONS           VARCHAR2(2000 BYTE),
  PACKING_INSTRUCTIONS            VARCHAR2(2000 BYTE),
  GS1_FORMAT                      VARCHAR2(100 BYTE),
  GS1_MC_PANEL                    VARCHAR2(30 BYTE),
  GS1_JUSTIFICATION               VARCHAR2(30 BYTE),
  GS1_SIDE_OFFSET                 NUMBER,
  GS1_BOTTOM_OFFSET               NUMBER,
  PRINT_CC                        VARCHAR2(1 BYTE),
  CC_MC_PANEL                     VARCHAR2(30 BYTE),
  CC_JUSTIFICATION                VARCHAR2(30 BYTE),
  CC_SIDE_OFFSET                  NUMBER,
  CC_BOTTOM_OFFSET                NUMBER,
  MC_MAX_LENGTH                   NUMBER,
  MC_MAX_WIDTH                    NUMBER,
  MC_MAX_HEIGHT                   NUMBER,
  MC_MAX_WEIGHT                   NUMBER,
  MC_MIN_LENGTH                   NUMBER,
  MC_MIN_WIDTH                    NUMBER,
  MC_MIN_HEIGHT                   NUMBER,
  MC_MIN_WEIGHT                   NUMBER,
  CUSTOM_DROPSHIP_PACKSLIP_FLAG   VARCHAR2(1 BYTE),
  CUSTOM_DROPSHIP_PHONE_NUM       VARCHAR2(100 BYTE),
  CUSTOM_DROPSHIP_EMAIL           VARCHAR2(100 BYTE),
  PRINT_PACK_SLIP                 VARCHAR2(1 BYTE),
  DROPSHIP_PACKSLIP_DISPLAY_NAME  VARCHAR2(100 BYTE),
  DROPSHIP_PACKSLIP_MESSAGE       VARCHAR2(2000 BYTE),
  SERVICE_TIME_FRAME              VARCHAR2(100 BYTE),
  CALL_IN_SLA                     VARCHAR2(100 BYTE),
  TMS_CUTOFF_TIME                 VARCHAR2(100 BYTE),
  ROUTING_DAY1                    VARCHAR2(100 BYTE),
  SCHEDULED_DAY1                  VARCHAR2(100 BYTE),
  ROUTING_DAY2                    VARCHAR2(100 BYTE),
  SCHEDULED_DAY2                  VARCHAR2(100 BYTE),
  BACK_TO_BACK                    VARCHAR2(1 BYTE),
  TMS_FLAG                        VARCHAR2(1 BYTE),
  TMS_URL                         VARCHAR2(1000 BYTE),
  TMS_USERNAME                    VARCHAR2(100 BYTE),
  TMS_PASSWORD                    VARCHAR2(100 BYTE),
  ROUTING_NOTES                   VARCHAR2(2000 BYTE),
  ROUTING_CONTACT_NAME            VARCHAR2(100 BYTE),
  ROUTING_CONTACT_PHONE           VARCHAR2(100 BYTE),
  ROUTING_CONTACT_FAX             VARCHAR2(100 BYTE),
  ROUTING_CONTACT_EMAIL           VARCHAR2(100 BYTE),
  PARCEL_SHIP_METHOD              VARCHAR2(100 BYTE),
  PARCEL_WEIGHT_LIMIT             NUMBER,
  PARCEL_DIM_WEIGHT_FLAG          VARCHAR2(1 BYTE),
  PARCEL_CARTON_LIMIT             NUMBER,
  LTL_SHIP_METHOD                 VARCHAR2(100 BYTE),
  LTL_WEIGHT_LIMIT                NUMBER,
  LTL_DIM_WEIGHT_FLAG             VARCHAR2(1 BYTE),
  LTL_CARTON_LIMIT                NUMBER,
  FTL_SHIP_METHOD                 VARCHAR2(100 BYTE),
  FTL_WEIGHT_LIMIT                NUMBER,
  FTL_DIM_WEIGHT_FLAG             VARCHAR2(1 BYTE),
  FTL_UNIT_LIMIT                  NUMBER,
  FTL_PALLET_FLAG                 VARCHAR2(1 BYTE),
  ATTRIBUTE1                      VARCHAR2(240 BYTE),
  ATTRIBUTE2                      VARCHAR2(240 BYTE),
  ATTRIBUTE3                      VARCHAR2(240 BYTE),
  ATTRIBUTE4                      VARCHAR2(240 BYTE),
  ATTRIBUTE5                      VARCHAR2(240 BYTE),
  ATTRIBUTE6                      VARCHAR2(240 BYTE),
  ATTRIBUTE7                      VARCHAR2(240 BYTE),
  ATTRIBUTE8                      VARCHAR2(240 BYTE),
  ATTRIBUTE9                      VARCHAR2(240 BYTE),
  ATTRIBUTE10                     VARCHAR2(240 BYTE),
  ATTRIBUTE11                     VARCHAR2(240 BYTE),
  ATTRIBUTE12                     VARCHAR2(240 BYTE),
  ATTRIBUTE13                     VARCHAR2(240 BYTE),
  ATTRIBUTE14                     VARCHAR2(240 BYTE),
  ATTRIBUTE15                     VARCHAR2(240 BYTE),
  ATTRIBUTE16                     VARCHAR2(240 BYTE),
  ATTRIBUTE17                     VARCHAR2(240 BYTE),
  ATTRIBUTE18                     VARCHAR2(240 BYTE),
  ATTRIBUTE19                     VARCHAR2(240 BYTE),
  ATTRIBUTE20                     VARCHAR2(240 BYTE),
  ATTRIBUTE21                     VARCHAR2(240 BYTE),
  ATTRIBUTE22                     VARCHAR2(240 BYTE),
  ATTRIBUTE23                     VARCHAR2(240 BYTE),
  ATTRIBUTE24                     VARCHAR2(240 BYTE),
  ATTRIBUTE25                     VARCHAR2(240 BYTE),
  ATTRIBUTE26                     VARCHAR2(240 BYTE),
  ATTRIBUTE27                     VARCHAR2(240 BYTE),
  ATTRIBUTE28                     VARCHAR2(240 BYTE),
  ATTRIBUTE29                     VARCHAR2(240 BYTE),
  ATTRIBUTE30                     VARCHAR2(240 BYTE),
  CREATED_BY                      NUMBER,
  CREATION_DATE                   DATE,
  LAST_UPDATED_BY                 NUMBER,
  LAST_UPDATED_DATE               DATE,
  LAST_UPDATE_LOGIN               NUMBER,
  SUPPLEMENTAL LOG DATA (ALL) COLUMNS,
  SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS,
  SUPPLEMENTAL LOG DATA (UNIQUE) COLUMNS,
  SUPPLEMENTAL LOG DATA (FOREIGN KEY) COLUMNS
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
-- XXD_ONT_CUST_HEADER_INFO_N1  (Index) 
--
--  Dependencies: 
--   XXD_ONT_CUSTOMER_HEADER_INFO_T (Table)
--
CREATE INDEX XXDO.XXD_ONT_CUST_HEADER_INFO_N1 ON XXDO.XXD_ONT_CUSTOMER_HEADER_INFO_T
(CUST_ACCOUNT_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_ONT_CUSTOMER_HEADER_INFO_T  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_CUSTOMER_HEADER_INFO_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_ONT_CUSTOMER_HEADER_INFO_T FOR XXDO.XXD_ONT_CUSTOMER_HEADER_INFO_T
/
