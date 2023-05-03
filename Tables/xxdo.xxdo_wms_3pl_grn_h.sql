--
-- XXDO_WMS_3PL_GRN_H  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_GRN_H
(
  GRN_HEADER_ID          NUMBER,
  MESSAGE_NAME           VARCHAR2(10 BYTE)      DEFAULT 'HGRN',
  SITE_ID                VARCHAR2(10 BYTE)      NOT NULL,
  CLIENT_ID              VARCHAR2(10 BYTE)      DEFAULT 'DECKERS',
  OWNER_ID               VARCHAR2(10 BYTE)      DEFAULT 'DECKERS',
  PREADVICE_ID           VARCHAR2(30 BYTE)      NOT NULL,
  RECEIPT_DATE           VARCHAR2(20 BYTE),
  RECEIVING_DATE         DATE,
  CREATED_BY             NUMBER                 DEFAULT 0,
  CREATION_DATE          DATE                   DEFAULT sysdate,
  LAST_UPDATED_BY        NUMBER                 DEFAULT 0,
  LAST_UPDATE_DATE       DATE                   DEFAULT sysdate,
  SOURCE_DOCUMENT_CODE   VARCHAR2(20 BYTE)      DEFAULT null,
  SOURCE_HEADER_ID       NUMBER                 DEFAULT null,
  ORGANIZATION_ID        NUMBER                 DEFAULT null,
  PROCESS_STATUS         VARCHAR2(1 BYTE)       DEFAULT 'P',
  PROCESSING_SESSION_ID  NUMBER                 DEFAULT null,
  ERROR_MESSAGE          VARCHAR2(240 BYTE)     DEFAULT null,
  IN_PROCESS_FLAG        VARCHAR2(1 BYTE)       DEFAULT 'N'                   NOT NULL,
  ORIGINAL_RECEIPT_DATE  VARCHAR2(40 BYTE)
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
-- XXDO_WMS_3PL_GRN_H_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_H (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_GRN_H_U1 ON XXDO.XXDO_WMS_3PL_GRN_H
(GRN_HEADER_ID)
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
-- XXDO_WMS_3PL_GRN_H_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_H (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_GRN_H_N1 ON XXDO.XXDO_WMS_3PL_GRN_H
(PROCESS_STATUS, PROCESSING_SESSION_ID, GRN_HEADER_ID)
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
-- XXDO_WMS_3PL_GRN_H_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_H (Table)
--
CREATE OR REPLACE TRIGGER XXDO.XXDO_WMS_3PL_GRN_H_T1 
   BEFORE INSERT OR UPDATE
   ON XXDO.XXDO_WMS_3PL_GRN_H
   FOR EACH ROW
WHEN (NVL (new.process_Status, 'E') != 'A')
DECLARE
   l_timezone       VARCHAR2 (50);
   l_offset         NUMBER;
   --Added as part of CCR #CCR0005487
   l_temp_date      VARCHAR2 (50);
   d_receipt_date   DATE;
   d_temp_date      DATE;
BEGIN
   --Get date conversion for 3PL file date
   d_receipt_date := TO_DATE (:new.receipt_date,  'YYYYMMDDHH24MISS');

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

   IF :new.grn_header_id IS NULL
   THEN
      SELECT xxdo.xxdo_wms_3pl_grn_h_s.NEXTVAL
        INTO :new.grn_header_id
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

   IF d_receipt_date IS NOT NULL
   THEN
      BEGIN
         --Get offset for timezone
         --Moved to package CCR0006561
         l_offset := APPS.XXDO_INT_WMS_UTIL.get_offset (l_timezone);

         --Added as part of CCR #CCR0005487
         --Receiving date not set for record (sb for new records)
         IF :new.receiving_date IS NULL
         THEN
            --Get the adjusted transaction time
            d_temp_date :=
               APPS.XXDO_INT_WMS_UTIL.get_file_adjusted_time (d_receipt_date,
                                                              :new.site_id); -- changed  CCR0006561

            --  l_timezone);
            IF d_temp_date <> d_receipt_date
            THEN
               --Adjusted date/time differes than receipt date update receivind date with new value and save the old value
               :new.receiving_date := d_temp_date;
               :new.ORIGINAL_RECEIPT_DATE := :new.receipt_date;
            --:new.error_message := 'Transaction Months/Dates are inconsistent';
            --:new.process_Status := 'E';
            ELSE
               --No update - set receipt date to transaction date - offset(convert to US Time)
               :new.receiving_date :=
                  LEAST (d_receipt_date + l_offset, SYSDATE);
            END IF;
         END IF;                                 --End for :new.receiving_date
      EXCEPTION
         WHEN OTHERS
         THEN
            :new.error_message :=
                  'Unable to convert receipt date ('
               || :new.receipt_date
               || ') to a date '
               || SQLERRM;
            :new.process_Status := 'E';
            RETURN;
      END;
   ELSE
      :new.receiving_date := SYSDATE;
   END IF;

   IF SUBSTR (:new.preadvice_id, 1, 3) = 'EPO'
   THEN
      :new.source_document_code := 'PO';
   ELSIF SUBSTR (:new.preadvice_id, 1, 3) = 'INV'
   THEN
      :new.source_document_code := 'INVENTORY';
   ELSIF SUBSTR (:new.preadvice_id, 1, 3) = 'REQ'
   THEN
      :new.source_document_code := 'REQ';
   ELSIF    SUBSTR (:new.preadvice_id, 1, 3) = 'RTN'
         OR SUBSTR (:new.preadvice_id, 1, 3) = 'RET'
   THEN
      :new.source_document_code := 'RMA';
   ELSE
      :new.source_document_code := NULL;
      :new.error_message :=
            'Preadvice of type ('
         || SUBSTR (:new.preadvice_id, 1, 3)
         || ') from preadvice '
         || :new.preadvice_id
         || ' not recognized';
      :new.process_Status := 'E';
      RETURN;
   END IF;

   --Aded :new.source_header_id is null to conditional to mitigate mutating trigger exception. --
   --Created another view to avoid mutating trigger exception QC Defect 2339
   IF     SUBSTR (:new.preadvice_id, 1, 3) != 'RTN'
      AND :new.source_header_id IS NULL
   THEN
      BEGIN
         SELECT NVL (MAX (source_header_id), 0)
           INTO :new.source_header_id
           FROM XXDO.XXDO_EDI_3PL_GRN_V --XXDO.xxdo_edi_3pl_preadvice_h_v -- Modified for QC Defect 2339
          WHERE     source_document_code = :new.source_document_code
                AND customer_ref =
                       SUBSTR (
                          :new.preadvice_id,
                          1,
                          DECODE (INSTR (:new.preadvice_id, '.') - 1,
                                  -1, LENGTH (:new.preadvice_id),
                                  INSTR (:new.preadvice_id, '.') - 1)) --:new.preadvice_id
                AND organization_id = :new.organization_id;

         IF :new.source_header_id = 0
         THEN
            :new.error_message :=
                  'Unable to convert preadvice ('
               || :new.preadvice_id
               || ') of type ('
               || :new.source_document_code
               || ') to a valid source header_id';
            :new.process_Status := 'E';
            RETURN;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            :new.error_message :=
                  'Unable to convert preadvice ('
               || :new.preadvice_id
               || ') to a number '
               || SQLERRM;
            :new.process_Status := 'E';
            RETURN;
      END;
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
