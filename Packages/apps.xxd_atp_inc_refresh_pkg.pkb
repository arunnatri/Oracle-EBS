--
-- XXD_ATP_INC_REFRESH_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_ATP_INC_REFRESH_PKG
AS
    /**********************************************************************************************
    * Package         : APPS.XXD_ATP_INC_REFRESH_PKG
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
    ************************************************************************************************/
    --Profile Options used in the Program
    --XXD_ATP_REFRESH_DATE --> meant to hold last refresh Date and Time of the incremental Program
    --XXD_ATP_RUN_DATE      --> meant to store the current refresh Date and Time    of the Incremental Program

    -- Global Variables
    gn_user_id          NUMBER := fnd_profile.VALUE ('USER_ID');
    gn_resp_id          NUMBER := fnd_profile.VALUE ('RESP_ID');
    gn_resp_appl_id     NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');
    gd_sysdate          DATE := SYSDATE;
    gd_last_refresh     DATE
        := TO_DATE (FND_PROFILE.VALUE ('XXD_ATP_REFRESH_DATE'),
                    'DD-MON-YYYY HH24:MI:SS');
    ln_del_error_days   NUMBER
                            := fnd_profile.VALUE ('XXD_ATP_DEL_ERROR_DAYS');


    PROCEDURE main_prog (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    AS
        lb_save_res   BOOLEAN;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Begin of Deckers Master ATP Refresh Incremental Load ');

        -- Initialize the Environment
        fnd_global.apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);

        -- Deleting the records from Error Table
        fnd_file.put_line (fnd_file.LOG, 'Truncating the Full Error Table');

        DELETE FROM XXDO.XXD_MASTER_ATP_ERROR_T
              WHERE creation_date < SYSDATE - NVL (ln_del_error_days, 10);

        COMMIT;

        -- Printing the Dates
        fnd_file.put_line (
            fnd_file.LOG,
               'Last Refresh Date     : '
            || TO_CHAR (gd_last_refresh, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               'GdSydate               : '
            || TO_CHAR (gd_sysdate, 'DD-MON-YYYY HH24:MI:SS'));

        fnd_file.put_line (fnd_file.LOG,
                           'Setting Profile XXD_ATP_RUN_DATE to GdSysdate..');
        lb_save_res   :=
            FND_PROFILE.SAVE ('XXD_ATP_RUN_DATE', TO_CHAR (gd_sysdate, 'DD-MON-YYYY HH24:MI:SS'), 'SITE'
                              , NULL, NULL);

        -- Call to extract trxs for inventory item ids for above date range
        fnd_file.put_line (
            fnd_file.LOG,
            '1.0 Extracting and Loading the data into Temp/Audit Table..');
        extract_trxs;

        fnd_file.put_line (
            fnd_file.LOG,
            '2.0 Call to trigger SubProgram(s) for ATP details..');
        call_to_sub_prog (x_errbuf, x_retcode);

        fnd_file.put_line (
            fnd_file.LOG,
            ' End of Deckers Master ATP Refresh Incremental Load  ');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               '4.0 Exception in Main Program:' || SQLERRM);
    END main_prog;

    ----------------------------------------------------------------------------------------------------------
    PROCEDURE extract_trxs
    AS
        -- v_cutoff_Date DATE;
        v_uom_code            VARCHAR2 (30);
        ld_current_run_Date   DATE
            := TO_DATE (FND_PROFILE.VALUE ('XXD_ATP_RUN_DATE'),
                        'DD-MON-YYYY HH24:MI:SS');

        CURSOR get_msc_trxs_cur (p_current_run_date DATE)
        IS
            SELECT DISTINCT msi.sr_inventory_item_id inventory_item_id, mad.organization_id, mad.demand_class
              FROM msc_alloc_demands@BT_EBS_TO_ASCP mad, msc_system_items@BT_EBS_TO_ASCP msi
             WHERE     mad.inventory_item_id = msi.inventory_item_id
                   AND mad.organization_id = msi.organization_id
                   AND mad.plan_id = msi.plan_id
                   AND mad.last_update_date >= gd_last_refresh
                   AND mad.last_update_date < p_current_run_date;
    BEGIN
        --v_cutoff_Date := TRUNC(SYSDATE);

        fnd_file.put_line (fnd_file.LOG, '1.1 In extract_trxs Procedure...');
        fnd_file.put_line (
            fnd_file.LOG,
               'Loading temp table...with ld_current_run_Date : '
            || TO_CHAR (ld_current_run_Date, 'DD-MON-YYYY HH24:MI:SS'));

        FOR get_msc_trxs_rec IN get_msc_trxs_cur (ld_current_run_Date)
        LOOP
            INSERT INTO XXDO.XXD_ATP_STG_T (SLNO, INVENTORY_ITEM_ID, ORGANIZATION_ID, DEMAND_CLASS, TRANSACTION_DATE, PLANNING_ORGANIZATION_ID, ATP_POPULATED_DATE, STATUS_FLAG, LAST_UPDATE_LOGIN, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE
                                            , LAST_UPDATED_BY)
                 VALUES (XXD_ATP_STG_T_S.NEXTVAL                  -- Sequence.
                                                , get_msc_trxs_rec.inventory_item_id, get_msc_trxs_rec.organization_id, get_msc_trxs_rec.demand_class, NULL -- TrxDate (for Now its Null)
                                                                                                                                                           , NULL -- PlanningOrganization_id
                                                                                                                                                                 , NULL -- ATP Populated_date
                                                                                                                                                                       , 'L' -- Loaded / 'S' Successfully Uploaded to Incremental.
                                                                                                                                                                            , gn_user_id, ld_current_run_Date, gn_user_id, ld_current_run_Date
                         , gn_user_id);
        END LOOP;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
            '1.2 Data loaded to the Audit table Successfully ...');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                '1.3 Exception in extract_trxs Procedure :' || SQLERRM);
    END extract_trxs;

    ----------------------------------------------------------------------------------------------------------
    PROCEDURE call_to_sub_prog (x_errbuf    OUT VARCHAR2,
                                x_retcode   OUT VARCHAR2)
    AS
        CURSOR get_stg_dtls_cur IS
            SELECT DISTINCT xstg.demand_class, xstg.organization_id
              FROM xxd_atp_stg_t xstg
             WHERE status_flag = 'L';

        lv_application    VARCHAR2 (100) := NULL;
        lv_org_code       VARCHAR2 (10) := NULL;
        lv_brand          VARCHAR2 (10) := NULL;
        l_request_id      NUMBER;
        lb_wait           BOOLEAN;
        lc_phase          VARCHAR2 (30);
        lc_status         VARCHAR2 (30);
        lc_dev_phase      VARCHAR2 (30);
        lc_dev_status     VARCHAR2 (30);
        ln_import_check   NUMBER;
        lc_message        VARCHAR2 (100);
        l_req_id          request_table;
        i                 NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           '2.0 In call_to_sub_prog Procedure  ...');

        FOR submit_rec IN get_stg_dtls_cur
        LOOP
            BEGIN
                lv_application   := NULL;
                lv_org_code      := NULL;
                lv_brand         := NULL;

                SELECT flv.attribute3                           -- application
                                     , flv.attribute1               --Org_code
                                                     , flv.attribute4  --brand
                  INTO lv_application, lv_org_code, lv_brand
                  FROM fnd_lookup_values flv, mtl_parameters mp
                 WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                       AND flv.language = USERENV ('LANG')
                       -- AND flv.enabled_flag = 'Y'
                       AND flv.attribute2 = submit_rec.demand_class -- Demand_class
                       AND mp.organization_id = submit_rec.organization_id
                       AND mp.organization_code = flv.attribute1 -- Inv_org_code
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       flv.start_date_active,
                                                       SYSDATE)
                                               AND NVL (flv.end_date_active,
                                                        SYSDATE);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           '2.2 Unable to derive Application/OrgCode/Brand'
                        || SQLERRM
                        || SQLCODE);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           '    For DemandClass - '
                        || submit_rec.demand_class
                        || ','
                        || 'OrganizationId - '
                        || submit_rec.organization_id);
            END;

            IF     lv_application IS NOT NULL
               AND lv_org_code IS NOT NULL
               AND lv_brand IS NOT NULL
            THEN
                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        '--------------------------------------------------');
                    -- Initialize the Environment
                    fnd_global.apps_initialize (gn_user_id,
                                                gn_resp_id,
                                                gn_resp_appl_id);

                    l_request_id   :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXD_ATP_REFRESH_SUB_INC_PROG',
                            argument1     => submit_rec.organization_id,
                            argument2     => submit_rec.demand_class,
                            argument3     => lv_application,
                            argument4     => lv_brand);

                    IF l_request_id > 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               '2.2 Sub Program Submitted - '
                            || l_request_id
                            || ', Inv Org - '
                            || lv_org_code
                            || ', Demand Class - '
                            || submit_rec.demand_class
                            || ', Application - '
                            || lv_application);

                        l_req_id (i)   := l_request_id;
                        i              := i + 1;
                        COMMIT;
                    ELSE
                        ROLLBACK;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        x_retcode   := 2;
                        x_errbuf    := x_errbuf || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG,
                                           '2.3 Unexp error ' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        x_retcode   := 2;
                        fnd_file.put_line (fnd_file.LOG,
                                           '2.3 Unexp error ' || SQLERRM);
                END;
            END IF;
        END LOOP;


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
                            INTERVAL     => 60,
                            max_wait     => 60,
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
        fnd_file.put_line (fnd_file.LOG,
                           '2.0 End of call_to_sub_prog Procedure  ...');
        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_stg_dtls_cur%ISOPEN
            THEN
                CLOSE get_stg_dtls_cur;
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                '2.4 Exception in call_to_sub_prog Procedure : ' || SQLERRM);
    END call_to_sub_prog;

    ----------------------------------------------------------------------------------------------------------
    PROCEDURE SUB_PROGRAM (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_inv_org_id IN NUMBER
                           , p_demand_class IN VARCHAR2, p_application IN VARCHAR2, p_brand IN VARCHAR2)
    IS
        v_table_get_inv_details_c   g_table_get_inv_details_c;
        ld_current_run_Date         DATE
            := TO_DATE (FND_PROFILE.VALUE ('XXD_ATP_RUN_DATE'),
                        'DD-MON-YYYY HH24:MI:SS');

        CURSOR get_stg_dtls_sub_cur (cp_demand_class   VARCHAR2,
                                     cp_inv_org_id     NUMBER)
        IS
            SELECT xstg.inventory_item_id
              FROM xxd_atp_stg_t xstg
             WHERE     status_flag = 'L'
                   AND xstg.demand_class = cp_demand_class
                   AND xstg.organization_id = cp_inv_org_id;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');
        fnd_file.put_line (fnd_file.LOG, 'Begin of SubProgram..');
        fnd_file.put_line (fnd_file.LOG,
                           'gdsydate : ' || ld_current_run_Date);

        OPEN get_stg_dtls_sub_cur (p_demand_class, p_inv_org_id);

        LOOP
            FETCH get_stg_dtls_sub_cur
                BULK COLLECT INTO v_table_get_inv_details_c
                LIMIT 1000;

            fnd_file.put_line (
                fnd_file.LOG,
                '--------------------------------------------------');
            fnd_file.put_line (
                fnd_file.LOG,
                   ' v_table_get_inv_details_c.count '
                || v_table_get_inv_details_c.COUNT);

            fnd_file.put_line (fnd_file.LOG, ' Call to Patch Procedure..');

            PATCH (v_table_get_inv_details_c, p_inv_org_id, p_demand_class,
                   p_application, p_brand);

            EXIT WHEN v_table_get_inv_details_c.COUNT = 0;
        END LOOP;

        CLOSE get_stg_dtls_sub_cur;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'In Subprogram Exception ' || SQLERRM || SQLCODE);

            IF get_stg_dtls_sub_cur%ISOPEN
            THEN
                CLOSE get_stg_dtls_sub_cur;
            END IF;
    END SUB_PROGRAM;

    ----------------------------------------------------------------------------------------------------------

    PROCEDURE PATCH (p_table_get_inv_details_c IN g_table_get_inv_details_c, p_inv_org_id IN NUMBER, p_demand_class IN VARCHAR2
                     , p_application IN VARCHAR2, p_brand IN VARCHAR2)
    IS
        v_cutoff_Date         DATE := gd_sysdate;
        save_res              BOOLEAN;
        lc_msg_data           VARCHAR2 (500);
        lc_msg_dummy          VARCHAR2 (1000);
        ln_msg_count          NUMBER;
        l_session_id          NUMBER;
        lc_var                VARCHAR2 (2000);
        ln_cnt                NUMBER := 0;
        l_uom_code            VARCHAR2 (1000);
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
        p_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period          mrp_atp_pub.atp_period_typ;
        x_atp_details         mrp_atp_pub.atp_details_typ;
        x_return_status       VARCHAR2 (100);
        x_error_message       VARCHAR2 (1000);
        x_msg_data            VARCHAR2 (2000);
        x_msg_count           NUMBER;
        ln_list               NUMBER;
        lv_brand              VARCHAR2 (30);
        lv_uom_code           VARCHAR2 (30);
        lv_sku                VARCHAR2 (50);
        ln_processed          NUMBER := 0;
        ln_errored            NUMBER := 0;
        ld_current_run_Date   DATE
            := TO_DATE (FND_PROFILE.VALUE ('XXD_ATP_RUN_DATE'),
                        'DD-Mon-YYYY HH24:MI:SS');
        lt_inv_items_atr      g_table_get_inv_details_c;        -- NRK 04May15
        lt_inv_items_no_atr   g_table_get_inv_details_c;        -- NRK 04May15
        ln_atr_qty            NUMBER := 0;                      -- NRK 04May15
        ln_a_cnt              NUMBER := 0;                      -- NRK 04May15
        ln_na_cnt             NUMBER := 0;                      -- NRK 04May15


        --For HUBSOFT/ECOMM
        CURSOR get_atp_dtl_hsoft_c (cp_session_id NUMBER)
        IS
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
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '..............................');
        fnd_file.put_line (fnd_file.LOG, 'Start of Patch Procedure');
        fnd_file.put_line (fnd_file.LOG, '..............................');
        fnd_file.put_line (fnd_file.LOG,
                           ' p_inv_org_id      : ' || p_inv_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           ' p_demand_class : ' || p_demand_class);
        fnd_file.put_line (fnd_file.LOG,
                           ' p_application  : ' || p_application);
        fnd_file.put_line (fnd_file.LOG, ' p_brand          : ' || p_brand);
        fnd_file.put_line (fnd_file.LOG, '..............................');

        ----------------------------------------------------------------------------------------------------------
        --Start of Changes for ATR NRK  04May15 ..to distinguish inventory items based on ATR availability
        ----------------------------------------------------------------------------------------------------------

        FOR ln_cnt IN 1 .. p_table_get_inv_details_c.COUNT
        LOOP
            BEGIN
                ln_atr_qty   :=
                    NVL (
                        do_inv_utils_pub.item_atr_quantity (
                            p_organization_id   => p_inv_org_id,
                            p_inventory_item_id   =>
                                p_table_get_inv_details_c (ln_cnt).inventory_item_id),
                        0);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_atr_qty   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception while calculating ATR for item : '
                        || p_table_get_inv_details_c (ln_cnt).inventory_item_id); --for Debug
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error : ' || SQLERRM || SQLCODE); --for Debug
            END;

            IF ln_atr_qty > 0
            THEN
                ln_a_cnt   := ln_a_cnt + 1;
                lt_inv_items_atr (ln_a_cnt).inventory_item_id   :=
                    p_table_get_inv_details_c (ln_cnt).inventory_item_id;
            ELSE
                ln_na_cnt   := ln_na_cnt + 1;
                lt_inv_items_no_atr (ln_na_cnt).inventory_item_id   :=
                    p_table_get_inv_details_c (ln_cnt).inventory_item_id;
            END IF;
        END LOOP;

        --For DEBUG
        fnd_file.put_line (
            fnd_file.LOG,
               'p_table_get_inv_details_c.COUNT -  '
            || p_table_get_inv_details_c.COUNT);
        fnd_file.put_line (
            fnd_file.LOG,
            'lt_inv_items_atr.COUNT -  ' || lt_inv_items_atr.COUNT);
        fnd_file.put_line (
            fnd_file.LOG,
            'lt_inv_items_no_atr.COUNT -  ' || lt_inv_items_no_atr.COUNT);

        ----------------------------------------------------------------------
        --End of Changes for ATR NRK  04May15
        ----------------------------------------------------------------------

        SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

        --ln_list := p_table_get_inv_details_c.COUNT;    --NRK04May15
        ln_list   := lt_inv_items_atr.COUNT;                      --NRK04May15

        fnd_file.put_line (fnd_file.LOG, 'Session ID -  ' || l_session_id);
        fnd_file.put_line (fnd_file.LOG, 'ln_list -  ' || ln_list);

        msc_atp_global.extend_atp (l_atp_rec, x_return_status, ln_list);
        msc_atp_global.extend_atp (x_atp_rec, x_return_status, ln_list);

        -- FOR ln_cnt IN 1 .. p_table_get_inv_details_c.COUNT --NRK04May15
        FOR ln_cnt IN 1 .. lt_inv_items_atr.COUNT                 --NRK04May15
        LOOP
            lv_uom_code   := NULL;

            BEGIN
                SELECT primary_uom_code
                  INTO lv_uom_code
                  FROM xxd_common_items_v
                 WHERE     inventory_item_id =
                           -- p_table_get_inv_details_c (ln_cnt).inventory_item_id  -- NRK04May15
                           lt_inv_items_atr (ln_cnt).inventory_item_id -- NRK04May15
                       AND organization_id = p_inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while deriving UOM for Item '
                        --  || p_table_get_inv_details_c (ln_cnt).inventory_item_id    -- NRK04May15
                        || lt_inv_items_atr (ln_cnt).inventory_item_id -- NRK04May15
                        || ' : '
                        || SQLERRM
                        || SQLCODE);
                    lv_uom_code   := 'PR';                       ---Required ?
            END;

            BEGIN
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

                -- l_atp_rec.inventory_item_id (ln_cnt) :=  p_table_get_inv_details_c (ln_cnt).inventory_item_id; -- NRK04May15
                l_atp_rec.inventory_item_id (ln_cnt)          :=
                    lt_inv_items_atr (ln_cnt).inventory_item_id; -- NRK04May15
                l_atp_rec.quantity_uom (ln_cnt)               := lv_uom_code;
                l_atp_rec.requested_ship_date (ln_cnt)        :=
                    ld_current_run_Date;
                l_atp_rec.source_organization_id (ln_cnt)     := p_inv_org_id;
                l_atp_rec.demand_class (ln_cnt)               := p_demand_class;
                l_atp_rec.action (ln_cnt)                     := 100;
                l_atp_rec.OE_Flag (ln_cnt)                    := 'N';
                l_atp_rec.Customer_Id (ln_cnt)                := NULL;
                l_atp_rec.Customer_Site_Id (ln_cnt)           := NULL;
                l_atp_rec.Calling_Module (ln_cnt)             := 660; -- use 724 when calling from MSC_ATP_CALL - otherwise NULL
                l_atp_rec.Row_Id (ln_cnt)                     := NULL;
                l_atp_rec.Source_Organization_Code (ln_cnt)   := NULL;
                l_atp_rec.Organization_Id (ln_cnt)            := p_inv_org_id;
                l_atp_rec.order_number (ln_cnt)               := NULL;
                l_atp_rec.line_number (ln_cnt)                := NULL;
                l_atp_rec.override_flag (ln_cnt)              := 'N';
                l_atp_rec.Identifier (ln_cnt)                 :=
                    XXD_ATP_INC_IDENTIFIER_S.NEXTVAL;
            END;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Before Call to API :'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24 MI SS'));
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
               'After Calling API : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24 MI SS'));

        IF (x_return_status = 'S')
        THEN
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

            IF p_application IN ('HUBSOFT', 'ECOMM')
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Before For Loop. Application : ' || p_application);

                FOR get_atp_dtl_hsoft_rec
                    IN get_atp_dtl_hsoft_c (l_session_id)
                LOOP
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Deriving ATP Details for : '
                        || get_atp_dtl_hsoft_rec.Inventory_Item_Id
                        || ','
                        || get_atp_dtl_hsoft_rec.organization_id);

                    BEGIN
                        lv_sku   := NULL;

                        SELECT item_number
                          INTO lv_sku
                          FROM xxd_common_items_v
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

                    DELETE FROM
                        XXDO.XXD_MASTER_ATP_FULL_T
                          WHERE     inventory_item_id =
                                    get_atp_dtl_hsoft_rec.Inventory_Item_Id
                                AND INV_ORGANIZATION_ID =
                                    get_atp_dtl_hsoft_rec.organization_id
                                AND DEMAND_CLASS_CODE = p_demand_class;

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
                         VALUES (XXD_MASTER_ATP_T_S.NEXTVAL, lv_sku, get_atp_dtl_hsoft_rec.inventory_item_id, get_atp_dtl_hsoft_rec.organization_id, p_demand_class, p_application, p_brand, get_atp_dtl_hsoft_rec.uom_code, ld_current_run_Date, get_atp_dtl_hsoft_rec.qty, get_atp_dtl_hsoft_rec.Period_Start_Date, ld_current_run_Date, gn_user_id, gn_user_id, ld_current_run_Date
                                 , gn_user_id);
                END LOOP;

                ----------------------------------------------------------------------
                --Start of Changes for ATR NRK  04May15 (Adding the records of NO ATR inventory items)
                ----------------------------------------------------------------------
                FOR i IN 1 .. lt_inv_items_no_atr.COUNT
                LOOP
                    BEGIN
                        lv_sku   := NULL;

                        SELECT item_number
                          INTO lv_sku
                          FROM XXD_COMMON_ITEMS_V
                         WHERE     inventory_item_id =
                                   lt_inv_items_no_atr (i).inventory_item_id
                               AND organization_id = p_inv_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error deriving SKU - ' || SQLERRM);
                    END;

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
                         VALUES (XXD_MASTER_ATP_T_S.NEXTVAL, lv_sku, lt_inv_items_no_atr (i).inventory_item_id, p_inv_org_id, p_demand_class, p_application, p_brand, NULL, -- UOMCODE Null?
                                                                                                                                                                            SYSDATE, -- REQUESTED_SHIP_DATE
                                                                                                                                                                                     0, -- Available_Quantity
                                                                                                                                                                                        NULL, -- AVAILABLE_DATE
                                                                                                                                                                                              SYSDATE, gn_user_id, gn_user_id, SYSDATE
                                 , gn_user_id);
                END LOOP;

                ----------------------------------------------------------------------
                --End of Changes for ATR NRK  04May15
                ----------------------------------------------------------------------
                COMMIT;
            ELSE                         --if application not in HUBSOFT/ECOMM
                FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
                LOOP
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Deriving ATP Details for : '
                        || x_atp_rec.Inventory_Item_Id (i)
                        || ','
                        || x_atp_rec.source_organization_id (i)
                        || ','
                        || x_atp_rec.demand_class (i));

                    IF item_exists (x_atp_rec.Inventory_Item_Id (i),
                                    x_atp_rec.source_organization_id (i),
                                    x_atp_rec.demand_class (i)) =
                       'N'
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Item doesnot Exists ');

                        BEGIN
                            lv_brand   := NULL;
                            lv_sku     := NULL;

                            SELECT xci.brand, xci.item_number
                              INTO lv_brand, lv_sku
                              FROM xxd_common_items_v xci
                             WHERE     xci.inventory_item_id =
                                       x_atp_rec.Inventory_Item_Id (i)
                                   AND xci.organization_id =
                                       x_atp_rec.source_organization_id (i);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Exception while deriving Brand/SKU'
                                    || SQLERRM
                                    || SQLCODE);
                        END;

                        fnd_file.put_line (fnd_file.LOG, 'Before Insert');

                        INSERT INTO XXD_MASTER_ATP_FULL_T (SLNO, SKU, INVENTORY_ITEM_ID, INV_ORGANIZATION_ID, DEMAND_CLASS_CODE, APPLICATION, BRAND, UOM_CODE, REQUESTED_SHIP_DATE, AVAILABLE_QUANTITY, AVAILABLE_DATE, CREATION_DATE, CREATED_BY, LAST_UPDATE_LOGIN, LAST_UPDATE_DATE
                                                           , LAST_UPDATED_BY)
                             VALUES (XXD_MASTER_ATP_T_S.NEXTVAL, --xxd_master_atp_incr_s.NEXTVAL,
                                                                 lv_sku, x_atp_rec.Inventory_Item_Id (i), x_atp_rec.source_organization_id (i), x_atp_rec.demand_class (i), p_application, lv_brand, x_atp_rec.quantity_uom (i), x_atp_rec.requested_ship_date (i), x_atp_rec.available_quantity (i), x_atp_rec.arrival_date (i), SYSDATE, gn_user_id, gn_user_id, SYSDATE
                                     , gn_user_id);

                        fnd_file.put_line (fnd_file.LOG, 'After Insert');
                    ELSE
                        fnd_file.put_line (fnd_file.LOG, 'Before Update');

                        UPDATE XXD_MASTER_ATP_FULL_T
                           SET AVAILABLE_QUANTITY = x_atp_rec.available_quantity (i), AVAILABLE_DATE = x_atp_rec.arrival_date (i)
                         WHERE     INVENTORY_ITEM_ID =
                                   x_atp_rec.Inventory_Item_Id (i)
                               AND INV_ORGANIZATION_ID =
                                   x_atp_rec.source_organization_id (i)
                               AND DEMAND_CLASS_CODE =
                                   x_atp_rec.demand_class (i)
                               AND LAST_UPDATE_DATE = SYSDATE
                               AND LAST_UPDATED_BY = gn_user_id;
                    END IF;

                    fnd_file.put_line (fnd_file.LOG, 'After Update');
                END LOOP;

                ----------------------------------------------------------------------
                --Start of Changes for ATR NRK  04May15 (Adding the records of NO ATR inventory items)
                ----------------------------------------------------------------------
                FOR i IN 1 .. lt_inv_items_no_atr.COUNT
                LOOP
                    BEGIN
                        lv_sku   := NULL;

                        SELECT item_number
                          INTO lv_sku
                          FROM XXD_COMMON_ITEMS_V
                         WHERE     inventory_item_id =
                                   lt_inv_items_no_atr (i).inventory_item_id
                               AND organization_id = p_inv_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error deriving SKU - ' || SQLERRM);
                    END;

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
                         VALUES (XXD_MASTER_ATP_T_S.NEXTVAL, lv_sku, lt_inv_items_no_atr (i).inventory_item_id, p_inv_org_id, p_demand_class, p_application, p_brand, NULL, -- UOMCODE Null?
                                                                                                                                                                            SYSDATE, -- REQUESTED_SHIP_DATE
                                                                                                                                                                                     0, -- Available_Quantity
                                                                                                                                                                                        NULL, -- AVAILABLE_DATE
                                                                                                                                                                                              SYSDATE, gn_user_id, gn_user_id, SYSDATE
                                 , gn_user_id);
                END LOOP;

                ----------------------------------------------------------------------
                --End of Changes for ATR NRK  04May15
                ----------------------------------------------------------------------
                COMMIT;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Records Processed Successfully.....');

            BEGIN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'gd_sysdate before Updating Processed Records.....'
                    || TO_CHAR (ld_current_run_Date,
                                'DD-MON-YYYY HH24:MI:SS'));

                SELECT COUNT (*)
                  INTO ln_processed
                  FROM XXDO.XXD_ATP_STG_T
                 WHERE TO_CHAR (last_update_date, 'DD-MON-YYYY  HH24:MI:SS') =
                       TO_CHAR (ld_current_run_Date,
                                'DD-MON-YYYY  HH24:MI:SS');

                fnd_file.put_line (
                    fnd_file.LOG,
                    'No. of Processed Records.....' || ln_processed);


                UPDATE XXDO.XXD_ATP_STG_T
                   SET status_flag   = 'P'    -- Mark the records as Processed
                 WHERE TO_CHAR (last_update_date, 'DD-MON-YYYY  HH24:MI:SS') =
                       TO_CHAR (ld_current_run_Date,
                                'DD-MON-YYYY  HH24:MI:SS');

                fnd_file.put_line (
                    fnd_file.LOG,
                       'gd_sysdate after Updating Processed Records.....'
                    || TO_CHAR (ld_current_run_Date,
                                'DD-MON-YYYY  HH24:MI:SS'));
                COMMIT;
            END;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Unable to Process records, Error Occurred.....');
            fnd_file.put_line (
                fnd_file.LOG,
                   'gd_sysdate before Updating Errored Records.....'
                || TO_CHAR (ld_current_run_Date, 'DD-MON-YYYY  HH24:MI:SS'));

            fnd_file.put_line (fnd_file.LOG, 'x_msg_data=' || x_msg_data);

            SELECT COUNT (*)
              INTO ln_errored
              FROM XXDO.XXD_ATP_STG_T
             WHERE TO_CHAR (last_update_date, 'DD-MON-YYYY  HH24:MI:SS') =
                   TO_CHAR (ld_current_run_Date, 'DD-MON-YYYY  HH24:MI:SS');

            fnd_file.put_line (fnd_file.LOG,
                               'No. of Errored Records.....' || ln_errored);

            UPDATE XXD_ATP_STG_T
               SET status_flag   = 'E'            -- Mark the records as Error
             WHERE TO_CHAR (last_update_date, 'DD-MON-YYYY  HH24:MI:SS') =
                   TO_CHAR (ld_current_run_Date, 'DD-MON-YYYY  HH24:MI:SS');

            fnd_file.put_line (
                fnd_file.LOG,
                   'gd_sysdate after Updating Errored Records.....'
                || TO_CHAR (ld_current_run_Date, 'DD-MON-YYYY  HH24:MI:SS'));

            COMMIT;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'time after all loop '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY  HH24:MI:SS'));

        fnd_file.put_line (fnd_file.LOG,
                           'Setting Profile XXD_ATP_REFRESH_DATE :');
        save_res   :=
            FND_PROFILE.SAVE ('XXD_ATP_REFRESH_DATE', TO_CHAR (ld_current_run_Date, 'DD-MON-YYYY HH24:MI:SS'), 'SITE'
                              , NULL, NULL);

        fnd_file.put_line (
            fnd_file.LOG,
               'Saved Refresh Cutoff Date to Profile :'
            || TO_CHAR (ld_current_run_Date, 'DD-MON-YYYY HH24:MI:SS'));

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'EXCEPTION :' || SQLERRM);

            UPDATE XXD_ATP_STG_T
               SET status_flag   = 'E'            -- Mark the records as Error
             WHERE TO_CHAR (last_update_date, 'DD-MON-YYYY  HH24:MI:SS') =
                   TO_CHAR (ld_current_run_Date, 'DD-MON-YYYY  HH24:MI:SS');


            COMMIT;
    END PATCH;

    ----------------------------------------------------------------------------------------------------------
    FUNCTION item_exists (p_inventory_item_id NUMBER, p_organization_id NUMBER, p_demand_class VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM XXD_MASTER_ATP_FULL_T
         WHERE     inventory_item_id = p_inventory_item_id
               AND INV_ORGANIZATION_ID = p_organization_id
               AND DEMAND_CLASS_CODE = p_demand_class;

        IF ln_count = 0
        THEN
            RETURN 'N';
        ELSE
            RETURN 'Y';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'EXCEPTION in item_exists function :' || SQLERRM);
            RETURN 'N';
    END item_exists;
----------------------------------------------------------------------------------------------------------

END XXD_ATP_INC_REFRESH_PKG;
/
