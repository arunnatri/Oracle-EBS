--
-- XXD_OZF_CLAIMS_UPDATE_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_OZF_CLAIMS_UPDATE_STG_T
(
  RECORD_ID             NUMBER,
  OPERATING_UNIT        VARCHAR2(240 BYTE),
  CLAIM_NUMBER          VARCHAR2(30 BYTE),
  WRITE_OFF_FLAG        VARCHAR2(1 BYTE),
  CLAIM_REASON          VARCHAR2(80 BYTE),
  CLAIM_TYPE            VARCHAR2(120 BYTE),
  CLAIM_OWNER           VARCHAR2(120 BYTE),
  CUSTOMER_REFERENCE    VARCHAR2(100 BYTE),
  GL_DATE               DATE,
  CUSTOMER_REASON       VARCHAR2(30 BYTE),
  PAYMENT_METHOD        VARCHAR2(30 BYTE),
  CLAIM_STATUS          VARCHAR2(30 BYTE),
  RECORD_STATUS         VARCHAR2(1 BYTE),
  ERROR_MESSAGE         VARCHAR2(4000 BYTE),
  CREATION_DATE         DATE,
  CREATED_BY            NUMBER,
  LAST_UPDATE_DATE      DATE,
  LAST_UPDATED_BY       NUMBER,
  LAST_UPDATE_LOGIN     NUMBER,
  REQUEST_ID            NUMBER,
  ORG_ID                NUMBER,
  CLAIM_ID              NUMBER,
  CLAIM_REASON_CODE_ID  NUMBER,
  CLAIM_TYPE_ID         NUMBER,
  CLAIM_OWNER_ID        NUMBER
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


ALTER TABLE XXDO.XXD_OZF_CLAIMS_UPDATE_STG_T ADD (
  PRIMARY KEY
  (RECORD_ID)
  USING INDEX
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
  ENABLE VALIDATE)
/


--  There is no statement for index XXDO.SYS_C006484746.
--  The object is created when the parent object is created.
