--
-- XXDO_WMS_3PL_ADJ_H  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_ADJ_H
(
  ADJ_HEADER_ID             NUMBER,
  MESSAGE_NAME              VARCHAR2(10 BYTE)   DEFAULT 'HADJ',
  SITE_ID                   VARCHAR2(10 BYTE)   NOT NULL,
  CLIENT_ID                 VARCHAR2(10 BYTE)   DEFAULT 'DECKERS',
  OWNER_ID                  VARCHAR2(10 BYTE)   DEFAULT 'DECKERS',
  ADJUSTMENT_DATE           VARCHAR2(20 BYTE),
  ADJUST_DATE               DATE,
  CREATED_BY                NUMBER              DEFAULT 0,
  CREATION_DATE             DATE                DEFAULT sysdate,
  LAST_UPDATED_BY           NUMBER              DEFAULT 0,
  LAST_UPDATE_DATE          DATE                DEFAULT sysdate,
  ORGANIZATION_ID           NUMBER              DEFAULT null,
  PROCESS_STATUS            VARCHAR2(1 BYTE)    DEFAULT 'P',
  PROCESSING_SESSION_ID     NUMBER              DEFAULT null,
  ERROR_MESSAGE             VARCHAR2(240 BYTE)  DEFAULT null,
  IN_PROCESS_FLAG           VARCHAR2(1 BYTE)    DEFAULT 'N'                   NOT NULL,
  ADJ_TYPE_CODE             VARCHAR2(100 BYTE),
  ORIGINAL_ADJUSTMENT_DATE  VARCHAR2(40 BYTE),
  ECOM_PLATFORM             VARCHAR2(20 BYTE)
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
-- XXDO_WMS_3PL_ADJ_H_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_H (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_ADJ_H_U1 ON XXDO.XXDO_WMS_3PL_ADJ_H
(ADJ_HEADER_ID)
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
-- XXDO_WMS_3PL_ADJ_H_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_H (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_ADJ_H_N1 ON XXDO.XXDO_WMS_3PL_ADJ_H
(PROCESS_STATUS, PROCESSING_SESSION_ID, ADJ_HEADER_ID)
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
-- XXDO_WMS_3PL_ADJ_H_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_H (Table)
--
CREATE OR REPLACE TRIGGER XXDO.XXDO_WMS_3PL_ADJ_H_T1 
   BEFORE INSERT OR UPDATE
   ON xxdo.xxdo_wms_3pl_adj_h
   FOR EACH ROW
WHEN (NVL (new.process_Status, 'E') != 'A')
DECLARE
   l_timezone          VARCHAR2 (50);
   l_offset            NUMBER;
   --Added as part of CCR #CCR0005487
   l_temp_date         VARCHAR2 (50);
   d_temp_date         DATE;
   d_adjustment_date   DATE;
BEGIN
   --Get date conversion for 3PL file date
   d_adjustment_date := TO_DATE (:new.adjustment_date, 'YYYYMMDDHH24MISS');

   --Set the session ID
   :new.processing_session_id :=
      NVL (:new.processing_session_id, USERENV ('SESSIONID'));

   --Get ORG ID for site
   --Moved to package CCR0006561
   :new.organization_id :=
      APPS.XXDO_INT_WMS_UTIL.get_wms_org_id (:new.site_id);

   IF :new.organization_id IS NULL
   THEN
      :new.error_message :=
            'Unable to find organization_id associated with site_id ('
         || :new.site_id
         || ')';
      :new.process_Status := 'E';
      RETURN;
   END IF;

   --Get timezone for Site
   --Moved to package CCR0006561
   l_timezone := APPS.XXDO_INT_WMS_UTIL.get_wms_timezone (:new.site_id);

   IF :new.adj_header_id IS NULL
   THEN
      SELECT xxdo.xxdo_wms_3pl_adj_h_s.NEXTVAL
        INTO :new.adj_header_id
        FROM DUAL;
   END IF;

   IF NVL (:new.created_by, 0) = 0
   THEN
      :new.created_by := NVL (apps.fnd_global.user_id, :new.created_by);
   END IF;

   IF NVL (:new.last_updated_by, 0) = 0
   THEN
      :new.last_updated_by :=
         NVL (apps.fnd_global.user_id, :new.last_updated_by);
   END IF;

   IF d_adjustment_date IS NOT NULL
   THEN
      BEGIN
         --Get offset for timezone
         --Moved to package CCR0006561
         l_offset := APPS.XXDO_INT_WMS_UTIL.get_offset (l_timezone);

         --Added as part of CCR #CCR0005487
         IF :new.adjust_date IS NULL
         THEN
            d_temp_date :=
               APPS.XXDO_INT_WMS_UTIL.get_file_adjusted_time (
                  d_adjustment_date,
                  :new.site_id);

            IF d_temp_date <> d_adjustment_date
            THEN
               :new.adjust_date := d_temp_date;
               :new.ORIGINAL_ADJUSTMENT_DATE := :new.adjustment_date;
            --:new.error_message := 'Transaction Months/Dates are inconsistent';
            --:new.process_Status := 'E';
            ELSE
               :new.adjust_date :=
                  LEAST (d_adjustment_date + l_offset, SYSDATE);
            END IF;
         END IF;                                    --End for :new.adjust_date
      EXCEPTION
         WHEN OTHERS
         THEN
            :new.error_message :=
                  'Unable to convert transfer date ('
               || :new.adjustment_date
               || ') to a date '
               || SQLERRM;
            :new.process_Status := 'E';
            RETURN;
      END;
   ELSE
      :new.adjust_date := SYSDATE;
   END IF;
EXCEPTION
   WHEN OTHERS
   THEN
      BEGIN
         :new.error_message := SQLERRM;
         :new.process_status := 'E';
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;
END;
/


--
-- XXDO_WMS_3PL_ADJ_H_T2  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_ADJ_H (Table)
--
CREATE OR REPLACE TRIGGER APPS.XXDO_WMS_3PL_ADJ_H_T2
BEFORE INSERT
ON XXDO.XXDO_WMS_3PL_ADJ_H    FOR EACH ROW
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
