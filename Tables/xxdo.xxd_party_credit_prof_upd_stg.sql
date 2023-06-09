--
-- XXD_PARTY_CREDIT_PROF_UPD_STG  (Table) 
--
CREATE TABLE XXDO.XXD_PARTY_CREDIT_PROF_UPD_STG
(
  SEQ_ID                       NUMBER,
  BATCH_ID                     NUMBER,
  NONBRAND_CUST_NO             VARCHAR2(30 BYTE),
  CREDIT_ANALYST               VARCHAR2(240 BYTE),
  NEXT_SCHEDULED_REVIEW_DATE   DATE,
  CUSTOMER_CATEGORY            VARCHAR2(30 BYTE),
  STATUS                       VARCHAR2(1 BYTE),
  ERROR_MESSAGE                VARCHAR2(4000 BYTE),
  REQUEST_ID                   NUMBER,
  CREATED_BY                   NUMBER,
  CREATION_DATE                DATE,
  LAST_UPDATED_BY              NUMBER,
  LAST_UPDATE_DATE             DATE,
  LAST_UPDATE_LOGIN            NUMBER,
  PROFILE_CLASS                VARCHAR2(30 BYTE),
  CURRENCY_CODE                VARCHAR2(15 BYTE),
  CREDIT_LIMIT                 NUMBER,
  ORDER_CREDIT_LIMIT           NUMBER,
  CREDIT_CLASSIFICATION        VARCHAR2(80 BYTE),
  REVIEW_CYCLE                 VARCHAR2(80 BYTE),
  US_VEN_VIO_RESEARCHER        VARCHAR2(150 BYTE),
  US_FREIGHT_RESEARCHER        VARCHAR2(150 BYTE),
  US_DISCOUNT_RESEARCHER       VARCHAR2(150 BYTE),
  US_CREDIT_MEMO_RESEARCHER    VARCHAR2(150 BYTE),
  US_SHORT_PAYMENT_RESEARCHER  VARCHAR2(150 BYTE),
  LAST_REVIEW_DATE             VARCHAR2(150 BYTE),
  SAFE_NUMBER                  VARCHAR2(150 BYTE),
  PARENT_NUMBER                VARCHAR2(150 BYTE),
  ULTIMATE_PARENT_NUMBER       VARCHAR2(150 BYTE),
  CREDIT_CHECKING              VARCHAR2(150 BYTE),
  BUYING_GROUP_CUST_NUM        VARCHAR2(150 BYTE),
  CUST_MEMBERSHIP_NUM          VARCHAR2(150 BYTE),
  BUYING_GROUP_VAT_NUM         VARCHAR2(150 BYTE),
  ATTRUBUTE9                   VARCHAR2(150 BYTE),
  ATTRUBUTE10                  VARCHAR2(150 BYTE)
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
-- XXD_PARTY_CREDIT_PROF_UPD_STG  (Synonym) 
--
--  Dependencies: 
--   XXD_PARTY_CREDIT_PROF_UPD_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PARTY_CREDIT_PROF_UPD_STG FOR XXDO.XXD_PARTY_CREDIT_PROF_UPD_STG
/
