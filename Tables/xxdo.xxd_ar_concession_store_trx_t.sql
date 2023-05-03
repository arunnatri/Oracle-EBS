--
-- XXD_AR_CONCESSION_STORE_TRX_T  (Table) 
--
CREATE TABLE XXDO.XXD_AR_CONCESSION_STORE_TRX_T
(
  SEQUENCE_ID                 NUMBER,
  RMS_TRAN_SEQ_NO             NUMBER,
  TRANSACTION_DATE            DATE,
  STORE_NUMBER                NUMBER,
  BRAND                       VARCHAR2(30 BYTE),
  RETAIL_AMOUNT               NUMBER,
  DISCOUNT_AMOUNT             NUMBER,
  PAYTOTAL_AMOUNT             NUMBER,
  TAX_AMOUNT                  NUMBER,
  STATUS                      VARCHAR2(1 BYTE),
  CREATION_DATE               DATE,
  CREATED_BY                  NUMBER,
  LAST_UPDATE_DATE            DATE,
  LAST_UPDATED_BY             NUMBER,
  LAST_UPDATE_LOGIN           NUMBER,
  REQUEST_ID                  NUMBER,
  SALES_CR_AMOUNT             NUMBER,
  SALES_CR_MODE_PRC_FLAG      VARCHAR2(1 BYTE),
  SALES_CR_MODE_ERROR_MSG     VARCHAR2(2000 BYTE),
  ANCILLARY1_MODE_AMOUNT      NUMBER,
  ANCILLARY1_MODE_PRC_FLAG    VARCHAR2(1 BYTE),
  ANCILLARY1_ERROR_MSG        VARCHAR2(2000 BYTE),
  ANCILLARY2_MODE_AMOUNT      NUMBER,
  ANCILLARY2_MODE_PRC_FLAG    VARCHAR2(1 BYTE),
  ANCILLARY2_ERROR_MSG        VARCHAR2(2000 BYTE),
  SALES_CR_TRX_NUM            VARCHAR2(20 BYTE),
  SALES_CR_TRX_LINE_NUM       NUMBER,
  SALES_CR_TRX_CREATION_DATE  DATE,
  SALES_CR_TRX_CREATED_BY     NUMBER,
  SALES_CR_TRX_REQUEST_ID     NUMBER,
  ANCILLARY1_TRX_NUM          VARCHAR2(20 BYTE),
  ANCILLARY1_TRX_LINE_NUM     NUMBER,
  ANCILLARY1_CREATION_DATE    DATE,
  ANCILLARY1_CREATED_BY       NUMBER,
  ANCILLARY1_REQUEST_ID       NUMBER,
  ANCILLARY2_TRX_NUM          VARCHAR2(20 BYTE),
  ANCILLARY2_TRX_LINE_NUM     NUMBER,
  ANCILLARY2_CREATION_DATE    DATE,
  ANCILLARY2_CREATED_BY       NUMBER,
  ANCILLARY2_REQUEST_ID       NUMBER,
  REPROCESS_FLAG              VARCHAR2(1 BYTE)
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


ALTER TABLE XXDO.XXD_AR_CONCESSION_STORE_TRX_T ADD (
  PRIMARY KEY
  (SEQUENCE_ID)
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


--  There is no statement for index XXDO.SYS_C004642798.
--  The object is created when the parent object is created.

--
-- XXD_AR_CONCESSION_STORE_TRX_T  (Synonym) 
--
--  Dependencies: 
--   XXD_AR_CONCESSION_STORE_TRX_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_AR_CONCESSION_STORE_TRX_T FOR XXDO.XXD_AR_CONCESSION_STORE_TRX_T
/


--
-- XXD_AR_CONCESSION_STORE_TRX_T  (Synonym) 
--
--  Dependencies: 
--   XXD_AR_CONCESSION_STORE_TRX_T (Table)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_AR_CONCESSION_STORE_TRX_T FOR XXDO.XXD_AR_CONCESSION_STORE_TRX_T
/


GRANT INSERT, SELECT ON XXDO.XXD_AR_CONCESSION_STORE_TRX_T TO SOA_INT
/