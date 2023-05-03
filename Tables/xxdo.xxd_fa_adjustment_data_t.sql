--
-- XXD_FA_ADJUSTMENT_DATA_T  (Table) 
--
CREATE TABLE XXDO.XXD_FA_ADJUSTMENT_DATA_T
(
  ROW_NUM            NUMBER,
  ASSET_ID           NUMBER,
  BOOK_TYPE_CODE     VARCHAR2(50 BYTE),
  ADJ_START_DATE     DATE,
  ADJ_END_DATE       DATE,
  ADJ_START_PERIOD   VARCHAR2(20 BYTE),
  ADJ_END_PERIOD     VARCHAR2(20 BYTE),
  ADJ_START_COUNTER  NUMBER,
  ADJ_END_COUNTER    NUMBER,
  PER_MONTH_ACC      NUMBER,
  REQUEST_ID         NUMBER
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