--
-- XXD_OE_CAN_LOYALTY_PNTS_ARC_T  (Table) 
--
CREATE TABLE XXDO.XXD_OE_CAN_LOYALTY_PNTS_ARC_T
(
  CREATED_AT                     VARCHAR2(100 BYTE),
  ACQ_BEGINING_BALANCE           VARCHAR2(100 BYTE),
  ACQ_EARNED                     VARCHAR2(100 BYTE),
  ACQ_EARNED_LOCAL_VALUE         VARCHAR2(100 BYTE),
  ACQ_REWARD                     VARCHAR2(100 BYTE),
  ACQ_REWARD_LOCAL_VALUE         VARCHAR2(100 BYTE),
  ACQ_EXPIRED                    VARCHAR2(100 BYTE),
  ACQ_EXPIRED_LOCAL_VALUE        VARCHAR2(100 BYTE),
  ACQ_RETURNED                   VARCHAR2(100 BYTE),
  ACQ_RETURNED_LOCAL_VALUE       VARCHAR2(100 BYTE),
  ACQ_ENDING_BALANCE             VARCHAR2(100 BYTE),
  ACQ_ENDING_BAL_LOCAL_VALUE     VARCHAR2(100 BYTE),
  ACQ_CONVERSION                 VARCHAR2(100 BYTE),
  ACQ_CONVERSION_LOCAL_VALUE     VARCHAR2(100 BYTE),
  PARTNER_ACQ_BEGIN_BAL          VARCHAR2(100 BYTE),
  PARTNER_ACQ_BEG_BAL_LOCAL_VAL  VARCHAR2(100 BYTE),
  PARTNER_ACQ_EARNED             VARCHAR2(100 BYTE),
  PARTNER_ACQ_EARNED_LOCAL_VAL   VARCHAR2(100 BYTE),
  PARTNER_ACQ_REWARD             VARCHAR2(100 BYTE),
  PARTNER_ACQ_REWARD_LOCAL_VAL   VARCHAR2(100 BYTE),
  PARTNER_ACQ_EXPIRED            VARCHAR2(100 BYTE),
  PARTNER_ACQ_EXPIRED_LOCAL_VAL  VARCHAR2(100 BYTE),
  PARTNER_ACQ_ENDING_BALANCE     VARCHAR2(100 BYTE),
  PARTNER_ACQ_END_BAL_LOCAL_VAL  VARCHAR2(100 BYTE),
  ENGAGEMENT_BEGINING_BALANCE    VARCHAR2(100 BYTE),
  ENGAGEMENT_BEG_BAL_LOCAL_VAL   VARCHAR2(100 BYTE),
  ENGAGEMENT_EARNED              VARCHAR2(100 BYTE),
  ENGAGEMENT_EARNED_LOCAL_VAL    VARCHAR2(100 BYTE),
  ENGAGEMENT_REWARD              VARCHAR2(100 BYTE),
  ENGAGEMENT_REWARD_LOCAL_VAL    VARCHAR2(100 BYTE),
  ENGAGEMENT_EXPIRED             VARCHAR2(100 BYTE),
  ENGAGEMENT_EXP_LOCAL_VAL       VARCHAR2(100 BYTE),
  ENGAGEMENT_RETURNED            VARCHAR2(100 BYTE),
  ENGAGEMENT_RETURN_LOCAL_VAL    VARCHAR2(100 BYTE),
  ENGAGEMENT_ADJUSTED            VARCHAR2(100 BYTE),
  ENGAGEMENT_ADJUST_LOCAL_VAL    VARCHAR2(100 BYTE),
  ENGAGEMENT_ENDING_BALANCE      VARCHAR2(100 BYTE),
  ENGAGEMENT_END_BAL_LOCAL_VAL   VARCHAR2(100 BYTE),
  ENGAGEMENT_CONVERSION          VARCHAR2(100 BYTE),
  ENGAGEMENT_CONV_LOCAL_VALUE    VARCHAR2(100 BYTE),
  OVERAGE_BEGINING_BALANCE       VARCHAR2(100 BYTE),
  OVERAGE_BEGIN_BAL_LOCAL_VAL    VARCHAR2(100 BYTE),
  OVERAGE_REWARD                 VARCHAR2(100 BYTE),
  OVERAGE_REWARD_LOCAL_VAL       VARCHAR2(100 BYTE),
  OVERAGE_EXPIRED                VARCHAR2(100 BYTE),
  OVERAGE_EXPIRED_LOCAL_VAL      VARCHAR2(100 BYTE),
  OVERAGE_ADJUSTED               VARCHAR2(100 BYTE),
  OVERAGE_ADJUSTED_LOCAL_VAL     VARCHAR2(100 BYTE),
  OVERAGE_ENDING_BALANCE         VARCHAR2(100 BYTE),
  OVERAGE_END_BAL_LOCAL_VAL      VARCHAR2(100 BYTE),
  TOTAL_DAY                      VARCHAR2(100 BYTE),
  TOTAL_DAY_LOCAL_VALUE          VARCHAR2(100 BYTE),
  TOTAL_ENDING_BALANCE           VARCHAR2(100 BYTE),
  TOTAL_ENDING_BAL_LOCAL_VAL     VARCHAR2(100 BYTE),
  FUTURE_FUTURE_ATTRIBUTE1       VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE2              VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE3              VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE4              VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE5              VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE6              VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE7              VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE8              VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE9              VARCHAR2(100 BYTE),
  FUTURE_ATTRIBUTE10             VARCHAR2(100 BYTE),
  ENTITY_UNIQUE_IDENTIFIER       VARCHAR2(10 BYTE),
  ACCOUNT                        VARCHAR2(10 BYTE),
  KEY3                           VARCHAR2(10 BYTE),
  KEY                            VARCHAR2(10 BYTE),
  KEY5                           VARCHAR2(10 BYTE),
  KEY6                           VARCHAR2(10 BYTE),
  KEY7                           VARCHAR2(10 BYTE),
  KEY8                           VARCHAR2(10 BYTE),
  KEY9                           VARCHAR2(10 BYTE),
  KEY10                          VARCHAR2(10 BYTE),
  PERIOD_END_DATE                VARCHAR2(20 BYTE),
  SUBLEDGER_REP_BAL              VARCHAR2(100 BYTE),
  SUBLEDGER_ALT_BAL              VARCHAR2(100 BYTE),
  SUBLEDGER_ACC_BAL              VARCHAR2(100 BYTE),
  CREATED_BY                     VARCHAR2(100 BYTE),
  CREATION_DATE                  DATE,
  LAST_UPDATED_BY                VARCHAR2(100 BYTE),
  LAST_UPDATE_DATE               DATE,
  REQUEST_ID                     VARCHAR2(100 BYTE),
  FILE_NAME                      VARCHAR2(100 BYTE),
  ORG_ID                         NUMBER
)
TABLESPACE CUSTOM_TX_TS
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
/


--
-- XXD_OE_CAN_LOYALTY_PNTS_ARC_T  (Synonym) 
--
--  Dependencies: 
--   XXD_OE_CAN_LOYALTY_PNTS_ARC_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_OE_CAN_LOYALTY_PNTS_ARC_T FOR XXDO.XXD_OE_CAN_LOYALTY_PNTS_ARC_T
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_OE_CAN_LOYALTY_PNTS_ARC_T TO APPS
/
