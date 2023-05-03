--
-- XXD_PO_ASN_RECEIVING_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_ASN_RECEIVING_T
(
  RECORD_ID                  NUMBER,
  ORDER_TYPE                 VARCHAR2(30 BYTE),
  ORG_ID                     NUMBER,
  SHIPMENT_ID                NUMBER,
  FACTORY_INVOICE_NUMBER     VARCHAR2(20 BYTE),
  FACTORY_ASN_NUMBER         VARCHAR2(25 BYTE),
  CONTAINER_ID               NUMBER,
  FACTORY_CONTAINER_NUMBER   VARCHAR2(30 BYTE),
  PO_HEADER_ID               NUMBER,
  PO_NUMBER                  VARCHAR2(20 BYTE),
  PO_LINE_ID                 NUMBER,
  PO_LINE_NUMBER             NUMBER,
  PO_LINE_LOCATION_ID        NUMBER,
  PO_SHIPMENT_NUMBER         NUMBER,
  ORACLE_INBOUND_ASN_NUMBER  VARCHAR2(30 BYTE),
  PO_QUANTITY                NUMBER,
  QUANTITY_RECEIVED          NUMBER,
  SHIPMENT_LINE_STATUS_CODE  VARCHAR2(25 BYTE),
  RECEIVING_ORGANIZATION_ID  NUMBER,
  RECEIVING_SUB_INVENTORY    VARCHAR2(10 BYTE),
  RECORD_STATUS              VARCHAR2(20 BYTE),
  ERROR_MESSAGE              VARCHAR2(4000 BYTE),
  REQUEST_ID                 NUMBER,
  CREATED_BY                 NUMBER,
  CREATION_DATE              DATE,
  LAST_UPDATED_BY            NUMBER,
  LAST_UPDATE_DATE           DATE
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
-- XXD_PO_ASN_RECEIVING_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_ASN_RECEIVING_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_ASN_RECEIVING_T FOR XXDO.XXD_PO_ASN_RECEIVING_T
/