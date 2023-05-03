--
-- XXD_WMS_LOCATOR_UTILS_X_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_LOCATOR_UTILS_X_PKG"
AS
    PROCEDURE CREATE_STOCK_LOCATORS (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        l_msg_data                  VARCHAR2 (100);
        l_msg_count                 NUMBER;
        l_return_status             VARCHAR2 (1);
        l_locator_id                NUMBER;
        l_locator_exists            VARCHAR2 (1);
        l_org_id                    NUMBER;
        l_organization_code         VARCHAR2 (10);
        l_sub_code                  VARCHAR2 (10);
        l_concatenated_segments     VARCHAR2 (100);
        l_description               VARCHAR2 (50 BYTE);
        l_inventory_location_type   NUMBER;
        l_picking_order             NUMBER;
        l_pick_uom_code             VARCHAR2 (3 BYTE);
        l_status_id                 NUMBER;
        l_dropping_order            NUMBER;
        l_attribute1                VARCHAR2 (20);
        l_attribute2                VARCHAR2 (20);
        l_attribute3                VARCHAR2 (20);

        -- Process Counters
        ln_loop_count               NUMBER := 0;
        ln_success_count            NUMBER := 0;
        ln_error_count              NUMBER := 0;
        ln_commit_count             NUMBER := 0;                       --Viswa

        -- Error Messaging
        --   lc_error                    VARCHAR2 (32767) ;

        CURSOR C1 IS
            SELECT ORG_ID, ORGANIZATION_CODE, DESCRIPTION,
                   INVENTORY_LOCATION_TYPE, PICKING_ORDER, SUBINVENTORY_CODE,
                   LOCATOR_CONCAT_SEGMENTS, PICK_UOM_CODE, STATUS_ID,
                   DROPPING_ORDER, ATTRIBUTE1, ATTRIBUTE2,
                   ATTRIBUTE3
              FROM APPS.XXD_WMS_STOCK_LOCATOR_STG_T;
    BEGIN
        FND_FILE.put_line (
            FND_FILE.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || '--------------------------------------------------------------------------------');
        FND_FILE.put_line (
            FND_FILE.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || 'Start of Procedure: APPS.XX_LOCATOR_UTILS_PKG.CREATE_STOCK_LOCATORS');

        FND_GLOBAL.APPS_INITIALIZE (1790, 21676, 385); ---BT_WMS_CONV, WAREHOUSE MANAGEMENT, WAREHOUSE MANAGER---

        FND_MSG_PUB.INITIALIZE;

        FOR I IN C1
        LOOP
            l_org_id                    := I.ORG_ID;
            l_organization_code         := I.ORGANIZATION_CODE;
            l_concatenated_segments     := I.LOCATOR_CONCAT_SEGMENTS;
            l_description               := I.DESCRIPTION;
            l_inventory_location_type   := I.INVENTORY_LOCATION_TYPE;
            l_picking_order             := I.PICKING_ORDER;
            l_sub_code                  := I.SUBINVENTORY_CODE;
            l_pick_uom_code             := I.PICK_UOM_CODE;
            l_status_id                 := I.STATUS_ID;
            l_dropping_order            := I.DROPPING_ORDER;
            l_attribute1                := I.ATTRIBUTE1;
            l_attribute2                := I.ATTRIBUTE2;
            l_attribute3                := I.ATTRIBUTE3;



            INV_LOC_WMS_PUB.CREATE_LOCATOR (x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data, x_inventory_location_id => l_locator_id, x_locator_exists => l_locator_exists, p_organization_id => l_org_id, p_organization_code => l_organization_code, p_concatenated_segments => l_concatenated_segments, p_description => l_description, p_inventory_location_type => l_inventory_location_type, p_picking_order => l_picking_order, p_location_maximum_units => NULL, p_subinventory_code => l_sub_code, p_location_weight_uom_code => NULL, p_max_weight => NULL, p_volume_uom_code => NULL, p_max_cubic_area => NULL, p_x_coordinate => NULL, p_y_coordinate => NULL, p_z_coordinate => NULL, p_physical_location_id => NULL, p_pick_uom_code => l_pick_uom_code, p_dimension_uom_code => NULL, p_length => NULL, p_width => NULL, p_height => NULL, p_status_id => l_status_id, p_dropping_order => l_dropping_order, p_attribute1 => l_attribute1, p_attribute2 => l_attribute2
                                            , p_attribute3 => l_attribute3);


            ln_loop_count               := ln_loop_count + 1;
            FND_FILE.put_line (
                FND_FILE.LOG,
                   TO_CHAR (SYSDATE, 'HH24:MI:SS')
                || ': Return Status '
                || l_concatenated_segments
                || ' - '
                || l_return_status);

            --
            IF l_return_status = fnd_api.g_ret_sts_success
            THEN
                ln_success_count   := ln_success_count + 1;
                ln_commit_count    := ln_commit_count + 1;             --Viswa
            ELSE
                ln_error_count   := ln_error_count + 1;
                --         Get Error Message
                --        FOR m IN 1..NVL(l_msg_count,0) LOOP
                --          lc_error  :=  lc_error ||','||fnd_msg_pub.get(m,NULL);
                --        END LOOP;
                --         Write Error to log
                FND_FILE.put_line (
                    FND_FILE.LOG,
                    TO_CHAR (SYSDATE, 'HH24:MI:SS') || ':    Error Message: ');
            END IF;

            --Viswa
            IF ln_commit_count = 2000
            THEN
                COMMIT;
                ln_commit_count   := 0;
            END IF;
        --Viswa
        --
        --
        END LOOP;

        FND_FILE.put_line (
            FND_FILE.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || '--------------------------------------------------------------------------------');
        FND_FILE.put_line (
            FND_FILE.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || ': Total Records in Staging Table: '
            || ln_loop_count);
        FND_FILE.put_line (
            FND_FILE.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || ': Successful: '
            || ln_success_count);
        FND_FILE.put_line (
            FND_FILE.LOG,
            TO_CHAR (SYSDATE, 'HH24:MI:SS') || ': Errors: ' || ln_error_count);
        FND_FILE.put_line (
            FND_FILE.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || '--------------------------------------------------------------------------------');

        --
        IF ln_error_count > 0
        THEN
            retcode   := 1;                                         -- Warning
            errbuf    := ln_error_count;
        ELSE
            retcode   := 0;                                         -- Success
        END IF;
    END;
END XXD_WMS_LOCATOR_UTILS_X_PKG;
/
