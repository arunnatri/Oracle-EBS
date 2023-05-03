--
-- XXD_WMS_LPN_LOAD_X_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_LPN_LOAD_X_PKG"
AS
    PROCEDURE LOAD_STAGING_TABLE (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        l_pallet              NUMBER;
        l_pallet_length       NUMBER;
        l_lpn                 VARCHAR2 (30 BYTE);
        l_lpn_length          NUMBER;
        l_inventory_item_id   NUMBER;
        l_item                VARCHAR2 (30);
        l_description         VARCHAR2 (250);
        l_uom                 VARCHAR2 (10);
        l_original_org        VARCHAR2 (3);
        l_org                 VARCHAR2 (3);
        l_org_id              NUMBER;
        l_sub                 VARCHAR2 (30);
        l_location            VARCHAR2 (50);
        l_locator_id          NUMBER;
        l_quantity            NUMBER;

        --Process Counters
        ln_loop_count         NUMBER := 0;
        ln_commit_count       NUMBER := 0;

        CURSOR C1 IS
              SELECT (SELECT license_plate_number
                        FROM apps.wms_license_plate_numbers@BT_READ_1206.US.ORACLE.COM
                       WHERE lpn_id = wlpn.parent_lpn_id)
                         pallet,
                     LENGTH (
                         (SELECT license_plate_number
                            FROM apps.wms_license_plate_numbers@BT_READ_1206.US.ORACLE.COM
                           WHERE lpn_id = wlpn.parent_lpn_id))
                         pallet_length,
                     wlpn.license_plate_number
                         lpn,
                     LENGTH (wlpn.license_plate_number)
                         lpn_length,
                     msi.inventory_item_id,
                     msi.segment1 || '-' || MSI.SEGMENT2 || '-' || MSI.SEGMENT3
                         AS item,
                     msi.description,
                     msi.primary_uom_code
                         UOM,
                     mp.organization_code
                         ORIGINAL_ORG,
                     DECODE (mp.organization_code,
                             'DC1', 'US2',
                             'DC2', 'US2',
                             'DC3', 'US3')
                         AS Org,
                     (SELECT organization_id
                        FROM apps.mtl_parameters
                       WHERE organization_code =
                             DECODE (mp.organization_code,
                                     'DC1', 'US2',
                                     'DC2', 'US2',
                                     'DC3', 'US3'))
                         org_id,
                     moqd.subinventory_code
                         AS Sub,
                        mil.segment1
                     || '.'
                     || mil.segment2
                     || '.'
                     || mil.segment3
                     || '.'
                     || mil.segment4
                     || '.'
                     || MIL.SEGMENT5
                         AS location,
                     (SELECT INVENTORY_LOCATION_ID
                        FROM APPS.MTL_ITEM_LOCATIONS_KFV
                       WHERE     ORGANIZATION_ID =
                                 (SELECT organization_id
                                    FROM apps.mtl_parameters
                                   WHERE organization_code =
                                         DECODE (mp.organization_code,
                                                 'DC1', 'US2',
                                                 'DC2', 'US2',
                                                 'DC3', 'US3'))
                             AND CONCATENATED_SEGMENTS =
                                 (mil.segment1 || '.' || mil.segment2 || '.' || mil.segment3 || '.' || mil.segment4 || '.' || MIL.SEGMENT5))
                         LOCATOR_ID,
                     SUM (moqd.primary_transaction_quantity)
                         AS Qty
                FROM apps.mtl_onhand_quantities_detail@BT_READ_1206.US.ORACLE.COM moqd, apps.mtl_system_items_b@BT_READ_1206.US.ORACLE.COM msi, apps.mtl_item_locations@BT_READ_1206.US.ORACLE.COM mil,
                     apps.mtl_parameters@BT_READ_1206.US.ORACLE.COM mp, apps.wms_license_plate_numbers@BT_READ_1206.US.ORACLE.COM wlpn
               WHERE     moqd.inventory_item_id = msi.inventory_item_id
                     AND moqd.organization_id = msi.organization_id
                     AND moqd.locator_id = mil.inventory_location_id
                     AND msi.organization_id = mp.organization_id
                     AND moqd.organization_id = wlpn.organization_id
                     AND moqd.lpn_id = wlpn.lpn_id
                     AND mp.organization_code IN ('DC1', 'DC2', 'DC3')
            GROUP BY wlpn.parent_lpn_id, wlpn.license_plate_number, msi.inventory_item_id,
                     msi.segment1 || '-' || MSI.SEGMENT2 || '-' || MSI.SEGMENT3, msi.description, msi.primary_uom_code,
                     organization_code, moqd.subinventory_code, mil.segment1 || '.' || mil.segment2 || '.' || mil.segment3 || '.' || mil.segment4 || '.' || MIL.SEGMENT5;
    BEGIN
        FOR I IN C1
        LOOP
            l_pallet              := I.PALLET;
            l_pallet_length       := I.PALLET_LENGTH;
            l_lpn                 := I.LPN;
            l_lpn_length          := I.LPN_LENGTH;
            l_inventory_item_id   := I.INVENTORY_ITEM_ID;
            l_item                := I.ITEM;
            l_description         := I.DESCRIPTION;
            l_uom                 := I.UOM;
            l_original_org        := I.ORIGINAL_ORG;
            l_org                 := I.ORG;
            l_org_id              := I.ORG_ID;
            l_sub                 := I.SUB;
            l_location            := I.LOCATION;
            l_locator_id          := I.LOCATOR_ID;
            l_quantity            := I.QTY;



            INSERT INTO XXD_INV_ITEM_ONHAND_LPN_STG_T (PALLET,
                                                       PALLET_LENGTH,
                                                       LPN,
                                                       LPN_LENGTH,
                                                       INVENTORY_ITEM_ID,
                                                       ITEM,
                                                       DESCRIPTION,
                                                       UOM,
                                                       ORIGINAL_ORG,
                                                       ORG,
                                                       ORG_ID,
                                                       SUB,
                                                       LOCATION,
                                                       LOCATOR_ID,
                                                       QUANTITY)
                 VALUES (l_pallet, l_pallet_length, l_lpn,
                         l_lpn_length, l_inventory_item_id, l_item,
                         l_description, l_uom, l_original_org,
                         l_org, l_org_id, l_sub,
                         l_location, l_locator_id, l_quantity);

            ln_loop_count         := ln_loop_count + 1;
            ln_commit_count       := ln_commit_count + 1;

            IF ln_commit_count = 2000
            THEN
                COMMIT;
                ln_commit_count   := 0;
            END IF;
        END LOOP;


        IF ln_loop_count < 1
        THEN
            retcode   := 1;                                         -- Warning
            errbuf    := 'No Records Processed';
        ELSE
            retcode   := 0;                                         -- Success
        END IF;
    END;
END XXD_WMS_LPN_LOAD_X_PKG;
/
