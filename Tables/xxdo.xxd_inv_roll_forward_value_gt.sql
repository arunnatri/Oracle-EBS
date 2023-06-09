--
-- XXD_INV_ROLL_FORWARD_VALUE_GT  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXD_INV_ROLL_FORWARD_VALUE_GT
(
  BRAND              VARCHAR2(40 BYTE),
  STYLE              VARCHAR2(45 BYTE),
  COLOR              VARCHAR2(100 BYTE),
  ITEM               VARCHAR2(40 BYTE),
  INVENTORY_ITEM_ID  NUMBER,
  ORGANIZATION_ID    NUMBER,
  ITEM_TYPE          VARCHAR2(25 BYTE),
  INIT_TARGET_QTY    NUMBER,
  END_TARGET_QTY     NUMBER,
  INIT_COST_TAB      NUMBER,
  END_COST_TAB       NUMBER,
  INIT_VALUE         NUMBER,
  END_VALUE          NUMBER,
  PO_IR_VALUE        NUMBER,
  PO_IR_QTY          NUMBER,
  SOI_VALUE          NUMBER,
  SOI_QTY            NUMBER,
  RMA_VALUE          NUMBER,
  RMA_QTY            NUMBER,
  AAI_VALUE          NUMBER,
  AAI_QTY            NUMBER,
  SUBINV_VALUE       NUMBER,
  SUBINV_QTY         NUMBER,
  AVRG_COST_VALUE    NUMBER,
  AVRG_COST_QTY      NUMBER,
  INT_SHIP_VALUE     NUMBER,
  INT_SHIP_QTY       NUMBER,
  OTHER_VAL          NUMBER,
  OTHER_QTY          NUMBER
)
ON COMMIT PRESERVE ROWS
NOCACHE
/
