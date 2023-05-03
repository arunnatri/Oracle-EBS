--
-- XXD_PO_DS_PR_UPD_T  (Table) 
--
CREATE TABLE XXDO.XXD_PO_DS_PR_UPD_T
(
  ORGANIZATION_CODE         VARCHAR2(20 BYTE),
  ORDER_NUMBER              VARCHAR2(20 BYTE),
  ORG_ID                    NUMBER,
  ORGANIZATION_ID           NUMBER,
  AUTOCREATE_PR_REQUEST_ID  NUMBER,
  INTERFACE_BATCH_ID        NUMBER,
  REQUISITION_NUMBER        VARCHAR2(20 BYTE),
  REQUEST_ID                NUMBER,
  STATUS                    VARCHAR2(1 BYTE),
  ERROR_MESSAGE             VARCHAR2(4000 BYTE),
  CREATED_BY                NUMBER,
  CREATION_DATE             DATE,
  LAST_UPDATED_BY           NUMBER,
  LAST_UPDATE_DATE          DATE,
  SEQ_NUM                   NUMBER
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
-- XXD_PO_DS_PR_UPD_T  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_DS_PR_UPD_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_PO_DS_PR_UPD_T FOR XXDO.XXD_PO_DS_PR_UPD_T
/
