--
-- XXDO_WMS_3PL_OHR_L  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_OHR_L
(
  OHR_HEADER_ID          NUMBER,
  OHR_LINE_ID            NUMBER,
  MESSAGE_TYPE           VARCHAR2(10 BYTE)      DEFAULT 'LOHR',
  BRAND                  VARCHAR2(40 BYTE),
  SKU_CODE               VARCHAR2(50 BYTE),
  DESCRIPTION            VARCHAR2(60 BYTE),
  LOCK_CODE              VARCHAR2(18 BYTE),
  SUBINVENTORY_CODE      VARCHAR2(30 BYTE),
  QUANTITY               NUMBER                 NOT NULL,
  UPC_CODE               VARCHAR2(30 BYTE),
  EBS_ONHAND_QTY         NUMBER,
  EBS_SHIP_PEND_QTY      NUMBER,
  EBS_SHIP_ERR_QTY       NUMBER,
  EBS_RMA_PEND_QTY       NUMBER,
  EBS_RMA_ERR_QTY        NUMBER,
  EBS_ASN_PEND_QTY       NUMBER,
  EBS_ASN_ERR_QTY        NUMBER,
  EBS_3PL_STG_ERR_QTY    NUMBER,
  EBS_ADJ_PEND_QTY       NUMBER,
  EBS_ADJ_ERR_QTY        NUMBER,
  INVENTORY_ITEM_ID      NUMBER                 DEFAULT null,
  LAST_TRANSACTION_DATE  DATE,
  CREATED_BY             NUMBER                 DEFAULT 0,
  CREATION_DATE          DATE                   DEFAULT sysdate,
  LAST_UPDATED_BY        NUMBER                 DEFAULT 0,
  LAST_UPDATE_DATE       DATE                   DEFAULT sysdate,
  PROCESS_STATUS         VARCHAR2(1 BYTE)       DEFAULT 'P',
  PROCESSING_SESSION_ID  NUMBER                 DEFAULT null,
  ERROR_MESSAGE          VARCHAR2(240 BYTE)     DEFAULT null,
  LAST_TXN_DATE_STR      VARCHAR2(30 BYTE),
  LAST_TXN_DATE          DATE
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
-- XXDO_WMS_3PL_OHR_L_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_OHR_L_U1 ON XXDO.XXDO_WMS_3PL_OHR_L
(OHR_LINE_ID)
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
-- XXDO_WMS_3PL_OHR_L_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OHR_L_N1 ON XXDO.XXDO_WMS_3PL_OHR_L
(OHR_HEADER_ID, PROCESS_STATUS, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_OHR_L_N2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OHR_L_N2 ON XXDO.XXDO_WMS_3PL_OHR_L
(INVENTORY_ITEM_ID, SUBINVENTORY_CODE)
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
-- XXDO_WMS_3PL_OHR_L_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_L (Table)
--
CREATE OR REPLACE TRIGGER APPS.XXDO_WMS_3PL_OHR_L_T1
before insert or update on xxdo.XXDO_WMS_3PL_OHR_L for each row
WHEN (
nvl(new.process_status, 'E') != 'A'
      )
declare
l_id number;
l_header xxdo.xxdo_wms_3pl_ohr_h%rowtype;
l_inv_item_id number;
begin
  :new.processing_session_id := nvl(:new.processing_session_id, userenv('SESSIONID'));
  if :new.ohr_header_id is null then
    select xxdo.XXDO_WMS_3PL_OHR_H_S.currval into :new.ohr_header_id from dual;
  end if;
  if :new.ohr_line_id is null then
    select xxdo.XXDO_WMS_3PL_OHR_L_S.nextval into :new.ohr_line_id from dual;
  end if;
  if nvl(:new.created_by, 0) = 0 then
    :new.created_by := nvl(apps.fnd_global.user_id, :new.created_by);
  end if;
  if nvl(:new.last_updated_by, 0) = 0 then
    :new.last_updated_by := nvl(apps.fnd_global.user_id, :new.last_updated_by);
  end if;
  begin
    select * into l_header from xxdo.xxdo_wms_3pl_ohr_h where ohr_header_id = :new.ohr_header_id;
  exception
    when others then
      :new.error_message := 'Unable to convert find OHR Header ('||:new.ohr_header_id||') ' || sqlerrm;
      :new.process_Status := 'E';
       return;
  end;
  begin
    if nvl(:new.quantity,0)=0 then
		:new.error_message := 'Quantity is null...';
		:new.process_Status := 'E';
		begin
			update xxdo.xxdo_wms_3pl_ohr_h
			set process_status = 'E'
			, error_message = 'One or more lines contain errors'
			where ohr_header_id = l_header.ohr_header_id;
		exception
			when others then
			null;
		end;
	    return;
	end if;
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
        update xxdo.xxdo_wms_3pl_ohr_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors, subinventory check fail'
          where ohr_header_id = l_header.ohr_header_id;
      exception
        when others then
          null;
      end;
      return;
    end;
  end if;

  begin
    --:new.inventory_item_id := apps.sku_to_iid(:new.sku_code);
	begin
		select 	inventory_item_id
		into 	l_inv_item_id --:new.inventory_item_id
		from 	apps.mtl_system_items_b
		where	segment1 = :new.sku_code
		and		organization_id = l_header.organization_id;

		:new.inventory_item_id := l_inv_item_id;
	exception
	when others then
		update xxdo.xxdo_wms_3pl_ohr_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors, sku_code check fail'
          where ohr_header_id = l_header.ohr_header_id;
	end;
    if nvl(:new.inventory_item_id, -1) = -1 then
      :new.error_message := 'Unable to find inventory_item_id for sku ('||:new.sku_code|| ')' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_ohr_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors, inventory_item_id check fail11'
          where ohr_header_id = l_header.ohr_header_id;
      exception
        when others then
          null;
      end;
      return;
    end if;
  exception
    when others then
    :new.error_message := 'Unable to find inventory_item_id for sku ('||:new.sku_code|| ')' || sqlerrm;
    :new.process_Status := 'E';
    begin
      update xxdo.xxdo_wms_3pl_ohr_h
        set process_status = 'E'
          , error_message = 'One or more lines contain errors, inventory_item_id check fail22'
        where ohr_header_id = l_header.ohr_header_id;
    exception
      when others then
        null;
    end;
    return;
  end;

  begin
	--Validate UPC_CODE value
	if nvl(:new.upc_code, -1) = -1 then
		begin
			select	cross_reference
			into	:new.upc_code
			from 	apps.mtl_cross_references
			where 	organization_id	  = l_header.organization_id
			and 	inventory_item_id = apps.sku_to_iid(:new.sku_code)
			and 	cross_reference_type='UPC Cross Reference';

		exception
		when others then
			:new.error_message := 'Unable to find cross reference code/UPC Code ('||:new.upc_code|| ')' || sqlerrm;
			:new.process_Status := 'E';
			begin
				update 	xxdo.xxdo_wms_3pl_ohr_h
				set 	process_status = 'E'
						, error_message = 'One or more lines contain errors, UPC code check fail'
				where ohr_header_id = l_header.ohr_header_id;
				exception
					when others then
					null;
				end;
		return;
		end;
	end if;
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
