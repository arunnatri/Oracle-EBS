--
-- XXD_GL_ARCHIVE_HISTORY  (Table) 
--
CREATE TABLE XXDO.XXD_GL_ARCHIVE_HISTORY
(
  LEDGER_ID                     NUMBER(15)      NOT NULL,
  FISCAL_YEAR                   NUMBER(15)      NOT NULL,
  LAST_UPDATE_DATE              DATE            NOT NULL,
  LAST_UPDATED_BY               NUMBER(15)      NOT NULL,
  DATA_TYPE                     VARCHAR2(1 BYTE) NOT NULL,
  BUDGET_VERSION_ID             NUMBER(15),
  LAST_ARCHIVED_EFF_PERIOD_NUM  NUMBER(15)      NOT NULL,
  LAST_PURGED_EFF_PERIOD_NUM    NUMBER(15)      NOT NULL,
  ACTUAL_FLAG                   VARCHAR2(1 BYTE) NOT NULL,
  STATUS                        VARCHAR2(1 BYTE),
  ARCHIVE_DATE                  DATE,
  ARCHIVED_BY                   NUMBER(15),
  TOTAL_RECORDS_ARCHIVED        NUMBER(15),
  PURGE_DATE                    DATE,
  PURGED_BY                     NUMBER(15),
  TOTAL_RECORDS_PURGED          NUMBER(15),
  TOTAL_HEADERS_PURGED          NUMBER(15),
  TOTAL_LINES_PURGED            NUMBER(15),
  TOTAL_REFERENCES_PURGED       NUMBER(15),
  MAX_JE_HEADER_ID              NUMBER(15)
)
TABLESPACE APPS_TS_TX_DATA
PCTUSED    0
PCTFREE    10
INITRANS   10
MAXTRANS   255
STORAGE    (
            INITIAL          128K
            NEXT             128K
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
-- XXD_GL_ARCHIVE_HISTORY_U1  (Index) 
--
--  Dependencies: 
--   XXD_GL_ARCHIVE_HISTORY (Table)
--
CREATE UNIQUE INDEX XXDO.XXD_GL_ARCHIVE_HISTORY_U1 ON XXDO.XXD_GL_ARCHIVE_HISTORY
(LEDGER_ID, DATA_TYPE, ACTUAL_FLAG, FISCAL_YEAR, BUDGET_VERSION_ID)
LOGGING
TABLESPACE APPS_TS_TX_IDX
PCTFREE    0
INITRANS   11
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

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON XXDO.XXD_GL_ARCHIVE_HISTORY TO APPS WITH GRANT OPTION
/

GRANT SELECT ON XXDO.XXD_GL_ARCHIVE_HISTORY TO APPSRO WITH GRANT OPTION
/

GRANT SELECT ON XXDO.XXD_GL_ARCHIVE_HISTORY TO DO_CUSTOM
/

GRANT SELECT ON XXDO.XXD_GL_ARCHIVE_HISTORY TO DO_IFACE
/
