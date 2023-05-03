--
-- XXD_WMS_GENERATE_PALLET_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_GENERATE_PALLET_PKG"
AS
    PROCEDURE create_pallet_lpns (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        l_return_status          VARCHAR2 (200);
        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (200);
        p_lpn_id_out             NUMBER;
        p_lpn_out                NUMBER;
        p_process_id             NUMBER;
        l_organization_id        NUMBER;
        l_license_plate_number   VARCHAR2 (30 BYTE);
        l_length                 NUMBER;
        -- Process Counters
        ln_loop_count            NUMBER := 0;
        ln_success_count         NUMBER := 0;
        ln_error_count           NUMBER := 0;
        ln_commit_count          NUMBER := 0;
        --BT Tech Team
        ln_msg_ct                NUMBER;
        l_output                 VARCHAR2 (2000);

        --BT Tech Team


        CURSOR c1 IS
            SELECT DISTINCT org_id, pallet, pallet_length
              FROM xxd_inv_item_onhand_lpn_stg_t;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || '--------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || 'Start of Procedure: APPS.XXD_WMS_GENERATE_LPN_PKG.CREATE_CASE_LPNS');
        fnd_global.apps_initialize (2130, 21676, 385);
        ---BT_WMS_INSTALL, WAREHOUSE MANAGEMENT, WAREHOUSE MANAGER---
        fnd_msg_pub.initialize;

        FOR i IN c1
        LOOP
            l_organization_id        := i.org_id;
            l_license_plate_number   := i.pallet;
            l_length                 := i.pallet_length;
            wms_container_pub.generate_lpn (
                p_api_version        => 1.0                    --p_api_version
                                           ,
                p_init_msg_list      => fnd_api.g_false      --p_init_msg_list
                                                       ,
                p_commit             => fnd_api.g_false             --p_commit
                                                       ,
                p_validation_level   => fnd_api.g_valid_level_full--p_validation_level
                                                                  ,
                x_return_status      => l_return_status,
                x_msg_count          => l_msg_count,
                x_msg_data           => l_msg_data,
                p_organization_id    => l_organization_id  --p_organization_id
                                                         ,
                p_starting_num       => l_license_plate_number--p_starting_num
                                                              ,
                p_quantity           => 1,
                p_source             => 5        --LPN Context of Pregenerated
                                         ,
                p_lpn_id_out         => p_lpn_id_out,
                p_lpn_out            => p_lpn_out,
                p_process_id         => p_process_id,
                p_total_length       => l_length);
            ln_loop_count            := ln_loop_count + 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   TO_CHAR (SYSDATE, 'HH24:MI:SS')
                || ': Return Status '
                || l_license_plate_number
                || ' - '
                || l_return_status);

            --
            IF l_return_status = fnd_api.g_ret_sts_success
            THEN
                ln_success_count   := ln_success_count + 1;
                ln_commit_count    := ln_commit_count + 1;
            ELSE
                ln_error_count   := ln_error_count + 1;
                --         Write Error to log
                fnd_file.put_line (
                    fnd_file.LOG,
                    TO_CHAR (SYSDATE, 'HH24:MI:SS') || ':    Error Message: ');

                -- BT Tech team
                IF l_msg_count > 0
                THEN
                    FOR j IN 1 .. l_msg_count
                    LOOP
                        fnd_msg_pub.get (j, FND_API.G_FALSE, l_msg_data,
                                         ln_msg_ct);
                        l_output   :=
                            ('Msg' || TO_CHAR (j) || ': ' || l_msg_data);
                        fnd_file.put_line (fnd_file.LOG,
                                           (SUBSTR (l_output, 1, 255)));
                    END LOOP;
                END IF;



                fnd_file.put_line (fnd_file.LOG,
                                   'x_return_status = ' || l_return_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'x_msg_count = ' || TO_CHAR (l_msg_count));
                fnd_file.put_line (fnd_file.LOG,
                                   'x_msg_data = ' || l_msg_data);
            --BT Tech Team -- added error log



            END IF;

            IF ln_commit_count = 2000
            THEN
                COMMIT;
                ln_commit_count   := 0;
            END IF;
        --
        --
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || '--------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || ': Total Records in Staging Table: '
            || ln_loop_count);
        fnd_file.put_line (
            fnd_file.LOG,
               TO_CHAR (SYSDATE, 'HH24:MI:SS')
            || ': Successful: '
            || ln_success_count);
        fnd_file.put_line (
            fnd_file.LOG,
            TO_CHAR (SYSDATE, 'HH24:MI:SS') || ': Errors: ' || ln_error_count);
        fnd_file.put_line (
            fnd_file.LOG,
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
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in xxd_wms_generate_pallet_pkg' || SQLERRM);
    END;
END xxd_wms_generate_pallet_pkg;
/
