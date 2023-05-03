--
-- XXD_WMS_LOCATOR_LOAD_X_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_LOCATOR_LOAD_X_PKG"
AS
    PROCEDURE LOAD_STAGING_TABLE (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        l_orig_org                  VARCHAR2 (10);
        l_org_id                    NUMBER;
        l_organization_code         VARCHAR2 (10);
        l_sub_code                  VARCHAR2 (10);
        l_concatenated_segments     VARCHAR2 (100);
        l_description               VARCHAR2 (50 BYTE);
        l_inventory_location_type   NUMBER;
        l_picking_order             NUMBER;
        l_pick_uom_code             VARCHAR2 (3 BYTE);
        l_dropping_order            NUMBER;
        l_inventory_item_id         NUMBER;
        l_attribute1                VARCHAR2 (20);
        l_attribute2                VARCHAR2 (20);
        l_attribute3                VARCHAR2 (20);
        l_status_id                 NUMBER;

        --Process Counters
        ln_loop_count               NUMBER := 0;


        CURSOR C1 IS
              SELECT mp_dev.organization_code ORIG_ORG, mp.organization_id org_id, mp.organization_code,
                     mil_dev.description, mil_dev.INVENTORY_LOCATION_TYPE, mil_dev.picking_order,
                     mil_dev.subinventory_code, DECODE (mil_dev.STATUS_ID,  1, 1,  20, 24,  21, 26,  40, 21,  41, 20,  42, 23,  43, 27,  44, 26,  60, 25) STATUS_ID, mil_dev.segment1 || '.' || mil_dev.segment2 || '.' || mil_dev.segment3 || '.' || mil_dev.segment4 || '.' || mil_dev.segment5 LOCATOR_CONCAT_SEGMENTS,
                     mil_dev.PICK_UOM_CODE, mil_dev.DROPPING_ORDER, mil_dev.ATTRIBUTE1,
                     mil_dev.inventory_item_id, DECODE (mil_dev.ATTRIBUTE2,  'DC1', 'US2',  'DC2', 'US2',  'DC3', 'US3') attribute2, mil_dev.ATTRIBUTE3
                FROM apps.mtl_item_locations@BT_READ_1206.US.ORACLE.COM mil_dev, apps.mtl_parameters@BT_READ_1206.US.ORACLE.COM mp_dev, apps.mtl_parameters mp
               WHERE     mil_dev.organization_id = mp_dev.organization_id
                     AND mp_dev.organization_code IN ('DC1', 'DC2', 'DC3')
                     AND DECODE (mp_dev.organization_code,
                                 'DC1', 'US2',
                                 'DC2', 'US2',
                                 'DC3', 'US3') =
                         mp.organization_code
                     AND mil_dev.end_date_active IS NULL -- change per operation plan to clean up locators by 1 MAR 2016
                     AND mil_dev.subinventory_code IS NOT NULL
                     AND mil_dev.subinventory_code <> 'XDOCK' --chnage for Special VAS
                     AND mil_dev.inventory_location_id NOT IN
                             (SELECT inventory_location_id
                                FROM apps.mtl_item_locations@BT_READ_1206.US.ORACLE.COM mil, apps.mtl_parameters@BT_READ_1206.US.ORACLE.COM mp3
                               WHERE     mil.organization_id =
                                         mp3.organization_id
                                     AND mp3.organization_code IN ('DC1')
                                     AND mil.subinventory_code = 'RSV')
            ORDER BY org_id DESC;
    BEGIN
        FOR I IN C1
        LOOP
            l_orig_org                  := I.ORIG_ORG;
            l_org_id                    := I.ORG_ID;
            l_organization_code         := I.ORGANIZATION_CODE;
            l_concatenated_segments     := I.LOCATOR_CONCAT_SEGMENTS;
            l_description               := I.DESCRIPTION;
            l_inventory_location_type   := I.INVENTORY_LOCATION_TYPE;
            l_picking_order             := I.PICKING_ORDER;
            l_sub_code                  := I.SUBINVENTORY_CODE;
            l_pick_uom_code             := I.PICK_UOM_CODE;
            l_dropping_order            := I.DROPPING_ORDER;
            l_inventory_item_id         := I.INVENTORY_ITEM_ID;
            l_attribute1                := I.ATTRIBUTE1;
            l_attribute2                := I.ATTRIBUTE2;
            l_attribute3                := I.ATTRIBUTE3;
            l_status_id                 := I.STATUS_ID;



            INSERT INTO XXD_WMS_STOCK_LOCATOR_STG_T (orig_org,
                                                     org_id,
                                                     organization_code,
                                                     locator_concat_segments,
                                                     description,
                                                     inventory_location_type,
                                                     picking_order,
                                                     subinventory_code,
                                                     status_id,
                                                     pick_uom_code,
                                                     dropping_order,
                                                     inventory_item_id,
                                                     attribute1,
                                                     attribute2,
                                                     attribute3)
                 VALUES (l_orig_org, l_org_id, l_organization_code,
                         l_concatenated_segments, l_description, l_inventory_location_type, l_picking_order, l_sub_code, l_status_id, l_pick_uom_code, l_dropping_order, l_inventory_item_id
                         , l_attribute1, l_attribute2, l_attribute3);

            ln_loop_count               := ln_loop_count + 1;
        END LOOP;


        IF ln_loop_count < 1
        THEN
            retcode   := 1;                                         -- Warning
            errbuf    := 'No Records Processed';
        ELSE
            retcode   := 0;                                         -- Success
        END IF;
    END;
END XXD_WMS_LOCATOR_LOAD_X_PKG;
/
