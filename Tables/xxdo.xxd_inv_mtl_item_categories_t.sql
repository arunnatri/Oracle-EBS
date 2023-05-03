--
-- XXD_INV_MTL_ITEM_CATEGORIES_T  (Table) 
--
CREATE TABLE XXDO.XXD_INV_MTL_ITEM_CATEGORIES_T
(
  INVENTORY_ITEM_ID  NUMBER,
  ORGANIZATION_ID    NUMBER,
  CATEGORY_SET_ID    NUMBER,
  BATCH_DATE         DATE,
  BATCH_ID           NUMBER,
  BATCH_MOD_DATE     NUMBER(2)
)
NOCOMPRESS 
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            BUFFER_POOL      DEFAULT
           )
PARTITION BY LIST (BATCH_MOD_DATE)
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


--
-- XXD_INV_MTL_ITEM_CATEGORIES_N1  (Index) 
--
--  Dependencies: 
--   XXD_INV_MTL_ITEM_CATEGORIES_T (Table)
--
CREATE INDEX XXDO.XXD_INV_MTL_ITEM_CATEGORIES_N1 ON XXDO.XXD_INV_MTL_ITEM_CATEGORIES_T
(INVENTORY_ITEM_ID, ORGANIZATION_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_INV_MTL_ITM_CAT_DATE_N1  (Index) 
--
--  Dependencies: 
--   XXD_INV_MTL_ITEM_CATEGORIES_T (Table)
--
CREATE INDEX XXDO.XXD_INV_MTL_ITM_CAT_DATE_N1 ON XXDO.XXD_INV_MTL_ITEM_CATEGORIES_T
(BATCH_DATE)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXD_INV_MTL_ITEM_CATEGORIES_T  (Synonym) 
--
--  Dependencies: 
--   XXD_INV_MTL_ITEM_CATEGORIES_T (Table)
--
CREATE OR REPLACE SYNONYM APPS.XXD_INV_MTL_ITEM_CATEGORIES_T FOR XXDO.XXD_INV_MTL_ITEM_CATEGORIES_T
/
