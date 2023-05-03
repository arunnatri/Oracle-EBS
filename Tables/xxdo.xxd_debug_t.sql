--
-- XXD_DEBUG_T  (Table) 
--
CREATE TABLE XXDO.XXD_DEBUG_T
(
  DEBUG_ID              NUMBER(30)              NOT NULL,
  DEBUG_DATE            DATE                    DEFAULT sysdate               NOT NULL,
  MS_ELAPSED            NUMBER                  NOT NULL,
  ORIGIN                VARCHAR2(64 BYTE)       NOT NULL,
  OBJECT_NAME           VARCHAR2(128 BYTE)      NOT NULL,
  OBJECT_LINE           NUMBER(10)              NOT NULL,
  MESSAGE               VARCHAR2(2000 BYTE),
  ATTRIBUTE_01          VARCHAR2(64 BYTE),
  ATTRIBUTE_02          VARCHAR2(64 BYTE),
  ATTRIBUTE_03          VARCHAR2(64 BYTE),
  ATTRIBUTE_04          VARCHAR2(64 BYTE),
  ATTRIBUTE_05          VARCHAR2(64 BYTE),
  ATTRIBUTE_06          VARCHAR2(64 BYTE),
  ATTRIBUTE_07          VARCHAR2(64 BYTE),
  ATTRIBUTE_08          VARCHAR2(64 BYTE),
  ATTRIBUTE_09          VARCHAR2(64 BYTE),
  ATTRIBUTE_10          VARCHAR2(64 BYTE),
  ATTRIBUTE_11          VARCHAR2(64 BYTE),
  ATTRIBUTE_12          VARCHAR2(64 BYTE),
  ATTRIBUTE_13          VARCHAR2(64 BYTE),
  ATTRIBUTE_14          VARCHAR2(64 BYTE),
  ATTRIBUTE_15          VARCHAR2(64 BYTE),
  ATTRIBUTE_16          VARCHAR2(64 BYTE),
  ATTRIBUTE_17          VARCHAR2(64 BYTE),
  ATTRIBUTE_18          VARCHAR2(64 BYTE),
  ATTRIBUTE_19          VARCHAR2(64 BYTE),
  ATTRIBUTE_20          VARCHAR2(64 BYTE),
  LOG_LEVEL             NUMBER(10)              NOT NULL,
  DEBUG_TIMESTAMP       TIMESTAMP(6)            DEFAULT systimestamp          NOT NULL,
  MESSAGE_MS            NUMBER                  NOT NULL,
  CALL_STACK            VARCHAR2(2000 BYTE),
  INSTANCE_NAME         VARCHAR2(16 BYTE)       NOT NULL,
  HOST_NAME             VARCHAR2(64 BYTE)       NOT NULL,
  USERNAME              VARCHAR2(30 BYTE)       NOT NULL,
  MACHINE               VARCHAR2(64 BYTE)       NOT NULL,
  OSUSER                VARCHAR2(30 BYTE)       NOT NULL,
  PROCESS               VARCHAR2(24 BYTE)       NOT NULL,
  SID                   NUMBER                  NOT NULL,
  SERIAL#               NUMBER                  NOT NULL,
  AUDSID                NUMBER                  NOT NULL,
  REQUEST_ID            NUMBER,
  REMOTE_INSTANCE_NAME  VARCHAR2(16 BYTE),
  REMOTE_HOST_NAME      VARCHAR2(64 BYTE),
  REMOTE_USERNAME       VARCHAR2(30 BYTE),
  REMOTE_MACHINE        VARCHAR2(64 BYTE),
  REMOTE_OSUSER         VARCHAR2(30 BYTE),
  REMOTE_PROCESS        VARCHAR2(24 BYTE),
  REMOTE_SID            NUMBER,
  REMOTE_SERIAL#        NUMBER,
  REMOTE_AUDSID         NUMBER,
  MOD_DEBUG_DATE        NUMBER(2)
)
NOCOMPRESS 
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            BUFFER_POOL      DEFAULT
           )
PARTITION BY LIST (MOD_DEBUG_DATE)
(  
  PARTITION RECORDS_00 VALUES (0)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_01 VALUES (1)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_02 VALUES (2)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_03 VALUES (3)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_04 VALUES (4)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_05 VALUES (5)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_06 VALUES (6)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_07 VALUES (7)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_08 VALUES (8)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_09 VALUES (9)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_10 VALUES (10)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_11 VALUES (11)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_12 VALUES (12)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_13 VALUES (13)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_14 VALUES (14)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_15 VALUES (15)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_16 VALUES (16)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_17 VALUES (17)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_18 VALUES (18)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_19 VALUES (19)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_20 VALUES (20)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_21 VALUES (21)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_22 VALUES (22)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_23 VALUES (23)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_24 VALUES (24)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_25 VALUES (25)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_26 VALUES (26)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_27 VALUES (27)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_28 VALUES (28)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_29 VALUES (29)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                INITIAL          128K
                NEXT             128K
                MINEXTENTS       1
                MAXEXTENTS       UNLIMITED
                PCTINCREASE      0
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION RECORDS_30 VALUES (30)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                BUFFER_POOL      DEFAULT
               ),  
  PARTITION OTHER_RECORDS VALUES (DEFAULT)
    LOGGING
    NOCOMPRESS 
    TABLESPACE APPS_TS_TX_DATA
    PCTFREE    10
    INITRANS   1
    MAXTRANS   255
    STORAGE    (
                BUFFER_POOL      DEFAULT
               )
)
NOCACHE
/
