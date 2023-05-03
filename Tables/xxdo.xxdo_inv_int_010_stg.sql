--
-- XXDO_INV_INT_010_STG  (Table) 
--
CREATE TABLE XXDO.XXDO_INV_INT_010_STG
(
  SCHEDULE_NBR           NUMBER,
  APPT_NBR               NUMBER,
  DC_DEST_ID             VARCHAR2(210 BYTE),
  PO_NBR                 VARCHAR2(210 BYTE),
  DOCUMENT_TYPE          VARCHAR2(21 BYTE),
  REF_DOC_NO             NUMBER,
  ASN_NBR                VARCHAR2(230 BYTE),
  RECEIPT_TYPE           VARCHAR2(22 BYTE),
  FROM_LOC               VARCHAR2(210 BYTE),
  FROM_LOC_TYPE          VARCHAR2(21 BYTE),
  ITEM_ID                VARCHAR2(225 BYTE),
  UNIT_QTY               NUMBER(12,4),
  RECEIPT_XACTN_TYPE     VARCHAR2(21 BYTE),
  RECEIPT_DATE           VARCHAR2(100 BYTE),
  RECEIPT_NBR            VARCHAR2(217 BYTE),
  DEST_ID                VARCHAR2(210 BYTE),
  CONTAINER_ID           VARCHAR2(220 BYTE),
  DISTRO_NBR             VARCHAR2(210 BYTE),
  DISTRO_DOC_TYPE        VARCHAR2(21 BYTE),
  TO_DISPOSITION         VARCHAR2(24 BYTE),
  FROM_DISPOSITION       VARCHAR2(24 BYTE),
  TO_WIP                 VARCHAR2(26 BYTE),
  FROM_WIP               VARCHAR2(26 BYTE),
  TO_TROUBLE             VARCHAR2(22 BYTE),
  FROM_TROUBLE           VARCHAR2(22 BYTE),
  USER_ID                VARCHAR2(230 BYTE),
  DUMMY_CARTON_IND       VARCHAR2(21 BYTE),
  TAMPERED_CARTON_IND    VARCHAR2(21 BYTE),
  UNIT_COST              NUMBER(20,4),
  SHIPPED_QTY            NUMBER(12,4),
  WEIGHT                 NUMBER(12,4),
  WEIGHT_UOM             VARCHAR2(24 BYTE),
  GROSS_COST             NUMBER(20,4),
  CARTON_STATUS_IND      VARCHAR2(21 BYTE),
  SEQ_NO                 NUMBER,
  PROCESSED_FLAG         VARCHAR2(240 BYTE),
  TRANSMISSION_DATE      DATE,
  ERRORCODE              VARCHAR2(240 BYTE),
  XMLDATA                CLOB,
  RETVAL                 CLOB,
  CREATION_DATE          DATE,
  STATUS                 VARCHAR2(100 BYTE),
  ATR_TRANSMISSION_FLAG  VARCHAR2(10 BYTE)
)
LOB (RETVAL) STORE AS BASICFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING
  STORAGE    (
              INITIAL          64K
              NEXT             1M
              MINEXTENTS       1
              MAXEXTENTS       UNLIMITED
              PCTINCREASE      0
              BUFFER_POOL      DEFAULT
             ))
LOB (XMLDATA) STORE AS BASICFILE (
  TABLESPACE  CUSTOM_TX_TS
  ENABLE      STORAGE IN ROW
  CHUNK       8192
  RETENTION
  NOCACHE
  LOGGING
  STORAGE    (
              INITIAL          64K
              NEXT             1M
              MINEXTENTS       1
              MAXEXTENTS       UNLIMITED
              PCTINCREASE      0
              BUFFER_POOL      DEFAULT
             ))
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
-- XXDO_INV_INT_010_STG  (Synonym) 
--
--  Dependencies: 
--   XXDO_INV_INT_010_STG (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXDO_INV_INT_010_STG FOR XXDO.XXDO_INV_INT_010_STG
/
