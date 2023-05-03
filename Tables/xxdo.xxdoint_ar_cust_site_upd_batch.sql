--
-- XXDOINT_AR_CUST_SITE_UPD_BATCH  (Table) 
--
CREATE TABLE XXDO.XXDOINT_AR_CUST_SITE_UPD_BATCH
(
  BATCH_ID           NUMBER                     NOT NULL,
  SITE_USE_ID        NUMBER                     NOT NULL,
  ORG_ID             NUMBER                     NOT NULL,
  BATCH_DATE         DATE                       DEFAULT sysdate,
  STATUS             VARCHAR2(50 BYTE),
  RESPONSE_MESSAGE   VARCHAR2(4000 BYTE),
  LAST_UPDATED_DATE  DATE,
  LAST_UPDATE_BY     VARCHAR2(10 BYTE)
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
-- XXDOINT_AR_SITE_UPD_BATCH_N1  (Index) 
--
--  Dependencies: 
--   XXDOINT_AR_CUST_SITE_UPD_BATCH (Table)
--
CREATE INDEX XXDO.XXDOINT_AR_SITE_UPD_BATCH_N1 ON XXDO.XXDOINT_AR_CUST_SITE_UPD_BATCH
(BATCH_DATE)
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
-- XXDOINT_AR_SITE_UPD_BATCH_N2  (Index) 
--
--  Dependencies: 
--   XXDOINT_AR_CUST_SITE_UPD_BATCH (Table)
--
CREATE INDEX XXDO.XXDOINT_AR_SITE_UPD_BATCH_N2 ON XXDO.XXDOINT_AR_CUST_SITE_UPD_BATCH
(BATCH_ID, SITE_USE_ID)
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
