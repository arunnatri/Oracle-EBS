--
-- XXDO_INV_ITEM_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INV_ITEM_INT_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_inv_item_int_pkg.sql   1.0    2014/10/06    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_item_int_pkg
    --
    -- Description  :  This is package  for WMS to EBS Item Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 06-Oct-14    Infosys            1.0       Created
    -- ***************************************************************************

    --Global Variables-----
    g_num_debug                         NUMBER := 0;
    g_num_request_id                    NUMBER := fnd_global.conc_request_id;
    g_num_operating_unit                NUMBER := fnd_profile.VALUE ('ORG_ID');
    g_num_user_id                       NUMBER := fnd_global.user_id;
    g_num_resp_id                       NUMBER := fnd_global.resp_id;
    g_num_login_id                      NUMBER := fnd_global.login_id;
    g_chr_status                        VARCHAR2 (100) := 'UNPROCESSED';

    g_chr_ret_status_warning   CONSTANT VARCHAR2 (1) := 'W';

    --   g_pkg_version CONSTANT VARCHAR2(100) :=


    -- ***************************************************************************
    -- Procedure/Function Name  :  Msg
    --
    -- Description                       :  The purpose of this procedure is to print debug messages
    --
    -- parameters                      :  p_in_var_message  In : message to be printed in the log file
    --
    -- Return/Exit                       :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/10/06    Infosys            1.0   Initial Version
    -- ***************************************************************************
    PROCEDURE msg (p_in_var_message IN VARCHAR2)
    IS
    BEGIN
        IF g_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, p_in_var_message);
        END IF;
    END msg;

    -- ***************************************************************************
    -- Procedure/Function Name  :  lock_records
    --
    -- Description                       :  The purpose of this procedure is to lock records for updating
    --
    -- parameters                      :  p_out_chr_errbuf  out : Error message
    --                                          p_out_chr_retcode  out : Execution status
    --
    -- Return/Exit                       :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/10/06    Infosys            1.0   Initial Version
    -- ***************************************************************************
    PROCEDURE lock_records (p_out_chr_errbuf    OUT VARCHAR2,
                            p_out_chr_retcode   OUT VARCHAR2)
    IS
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        UPDATE xxdo_inv_item_int_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE, error_message = NULL
         WHERE process_status = 'NEW';

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := SQLERRM;
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'ERROR in lock records procedure : ' || p_out_chr_errbuf);
    END lock_records;

    -- There is no API to create UOM Conversion in R12.0.6.
    -- The following API is available only in R12.1.3 or as part of the Patch 9335882 (BUG NUMBER : 9335882)
    -- The Pls version is  '$Header: INVUMCNB.pls 120.2.12010000.7 2010/04/01 06:11:07 ksaripal ship $';
    -- ***************************************************************************
    -- Procedure/Function Name  :  create_uom_conversion
    --
    -- Description                       :  The purpose of this procedure is to create the conversion between two uom's using uom_rate
    --                                             to_uom_code = uom_rate * from_uom_code
    --
    -- parameters                      :
    --                                        p_from_uom_code IN : From UOM Code - Primary UOM code of the item
    --                                        p_to_uom_code     IN : To UOM Code - Case
    --                                        p_item_id     IN : Inventory Item Id
    --                                        p_uom_rate     IN : Conversion rate
    --                                        x_return_status OUT : Execution Status - S: Success, W: Warning - Conversion exists already, E: Error, U: Unexpected Error
    --                                        x_msg_data  OUT : Error Message
    -- Return/Exit                       :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/10/06    Infosys            1.0   Initial Version
    -- ***************************************************************************


    PROCEDURE create_uom_conversion (p_from_uom_code VARCHAR2, p_to_uom_code VARCHAR2, p_item_id NUMBER
                                     , p_uom_rate NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_data OUT NOCOPY VARCHAR2)
    IS
        l_from_class              VARCHAR2 (10);
        l_to_class                VARCHAR2 (10);
        l_from_unit_of_measure    VARCHAR2 (25);
        l_to_unit_of_measure      VARCHAR2 (25);
        l_from_base_uom_flag      VARCHAR2 (1);
        l_to_base_uom_flag        VARCHAR2 (1);

        l_temp_uom                VARCHAR2 (3);
        l_temp_item_id            NUMBER;
        l_conversion_exists       VARCHAR2 (1);
        l_primary_uom_code        VARCHAR2 (3);

        l_invalid_uom_exc         EXCEPTION;
        l_uom_fromto_exc          EXCEPTION;
        l_invalid_item_exc        EXCEPTION;
        l_conversion_exists_exc   EXCEPTION;
    BEGIN
        IF (p_from_uom_code = NULL) OR (p_to_uom_code = NULL)
        THEN
            msg (' UOM_code is null ');

            RAISE l_invalid_uom_exc;
        ELSIF p_from_uom_code = p_to_uom_code
        THEN
            msg (' from and to uom codes equal ');

            RAISE l_uom_fromto_exc;
        END IF;

        BEGIN
            SELECT unit_of_measure, uom_class, base_uom_flag
              INTO l_from_unit_of_measure, l_from_class, l_from_base_uom_flag
              FROM MTL_UNITS_OF_MEASURE_VL
             WHERE     uom_code = p_from_uom_code
                   AND NVL (disable_date, TRUNC (SYSDATE) + 1) >
                       TRUNC (SYSDATE);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                msg (p_from_uom_code || ' doesnot exist ');
                RAISE l_invalid_uom_exc;
        END;


        BEGIN
            SELECT unit_of_measure, uom_class, base_uom_flag
              INTO l_to_unit_of_measure, l_to_class, l_to_base_uom_flag
              FROM MTL_UNITS_OF_MEASURE_VL
             WHERE     uom_code = p_to_uom_code
                   AND NVL (disable_date, TRUNC (SYSDATE) + 1) >
                       TRUNC (SYSDATE);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                msg (p_to_uom_code || ' doesnot exist ');
                RAISE l_invalid_uom_exc;
        END;



        IF l_from_base_uom_flag <> 'Y'
        THEN
            msg (p_to_uom_code || ' doesnot exist ');
            RAISE l_invalid_uom_exc;
        END IF;


        IF l_from_class = l_to_class
        THEN
            IF p_item_id <> 0
            THEN
                BEGIN
                    SELECT DISTINCT inventory_item_id
                      INTO l_temp_item_id
                      FROM mtl_system_items_vl
                     WHERE     inventory_item_id = p_item_id
                           AND inventory_item_id IN
                                   (SELECT DISTINCT I.inventory_item_id
                                      FROM mtl_system_items_vl I
                                     WHERE     I.enabled_flag = 'Y'
                                           AND (SYSDATE BETWEEN NVL (TRUNC (I.start_date_active), SYSDATE) AND NVL (TRUNC (I.end_date_active), SYSDATE))
                                           AND (EXISTS
                                                    (SELECT A.unit_of_measure
                                                       FROM mtl_units_of_measure A
                                                      WHERE     (   A.uom_class IN
                                                                        (SELECT to_uom_class
                                                                           FROM mtl_uom_class_conversions B
                                                                          WHERE B.inventory_item_id =
                                                                                I.inventory_item_id)
                                                                 OR A.uom_class =
                                                                    (SELECT Z.uom_class
                                                                       FROM mtl_units_of_measure Z
                                                                      WHERE Z.uom_code =
                                                                            I.primary_uom_code))
                                                            AND A.base_uom_flag <>
                                                                'Y'
                                                            AND NVL (
                                                                    A.disable_date,
                                                                      SYSDATE
                                                                    + 1) >
                                                                SYSDATE
                                                            AND A.uom_class =
                                                                NVL (
                                                                    l_to_class,
                                                                    A.uom_class))));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        msg (
                               p_item_id
                            || ' item not valid for intra class conversion ');
                        RAISE l_invalid_item_exc;
                END;



                BEGIN
                    SELECT DISTINCT x.uom_code
                      INTO l_temp_uom
                      FROM mtl_units_of_measure x
                     WHERE     x.uom_code = p_to_uom_code
                           AND x.uom_code IN
                                   (SELECT DISTINCT a.uom_code
                                      FROM mtl_units_of_measure a
                                     WHERE     (   a.uom_class IN
                                                       (SELECT to_uom_class
                                                          FROM mtl_uom_class_conversions b
                                                         WHERE b.inventory_item_id =
                                                               p_item_id)
                                                OR a.uom_class =
                                                   (SELECT DISTINCT
                                                           z.uom_class
                                                      FROM mtl_units_of_measure z, mtl_system_items_vl m
                                                     WHERE     m.inventory_item_id =
                                                               p_item_id
                                                           AND z.uom_code =
                                                               m.primary_uom_code))
                                           AND a.base_uom_flag <> 'Y'
                                           AND NVL (a.disable_date,
                                                    SYSDATE + 1) >
                                               SYSDATE);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        msg (
                               p_to_uom_code
                            || ' UOM not valid for intra class conversion ');
                        RAISE l_invalid_uom_exc;
                END;


                BEGIN
                    SELECT 'Y'
                      INTO l_conversion_exists
                      FROM mtl_uom_conversions
                     WHERE     inventory_item_id = p_item_id
                           AND uom_code = p_to_uom_code;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        msg (' Creating Intra-class conversion ');
                        l_conversion_exists   := 'N';
                END;
            ELSE
                BEGIN
                    SELECT 'Y'
                      INTO l_conversion_exists
                      FROM mtl_uom_conversions
                     WHERE inventory_item_id = 0 AND uom_code = p_to_uom_code;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        msg (' Creating Standard conversion ');
                        l_conversion_exists   := 'N';
                END;
            END IF;

            IF l_conversion_exists = 'N'
            THEN
                INSERT INTO mtl_uom_conversions (inventory_item_id,
                                                 unit_of_measure,
                                                 uom_code,
                                                 uom_class,
                                                 last_update_date,
                                                 last_updated_by,
                                                 creation_date,
                                                 created_by,
                                                 last_update_login,
                                                 conversion_rate,
                                                 default_conversion_flag)
                     VALUES (p_item_id, l_to_unit_of_measure, p_to_uom_code,
                             l_to_class, SYSDATE, fnd_global.user_id,
                             SYSDATE, fnd_global.user_id, -1,
                             p_uom_rate, 'N');
            ELSE
                msg (' Conversion already exists');
                RAISE l_conversion_exists_exc;
            END IF;
        ELSE
            IF p_item_id = 0
            THEN
                msg (
                    ' Inter-class conversion cannot be created if item_id =0');
                RAISE l_invalid_item_exc;
            ELSE
                IF l_to_base_uom_flag <> 'Y'
                THEN
                    msg (
                        ' inter class conversion cannot be done for non base units ');
                    RAISE l_invalid_uom_exc;
                END IF;

                BEGIN
                    SELECT DISTINCT inventory_item_id, primary_uom_code
                      INTO l_temp_item_id, l_primary_uom_code
                      FROM mtl_system_items_vl
                     WHERE     inventory_item_id = p_item_id
                           AND inventory_item_id IN
                                   (SELECT DISTINCT I.inventory_item_id
                                      FROM mtl_system_items_vl I
                                     WHERE     I.enabled_flag = 'Y'
                                           AND (SYSDATE BETWEEN NVL (TRUNC (I.start_date_active), SYSDATE) AND NVL (TRUNC (I.end_date_active), SYSDATE))
                                           AND (EXISTS
                                                    (SELECT A.unit_of_measure
                                                       FROM mtl_units_of_measure A
                                                      WHERE     (A.uom_class <>
                                                                 (SELECT R.uom_class
                                                                    FROM mtl_units_of_measure R
                                                                   WHERE R.uom_code =
                                                                         I.primary_uom_code))
                                                            AND A.base_uom_flag =
                                                                'Y'
                                                            AND NVL (
                                                                    A.disable_date,
                                                                      SYSDATE
                                                                    + 1) >
                                                                SYSDATE
                                                            AND A.uom_class =
                                                                NVL (
                                                                    l_to_class,
                                                                    A.uom_class))));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        msg (
                               p_item_id
                            || ' item not valid for inter class conversion ');
                        RAISE l_invalid_item_exc;
                END;

                BEGIN
                    SELECT 'Y'
                      INTO l_conversion_exists
                      FROM mtl_uom_class_conversions
                     WHERE     inventory_item_id = p_item_id
                           AND to_uom_code = p_to_uom_code;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        msg (' Creating Inter-class conversion ');
                        l_conversion_exists   := 'N';
                END;

                IF l_conversion_exists = 'N'
                THEN
                    INSERT INTO mtl_uom_class_conversions (inventory_item_id, from_unit_of_measure, from_uom_code, from_uom_class, to_unit_of_measure, to_uom_code, to_uom_class, last_update_date, last_updated_by, creation_date, created_by, last_update_login
                                                           , conversion_rate)
                         VALUES (p_item_id, l_from_unit_of_measure, p_from_uom_code, l_from_class, l_to_unit_of_measure, p_to_uom_code, l_to_class, SYSDATE, fnd_global.user_id, SYSDATE, fnd_global.user_id, -1
                                 , p_uom_rate);
                ELSE
                    msg (' inter class conversion already exists');
                    RAISE l_conversion_exists_exc;
                END IF;
            END IF;
        END IF;

        msg (
            ' successfully returned from the package create_uom_conversion ');
        x_return_status   := FND_API.G_RET_STS_SUCCESS;
    EXCEPTION
        WHEN l_conversion_exists_exc
        THEN
            x_msg_data        := 'UOM Conversion exists already';
            x_return_status   := g_chr_ret_status_warning;
        WHEN l_invalid_uom_exc
        THEN
            x_msg_data        :=
                fnd_message.get_string ('INV', 'INV_UOM_NOTFOUND');
            x_return_status   := FND_API.G_RET_STS_ERROR;
        WHEN l_invalid_item_exc
        THEN
            x_msg_data        :=
                fnd_message.get_string ('INV', 'INV_INVALID_ITEM');
            x_return_status   := FND_API.G_RET_STS_ERROR;
        WHEN l_uom_fromto_exc
        THEN
            x_msg_data        :=
                fnd_message.get_string ('INV', 'INV_LOTC_UOM_FROMTO_ERROR');
            x_return_status   := FND_API.G_RET_STS_ERROR;
        WHEN OTHERS
        THEN
            x_msg_data        := 'Unexpected error : ' || SQLERRM;
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;
    END create_uom_conversion;

    -- ***************************************************************************
    -- Procedure/Function Name  :  item_update
    --
    -- Description                       :  This is the main procedure which does the item update at the EBS side
    --
    -- parameters                      :  p_out_chr_errbuf     OUT : Error message
    --                                          p_out_chr_retcode    OUT : Execution status
    --                                         p_in_chr_debug_level  IN : Debug Level
    -- Return/Exit                       :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/10/06    Infosys            1.0   Initial Version
    --2014/12/29    Infosys             2.0   BT Remediation
    -- ***************************************************************************
    PROCEDURE item_update (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_debug_level IN VARCHAR2)
    AS
        CURSOR cur_item IS
              SELECT stg.*,
                     (SELECT mp.master_organization_id
                        FROM mtl_parameters mp
                       WHERE mp.organization_code = stg.wh_id) master_organization_id
                FROM xxdo_inv_item_int_stg stg
               WHERE     stg.process_status = 'INPROCESS'
                     AND stg.request_id = g_num_request_id
            ORDER BY stg.interface_seq_id;

        l_chr_req_failure         VARCHAR2 (1) := 'N';
        l_chr_phase               VARCHAR2 (100) := NULL;
        l_chr_status              VARCHAR2 (100) := NULL;
        l_chr_dev_phase           VARCHAR2 (100) := NULL;
        l_chr_dev_status          VARCHAR2 (100) := NULL;
        l_chr_message             VARCHAR2 (1000) := NULL;
        l_chr_primary_uom_code    VARCHAR2 (30);
        l_chr_weight_uom_code     VARCHAR2 (5);
        l_chr_dim_uom_code        VARCHAR2 (5);
        l_chr_volume_uom_code     VARCHAR2 (5);
        l_chr_case_dim_uom_code   VARCHAR2 (5);
        l_chr_return_status       VARCHAR2 (200);
        l_num_request_id          NUMBER;
        l_num_or_id               NUMBER;
        l_num_master_org          NUMBER := 0;
        l_num_count               NUMBER := 0;
        l_num_inventory_item_id   NUMBER;
        l_num_organization_id     NUMBER;
        l_num_rate                NUMBER;
        l_num_mtl                 NUMBER;
        l_bol_req_status          BOOLEAN;

        l_num_unit_weight         NUMBER;
        l_num_unit_length         NUMBER;
        l_num_unit_width          NUMBER;
        l_num_unit_height         NUMBER;
        l_num_unit_volume         NUMBER;
        l_num_case_length         NUMBER;
        l_num_case_width          NUMBER;
        l_num_case_height         NUMBER;
        l_chr_err_message         VARCHAR2 (1000);
        l_inv_org_attr_tab        g_inv_org_attr_tab_type;
        l_exe_warehouse_err       EXCEPTION;
        l_exe_invalid_item        EXCEPTION;
        l_exe_dup_proc_failure    EXCEPTION;
        l_exe_lock_failure        EXCEPTION;
    -- l_inv_item_dtl_rec                  xxdo_inv_item_int_stg%ROWTYPE;


    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        fnd_file.put_line (
            fnd_file.LOG,
               'Main program started for Item Interface:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        IF p_in_chr_debug_level = 'Y'
        THEN
            g_num_debug   := 1;
        ELSE
            g_num_debug   := 0;
        END IF;

        BEGIN
            lock_records (p_out_chr_errbuf, p_out_chr_retcode);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    := SQLERRM;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'ERROR while invoking lock records procedure : '
                    || p_out_chr_errbuf);
                RAISE l_exe_lock_failure;
        END;

        /* -- logic to process the duplicate records if only the changed values are sent
              BEGIN
                    update_duplicate_records(p_out_chr_errbuf  , p_out_chr_retcode ) ;
              EXCEPTION
                    WHEN OTHERS THEN
                    p_out_chr_retcode := '2';
                    p_out_chr_errbuf := SQLERRM;
                    FND_FILE.PUT_LINE (FND_FILE.LOG,'ERROR while invoking update duplicate records procedure : ' || p_out_chr_errbuf);
                    RAISE l_exe_dup_proc_failure;
              END;

        */
        BEGIN
            UPDATE xxdo_inv_item_int_stg stg
               SET process_status = 'IGNORED', last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE     process_status = 'INPROCESS'
                   AND request_id = g_num_request_id
                   AND item_number IN
                           (  SELECT item_number
                                --                                                           max(interface_seq_id) latest_seq_id
                                FROM xxdo_inv_item_int_stg
                               WHERE     process_status = 'INPROCESS'
                                     AND request_id = g_num_request_id
                            GROUP BY item_number
                              HAVING COUNT (1) > 1)
                   AND interface_seq_id NOT IN
                           (  SELECT MAX (interface_seq_id)
                                FROM xxdo_inv_item_int_stg
                               WHERE     process_status = 'INPROCESS'
                                     AND request_id = g_num_request_id
                            GROUP BY item_number
                              HAVING COUNT (1) > 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    := SQLERRM;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'ERROR while updating duplicate records : '
                    || p_out_chr_errbuf);
                RAISE l_exe_dup_proc_failure;
        END;


        COMMIT;

        FOR rec_cur_item IN cur_item
        LOOP
            BEGIN
                --Get organization id

                l_num_organization_id     := NULL;

                BEGIN
                    SELECT mp.organization_id
                      INTO l_num_organization_id
                      FROM fnd_lookup_values flv, mtl_parameters mp
                     WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                           AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                               USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (end_date_active,
                                                    SYSDATE + 1)
                           AND mp.organization_code = flv.lookup_code
                           AND flv.lookup_code = rec_cur_item.wh_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_organization_id   := NULL;
                END;

                IF l_num_organization_id IS NULL
                THEN
                    RAISE l_exe_warehouse_err;
                END IF;


                l_num_inventory_item_id   := NULL;
                l_chr_primary_uom_code    := NULL;

                --check whether item is valid
                BEGIN
                    SELECT inventory_item_id, primary_uom_code, unit_weight,
                           weight_uom_code, unit_length, unit_width,
                           unit_height, dimension_uom_code, volume_uom_code
                      INTO l_num_inventory_item_id, l_chr_primary_uom_code, l_num_unit_weight, l_chr_weight_uom_code,
                                                  l_num_unit_length, l_num_unit_width, l_num_unit_height,
                                                  l_chr_dim_uom_code, l_chr_volume_uom_code
                      FROM mtl_system_items_b
                     WHERE     organization_id = l_num_organization_id
                           AND segment1 = rec_cur_item.item_number; --Added for BT Remediation
                /*commented for BT Remediation
                    AND segment1 = REGEXP_SUBSTR (rec_cur_item.item_number,  '[^-]+', 1 , 1)
                    AND segment2 = REGEXP_SUBSTR (rec_cur_item.item_number,  '[^-]+', 1 , 2)
                    AND segment3 = REGEXP_SUBSTR (rec_cur_item.item_number,  '[^-]+', 1 , 3); */
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_inventory_item_id   := NULL;
                        l_chr_primary_uom_code    := NULL;
                        l_num_unit_weight         := NULL;
                        l_chr_weight_uom_code     := 'Lbs';
                        l_num_unit_length         := NULL;
                        l_num_unit_width          := NULL;
                        l_num_unit_height         := NULL;
                        l_chr_dim_uom_code        := 'IN';
                        l_chr_volume_uom_code     := 'IN3';
                END;

                IF l_num_inventory_item_id IS NULL
                THEN
                    RAISE l_exe_invalid_item;
                END IF;

                -- l_inv_item_dtl_rec.inventory_item_id := l_num_inventory_item_id;

                /*insert into interface table*/
                IF     (rec_cur_item.each_weight IS NOT NULL OR rec_cur_item.each_length IS NOT NULL OR rec_cur_item.each_width IS NOT NULL OR rec_cur_item.each_height IS NOT NULL)
                   AND (NVL (rec_cur_item.each_weight, -1) <> NVL (l_num_unit_weight, -1) OR NVL (rec_cur_item.each_length, -1) <> NVL (l_num_unit_length, -1) OR NVL (rec_cur_item.each_width, -1) <> NVL (l_num_unit_width, -1) OR NVL (rec_cur_item.each_height, -1) <> NVL (l_num_unit_height, -1))
                THEN
                    -- Logic to derive the unit volume
                    IF    rec_cur_item.each_length IS NOT NULL
                       OR rec_cur_item.each_width IS NOT NULL
                       OR rec_cur_item.each_height IS NOT NULL
                    THEN
                        l_num_unit_volume   :=
                              NVL (rec_cur_item.each_length,
                                   l_num_unit_length)
                            * NVL (rec_cur_item.each_width, l_num_unit_width)
                            * NVL (rec_cur_item.each_height,
                                   l_num_unit_height);

                        IF     l_chr_volume_uom_code IS NULL
                           AND l_num_unit_volume IS NOT NULL
                        THEN
                            l_chr_volume_uom_code   := 'IN3';
                        END IF;
                    ELSE
                        l_chr_volume_uom_code   := NULL;
                        l_num_unit_volume       := NULL;
                    END IF;

                    l_num_master_org   := rec_cur_item.master_organization_id;

                    BEGIN
                        INSERT INTO mtl_system_items_interface (
                                        organization_id,
                                        --                                                                       organization_code,
                                        inventory_item_id,
                                        unit_length,
                                        unit_width,
                                        unit_height,
                                        dimension_uom_code,
                                        unit_weight,
                                        weight_uom_code,
                                        unit_volume,
                                        volume_uom_code,
                                        set_process_id,
                                        transaction_type,
                                        process_flag,
                                        last_update_date,
                                        last_updated_by,
                                        creation_date,
                                        created_by,
                                        last_update_login)
                                 VALUES (rec_cur_item.master_organization_id,
                                         --                                                                       'VNT',--rec_cur_item.wh_id,
                                         l_num_inventory_item_id,
                                         rec_cur_item.each_length,
                                         rec_cur_item.each_width,
                                         rec_cur_item.each_height,
                                         NVL (l_chr_dim_uom_code, 'IN'),
                                         rec_cur_item.each_weight,
                                         NVL (l_chr_weight_uom_code, 'Lbs'),
                                         l_num_unit_volume,
                                         l_chr_volume_uom_code,
                                         g_num_request_id,
                                         'UPDATE',
                                         1,
                                         SYSDATE,
                                         g_num_user_id,
                                         SYSDATE,
                                         g_num_user_id,
                                         g_num_login_id);

                        l_num_count   := SQL%ROWCOUNT;
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_req_failure   := 'Y';
                            p_out_chr_retcode   := 2;
                            p_out_chr_errbuf    :=
                                   'Error occured for interface table insert '
                                || SQLERRM;
                            msg (p_out_chr_errbuf);
                            ROLLBACK;
                    END;
                END IF;

                --update the case records

                IF    rec_cur_item.case_length IS NOT NULL
                   OR rec_cur_item.case_width IS NOT NULL
                   OR rec_cur_item.case_height IS NOT NULL
                   OR rec_cur_item.units_per_case IS NOT NULL
                THEN
                    l_num_rate          := NULL;
                    l_num_case_length   := NULL;
                    l_num_case_width    := NULL;
                    l_num_case_height   := NULL;

                    BEGIN
                        SELECT conversion_rate, LENGTH, width,
                               height, dimension_uom
                          INTO l_num_rate, l_num_case_length, l_num_case_width, l_num_case_height,
                                         l_chr_case_dim_uom_code
                          FROM mtl_uom_conversions
                         WHERE     uom_code = 'CSE'
                               AND inventory_item_id =
                                   l_num_inventory_item_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_num_rate                := NULL;
                            l_num_case_length         := NULL;
                            l_num_case_width          := NULL;
                            l_num_case_height         := NULL;
                            l_chr_case_dim_uom_code   := 'IN';
                    END;

                    IF rec_cur_item.units_per_case IS NOT NULL
                    THEN
                        IF l_num_rate IS NULL
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'Creating new UOM Conversion');

                            create_uom_conversion (
                                --                                'CSE' ,
                                l_chr_primary_uom_code,
                                'CSE',
                                l_num_inventory_item_id,
                                rec_cur_item.units_per_case,
                                l_chr_return_status,
                                l_chr_message);

                            --- Process status update for new UOM Creation
                            IF l_chr_return_status IN
                                   (g_chr_ret_status_warning, FND_API.G_RET_STS_ERROR, FND_API.G_RET_STS_UNEXP_ERROR)
                            THEN
                                UPDATE xxdo_inv_item_int_stg xii
                                   SET process_status = 'ERROR', error_message = l_chr_message, last_update_date = SYSDATE
                                 WHERE     request_id = g_num_request_id
                                       AND process_status = 'INPROCESS'
                                       AND item_number =
                                           rec_cur_item.item_number
                                       AND wh_id = rec_cur_item.wh_id;
                            END IF;
                        ELSIF NVL (l_num_rate, -1) <>
                              NVL (rec_cur_item.units_per_case, -1)
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Updating the UOM Conversion rate');

                            UPDATE mtl_uom_conversions
                               SET conversion_rate = rec_cur_item.units_per_case
                             WHERE     inventory_item_id =
                                       l_num_inventory_item_id
                                   AND uom_code = 'CSE';
                        END IF;
                    END IF;     -- Check whether the conversion rate is passed

                    IF     (rec_cur_item.case_length IS NOT NULL OR rec_cur_item.case_width IS NOT NULL OR rec_cur_item.case_height IS NOT NULL)
                       AND (NVL (rec_cur_item.case_length, -1) <> NVL (l_num_case_length, -1) OR NVL (rec_cur_item.case_width, -1) <> NVL (l_num_case_width, -1) OR NVL (rec_cur_item.case_height, -1) <> NVL (l_num_case_height, -1))
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Updating the Case Dimensions');

                        UPDATE mtl_uom_conversions
                           SET LENGTH = rec_cur_item.case_length, width = rec_cur_item.case_width, height = rec_cur_item.case_height,
                               dimension_uom = NVL (l_chr_case_dim_uom_code, 'IN')
                         WHERE     inventory_item_id =
                                   l_num_inventory_item_id
                               AND uom_code = 'CSE';
                    END IF;

                    -- Update the process status if the item attributes are not passed

                    IF     NOT (rec_cur_item.each_weight IS NOT NULL OR rec_cur_item.each_length IS NOT NULL OR rec_cur_item.each_width IS NOT NULL OR rec_cur_item.each_height IS NOT NULL)
                       AND (NVL (rec_cur_item.each_weight, -1) <> NVL (l_num_unit_weight, -1) OR NVL (rec_cur_item.each_length, -1) <> NVL (l_num_unit_length, -1) OR NVL (rec_cur_item.each_width, -1) <> NVL (l_num_unit_width, -1) OR NVL (rec_cur_item.each_height, -1) <> NVL (l_num_unit_height, -1))
                    THEN
                        UPDATE xxdo_inv_item_int_stg xii
                           SET process_status = 'PROCESSED', last_update_date = SYSDATE
                         WHERE     request_id = g_num_request_id
                               AND process_status = 'INPROCESS'
                               AND item_number = rec_cur_item.item_number
                               AND wh_id = rec_cur_item.wh_id;
                    END IF;

                    -- Commit the case level changes
                    COMMIT;
                END IF;      -- check whether case related fields are not null
            EXCEPTION
                WHEN l_exe_warehouse_err
                THEN
                    UPDATE xxdo_inv_item_int_stg xii
                       SET process_status = 'ERROR', error_message = 'Warehouse is not WMS Enabled', last_update_date = SYSDATE,
                           org_id = l_num_organization_id
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND item_number = rec_cur_item.item_number
                           AND wh_id = rec_cur_item.wh_id;
                WHEN l_exe_invalid_item
                THEN
                    UPDATE xxdo_inv_item_int_stg xii
                       SET process_status = 'ERROR', error_message = 'Inventory Item is not valid', last_update_date = SYSDATE,
                           org_id = l_num_organization_id
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND item_number = rec_cur_item.item_number
                           AND wh_id = rec_cur_item.wh_id;
                WHEN OTHERS
                THEN
                    l_chr_err_message   := SQLERRM;

                    UPDATE xxdo_inv_item_int_stg xii
                       SET process_status = 'ERROR', error_message = 'Unexpected error : ' || l_chr_err_message, last_update_date = SYSDATE,
                           org_id = l_num_organization_id, inventory_item_id = l_num_inventory_item_id
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND item_number = rec_cur_item.item_number
                           AND wh_id = rec_cur_item.wh_id;
            END;

            -- Updating the id columns
            BEGIN
                UPDATE xxdo_inv_item_int_stg xii
                   SET inventory_item_id = l_num_inventory_item_id, org_id = l_num_organization_id
                 WHERE     request_id = g_num_request_id
                       AND process_status = 'INPROCESS'
                       AND item_number = rec_cur_item.item_number
                       AND wh_id = rec_cur_item.wh_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;                                               -- Main cursor

        COMMIT;

        --Submit Item Import Program
        IF l_num_count > 0
        THEN
            l_num_request_id    :=
                fnd_request.submit_request (application   => 'INV',
                                            program       => 'INCOIN',
                                            argument1     => l_num_master_org, --Organization id
                                            argument2     => 1, --All organizations
                                            argument3     => 1, --Validate Items
                                            argument4     => 1, --Process Items
                                            --argument5        => 2,                                  --Delete Processed Rows
                                            argument5     => 1, --Delete Processed Rows
                                            argument6     => g_num_request_id, --Item Set to be processed
                                            argument7     => 2, --CREATE new Items or UPDATE existing Items
                                            description   => NULL,
                                            start_time    => NULL);
            COMMIT;

            IF l_num_request_id = 0
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   ' Concurrent Request is not launched');
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                    'One or more Child requests are not launched. Please refer the log file for more details';
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Concurrent Request ID : ' || l_num_request_id);
            END IF;

            COMMIT;

            l_chr_req_failure   := 'N';
            fnd_file.put_line (fnd_file.LOG, '');
            fnd_file.put_line (
                fnd_file.LOG,
                '-------------Concurrent Requests Status Report ---------------');

            l_bol_req_status    :=
                fnd_concurrent.wait_for_request (l_num_request_id,
                                                 10,
                                                 0,
                                                 l_chr_phase,
                                                 l_chr_status,
                                                 l_chr_dev_phase,
                                                 l_chr_dev_status,
                                                 l_chr_message);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Concurrent request ID : '
                || l_num_request_id
                || CHR (9)
                || ' Phase: '
                || l_chr_phase
                || CHR (9)
                || ' Status: '
                || l_chr_status
                || CHR (9)
                || ' Dev Phase: '
                || l_chr_dev_phase
                || CHR (9)
                || ' Dev Status: '
                || l_chr_dev_status
                || CHR (9)
                || ' Message: '
                || l_chr_message);
        END IF;

        --Update status accordingly in the staging table
        UPDATE xxdo_inv_item_int_stg xii
           SET process_status     = 'ERROR',
               last_update_date   = SYSDATE,
               error_message     =
                   (SELECT error_message
                      FROM mtl_interface_errors mie, mtl_system_items_interface msii
                     WHERE     msii.set_process_id = g_num_request_id
                           AND msii.inventory_item_id = xii.inventory_item_id
                           AND msii.transaction_id = mie.transaction_id
                           AND msii.process_flag = 3
                           AND ROWNUM = 1)
         WHERE     request_id = g_num_request_id
               AND process_status = 'INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM mtl_system_items_interface msii
                         WHERE     msii.set_process_id = g_num_request_id
                               AND msii.inventory_item_id =
                                   xii.inventory_item_id
                               AND msii.process_flag = 3);

        UPDATE xxdo_inv_item_int_stg xii
           SET process_status = 'PROCESSED', error_message = NULL, last_update_date = SYSDATE
         WHERE request_id = g_num_request_id AND process_status = 'INPROCESS';

        COMMIT;
    EXCEPTION
        WHEN l_exe_dup_proc_failure
        THEN
            NULL;
        WHEN l_exe_lock_failure
        THEN
            NULL;
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := 2;
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error occured in item update due to  ' || SQLERRM);
    END item_update;

    PROCEDURE insert_item_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_item_tab IN item_dimensions_obj_tab_type)
    IS
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        IF p_in_item_tab.EXISTS (1)
        THEN
            FOR l_num_index IN p_in_item_tab.FIRST .. p_in_item_tab.LAST
            LOOP
                INSERT INTO xxdo_inv_item_int_stg (wh_id,
                                                   datetime,
                                                   item_number,
                                                   case_length,
                                                   case_width,
                                                   case_height,
                                                   case_weight,
                                                   each_length,
                                                   each_width,
                                                   each_height,
                                                   each_weight,
                                                   cases_per_pallet,
                                                   units_per_case,
                                                   process_status,
                                                   error_message,
                                                   request_id,
                                                   creation_date,
                                                   created_by,
                                                   last_update_date,
                                                   last_updated_by,
                                                   last_update_login,
                                                   source_type,
                                                   attribute1,
                                                   attribute2,
                                                   attribute3,
                                                   attribute4,
                                                   attribute5,
                                                   attribute6,
                                                   attribute7,
                                                   attribute8,
                                                   attribute9,
                                                   attribute10,
                                                   attribute11,
                                                   attribute12,
                                                   attribute13,
                                                   attribute14,
                                                   attribute15,
                                                   attribute16,
                                                   attribute17,
                                                   attribute18,
                                                   attribute19,
                                                   attribute20,
                                                   source,
                                                   destination,
                                                   record_type,
                                                   inventory_item_id,
                                                   org_id,
                                                   interface_seq_id)
                         VALUES (
                                    p_in_item_tab (l_num_index).wh_id,
                                    p_in_item_tab (l_num_index).datetime,
                                    p_in_item_tab (l_num_index).item_number,
                                    p_in_item_tab (l_num_index).case_length,
                                    p_in_item_tab (l_num_index).case_width,
                                    p_in_item_tab (l_num_index).case_height,
                                    p_in_item_tab (l_num_index).case_weight,
                                    p_in_item_tab (l_num_index).each_length,
                                    p_in_item_tab (l_num_index).each_width,
                                    p_in_item_tab (l_num_index).each_height,
                                    p_in_item_tab (l_num_index).each_weight,
                                    p_in_item_tab (l_num_index).cases_per_pallet,
                                    p_in_item_tab (l_num_index).units_per_case,
                                    NVL (
                                        p_in_item_tab (l_num_index).process_status,
                                        'NEW'),
                                    p_in_item_tab (l_num_index).error_message,
                                    p_in_item_tab (l_num_index).request_id,
                                    NVL (
                                        p_in_item_tab (l_num_index).creation_date,
                                        SYSDATE),
                                    NVL (
                                        p_in_item_tab (l_num_index).created_by,
                                        g_num_user_id),
                                    NVL (
                                        p_in_item_tab (l_num_index).last_update_date,
                                        SYSDATE),
                                    NVL (
                                        p_in_item_tab (l_num_index).last_updated_by,
                                        g_num_user_id),
                                    NVL (
                                        p_in_item_tab (l_num_index).last_update_login,
                                        g_num_login_id),
                                    p_in_item_tab (l_num_index).source_type,
                                    p_in_item_tab (l_num_index).attribute1,
                                    p_in_item_tab (l_num_index).attribute2,
                                    p_in_item_tab (l_num_index).attribute3,
                                    p_in_item_tab (l_num_index).attribute4,
                                    p_in_item_tab (l_num_index).attribute5,
                                    p_in_item_tab (l_num_index).attribute6,
                                    p_in_item_tab (l_num_index).attribute7,
                                    p_in_item_tab (l_num_index).attribute8,
                                    p_in_item_tab (l_num_index).attribute9,
                                    p_in_item_tab (l_num_index).attribute10,
                                    p_in_item_tab (l_num_index).attribute11,
                                    p_in_item_tab (l_num_index).attribute12,
                                    p_in_item_tab (l_num_index).attribute13,
                                    p_in_item_tab (l_num_index).attribute14,
                                    p_in_item_tab (l_num_index).attribute15,
                                    p_in_item_tab (l_num_index).attribute16,
                                    p_in_item_tab (l_num_index).attribute17,
                                    p_in_item_tab (l_num_index).attribute18,
                                    p_in_item_tab (l_num_index).attribute19,
                                    p_in_item_tab (l_num_index).attribute20,
                                    NVL (p_in_item_tab (l_num_index).source,
                                         'WMS'),
                                    NVL (
                                        p_in_item_tab (l_num_index).destination,
                                        'EBS'),
                                    p_in_item_tab (l_num_index).record_type,
                                    p_in_item_tab (l_num_index).inventory_item_id,
                                    p_in_item_tab (l_num_index).org_id,
                                    xxdo_inv_item_int_stg_s.NEXTVAL);
            END LOOP;
        END IF;                     -- Check whether atleast one record exists
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := 2;
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error occured in item update due to  ' || SQLERRM);
    END insert_item_records;
/*
PROCEDURE update_duplicate_records(p_out_chr_errbuf   OUT VARCHAR2,
                                                        p_out_chr_retcode OUT VARCHAR2
                                                        )
IS

l_num_latest_length NUMBER;
l_num_latest_width NUMBER;
l_num_latest_height NUMBER;
l_num_latest_weight NUMBER;

l_num_current_length NUMBER;
l_num_current_width NUMBER;
l_num_current_height NUMBER;
l_num_current_weight NUMBER;

CURSOR cur_dup_latest_records
         IS
 SELECT item_number,
            max(interface_seq_id) latest_seq_id
    FROM xxdo_inv_item_int_stg
 WHERE process_status = 'INPROCESS'
      AND request_id = g_num_request_id
GROUP BY item_number
HAVING COUNT(1) > 1;

CURSOR cur_dup_records (p_chr_item_number IN VARCHAR2,
                                        p_num_latest_seq_id IN NUMBER)
         IS
 SELECT interface_seq_id,
             each_length,
             each_width,
             each_height,
             each_weight
    FROM xxdo_inv_item_int_stg
 WHERE process_status = 'INPROCESS'
      AND request_id = g_num_request_id
      AND item_number = p_chr_item_number
      AND interface_seq_id <> p_num_latest_seq_id
  ORDER BY interface_seq_id DESC;

BEGIN
        p_out_chr_errbuf := NULL;
        p_out_chr_retcode := '0';

        FOR dup_latest_records IN cur_dup_latest_records
        LOOP

            SELECT each_length,
                        each_width,
                        each_height,
                        each_weight
                INTO l_num_latest_length,
                        l_num_latest_width,
                        l_num_latest_height,
                        l_num_latest_weight
               FROM xxdo_inv_item_int_stg
            WHERE interface_seq_id =  dup_latest_records.latest_seq_id;

            FOR dup_records IN cur_dup_records (dup_latest_records.item_number,
                                                                    dup_latest_records.latest_seq_id)
            LOOP

                l_num_current_length :=  dup_records.each_length;
                l_num_current_width :=  dup_records.each_width;
                l_num_current_height :=  dup_records.each_height;
                l_num_current_weight :=  dup_records.each_weight;

                IF l_num_latest_length IS NOT NULL AND l_num_current_length IS NOT NULL THEN
                    l_num_current_length := NULL;
                ELSIF l_num_latest_length IS NULL AND l_num_current_length IS NOT NULL THEN
                    l_num_latest_length := l_num_current_length;
                END IF;

                IF l_num_latest_width IS NOT NULL AND l_num_current_width IS NOT NULL THEN
                    l_num_current_width := NULL;
                ELSIF l_num_latest_width IS NULL AND l_num_current_width IS NOT NULL THEN
                    l_num_latest_width := l_num_current_width;
                END IF;

                IF l_num_latest_height IS NOT NULL AND l_num_current_height IS NOT NULL THEN
                    l_num_current_height := NULL;
                ELSIF l_num_latest_height IS NULL AND l_num_current_height IS NOT NULL THEN
                    l_num_latest_height := l_num_current_height;
                END IF;

                IF l_num_latest_weight IS NOT NULL AND l_num_current_weight IS NOT NULL THEN
                    l_num_current_weight := NULL;
                ELSIF l_num_latest_weight IS NULL AND l_num_current_weight IS NOT NULL THEN
                    l_num_latest_weight := l_num_current_weight;
                END IF;

                UPDATE xxdo_inv_item_int_stg
                     SET each_length = l_num_current_length,
                            each_width = l_num_current_width,
                            each_height = l_num_current_height,
                            each_weight = l_num_current_weight
                WHERE interface_seq_id =  dup_records.interface_seq_id;

            END LOOP;

                UPDATE xxdo_inv_item_int_stg
                     SET each_length = l_num_latest_length,
                            each_width = l_num_latest_width,
                            each_height = l_num_latest_height,
                            each_weight = l_num_latest_weight
                WHERE interface_seq_id =  dup_latest_records.latest_seq_id;

        END LOOP;


      UPDATE xxdo_inv_item_int_stg
          SET process_status = 'IGNORED'
     WHERE process_status = 'INPROCESS'
          AND request_id = g_num_request_id
            AND  case_length    IS NULL
            AND    case_width    IS NULL
            AND    case_height    IS NULL
            AND    each_length    IS NULL
            AND    each_width    IS NULL
            AND    each_height    IS NULL
            AND    each_weight    IS NULL
            AND    units_per_case    IS NULL;

EXCEPTION
    WHEN OTHERS THEN
            p_out_chr_retcode := '2';
            p_out_chr_errbuf := SQLERRM;
            FND_FILE.PUT_LINE (FND_FILE.LOG,'ERROR in update duplicate records procedure : ' || p_out_chr_errbuf);
END update_duplicate_records;
*/

END xxdo_inv_item_int_pkg;
/


GRANT EXECUTE ON APPS.XXDO_INV_ITEM_INT_PKG TO SOA_INT
/
