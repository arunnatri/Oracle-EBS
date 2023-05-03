--
-- XXDO_WMS_3PL_ADJ_L  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_ADJ_L
(
  ADJ_HEADER_ID          NUMBER,
  ADJ_LINE_ID            NUMBER,
  MESSAGE_TYPE           VARCHAR2(10 BYTE)      DEFAULT 'LADJ',
  TRANSACTION_ID         VARCHAR2(20 BYTE)      NOT NULL,
  SKU_CODE               VARCHAR2(30 BYTE),
  QTY_CHANGE             VARCHAR2(15 BYTE)      NOT NULL,
  REASON_CODE            VARCHAR2(30 BYTE),
  COMMENTS               VARCHAR2(240 BYTE),
  ADJUSTED_BY            VARCHAR2(50 BYTE),
  LOCK_CODE              VARCHAR2(20 BYTE),
  CREATED_BY             NUMBER                 DEFAULT 0,
  CREATION_DATE          DATE                   DEFAULT sysdate,
  LAST_UPDATED_BY        NUMBER                 DEFAULT 0,
  LAST_UPDATE_DATE       DATE                   DEFAULT sysdate,
  INVENTORY_ITEM_ID      NUMBER                 DEFAULT null,
  QUANTITY_TO_ADJUST     NUMBER                 DEFAULT null,
  SUBINVENTORY_CODE      VARCHAR2(30 BYTE)      DEFAULT null,
  PROCESS_STATUS         VARCHAR2(1 BYTE)       DEFAULT 'P',
  PROCESSING_SESSION_ID  NUMBER                 DEFAULT null,
  ERROR_MESSAGE          VARCHAR2(240 BYTE)     DEFAULT null,
  ADJ_TYPE_CODE          VARCHAR2(100 BYTE),
  DUTY_PAID_FLAG         VARCHAR2(1 BYTE)
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
-- XXDO_WMS_3PL_ADJ_L_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_ADJ_L_U1 ON XXDO.XXDO_WMS_3PL_ADJ_L
(ADJ_LINE_ID)
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
-- XXDO_WMS_3PL_ADJ_L_U2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_ADJ_L_U2 ON XXDO.XXDO_WMS_3PL_ADJ_L
(ADJ_HEADER_ID, ADJ_LINE_ID)
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
-- XXDO_WMS_3PL_ADJ_L_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_ADJ_L_N1 ON XXDO.XXDO_WMS_3PL_ADJ_L
(ADJ_HEADER_ID, PROCESS_STATUS, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_ADJ_L_N2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_ADJ_L_N2 ON XXDO.XXDO_WMS_3PL_ADJ_L
(ADJ_HEADER_ID, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_ADJ_L_N3  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_ADJ_L_N3 ON XXDO.XXDO_WMS_3PL_ADJ_L
(INVENTORY_ITEM_ID)
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
-- XXDO_WMS_3PL_ADJ_L_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_L (Table)
--
CREATE OR REPLACE TRIGGER XXDO.XXDO_WMS_3PL_ADJ_L_T1 
before insert or update on xxdo.xxdo_wms_3pl_adj_l for each row
WHEN (
nvl(new.process_status, 'E') != 'A'
      )
declare
l_id number;
l_header xxdo.xxdo_wms_3pl_adj_h%rowtype;
begin
  :new.processing_session_id := nvl(:new.processing_session_id, userenv('SESSIONID'));
  if :new.adj_header_id is null then
    select xxdo.xxdo_wms_3pl_adj_h_s.currval into :new.adj_header_id from dual; 
  end if;
  if :new.adj_line_id is null then
    select xxdo.xxdo_wms_3pl_adj_l_s.nextval into :new.adj_line_id from dual; 
  end if;
  if nvl(:new.created_by, 0) = 0 then
    :new.created_by := nvl(apps.fnd_global.user_id, :new.created_by); 
  end if;
  if nvl(:new.last_updated_by, 0) = 0 then
    :new.last_updated_by := nvl(apps.fnd_global.user_id, :new.last_updated_by); 
  end if;
  begin
    select * into l_header from xxdo.xxdo_wms_3pl_adj_h where adj_header_id = :new.adj_header_id;
  exception
    when others then 
      :new.error_message := 'Unable to convert find ADJ Header ('||:new.adj_header_id||') ' || sqlerrm;
      :new.process_Status := 'E';
       return;
  end;
  begin
    :new.quantity_to_adjust := to_number(:new.qty_change);
  exception
    when others then 
      :new.error_message := 'Unable to convert find transfer quantity ('||:new.qty_change||') to a number' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_adj_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where adj_header_id = l_header.adj_header_id;
      exception
        when others then
          null;
      end;
      return;
  end;
  if :new.lock_code is null then
    begin
      select attribute2
        into :new.subinventory_code
        from apps.HR_ORGANIZATION_UNITS hou
        where organization_id = l_header.organization_id
          and exists (select null from apps.mtl_secondary_inventories msi where msi.organization_id = hou.organization_id and msi.secondary_inventory_name = hou.attribute2);
    exception
      when others then
        null;
    end;
  else
    begin
      select secondary_inventory_name
        into :new.subinventory_code
        from apps.mtl_secondary_inventories msi 
        where organization_id = l_header.organization_id
          and msi.secondary_inventory_name = :new.lock_code;
          --and msi.attribute1 = :new.lock_code;
    exception
      when others then
      :new.error_message := 'Unable to find subinventory for lock code ('||:new.lock_code|| ')' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_adj_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where adj_header_id = l_header.adj_header_id;
      exception
        when others then
          null;
      end;
      return;
    end;
  end if;
  
  begin
    :new.inventory_item_id := apps.sku_to_iid(:new.sku_code);
    if nvl(:new.inventory_item_id, -1) = -1 then
      :new.error_message := 'Unable to find inventor_item_id for sku ('||:new.sku_code|| ')' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_adj_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where adj_header_id = l_header.adj_header_id;
      exception
        when others then
          null;
      end;
      return;
    end if;
  exception
    when others then
    :new.error_message := 'Unable to find inventor_item_id for sku ('||:new.sku_code|| ')' || sqlerrm;
    :new.process_Status := 'E';
    begin
      update xxdo.xxdo_wms_3pl_adj_h
        set process_status = 'E'
          , error_message = 'One or more lines contain errors'
        where adj_header_id = l_header.adj_header_id;
    exception
      when others then
        null;
    end;
    return;
  end;

exception
  when others then
    begin
      :new.error_message := sqlerrm;
      :new.process_status := 'E';
    exception
      when others then null;
    end;
end;
/


--
-- XXDO_WMS_3PL_ADJ_L_T2  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_L (Table)
--
CREATE OR REPLACE TRIGGER APPS.XXDO_WMS_3PL_ADJ_L_T2
BEFORE INSERT
ON XXDO.XXDO_WMS_3PL_ADJ_L    FOR EACH ROW
WHEN (
NEW.ADJ_TYPE_CODE IS NOT NULL
      )
BEGIN
   FOR cur_adj_type_code IN (SELECT lookup_code
                               FROM apps.fnd_lookup_values
                              WHERE lookup_type = 'XXDO_ECOM_ADJ_MAPPING'
                                AND LANGUAGE = USERENV ('LANG')
                                AND enabled_flag = 'Y')
   LOOP
      IF :NEW.ADJ_TYPE_CODE = cur_adj_type_code.lookup_code
      THEN
         :NEW.process_status := 'O';
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS
   THEN
      BEGIN
         :NEW.error_message := SQLERRM;
         :NEW.process_status := 'E';
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;
END;
/
