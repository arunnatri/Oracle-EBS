--
-- XXDO_WMS_3PL_OSC_L  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_OSC_L
(
  OSC_HEADER_ID          NUMBER,
  OSC_LINE_ID            NUMBER,
  MESSAGE_TYPE           VARCHAR2(10 BYTE)      DEFAULT 'LOSC',
  LINE_SEQUENCE          VARCHAR2(30 BYTE)      NOT NULL,
  SKU_CODE               VARCHAR2(30 BYTE),
  QTY_SHIPPED            VARCHAR2(15 BYTE)      NOT NULL,
  CARTON_NUMBER          VARCHAR2(30 BYTE),
  TRACKING_NUMBER        VARCHAR2(30 BYTE),
  CREATED_BY             NUMBER                 DEFAULT 0,
  CREATION_DATE          DATE                   DEFAULT sysdate,
  LAST_UPDATED_BY        NUMBER                 DEFAULT 0,
  LAST_UPDATE_DATE       DATE                   DEFAULT sysdate,
  SOURCE_LINE_ID         NUMBER                 DEFAULT null,
  INVENTORY_ITEM_ID      NUMBER                 DEFAULT null,
  QUANTITY_TO_SHIP       NUMBER                 DEFAULT null,
  SUBINVENTORY_CODE      VARCHAR2(30 BYTE)      DEFAULT null,
  PROCESS_STATUS         VARCHAR2(1 BYTE)       DEFAULT 'P',
  PROCESSING_SESSION_ID  NUMBER                 DEFAULT null,
  ERROR_MESSAGE          VARCHAR2(4000 BYTE)    DEFAULT null,
  DUTY_PAID_FLAG         VARCHAR2(1 BYTE),
  COUNTRY_OF_ORIGIN      VARCHAR2(150 BYTE),
  TOTAL_WEIGHT           NUMBER,
  WEIGHT_UOM_CODE        VARCHAR2(50 BYTE),
  TOTAL_VOLUME           NUMBER,
  VOLUME_UOM_CODE        VARCHAR2(50 BYTE)
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
-- XXDO_WMS_3PL_OSC_L_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_OSC_L_U1 ON XXDO.XXDO_WMS_3PL_OSC_L
(OSC_LINE_ID)
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
-- XXDO_WMS_3PL_OSC_L_U2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_OSC_L_U2 ON XXDO.XXDO_WMS_3PL_OSC_L
(OSC_LINE_ID, OSC_HEADER_ID)
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
-- XXDO_WMS_3PL_OSC_L_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OSC_L_N1 ON XXDO.XXDO_WMS_3PL_OSC_L
(OSC_HEADER_ID, PROCESS_STATUS, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_OSC_L_N2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OSC_L_N2 ON XXDO.XXDO_WMS_3PL_OSC_L
(OSC_HEADER_ID, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_OSC_L_N3  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OSC_L_N3 ON XXDO.XXDO_WMS_3PL_OSC_L
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
-- XXDO_WMS_3PL_OSC_L_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_L (Table)
--
CREATE OR REPLACE TRIGGER APPS.XXDO_WMS_3PL_OSC_L_T1 
before insert or update ON XXDO.XXDO_WMS_3PL_OSC_L for each row
WHEN (
nvl(new.process_status, 'E') != 'A'
      )
declare
l_id number;
l_header xxdo.xxdo_wms_3pl_osc_h%rowtype;
begin
  :new.processing_session_id := nvl(:new.processing_session_id, userenv('SESSIONID'));
  if :new.osc_header_id is null then
    select xxdo.xxdo_wms_3pl_osc_h_s.currval into :new.osc_header_id from dual; 
  end if;
  if :new.osc_line_id is null then
    select xxdo.xxdo_wms_3pl_osc_l_s.nextval into :new.osc_line_id from dual; 
  end if;
  if nvl(:new.created_by, 0) = 0 then
    :new.created_by := nvl(apps.fnd_global.user_id, :new.created_by); 
  end if;
  if nvl(:new.last_updated_by, 0) = 0 then
    :new.last_updated_by := nvl(apps.fnd_global.user_id, :new.last_updated_by); 
  end if;
  begin
    select * into l_header from xxdo.xxdo_wms_3pl_osc_h where osc_header_id = :new.osc_header_id;
  exception
    when others then 
      :new.error_message := 'Unable to find OSC Header ('||:new.osc_header_id||') ' || sqlerrm;
      :new.process_Status := 'E';
       return;
  end;
  begin
    select distinct source_line_id 
      into :new.source_line_id 
      from xxdo.xxdo_edi_3pl_ats_lines_v
      where order_id = l_header.order_id
        and line_num = :new.line_sequence;
  exception
    when others then 
      :new.error_message := 'Unable to find OSC Line ('|| l_header.order_id||'-'||:new.line_sequence||') ' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_osc_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where osc_header_id = l_header.osc_header_id;
      exception
        when others then
          null;
      end;
       return;
  end;
  begin
    :new.quantity_to_ship := to_number(:new.qty_shipped);
  exception
    when others then 
      :new.error_message := 'Unable to convert find quantity shipped ('||:new.qty_shipped||') to a number' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_osc_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where osc_header_id = l_header.osc_header_id;
      exception
        when others then
          null;
      end;
      return;
  end;
  begin
    :new.inventory_item_id := apps.sku_to_iid(:new.sku_code);
    if nvl(:new.inventory_item_id, -1) = -1 then
      :new.error_message := 'Unable to convert sku_code ('||:new.sku_code||') to a SKU' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_osc_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where osc_header_id = l_header.osc_header_id;
      exception
        when others then
          null;
      end;
      return;
    end if;
  exception
    when others then 
      :new.error_message := 'Unable to convert sku_code ('||:new.sku_code||') to a SKU' || sqlerrm;
      :new.process_Status := 'E';
      begin
        update xxdo.xxdo_wms_3pl_osc_h
          set process_status = 'E'
            , error_message = 'One or more lines contain errors'
          where osc_header_id = l_header.osc_header_id;
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXDO_WMS_3PL_OSC_L TO APPS WITH GRANT OPTION
/
