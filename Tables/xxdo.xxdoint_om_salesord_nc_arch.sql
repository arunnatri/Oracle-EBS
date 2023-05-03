--
-- XXDOINT_OM_SALESORD_NC_ARCH  (Table) 
--
CREATE TABLE XXDO.XXDOINT_OM_SALESORD_NC_ARCH
(
  BATCH_ID    NUMBER                            NOT NULL,
  HEADER_ID   NUMBER                            NOT NULL,
  BATCH_DATE  DATE                              DEFAULT sysdate               NOT NULL,
  PROC_ID     NUMBER,
  ARCH_DATE   DATE                              DEFAULT sysdate               NOT NULL
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
