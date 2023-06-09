--
-- XXD_ONT_CONSUMPTION_GT  (Table) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XXD_ONT_ORD_LINE_OBJ (Type)
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXD_ONT_CONSUMPTION_GT
(
  IDX                NUMBER,
  OPERATION          VARCHAR2(40 BYTE),
  PR_NEW_OBJ         XXD_NE.XXD_ONT_ORD_LINE_OBJ,
  PR_OLD_OBJ         XXD_NE.XXD_ONT_ORD_LINE_OBJ,
  LINE_ID            NUMBER,
  INVENTORY_ITEM_ID  NUMBER
)
COLUMN PR_NEW_OBJ NOT SUBSTITUTABLE AT ALL LEVELS
COLUMN PR_OLD_OBJ NOT SUBSTITUTABLE AT ALL LEVELS
ON COMMIT DELETE ROWS
NOCACHE
/
