--
-- XXDO_WMS_3PL_TRK_H  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_TRK_H
(
  TRK_HEADER_ID          NUMBER                 NOT NULL,
  MESSAGE_NAME           VARCHAR2(10 BYTE)      DEFAULT 'HTRK',
  SITE_ID                VARCHAR2(10 BYTE)      NOT NULL,
  CLIENT_ID              VARCHAR2(10 BYTE)      DEFAULT 'DECKERS',
  OWNER_ID               VARCHAR2(10 BYTE)      DEFAULT 'DECKERS',
  ORDER_ID               VARCHAR2(20 BYTE)      NOT NULL,
  TRACKING_NUMBER        VARCHAR2(80 BYTE)      NOT NULL,
  TRACKING_DATE          VARCHAR2(20 BYTE),
  TRACK_DATE             DATE,
  CREATED_BY             NUMBER                 DEFAULT 0,
  CREATION_DATE          DATE                   DEFAULT sysdate,
  LAST_UPDATED_BY        NUMBER                 DEFAULT 0,
  LAST_UPDATE_DATE       DATE                   DEFAULT sysdate,
  ORG_ID                 NUMBER                 DEFAULT null,
  ORGANIZATION_ID        NUMBER                 DEFAULT null,
  SOURCE_HEADER_ID       NUMBER                 DEFAULT null,
  PROCESS_STATUS         VARCHAR2(1 BYTE)       DEFAULT 'P',
  PROCESSING_SESSION_ID  NUMBER                 DEFAULT null,
  ERROR_MESSAGE          VARCHAR2(240 BYTE)     DEFAULT null,
  IN_PROCESS_FLAG        VARCHAR2(1 BYTE)       DEFAULT 'N'                   NOT NULL
)
TABLESPACE CUSTOM_TX_TS
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
/


--
-- XXDO_WMS_3PL_TRK_H_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRK_H (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_TRK_H_U1 ON XXDO.XXDO_WMS_3PL_TRK_H
(TRK_HEADER_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXDO_WMS_3PL_TRK_H_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRK_H (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_TRK_H_N1 ON XXDO.XXDO_WMS_3PL_TRK_H
(PROCESS_STATUS, PROCESSING_SESSION_ID, TRK_HEADER_ID)
LOGGING
TABLESPACE CUSTOM_TX_TS
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/

--
-- XXDO_WMS_3PL_TRK_H_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_TRK_H (Table)
--
CREATE OR REPLACE TRIGGER XXDO.XXDO_WMS_3PL_TRK_H_T1
before insert or update ON XXDO.XXDO_WMS_3PL_TRK_H for each row
WHEN (
nvl(new.process_status, 'E') != 'A'
      )
declare
l_timezone varchar2(50);
l_offset number;
begin
  :new.processing_session_id := nvl(:new.processing_session_id, userenv('SESSIONID'));
  begin
    select hou.organization_id
           , hra.timezone_code
    into :new.organization_id
         , l_timezone
      from apps.hr_locations_all  hra
         , apps.hr_organization_units hou
      where hra.attribute1 = :new.site_id
        and hou.location_id = hra.location_id;

      if l_timezone is null then
        select name
        into l_timezone
        from apps.hz_timezones_tl htt
        where htt.timezone_id=apps.fnd_profile.value('SERVER_TIMEZONE_ID')
            and htt.language = 'US';
     end if;

  exception
    when others then
      :new.error_message := 'Unable to find organization_id associated with site_id ('||:new.site_id||')';
      :new.process_Status := 'E';
      return;
  end;
  if :new.trk_header_id is null then
    select xxdo.xxdo_wms_3pl_trk_h_s.nextval into :new.trk_header_id from dual;
  end if;
  if nvl(:new.created_by, 0) = 0 then
    :new.created_by := nvl(apps.fnd_global.user_id, :new.created_by);
  end if;
  if nvl(:new.last_updated_by, 0) = 0 then
    :new.last_updated_by := nvl(apps.fnd_global.user_id, :new.last_updated_by);
  end if;

  begin
    select nvl(max(delivery_id), 0)
      into :new.source_header_id
      from apps.wsh_new_deliveries
     where delivery_id = to_number(:new.order_id)
       and organization_id = :new.organization_id;
    if :new.source_header_id = 0 then
      :new.error_message := 'Unable to convert order_id ('||:new.order_id||') to a valid source header_id';
      :new.process_Status := 'E';
      return;
    end if;
  exception
    when others then
      :new.error_message := 'Unable to convert order_id ('||:new.order_id||') to a number ' || sqlerrm;
      :new.process_Status := 'E';
  end;

  if :new.tracking_date is not null then
    begin
        begin
            select sum(gmt_deviation_hours)/24
            into l_offset
            from (
                select -ht.gmt_deviation_hours as gmt_deviation_hours
                  from apps.hz_timezones ht
                     , apps.hz_timezones_tl htt
                  where  htt.name = l_timezone
                          and htt.language = 'US'
                          and ht.timezone_id = htt.timezone_id
                union all
                    select gmt_deviation_hours
                    from apps.hz_timezones ht
                    where timezone_id=apps.fnd_profile.value('SERVER_TIMEZONE_ID')
            );
       exception
         when others then
             l_offset := 0;
       end;

        if instr(:new.tracking_date, ':') > 0 then
            :new.track_date := least(to_date(:new.tracking_date, 'YYYYMMDD HH24:MI:SS')+l_offset, sysdate);
        else
            :new.track_date := least(to_date(:new.tracking_date, 'YYYYMMDDHH24MISS')+l_offset, sysdate);
        end if;

    exception
      when others then
        :new.error_message := 'Unable to convert tracking date ('||:new.tracking_date||') to a date ' || sqlerrm;
        :new.process_Status := 'E';
        return;
    end;
  else
    :new.track_date := sysdate;
  end if;

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
