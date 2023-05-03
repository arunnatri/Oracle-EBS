--
-- XXD_ATP_REFRESH_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ATP_REFRESH_PKG"
AS
    /**********************************************************************************************
    * Package         : APPS.XXD_ATP_REFRESH_PKG
    * Author          : BT Technology Team
    * Created         : 24-FEB-2015
    * Program Name    :
    * Description     :
    *
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *-----------------------------------------------------------------------------------------------
    *     24-Feb-2015 BT Technology Team     V1.1         Development
    *     26-Oct-2015 BT Technology Team     V1.2         Hubsoft filtering the ATR zero condition
    ************************************************************************************************/
    gn_user_id        NUMBER := fnd_profile.VALUE ('USER_ID');
    gn_resp_id        NUMBER := fnd_profile.VALUE ('RESP_ID');
    gn_resp_appl_id   NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');

    PROCEDURE MAIN_PROGRAM (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    AS
        l_request_id        NUMBER;
        lb_wait             BOOLEAN;
        lc_phase            VARCHAR2 (30);
        lc_status           VARCHAR2 (30);
        lc_dev_phase        VARCHAR2 (30);
        lc_dev_status       VARCHAR2 (30);
        ln_import_check     NUMBER;
        lc_message          VARCHAR2 (100);
        l_req_id            request_table;
        i                   NUMBER := 0;
        save_res            BOOLEAN;
        ln_user_id          NUMBER;
        ln_resp_id          NUMBER;
        ln_resp_appl_id     NUMBER;
        ln_del_error_days   NUMBER
            := fnd_profile.VALUE ('XXD_ATP_DEL_ERROR_DAYS');

        CURSOR cur_lukp_dtls IS
            SELECT attribute1 inv_org_code, attribute2 demand_class, attribute3 application,
                   attribute4 brand, attribute5 division
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE)
            UNION ALL                          --NRK Added on 05May2015 #Start
            SELECT DISTINCT attribute1 inv_org_code, '-1' Demand_class, attribute3 application,
                            attribute4 brand, attribute5 division
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE)
                   AND attribute3 = 'RMS';       --NRK Added on 05May2015 #End
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Start of "Deckers Master ATP Refresh Full Load" Program');

        ln_user_id        := gn_user_id;
        ln_resp_id        := gn_resp_id;
        ln_resp_appl_id   := gn_resp_appl_id;

        -- Truncating the Full Load Table
        fnd_file.put_line (fnd_file.LOG, 'Truncating the Full Load Table');

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXD_MASTER_ATP_FULL_T';

        -- Deleting the records from Error Table
        fnd_file.put_line (fnd_file.LOG, 'Truncating the Full Error Table');

        DELETE FROM XXDO.XXD_MASTER_ATP_ERROR_T
              WHERE creation_date < SYSDATE - NVL (ln_del_error_days, 10);

        COMMIT;

        -- Purge ATP Temp Tables
        -- Commented by BT Team on 04-Oct-15

        --      fnd_file.put_line (fnd_file.LOG,
        --                         'Calling Purge_atp_temp_tbls procedure..');
        --      purge_atp_temp_tbls (1);

        -- To Spawn the ATP Refresh for a given InvOrg and DemandClass
        FOR submit_rec IN cur_lukp_dtls
        LOOP
            BEGIN
                -- Initialize the Environment
                fnd_global.apps_initialize (ln_user_id,
                                            ln_resp_id,
                                            ln_resp_appl_id);

                l_request_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_ATP_REFRESH_SUB_PROG',
                        argument1     => submit_rec.inv_org_code,
                        argument2     => submit_rec.demand_class,
                        argument3     => submit_rec.application,
                        argument4     => submit_rec.brand,
                        argument5     => submit_rec.division);

                IF l_request_id > 0
                THEN
                    l_req_id (i)   := l_request_id;  -- NRK Added on 05May2015
                    i              := i + 1;         -- NRK Added on 05May2015
                    COMMIT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Sub Program Submitted - '
                        || l_request_id
                        || ', Inv Org - '
                        || submit_rec.inv_org_code
                        || ', Demand Class - '
                        || submit_rec.demand_class
                        || ', Application - '
                        || submit_rec.application
                        || ', Brand - '
                        || submit_rec.brand
                        || ', Division - '
                        || submit_rec.division);
                ELSE
                    ROLLBACK;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_retcode   := 2;
                    x_errbuf    := x_errbuf || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Unexp error ' || SQLERRM);
                WHEN OTHERS
                THEN
                    x_retcode   := 2;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Unexp error ' || SQLERRM);
            END;
        END LOOP;

        --NRK Added on 05May2015 #Start
        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');

        FOR rec IN l_req_id.FIRST .. l_req_id.LAST
        LOOP
            IF l_req_id (rec) > 0
            THEN
                LOOP
                    lc_dev_phase    := NULL;
                    lc_dev_status   := NULL;
                    lb_wait         :=
                        fnd_concurrent.wait_for_request (
                            request_id   => l_req_id (rec) --ln_concurrent_request_id
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
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Concurrent request '
                            || l_req_id (rec)
                            || ' : Completed');
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');

        -- Commented by BT Team on 04-Oct-15
        -- Purge ATP Temp Tables
        --      fnd_file.put_line (fnd_file.LOG,
        --                         'Calling Purge_atp_temp_tbls procedure..');
        --      purge_atp_temp_tbls (1);


        -- Setting Incremental Profile OPTION
        fnd_file.put_line (fnd_file.LOG,
                           'Setting Profile XXD_ATP_REFRESH_DATE :');
        save_res          :=
            FND_PROFILE.SAVE ('XXD_ATP_REFRESH_DATE', TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'), 'SITE'
                              , NULL, NULL);

        fnd_file.put_line (
            fnd_file.LOG,
               'Saved Refresh Cutoff Date to Profile :'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        COMMIT;                                  --NRK Added on 05May2015 #END
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_lukp_dtls%ISOPEN
            THEN
                CLOSE cur_lukp_dtls;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'exception=' || SQLERRM);
    END MAIN_PROGRAM;

    --------------------------------------------------------------------------------------------------------------------
    PROCEDURE SUB_PROGRAM (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_org_code IN VARCHAR2, p_demand_class IN VARCHAR2, p_application IN VARCHAR2, p_brand IN VARCHAR2
                           , p_division IN VARCHAR2)
    IS
        CURSOR get_inv_details_c (cp_org_id     NUMBER,
                                  cp_brand      VARCHAR2,
                                  cp_division   VARCHAR2)
        IS
            SELECT inventory_item_id
              FROM XXD_COMMON_ITEMS_V
             WHERE     organization_id = cp_org_id
                   AND brand = cp_brand
                   AND division = cp_division
                   AND atp_flag = 'Y'
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));

        v_table_get_inv_details_c   g_table_get_inv_details_c;
        lv_organization_id          NUMBER;

        lt_inv_items_atr            g_table_get_inv_details_c;   --NRK 04May15
        lt_inv_items_no_atr         g_table_get_inv_details_c;   --NRK 04May15
        ln_atr_qty                  NUMBER := 0;                 --NRK 04May15
        ln_a_cnt                    NUMBER := 0;                 --NRK 04May15
        ln_na_cnt                   NUMBER := 0;                 --NRK 04May15
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            '...................................................................');
        fnd_file.put_line (fnd_file.LOG, 'Begin of SubProgram..');
        fnd_file.put_line (
            fnd_file.LOG,
               'Time when SubProgram begun : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        SELECT mp.organization_id
          INTO lv_organization_id
          FROM mtl_parameters mp
         WHERE mp.organization_code = p_org_code;

        OPEN get_inv_details_c (lv_organization_id, p_brand, p_division); -- 14-april-15

        LOOP
            FETCH get_inv_details_c
                BULK COLLECT INTO v_table_get_inv_details_c
                LIMIT 1000;

            fnd_file.put_line (fnd_file.LOG,
                               '..................................');
            fnd_file.put_line (
                fnd_file.LOG,
                   ' v_table_get_inv_details_c.count '
                || v_table_get_inv_details_c.COUNT);
            fnd_file.put_line (fnd_file.LOG,
                               ' Call to the Patch procedure....');

            PATCH (v_table_get_inv_details_c, lv_organization_id, p_demand_class
                   , p_application, p_brand, p_division);

            fnd_file.put_line (fnd_file.LOG,
                               ' End of the Patch procedure....');
            fnd_file.put_line (fnd_file.LOG,
                               '..................................');


            EXIT WHEN v_table_get_inv_details_c.COUNT = 0;
        END LOOP;

        CLOSE get_inv_details_c;

        fnd_file.put_line (
            fnd_file.LOG,
            '...................................................................');
        fnd_file.put_line (fnd_file.LOG, 'End of SubProgram..');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'In Subprogram Exception ' || SQLERRM || SQLCODE);

            IF get_inv_details_c%ISOPEN
            THEN
                CLOSE get_inv_details_c;
            END IF;
    END SUB_PROGRAM;

    --------------------------------------------------------------------------------------------------------------------
    PROCEDURE PATCH (
        p_table_get_inv_details_c   IN g_table_get_inv_details_c,
        p_organization_id           IN VARCHAR2,
        p_demand_class              IN VARCHAR2,
        p_application               IN VARCHAR2,
        p_brand                     IN VARCHAR2,
        p_division                  IN VARCHAR2)
    AS
        l_atp_rec                      mrp_atp_pub.atp_rec_typ;
        x_atp_rec                      mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand            mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period                   mrp_atp_pub.atp_period_typ;
        x_atp_details                  mrp_atp_pub.atp_details_typ;
        x_return_status                VARCHAR2 (2000);
        x_msg_data                     VARCHAR2 (2000);
        x_msg_count                    NUMBER;
        l_session_id                   NUMBER;
        ln_cnt                         NUMBER := 0;
        x_error_message                VARCHAR2 (2000);
        lc_var                         VARCHAR2 (2000);
        ln_list                        INTEGER := 0;
        gn_limit                       INTEGER := 2000;
        lv_uom                         VARCHAR2 (10);
        lv_sku                         VARCHAR2 (50);
        empty_l_atp_rec                mrp_atp_pub.atp_rec_typ;

        l_count_MRP_ATP_DETAILS_TEMP   NUMBER := 0;
        ln_limit                       NUMBER := 3000;

        lt_inv_items_atr               g_table_get_inv_details_c; --NRK 04May15
        lt_inv_items_no_atr            g_table_get_inv_details_c; --NRK 04May15
        ln_atr_qty                     NUMBER := 0;              --NRK 04May15
        ln_a_cnt                       NUMBER := 0;              --NRK 04May15
        ln_na_cnt                      NUMBER := 0;              --NRK 04May15
        ln_av_quantity                 NUMBER := 0;

        CURSOR get_inv_details_c (cp_org_id     NUMBER,
                                  cp_brand      VARCHAR2,
                                  cp_division   VARCHAR2)
        IS
            SELECT inventory_item_id
              FROM XXD_COMMON_ITEMS_V
             WHERE     organization_id = cp_org_id
                   AND brand = cp_brand
                   AND division = cp_division
                   AND atp_flag = 'Y'
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));


        TYPE table_get_inv_details_c IS TABLE OF get_inv_details_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        v_table_get_inv_details_c      table_get_inv_details_c;

        --For HUBSOFT/ECOMM

        CURSOR get_atp_dtl_hsoft_c (cp_session_id NUMBER)
        IS
              /* -- Commented by BT Team on 7/20/2015 for CR 77
                         SELECT md_qty.inventory_item_id,
                                md_qty.organization_id,
                                md_qty.uom_code,
                                dt_qry.period_start_date,
                                SUM (cumulative_quantity) qty
                           FROM MRP_ATP_DETAILS_TEMP md_qty,
                                (SELECT DISTINCT
                                        inventory_item_id, organization_id, period_start_date
                                   FROM MRP_ATP_DETAILS_TEMP md_date
                                  WHERE Session_id = cp_session_id AND record_type = 1) dt_qry
                          WHERE     md_qty.INVENTORY_ITEM_ID = dt_qry.INVENTORY_ITEM_ID
                                AND md_qty.ORGANIZATION_ID = dt_qry.organization_id
                                AND md_qty.session_id = cp_session_id
                                AND MD_QTY.RECORD_TYPE = 1
                                AND TRUNC (DT_QRY.PERIOD_START_DATE) BETWEEN TRUNC (
                                                                                md_qty.period_start_date)
                                                                         AND TRUNC (
                                                                                md_qty.period_end_date)
                       GROUP BY md_qty.inventory_item_id,
                                md_qty.organization_id,
                                md_qty.uom_code,
                                dt_qry.period_start_date;
              */

              SELECT DISTINCT inventory_item_id,
                              organization_id,
                              uom_code,
                              qty,
                              MIN (period_start_date)
                              KEEP (DENSE_RANK FIRST
                                    ORDER BY period_start_date)
                              OVER (PARTITION BY inventory_item_id, organization_id, uom_code,
                                                 qty) Period_Start_Date
                FROM (  SELECT md_qty.inventory_item_id, md_qty.organization_id, md_qty.uom_code,
                               dt_qry.period_start_date, SUM (cumulative_quantity) qty
                          FROM MRP_ATP_DETAILS_TEMP md_qty,
                               (SELECT DISTINCT inventory_item_id, organization_id, period_start_date
                                  FROM MRP_ATP_DETAILS_TEMP md_date
                                 WHERE     Session_id = cp_session_id
                                       AND record_type = 1) dt_qry
                         WHERE     md_qty.INVENTORY_ITEM_ID =
                                   dt_qry.INVENTORY_ITEM_ID
                               AND md_qty.ORGANIZATION_ID =
                                   dt_qry.organization_id
                               AND md_qty.session_id = cp_session_id
                               AND MD_QTY.RECORD_TYPE = 1
                               AND TRUNC (DT_QRY.PERIOD_START_DATE) BETWEEN TRUNC (
                                                                                md_qty.period_start_date)
                                                                        AND TRUNC (
                                                                                md_qty.period_end_date)
                      GROUP BY md_qty.inventory_item_id, md_qty.organization_id, md_qty.uom_code,
                               dt_qry.period_start_date) Main_query
            ORDER BY inventory_item_id, organization_id, uom_code,
                     qty;
    /* Commented by BT Team on 31-May
               SELECT main_query.inventory_item_id,
                      main_query.organization_id,
                      main_query.uom_code,
                      main_query.period_start_date,
                      MAX (
                           main_query.period_quantity
                         + (SELECT SUM (NVL (period_quantity, 0))
                              FROM MRP_ATP_DETAILS_TEMP madt_neg
                             WHERE     1 = 1  --pegging_id = main_query.pegging_id
                                   AND madt_neg.inventory_item_id =
                                          main_query.inventory_item_id
                                   AND madt_neg.record_type = 1
                                   AND madt_neg.session_id = cp_session_id
                                   AND madt_neg.organization_id =
                                          main_query.organization_id
                                   AND period_quantity < 0))
                         period_quantity
                 FROM (SELECT matpd_1.record_type,
                              matpd_1.inventory_item_id,
                              matpd_1.organization_id,
                              matpd_1.uom_code,
                              matpd_1.atp_level,
                              matpd_1.pegging_type,
                              matpd_1.period_start_date,
                              SUM (
                                 matpd_1.period_quantity)
                              OVER (
                                 PARTITION BY matpd_1.inventory_item_id,
                                              matpd_1.organization_id,
                                              matpd_1.pegging_type
                                 ORDER BY period_start_date
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                 period_quantity
                         FROM MRP_ATP_DETAILS_TEMP matpd_1
                        WHERE     matpd_1.session_id = cp_session_id
                              AND matpd_1.record_type = 1
                              AND (   TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                 matpd_1.period_start_date)
                                                          AND TRUNC (
                                                                 matpd_1.period_end_date)
                                   OR TRUNC (matpd_1.period_start_date) >
                                         TRUNC (SYSDATE))
                              AND matpd_1.period_quantity > 0
                              AND matpd_1.pegging_id IN
                                     (SELECT pegging_id
                                        FROM MRP_ATP_DETAILS_TEMP matpd_2
                                       WHERE     matpd_2.session_id =
                                                    matpd_1.session_id
                                             AND matpd_2.record_type = 3
                                             AND matpd_2.pegging_type = 3
                                             AND matpd_2.INVENTORY_ITEM_ID =
                                                    matpd_1.INVENTORY_ITEM_ID
                                             AND matpd_2.ORGANIZATION_ID =
                                                    matpd_1.ORGANIZATION_ID)) main_query
             GROUP BY main_query.inventory_item_id,
                      main_query.organization_id,
                      main_query.uom_code,
                      main_query.period_start_date;
    */

    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Time when Patch Procedure begun : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        ----------------------------------------------------------------------
        --Start of Changes for ATR NRK  04May15
        ----------------------------------------------------------------------

        --      FOR ln_cnt IN 1 .. p_table_get_inv_details_c.COUNT
        --      LOOP
        --         BEGIN
        --            ln_atr_qty :=
        --               NVL (
        --                  do_inv_utils_pub.item_atr_quantity (
        --                     p_organization_id     => p_organization_id,
        --                     p_inventory_item_id   => p_table_get_inv_details_c (
        --                                                ln_cnt).inventory_item_id),
        --                  0);
        --         EXCEPTION
        --            WHEN OTHERS
        --            THEN
        --               ln_atr_qty := 0;
        --               fnd_file.put_line (
        --                  fnd_file.LOG,
        --                     'Exception while calculating ATR for item : '
        --                  || p_table_get_inv_details_c (ln_cnt).inventory_item_id); --for Debug
        --               fnd_file.put_line (fnd_file.LOG,
        --                                  'Error : ' || SQLERRM || SQLCODE); --for Debug
        --         END;
        --
        --         IF ln_atr_qty > 0
        --         THEN
        --            ln_a_cnt := ln_a_cnt + 1;
        --            lt_inv_items_atr (ln_a_cnt).inventory_item_id :=
        --               p_table_get_inv_details_c (ln_cnt).inventory_item_id;
        --         ELSE
        --            ln_na_cnt := ln_na_cnt + 1;
        --            lt_inv_items_no_atr (ln_na_cnt).inventory_item_id :=
        --               p_table_get_inv_details_c (ln_cnt).inventory_item_id;
        --         END IF;
        --      END LOOP;

        --For DEBUG
        --      fnd_file.put_line (
        --         fnd_file.LOG,
        --            'p_table_get_inv_details_c.COUNT -  '
        --         || p_table_get_inv_details_c.COUNT);
        --      fnd_file.put_line (
        --         fnd_file.LOG,
        --         'lt_inv_items_atr.COUNT -  ' || lt_inv_items_atr.COUNT);
        --      fnd_file.put_line (
        --         fnd_file.LOG,
        --         'lt_inv_items_no_atr.COUNT -  ' || lt_inv_items_no_atr.COUNT);

        ----------------------------------------------------------------------
        --End of Changes for ATR NRK  04May15
        ----------------------------------------------------------------------

        --            ln_a_cnt := ln_a_cnt + 1;
        --            lt_inv_items_atr (ln_a_cnt).inventory_item_id :=
        --               p_table_get_inv_details_c (ln_cnt).inventory_item_id;

        SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

        fnd_file.put_line (fnd_file.LOG, 'Session ID -  ' || l_session_id);

        ln_list           := p_table_get_inv_details_c.COUNT;     --NRK04May15
        -- ln_list := lt_inv_items_atr.COUNT;                         -- NRK04May15
        fnd_file.put_line (fnd_file.LOG, 'ln_list -  ' || ln_list);

        -- Reset the Record types and the status.
        l_atp_rec         := empty_l_atp_rec;
        x_atp_rec         := empty_l_atp_rec;
        x_return_status   := NULL;

        msc_atp_global.extend_atp (l_atp_rec, x_return_status, ln_list);
        msc_atp_global.extend_atp (x_atp_rec, x_return_status, ln_list);

        fnd_file.put_line (
            fnd_file.LOG,
            'l_atp_rec after Initialization -  ' || l_atp_rec.inventory_item_id.COUNT);
        fnd_file.put_line (
            fnd_file.LOG,
            'x_atp_rec after Initialization -  ' || x_atp_rec.inventory_item_id.COUNT);
        fnd_file.put_line (
            fnd_file.LOG,
            'x_return_status after Initiali -  ' || x_return_status);


        FOR ln_cnt IN 1 .. p_table_get_inv_details_c.COUNT        --NRK04May15
        --      FOR ln_cnt IN 1 .. lt_inv_items_atr.COUNT                   --NRK04May15
        LOOP
            BEGIN
                lv_uom                                        := NULL;

                SELECT primary_uom_code
                  INTO lv_uom
                  FROM mtl_system_items_b
                 WHERE     inventory_item_id =
                           --lt_inv_items_atr (ln_cnt).inventory_item_id
                           p_table_get_inv_details_c (ln_cnt).inventory_item_id
                       AND organization_id = p_organization_id;


                IF p_application IN ('HUBSOFT', 'ECOMM')
                THEN
                    l_atp_rec.quantity_ordered (ln_cnt)   := 9999999999;
                    l_atp_rec.Insert_Flag (ln_cnt)        := 1; -- Hardcoded value for profile MRP:Calculate Supply Demand 0= NO
                    l_atp_rec.Attribute_04 (ln_cnt)       := 1; -- With this Attribute set to 1 this will enable the Period (Horizontal Plan),
                ELSE
                    l_atp_rec.quantity_ordered (ln_cnt)   := 1;
                    l_atp_rec.Insert_Flag (ln_cnt)        := 0; -- Hardcoded value for profile MRP:Calculate Supply Demand 0= NO
                    l_atp_rec.Attribute_04 (ln_cnt)       := 0; -- With this Attribute set to 1 this will enable the Period (Horizontal Plan),
                END IF;


                l_atp_rec.inventory_item_id (ln_cnt)          :=
                    p_table_get_inv_details_c (ln_cnt).inventory_item_id; --NRK04May15
                --            l_atp_rec.inventory_item_id (ln_cnt) :=
                --               lt_inv_items_atr (ln_cnt).inventory_item_id;       --NRK04May15
                l_atp_rec.quantity_uom (ln_cnt)               := lv_uom; --'PR';
                l_atp_rec.requested_ship_date (ln_cnt)        := SYSDATE; --TO_DATE ('10-FEB-2015');
                l_atp_rec.source_organization_id (ln_cnt)     :=
                    p_organization_id;     -- cur.organization_id; -- Ram 2/28
                l_atp_rec.demand_class (ln_cnt)               := p_demand_class; -- cur.demand_class; --'UGG-NEIMAN MARCUS'; --'UGG-THE WALKING COMPANY'
                l_atp_rec.action (ln_cnt)                     := 100;
                l_atp_rec.OE_Flag (ln_cnt)                    := 'N';
                l_atp_rec.Customer_Id (ln_cnt)                := NULL;
                l_atp_rec.Customer_Site_Id (ln_cnt)           := NULL;
                l_atp_rec.Calling_Module (ln_cnt)             := 660; -- use 724 when calling from MSC_ATP_CALL - otherwise NULL
                l_atp_rec.Row_Id (ln_cnt)                     := NULL;
                l_atp_rec.Source_Organization_Code (ln_cnt)   := NULL;
                l_atp_rec.Organization_Id (ln_cnt)            :=
                    p_organization_id;     -- cur.organization_id; -- Ram 2/28
                l_atp_rec.order_number (ln_cnt)               := NULL;
                l_atp_rec.line_number (ln_cnt)                := NULL;
                l_atp_rec.override_flag (ln_cnt)              := 'N';
                l_atp_rec.Identifier (ln_cnt)                 :=
                    xxd_master_atp_idnt_s.NEXTVAL;
            END;
        END LOOP;

        /*SELECT COUNT (*)
          INTO l_count_MRP_ATP_DETAILS_TEMP
          FROM MRP_ATP_DETAILS_TEMP;

        fnd_file.put_line (
           fnd_file.LOG,
              'Before call of API count of MRP TABLE-  '
           || l_count_MRP_ATP_DETAILS_TEMP);*/

        fnd_file.put_line (
            fnd_file.LOG,
               'Time before calling API : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        apps.mrp_atp_pub.call_atp (
            p_session_id          => l_session_id,
            p_atp_rec             => l_atp_rec,
            x_atp_rec             => x_atp_rec,
            x_atp_supply_demand   => x_atp_supply_demand,
            x_atp_period          => x_atp_period,
            x_atp_details         => x_atp_details,
            x_return_status       => x_return_status,
            x_msg_data            => x_msg_data,
            x_msg_count           => x_msg_count);
        fnd_file.put_line (
            fnd_file.LOG,
               'Time After calling API : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        /*fnd_file.put_line (
           fnd_file.LOG,
              'After call of API count of l_atp_rec-  '
           || l_atp_rec.inventory_item_id.COUNT);
        fnd_file.put_line (
           fnd_file.LOG,
              'After call of API count of x_atp_rec-  '
           || x_atp_rec.inventory_item_id.COUNT);

        SELECT COUNT (*)
          INTO l_count_MRP_ATP_DETAILS_TEMP
          FROM MRP_ATP_DETAILS_TEMP;

        fnd_file.put_line (
           fnd_file.LOG,
              'After call of API count of MRP TABLE-  '
           || l_count_MRP_ATP_DETAILS_TEMP);*/

        Fnd_file.put_line (fnd_file.LOG,
                           'x_return_status : ' || x_return_status);


        /*fnd_file.put_line (fnd_file.LOG,
                           'p_application    : ' || p_application);*/
        fnd_file.put_line (
            fnd_file.LOG,
               'Time before Inserting to Full Load : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        IF (x_return_status = 'S')
        THEN
            --------------------------------------------------------
            -- Loading Error messages to Error Table if any
            -------------------------------------------------------
            FOR e IN 1 .. x_atp_rec.Inventory_item_id.COUNT
            LOOP
                x_error_message   := '';

                IF (x_atp_rec.ERROR_CODE (e) <> 0)
                THEN
                    SELECT SUBSTR (meaning, 1, 250)
                      INTO x_error_message
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (e);

                    INSERT INTO XXDO.XXD_MASTER_ATP_ERROR_T (
                                    SLNO,
                                    INVENTORY_ITEM_ID,
                                    INV_ORGANIZATION_ID,
                                    DEMAND_CLASS_CODE,
                                    APPLICATION,
                                    BRAND,
                                    UOM_CODE,
                                    ERROR_CODE,
                                    ERROR_MESSAGE,
                                    CREATION_DATE,
                                    CREATED_BY)
                         VALUES (XXD_ATP_ERROR_SLNO_S.NEXTVAL, x_atp_rec.inventory_item_id (e), x_atp_rec.source_organization_id (e), x_atp_rec.demand_class (e), p_application, p_brand, x_atp_rec.Quantity_UOM (e), x_atp_rec.ERROR_CODE (e), x_error_message
                                 , SYSDATE, gn_user_id);
                END IF;
            END LOOP;

            COMMIT;

            IF p_application IN ('HUBSOFT', 'ECOMM')
            THEN
                FOR get_atp_dtl_hsoft_rec
                    IN get_atp_dtl_hsoft_c (l_session_id)
                LOOP
                    BEGIN
                        SAVEPOINT xxd_hubsoft_svpt;

                        /*fnd_file.put_line (
                           fnd_file.LOG,
                              'Hubsoft Result - '
                           || get_atp_dtl_hsoft_rec.inventory_item_id
                           || '-'
                           || get_atp_dtl_hsoft_rec.period_Quantity
                           || '-'
                           || get_atp_dtl_hsoft_rec.Period_Start_Date);*/

                        BEGIN
                            lv_sku   := NULL;

                            SELECT item_number
                              INTO lv_sku
                              FROM XXD_COMMON_ITEMS_V
                             WHERE     inventory_item_id =
                                       get_atp_dtl_hsoft_rec.inventory_item_id
                                   AND organization_id =
                                       get_atp_dtl_hsoft_rec.organization_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error deriving SKU - ' || SQLERRM);
                        END;

                        --                  IF TRUNC (get_atp_dtl_hsoft_rec.Period_Start_Date) >=
                        --                        TRUNC (SYSDATE)
                        --                  THEN
                        INSERT INTO XXDO.XXD_MASTER_ATP_FULL_T (
                                        SLNO,
                                        SKU,
                                        INVENTORY_ITEM_ID,
                                        INV_ORGANIZATION_ID,
                                        DEMAND_CLASS_CODE,
                                        APPLICATION,
                                        BRAND,
                                        UOM_CODE,
                                        REQUESTED_SHIP_DATE,
                                        AVAILABLE_QUANTITY,
                                        AVAILABLE_DATE,
                                        CREATION_DATE,
                                        CREATED_BY,
                                        LAST_UPDATE_LOGIN,
                                        LAST_UPDATE_DATE,
                                        LAST_UPDATED_BY)
                             VALUES (XXD_MASTER_ATP_T_S.NEXTVAL, lv_sku, get_atp_dtl_hsoft_rec.inventory_item_id, get_atp_dtl_hsoft_rec.organization_id, p_demand_class, p_application, p_brand, get_atp_dtl_hsoft_rec.uom_code, SYSDATE, -- Start modification by BT team on 31-May-15
                                                                                                                                                                                                                                          --                          get_atp_dtl_hsoft_rec.period_Quantity,
                                                                                                                                                                                                                                          NVL (get_atp_dtl_hsoft_rec.qty, 0), -- End modification by BT team on 31-May-15
                                                                                                                                                                                                                                                                              NVL (get_atp_dtl_hsoft_rec.Period_Start_Date, SYSDATE), SYSDATE, gn_user_id, gn_user_id, SYSDATE
                                     , gn_user_id);
                    --                  END IF;
                    --fnd_file.put_line (fnd_file.LOG, '0. Commit Executed successfully');

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ROLLBACK TO xxd_hubsoft_svpt;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error While Detail Records - ' || SQLERRM);
                    END;
                END LOOP;

                ----------------------------------------------------------------------
                --Start of Changes for ATR NRK  04May15 (Adding the records of NO ATR inventory items)
                ----------------------------------------------------------------------
                --            FOR i IN 1 .. lt_inv_items_no_atr.COUNT
                --            LOOP
                --               BEGIN
                --                  lv_sku := NULL;
                --
                --                  SELECT item_number
                --                    INTO lv_sku
                --                    FROM XXD_COMMON_ITEMS_V
                --                   WHERE     inventory_item_id =
                --                                lt_inv_items_no_atr (i).inventory_item_id
                --                         AND organization_id = p_organization_id;
                --               EXCEPTION
                --                  WHEN OTHERS
                --                  THEN
                --                     fnd_file.put_line (fnd_file.LOG,
                --                                        'Error deriving SKU - ' || SQLERRM);
                --               END;
                --
                --               INSERT INTO XXDO.XXD_MASTER_ATP_FULL_T (SLNO,
                --                                                       SKU,
                --                                                       INVENTORY_ITEM_ID,
                --                                                       INV_ORGANIZATION_ID,
                --                                                       DEMAND_CLASS_CODE,
                --                                                       APPLICATION,
                --                                                       BRAND,
                --                                                       UOM_CODE,
                --                                                       REQUESTED_SHIP_DATE,
                --                                                       AVAILABLE_QUANTITY,
                --                                                       AVAILABLE_DATE,
                --                                                       CREATION_DATE,
                --                                                       CREATED_BY,
                --                                                       LAST_UPDATE_LOGIN,
                --                                                       LAST_UPDATE_DATE,
                --                                                       LAST_UPDATED_BY)
                --                    VALUES (XXD_MASTER_ATP_T_S.NEXTVAL,
                --                            lv_sku,
                --                            lt_inv_items_no_atr (i).inventory_item_id,
                --                            p_organization_id,
                --                            p_demand_class,
                --                            p_application,
                --                            p_brand,
                --                            NULL,                             -- UOMCODE Null?
                --                            SYSDATE,                    -- REQUESTED_SHIP_DATE
                --                            0,                           -- Available_Quantity
                --                            SYSDATE,                         -- AVAILABLE_DATE
                --                            SYSDATE,
                --                            gn_user_id,
                --                            gn_user_id,
                --                            SYSDATE,
                --                            gn_user_id);
                --            END LOOP;

                ----------------------------------------------------------------------
                --End of Changes for ATR NRK  04May15
                ----------------------------------------------------------------------
                COMMIT;
            ELSE
                FOR k IN 1 .. x_atp_rec.Inventory_item_id.COUNT
                LOOP
                    BEGIN
                        /*fnd_file.put_line (
                           fnd_file.LOG,
                              'Result - '
                           || x_atp_rec.inventory_item_id (k)
                           || '-'
                           || x_atp_rec.quantity_ordered (k)
                           || '-'
                           || x_atp_rec.quantity_uom (k)
                           || '-'
                           || x_atp_rec.requested_ship_date (k)
                           || '-'
                           || x_atp_rec.source_organization_id (k)
                           || '-'
                           || x_atp_rec.demand_class (k)
                           || '-'
                           || x_atp_rec.Ship_Date (k)
                           || '-'
                           || x_atp_rec.Arrival_Date (k)
                           || '-'
                           || x_atp_rec.Available_Quantity (k)
                           || '-'
                           || x_atp_rec.Requested_Date_Quantity (k)
                           || '-'
                           || x_atp_rec.Group_Ship_Date (k));*/


                        BEGIN
                            lv_sku   := NULL;

                            SELECT item_number
                              INTO lv_sku
                              FROM XXD_COMMON_ITEMS_V
                             WHERE     inventory_item_id =
                                       x_atp_rec.inventory_item_id (k)
                                   AND organization_id =
                                       x_atp_rec.source_organization_id (k);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error deriving SKU - ' || SQLERRM);
                        END;


                        IF     p_application = 'RMS'
                           AND constraint_flag_exists (
                                   l_session_id,
                                   x_atp_rec.inventory_item_id (k),
                                   x_atp_rec.source_organization_id (k)) <>
                               0
                        THEN
                            ln_av_quantity   := 0;
                        ELSE
                            ln_av_quantity   :=
                                x_atp_rec.Available_Quantity (k);
                        END IF;


                        INSERT INTO XXDO.XXD_MASTER_ATP_FULL_T (
                                        SLNO,
                                        SKU,
                                        INVENTORY_ITEM_ID,
                                        INV_ORGANIZATION_ID,
                                        DEMAND_CLASS_CODE,
                                        APPLICATION,
                                        BRAND,
                                        UOM_CODE,
                                        REQUESTED_SHIP_DATE,
                                        AVAILABLE_QUANTITY,
                                        AVAILABLE_DATE,
                                        CREATION_DATE,
                                        CREATED_BY,
                                        LAST_UPDATE_LOGIN,
                                        LAST_UPDATE_DATE,
                                        LAST_UPDATED_BY)
                             VALUES (XXD_MASTER_ATP_T_S.NEXTVAL, lv_sku, x_atp_rec.inventory_item_id (k), x_atp_rec.source_organization_id (k), x_atp_rec.demand_class (k), p_application, p_brand, x_atp_rec.Quantity_UOM (k), x_atp_rec.requested_ship_date (k), --                          NVL (x_atp_rec.Available_Quantity (k),0),
                                                                                                                                                                                                                                                                   ln_av_quantity, NVL (x_atp_rec.Arrival_Date (k), SYSDATE), SYSDATE, gn_user_id, gn_user_id, SYSDATE
                                     , gn_user_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error While Summary Records - ' || SQLERRM);
                    END;
                END LOOP;
            ----------------------------------------------------------------------
            --Start of Changes for ATR NRK  04May15 (Adding the records of NO ATR inventory items)
            ----------------------------------------------------------------------
            --            FOR i IN 1 .. lt_inv_items_no_atr.COUNT
            --            LOOP
            --               BEGIN
            --                  lv_sku := NULL;
            --
            --                  SELECT item_number
            --                    INTO lv_sku
            --                    FROM XXD_COMMON_ITEMS_V
            --                   WHERE     inventory_item_id =
            --                                lt_inv_items_no_atr (i).inventory_item_id
            --                         AND organization_id = p_organization_id;
            --               EXCEPTION
            --                  WHEN OTHERS
            --                  THEN
            --                     fnd_file.put_line (fnd_file.LOG,
            --                                        'Error deriving SKU - ' || SQLERRM);
            --               END;
            --
            --               INSERT INTO XXDO.XXD_MASTER_ATP_FULL_T (SLNO,
            --                                                       SKU,
            --                                                       INVENTORY_ITEM_ID,
            --                                                       INV_ORGANIZATION_ID,
            --                                                       DEMAND_CLASS_CODE,
            --                                                       APPLICATION,
            --                                                       BRAND,
            --                                                       UOM_CODE,
            --                                                       REQUESTED_SHIP_DATE,
            --                                                       AVAILABLE_QUANTITY,
            --                                                       AVAILABLE_DATE,
            --                                                       CREATION_DATE,
            --                                                       CREATED_BY,
            --                                                       LAST_UPDATE_LOGIN,
            --                                                       LAST_UPDATE_DATE,
            --                                                       LAST_UPDATED_BY)
            --                    VALUES (XXD_MASTER_ATP_T_S.NEXTVAL,
            --                            lv_sku,
            --                            lt_inv_items_no_atr (i).inventory_item_id,
            --                            p_organization_id,
            --                            p_demand_class,
            --                            p_application,
            --                            p_brand,
            --                            NULL,                             -- UOMCODE Null?
            --                            SYSDATE,                    -- REQUESTED_SHIP_DATE
            --                            0,                           -- Available_Quantity
            --                            SYSDATE,                         -- AVAILABLE_DATE
            --                            SYSDATE,
            --                            gn_user_id,
            --                            gn_user_id,
            --                            SYSDATE,
            --                            gn_user_id);
            --            END LOOP;
            ----------------------------------------------------------------------
            --End of Changes for ATR NRK  04May15
            ----------------------------------------------------------------------
            END IF;

            COMMIT;
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'x_msg_data=' || x_msg_data);
            Fnd_file.put_line (fnd_file.LOG,
                               'x_return_status : ' || x_return_status);
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Time after Inserting to Full Load : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_inv_details_c%ISOPEN
            THEN
                CLOSE get_inv_details_c;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'exception=' || SQLERRM);
    END PATCH;

    FUNCTION constraint_flag_exists (p_session_id NUMBER, p_inventory_item_id NUMBER, p_organization_id NUMBER)
        RETURN NUMBER
    IS
        ln_count   NUMBER := 0;
    BEGIN
        -- Start modification by BT Team on 05-Oct-15
        SELECT COUNT (*)
          INTO ln_count
          FROM mrp_atp_details_temp mad
         WHERE     mad.session_id = p_session_id
               AND mad.inventory_item_id = p_inventory_item_id
               AND mad.organization_id = p_organization_id
               AND CONSTRAINT_FLAG = 'Y';

        /* -- Commented the code by BT team on 08-Oct-15
             SELECT COUNT (*)
                INTO ln_count
                FROM mrp_atp_schedule_temp mad
               WHERE     mad.session_id = p_session_id
                     AND mad.inventory_item_id = p_inventory_item_id
                     AND mad.organization_id = p_organization_id
                     AND status_FLAG = 99;
        */

        RETURN ln_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception while checking the constraint flag ');
            fnd_file.put_line (
                fnd_file.LOG,
                   'Session/Item_ID/Inv_Org_ID : '
                || p_session_id
                || '/'
                || p_inventory_item_id
                || '/'
                || p_organization_id);
            fnd_file.put_line (fnd_file.LOG, 'Error :' || SQLERRM || SQLCODE);
            ln_count   := 0;

            RETURN ln_count;
    END constraint_flag_exists;

    --------------------------------------------------------------------------------------------------------------------
    -- NRK Added 05May 2015
    PROCEDURE purge_atp_temp_tbls (p_no_of_hrs IN NUMBER)
    IS
        l_request_id      NUMBER;
        lb_wait           BOOLEAN;
        lc_phase          VARCHAR2 (30);
        lc_status         VARCHAR2 (30);
        lc_dev_phase      VARCHAR2 (30);
        lc_dev_status     VARCHAR2 (30);
        ln_import_check   NUMBER;
        lc_message        VARCHAR2 (100);
        ln_user_id        NUMBER;
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;
    BEGIN
        /*BEGIN
           fnd_file.put_line (fnd_file.LOG,'--------------------------------------------------');
           fnd_file.put_line (fnd_file.LOG, 'Purging the temp Tables....in ASCP ');
           fnd_file.put_line (fnd_file.LOG,'--------------------------------------------------');
           --Initializing environment to run the program by SYSADMIN user from SYSTEM ADMINISTRATOR responsibility
           fnd_global.apps_initialize@BT_EBS_TO_ASCP (0, 20420, 1);

           l_request_id :=
              fnd_request.submit_request@BT_EBS_TO_ASCP (
                 application   => 'MSC',
                 program       => 'MSCATPPURG',
                 argument1     => 1);

           IF l_request_id > 0
           THEN

                fnd_file.put_line (fnd_file.LOG, 'Request '||l_request_id||'submitted in ASCP Server...');
                COMMIT;
                 LOOP
                    lc_dev_phase := NULL;
                    lc_dev_status := NULL;
                    lb_wait :=
                       fnd_concurrent.wait_for_request@BT_EBS_TO_ASCP (
                          request_id   => l_request_id  ,
                          INTERVAL     => 1,
                          max_wait     => 1,
                          phase        => lc_phase,
                          status       => lc_status,
                          dev_phase    => lc_dev_phase,
                          dev_status   => lc_dev_status,
                          MESSAGE      => lc_message);

                    IF (   (UPPER (lc_dev_phase) = 'COMPLETE')
                        OR (UPPER (lc_phase) = 'COMPLETED'))
                    THEN
                       fnd_file.put_line (
                          fnd_file.LOG,
                             'Concurrent request '
                          || l_request_id
                          || ' : Completed');
                       EXIT;
                    END IF;
                 END LOOP;
           ELSE
              ROLLBACK;
           END IF;
        EXCEPTION
           WHEN OTHERS
           THEN
              --x_retcode := 2;
              fnd_file.put_line (
                 fnd_file.LOG,
                 'Unexp error while purging tables in ASCP Server ' || SQLERRM);
        END;*/
        -- Commented as per Doc ID 466800.1

        BEGIN
            fnd_file.put_line (
                fnd_file.LOG,
                '--------------------------------------------------');
            fnd_file.put_line (fnd_file.LOG,
                               'Purging the temp Tables....in EBS ');
            fnd_file.put_line (
                fnd_file.LOG,
                '--------------------------------------------------');

            ln_user_id   := fnd_profile.VALUE ('USER_ID');

            SELECT frl.application_id, frl.responsibility_id
              INTO ln_resp_appl_id, ln_resp_id
              FROM fnd_responsibility_tl frl
             WHERE     frl.responsibility_name = 'System Administrator'
                   AND frl.LANGUAGE = USERENV ('LANG');

            --Initializing environment to run the program by SYSADMIN user from SYSTEM ADMINISTRATOR responsibility
            fnd_global.apps_initialize (ln_user_id,
                                        ln_resp_id,
                                        ln_resp_appl_id);

            l_request_id   :=
                fnd_request.submit_request (application   => 'MSC',
                                            program       => 'MSCATPPURG',
                                            argument1     => p_no_of_hrs);

            IF l_request_id > 0
            THEN
                COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Request '
                    || l_request_id
                    || 'submitted in EBS Server...');

                LOOP
                    lc_dev_phase    := NULL;
                    lc_dev_status   := NULL;
                    lb_wait         :=
                        fnd_concurrent.wait_for_request (
                            request_id   => l_request_id,
                            INTERVAL     => 1,
                            max_wait     => 1,
                            phase        => lc_phase,
                            status       => lc_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);

                    IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Concurrent request '
                            || l_request_id
                            || ' : Completed');
                        EXIT;
                    END IF;
                END LOOP;
            ELSE
                ROLLBACK;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                --x_retcode := 2;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unexp error while purging tables in EBS Server '
                    || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Waiting for the submitted purge requests to complete');
        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In Exception while Purging ATP Temp Tables'
                || SQLERRM
                || SQLCODE);
    END purge_atp_temp_tbls;
--------------------------------------------------------------------------------------------------------------------
END XXD_ATP_REFRESH_PKG;
/
