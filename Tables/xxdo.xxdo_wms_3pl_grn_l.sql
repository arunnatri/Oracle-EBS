--
-- XXDO_WMS_3PL_GRN_L  (Table) 
--
CREATE TABLE XXDO.XXDO_WMS_3PL_GRN_L
(
  GRN_HEADER_ID          NUMBER,
  GRN_LINE_ID            NUMBER,
  MESSAGE_TYPE           VARCHAR2(10 BYTE)      DEFAULT 'LGRN',
  SKU_CODE               VARCHAR2(30 BYTE),
  LINE_SEQUENCE          VARCHAR2(6 BYTE)       NOT NULL,
  QTY_RECEIVED           VARCHAR2(15 BYTE)      NOT NULL,
  LOCK_CODE              VARCHAR2(20 BYTE),
  CREATED_BY             NUMBER                 DEFAULT 0,
  CREATION_DATE          DATE                   DEFAULT sysdate,
  LAST_UPDATED_BY        NUMBER                 DEFAULT 0,
  LAST_UPDATE_DATE       DATE                   DEFAULT sysdate,
  SOURCE_LINE_ID         NUMBER                 DEFAULT null,
  INVENTORY_ITEM_ID      NUMBER                 DEFAULT null,
  QUANTITY_TO_RECEIVE    NUMBER                 DEFAULT null,
  SUBINVENTORY_CODE      VARCHAR2(30 BYTE)      DEFAULT null,
  PROCESS_STATUS         VARCHAR2(1 BYTE)       DEFAULT 'P',
  PROCESSING_SESSION_ID  NUMBER                 DEFAULT null,
  ERROR_MESSAGE          VARCHAR2(240 BYTE)     DEFAULT null,
  CARTON_CODE            VARCHAR2(20 BYTE),
  RETURN_REASON_CODE     VARCHAR2(12 BYTE),
  DUTY_PAID_FLAG         VARCHAR2(1 BYTE),
  RECEIPT_TYPE           VARCHAR2(20 BYTE),
  COO                    CHAR(3 BYTE),
  UNIT_WEIGHT            NUMBER,
  UNIT_LENGTH            NUMBER,
  UNIT_WIDTH             NUMBER,
  UNIT_HEIGHT            NUMBER,
  SPLIT                  VARCHAR2(30 BYTE),
  TRANSACTION_ID         NUMBER
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
-- XXDO_WMS_3PL_GRN_L_U1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_GRN_L_U1 ON XXDO.XXDO_WMS_3PL_GRN_L
(GRN_LINE_ID)
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
-- XXDO_WMS_3PL_GRN_L_U2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_L (Table)
--
CREATE UNIQUE INDEX XXDO.XXDO_WMS_3PL_GRN_L_U2 ON XXDO.XXDO_WMS_3PL_GRN_L
(GRN_HEADER_ID, GRN_LINE_ID)
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
-- XXDO_WMS_3PL_GRN_L_N1  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_GRN_L_N1 ON XXDO.XXDO_WMS_3PL_GRN_L
(GRN_HEADER_ID, PROCESS_STATUS, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_GRN_L_N2  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_GRN_L_N2 ON XXDO.XXDO_WMS_3PL_GRN_L
(GRN_HEADER_ID, PROCESSING_SESSION_ID)
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
-- XXDO_WMS_3PL_GRN_L_N3  (Index) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_L (Table)
--
CREATE INDEX XXDO.XXDO_WMS_3PL_GRN_L_N3 ON XXDO.XXDO_WMS_3PL_GRN_L
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
-- XXDO_WMS_3PL_GRN_L_T1  (Trigger) 
--
--  Dependencies: 
--   XXDO_WMS_3PL_GRN_L (Table)
--
CREATE OR REPLACE TRIGGER APPS.XXDO_WMS_3PL_GRN_L_T1 
BEFORE INSERT OR UPDATE 
    ON xxdo.xxdo_wms_3pl_grn_l
   FOR EACH ROW
WHEN (NVL (NEW.process_status, 'E') != 'A')
DECLARE
   l_id              NUMBER;
   l_header          xxdo.xxdo_wms_3pl_grn_h%ROWTYPE;
   lv_standard_org   VARCHAR2 (2);                 --Added for CCR CCR0008870
   l_trx_cnt   NUMBER;
BEGIN
IF NVL(:NEW.SPLIT,'X') IN ('I','U')  -- Added IF Condition for CCR0010325
THEN 
   NULL;
ELSE 
   :NEW.processing_session_id := NVL (:NEW.processing_session_id, USERENV ('SESSIONID'));

   IF :NEW.grn_header_id IS NULL
   THEN
      SELECT xxdo.xxdo_wms_3pl_grn_h_s.CURRVAL
        INTO :NEW.grn_header_id
        FROM DUAL;
   END IF;

   IF :NEW.grn_line_id IS NULL
   THEN
      SELECT xxdo.xxdo_wms_3pl_grn_l_s.NEXTVAL
        INTO :NEW.grn_line_id
        FROM DUAL;
   END IF;

   IF NVL (:NEW.created_by, 0) = 0
   THEN
      :NEW.created_by := NVL (apps.fnd_global.user_id, :NEW.created_by);
   END IF;

   IF NVL (:NEW.last_updated_by, 0) = 0
   THEN
      :NEW.last_updated_by := NVL (apps.fnd_global.user_id,:NEW.last_updated_by);
   END IF;

   BEGIN
      SELECT *
        INTO l_header
        FROM xxdo.xxdo_wms_3pl_grn_h
       WHERE grn_header_id = :NEW.grn_header_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         :NEW.error_message :=
               'Unable to find GRN Header ('
            || :NEW.grn_header_id
            || ') '
            || SQLERRM;
         :NEW.process_status := 'E';
         RETURN;
   END;

   IF  SUBSTR (l_header.preadvice_id, 1, 3) != 'RTN'
   AND (:NEW.receipt_type IS NULL OR :NEW.receipt_type = 'RECEIVE')--Added new condition for CCR CCR0008870
   THEN
      BEGIN
         SELECT source_line_id
           INTO :NEW.source_line_id
           FROM (SELECT   source_line_id
                     FROM xxdo.xxdo_wms_grn_l_v                   --CCR0007219
                    WHERE source_document_code = l_header.source_document_code
                      AND source_header_id = l_header.source_header_id
                      AND sku = :NEW.sku_code
                      AND (   NVL (carton_code, '-NONE-') =
                                              NVL (:NEW.carton_code, '-NONE-')
                           OR :NEW.carton_code IS NULL
                          )
                 ORDER BY DECODE (line_num, :NEW.line_sequence, 0, 1),
                          source_line_id)
          WHERE ROWNUM = 1;
      EXCEPTION
         WHEN OTHERS
         THEN
            :NEW.error_message :=
                  'Unable to find GRN line ('
               || l_header.source_document_code
               || '-'
               || l_header.source_header_id
               || '-'
               || :NEW.sku_code
               || '-'
               || NVL (:NEW.carton_code, '-NONE-')
               || ') '
               || SQLERRM;
            :NEW.process_status := 'E';

            BEGIN
               UPDATE xxdo.xxdo_wms_3pl_grn_h
                  SET process_status = 'E',
                      error_message = 'One or more lines contain errors'
                WHERE grn_header_id = l_header.grn_header_id;
            EXCEPTION
               WHEN OTHERS
               THEN
                  NULL;
            END;

            RETURN;
      END;
   END IF;




   IF  SUBSTR(l_header.preadvice_id, 1, 3) != 'RTN'
   AND (:NEW.receipt_type = 'DELIVER') --Added new condition for CCR CCR0008870
   THEN
      BEGIN
         SELECT   MIN (rsl.shipment_line_id) AS source_line_id
             INTO :NEW.source_line_id
             FROM apps.rcv_shipment_lines rsl,
                  apps.rcv_shipment_headers rsh,
                  (SELECT   source_line_id, destination_line_id,
                            CASE rsh1.attribute4
                               WHEN 'Y'
                                  THEN carton_number
                               ELSE NULL
                            END carton_number,
                            SUM (quantity) quantity,
                            SUM (quantity_received) quantity_received
                       FROM xxdo.xxdo_wms_asn_cartons c1,
                            apps.rcv_shipment_headers rsh1
                      WHERE status_flag = 'ACTIVE'
                        AND c1.destination_header_id = rsh1.shipment_header_id
                   GROUP BY source_line_id,
                            destination_line_id,
                            CASE rsh1.attribute4
                               WHEN 'Y'
                                  THEN carton_number
                               ELSE NULL
                            END) cart,
                  apps.rcv_routing_headers rrh
            WHERE 1 = 1
              AND rsl.shipment_line_status_code IN
                         ('FULLY RECEIVED', 'PARTIALLY RECEIVED', 'EXPECTED')
              AND rsl.shipment_header_id = rsh.shipment_header_id
              AND rsl.shipment_line_id = cart.destination_line_id(+)
              AND rsl.source_document_code IN ('PO', 'REQ')
              AND TO_NUMBER (rsh.attribute2) = l_header.source_header_id
              AND apps.iid_to_sku (rsl.item_id) = :NEW.sku_code
              AND rrh.routing_header_id = rsl.routing_header_id
              AND rrh.routing_name = 'Standard Receipt'
         GROUP BY rsh.attribute2,
                  rsh.attribute4,
                  apps.iid_to_sku (rsl.item_id),
                  LPAD (apps.iid_to_upc (rsl.item_id), 13, '0'),
                  cart.carton_number,
                  rsl.source_document_code,
                  rsl.shipment_line_status_code,
                  rsl.quantity_shipped,
                  rsl.quantity_received,
                  rsl.shipment_line_id;

         l_trx_cnt := 0;          
         SELECT COUNT(1) 
           INTO l_trx_cnt 
           FROM rcv_transactions 
          WHERE 1=1 
            AND transaction_type = 'RECEIVE'
            AND shipment_line_id = :NEW.source_line_id
            AND quantity         = :NEW.qty_received ;  
         IF l_trx_cnt = 0 
         THEN  
            :NEW.source_line_id := -1;
         END IF; 

      EXCEPTION
         WHEN TOO_MANY_ROWS  
         THEN 
            :NEW.source_line_id := -1; -- Added for CCR0010325

         WHEN OTHERS
         THEN
            BEGIN
               SELECT source_line_id
                 INTO :NEW.source_line_id
                 FROM (SELECT   source_line_id
                           FROM xxdo.xxdo_wms_grn_l_v             --CCR0007219
                          WHERE source_document_code =
                                                 l_header.source_document_code
                            AND source_header_id = l_header.source_header_id
                            AND sku = :NEW.sku_code
                            AND (   NVL (carton_code, '-NONE-') =
                                              NVL (:NEW.carton_code, '-NONE-')
                                 OR :NEW.carton_code IS NULL
                                )
                       ORDER BY DECODE (line_num, :NEW.line_sequence, 0, 1),
                                source_line_id)
                WHERE ROWNUM = 1;
            EXCEPTION
               WHEN OTHERS
               THEN
                  :NEW.error_message :=
                        'Unable to find GRN line ('
                     || l_header.source_document_code
                     || '-'
                     || l_header.source_header_id
                     || '-'
                     || :NEW.sku_code
                     || '-'
                     || NVL (:NEW.carton_code, '-NONE-')
                     || ') '
                     || SQLERRM;
                  :NEW.process_status := 'E';

                  BEGIN
                     UPDATE xxdo.xxdo_wms_3pl_grn_h
                        SET process_status = 'E',
                            error_message = 'One or more lines contain errors'
                      WHERE grn_header_id = l_header.grn_header_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        NULL;
                  END;

                  RETURN;
            END;
      END;
   END IF;







   BEGIN
      :NEW.quantity_to_receive := TO_NUMBER (:NEW.qty_received);
   EXCEPTION
      WHEN OTHERS
      THEN
         :NEW.error_message :=
               'Unable to convert find quantity received ('
            || :NEW.qty_received
            || ') to a number'
            || SQLERRM;
         :NEW.process_status := 'E';

         BEGIN
            UPDATE xxdo.xxdo_wms_3pl_grn_h
               SET process_status = 'E',
                   error_message = 'One or more lines contain errors'
             WHERE grn_header_id = l_header.grn_header_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;

         RETURN;
   END;

   --Start of cahnges for CCR CCR0008870
   BEGIN
      SELECT 'Y'
        INTO lv_standard_org
        FROM fnd_lookup_values fv, org_organization_definitions ood
       WHERE fv.lookup_type = 'XDO_PO_STAND_RECEIPT_ORGS'
         AND fv.LANGUAGE = USERENV ('Lang')
         AND fv.enabled_flag = 'Y'
         AND SYSDATE BETWEEN fv.start_date_active
                         AND NVL (fv.end_date_active, SYSDATE)
         AND ood.organization_code = fv.meaning
         AND ood.organization_id = l_header.organization_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_standard_org := 'N';
   END;

   --END of cahnges for CCR CCR0008870
   IF     :NEW.lock_code IS NULL
      AND NVL (lv_standard_org, 'N') = 'N'       --Added for change CCR0008870
   THEN
      BEGIN
         SELECT attribute2
           INTO :NEW.subinventory_code
           FROM hr_organization_units hou
          WHERE organization_id = l_header.organization_id
            AND EXISTS (
                   SELECT NULL
                     FROM apps.mtl_secondary_inventories msi
                    WHERE msi.organization_id = hou.organization_id
                      AND msi.secondary_inventory_name = hou.attribute2);
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;
   ELSIF :NEW.lock_code IS NOT NULL              --Added for change CCR0008870
   THEN
      BEGIN
         SELECT secondary_inventory_name
           INTO :NEW.subinventory_code
           FROM apps.mtl_secondary_inventories msi
          WHERE organization_id = l_header.organization_id
            --and msi.attribute1 = :new.lock_code;
            AND msi.secondary_inventory_name = :NEW.lock_code;
      EXCEPTION
         WHEN OTHERS
         THEN
            :NEW.error_message :=
                  'Unable to find subinventory for lock code ('
               || :NEW.lock_code
               || ')'
               || SQLERRM;
            :NEW.process_status := 'E';

            BEGIN
               UPDATE xxdo.xxdo_wms_3pl_grn_h
                  SET process_status = 'E',
                      error_message = 'One or more lines contain errors'
                WHERE grn_header_id = l_header.grn_header_id;
            EXCEPTION
               WHEN OTHERS
               THEN
                  NULL;
            END;

            RETURN;
      END;
   END IF;

   --Start of changes for change CCR0008870
   IF :NEW.lock_code IS NULL AND :NEW.receipt_type = 'DELIVER'
   THEN
      :NEW.error_message :=
         'Unable to find subinventory for lock code (' || :NEW.lock_code
         || ')';
      :NEW.process_status := 'E';

      BEGIN
         UPDATE xxdo.xxdo_wms_3pl_grn_h
            SET process_status = 'E',
                error_message = 'One or more lines contain errors'
          WHERE grn_header_id = l_header.grn_header_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;

      RETURN;
   END IF;

   --End of changes for change CCR0008870
   BEGIN
      :NEW.inventory_item_id := apps.sku_to_iid (:NEW.sku_code);

      IF NVL (:NEW.inventory_item_id, -1) = -1
      THEN
         :NEW.error_message :=
               'Unable to find inventory_item_id for sku ('
            || :NEW.sku_code
            || ')'
            || SQLERRM;
         :NEW.process_status := 'E';

         BEGIN
            UPDATE xxdo.xxdo_wms_3pl_grn_h
               SET process_status = 'E',
                   error_message = 'One or more lines contain errors'
             WHERE grn_header_id = l_header.grn_header_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;

         RETURN;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         :NEW.error_message :=
               'Unable to find inventory_item_id for sku ('
            || :NEW.sku_code
            || ')'
            || SQLERRM;
         :NEW.process_status := 'E';

         BEGIN
            UPDATE xxdo.xxdo_wms_3pl_grn_h
               SET process_status = 'E',
                   error_message = 'One or more lines contain errors'
             WHERE grn_header_id = l_header.grn_header_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;

         RETURN;
   END;
END IF;    
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
