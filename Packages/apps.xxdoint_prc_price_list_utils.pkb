--
-- XXDOINT_PRC_PRICE_LIST_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINT_PRC_PRICE_LIST_UTILS"
AS
    /*************************************************************************************
     * Package         : XXDOINT_PRC_PRICE_LIST_UTILS
     * Description     : The purpose of this package to capture the CDC for Pricelist
     *                   and raise business for SOA.
     * Notes           :
     * Modification    :
     *-------------------------------------------------------------------------------------
     * Date         Version#      Name                       Description
     *-------------------------------------------------------------------------------------
     *              1.0                                Initial Version
     * 03-Dec-2020  1.1        Aravind Kannuri         Updated for CCR0009027
     ***************************************************************************************/

    g_pkg_name                  CONSTANT VARCHAR2 (40) := 'XXDOINT_OM_SALES_ORDER_UTILS';
    g_cdc_substription_name     CONSTANT VARCHAR2 (40)
                                             := 'XXDOINT_OM_SALESORDER_SUB' ;
    g_pirce_update_event        CONSTANT VARCHAR2 (40)
        := 'oracle.apps.xxdo.price_list_update' ;
    g_so_max_batch_rows         CONSTANT NUMBER := 250;
    g_so_batch_throttle         CONSTANT NUMBER := 60;
    g_so_batch_split_throttle   CONSTANT NUMBER := 3;

    gn_userid                            NUMBER := apps.fnd_global.user_id;
    gn_resp_id                           NUMBER := apps.fnd_global.resp_id;
    gn_app_id                            NUMBER
                                             := apps.fnd_global.prog_appl_id;
    gn_conc_request_id                   NUMBER
        := apps.fnd_global.conc_request_id;
    g_num_login_id                       NUMBER := fnd_global.login_id;
    l_rundate                            DATE := NULL;
    ld_rundate                           DATE := NULL;
    ld_rundate2                          DATE := NULL;
    ld_rundate1                          VARCHAR2 (50);
    gv_debug                             VARCHAR2 (50);
    gn_qp_batch_throttle        CONSTANT NUMBER := 60; --Added as per CCR0009027
    gn_max_batch_cnt            CONSTANT NUMBER := 2000; --Added as per CCR0009027

    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN VARCHAR2:= 10000)
    IS
    BEGIN
        IF gv_debug = 'Y'
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    ' Message  ' || p_message);
        END IF;
    END;


    FUNCTION in_conc_request
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN apps.fnd_global.conc_request_id != -1;
    END;

    FUNCTION Get_Last_Conc_Req_Run (pn_request_id IN NUMBER)
        RETURN DATE
    IS
        ld_last_start_date         DATE;
        ln_concurrent_program_id   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Get Last Conc Req Ren - Start');
        fnd_file.put_line (fnd_file.LOG, 'REQUEST ID:  ' || pn_request_id);

        --Get the Concurrent program for the current running request
        BEGIN
            SELECT concurrent_program_id
              INTO ln_concurrent_program_id
              FROM fnd_concurrent_requests
             WHERE request_id = pn_request_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            --No occurnace running just return NULL
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No program found');
                RETURN NULL;
        END;

        fnd_file.put_line (fnd_file.LOG, 'CC REQ ID : ' || pn_request_id);

        BEGIN
            --Find the last occurance of this request
            SELECT NVL (MAX (actual_start_date), SYSDATE - 1)
              INTO ld_last_start_date
              FROM fnd_concurrent_requests
             WHERE     concurrent_program_id = ln_concurrent_program_id
                   AND ARGUMENT3 IS NULL
                   AND ARGUMENT4 IS NULL
                   -- AND ARGUMENT5 IS NULL fixed for performance
                   AND STATUS_CODE = 'C' --Only count completed tasks to not limit data to any erroring out.
                   AND request_id != gn_conc_request_id; --Don't include the current active request
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No prior occurance found');
                ld_last_start_date   :=
                    TRUNC (TO_DATE (SYSDATE - 1, 'YYYY/MM/DD HH24:MI:SS'));
        END;

        RETURN ld_last_start_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    PROCEDURE archive_batch (p_batch_id IN NUMBER, p_process_id IN NUMBER:= NULL, x_ret_stat OUT VARCHAR2
                             , x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.purge_batch';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            SAVEPOINT before_so_archive;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                msg (' ready to archive batch records.');

                INSERT INTO xxdo.xxd_hbs_price_nc_batch_arch (batch_id,
                                                              LIST_HEADER_ID,
                                                              batch_date)
                    SELECT batch_id, LIST_HEADER_ID, batch_date
                      FROM xxdo.xxd_hbs_price_nc_batch
                     WHERE batch_id = p_batch_id;

                msg (
                       ' archived '
                    || SQL%ROWCOUNT
                    || ' record(s) from the sales order header batch table.');
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_so_archive;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.purge_batch';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            SAVEPOINT before_so_purge;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                msg (' ready to delete batch records.');

                INSERT INTO xxdo.xxd_hbs_price_nc_batch_arch
                    (SELECT * FROM xxdo.xxd_hbs_price_nc_batch);

                DELETE FROM xxdo.xxd_hbs_price_nc_batch
                      WHERE batch_id = p_batch_id;

                DELETE FROM xxdo.xxd_hbs_price_nc_batch_arch
                      WHERE BATCH_DATE < SYSDATE - 10;

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' record(s) from the sales order header batch table.');
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_so_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE remove_batch (p_batch_id IN NUMBER, p_process_id IN NUMBER, x_ret_stat OUT VARCHAR2
                            , x_error_messages OUT VARCHAR2)
    IS
        l_proc_name      VARCHAR2 (80) := g_pkg_name || '.remove_batch';
        failed_archive   EXCEPTION;
        failed_purge     EXCEPTION;
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            SAVEPOINT before_so_remove;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                msg (' calling archive');
                archive_batch (p_batch_id => p_batch_id, p_process_id => p_process_id, x_ret_stat => x_ret_stat
                               , x_error_messages => x_error_messages);

                IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                   apps.fnd_api.g_ret_sts_success
                THEN
                    RAISE failed_archive;
                END IF;

                purge_batch (p_batch_id         => p_batch_id,
                             x_ret_stat         => x_ret_stat,
                             x_error_messages   => x_error_messages);

                IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                   apps.fnd_api.g_ret_sts_success
                THEN
                    RAISE failed_purge;
                END IF;

                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_so_remove;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.purge_old_batches';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_hours_old=' || p_hours_old);

        BEGIN
            SAVEPOINT before_so_purge;

            IF p_hours_old IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A time threshhold was not specified.';
            ELSE
                msg (' ready to delete batch records.');

                DELETE FROM xxdo.xxd_hbs_price_nc_batch
                      WHERE batch_date < SYSDATE - (p_hours_old / 24);

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' record(s) from the sales order header batch table.');
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_so_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE process_update_batch (p_raise_event IN VARCHAR2:= 'Y', p_style IN VARCHAR2, p_batch IN NUMBER
                                    , x_batch_id OUT NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_proc_name                   VARCHAR2 (80) := g_pkg_name || '.process_update_batch';
        l_bus_event_result            VARCHAR2 (20);
        l_cnt                         NUMBER;
        l_tot_cnt                     NUMBER;
        l_batch_order_source          VARCHAR2 (200);
        l_batch_org_id                NUMBER;
        l_line_cnt                    NUMBER;
        l_max_batch_cnt               NUMBER;
        l_batch_throttle_time         NUMBER;
        l_split_batch_throttle_time   NUMBER;
        l_batch_list                  SYS.ODCINUMBERLIST;
        l_split_idx                   NUMBER;
        l_split                       NUMBER;
        x_new_batch_id                NUMBER;
        ln_batch_id                   NUMBER;


        CURSOR c_batch_output (cn_batch_id IN NUMBER)
        IS
              SELECT COUNT (1), LIST_HEADER_ID, BRAND
                FROM xxdo.xxd_hbs_price_nc_batch
               WHERE batch_id = cn_batch_id
            GROUP BY LIST_HEADER_ID, BRAND;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Process_update_batch started At '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));


        x_ret_stat         := apps.fnd_api.g_ret_sts_success;
        x_error_messages   := NULL;


        SELECT xxdo.xxd_hbs_pricelist_btch_s.NEXTVAL
          INTO x_batch_id
          FROM DUAL;



        l_rundate          := Get_Last_Conc_Req_Run (gn_conc_request_id);
        ld_rundate1        := TO_CHAR (l_rundate, 'DD-MON-YYYY HH24:MI:SS');

        -- Sales Order Headers --

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Rundate1 : ' || ld_rundate1);

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Raise Business Event "Yes/No" ' || p_raise_event);


        apps.fnd_file.put_line (apps.fnd_file.LOG, 'Style : ' || p_style);

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                '************************************');

        IF p_batch IS NULL
        THEN
            IF p_style IS NOT NULL
            THEN
                BEGIN
                    INSERT INTO xxdo.xxd_hbs_price_nc_batch (
                                    BATCH_ID,
                                    LIST_HEADER_ID,
                                    BATCH_DATE,
                                    STYLE_NAME,
                                    SKU,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    BRAND,
                                    UOM,
                                    hubsoft_price_list_id)
                        SELECT DISTINCT x_batch_id, LIST_HEADER_ID, SYSDATE,
                                        DECODE (product_attribute,  'PRICING_ATTRIBUTE2', product_attr_value,  'PRICING_ATTRIBUTE1', NULL) style_name, DECODE (product_attribute,  'PRICING_ATTRIBUTE1', product_attr_value,  'PRICING_ATTRIBUTE2', NULL) sku, SYSDATE,
                                        0, qlv.attribute1, qlv.product_uom_code,
                                        flv.ATTRIBUTE6
                          FROM mtl_category_sets mtsc, mtl_item_categories mic, mtl_categories_b mcb,
                               qp_list_lines_v qlv, apps.xxd_common_items_v msi, fnd_lookup_values_vl flv
                         WHERE     CATEGORY_SET_NAME = 'OM Sales Category'
                               AND mic.category_set_id = mtsc.category_set_id
                               AND mcb.category_id = mic.category_id
                               AND mtsc.structure_id = mcb.structure_id
                               AND qlv.product_attribute IN
                                       ('PRICING_ATTRIBUTE2', 'PRICING_ATTRIBUTE1')
                               AND msi.master_org_flag = 'Y'
                               AND qlv.list_header_id =
                                   TO_NUMBER (flv.attribute1)
                               -- AND flv.language = USERENV ('LANG')
                               AND flv.enabled_flag = 'Y'
                               AND flv.lookup_type =
                                   'XXD_HUBSOFT_PRICELIST_MAP'
                               AND qlv.product_attribute_context = 'ITEM'
                               AND qlv.pricing_attribute_context IS NULL
                               AND MSI.primary_uom_code =
                                   qlv.product_uom_code
                               AND qlv.product_attr_value =
                                   TO_CHAR (
                                       DECODE (
                                           product_attribute,
                                           'PRICING_ATTRIBUTE2', mic.category_id,
                                           'PRICING_ATTRIBUTE1', mic.inventory_item_id))
                               AND msi.inventory_item_id =
                                   mic.inventory_item_id
                               AND msi.organization_id = mic.organization_id
                               AND msi.style_number = p_style;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Error while inserting   ' || SQLERRM);
                END;

                l_cnt       := SQL%ROWCOUNT;
                l_tot_cnt   := l_cnt;
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Record Inserted  ' || l_cnt);
            ELSE
                BEGIN
                    INSERT INTO xxdo.xxd_hbs_price_nc_batch (
                                    BATCH_ID,
                                    LIST_HEADER_ID,
                                    BATCH_DATE,
                                    STYLE_NAME,
                                    SKU,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    BRAND,
                                    UOM,
                                    hubsoft_price_list_id)
                        SELECT DISTINCT x_batch_id, qll.list_header_id, TRUNC (SYSDATE),
                                        DECODE (product_attribute,  'PRICING_ATTRIBUTE2', product_attr_value,  'PRICING_ATTRIBUTE1', NULL) style_name, DECODE (product_attribute,  'PRICING_ATTRIBUTE1', product_attr_value,  'PRICING_ATTRIBUTE2', NULL) sku, SYSDATE,
                                        gn_userid, qll.attribute1, qpa.product_uom_code,
                                        flv.ATTRIBUTE6
                          FROM apps.qp_list_lines qll, qp_pricing_attributes qpa, fnd_lookup_values flv
                         WHERE     qll.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND qpa.list_line_id = qll.list_line_id
                               AND qpa.pricing_attribute_context IS NULL
                               AND qpa.excluder_flag = 'N'
                               AND flv.lookup_type =
                                   'XXD_HUBSOFT_PRICELIST_MAP'
                               AND product_attribute IN
                                       ('PRICING_ATTRIBUTE1', 'PRICING_ATTRIBUTE2')
                               AND qll.list_header_id =
                                   TO_NUMBER (flv.attribute1)
                               AND flv.language = USERENV ('LANG')
                               AND flv.enabled_flag = 'Y'
                               AND PRODUCT_ATTRIBUTE_CONTEXT = 'ITEM';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Error while inserting   ' || SQLERRM);
                END;

                l_cnt       := SQL%ROWCOUNT;
                l_tot_cnt   := l_cnt;
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Record Inserted  ' || l_cnt);
            END IF;
        ELSE
            x_batch_id   := p_batch;
            l_cnt        := 1;
        END IF;



        COMMIT;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Parent batch Number  ' || x_batch_id);

        IF l_cnt > 0
        THEN
            FOR c_batch_rec IN c_batch_output (x_batch_id)
            LOOP
                SELECT xxdo.xxd_hbs_pricelist_btch_s.NEXTVAL
                  INTO ln_batch_id
                  FROM DUAL;

                UPDATE xxdo.xxd_hbs_price_nc_batch
                   SET batch_id   = ln_batch_id
                 WHERE     list_header_id = c_batch_rec.list_header_id
                       AND brand = c_batch_rec.brand
                       AND batch_id = x_batch_id;

                l_cnt       := SQL%ROWCOUNT;
                l_tot_cnt   := l_cnt;
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Record updated  ' || l_cnt);

                COMMIT;

                IF NVL (UPPER (p_raise_event), 'Y') IN ('Y', 'YES')
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Raised Business Event :'
                        || ln_batch_id
                        || ' For Brand Pricelist :'
                        || c_batch_rec.brand
                        || '-'
                        || c_batch_rec.list_header_id);

                    BEGIN
                        raise_business_event (
                            p_batch_id         => ln_batch_id,
                            p_batch_name       => g_pirce_update_event,
                            x_ret_stat         => x_ret_stat,
                            x_error_messages   => x_error_messages);
                    END;
                END IF;
            END LOOP;
        END IF;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                '************************************');

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            ' Ended At ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        COMMIT;
        msg (
               'x_batch_id='
            || x_batch_id
            || ', x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    END;

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, p_batch_name IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                    , x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.raise_business_event';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            apps.wf_event.RAISE (p_event_name => p_batch_name, p_event_key => TO_CHAR (p_batch_id), p_event_data => NULL
                                 , p_parameters => NULL);
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

    PROCEDURE process_update_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_raise_event IN VARCHAR2:= 'Y'
                                         , p_debug_level IN VARCHAR2:= NULL, p_style IN VARCHAR2:= NULL, p_batch IN NUMBER:= NULL)
    IS
        l_proc_name        VARCHAR2 (80)
                               := g_pkg_name || '.process_update_batch_conc';
        l_batch_id         NUMBER;
        l_ret              VARCHAR2 (1);
        l_err              VARCHAR2 (2000);
        x_ret_stat         VARCHAR2 (2000);
        ln_batch_id        NUMBER;
        l_cnt              NUMBER;
        l_tot_cnt          NUMBER;
        x_error_messages   VARCHAR2 (2000);
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                ' program started ' || SYSDATE);

        gv_debug   := p_debug_level;
        msg ('+' || l_proc_name);
        msg (
               'p_raise_event='
            || p_raise_event
            || ', p_debug_level='
            || p_debug_level);


        process_update_batch (p_raise_event      => p_raise_event,
                              p_style            => p_style,
                              p_batch            => p_batch,
                              x_batch_id         => l_batch_id,
                              x_ret_stat         => l_ret,
                              x_error_messages   => l_err);

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
    END;

    PROCEDURE reprocess_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_hours_old IN NUMBER
                                    , p_debug_level IN VARCHAR2:= NULL)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.reprocess_batch_conc';
        l_ret         VARCHAR2 (1);
        l_err         VARCHAR2 (2000);
        l_ret_txt     VARCHAR2 (10);

        CURSOR c_batches IS
              SELECT batch_id, COUNT (1) AS order_count
                FROM xxdo.xxd_hbs_price_nc_batch upd_btch
               WHERE batch_date < SYSDATE - (p_hours_old / 24)
            GROUP BY batch_id
            ORDER BY batch_id;
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_SO_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (apps.fnd_profile.VALUE ('XXDOINT_SO_DEBUG_LEVEL')));
        END IF;

        msg ('+' || l_proc_name);
        msg (
               'p_hours_old='
            || p_hours_old
            || ', p_debug_level='
            || p_debug_level);
        perrproc   := 0;
        psqlstat   := NULL;
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Hours Back: ' || p_hours_old);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Batch ID', 15, ' ')
            || LPAD ('Orders', 10, ' ')
            || RPAD ('Messages', 200, ' '));
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('=', 225, '='));

        FOR c_batch IN c_batches
        LOOP
            raise_business_event (p_batch_id => c_batch.batch_id, p_batch_name => g_pirce_update_event, x_ret_stat => l_ret
                                  , x_error_messages => l_err);

            IF NVL (l_ret, apps.fnd_api.g_ret_sts_error) !=
               apps.fnd_api.g_ret_sts_success
            THEN
                l_ret_txt   := 'Error';
                perrproc    := 1;
                psqlstat    := 'At least one batch failed to process.';
            ELSE
                l_ret_txt   := 'Success';
            END IF;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD (c_batch.batch_id, 15, ' ')
                || RPAD (c_batch.order_count, 10, ' ')
                || RPAD (l_err, 200, ' '));
        END LOOP;

        msg ('-' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXCEPTION: ' || SQLERRM);
            perrproc   := 2;
            psqlstat   := SQLERRM;
    END;

    --Start Added as per CCR0009027
    PROCEDURE process_full_load_batch (
        psqlstat           OUT VARCHAR2,
        perrproc           OUT VARCHAR2,
        p_raise_event   IN     VARCHAR2 := 'Y',
        p_debug_level   IN     VARCHAR2 := NULL,
        p_brand         IN     VARCHAR2 := NULL,
        p_region        IN     VARCHAR2 := NULL,
        p_season        IN     VARCHAR2 := NULL,
        p_price_list    IN     VARCHAR2 := NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lv_proc_name             VARCHAR2 (80)
                                     := g_pkg_name || '.process_full_load_batch';
        ln_batch_throttle_time   NUMBER;
        ln_max_batch_cnt         NUMBER;
        ln_cnt                   NUMBER;
        ln_tot_cnt               NUMBER;
        ln_split                 NUMBER;
        ln_batch_list            SYS.ODCINUMBERLIST;
        ln_split_idx             NUMBER;
        ln_new_batch_id          NUMBER;
        x_batch_id               NUMBER;
        x_ret_stat               VARCHAR2 (200);
        x_error_messages         VARCHAR2 (2000);


        CURSOR c_batch_output (cn_batch_id IN NUMBER)
        IS
              SELECT COUNT (1), LIST_HEADER_ID, BRAND
                FROM xxdo.xxd_hbs_price_nc_batch
               WHERE batch_id = cn_batch_id
            GROUP BY LIST_HEADER_ID, BRAND;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'process_full_load_batch started At '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        x_ret_stat         := apps.fnd_api.g_ret_sts_success;
        x_error_messages   := NULL;

        SELECT xxdo.xxd_hbs_pricelist_btch_s.NEXTVAL
          INTO x_batch_id
          FROM DUAL;

        l_rundate          := Get_Last_Conc_Req_Run (gn_conc_request_id);
        ld_rundate1        := TO_CHAR (l_rundate, 'DD-MON-YYYY HH24:MI:SS');

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Rundate1 : ' || ld_rundate1);
        apps.fnd_file.put_line (apps.fnd_file.LOG, 'BRAND : ' || p_brand);

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Raise Business Event "Yes/No" ' || p_raise_event);

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                '************************************');

        BEGIN
            IF p_brand = 'ALL'                            --Distributor Portal
            THEN
                INSERT INTO xxdo.xxd_hbs_price_nc_batch (
                                BATCH_ID,
                                LIST_HEADER_ID,
                                BATCH_DATE,
                                STYLE_NAME,
                                SKU,
                                CREATION_DATE,
                                CREATED_BY,
                                BRAND,
                                UOM,
                                HUBSOFT_PRICE_LIST_ID)
                    SELECT DISTINCT
                           x_batch_id,
                           (SELECT list_header_id
                              FROM apps.qp_list_headers
                             WHERE name = ebs_price_list_name) price_list_id,
                           SYSDATE,
                           DECODE (product_attribute,
                                   'PRICING_ATTRIBUTE2', product_attr_value,
                                   'PRICING_ATTRIBUTE1', NULL) style_name,
                           DECODE (product_attribute,
                                   'PRICING_ATTRIBUTE1', product_attr_value,
                                   'PRICING_ATTRIBUTE2', NULL) sku,
                           SYSDATE,
                           0,
                           brand,
                           PRIMARY_UOM_CODE,
                           hubsoft_price_list_id
                      FROM xxdo.xxd_b2b_price_full_load_v
                     WHERE     brand IS NULL
                           AND season = p_season
                           AND operating_unit_id = p_region
                           AND ebs_price_list_name = p_price_list;
            ELSE                                           --All other portals
                INSERT INTO xxdo.xxd_hbs_price_nc_batch (
                                BATCH_ID,
                                LIST_HEADER_ID,
                                BATCH_DATE,
                                STYLE_NAME,
                                SKU,
                                CREATION_DATE,
                                CREATED_BY,
                                BRAND,
                                UOM,
                                HUBSOFT_PRICE_LIST_ID)
                    SELECT DISTINCT
                           x_batch_id,
                           (SELECT list_header_id
                              FROM apps.qp_list_headers
                             WHERE name = ebs_price_list_name) price_list_id,
                           SYSDATE,
                           DECODE (product_attribute,
                                   'PRICING_ATTRIBUTE2', product_attr_value,
                                   'PRICING_ATTRIBUTE1', NULL) style_name,
                           DECODE (product_attribute,
                                   'PRICING_ATTRIBUTE1', product_attr_value,
                                   'PRICING_ATTRIBUTE2', NULL) sku,
                           SYSDATE,
                           0,
                           brand,
                           PRIMARY_UOM_CODE,
                           hubsoft_price_list_id
                      FROM xxdo.xxd_b2b_price_full_load_v
                     WHERE     brand = p_brand
                           AND season = p_season
                           AND operating_unit_id = p_region
                           AND ebs_price_list_name = p_price_list;
            END IF;
        END;

        ln_cnt             := SQL%ROWCOUNT;
        ln_tot_cnt         := ln_cnt;
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Record updated  ' || ln_tot_cnt);
        COMMIT;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Parent batch Number  ' || x_batch_id);

        --To fetch Batch Max Rows and Sleep Time
        BEGIN
            SELECT TO_NUMBER (tag), TO_NUMBER (meaning)
              INTO ln_max_batch_cnt, ln_batch_throttle_time
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_QP_B2B_BATCH_ROWS_TIME'
                   AND language = 'US'
                   AND enabled_flag = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_max_batch_cnt         := gn_max_batch_cnt;
                ln_batch_throttle_time   := gn_qp_batch_throttle;
                msg (' Exp-Batch Max Rows and Sleep Time : ' || SQLERRM);
        END;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Batch Max Rows and Sleep Time  '
            || ln_max_batch_cnt
            || ' and '
            || ln_batch_throttle_time);

        IF ln_tot_cnt > ln_max_batch_cnt
        THEN
            --SPLIT
            ln_split            := CEIL (ln_tot_cnt / ln_max_batch_cnt);
            ln_split_idx        := 1;
            ln_batch_list       := SYS.ODCINUMBERLIST ();
            ln_batch_list.EXTEND (ln_split + 1);
            ln_batch_list (1)   := x_batch_id;

            msg (
                   'Start: '
                || TO_CHAR (SYSDATE, 'yyyy-mm-dd hh24.mi.ss')
                || ' waiting '
                || ln_batch_throttle_time
                || ' secs');

            WHILE ln_split > 0
            LOOP
                msg ('Splitting' || ln_batch_list (ln_split_idx));

                SELECT xxdo.xxd_hbs_pricelist_btch_s.NEXTVAL
                  INTO ln_new_batch_id
                  FROM DUAL;

                UPDATE xxdo.xxd_hbs_price_nc_batch
                   SET batch_id   = ln_new_batch_id
                 WHERE     batch_id = ln_batch_list (ln_split_idx)
                       AND ROWNUM <= ln_max_batch_cnt;

                ln_split_idx                   := ln_split_idx + 1;
                ln_split                       := ln_split - 1;
                ln_batch_list (ln_split_idx)   := x_batch_id;

                COMMIT;

                IF NVL (UPPER (p_raise_event), 'Y') IN ('Y', 'YES')
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Raised Business Event :' || ln_new_batch_id);

                    --Sleep Time
                    IF NVL (ln_batch_throttle_time, 0) > 0
                    THEN
                        DBMS_LOCK.sleep (ln_batch_throttle_time);
                    --DBMS_SESSION.sleep (ln_batch_throttle_time);
                    END IF;

                    --Raise Event
                    BEGIN
                        raise_business_event (
                            p_batch_id         => ln_new_batch_id,
                            p_batch_name       => g_pirce_update_event,
                            x_ret_stat         => x_ret_stat,
                            x_error_messages   => x_error_messages);
                    END;
                END IF;
            END LOOP;

            msg (
                   'Start: '
                || TO_CHAR (SYSDATE, 'yyyy-mm-dd hh24.mi.ss')
                || ' waiting '
                || ln_batch_throttle_time
                || ' secs');
        ELSE
            ln_batch_list       := SYS.ODCINUMBERLIST ();
            ln_batch_list.EXTEND;
            ln_batch_list (1)   := x_batch_id;
            msg ('Not Splitting ' || x_batch_id);

            --Raise Event
            IF NVL (UPPER (p_raise_event), 'Y') IN ('Y', 'YES')
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Raised Business Event :' || x_batch_id);

                BEGIN
                    raise_business_event (
                        p_batch_id         => x_batch_id,
                        p_batch_name       => g_pirce_update_event,
                        x_ret_stat         => x_ret_stat,
                        x_error_messages   => x_error_messages);
                END;
            END IF;
        END IF;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                '************************************');

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            ' Ended At ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        COMMIT;
        msg (
               'x_batch_id='
            || x_batch_id
            || ', x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || lv_proc_name);
    END;
--End Added as per CCR0009027
END;
/


GRANT EXECUTE ON APPS.XXDOINT_PRC_PRICE_LIST_UTILS TO SOA_INT
/
