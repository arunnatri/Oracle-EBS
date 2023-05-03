--
-- XXDO_WMS_3PL_OSC_H  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_OSC_H
(
  OSC_HEADER_ID            NUMBER,
  MESSAGE_NAME             VARCHAR2(10 BYTE)    DEFAULT 'HOSC',
  SITE_ID                  VARCHAR2(10 BYTE)    NOT NULL,
  CLIENT_ID                VARCHAR2(10 BYTE)    DEFAULT 'DECKERS',
  OWNER_ID                 VARCHAR2(10 BYTE)    DEFAULT 'DECKERS',
  ORDER_ID                 VARCHAR2(20 BYTE)    NOT NULL,
  CARRIER                  VARCHAR2(20 BYTE),
  SHIPMENT_DATE            VARCHAR2(20 BYTE),
  SHIP_CONFIRM_DATE        DATE,
  CREATED_BY               NUMBER               DEFAULT 0,
  CREATION_DATE            DATE                 DEFAULT sysdate,
  LAST_UPDATED_BY          NUMBER               DEFAULT 0,
  LAST_UPDATE_DATE         DATE                 DEFAULT sysdate,
  SOURCE_DOCUMENT_CODE     VARCHAR2(20 BYTE)    DEFAULT null,
  SOURCE_HEADER_ID         NUMBER               DEFAULT null,
  ORG_ID                   NUMBER               DEFAULT null,
  CARRIER_CODE             VARCHAR2(240 BYTE)   DEFAULT null,
  ORGANIZATION_ID          NUMBER               DEFAULT null,
  PROCESS_STATUS           VARCHAR2(1 BYTE)     DEFAULT 'P',
  PROCESSING_SESSION_ID    NUMBER               DEFAULT null,
  ERROR_MESSAGE            VARCHAR2(4000 BYTE)  DEFAULT null,
  CUSTOMER_REFERENCE       VARCHAR2(80 BYTE),
  IN_PROCESS_FLAG          VARCHAR2(1 BYTE)     DEFAULT 'N'                   NOT NULL,
  SHIPPING_METHOD          VARCHAR2(80 BYTE),
  FREIGHT_CHARGES          VARCHAR2(10 BYTE),
  BOL_NUMBER               VARCHAR2(30 BYTE),
  LOAD_ID                  VARCHAR2(40 BYTE),
  ORIGINAL_SHIPMENT_DATE   VARCHAR2(40 BYTE),
  PRO_NUMBER               VARCHAR2(20 BYTE),
  VESSEL_DEPARTURE_DATE    VARCHAR2(50 BYTE),
  DEPARTURE_LOCATION_CODE  VARCHAR2(50 BYTE),
  VESSEL_ARRIVAL_DATE      VARCHAR2(50 BYTE),
  VESSEL_LOCATION_CODE     VARCHAR2(50 BYTE),
  CONTAINER_LOAD_TYPE      VARCHAR2(50 BYTE),
  CONTAINER_TYPE_CODE      VARCHAR2(50 BYTE),
  CONTAINER_NUMBER         VARCHAR2(50 BYTE),
  SEAL_NUMBER              VARCHAR2(50 BYTE),
  TOTAL_WEIGHT             NUMBER,
  WEIGHT_UOM_CODE          VARCHAR2(50 BYTE),
  TOTAL_VOLUME             NUMBER,
  VOLUME_UOM_CODE          VARCHAR2(50 BYTE),
  ORIGINAL_DELIVERY        VARCHAR2(50 BYTE)
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
-- XXDO_WMS_3PL_OSC_H_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_H (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_OSC_H_U1 ON XXDO.XXDO_WMS_3PL_OSC_H
(OSC_HEADER_ID)
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
-- XXDO_WMS_3PL_OSC_H_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_H (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_OSC_H_N1 ON XXDO.XXDO_WMS_3PL_OSC_H
(PROCESS_STATUS, PROCESSING_SESSION_ID, OSC_HEADER_ID)
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
-- XXDO_WMS_3PL_OSC_H_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_OSC_H (Table)
--
CREATE OR REPLACE TRIGGER APPS.XXDO_WMS_3PL_OSC_H_T1 
   BEFORE INSERT OR UPDATE
   ON XXDO.XXDO_WMS_3PL_OSC_H
   FOR EACH ROW
WHEN (NVL (new.process_Status, 'E') NOT IN ('S', 'A'))
DECLARE
   l_timezone        VARCHAR2 (50);
   l_offset          NUMBER;
   --Added as part of CCR #CCR0005487
   l_temp_date       VARCHAR2 (50);
   d_temp_date       DATE;
   d_shipment_date   DATE;
   lv_organization_code VARCHAR2 (50);  --Added for #CCR0009055
BEGIN
   --Get date conversion for 3PL file date
   d_shipment_date := TO_DATE (:new.shipment_date, 'YYYYMMDDHH24MISS');

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

   IF :new.osc_header_id IS NULL
   THEN
      SELECT xxdo.xxdo_wms_3pl_osc_h_s.NEXTVAL
        INTO :new.osc_header_id
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
-- Commented for CCR0009446
   --Start Added for #CCR0009055
    /*BEGIN		 
	   SELECT organization_code
	    INTO lv_organization_code
		 FROM mtl_parameters
		 WHERE organization_id = :new.organization_id;

	    IF (lv_organization_code = 'US5' 
				AND :new.process_status = 'P' 
				AND nvl(:new.freight_charges, 0) > 0)
	    THEN	
		   :new.freight_charges := 0.000;			 
        END IF;		
    EXCEPTION
      WHEN OTHERS
      THEN
         :new.error_message :=
               'Unable to update freight charges ('           
            || SQLERRM;
         :new.process_Status := 'E';
         RETURN;
    END;*/
   --End Added for #CCR0009055
-- Commented for CCR0009446
   BEGIN
      SELECT NVL (MAX (source_header_id), 0)
        INTO :new.source_header_id
        FROM xxdo.xxdo_edi_3pl_ats_headers_v
       WHERE     order_id = TO_NUMBER (:new.order_id)
             AND organization_id = :new.organization_id;

      IF :new.source_header_id = 0
      THEN
         :new.error_message :=
               'Unable to convert order_id ('
            || :new.order_id
            || ') to a valid source header_id';
         :new.process_Status := 'E';
         RETURN;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         :new.error_message :=
               'Unable to convert order_id ('
            || :new.order_id
            || ') to a number '
            || SQLERRM;
         :new.process_Status := 'E';
         RETURN;
   END;


   IF d_shipment_date IS NOT NULL
   THEN
      BEGIN
         --Get offset for timezone
         --Moved to package CCR0006561
         l_offset := APPS.XXDO_INT_WMS_UTIL.get_offset (l_timezone);


         --Added as part of CCR #CCR0005487
         --        apps.XXDO_3PL_DEBUG_PROCEDURE('3PL Shipment_date is not null: '||:new.shipment_date);
         IF :new.ship_confirm_date IS NULL
         THEN
            --Get the adjusted transaction time
            d_temp_date :=
               APPS.XXDO_INT_WMS_UTIL.get_file_adjusted_time (d_shipment_date,
                                                              :new.site_id); -- changed  CCR0006561

            IF d_temp_date <> d_shipment_date
            THEN
               :new.ship_confirm_date := d_temp_date;
               :new.original_shipment_date := :new.shipment_date;
            --:new.error_message := 'Transaction Months/Dates are inconsistent';
            --:new.process_Status := 'E';
            ELSE
               --:new.ship_confirm_date := to_date(APPS.XXDO_INT_WMS_UTIL.get_file_adjusted_time(:new.shipment_date,l_timezone),'MM:DD:YYYY HH:MI:SS AM');
               :new.ship_confirm_date :=
                  LEAST (d_shipment_date + l_offset, SYSDATE);
            END IF;
         END IF;                              --End for :new.ship_confirm_date
      EXCEPTION
         WHEN OTHERS
         THEN
            :new.error_message :=
                  'Unable to convert shipment date ('
               || :new.shipment_date
               || ') to a date '
               || SQLERRM;
            :new.process_Status := 'E';
            RETURN;
      END;
   ELSE
      :new.ship_confirm_date := SYSDATE;
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


GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK ON XXDO.XXDO_WMS_3PL_OSC_H TO APPS WITH GRANT OPTION
/
