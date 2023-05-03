--
-- XXD_FACTORY_FINISH_DATE_T  (Table) 
--
CREATE TABLE XXDO.XXD_FACTORY_FINISH_DATE_T
(
  SEQ_NO                    NUMBER,
  PO_NO                     VARCHAR2(20 BYTE)   NOT NULL,
  STYLE_NO                  VARCHAR2(150 BYTE)  NOT NULL,
  SHIP_TO_LOC_ID            NUMBER              NOT NULL,
  COLOR                     VARCHAR2(150 BYTE)  NOT NULL,
  BRAND                     VARCHAR2(150 BYTE),
  STYLE_NAME                VARCHAR2(150 BYTE),
  BUY_SEASON                VARCHAR2(150 BYTE),
  BUY_MONTH                 VARCHAR2(150 BYTE),
  FACTORY                   VARCHAR2(150 BYTE),
  QUANTITY                  NUMBER,
  XFCFM                     DATE,
  REQUESTED_EXFACTORY_DATE  DATE                NOT NULL,
  FACTORY_FINISH_DATE       DATE,
  DESTINATION               VARCHAR2(150 BYTE),
  SHIPPING_WAY              VARCHAR2(150 BYTE),
  AIR_QTY_PAIDBY_FACTORY    VARCHAR2(150 BYTE),
  AIR_QTY_PAIDBY_DECKERS    VARCHAR2(150 BYTE),
  SI_RECEIVING_DATE         DATE,
  ACTUAL_SHIPPING_DATE      DATE,
  REMARK1                   VARCHAR2(150 BYTE),
  REMARK2                   VARCHAR2(150 BYTE),
  REMARK3                   VARCHAR2(150 BYTE),
  CREATION_DATE             DATE                NOT NULL,
  CREATED_BY                NUMBER              NOT NULL,
  LAST_UPDATED_BY           NUMBER              NOT NULL,
  LAST_UPDATE_DATE          DATE                NOT NULL,
  LAST_UPDATE_LOGIN         NUMBER,
  STATUS                    VARCHAR2(1 BYTE),
  ERROR_MESSAGE             VARCHAR2(3000 BYTE),
  REQUEST_ID                NUMBER,
  FILE_NAME                 VARCHAR2(240 BYTE)
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
-- SEQ_NO_UN1  (Index) 
--
--  Dependencies: 
--   XXD_FACTORY_FINISH_DATE_T (Table)
--
CREATE UNIQUE INDEX XXDO.SEQ_NO_UN1 ON XXDO.XXD_FACTORY_FINISH_DATE_T
(SEQ_NO)
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

ALTER TABLE XXDO.XXD_FACTORY_FINISH_DATE_T ADD (
  CONSTRAINT SEQ_NO_UN1
  UNIQUE (SEQ_NO)
  USING INDEX XXDO.SEQ_NO_UN1
  ENABLE VALIDATE)
/


--
-- XXD_FACTORY_FINISH_DATE_T  (Synonym) 
--
--  Dependencies: 
--   XXD_FACTORY_FINISH_DATE_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_FACTORY_FINISH_DATE_T FOR XXDO.XXD_FACTORY_FINISH_DATE_T
/
