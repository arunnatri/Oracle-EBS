--
-- XXD_PPM_IP_USER_CURRENT_T  (Table) 
--
CREATE TABLE XXDO.XXD_PPM_IP_USER_CURRENT_T
(
  USER_NAME               VARCHAR2(10 BYTE)     NOT NULL,
  FULL_NAME               VARCHAR2(30 BYTE),
  PLAN_CODE               VARCHAR2(10 BYTE),
  VIEW_CODE               VARCHAR2(10 BYTE),
  LANGUAGE                VARCHAR2(8 BYTE),
  CUSTOM                  VARCHAR2(8 BYTE),
  USER_CLASS              VARCHAR2(8 BYTE),
  APP_GRANT               VARCHAR2(8 BYTE),
  CONNECTED               VARCHAR2(1 BYTE),
  BASELINE_CODE           VARCHAR2(10 BYTE),
  TMP_SCHEDULE            VARCHAR2(10 BYTE),
  USER_GROUP              VARCHAR2(10 BYTE),
  BATCH_GRANTED           VARCHAR2(1 BYTE),
  CREATE_CAL              VARCHAR2(1 BYTE),
  GRT_ALLO_RE             VARCHAR2(1 BYTE),
  GRT_ALLO_PE             VARCHAR2(1 BYTE),
  MOD_STRUCTURE           VARCHAR2(1 BYTE),
  UPD_TS                  VARCHAR2(1 BYTE),
  USER_PASSWORD           VARCHAR2(80 BYTE)     NOT NULL,
  PASSWORD_DATE           DATE,
  DISCONNECT_FLAG         VARCHAR2(3 BYTE),
  LOGIN_FLAG              VARCHAR2(3 BYTE),
  LOGIN_TIME              DATE,
  APPR_EXPENSE            VARCHAR2(1 BYTE),
  PHONE1                  VARCHAR2(25 BYTE),
  PHONE2                  VARCHAR2(25 BYTE),
  PAGER                   VARCHAR2(25 BYTE),
  E_MAIL                  VARCHAR2(85 BYTE),
  ROLE_CODE               VARCHAR2(10 BYTE),
  LAST_MODIFIED           DATE,
  OS_USER_NAME            VARCHAR2(512 BYTE),
  CRI_ESCALATE_TO         VARCHAR2(1 BYTE),
  PV_OUTLOOK              VARCHAR2(1 BYTE),
  TICKET                  NUMBER,
  COLOR                   VARCHAR2(20 BYTE),
  ADDED_DATE              DATE,
  ADDED_BY                VARCHAR2(10 BYTE),
  EXPIRATION_DATE         DATE,
  USER_COMMENT            VARCHAR2(80 BYTE),
  MUST_LOGIN_IND          VARCHAR2(1 BYTE),
  PASSWORD_EXPIRES        NUMBER,
  CURRENCY_CODE           VARCHAR2(10 BYTE),
  CUSTOMER_CODE           VARCHAR2(10 BYTE),
  MODIFIED_BY             VARCHAR2(10 BYTE),
  BAD_LOGIN_COUNT         NUMBER,
  SELF_REG_IND            VARCHAR2(1 BYTE),
  SR_IP_ADDRESS           VARCHAR2(40 BYTE),
  ACTIVE_IND              VARCHAR2(1 BYTE)      NOT NULL,
  IA_ACTIVE_DIR_USER      VARCHAR2(512 BYTE),
  RESET_PWD_IND           VARCHAR2(1 BYTE),
  DELETED_IND             VARCHAR2(1 BYTE),
  CTM_USER_NAME           VARCHAR2(255 BYTE),
  TIMED_INVITE_IND        VARCHAR2(1 BYTE),
  INVITE_EXPIRES_ON       DATE,
  INVITE_DURATION_HRS     NUMBER,
  INV_SESSION_EXPIRES_ON  DATE,
  DEPERSONALIZED_IND      VARCHAR2(1 BYTE)
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
