--
-- XXD_CONV_CALC_LEAD_TIME_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_CONV_CALC_LEAD_TIME_PKG"
/*
================================================================
 Created By              : BT Technology Team
 Creation Date           : 6-May-2015
 File Name               : XXD_CONV_CALC_LEAD_TIME_PKG.pkb
 Incident Num            :
 Description             :
 Latest Version          : 1.0

================================================================
 Date               Version#    Name                    Remarks
================================================================
6-May-2015        1.0       BT Technology Team
26-May-2015       1.1       BT Technology Team         Changed to direct table update for performance
28-May-2015       1.2       BT Technology Team         Removed RETURN 0 when there is exception
================================================================
*/
AS
    gc_debug_flag   VARCHAR2 (3) := 'Y';

    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;


    FUNCTION func_lead_time_cal (pn_organization_id IN NUMBER, pn_inventory_id IN NUMBER, p_attribute28 IN mtl_system_items_b.attribute28%TYPE)
        --                             postprocessing_lead_time IN       mtl_system_items_b.postprocessing_lead_time%TYPE,
        --                             preprocessing_lead_time  IN       mtl_system_items_b.preprocessing_lead_time%TYPE)
        RETURN NUMBER
    AS
        ln_category_id           NUMBER;
        lc_transit_days          VARCHAR2 (100);
        ln_full_lead_time        NUMBER := 90;
        ln_lead_time             NUMBER;
        l_territory_short_name   fnd_territories_vl.territory_short_name%TYPE;
        lv_attribute             mtl_system_items_b.attribute28%TYPE;
        ln_post_lt               mtl_system_items_b.postprocessing_lead_time%TYPE;
        ln_pre_lt                mtl_system_items_b.preprocessing_lead_time%TYPE;
        l_region                 fnd_lookup_values.attribute1%TYPE;
        l_vendor_name            mrp_sr_source_org_v.vendor_name%TYPE;
        l_vendor_site            mrp_sr_source_org_v.vendor_site%TYPE;
    --Calculating Territory
    BEGIN
        log_records (gc_debug_flag, 'inventory_id :' || pn_inventory_id);

        BEGIN
            SELECT ft.territory_short_name
              INTO l_territory_short_name
              FROM mtl_parameters mp, hr_locations hl, fnd_territories_vl ft
             WHERE     hl.inventory_organization_id = mp.organization_id
                   AND mp.attribute10 = 'Y'
                   AND mp.organization_id = pn_organization_id
                   AND hl.country = ft.territory_code
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                log_records (gc_debug_flag,
                             'Error in Finding territory Name' || SQLERRM);
        -- RETURN 0; commented in v1.2
        END;

        /*      --Calculating Item Attributes
              BEGIN
                 SELECT attribute28,
                        postprocessing_lead_time,
                        preprocessing_lead_time
                   INTO lv_attribute, ln_post_lt, ln_pre_lt
                   FROM mtl_system_items_b
                  WHERE     inventory_item_id = pn_inventory_id
                        AND organization_id = pn_organization_id;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                  log_records(gc_debug_flag,'Error in Item Attributes :'||sqlerrm);
                    RETURN 0;
              END;
        */
        --Calculating Category Value
        BEGIN
            SELECT category_id
              INTO ln_category_id
              FROM mtl_item_categories_v
             WHERE     category_set_name = 'Inventory'
                   AND organization_id = pn_organization_id
                   AND inventory_item_id = pn_inventory_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                log_records (gc_debug_flag,
                             'Error in Category Value :' || SQLERRM);
        -- RETURN 0; commented in v1.2
        END;

        --Finding Region
        BEGIN
            SELECT attribute1
              INTO l_region
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
                   AND language = 'US'
                   AND attribute2 = 'Inventory Organization'
                   AND attribute_category = 'XXDO_SOURCING_RULE_REGION_MAP'
                   AND attribute3 =
                       (SELECT organization_code
                          FROM mtl_parameters
                         WHERE organization_id = pn_organization_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                log_records (gc_debug_flag, 'Error in  Region :' || SQLERRM);
                l_region   := 'NA';
        -- RETURN 0;
        END;

        --Finding Vendor Name and Vendor Site
        BEGIN
            --         SELECT mso.vendor_name, mso.vendor_site
            --           INTO l_vendor_name, l_vendor_site
            --           FROM mrp_assignment_sets mrp,
            --                mrp_sr_assignments msra,
            --                mrp_sourcing_rules msr,
            --                mrp_sr_source_org_v mso
            --          WHERE     assignment_set_name LIKE '%l_region%' -- 'Deckers Default Set-US/JP'
            --                AND mrp.assignment_set_id = msra.assignment_set_id
            --                AND msr.sourcing_rule_id = msra.sourcing_rule_id
            --                AND mso.sr_source_id = msr.sourcing_rule_id
            --                AND msra.category_id = ln_category_id
            --                AND msra.organization_id = pn_organization_id
            --                AND mso.allocation_percent = 100
            --                AND mso.RANK = 1
            --                AND msra.assignment_type = 5
            --                AND ROWNUM = 1;

            SELECT vendor_id, mso.vendor_site
              INTO l_vendor_name, l_vendor_site
              FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                   mrp_sr_source_org_v mso, mrp_sr_receipt_org_v msrov
             WHERE     assignment_set_name LIKE '%' || l_region || '%' -- 'Deckers Default Set-US/JP'
                   AND mrp.assignment_set_id = msra.assignment_set_id
                   AND msr.sourcing_rule_id = msra.sourcing_rule_id
                   AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                   AND msra.category_id = ln_category_id
                   AND msra.organization_id = pn_organization_id
                   AND msra.assignment_type = 5
                   AND mso.allocation_percent = 100
                   AND mso.RANK = 1
                   AND mso.sr_receipt_id = msrov.sr_receipt_id
                   AND SYSDATE BETWEEN msrov.effective_date
                                   AND TRUNC (
                                           NVL (msrov.disable_date,
                                                SYSDATE + 1));

            log_records (gc_debug_flag, 'Finding vendor ' || l_vendor_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                log_records (
                    gc_debug_flag,
                    'Error in Vendor Name and Vendor Site :' || SQLERRM);
                l_vendor_name   := NULL;
                l_vendor_site   := NULL;
        -- RETURN 0;  commented in v1.1
        END;

        IF p_attribute28 LIKE '%SAMPLE%'
        THEN
            BEGIN
                SELECT attribute5
                  INTO lc_transit_days
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                       AND language = 'US'
                       AND attribute4 = l_territory_short_name
                       AND attribute1 = l_vendor_name
                       AND attribute2 = l_vendor_site;
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (gc_debug_flag,
                                 'Error in Sample :' || SQLERRM);
                    lc_transit_days   := NULL;
            END;

            log_records (gc_debug_flag, 'Finding Sample ' || lc_transit_days);
        ELSE
            BEGIN
                SELECT attribute6
                  INTO lc_transit_days
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                       AND language = 'US'
                       AND attribute4 = l_territory_short_name
                       AND attribute1 = l_vendor_name
                       AND attribute2 = l_vendor_site;

                log_records (gc_debug_flag,
                             'Finding NOT Sample ' || lc_transit_days);
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (gc_debug_flag,
                                 'Error in NOT Sample :' || SQLERRM);
                    lc_transit_days   := NULL;
            END;
        END IF;

        /*
        --Commented in v1.1.  Full lead time to be considered as 90

        ln_full_lead_time := NULL;

        --Finding full_lead_time from MST
        BEGIN
           SELECT full_lead_time
             INTO ln_full_lead_time
             FROM mtl_system_items_b
            WHERE     organization_id = (SELECT organization_id
                                           FROM mtl_parameters
                                          WHERE organization_code = 'MST')
                  AND inventory_item_id = pn_inventory_id;
          log_records(gc_debug_flag,'ln_full_lead_time ' || ln_full_lead_time);
        EXCEPTION
           WHEN OTHERS
           THEN
               log_records(gc_debug_flag,'Error in full_lead_time :'||sqlerrm);
              ln_full_lead_time := 0;
        END;
      */

        ln_lead_time   :=
            CEIL (
                  5
                / 7
                * (NVL (ln_full_lead_time, 0) + NVL (lc_transit_days, 0)));
        log_records (gc_debug_flag, 'Finding ln_lead_time ' || ln_lead_time);
        RETURN ln_lead_time;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (gc_debug_flag, 'Error in lead_time :' || SQLERRM);
            RETURN 0;
    END func_lead_time_cal;

    -------------------------------------------
    -- Procedure prc_calc_cum_lead_time_child
    -- This procedure called by child program
    -------------------------------------------
    PROCEDURE prc_calc_cum_lead_time_child (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, pn_organization_id NUMBER)
    AS
        CURSOR Get_items_c IS
            SELECT inventory_item_id, organization_id, attribute28,
                   POSTPROCESSING_LEAD_TIME, PREPROCESSING_LEAD_TIME
              FROM mtl_system_items_b msb
             WHERE     MRP_PLANNING_CODE <> '6'
                   AND organization_id = pn_organization_id;

        TYPE lcu_Get_items_typ IS TABLE OF Get_items_c%ROWTYPE;

        lcu_get_items_c               lcu_Get_items_typ;
        x_item_tbl_typ                EGO_Item_PUB.Item_Tbl_Type;

        ln_lead_time                  NUMBER;
        ln_POSTPROCESSING_LEAD_TIME   NUMBER;
        ln_PREPROCESSING_LEAD_TIME    NUMBER;
        ln_cum_ld_time                NUMBER;
        l_item_tbl_typ                EGO_Item_PUB.Item_Tbl_Type;
        l_api_version        CONSTANT NUMBER := 1.0;
        x_return_status               VARCHAR2 (4000);
        x_msg_count                   NUMBER;
        x_message_list                Error_Handler.Error_Tbl_Type;
        lc_err_message_text           VARCHAR2 (4000);
        l_success_count               NUMBER := 0;
        l_error_count                 NUMBER := 0;
        ln_org_code                   VARCHAR2 (10);
        ln_commit_count               NUMBER := 0;
    BEGIN
        -- Get orgnization name
        SELECT organization_code
          INTO ln_org_code
          FROM mtl_parameters
         WHERE organization_id = pn_organization_id;


        OPEN Get_items_c;

        LOOP
            FETCH Get_items_c BULK COLLECT INTO lcu_Get_items_c LIMIT 500;

            l_item_tbl_typ.delete;

            EXIT WHEN lcu_Get_items_c.COUNT = 0;

            FOR i IN lcu_Get_items_c.FIRST .. lcu_Get_items_c.LAST
            LOOP
                ln_lead_time                  :=
                    func_lead_time_cal (
                        lcu_Get_items_c (i).organization_id,
                        lcu_Get_items_c (i).inventory_item_id,
                        lcu_Get_items_c (i).attribute28);

                ln_POSTPROCESSING_LEAD_TIME   := NULL;
                ln_PREPROCESSING_LEAD_TIME    := NULL;

                --      SELECT POSTPROCESSING_LEAD_TIME, PREPROCESSING_LEAD_TIME
                --        INTO ln_postprocessing_lead_time, ln_preprocessing_lead_time
                --        FROM mtl_system_items_b
                --       WHERE     inventory_item_id = lcu_Get_items_c(i).inventory_item_id
                --             AND organization_id = lcu_Get_items_c(i).organization_id;

                ln_cum_ld_time                := NULL;

                ln_cum_ld_time                :=
                      NVL (lcu_Get_items_c (i).POSTPROCESSING_LEAD_TIME, 0)
                    + NVL (lcu_Get_items_c (i).PREPROCESSING_LEAD_TIME, 0)
                    + NVL (ln_lead_time, 0);

                log_records (gc_debug_flag,
                             'Cumulative Lead Time ---> ' || ln_cum_ld_time);

                /*
                --Commneted this in v1.1
                --Logic changed to update base table for performance issue


                l_item_tbl_typ (i).transaction_type := 'UPDATE';
                l_item_tbl_typ (i).inventory_item_id := lcu_Get_items_C(i).inventory_item_id;
                l_item_tbl_typ (i).organization_id := lcu_Get_items_C(i).organization_id;
                l_item_tbl_typ (i).CUMULATIVE_TOTAL_LEAD_TIME := ln_cum_ld_time;
                l_item_tbl_typ (i).FULL_LEAD_TIME := ln_lead_time;

                  ego_item_pub.process_items (
                   p_api_version      => l_api_version,
                   p_init_msg_list    => fnd_api.g_false,
                   p_commit           => fnd_api.g_true,
                   p_item_tbl         => l_item_tbl_typ,
                   x_item_tbl         => x_item_tbl_typ,
                   p_role_grant_tbl   => ego_item_pub.g_miss_role_grant_tbl,
                   x_return_status    => x_return_status,
                   x_msg_count        => x_msg_count);

                IF (x_return_status <> fnd_api.g_ret_sts_success)
                THEN
                   log_records (gc_debug_flag, 'Error Messages :');
                   error_handler.get_message_list (x_message_list => x_message_list);
                   lc_err_message_text := NULL;

                   FOR i IN 1 .. x_message_list.COUNT
                   LOOP

                   log_records ('Y' ,'Message ' || x_message_list (i).MESSAGE_TEXT);
                      lc_err_message_text :=
                         SUBSTR (
                               lc_err_message_text
                            || ','
                            || x_message_list (i).MESSAGE_TEXT,
                            1,
                            4000);

                   END LOOP;

                ELSE
                log_records('Y',' STATUS COUNT : '||x_return_status);

                   IF x_return_status ='S' THEN
                     l_success_count :=l_success_count+1;
                   END IF;

                    IF x_return_status ='E' THEN
                     l_error_count := l_error_count+1;
                    END IF;

                    COMMIT;
                END IF;
          --      END LOOP;
                  */

                x_return_status               := 'S';

                BEGIN
                    UPDATE MTL_SYSTEM_ITEMS
                       SET CUMULATIVE_TOTAL_LEAD_TIME = ln_cum_ld_time, FULL_LEAD_TIME = ln_lead_time
                     WHERE     inventory_item_id =
                               lcu_Get_items_C (i).inventory_item_id
                           AND organization_id =
                               lcu_Get_items_C (i).organization_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_return_status   := 'E';
                END;

                log_records ('Y', ' STATUS COUNT : ' || x_return_status);

                IF x_return_status = 'S'
                THEN
                    l_success_count   := l_success_count + 1;
                END IF;

                IF x_return_status = 'E'
                THEN
                    l_error_count   := l_error_count + 1;
                END IF;

                ln_commit_count               := ln_commit_count + 1;

                IF (ln_commit_count = 1000)
                THEN
                    COMMIT;
                    ln_commit_count   := 0;
                END IF;
            END LOOP;
        END LOOP;

        COMMIT;

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'No of records successfully update :' || l_success_count);
        fnd_file.put_line (
            fnd_file.OUTPUT,
            'No of records which went to error status :' || l_error_count);
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                gc_debug_flag,
                ' Other Error @prc_calc_cum_lead_time_child: ' || SQLERRM);
    END;


    PROCEDURE PRC_CALC_LEAD_TIME_MAIN (x_errbuf    OUT VARCHAR2,
                                       x_retcode   OUT NUMBER)
    IS
        l_err_msg                VARCHAR2 (4000);
        l_err_code               NUMBER;
        l_interface_rec_cnt      NUMBER;
        l_request_id             NUMBER;
        l_succ_interfc_rec_cnt   NUMBER := 0;
        l_warning_cnt            NUMBER := 0;
        l_error_cnt              NUMBER := 0;
        l_return                 BOOLEAN;
        --      l_low_batch_limit        NUMBER;
        --      l_high_batch_limit       NUMBER;
        l_phase                  VARCHAR2 (30);
        l_status                 VARCHAR2 (30);
        l_dev_phase              VARCHAR2 (30);
        l_dev_status             VARCHAR2 (30);
        l_message                VARCHAR2 (1000);
        l_instance               VARCHAR2 (1000);
        l_batch_nos              VARCHAR2 (1000);
        l_sub_requests           fnd_concurrent.requests_tab_type;
        l_errored_rec_cnt        NUMBER;
        l_validated_rec_cnt      NUMBER;
        v_request_id             NUMBER;
        g_debug                  VARCHAR2 (10);
        g_process_level          VARCHAR2 (50);
        l_count                  NUMBER;
        ln_org_id                NUMBER;
        ln_parent_request_id     NUMBER := fnd_global.conc_request_id;
        ln_valid_rec_cnt         NUMBER;
        ln_request_id            NUMBER := 0;
        lc_phase                 VARCHAR2 (200);
        lc_status                VARCHAR2 (200);
        lc_dev_phase             VARCHAR2 (200);
        lc_dev_status            VARCHAR2 (200);
        lc_message               VARCHAR2 (200);
        ln_ret_code              NUMBER;
        lc_err_buff              VARCHAR2 (1000);
        ln_count                 NUMBER;
        ln_cntr                  NUMBER := 0;
        lb_wait                  BOOLEAN;
        lx_return_mesg           VARCHAR2 (2000);

        TYPE org_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_org_id_tab            org_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                 request_table;
    BEGIN
        FOR i IN (  SELECT organization_id
                      FROM MTL_PARAMETERS
                     WHERE organization_code <> 'MST'
                  --and organization_id=129
                  ORDER BY 1)
        LOOP
            ln_cntr                   := ln_cntr + 1;
            ln_org_id_tab (ln_cntr)   := i.organization_id;
        END LOOP;



        IF ln_org_id_tab.COUNT > 0
        THEN
            log_records (
                gc_debug_flag,
                   'Calling XXD_INV_CAL_LEAD_TIME_CHILD in batch '
                || ln_org_id_tab.COUNT);

            FOR i IN ln_org_id_tab.FIRST .. ln_org_id_tab.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM mtl_system_items_b
                 WHERE organization_id = ln_org_id_tab (i);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        log_records (
                            gc_debug_flag,
                               'Calling Worker process for org id ln_org_id_tab(i) := '
                            || ln_org_id_tab (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_INV_CAL_LEAD_TIME_CHILD',
                                '',
                                '',
                                FALSE,
                                ln_org_id_tab (i));
                        log_records (gc_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_INV_CAL_LEAD_TIME_CHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_INV_CAL_LEAD_TIME_CHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            log_records (
                gc_debug_flag,
                   'Calling XXD_INV_CAL_LEAD_TIME_CHILD in batch '
                || ln_org_id_tab.COUNT);
            log_records (
                gc_debug_flag,
                'Calling WAIT FOR REQUEST XXD_INV_CAL_LEAD_TIME_CHILD to complete');

            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec) > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec)--ln_concurrent_request_id
                                                              ,
                                INTERVAL     => 1,
                                max_wait     => 1,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (gc_debug_flag,
                         'Error message @ prc_cal_lead_time_main' || SQLERRM);
    END PRC_CALC_LEAD_TIME_MAIN;
END xxd_conv_calc_lead_time_pkg;
/
