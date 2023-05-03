--
-- XXD_GL_ARCHIVE_BATCHES  (Table) 
--
CREATE TABLE XXDO.XXD_GL_ARCHIVE_BATCHES
(
  JE_BATCH_ID                 NUMBER(15)        NOT NULL,
  LAST_UPDATE_DATE            DATE              NOT NULL,
  LAST_UPDATED_BY             NUMBER(15)        NOT NULL,
  NAME                        VARCHAR2(100 BYTE) NOT NULL,
  STATUS                      VARCHAR2(1 BYTE)  NOT NULL,
  STATUS_VERIFIED             VARCHAR2(1 BYTE)  NOT NULL,
  ACTUAL_FLAG                 VARCHAR2(1 BYTE)  NOT NULL,
  DEFAULT_EFFECTIVE_DATE      DATE              NOT NULL,
  BUDGETARY_CONTROL_STATUS    VARCHAR2(1 BYTE)  NOT NULL,
  CREATION_DATE               DATE,
  CREATED_BY                  NUMBER(15),
  LAST_UPDATE_LOGIN           NUMBER(15),
  STATUS_RESET_FLAG           VARCHAR2(1 BYTE),
  DEFAULT_PERIOD_NAME         VARCHAR2(15 BYTE),
  UNIQUE_DATE                 VARCHAR2(30 BYTE),
  EARLIEST_POSTABLE_DATE      DATE,
  POSTED_DATE                 DATE,
  DATE_CREATED                DATE,
  DESCRIPTION                 VARCHAR2(240 BYTE),
  CONTROL_TOTAL               NUMBER,
  RUNNING_TOTAL_DR            NUMBER,
  RUNNING_TOTAL_CR            NUMBER,
  RUNNING_TOTAL_ACCOUNTED_DR  NUMBER,
  RUNNING_TOTAL_ACCOUNTED_CR  NUMBER,
  ATTRIBUTE1                  VARCHAR2(150 BYTE),
  ATTRIBUTE2                  VARCHAR2(150 BYTE),
  ATTRIBUTE3                  VARCHAR2(150 BYTE),
  ATTRIBUTE4                  VARCHAR2(150 BYTE),
  ATTRIBUTE5                  VARCHAR2(150 BYTE),
  ATTRIBUTE6                  VARCHAR2(150 BYTE),
  ATTRIBUTE7                  VARCHAR2(150 BYTE),
  ATTRIBUTE8                  VARCHAR2(150 BYTE),
  ATTRIBUTE9                  VARCHAR2(150 BYTE),
  ATTRIBUTE10                 VARCHAR2(150 BYTE),
  CONTEXT                     VARCHAR2(150 BYTE),
  PACKET_ID                   NUMBER(15),
  USSGL_TRANSACTION_CODE      VARCHAR2(30 BYTE),
  CONTEXT2                    VARCHAR2(150 BYTE),
  POSTING_RUN_ID              NUMBER(15),
  REQUEST_ID                  NUMBER(15),
  UNRESERVATION_PACKET_ID     NUMBER(15),
  AVERAGE_JOURNAL_FLAG        VARCHAR2(1 BYTE)  NOT NULL,
  ORG_ID                      NUMBER(15),
  POSTED_BY                   NUMBER(15),
  APPROVAL_STATUS_CODE        VARCHAR2(1 BYTE)  NOT NULL,
  PARENT_JE_BATCH_ID          NUMBER(15),
  CHART_OF_ACCOUNTS_ID        NUMBER(15)        NOT NULL,
  PERIOD_SET_NAME             VARCHAR2(15 BYTE) NOT NULL,
  ACCOUNTED_PERIOD_TYPE       VARCHAR2(15 BYTE) NOT NULL,
  GROUP_ID                    NUMBER,
  APPROVER_EMPLOYEE_ID        NUMBER(15),
  GLOBAL_ATTRIBUTE_CATEGORY   VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE1           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE2           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE3           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE4           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE5           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE6           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE7           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE8           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE9           VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE10          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE11          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE12          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE13          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE14          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE15          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE16          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE17          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE18          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE19          VARCHAR2(150 BYTE),
  GLOBAL_ATTRIBUTE20          VARCHAR2(150 BYTE)
)
TABLESPACE APPS_TS_TX_DATA
PCTUSED    0
PCTFREE    1
INITRANS   1
MAXTRANS   255
STORAGE    (
            INITIAL          1000K
            NEXT             1000K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
COMPRESS FOR QUERY HIGH
NOCACHE
/


--
-- XXD_GL_ARCHIVE_BATCHES_N1  (Index) 
--
--  Dependencies: 
--   XXD_GL_ARCHIVE_BATCHES (Table)
--
CREATE INDEX XXDO.XXD_GL_ARCHIVE_BATCHES_N1 ON XXDO.XXD_GL_ARCHIVE_BATCHES
(STATUS)
LOGGING
TABLESPACE APPS_TS_TX_IDX
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_GL_ARCHIVE_BATCHES_U1  (Index) 
--
--  Dependencies: 
--   XXD_GL_ARCHIVE_BATCHES (Table)
--
CREATE INDEX XXDO.XXD_GL_ARCHIVE_BATCHES_U1 ON XXDO.XXD_GL_ARCHIVE_BATCHES
(JE_BATCH_ID)
LOGGING
TABLESPACE APPS_TS_TX_IDX
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_GL_ARCHIVE_BATCHES_U2  (Index) 
--
--  Dependencies: 
--   XXD_GL_ARCHIVE_BATCHES (Table)
--
CREATE INDEX XXDO.XXD_GL_ARCHIVE_BATCHES_U2 ON XXDO.XXD_GL_ARCHIVE_BATCHES
(NAME, DEFAULT_PERIOD_NAME, CHART_OF_ACCOUNTS_ID, PERIOD_SET_NAME, ACCOUNTED_PERIOD_TYPE)
LOGGING
TABLESPACE APPS_TS_TX_IDX
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_GL_ARCHIVE_BATCHES  (Synonym) 
--
--  Dependencies: 
--   XXD_GL_ARCHIVE_BATCHES (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_GL_ARCHIVE_BATCHES FOR XXDO.XXD_GL_ARCHIVE_BATCHES
/


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXD_GL_ARCHIVE_BATCHES TO APPS WITH GRANT OPTION
/