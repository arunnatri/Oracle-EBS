--
-- XXDO_WMS_3PL_TRA_L  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_TRA_L
(
  TRA_HEADER_ID           NUMBER,
  TRA_LINE_ID             NUMBER,
  MESSAGE_TYPE            VARCHAR2(10 BYTE)     DEFAULT 'LTRA',
  TRANSACTION_ID          VARCHAR2(20 BYTE)     NOT NULL,
  FROM_LOCK_CODE          VARCHAR2(20 BYTE),
  TO_LOCK_CODE            VARCHAR2(20 BYTE),
  SKU_CODE                VARCHAR2(30 BYTE),
  QTY_CHANGE              VARCHAR2(15 BYTE)     NOT NULL,
  REASON_CODE             VARCHAR2(30 BYTE),
  COMMENTS                VARCHAR2(240 BYTE),
  TRANSFERRED_BY          VARCHAR2(50 BYTE),
  CREATED_BY              NUMBER                DEFAULT 0,
  CREATION_DATE           DATE                  DEFAULT sysdate,
  LAST_UPDATED_BY         NUMBER                DEFAULT 0,
  LAST_UPDATE_DATE        DATE                  DEFAULT sysdate,
  INVENTORY_ITEM_ID       NUMBER                DEFAULT null,
  QUANTITY_TO_TRANSFER    NUMBER                DEFAULT null,
  FROM_SUBINVENTORY_CODE  VARCHAR2(30 BYTE)     DEFAULT null,
  TO_SUBINVENTORY_CODE    VARCHAR2(30 BYTE)     DEFAULT null,
  PROCESS_STATUS          VARCHAR2(1 BYTE)      DEFAULT 'P',
  PROCESSING_SESSION_ID   NUMBER                DEFAULT null,
  ERROR_MESSAGE           VARCHAR2(240 BYTE)    DEFAULT null,
  DUTY_PAID_FLAG          VARCHAR2(1 BYTE)
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
-- XXDO_WMS_3PL_TRA_L_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRA_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_TRA_L_U1 ON XXDO.XXDO_WMS_3PL_TRA_L
(TRA_LINE_ID)
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
-- XXDO_WMS_3PL_TRA_L_U2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRA_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_TRA_L_U2 ON XXDO.XXDO_WMS_3PL_TRA_L
(TRA_HEADER_ID, TRA_LINE_ID)
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
-- XXDO_WMS_3PL_TRA_L_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRA_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_TRA_L_N1 ON XXDO.XXDO_WMS_3PL_TRA_L
(TRA_HEADER_ID, PROCESS_STATUS, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_TRA_L_N2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRA_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_TRA_L_N2 ON XXDO.XXDO_WMS_3PL_TRA_L
(TRA_HEADER_ID, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_TRA_L_N3  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRA_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_TRA_L_N3 ON XXDO.XXDO_WMS_3PL_TRA_L
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
-- XXDO_WMS_3PL_TRA_L_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRA_L (Table)
--
CREATE OR REPLACE TRIGGER XXDO.XXDO_WMS_3PL_TRA_L_T1 
before insert or update on xxdo.xxdo_wms_3pl_tra_l for each row
WHEN (
nvl(new.process_status, 'E') != 'A'
      )
declare
l_id number;
l_header xxdo.xxdo_wms_3pl_tra_h%rowtype;
begin
  :new.processing_session_id := nvl(:new.processing_session_id, userenv('SESSIONID'));
  if :new.tra_header_id is null then
    select xxdo.xxdo_wms_3pl_tra_h_s.currval into :new.tra_header_id from dual; 
  end if;
  if :new.tra_line_id is null then
    select xxdo.xxdo_wms_3pl_tra_l_s.nextval into :new.tra_line_id from dual; 
  end if;
  if nvl(:new.created_by, 0) = 0 then
    :new.created_by := nvl(apps.fnd_global.user_id, :new.created_by); 
  end if;
  if nvl(:new.last_updated_by, 0) = 0 then
    :new.last_updated_by := nvl(apps.fnd_global.user_id, :new.last_updated_by); 
  end if;
  begin
    select * into l_header from xxdo.xxdo_wms_3pl_tra_h where tra_header_id = :new.tra_header_id;
  exception
    when others then 
      :new.error_message := 'Unable to convert find TRA Header ('||:new.tra_header_id||') ' || sqlerrm;
      :new.process_Status := 'E';
       return;
  end;
  begin
    :new.quantity_to_transfer := to_number(:new.qty_change);
  exception
    when others then 
      :new.error_message := 'Unable to convert find transfer quantity ('||:new.qty_change||') to a number' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_tra_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where tra_header_id = l_header.tra_header_id;
      exception
        when others then
          null;
      end;
      return;
  end;
  if :new.from_lock_code is null then
    begin
      select attribute2
        into :new.from_subinventory_code
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
        into :new.from_subinventory_code
        from apps.mtl_secondary_inventories msi 
        where organization_id = l_header.organization_id
          and msi.secondary_inventory_name = :new.from_lock_code;
          --and msi.attribute1 = :new.from_lock_code;
    exception
      when others then
      :new.error_message := 'Unable to find from subinventory for lock code ('||:new.from_lock_code|| ')' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_tra_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where tra_header_id = l_header.tra_header_id;
      exception
        when others then
          null;
      end;
      return;
    end;
  end if;

  if :new.to_lock_code is null then
    begin
      select attribute2
        into :new.to_subinventory_code
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
        into :new.to_subinventory_code
        from apps.mtl_secondary_inventories msi 
        where organization_id = l_header.organization_id
          and msi.secondary_inventory_name = :new.to_lock_code;
          --and msi.attribute1 = :new.to_lock_code;
    exception
      when others then
      :new.error_message := 'Unable to find to subinventory for lock code ('||:new.to_lock_code|| ')' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_tra_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where tra_header_id = l_header.tra_header_id;
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
        update xxdo.xxdo_wms_3pl_tra_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where tra_header_id = l_header.tra_header_id;
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
      update xxdo.xxdo_wms_3pl_tra_h
        set process_status = 'E'
          , error_message = 'One or more lines contain errors'
        where tra_header_id = l_header.tra_header_id;
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
