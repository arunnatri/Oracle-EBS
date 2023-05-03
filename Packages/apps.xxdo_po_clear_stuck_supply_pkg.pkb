--
-- XXDO_PO_CLEAR_STUCK_SUPPLY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_CLEAR_STUCK_SUPPLY_PKG"
AS
    /******************************************************************************
    NAME:       XXDO_PO_CLEAR_STUCK_SUPPLY_PKG
    PURPOSE:    To clear stuck supply records which get stuck due to a standard oracle bug.
    REVISIONS:
    Ver        Date        Author           Description
    ---------  ----------  ---------------  ------------------------------------
    1.0        01/27/2017   Infosys       1. Created this package.
    ******************************************************************************/
    --***************************************************************************
    --                (c) Copyright Deckers
    --                     All rights reserved
    -- ***************************************************************************
    --
    -- Package Name:  XXDO_PO_CLEAR_STUCK_SUPPLY_PKG
    -- PROCEDURE Name :XXDO_PO_CLR_STCK_SUPPLY_PROC
    -- Description:  To clear stuck supply records which get stuck due to a standard oracle bug,
    --               the supply stays in mtl_supply even after the PO is fully received.
    --               Shipment Supply Data Exists After Full Correction to Over Received ASN.
    -- DEVELOPMENT MAINTENANCE HISTORY
    --
    -- Date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2017/27/01   Infosys              1.0.0    Initial version
    -- ***************************************************************************
    PROCEDURE xxdo_po_clr_stck_supply_proc (p_retcode     OUT NUMBER,
                                            p_error_buf   OUT VARCHAR2)
    IS
        CURSOR cur_qty_left IS
            SELECT (rsl.quantity_shipped - rsl.quantity_received) AS quantity_left, ms.shipment_line_id AS shipment_line_id, ms.UNIT_OF_MEASURE AS uom,
                   ms.TO_ORG_PRIMARY_UOM AS primary_uom, ms.ITEM_ID AS item_id, ms.po_line_location_id
              FROM (  SELECT SUM (quantity) AS quantity, shipment_line_id, UNIT_OF_MEASURE,
                             TO_ORG_PRIMARY_UOM, ITEM_ID, po_line_location_id
                        FROM mtl_supply
                       WHERE supply_type_code = 'SHIPMENT'
                    GROUP BY shipment_line_id, UNIT_OF_MEASURE, TO_ORG_PRIMARY_UOM,
                             ITEM_ID, po_line_location_id) ms,
                   rcv_shipment_lines rsl,
                   po_line_locations_all plla
             WHERE     ms.shipment_line_id = rsl.shipment_line_id
                   AND rsl.ASN_LINE_FLAG = 'Y'
                   AND ms.quantity + rsl.quantity_received >
                       rsl.quantity_shipped
                   AND ms.po_line_location_id = plla.line_location_id;

        CURSOR C_MS_DIS (l_rsl_id NUMBER)
        IS
              SELECT po_distribution_id, quantity, TO_ORG_PRIMARY_QUANTITY
                FROM mtl_supply
               WHERE     shipment_line_id = l_rsl_id
                     AND supply_type_code = 'SHIPMENT'
            ORDER BY po_distribution_id;

        v_primary_qty   NUMBER;
        v_qty           NUMBER;
        v_count         NUMBER;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               '*** Main Program Start at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        fnd_file.put_line (fnd_file.LOG, '');

        DELETE FROM apps.ms_9880944_bak;

        COMMIT;
        v_count   := 0;

        FOR c1_rec IN cur_qty_left
        LOOP
            IF c1_rec.quantity_left > 0
            THEN
                v_qty   := c1_rec.quantity_left;
                v_primary_qty   :=
                      c1_rec.quantity_left
                    * po_uom_s.po_uom_convert (c1_rec.uom,
                                               c1_rec.primary_uom,
                                               c1_rec.item_id);

                FOR c_ms_rec IN C_MS_DIS (c1_rec.shipment_line_id)
                LOOP
                    IF v_primary_qty >= c_ms_rec.TO_ORG_PRIMARY_QUANTITY
                    THEN
                        v_qty           := v_qty - c_ms_rec.quantity;
                        v_primary_qty   :=
                            v_primary_qty - c_ms_rec.TO_ORG_PRIMARY_QUANTITY;
                        v_count         := v_count + 1;
                    ELSE
                        v_count   := v_count + 1;

                        IF v_primary_qty > 0
                        THEN
                            INSERT INTO ms_9880944_bak
                                SELECT *
                                  FROM MTL_SUPPLY
                                 WHERE     shipment_line_id =
                                           c1_rec.shipment_line_id
                                       AND po_distribution_id =
                                           c_ms_rec.po_distribution_id
                                       AND supply_type_code = 'SHIPMENT';

                            UPDATE mtl_supply
                               SET quantity = v_qty, TO_ORG_PRIMARY_QUANTITY = v_primary_qty
                             WHERE     shipment_line_id =
                                       c1_rec.shipment_line_id
                                   AND po_distribution_id =
                                       c_ms_rec.po_distribution_id
                                   AND supply_type_code = 'SHIPMENT';

                            v_primary_qty   := -1;
                        ELSE
                            INSERT INTO ms_9880944_bak
                                SELECT *
                                  FROM MTL_SUPPLY
                                 WHERE     shipment_line_id =
                                           c1_rec.shipment_line_id
                                       AND po_distribution_id =
                                           c_ms_rec.po_distribution_id
                                       AND supply_type_code = 'SHIPMENT';

                            DELETE FROM
                                mtl_supply
                                  WHERE     shipment_line_id =
                                            c1_rec.shipment_line_id
                                        AND po_distribution_id =
                                            c_ms_rec.po_distribution_id
                                        AND supply_type_code = 'SHIPMENT';
                        END IF;
                    END IF;
                END LOOP;
            ELSE
                INSERT INTO ms_9880944_bak
                    SELECT *
                      FROM MTL_SUPPLY
                     WHERE     shipment_line_id = c1_rec.shipment_line_id
                           AND supply_type_code = 'SHIPMENT';

                DELETE FROM
                    mtl_supply
                      WHERE     shipment_line_id = c1_rec.shipment_line_id
                            AND supply_type_code = 'SHIPMENT';

                v_count   := v_count + 1;
            END IF;

            IF custom_create_po_supply (c1_rec.po_line_location_id)
            THEN
                v_count   := v_count + 1;
            END IF;
        END LOOP;

        COMMIT;
        fnd_file.put_line (fnd_file.LOG,
                           'Update ' || v_count || ' records Successful!');
        fnd_file.put_line (fnd_file.LOG, '');
        fnd_file.put_line (
            fnd_file.LOG,
               '*** Main Program End at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        fnd_file.put_line (fnd_file.LOG, '');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (fnd_file.LOG, 'Rollbacked the transaction...');
            fnd_file.put_line (fnd_file.LOG, '');
    END xxdo_po_clr_stck_supply_proc;
END XXDO_PO_CLEAR_STUCK_SUPPLY_PKG;
/
