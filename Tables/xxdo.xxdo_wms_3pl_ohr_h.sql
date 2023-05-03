--
-- XXDO_WMS_3PL_OHR_H  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_OHR_H
(
  OHR_HEADER_ID          NUMBER,
  MESSAGE_NAME           VARCHAR2(10 BYTE)      DEFAULT 'OHR',
  SITE_ID                VARCHAR2(10 BYTE)      NOT NULL,
  CLIENT_ID              VARCHAR2(10 BYTE)      DEFAULT 'DECKERS',
  OWNER_ID               VARCHAR2(10 BYTE)      DEFAULT 'DECKERS',
  ORGANIZATION_ID        NUMBER                 DEFAULT null,
  SNAPSHOT_DATE_STR      VARCHAR2(30 BYTE)      NOT NULL,
  SNAPSHOT_DATE          DATE,
  INV_CONCILLATION_DATE  DATE,
  CONC_REQUEST_ID        NUMBER,
  CREATED_BY             NUMBER                 DEFAULT 0,
  CREATION_DATE          DATE                   DEFAULT sysdate,
  LAST_UPDATED_BY        NUMBER                 DEFAULT 0,
  LAST_UPDATE_DATE       DATE                   DEFAULT sysdate,
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
-- XXDO_WMS_3PL_OHR_H_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_H (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OHR_H_N1 ON XXDO.XXDO_WMS_3PL_OHR_H
(PROCESS_STATUS, PROCESSING_SESSION_ID, OHR_HEADER_ID)
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
-- XXDO_WMS_3PL_OHR_H_N2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_H (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OHR_H_N2 ON XXDO.XXDO_WMS_3PL_OHR_H
(ORGANIZATION_ID)
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
-- XXDO_WMS_3PL_OHR_H_N3  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_H (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OHR_H_N3 ON XXDO.XXDO_WMS_3PL_OHR_H
(CONC_REQUEST_ID)
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
-- XXDO_WMS_3PL_OHR_H_N4  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_H (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OHR_H_N4 ON XXDO.XXDO_WMS_3PL_OHR_H
(SNAPSHOT_DATE)
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
-- XXDO_WMS_3PL_OHR_H_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OHR_H (Table)
--
CREATE OR REPLACE TRIGGER APPS.XXDO_WMS_3PL_OHR_H_T1
before insert or update on xxdo.xxdo_wms_3pl_ohr_h for each row
WHEN (
nvl(new.process_Status, 'E') != 'A'
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
  if :new.ohr_header_id is null then
    select xxdo.XXDO_WMS_3PL_OHR_H_S.nextval into :new.ohr_header_id from dual;
  end if;
  if nvl(:new.created_by, 0) = 0 then
    :new.created_by := nvl(apps.fnd_global.user_id, :new.created_by);
  end if;
  if nvl(:new.last_updated_by, 0) = 0 then
    :new.last_updated_by := nvl(apps.fnd_global.user_id, :new.last_updated_by);
  end if;

  if :new.SNAPSHOT_DATE_STR is not null then
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

        if instr(:new.SNAPSHOT_DATE_STR, ':') > 0 then
            :new.SNAPSHOT_DATE := least(to_date(:new.SNAPSHOT_DATE_STR, 'YYYYMMDD HH24:MI:SS')+l_offset, sysdate);
        else
            :new.SNAPSHOT_DATE := least(to_date(:new.SNAPSHOT_DATE_STR, 'YYYYMMDDHH24MISS')+l_offset, sysdate);
        end if;

    exception
      when others then
        :new.error_message := 'Unable to convert snapshot date ('||:new.SNAPSHOT_DATE_STR||') to a date ' || sqlerrm;
        :new.process_Status := 'E';
        return;
    end;
  else
    :new.SNAPSHOT_DATE := sysdate;
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
