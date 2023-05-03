--
-- XXDO_ATP_INTEGRATION_SCRIPTS  (Table) 
--
CREATE TABLE XXDO.XXDO_ATP_INTEGRATION_SCRIPTS
(
  SCRIPT_ID        NUMBER,
  PROCESS_NUMBER   NUMBER,
  APPLICATION      VARCHAR2(240 BYTE),
  STEP_NUMBER      NUMBER                       DEFAULT 1,
  ENABLED          NUMBER                       DEFAULT 0,
  CREATED_BY       NUMBER                       DEFAULT 1037,
  CREATION_DATE    DATE                         DEFAULT SYSDATE,
  LAST_UPDATED_BY  NUMBER                       DEFAULT 1037,
  LAST_UPADE_DATE  DATE                         DEFAULT SYSDATE,
  DESCRIPTION      VARCHAR2(240 BYTE),
  SCRIPT           LONG
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
-- XXDO_ATP_INT_SCRIPTS_U1  (Index) 
--
--  Dependencies: 
--   XXDO_ATP_INTEGRATION_SCRIPTS (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_ATP_INT_SCRIPTS_U1 ON XXDO.XXDO_ATP_INTEGRATION_SCRIPTS
(SCRIPT_ID)
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
-- XXDO_ATP_INT_SCRIPTS_U2  (Index) 
--
--  Dependencies: 
--   XXDO_ATP_INTEGRATION_SCRIPTS (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_ATP_INT_SCRIPTS_U2 ON XXDO.XXDO_ATP_INTEGRATION_SCRIPTS
(PROCESS_NUMBER, STEP_NUMBER)
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
-- XXDO_ATP_INT_SCRIPTS_I1  (Trigger) 
--
--  Dependencies: 
--   XXDO_ATP_INTEGRATION_SCRIPTS (Table)
--
CREATE OR REPLACE TRIGGER XXDO.XXDO_ATP_INT_SCRIPTS_I1
   BEFORE INSERT
   ON xxdo.xxdo_atp_integration_scripts
   REFERENCING OLD AS old NEW AS new
   FOR EACH ROW
BEGIN
   SELECT xxdo.xxdo_atp_integration_scripts_s.NEXTVAL
     INTO :new.script_id
     FROM DUAL;
END;
/
