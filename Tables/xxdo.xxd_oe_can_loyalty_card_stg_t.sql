--
-- XXD_OE_CAN_LOYALTY_CARD_STG_T  (Table) 
--
CREATE TABLE XXDO.XXD_OE_CAN_LOYALTY_CARD_STG_T
(
  DATE_AT                      VARCHAR2(30 BYTE),
  REWARD_ID                    VARCHAR2(100 BYTE),
  COST                         VARCHAR2(100 BYTE),
  STRATING_BALANCE             VARCHAR2(100 BYTE),
  ISSUED                       VARCHAR2(100 BYTE),
  REWARD_ISSUED_LOCAL_VALUE    VARCHAR2(100 BYTE),
  REDEEMED                     VARCHAR2(100 BYTE),
  REWARD_REDEEMED_LOCAL_VALUE  VARCHAR2(100 BYTE),
  EXPIRED                      VARCHAR2(100 BYTE),
  REWARD_EXPIRED_LOCAL_VALUE   VARCHAR2(100 BYTE),
  INVALIDATED                  VARCHAR2(100 BYTE),
  REWARD_INVALID_LOCAL_VAL     VARCHAR2(100 BYTE),
  REISSUED                     VARCHAR2(100 BYTE),
  REWARD_REISSUED_LOCAL_VALUE  VARCHAR2(100 BYTE),
  ENDING_BALANCE               VARCHAR2(100 BYTE),
  REWARD_ENDING_BAL_LOCAL_VAL  VARCHAR2(100 BYTE),
  CREATED_BY                   NUMBER,
  CREATION_DATE                DATE,
  LAST_UPDATED_BY              NUMBER,
  LAST_UPDATE_DATE             DATE,
  REQUEST_ID                   NUMBER,
  FILE_NAME                    VARCHAR2(100 BYTE)
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
-- XXD_OE_CAN_LOYALTY_CARD_STG_T  (Synonym) 
--
--  Dependencies: 
--   XXD_OE_CAN_LOYALTY_CARD_STG_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_OE_CAN_LOYALTY_CARD_STG_T FOR XXDO.XXD_OE_CAN_LOYALTY_CARD_STG_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_OE_CAN_LOYALTY_CARD_STG_T TO APPS
/
