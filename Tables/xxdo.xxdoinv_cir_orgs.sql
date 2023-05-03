--
-- XXDOINV_CIR_ORGS  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXDOINV_CIR_ORGS
(
  ORGANIZATION_ID      NUMBER                   NOT NULL,
  IS_MASTER_ORG_ID     NUMBER,
  PRIMARY_COST_METHOD  NUMBER                   NOT NULL
)
ON COMMIT PRESERVE ROWS
NOCACHE
/


--
-- XXDOINV_CIR_ORGS_PK  (Index) 
--
--  Dependencies: 
--   XXDOINV_CIR_ORGS (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOINV_CIR_ORGS_PK ON XXDO.XXDOINV_CIR_ORGS
(ORGANIZATION_ID)
/
--
-- XXDOINV_CIR_ORGS_U1  (Index) 
--
--  Dependencies: 
--   XXDOINV_CIR_ORGS (Table)
--
CREATE UNIQUE INDEX XXDO.XXDOINV_CIR_ORGS_U1 ON XXDO.XXDOINV_CIR_ORGS
(IS_MASTER_ORG_ID)
/

ALTER TABLE XXDO.XXDOINV_CIR_ORGS ADD (
  CONSTRAINT XXDOINV_CIR_ORGS_PK
  PRIMARY KEY
  (ORGANIZATION_ID)
  USING INDEX XXDO.XXDOINV_CIR_ORGS_PK
  ENABLE VALIDATE)
/
