--
-- XXDOINT_INV_PROD_CAT_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINT_INV_PROD_CAT_UTILS"
AS
    /****************************************************************************
     * PACKAGE Name    : XXDOINT_INV_PROD_CAT_UTILS
     *
     * Description       : The purpose of this package to capture the CDC
     *                     for Product and raise business for SOA.
     *
     * INPUT Parameters  :
     *
     * OUTPUT Parameters :
     *
     * DEVELOPMENT and MAINTENANCE HISTORY
     *
     * ======================================================================================
     * Date         Version#   Name                    Comments
     * ======================================================================================
     * 04-Apr-2016   1.0                                Initial Version
     * 10-Jun-2020   1.1        Aravind Kannuri         Updated for CCR0007740
     * 05-Jun-2020   1.2        Viswanathan Pandian     Updated for CCR0009133
     * 08-Sep-2020   1.2        Aravind Kannuri         Updated for CCR0008880
     * 19-Nov-2020   1.3        Aravind Kannuri         Updated for CCR0009029
     * 27-July-2021  1.4        Gaurav Joshi            Updated for CCR0009447
     * 11-Sep-2021   2.0        Shivanshu               Modified for 19C Upgrade CCR0009596
  * 11-Jan-2023   2.1        Shivanshu               Updated for CCR0010301
     ******************************************************************************************/
    G_PKG_NAME                     CONSTANT VARCHAR2 (40) := 'XXDOINT_INV_PROD_CAT_UTILS';
    G_CDC_SUBSTRIPTION_NAME        CONSTANT VARCHAR2 (40)
                                                := 'XXDOINT_INV_PRODUCT_SUB' ;
    G_ITEM_UPDATE_EVENT            CONSTANT VARCHAR2 (40)
        := 'oracle.apps.xxdo.inventory_item_update' ;
    --Start changes for CCR0009029
    G_SEASON_SUBSTRIPTION_NAME     CONSTANT VARCHAR2 (40)
                                                := 'XXD_INV_PROD_SEASON_SUB' ;
    G_ITEM_SEASON_UPD_EVENT        CONSTANT VARCHAR2 (40)
        := 'oracle.apps.xxdo.inv_prod_season_update' ;

    --End changes for CCR0009029

    --Start changes for CCR0008880
    gn_item_batch_threads          CONSTANT NUMBER := 2;
    gn_item_batch_throttle         CONSTANT NUMBER := 60;
    gn_item_batch_split_throttle   CONSTANT NUMBER := 60;
    gn_item_event_throttle         CONSTANT NUMBER := 300;
    gn_mst_inv_org_id                       NUMBER
                                                := xxd_get_inv_org_id ('MST');

    --End changes for CCR0008880



    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
    END;

    FUNCTION in_conc_request
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN apps.fnd_global.conc_request_id != -1;
    END;

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.purge_batch';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            SAVEPOINT before_prd_purge;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                msg (' ready to delete batch records.');

                --Start Added as per CCR0008880
                --To Insert Batch History prior Delete
                BEGIN
                    INSERT INTO xxdo.xxd_inv_prd_cat_upd_bat_hist_t
                        (SELECT *
                           FROM xxdo.xxdoint_inv_prd_cat_upd_batch
                          WHERE batch_id = p_batch_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                --End Added as per CCR0008880

                DELETE FROM xxdo.xxdoint_inv_prd_cat_upd_batch
                      WHERE batch_id = p_batch_id;


                DELETE FROM
                    xxdo.xxdoint_inv_prd_cat_upd_batch
                      WHERE BATCH_DATE <
                              SYSDATE
                            - NVL (
                                  fnd_profile.VALUE (
                                      'XXD_PRODUCT_BATCH_PURG_DAYS'),
                                  5);

                DELETE FROM
                    xxdo.xxd_inv_mtl_item_categories_t
                      WHERE BATCH_DATE <
                              SYSDATE
                            - NVL (
                                  fnd_profile.VALUE (
                                      'XXD_PRODUCT_BATCH_PURG_DAYS'),
                                  5);


                DELETE FROM
                    xxdo.xxd_inv_mtl_categories_t
                      WHERE BATCH_DATE <
                              SYSDATE
                            - NVL (
                                  fnd_profile.VALUE (
                                      'XXD_PRODUCT_BATCH_PURG_DAYS'),
                                  5);


                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' record(s) from the batch table.');

                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_prd_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END purge_batch;


    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.purge_old_batches';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_hours_old=' || p_hours_old);

        BEGIN
            SAVEPOINT before_prd_purge;

            IF p_hours_old IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A time threshhold was not specified.';
            ELSE
                msg (' ready to delete batch records.');

                DELETE FROM xxdo.xxdoint_inv_prd_cat_upd_batch
                      WHERE batch_date < SYSDATE - (p_hours_old / 24);

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' record(s) from the batch table.');

                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_prd_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE process_update_batch (
        p_raise_event          IN     VARCHAR2 := 'Y',
        p_raise_season_event   IN     VARCHAR2 := 'Y', --Added as per CCR0009029
        x_batch_id                OUT NUMBER,
        x_ret_stat                OUT VARCHAR2,
        x_error_messages          OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_proc_name                    VARCHAR2 (80) := G_PKG_NAME || '.process_update_batch';
        l_bus_event_result             VARCHAR2 (20);
        l_cnt                          NUMBER;
        l_tot_cnt                      NUMBER;
        ln_before                      NUMBER;
        ln_after                       NUMBER;
        ln_before_purge                NUMBER;
        ln_after_purge                 NUMBER;

        --Start changes for CCR0008880
        ln_batch_threads               NUMBER;
        ln_max_batch_cnt               NUMBER;
        ln_batch_list                  SYS.ODCINUMBERLIST;
        ln_split_idx                   NUMBER;
        ln_split                       NUMBER := 0;
        ln_style_cnt                   NUMBER := 0;
        ln_loop_cntr                   NUMBER := 0;
        ln_batch_throttle_time         NUMBER := gn_item_batch_throttle;
        ln_split_batch_throttle_time   NUMBER := gn_item_batch_split_throttle;
        ln_item_event_throttle         NUMBER := gn_item_event_throttle;
        lx_new_batch_id                NUMBER;
        ln_split_batch_time            NUMBER;
        ln_dt_days                     NUMBER := 1;  --Added as per CCR0009133
        ln_process_batch_id            NUMBER;

        --End changes for CCR0008880

        --CURSOR c_batch_output  --Commented as per CCR0008880
        CURSOR c_batch_output (p_batch_id IN NUMBER  --Added as per CCR0008880
                                                   )
        IS
              SELECT mp.organization_code, mcb.segment1 AS brand, COUNT (1) AS itm_cnt
                FROM xxdo.xxdoint_inv_prd_cat_upd_batch prd_batch
                     INNER JOIN inv.mtl_parameters mp
                         ON mp.organization_id = prd_batch.organization_id
                     INNER JOIN inv.mtl_item_categories mic
                         --on mic.category_set_id = 1                    --commented by BT Team on 15/01/2015
                         ON     mic.category_set_id =
                                (SELECT category_set_id
                                   FROM mtl_category_sets
                                  WHERE category_set_name = 'Inventory') --Added by BT team on 15/01/2015
                            AND mic.organization_id = prd_batch.organization_id
                            AND mic.inventory_item_id =
                                prd_batch.inventory_item_id
                     INNER JOIN inv.mtl_categories_b mcb
                         ON mcb.category_id = mic.category_id
               --WHERE prd_batch.batch_id = x_batch_id       --Commented as per CCR0008880
               WHERE prd_batch.batch_id = p_batch_id --Added as per CCR0008880
            GROUP BY mp.organization_code, mcb.segment1
            ORDER BY mp.organization_code, mcb.segment1;

        --Start Added as per CCR0008880
        CURSOR get_style_batches (p_batch_id IN NUMBER)
        IS
              SELECT DISTINCT
                     SUBSTR (segment1, 1, INSTR (segment1, '-', -1) - 1) style_color
                FROM xxdoint_inv_prd_cat_upd_batch prd_btch, mtl_system_items_b msib
               WHERE     1 = 1
                     AND prd_btch.inventory_item_id = msib.inventory_item_id
                     AND prd_btch.batch_id = p_batch_id
            ORDER BY 1;
    --End Added as per CCR0008880

    BEGIN
        msg ('+' || l_proc_name);
        msg (' p_raise_event=' || p_raise_event);

        ln_process_batch_id   := xxdo.xxdoint_inv_prod_cat_batch_s.NEXTVAL;

        BEGIN
            UPDATE xxdo.xxd_inv_mtl_system_items_t
               SET batch_id   = ln_process_batch_id
             WHERE batch_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_batch_threads   := gn_item_batch_threads;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        COMMIT;


        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Test msg: Inside  process_update_batch');

        BEGIN
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;

            --Start Added as per CCR0008880
            BEGIN
                SELECT DISTINCT tag, TO_NUMBER (meaning)
                  INTO ln_batch_threads, ln_split_batch_time
                  FROM apps.fnd_lookup_values flv
                 WHERE     1 = 1
                       AND flv.lookup_type = 'XXD_OM_PRD_STYLE_BATCH' --updated for CCR0010301
                       AND flv.language = USERENV ('LANG')
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           flv.start_date_active,
                                                           SYSDATE - 1))
                                               AND TRUNC (
                                                       NVL (
                                                           flv.end_date_active,
                                                           SYSDATE + 1))
                       AND NVL (flv.enabled_flag, 'N') = 'Y';

                IF ln_batch_threads IS NULL
                THEN
                    ln_batch_threads   := gn_item_batch_threads;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_batch_threads   := gn_item_batch_threads;
                    msg ('  EXCEPTION: ' || SQLERRM);
            END;

            --End Added as per CCR0008880

            --Start Added as per CCR0009133
            --Verify order exists in Batch History table while Insertion
            BEGIN
                SELECT TO_NUMBER (tag)
                  INTO ln_dt_days
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXD_OM_SALESORD_BAT_HIST_LKP'
                       AND lookup_code = 'ITEM'
                       AND language = 'US'
                       AND enabled_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_dt_days   := 1;
            END;

            --End Added as per CCR0009133

            SELECT xxdo.xxdoint_inv_prod_cat_batch_s.NEXTVAL
              INTO x_batch_id
              FROM DUAL;

            msg ('  obtained batch_id ' || x_batch_id);

            apps.fnd_file.put_line (apps.fnd_file.output,
                                    'x_batch_id - ' || x_batch_id);

            -- Start changes for CCR0009133
            /*SELECT COUNT (1)
              INTO ln_before
              FROM apps.PRD_XXDOINT_MTL_SYSTEM_ITEMS_V;

            BEGIN
                DBMS_CDC_SUBSCRIBE.EXTEND_WINDOW (
                    subscription_name   => G_CDC_SUBSTRIPTION_NAME);
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (apps.fnd_file.output,
                                            'unable to get subs' || SQLERRM);
            END;

            SELECT COUNT (1)
              INTO ln_after
              FROM apps.PRD_XXDOINT_MTL_SYSTEM_ITEMS_V;

            msg ('  extended CDC window');

            msg ('  beginning inserts.');

            apps.fnd_file.put_line (apps.fnd_file.output, 'after dbms_cdc ');

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                'before, after ' || ln_before || '-' || ln_after);

            -- Items --
            INSERT INTO xxdo.xxdoint_inv_prd_cat_upd_batch (
                            batch_id,
                            organization_id,
                            inventory_item_id)
                SELECT DISTINCT
                       x_batch_id, organization_id, inventory_item_id
                  FROM (  SELECT itm.cscn$,
                                 itm.organization_id,
                                 itm.inventory_item_id
                            FROM apps.PRD_XXDOINT_MTL_SYSTEM_ITEMS_V itm,
                                 hr.hr_all_organization_units       haou
                           WHERE     itm.organization_id = haou.organization_id
                                 AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                 haou.date_from,
                                                                 SYSDATE - 1)
                                                         AND NVL (haou.date_to,
                                                                  SYSDATE + 1)
                        -- and itm.segment3 != 'ALL'             --commented by BT team on 15/01/2015
                        --                             AND itm.segment3 != 'GENERIC' --Added by BT team on 15/01/2015
                        GROUP BY itm.cscn$,
                                 itm.organization_id,
                                 itm.inventory_item_id
                          HAVING    DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.segment1, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.segment2, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.segment3, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.description,
                                                          ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         itm.primary_uom_code,
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         itm.inventory_item_status_code,
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.attribute1,
                                                          ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.attribute2,
                                                          ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.attribute10,
                                                          ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.attribute11,
                                                          ' '))) >
                                    1
                                 --Start Adding as per CCR0007740
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.attribute25,
                                                          ' '))) >
                                    1
                                 --End Adding as per CCR0007740
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         TO_CHAR (
                                                             itm.list_price_per_unit),
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.enabled_flag,
                                                          ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         TO_CHAR (
                                                             itm.start_date_active),
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         TO_CHAR (
                                                             itm.end_date_active),
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         itm.customer_order_enabled_flag,
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (itm.atp_flag, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         TO_CHAR (
                                                             itm.unit_length),
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         TO_CHAR (
                                                             itm.unit_width),
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         TO_CHAR (
                                                             itm.unit_height),
                                                         ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (itm.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (
                                                         TO_CHAR (
                                                             itm.unit_weight),
                                                         ' '))) >
                                    1) alpha
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_inv_prd_cat_upd_batch btch
                             WHERE     btch.batch_id = x_batch_id
                                   AND btch.organization_id =
                                       alpha.organization_id
                                   AND btch.inventory_item_id =
                                       alpha.inventory_item_id);*/
            -- Items -- Added as part of CCR0009596
            INSERT INTO xxdo.xxdoint_inv_prd_cat_upd_batch (
                            batch_id,
                            organization_id,
                            inventory_item_id)
                SELECT x_batch_id, organization_id, inventory_item_id
                  FROM xxd_inv_mtl_system_items_t ximsi
                 WHERE     1 = 1
                       AND ximsi.batch_id = ln_process_batch_id
                       --Start Added as per CCR0008880
                       AND ximsi.organization_id IN
                               (SELECT TO_NUMBER (flv.meaning)
                                  FROM apps.fnd_lookup_values flv
                                 WHERE     flv.lookup_type =
                                           'XXD_OM_PRD_INV_ORGS'
                                       AND flv.language = USERENV ('LANG')
                                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                       NVL (
                                                                           flv.start_date_active,
                                                                             SYSDATE
                                                                           - 1))
                                                               AND TRUNC (
                                                                       NVL (
                                                                           flv.end_date_active,
                                                                             SYSDATE
                                                                           + 1))
                                       AND NVL (flv.enabled_flag, 'N') = 'Y')
                       --End Added as per CCR0008880
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM xxdo.xxdoint_inv_prd_cat_upd_batch bat
                                 WHERE     bat.batch_id = x_batch_id
                                       AND bat.organization_id =
                                           ximsi.organization_id
                                       AND bat.inventory_item_id =
                                           ximsi.inventory_item_id);

            -- End changes for CCR0009133

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to MTL_SYSTEM_ITEMS_B.');

            -- Start changes for CCR0009133
            -- Category Assignments --
            /*INSERT INTO xxdo.xxdoint_inv_prd_cat_upd_batch (
                            batch_id,
                            organization_id,
                            inventory_item_id)
                SELECT DISTINCT
                       x_batch_id, organization_id, inventory_item_id
                  FROM (  SELECT mic.cscn$,
                                 mic.organization_id,
                                 mic.inventory_item_id
                            FROM apps.PRD_XXDOINT_MTL_ITEM_CATEGOR_V mic,
                                 hr.hr_all_organization_units       haou -- , inv.mtl_system_items_b msib                       --commented by BT team on 15/01/2015
                                                                        ,
                                 apps.xxd_common_items_v            msib --Added by BT team on 15/01/2015
                           WHERE     haou.organization_id = mic.organization_id
                                 AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                 haou.date_from,
                                                                 SYSDATE - 1)
                                                         AND NVL (haou.date_to,
                                                                  SYSDATE + 1)
                                 AND msib.organization_id = mic.organization_id
                                 AND msib.inventory_item_id =
                                     mic.inventory_item_id
                                 --and msib.segment3 != 'ALL'                                   --commented by BT Team on 15/01/2015
                                 AND msib.item_type != 'GENERIC' --Added by BT team on 15/01/2015
                                 --and mic.category_set_id = 1                                  --commented By BT Team on 15/01/2015
                                 AND mic.category_set_id =
                                     (SELECT category_set_id
                                        FROM mtl_category_sets
                                       WHERE category_set_name = 'Inventory') --Added by BT tema on 15/01/2015
                        GROUP BY mic.cscn$,
                                 mic.organization_id,
                                 mic.inventory_item_id
                          HAVING DECODE (
                                     MAX (mic.operation$),
                                     'I ', 2,
                                     'D ', 2,
                                     COUNT (
                                         DISTINCT NVL (
                                                      TO_CHAR (
                                                          mic.category_id),
                                                      ' '))) >
                                 1) alpha
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_inv_prd_cat_upd_batch btch
                             WHERE     btch.batch_id = x_batch_id
                                   AND btch.organization_id =
                                       alpha.organization_id
                                   AND btch.inventory_item_id =
                                       alpha.inventory_item_id);*/
            -- Item Categories  -- Added as part of CCR0009596
            INSERT INTO xxdo.xxdoint_inv_prd_cat_upd_batch (
                            batch_id,
                            organization_id,
                            inventory_item_id)
                SELECT x_batch_id, organization_id, inventory_item_id
                  FROM mtl_system_items_b msib
                 WHERE     msib.attribute28 != 'GENERIC'
                       --Start Added as per CCR0008880
                       AND msib.organization_id IN
                               (SELECT TO_NUMBER (flv.meaning)
                                  FROM apps.fnd_lookup_values flv
                                 WHERE     flv.lookup_type =
                                           'XXD_OM_PRD_INV_ORGS'
                                       AND flv.language = USERENV ('LANG')
                                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                       NVL (
                                                                           flv.start_date_active,
                                                                             SYSDATE
                                                                           - 1))
                                                               AND TRUNC (
                                                                       NVL (
                                                                           flv.end_date_active,
                                                                             SYSDATE
                                                                           + 1))
                                       AND NVL (flv.enabled_flag, 'N') = 'Y')
                       --End Added as per CCR0008880
                       AND EXISTS
                               (SELECT 1
                                  FROM xxd_inv_mtl_item_categories_t ximic, mtl_category_sets mcs
                                 WHERE     ximic.category_set_id =
                                           mcs.category_set_id
                                       AND ximic.inventory_item_id =
                                           msib.inventory_item_id
                                       AND ximic.organization_id =
                                           msib.organization_id
                                       AND ximic.batch_id =
                                           ln_process_batch_id
                                       AND mcs.category_set_name =
                                           'Inventory')
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM xxdo.xxdoint_inv_prd_cat_upd_batch bat
                                 WHERE     bat.batch_id = x_batch_id
                                       AND bat.organization_id =
                                           msib.organization_id
                                       AND bat.inventory_item_id =
                                           msib.inventory_item_id);

            -- End changes for CCR0009133

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to MTL_ITEM_CATEGORIES.');

            -- Start changes for CCR0009133
            -- Categories --
            /*INSERT INTO xxdo.xxdoint_inv_prd_cat_upd_batch (
                            batch_id,
                            organization_id,
                            inventory_item_id)
                SELECT DISTINCT
                       x_batch_id, organization_id, inventory_item_id
                  FROM (  SELECT cat.cscn$ /* , mic.organization_id
                                            , mic.inventory_item_id*/
            --commented by BT Team on 15/01/2015
            /*, msib.organization_id, msib.inventory_item_id --added by BT team on 15/01/2015
       FROM apps.PRD_XXDOINT_MTL_CATEGORIES_B_V cat -- , inv.mtl_item_categories mic                       --commented by BT team on 15/01/2015
                                                   ,
            hr.hr_all_organization_units       haou -- , inv.mtl_system_items_b msib                       --commented by BT team on 15/01/2015
                                                   ,
            apps.xxd_common_items_v            msib --Added by BT team on 15/01/2015
      /*   where mic.category_id = cat.category_id
           and mic.category_set_id = 1
           and haou.organization_id = mic.organization_id
           and msib.organization_id = mic.organization_id
           and msib.inventory_item_id = mic.inventory_item_id
           and trunc(sysdate) between nvl(haou.date_from, sysdate-1) and nvl(haou.date_to, sysdate+1)
           and msib.segment3 != 'ALL'*/
            --commented by BT Team on 15/01/2015
            /*WHERE     msib.category_id = cat.category_id
                  AND haou.organization_id =
                      msib.organization_id
                  AND TRUNC (SYSDATE) BETWEEN NVL (
                                                  haou.date_from,
                                                  SYSDATE - 1)
                                          AND NVL (haou.date_to,
                                                   SYSDATE + 1)
                  AND msib.item_type != 'GENERIC' --Added by  BT Team on 15/01/2015
         GROUP BY cat.cscn$,
                  msib.organization_id,
                  msib.inventory_item_id --added by BT team on 15/01/2015
           /*  , mic.organization_id
             , mic.inventory_item_id*/
            --commented by BT Team on 15/01/2015
            /*HAVING    DECODE (
                          MAX (cat.operation$),
                          'I ', 2,
                          'D ', 2,
                          COUNT (
                              DISTINCT NVL (cat.segment1, ' '))) >
                      1
                   OR DECODE (
                          MAX (cat.operation$),
                          'I ', 2,
                          'D ', 2,
                          COUNT (
                              DISTINCT NVL (cat.segment2, ' '))) >
                      1
                   OR DECODE (
                          MAX (cat.operation$),
                          'I ', 2,
                          'D ', 2,
                          COUNT (
                              DISTINCT NVL (cat.segment3, ' '))) >
                      1
                   OR DECODE (
                          MAX (cat.operation$),
                          'I ', 2,
                          'D ', 2,
                          COUNT (
                              DISTINCT NVL (cat.segment4, ' '))) >
                      1
                   OR DECODE (
                          MAX (cat.operation$),
                          'I ', 2,
                          'D ', 2,
                          COUNT (
                              DISTINCT NVL (cat.segment5, ' '))) >
                      1) alpha
   WHERE NOT EXISTS
             (SELECT NULL
                FROM xxdo.xxdoint_inv_prd_cat_upd_batch btch
               WHERE     btch.batch_id = x_batch_id
                     AND btch.organization_id =
                         alpha.organization_id
                     AND btch.inventory_item_id =
                         alpha.inventory_item_id);*/

            -- Categories --Start Added as part of CCR0009596
            INSERT INTO xxdo.xxdoint_inv_prd_cat_upd_batch (
                            batch_id,
                            organization_id,
                            inventory_item_id)
                SELECT x_batch_id, organization_id, inventory_item_id
                  FROM mtl_system_items_b msib
                 WHERE     msib.attribute28 != 'GENERIC'
                       --Start Added as per CCR0008880
                       AND msib.organization_id IN
                               (SELECT TO_NUMBER (flv.meaning)
                                  FROM apps.fnd_lookup_values flv
                                 WHERE     flv.lookup_type =
                                           'XXD_OM_PRD_INV_ORGS'
                                       AND flv.language = USERENV ('LANG')
                                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                       NVL (
                                                                           flv.start_date_active,
                                                                             SYSDATE
                                                                           - 1))
                                                               AND TRUNC (
                                                                       NVL (
                                                                           flv.end_date_active,
                                                                             SYSDATE
                                                                           + 1))
                                       AND NVL (flv.enabled_flag, 'N') = 'Y')
                       --End Added as per CCR0008880
                       AND EXISTS
                               (SELECT 1
                                  FROM xxd_inv_mtl_categories_t ximc, mtl_item_categories mic, mtl_category_sets mcs
                                 WHERE     ximc.category_id = mic.category_id
                                       AND mic.category_set_id =
                                           mcs.category_set_id
                                       AND mic.inventory_item_id =
                                           msib.inventory_item_id
                                       AND mic.organization_id =
                                           msib.organization_id
                                       AND ximc.batch_id =
                                           ln_process_batch_id
                                       AND mcs.category_set_name =
                                           'Inventory')
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM xxdo.xxdoint_inv_prd_cat_upd_batch bat
                                 WHERE     bat.batch_id = x_batch_id
                                       AND bat.organization_id =
                                           msib.organization_id
                                       AND bat.inventory_item_id =
                                           msib.inventory_item_id);

            --End Added as part of CCR0009596

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to MTL_CATEGORIES_B.');


            COMMIT;


            BEGIN                                  -- W.r.t Version CCR0008880
                INSERT INTO xxdo.xxdoint_inv_prd_cat_upd_batch (
                                batch_id,
                                organization_id,
                                inventory_item_id)
                      SELECT DISTINCT x_batch_id, f.organization_id, f.inventory_item_id
                        FROM mtl_system_items_b i, mtl_system_items_b f, xxdo.xxdoint_inv_prd_cat_upd_batch h
                       WHERE     i.inventory_item_id = h.inventory_item_id
                             AND SUBSTR (i.segment1,
                                         1,
                                         INSTR (i.segment1, '-', -1) - 1) =
                                 SUBSTR (f.segment1,
                                         1,
                                         INSTR (f.segment1, '-', -1) - 1)
                             AND i.organization_id = h.organization_id
                             --AND i.organization_id = f.organization_id
                             AND i.description = f.description
                             AND i.item_type != 'GENERIC'
                             AND f.item_type != 'GENERIC'
                             AND f.organization_id IN
                                     (SELECT TO_NUMBER (flv.meaning)
                                        FROM apps.fnd_lookup_values flv
                                       WHERE     flv.lookup_type =
                                                 'XXD_OM_PRD_INV_ORGS'
                                             AND flv.language =
                                                 USERENV ('LANG')
                                             AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 flv.start_date_active,
                                                                                   SYSDATE
                                                                                 - 1))
                                                                     AND TRUNC (
                                                                             NVL (
                                                                                 flv.end_date_active,
                                                                                   SYSDATE
                                                                                 + 1))
                                             AND NVL (flv.enabled_flag, 'N') =
                                                 'Y')
                             AND NOT EXISTS
                                     (SELECT 1
                                        FROM xxdo.xxdoint_inv_prd_cat_upd_batch
                                       WHERE     batch_id = x_batch_id
                                             AND f.inventory_item_id =
                                                 inventory_item_id
                                             AND f.organization_id =
                                                 organization_id)
                             AND batch_id = x_batch_id
                    /*  AND f.size_scale_id =
                             (SELECT DISTINCT sizing
                                FROM xxdo.xxdo_plm_staging xps
                               WHERE     xps.style = f.style_number
                                     AND xps.colorway = f.color_code
                                     AND xps.record_id =
                                            (SELECT MAX (record_id)
                                               FROM xxdo.xxdo_plm_staging plm
                                              WHERE     plm.style =
                                                           f.style_number
                                                    AND colorway = f.color_code AND ATTRIBUTE4 is null AND sizing is not null)) */
                    ORDER BY inventory_item_id, organization_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    fnd_file.put_line (fnd_file.LOG,
                                       'SKU Collaboration issue ' || SQLERRM);
            END;


            --Start Added as per CCR0008880
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                'batch split limit-lookup: ' || ln_batch_threads);

            ln_split           := 0;
            ln_style_cnt       := 0;
            ln_loop_cntr       := 0;

            --Fetch Count of Distinct Style-Color for Batch Split
            FOR c_rec IN get_style_batches (x_batch_id)
            LOOP
                ln_style_cnt   := get_style_batches%ROWCOUNT;
            END LOOP;

            apps.fnd_file.put_line (apps.fnd_file.output,
                                    'style color distinct: ' || ln_style_cnt);

            ln_split           := CEIL (ln_style_cnt / ln_batch_threads);
            apps.fnd_file.put_line (apps.fnd_file.output,
                                    'split batch count: ' || ln_split);

            IF ln_split > 1
            THEN
                --SPLIT
                ln_split_idx        := 1;
                ln_batch_list       := SYS.ODCINUMBERLIST ();
                ln_batch_list.EXTEND (ln_split + 1);
                ln_batch_list (1)   := x_batch_id;

                FOR c_rec IN get_style_batches (x_batch_id)
                LOOP
                    msg ('Splitting Batch' || ln_batch_list (ln_split_idx));

                    IF (ln_loop_cntr <> 0 AND (ln_batch_threads - ln_loop_cntr = 0))
                    THEN
                        ln_loop_cntr   := 0;
                    END IF;

                    IF ln_loop_cntr = 0
                    THEN
                        SELECT xxdo.xxdoint_inv_prod_cat_batch_s.NEXTVAL
                          INTO lx_new_batch_id
                          FROM DUAL;

                        ln_split_idx                   := ln_split_idx + 1;
                        ln_split                       := ln_split - 1;
                        ln_batch_list (ln_split_idx)   := lx_new_batch_id;
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                            'Split Batch Id: ' || lx_new_batch_id);
                    END IF;

                    UPDATE xxdo.xxdoint_inv_prd_cat_upd_batch
                       SET batch_id   = lx_new_batch_id
                     WHERE     batch_id = x_batch_id
                           AND inventory_item_id IN
                                   (SELECT DISTINCT inventory_item_id
                                      FROM mtl_system_items_b
                                     WHERE     SUBSTR (
                                                   segment1,
                                                   1,
                                                     INSTR (segment1,
                                                            '-',
                                                            -1)
                                                   - 1) =
                                               c_rec.style_color
                                           AND organization_id =
                                               gn_mst_inv_org_id);

                    ln_loop_cntr   := ln_loop_cntr + 1;
                    COMMIT;
                END LOOP;
            ELSE
                ln_batch_list       := SYS.ODCINUMBERLIST ();
                ln_batch_list.EXTEND;
                ln_batch_list (1)   := x_batch_id;
                msg ('No Batch Split ' || x_batch_id);
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                    'No Batch Split - Batch Id: ' || x_batch_id);
            END IF;

            FOR batch_idx IN 1 .. ln_batch_list.COUNT
            LOOP
                --End Added as per CCR0008880

                IF l_tot_cnt = 0
                THEN
                    msg (
                        '  no product changes were found.  skipping business event.');
                    l_bus_event_result   := 'Not Needed';
                ELSIF NVL (p_raise_event, 'Y') = 'Y'
                THEN
                    msg ('  raising business event.');
                    --Start changes for CCR0008880
                    /*raise_business_event (p_batch_id         => x_batch_id,
                                                   x_ret_stat         => x_ret_stat,
                                                   x_error_messages   => x_error_messages);*/

                    raise_business_event (
                        p_batch_id         => ln_batch_list (batch_idx),
                        x_ret_stat         => x_ret_stat,
                        x_error_messages   => x_error_messages);

                    --End changes for CCR0008880

                    IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                       apps.fnd_api.g_ret_sts_success
                    THEN
                        l_bus_event_result   := 'Failed';
                    ELSE
                        l_bus_event_result   := 'Raised';
                    END IF;
                ELSE
                    l_bus_event_result   := 'Skipped';
                END IF;

                --Start changes for CCR0008880
                /*IF in_conc_request
                THEN
                   apps.fnd_file.put_line (apps.fnd_file.output,
                                           'Batch ID: ' || x_batch_id);
                   apps.fnd_file.put_line (apps.fnd_file.output,
                                           'Business Event: ' || l_bus_event_result);
                   apps.fnd_file.put_line (apps.fnd_file.output, ' ');
                   apps.fnd_file.put_line (
                      apps.fnd_file.output,
                         RPAD ('Warehouse', 10, ' ')
                      || RPAD ('Brand', 10, ' ')
                      || LPAD ('Items', 10, ' '));
                   apps.fnd_file.put_line (apps.fnd_file.output,
                                           RPAD ('=', 30, '='));

                   FOR c_output IN c_batch_output
                   LOOP
                      apps.fnd_file.put_line (
                         apps.fnd_file.output,
                            RPAD (c_output.organization_code, 10, ' ')
                         || RPAD (c_output.brand, 10, ' ')
                         || LPAD (c_output.itm_cnt, 10, ' '));
                   END LOOP;
                END IF;*/

                msg (
                       'Batch Split End: '
                    || ln_batch_list (batch_idx)
                    || ' '
                    || TO_CHAR (SYSDATE, 'yyyy-mm-dd hh24.mi.ss')
                    || ' waiting '
                    || ln_split_batch_throttle_time
                    || ' secs');

                IF in_conc_request
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                        'Batch ID: ' || ln_batch_list (batch_idx));
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                        'Business Event: ' || l_bus_event_result);
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           'Business Event: '
                        || TO_CHAR (SYSDATE, 'MM-DD-YYYY HH24:MI:SS')); --CCR0010301
                    apps.fnd_file.put_line (apps.fnd_file.output, ' ');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           RPAD ('Warehouse', 10, ' ')
                        || RPAD ('Brand', 10, ' ')
                        || LPAD ('Items', 10, ' '));
                    apps.fnd_file.put_line (apps.fnd_file.output,
                                            RPAD ('=', 30, '='));

                    FOR c_output
                        IN c_batch_output (ln_batch_list (batch_idx))
                    LOOP
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               RPAD (c_output.organization_code, 10, ' ')
                            || RPAD (c_output.brand, 10, ' ')
                            || LPAD (c_output.itm_cnt, 10, ' '));
                    END LOOP;
                END IF;

                ln_split_batch_throttle_time   :=
                    NVL (ln_split_batch_time, gn_item_batch_split_throttle);

                IF NVL (ln_split_batch_throttle_time, 0) > 0
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           'Lets wait for next batch '
                        || TO_CHAR (SYSDATE, 'MM-DD-YYYY HH24:MI:SS'));

                    DBMS_LOCK.sleep (ln_split_batch_throttle_time);

                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           'Wait Over '
                        || TO_CHAR (SYSDATE, 'MM-DD-YYYY HH24:MI:SS')); --CCR0010301
                END IF;
            END LOOP;                                         -- FOR batch_idx

            --Start changes for CCR0009029
            DBMS_LOCK.sleep (ln_item_event_throttle);

            IF NVL (p_raise_season_event, 'Y') = 'Y'
            THEN
                msg ('  raising season event.');

                raise_season_event (p_batch_id         => x_batch_id,
                                    x_ret_stat         => x_ret_stat,
                                    x_error_messages   => x_error_messages);

                IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                   apps.fnd_api.g_ret_sts_success
                THEN
                    l_bus_event_result   := 'Failed';
                ELSE
                    l_bus_event_result   := 'Raised';
                END IF;
            ELSE
                l_bus_event_result   := 'Skipped';
            END IF;

            COMMIT;
            --End changes for CCR0009029

            msg (
                   'End: '
                || TO_CHAR (SYSDATE, 'yyyy-mm-dd hh24.mi.ss')
                || ' waiting '
                || ln_batch_throttle_time
                || ' secs');

            IF NVL (ln_batch_throttle_time, 0) > 0
            THEN
                DBMS_LOCK.sleep (ln_batch_throttle_time);
            END IF;
        --End changes for CCR0008880
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                x_batch_id         := NULL;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg (
               'x_batch_id='
            || x_batch_id
            || ', x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    END;

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.raise_business_event';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            apps.wf_event.raise (p_event_name => G_ITEM_UPDATE_EVENT, p_event_key => TO_CHAR (p_batch_id), p_event_data => NULL
                                 , p_parameters => NULL);

            COMMIT;
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg (
               'x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    END;


    --Start Added as per CCR0009029
    PROCEDURE raise_season_event (p_batch_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.raise_season_event';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            apps.wf_event.raise (p_event_name => G_ITEM_SEASON_UPD_EVENT, p_event_key => TO_CHAR (p_batch_id), p_event_data => NULL
                                 , p_parameters => NULL);
            COMMIT;
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        --End Added as per CCR0009029

        msg (
               'x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    END raise_season_event;

    PROCEDURE process_update_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_raise_event IN VARCHAR2:= 'Y'
                                         , p_raise_season_event IN VARCHAR2:= 'Y', --Added as per CCR0009029
                                                                                   p_debug_level IN NUMBER:= NULL)
    IS
        l_proc_name   VARCHAR2 (80)
                          := G_PKG_NAME || '.process_update_batch_conc';
        l_batch_id    NUMBER;
        l_ret         VARCHAR2 (1);
        l_err         VARCHAR2 (2000);
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_PROD_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (
                    apps.fnd_profile.VALUE ('XXDOINT_PROD_DEBUG_LEVEL')));
        END IF;

        msg ('+' || l_proc_name);
        msg (
               'p_raise_event='
            || p_raise_event
            || ', p_debug_level='
            || p_debug_level);
        process_update_batch (p_raise_event => p_raise_event, x_batch_id => l_batch_id, x_ret_stat => l_ret
                              , x_error_messages => l_err);

        IF NVL (l_ret, apps.fnd_api.g_ret_sts_error) =
           apps.fnd_api.g_ret_sts_success
        THEN
            perrproc   := 0;
            psqlstat   := NULL;
        ELSE
            perrproc   := 2;
            psqlstat   := l_err;
        END IF;

        msg ('-' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXCEPTION: ' || SQLERRM);
            perrproc   := 2;
            psqlstat   := SQLERRM;
    END process_update_batch_conc;

    --Start Added as per CCR0009029
    PROCEDURE insert_plm_sizes (p_size_chart_code IN NUMBER, p_size_chart_desc IN VARCHAR2, p_size_chart_values IN VARCHAR2
                                , p_enabled_flag IN VARCHAR2:= 'Y')
    IS
        l_proc_name            VARCHAR2 (80) := G_PKG_NAME || '.insert_plm_sizes';
        ln_user_id    CONSTANT NUMBER := fnd_global.user_id;
        ln_login_id   CONSTANT NUMBER := fnd_global.login_id;
        ln_exists              NUMBER := 0;
    BEGIN
        msg ('+' || l_proc_name);
        msg (
               'p_size_chart_code='
            || p_size_chart_code
            || ', p_size_chart_desc='
            || p_size_chart_desc
            || ', p_size_chart_values='
            || p_size_chart_values);

        IF (p_size_chart_code IS NOT NULL AND p_size_chart_desc IS NOT NULL AND p_size_chart_values IS NOT NULL)
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_exists
                  FROM xxdo.xxd_inv_plm_size_definitions_t
                 WHERE size_chart_code = p_size_chart_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_exists   := -1;
            END;

            IF NVL (ln_exists, 0) = 0
            THEN
                INSERT INTO xxdo.xxd_inv_plm_size_definitions_t (
                                size_chart_code,
                                size_chart_desc,
                                size_chart_values,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                last_update_login,
                                enabled_flag)
                         VALUES (p_size_chart_code,
                                 p_size_chart_desc,
                                 p_size_chart_values,
                                 SYSDATE,
                                 NVL (ln_user_id, -1),
                                 SYSDATE,
                                 NVL (ln_user_id, -1),
                                 NVL (ln_login_id, -1),
                                 p_enabled_flag);
            ELSE
                UPDATE xxdo.xxd_inv_plm_size_definitions_t
                   SET size_chart_desc = p_size_chart_desc, size_chart_values = p_size_chart_values, last_update_date = SYSDATE,
                       last_updated_by = NVL (ln_user_id, -1)
                 WHERE     size_chart_code = p_size_chart_code
                       AND NVL (enabled_flag, 'N') = 'Y';
            END IF;
        END IF;

        msg ('-' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            msg (
                   'EXCEPTION: -Insertion of PLM Size Definitions Failed '
                || SQLERRM);
    END insert_plm_sizes;

    PROCEDURE purge_season_batch (p_batch_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.purge_season_batch';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            SAVEPOINT before_prd_purge;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                msg (' ready to delete season batch records.');

                --To Insert Season Batch History prior Delete
                BEGIN
                    INSERT INTO xxdo.xxd_inv_season_batch_hist_t
                        (SELECT *
                           FROM xxdo.xxd_inv_season_batch_t
                          WHERE batch_id = p_batch_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                DELETE FROM xxdo.xxd_inv_season_batch_t
                      WHERE batch_id = p_batch_id;

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' record(s) from the season batch table.');

                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_prd_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    --End Added as per CCR0009029
    -- ver 1.5 added function get get country of origin
    FUNCTION get_country_of_origin (p_inventory_item_id   IN NUMBER,
                                    p_inv_org_id          IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_country_of_origin   VARCHAR2 (100);

        CURSOR c_get_coo (in_inventory_item_id NUMBER, in_inv_org_id NUMBER)
        IS
              SELECT COUNTRY
                FROM (SELECT SS.COUNTRY, msr.sourcing_rule_id
                        FROM apps.mrp_sourcing_rules msr, apps.mrp_sr_assignments msa, apps.mrp_assignment_sets mas,
                             apps.mtl_parameters mp, apps.mrp_sr_receipt_org msro, apps.mrp_sr_source_org msso,
                             apps.ap_suppliers sup, apps.ap_supplier_sites_all ss, apps.mtl_category_sets mcs,
                             apps.mtl_categories mcb, apps.mtl_system_items_b msi, apps.mtl_item_categories mic
                       WHERE     1 = 1
                             AND msr.sourcing_rule_id = msa.sourcing_rule_id
                             AND msa.assignment_set_id = mas.assignment_set_id
                             AND mas.attribute1 = 'US-JP' --Deckers Default Set-US-JP
                             AND msa.assignment_type = 5
                             AND mp.attribute1 = 'US'
                             AND mas.attribute1 IS NOT NULL
                             AND msa.organization_id = mp.organization_id
                             AND msa.category_set_id = mcs.category_set_id
                             AND mcs.structure_id = mcb.structure_id
                             AND msa.category_id = mcb.category_id
                             AND msr.sourcing_rule_id = msro.sourcing_rule_id
                             AND (msro.disable_date IS NULL OR msro.disable_date >= TRUNC (SYSDATE))
                             AND msro.sr_receipt_id = msso.sr_receipt_id
                             AND msso.vendor_id = sup.vendor_id(+)
                             AND msso.vendor_site_id = ss.vendor_site_id(+)
                             AND msi.organization_id = mic.organization_id
                             AND msi.inventory_item_id = mic.inventory_item_id
                             AND mic.category_set_id = mcs.category_set_id
                             AND mic.category_id = mcb.category_id
                             AND mic.category_set_id = 1
                             AND msi.organization_id = mp.organization_id
                             AND msi.inventory_item_id = in_inventory_item_id
                             AND msi.organization_id = in_inv_org_id
                      UNION
                      SELECT SS.COUNTRY, msr.sourcing_rule_id
                        FROM apps.mrp_sourcing_rules msr, apps.mrp_sr_assignments msa, apps.mrp_assignment_sets mas,
                             apps.mtl_parameters mp, apps.mrp_sr_receipt_org msro, apps.mrp_sr_source_org msso,
                             apps.ap_suppliers sup, apps.ap_supplier_sites_all ss, apps.mtl_category_sets mcs,
                             apps.mtl_categories mcb, apps.mtl_system_items_b msi, apps.mtl_item_categories mic
                       WHERE     1 = 1
                             AND msr.sourcing_rule_id = msa.sourcing_rule_id
                             -- AND msa.assignment_set_id = mas.assignment_set_id
                             AND mas.attribute1 <> 'US-JP' --not Deckers Default Set-US-JP
                             AND msa.assignment_type = 5
                             AND mp.attribute1 <> 'US'
                             AND mas.attribute1 IS NOT NULL
                             AND mp.attribute1 = mas.attribute1
                             AND msa.organization_id = mp.organization_id
                             AND msa.category_set_id = mcs.category_set_id
                             AND mcs.structure_id = mcb.structure_id
                             AND msa.category_id = mcb.category_id
                             AND msr.sourcing_rule_id = msro.sourcing_rule_id
                             AND (msro.disable_date IS NULL OR msro.disable_date >= TRUNC (SYSDATE))
                             AND msro.sr_receipt_id = msso.sr_receipt_id
                             AND msso.vendor_id = sup.vendor_id(+)
                             AND msso.vendor_site_id = ss.vendor_site_id(+)
                             AND msi.organization_id = mic.organization_id
                             AND msi.inventory_item_id = mic.inventory_item_id
                             AND mic.category_set_id = mcs.category_set_id
                             AND mic.category_id = mcb.category_id
                             AND mic.category_set_id = 1
                             AND msi.organization_id = mp.organization_id
                             AND msi.inventory_item_id = in_inventory_item_id
                             AND msi.organization_id = in_inv_org_id) a
               WHERE 1 = 1
            ORDER BY sourcing_rule_id DESC;
    BEGIN
        BEGIN
            OPEN c_get_coo (p_inventory_item_id, p_inv_org_id);

            FETCH c_get_coo INTO lv_country_of_origin;

            CLOSE c_get_coo;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        RETURN lv_country_of_origin;
    END get_country_of_origin;
END xxdoint_inv_prod_cat_utils;
/


GRANT EXECUTE ON APPS.XXDOINT_INV_PROD_CAT_UTILS TO SOA_INT
/

GRANT EXECUTE ON APPS.XXDOINT_INV_PROD_CAT_UTILS TO XXDO
/
