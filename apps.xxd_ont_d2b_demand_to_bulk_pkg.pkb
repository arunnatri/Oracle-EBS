--
-- XXD_ONT_D2B_DEMAND_TO_BULK_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_D2B_DEMAND_TO_BULK_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_D2B_DEMAND_TO_BULK_PKG
    -- Design       : This package will be used for the DTC Demand to Bulk Order Automation.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name               Ver    Description
    -- ----------      --------------    -----  ------------------
    -- 30-Aug-2022     Jayarajan A K      1.0    Initial Version (CCR0010104)
    -- 17-Jan-2023     Jayarajan A K      1.1    Updated New Order Batching logic
    -- 24-Jan-2023     Jayarajan A K      1.2    Used lookup to derive start and end dates for YYYY-MM periods
    -- 20-Feb-2023     Jayarajan A K      1.3    Updated cust_po_number to display fcst_month instead of request_date month
    -- #########################################################################################################################
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gn_user_id             NUMBER := NVL (fnd_global.user_id, -1);
    gn_login_id            NUMBER := NVL (fnd_global.login_id, -1);
    gl_table_owner         VARCHAR2 (10) := 'XXDO';
    gl_package_name        VARCHAR2 (50) := 'xxd_ont_d2b_demand_to_bulk_pkg';
    gl_ascp_db_link_name   VARCHAR2 (50) := 'BT_EBS_TO_ASCP';
    gn_dop                 NUMBER := 6;
    gv_debug               VARCHAR2 (1);

    --  insert_message procedure
    PROCEDURE insrt_msg (pv_message_type   IN VARCHAR2,
                         pv_message        IN VARCHAR2,
                         pv_debug          IN VARCHAR2 := 'N')
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH') AND pv_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_message);
        END IF;

        IF UPPER (pv_message_type) IN ('OUTPUT', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, pv_message);
        END IF;

        IF UPPER (pv_message_type) = 'DATABASE'
        THEN
            DBMS_OUTPUT.put_line (pv_message);
        END IF;
    END insrt_msg;

    --Start changes v1.2
    FUNCTION get_prd_strt_dt (p_yyyy_mm IN VARCHAR2)
        RETURN DATE
    IS
        ld_start_date   DATE;
    BEGIN
        SELECT TO_DATE (meaning, 'DD-MON-RRRR')
          INTO ld_start_date
          FROM fnd_lookup_values flv
         WHERE     lookup_type = 'XXD_MSC_PERIOD_DATES'
               AND lookup_code = p_yyyy_mm
               AND flv.language = USERENV ('LANG')
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                SYSDATE)
                                       AND NVL (flv.end_date_active, SYSDATE)
               AND flv.enabled_flag = 'Y';

        RETURN ld_start_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            ld_start_date   := TO_DATE (p_yyyy_mm, 'YYYY-MM');
            RETURN ld_start_date;
    END get_prd_strt_dt;

    --End changes v1.2

    PROCEDURE generate_output (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2, x_batch_name IN VARCHAR2)
    AS
        lv_line             VARCHAR2 (1000);
        lv_file_delimiter   VARCHAR2 (1) := CHR (9);

        CURSOR output_cur IS
              SELECT fcst_region, channel, brand,
                     fcst_month, SUM (final_fcst) fcst_qty, SUM (bulk_qty) bulk_qty
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE xdfs.batch_name = x_batch_name
            GROUP BY fcst_region, channel, brand,
                     fcst_month
            ORDER BY fcst_region, channel, brand,
                     fcst_month;
    BEGIN
        insrt_msg ('LOG', 'Inside generate_output Procedure', 'Y');

        lv_line   :=
               'Forecast Region'
            || lv_file_delimiter
            || 'Channel'
            || lv_file_delimiter
            || 'Brand'
            || lv_file_delimiter
            || 'Forecast Month'
            || lv_file_delimiter
            || 'Total Forecast'
            || lv_file_delimiter
            || 'Total Bulk'
            || lv_file_delimiter;

        insrt_msg ('OUTPUT', lv_line);

        FOR output_rec IN output_cur
        LOOP
            lv_line   :=
                   output_rec.fcst_region
                || lv_file_delimiter
                || output_rec.channel
                || lv_file_delimiter
                || output_rec.brand
                || lv_file_delimiter
                || output_rec.fcst_month
                || lv_file_delimiter
                || output_rec.fcst_qty
                || lv_file_delimiter
                || output_rec.bulk_qty
                || lv_file_delimiter;

            insrt_msg ('OUTPUT', lv_line);
        END LOOP;

        insrt_msg ('LOG', 'Completed generate_output Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            insrt_msg ('LOG',
                       'Error while generating output: ' || SQLERRM,
                       'Y');
    END generate_output;

    PROCEDURE val_fcst_file (retcode          OUT VARCHAR2,
                             errbuff          OUT VARCHAR2,
                             p_file_name   IN     VARCHAR2)
    AS
        l_tablename     VARCHAR2 (240) := 'XXD_ONT_D2B_DMND_FCST_FILE_T';
        ld_fcst_dt      DATE;
        ln_fcst_qty     NUMBER;
        lv_org_code     VARCHAR2 (10);
        ln_org_id       NUMBER;
        ln_inv_itm_id   NUMBER;
        lv_err_msg      VARCHAR2 (4000);
        lv_status       VARCHAR2 (1);

        CURSOR fcst_data_cur IS
            SELECT *
              FROM soa_int.xxd_ont_d2b_dmnd_fcst_file_t xdff
             WHERE xdff.file_name = p_file_name;

        TYPE fcst_data_tb IS TABLE OF fcst_data_cur%ROWTYPE;

        vt_fcst_data    fcst_data_tb;
        v_fcst_limit    NUMBER := 10000;
    BEGIN
        insrt_msg ('LOG', 'Inside val_fcst_file', 'Y');

        DBMS_STATS.gather_table_Stats (ownname => 'soa_int', tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gn_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE table_name = l_tablename AND table_owner = 'soa_int')
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;

        /*
        OPEN fcst_data_cur;

     LOOP
    FETCH fcst_data_cur BULK COLLECT INTO vt_fcst_data LIMIT v_fcst_limit;
    BEGIN
     FORALL i IN 1 .. vt_fcst_data.COUNT
     --update
    EXCEPTION
     WHEN OTHERS
     THEN
      insrt_msg('LOG', 'Error during insertion: '|| SQLERRM, 'Y');
    END;

    COMMIT;
    EXIT WHEN fcst_data_cur%NOTFOUND;
   END LOOP;

   CLOSE fcst_data_cur
   */

        FOR fcst_rec IN fcst_data_cur
        LOOP
            lv_status       := 'X';
            lv_err_msg      := NULL;
            ln_inv_itm_id   := NULL;
            ln_org_id       := NULL;
            lv_org_code     := NULL;

            --fcst_date format check
            BEGIN
                SELECT TO_DATE (fcst_rec.fcst_month, 'YYYY-MM')
                  INTO ld_fcst_dt
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        'Invalid Format for FCST_DATE. The format should be YYYY-MM';
                    lv_status   := 'E';
            END;

            --FINAL_FCST number check
            IF lv_status = 'X'
            THEN
                BEGIN
                    SELECT TO_NUMBER (fcst_rec.final_fcst)
                      INTO ln_fcst_qty
                      FROM DUAL
                     WHERE TO_NUMBER (fcst_rec.final_fcst) >= 0;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_err_msg   := 'Invalid Number for FINAL_FCST';
                        lv_status    := 'E';
                END;
            END IF;

            --lv_org_code check
            IF lv_status = 'X'
            THEN
                BEGIN
                    SELECT attribute4
                      INTO lv_org_code
                      FROM fnd_lookup_values flv
                     WHERE     lookup_type = 'XXDO_D2B_FORECAST_BULK_MAPPING'
                           AND attribute1 = fcst_rec.fcst_region
                           AND attribute2 = fcst_rec.channel
                           AND attribute3 = fcst_rec.brand
                           AND attribute7 = '1'
                           AND flv.language = USERENV ('LANG')
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           SYSDATE)
                           AND flv.enabled_flag = 'Y';

                    SELECT organization_id
                      INTO ln_org_id
                      FROM mtl_parameters
                     WHERE organization_code = lv_org_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_err_msg   :=
                            'Inv Org Code not set-up for the brand-channel-fcst_region combination';
                        lv_status   := 'E';
                END;
            END IF;


            IF lv_status = 'X' AND ln_org_id IS NOT NULL
            THEN
                BEGIN
                    SELECT inventory_item_id
                      INTO ln_inv_itm_id
                      FROM mtl_system_items_b msib
                     WHERE     msib.organization_id = ln_org_id
                           AND msib.segment1 = fcst_rec.sku
                           AND enabled_flag = 'Y'
                           AND inventory_item_status_code <> 'Inactive';
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        BEGIN
                            SELECT inventory_item_id
                              INTO ln_inv_itm_id
                              FROM mtl_system_items_b msib
                             WHERE msib.segment1 = fcst_rec.sku;

                            lv_err_msg   := 'Inactive Item';
                            lv_status    := 'E';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_err_msg   := 'Item Not Found';
                                lv_status    := 'E';
                        END;
                    WHEN OTHERS
                    THEN
                        lv_err_msg   := 'Item Not Found';
                        lv_status    := 'E';
                END;
            END IF;

            IF lv_status = 'X'
            THEN
                lv_status   := 'S';
            END IF;

            UPDATE soa_int.xxd_ont_d2b_dmnd_fcst_file_t xdff
               SET inventory_item_id = ln_inv_itm_id, organization_id = ln_org_id, inv_org_code = lv_org_code,
                   status = lv_status, error_message = lv_err_msg, last_updated_by = gn_user_id,
                   last_update_date = SYSDATE
             WHERE     record_id = fcst_rec.record_id
                   AND file_name = fcst_rec.file_name;
        END LOOP;

        COMMIT;
        retcode   := g_ret_success;
        errbuff   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := g_ret_unexp;
            errbuff   := SUBSTR (SQLERRM, 1, 2000);
            ROLLBACK;
    END val_fcst_file;

    PROCEDURE archive_stg_tabs (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2, x_region IN VARCHAR2
                                , x_brand IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name             VARCHAR2 (100)
                               := gl_package_name || '.' || 'archive_dmnd_stg';
        l_tablename        VARCHAR2 (240) := 'XXD_ONT_D2B_DMND_FCST_STG_T';
        ln_hst_retn_days   NUMBER := 90;
        ln_stg_retn_days   NUMBER := 40;
    BEGIN
        insrt_msg ('LOG', 'Start archive_dmnd_stg', 'Y');

        BEGIN
            SELECT TO_NUMBER (tag)
              INTO ln_stg_retn_days
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXDO_D2B_FCST_BK_RPT_UTILITIES'
                   AND flv.meaning = 'Stage Days'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE);

            SELECT TO_NUMBER (tag)
              INTO ln_hst_retn_days
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXDO_D2B_FCST_BK_RPT_UTILITIES'
                   AND flv.meaning = 'Archive Days'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE);

            insrt_msg (
                'LOG',
                   'Before FCST Archive Delete: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
                gv_debug);

            DELETE FROM xxdo.xxd_ont_d2b_dmnd_fcst_hist_t
                  WHERE creation_date < SYSDATE - ln_hst_retn_days;

            insrt_msg ('LOG',
                       'Deleted from FCST Archive table: ' || SQL%ROWCOUNT,
                       'Y');

            insrt_msg (
                'LOG',
                   'Before FCST Archive Insert: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
                gv_debug);

            INSERT INTO xxdo.xxd_ont_d2b_dmnd_fcst_hist_t
                SELECT *
                  FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t
                 WHERE creation_date < SYSDATE - ln_stg_retn_days;

            insrt_msg ('LOG',
                       'Inserted into FCST Archive table: ' || SQL%ROWCOUNT,
                       'Y');

            insrt_msg (
                'LOG',
                   'Before FCST Staging Delete: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
                gv_debug);

            DELETE FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t
                  WHERE creation_date < SYSDATE - ln_stg_retn_days;

            insrt_msg ('LOG',
                       'Deleted from FCST Staging table: ' || SQL%ROWCOUNT,
                       'Y');
        EXCEPTION
            WHEN OTHERS
            THEN
                insrt_msg (
                    'LOG',
                    'Error While Archiving FCST Staging Table: ' || SQLERRM,
                    'Y');
        END;

        COMMIT;

        BEGIN
            insrt_msg (
                'LOG',
                   'Before Bulk Archive Delete: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
                gv_debug);

            DELETE FROM xxdo.xxd_ont_d2b_bulk_ordr_hist_t
                  WHERE creation_date < SYSDATE - ln_hst_retn_days;

            insrt_msg ('LOG',
                       'Deleted from Bulk Archive table: ' || SQL%ROWCOUNT,
                       'Y');

            insrt_msg (
                'LOG',
                   'Before Bulk Archive Insert: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
                gv_debug);

            INSERT INTO xxdo.xxd_ont_d2b_bulk_ordr_hist_t
                SELECT *
                  FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t
                 WHERE creation_date < SYSDATE - ln_stg_retn_days;

            insrt_msg ('LOG',
                       'Inserted into Bulk Archive table: ' || SQL%ROWCOUNT,
                       'Y');

            insrt_msg (
                'LOG',
                   'Before Bulk Staging Delete: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
                gv_debug);

            DELETE FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t
                  WHERE creation_date < SYSDATE - ln_stg_retn_days;

            insrt_msg ('LOG',
                       'Deleted from Bulk Staging table: ' || SQL%ROWCOUNT,
                       'Y');
        EXCEPTION
            WHEN OTHERS
            THEN
                insrt_msg (
                    'LOG',
                    'Error While Archiving Bulk Staging Table: ' || SQLERRM,
                    'Y');
        END;

        COMMIT;

        insrt_msg ('LOG', 'End archive_stg_tabs: ' || x_ret_stat, 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_unexp;
            x_msg        := SUBSTR (SQLERRM, 1, 2000);
            ROLLBACK;
            insrt_msg ('LOG', 'Error in archive_stg_tabs: ' || SQLERRM, 'Y');
    END archive_stg_tabs;

    PROCEDURE collect_dmnd_fcst (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2, x_region IN VARCHAR2, x_fcst_rgn IN VARCHAR2, x_channel IN VARCHAR2, x_brand IN VARCHAR2
                                 , x_batch_name IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name        VARCHAR2 (100)
                          := gl_package_name || '.' || 'collect_dmnd_fcst';
        l_tablename   VARCHAR2 (240) := 'XXD_ONT_D2B_DMND_FCST_STG_T';
        l_sql_stmnt   LONG;
    BEGIN
        insrt_msg (
            'LOG',
               'Starting collect_dmnd_fcst: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');
        l_sql_stmnt   :=
               '
                    INSERT /*+ APPEND PARALLEL('
            || gn_dop
            || ') */
                           INTO '
            || gl_table_owner
            || '.'
            || l_tablename
            || ' (
							  record_id
							, file_name
							, ascp_inv_item_id
							, ebs_inv_item_id
							, sku
							, brand
							, region
							, batch_name
							, request_id
							, division
							, department  
							, channel
							, fcst_region
							, fcst_month
							, final_fcst
							, status
							, forecast_start_date
							, forecast_end_date
							, uom_code
							, list_price
							, organization_id
							, inv_org_code
							, creation_date
							, created_by
							, last_update_date
							, last_updated_by
							, last_update_login
						    )
                         ( 
                           SELECT /*+PARALLEL('
            || gn_dop
            || ')*/
                                  xafs.record_id 
                                , xafs.file_name
                                , xafs.inventory_item_id
                                , xafs.sr_inventory_item_id
                                , xafs.sku
                                , xafs.brand
                                , '''
            || x_region
            || ''' 
                                , '''
            || x_batch_name
            || '''
                                , '
            || gn_request_id
            || ' 
                                , xafs.division
                                , xafs.department
                                , xafs.channel
                                , xafs.fcst_region
                                , xafs.fcst_month
                                , ROUND(xafs.final_fcst)
                                , ''N''
                                , xafs.forecast_start_date
                                , xafs.forecast_end_date
                                , xafs.uom_code
                                , xafs.list_price
                                , xafs.organization_id
                                , xafs.inv_org_code
								, SYSDATE            
                                , '
            || gn_user_id
            || ' 
								, SYSDATE
                                , '
            || gn_user_id
            || '
                                , '
            || gn_login_id
            || ' 
                             FROM '
            || gl_table_owner
            || '.xxd_msc_adv_ascp_fcst_stg_t@'
            || gl_ascp_db_link_name
            || ' xafs						
					  WHERE 1=1
						AND xafs.fcst_region = NVL('''
            || x_fcst_rgn
            || ''', xafs.fcst_region) 
						AND xafs.channel = NVL('''
            || x_channel
            || ''', xafs.channel) 
					    AND xafs.status = ''S''
						AND xafs.brand = NVL('''
            || x_brand
            || ''', xafs.brand) 
						AND sr_inventory_item_id IS NOT NULL  
						AND EXISTS (
									SELECT 1 
									  FROM fnd_lookup_values flv	
									 WHERE 1=1
									   AND flv.lookup_type = ''XXDO_D2B_FORECAST_BULK_MAPPING'' 
									   AND xafs.fcst_region = flv.attribute1
									   AND xafs.channel = flv.attribute2
									   AND xafs.brand = NVL(flv.attribute3, xafs.brand)
									   AND flv.tag = '''
            || x_region
            || '''
									   AND flv.language = USERENV (''LANG'')  
									   AND flv.enabled_flag = ''Y'' 
									   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active, SYSDATE)
						 						               AND NVL (flv.end_date_active, SYSDATE)
									)
                         )
                    ';

        -- insrt_msg ('LOG', 'l_sql_stmnt: '|| l_sql_stmnt, gv_debug);

        EXECUTE IMMEDIATE l_sql_stmnt;

        insrt_msg (
            'LOG',
            'Records inserted into FCST Staging table: ' || SQL%ROWCOUNT,
            'Y');

        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gn_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;
        insrt_msg ('LOG', 'End collect_dmnd_fcst: ' || x_ret_stat, 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_unexp;
            x_msg        := SQLERRM;
            ROLLBACK;
            insrt_msg ('LOG', 'Error in collect_dmnd_fcst: ' || x_msg, 'Y');
    END collect_dmnd_fcst;

    PROCEDURE pull_dmnd_fcst_data (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2, x_region IN VARCHAR2, x_fcst_rgn IN VARCHAR2, x_channel IN VARCHAR2, x_brand IN VARCHAR2
                                   , x_batch_name IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name        VARCHAR2 (100)
                          := gl_package_name || '.' || 'pull_dmnd_fcst_data';
        l_tablename   VARCHAR2 (240) := 'XXD_ONT_D2B_DMND_FCST_STG_T';
        l_sql_stmnt   LONG;
    BEGIN
        insrt_msg (
            'LOG',
               'Starting pull_dmnd_fcst_data: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');
        l_sql_stmnt   :=
               '
                    INSERT /*+ APPEND PARALLEL('
            || gn_dop
            || ') */
                           INTO '
            || gl_table_owner
            || '.'
            || l_tablename
            || ' (
							  record_id
							, file_name
							, ebs_inv_item_id
							, sku
							, brand
							, region
							, batch_name
							, request_id
							, division
							, department 
							, channel
							, fcst_region
							, fcst_month
							, final_fcst
							, status
							, forecast_start_date
							, forecast_end_date
							, uom_code
							, list_price
							, organization_id
							, inv_org_code
							, creation_date
							, created_by
							, last_update_date
							, last_updated_by
							, last_update_login
						    )
                         ( 
                           SELECT /*+PARALLEL('
            || gn_dop
            || ')*/
                                  xdff.record_id 
                                , xdff.file_name
                                , xdff.inventory_item_id
                                , xdff.sku
                                , xdff.brand
                                , '''
            || x_region
            || ''' 
                                , '''
            || x_batch_name
            || '''
                                , '
            || gn_request_id
            || ' 
                                , xdff.division
                                , xdff.department
                                , xdff.channel
                                , xdff.fcst_region
                                , xdff.fcst_month
                                , ROUND(xdff.final_fcst)
                                , ''N''
                                , xdff.forecast_start_date
                                , xdff.forecast_end_date
                                , xdff.uom_code
                                , xdff.list_price
                                , xdff.organization_id
                                , xdff.inv_org_code
								, SYSDATE            
                                , '
            || gn_user_id
            || ' 
								, SYSDATE
                                , '
            || gn_user_id
            || '
                                , '
            || gn_login_id
            || ' 
                             FROM '
            || 'soa_int.xxd_ont_d2b_dmnd_fcst_file_t xdff						
					  WHERE 1=1
						AND xdff.fcst_region = NVL('''
            || x_fcst_rgn
            || ''', xdff.fcst_region) 
						AND xdff.channel = NVL('''
            || x_channel
            || ''', xdff.channel) 
					    AND xdff.status = ''S''
						AND xdff.brand = NVL('''
            || x_brand
            || ''', xdff.brand) 
						AND inventory_item_id IS NOT NULL  
						AND EXISTS (
									SELECT 1 
									  FROM fnd_lookup_values flv	
									 WHERE 1=1
									   AND flv.lookup_type = ''XXDO_D2B_FORECAST_BULK_MAPPING'' 
									   AND xdff.fcst_region = flv.attribute1
									   AND xdff.channel = flv.attribute2
									   AND xdff.brand = NVL(flv.attribute3, xdff.brand)
									   AND flv.tag = '''
            || x_region
            || '''
									   AND flv.language = USERENV (''LANG'')  
									   AND flv.enabled_flag = ''Y'' 
									   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active, SYSDATE)
						 						               AND NVL (flv.end_date_active, SYSDATE)
									)
                         )
                    ';

        -- insrt_msg ('LOG', 'l_sql_stmnt: '|| l_sql_stmnt, gv_debug);

        EXECUTE IMMEDIATE l_sql_stmnt;

        insrt_msg (
            'LOG',
            'Records inserted into FCST Staging table: ' || SQL%ROWCOUNT,
            'Y');

        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gn_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;
        insrt_msg ('LOG', 'End pull_dmnd_fcst_data: ' || x_ret_stat, 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_unexp;
            x_msg        := SQLERRM;
            ROLLBACK;
            insrt_msg ('LOG', 'Error in pull_dmnd_fcst_data: ' || x_msg, 'Y');
    END pull_dmnd_fcst_data;

    PROCEDURE pull_blk_ordr_data (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2, x_region IN VARCHAR2, x_fcst_rgn IN VARCHAR2, x_channel IN VARCHAR2, x_brand IN VARCHAR2
                                  , x_batch_name IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name            VARCHAR2 (100)
                              := gl_package_name || '.' || 'pull_blk_ordr_data';
        l_tablename       VARCHAR2 (240) := 'XXD_ONT_D2B_BULK_ORDR_STG_T';
        ld_max_frcst_dt   DATE;
        ld_min_frcst_dt   DATE;
        --Start changes v1.2
        ld_max_rqst_mm    VARCHAR2 (10);
        ld_min_rqst_mm    VARCHAR2 (10);

        --End changes v1.2

        CURSOR bulk_line_cur (p_req_date_from DATE, p_req_date_to DATE)
        IS
            SELECT ott.name, ooha.org_id, ooha.attribute5 brand,
                   ooha.order_type_id, ooha.creation_date hdr_creation_date, ooha.order_number,
                   ooha.sold_to_org_id, oola.ship_from_org_id, oola.ordered_item sku,
                   oola.inventory_item_id, oola.demand_class_code, oola.order_quantity_uom,
                   oola.header_id, oola.line_id, oola.schedule_ship_date,
                   oola.request_date, oola.creation_date lne_creation_date, oola.order_source_id,
                   oola.ordered_quantity, oola.latest_acceptable_date, oola.line_number || '.' || oola.shipment_number line_number,
                   TO_CHAR (oola.request_date, 'YYYY-MM') rqst_mm, flv.attribute1 fcst_region, flv.attribute2 channel
              FROM oe_order_lines_all oola, mtl_parameters mp, hz_cust_accounts hca,
                   oe_order_headers_all ooha, oe_transaction_types_tl ott, fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXDO_D2B_FORECAST_BULK_MAPPING'
                   AND flv.tag = x_region
                   AND flv.attribute1 = NVL (x_fcst_rgn, flv.attribute1)
                   AND flv.attribute2 = NVL (x_channel, flv.attribute2)
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE)
                   AND ott.name = flv.attribute5
                   AND ott.language = USERENV ('LANG')
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND ooha.attribute5 =
                       NVL (flv.attribute3, ooha.attribute5)           --brand
                   AND ooha.attribute5 = NVL (x_brand, ooha.attribute5)
                   AND ooha.open_flag = 'Y'
                   AND ooha.booked_flag = 'Y'
                   AND hca.cust_account_id = ooha.sold_to_org_id
                   AND hca.account_number =
                       NVL (flv.attribute6, hca.account_number)
                   AND ooha.header_id = oola.header_id
                   AND mp.organization_code = flv.attribute4
                   AND oola.ship_from_org_id = mp.organization_id
                   AND oola.open_flag = 'Y'
                   AND oola.ordered_quantity > 0
                   AND oola.request_date >= p_req_date_from
                   AND oola.request_date < p_req_date_to
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = oola.line_id);

        TYPE bulk_line_tb IS TABLE OF bulk_line_cur%ROWTYPE;

        vt_bulk_line      bulk_line_tb;
        v_bulk_limit      NUMBER := 10000;
        ln_bulk_cnt       NUMBER := 0;
    BEGIN
        insrt_msg (
            'LOG',
               'Starting pull_blk_ordr_data: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');

        BEGIN
            --Start changes v1.2
            /*
      SELECT MAX(ADD_MONTHS(TO_DATE(fcst_month, 'yyyy-mm'),1)),
             MIN(TO_DATE(fcst_month, 'yyyy-mm'))
        INTO ld_max_frcst_dt,
             ld_min_frcst_dt
        FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t
       WHERE batch_name = x_batch_name;
       */

            SELECT MAX (fcst_month), MIN (fcst_month)
              INTO ld_max_rqst_mm, ld_min_rqst_mm
              FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t
             WHERE batch_name = x_batch_name;

            SELECT TO_DATE (description, 'DD-MON-RRRR') + 1
              INTO ld_max_frcst_dt
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_MSC_PERIOD_DATES'
                   AND lookup_code = ld_max_rqst_mm
                   AND flv.language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE)
                   AND flv.enabled_flag = 'Y';

            ld_min_frcst_dt   := get_prd_strt_dt (ld_min_rqst_mm);
            --End changes v1.2

            insrt_msg ('LOG',
                       'p_req_date_from: ' || ld_min_frcst_dt,
                       gv_debug);
            insrt_msg ('LOG', 'p_req_date_to: ' || ld_max_frcst_dt, gv_debug);
        EXCEPTION
            WHEN OTHERS
            THEN
                insrt_msg (
                    'LOG',
                    'Error while fetching ld_max_frcst_dt: ' || SQLERRM,
                    'Y');
        END;

        ---CURSOR
        OPEN bulk_line_cur (ld_min_frcst_dt, ld_max_frcst_dt);

        LOOP
            FETCH bulk_line_cur
                BULK COLLECT INTO vt_bulk_line
                LIMIT v_bulk_limit;

            BEGIN
                FORALL i IN 1 .. vt_bulk_line.COUNT
                    INSERT INTO xxdo.xxd_ont_d2b_bulk_ordr_stg_t (
                                    header_id,
                                    line_id,
                                    request_id,
                                    batch_name,
                                    order_number,
                                    org_id,
                                    ship_from_org_id,
                                    brand,
                                    order_type_id,
                                    sold_to_org_id,
                                    sku,
                                    inventory_item_id,
                                    channel,
                                    fcst_region,
                                    rqst_mm,
                                    original_quantity,
                                    request_date,
                                    hdr_creation_date,
                                    lne_creation_date,
                                    latest_acceptable_date,
                                    schedule_ship_date,
                                    line_number,
                                    process_mode,
                                    status,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                         VALUES (vt_bulk_line (i).header_id, vt_bulk_line (i).line_id, gn_request_id, x_batch_name, vt_bulk_line (i).order_number, vt_bulk_line (i).org_id, vt_bulk_line (i).ship_from_org_id, vt_bulk_line (i).brand, vt_bulk_line (i).order_type_id, vt_bulk_line (i).sold_to_org_id, vt_bulk_line (i).sku, vt_bulk_line (i).inventory_item_id, vt_bulk_line (i).channel, vt_bulk_line (i).fcst_region, vt_bulk_line (i).rqst_mm, vt_bulk_line (i).ordered_quantity, vt_bulk_line (i).request_date, vt_bulk_line (i).hdr_creation_date, vt_bulk_line (i).lne_creation_date, vt_bulk_line (i).latest_acceptable_date, vt_bulk_line (i).schedule_ship_date, vt_bulk_line (i).line_number, 'INSERT', --process_mode
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    'N', --status
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         SYSDATE, --creation_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  gn_user_id, --created_by
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              SYSDATE
                                 ,                          --last_update_date
                                   gn_user_id                --last_updated_by
                                             );

                ln_bulk_cnt   := ln_bulk_cnt + SQL%ROWCOUNT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    insrt_msg ('LOG',
                               'Error during insertion: ' || SQLERRM,
                               'Y');
            END;

            COMMIT;
            EXIT WHEN bulk_line_cur%NOTFOUND;
        END LOOP;

        CLOSE bulk_line_cur;

        insrt_msg (
            'LOG',
            'Records inserted into Bulk Staging table: ' || ln_bulk_cnt,
            'Y');

        --Start changes v1.2
        UPDATE xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
           SET rqst_mm   =
                   (SELECT NVL (lookup_code, xdbs.rqst_mm)
                      FROM fnd_lookup_values flv
                     WHERE     lookup_type = 'XXD_MSC_PERIOD_DATES'
                           AND flv.language = USERENV ('LANG')
                           AND TRUNC (request_date) BETWEEN TO_DATE (
                                                                meaning,
                                                                'DD-MON-RRRR')
                                                        AND TO_DATE (
                                                                description,
                                                                'DD-MON-RRRR')
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           SYSDATE)
                           AND flv.enabled_flag = 'Y')
         WHERE request_id = gn_request_id AND status = 'N';

        insrt_msg (
            'LOG',
               'Records updated with rqst_mm in Bulk Staging table: '
            || SQL%ROWCOUNT,
            'Y');
        --End changes v1.2

        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gn_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;
        insrt_msg ('LOG', 'End pull_blk_ordr_data: ' || x_ret_stat, 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_unexp;
            x_msg        := SQLERRM;
            ROLLBACK;
            insrt_msg ('LOG', 'Error in pull_blk_ordr_data: ' || x_msg, 'Y');
    END pull_blk_ordr_data;

    PROCEDURE validate_d2b_data (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2, x_batch_name IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        ln_hdr_id    NUMBER;
        ln_lne_id    NUMBER;
        ln_rem_qty   NUMBER;
        ln_f_cnt     NUMBER := 0;
        ln_d_cnt     NUMBER := 0;
        ln_c_cnt     NUMBER := 0;
        ln_b_cnt     NUMBER;

        CURSOR fcst_cur IS
              SELECT ebs_inv_item_id, fcst_month, channel,
                     fcst_region, qty_update
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE xdfs.batch_name = x_batch_name AND xdfs.operation = 'D'
            GROUP BY ebs_inv_item_id, channel, fcst_region,
                     fcst_month, qty_update
            ORDER BY fcst_month, ebs_inv_item_id;

        CURSOR bulk_cur (p_item_id NUMBER, p_f_month VARCHAR2, p_channel VARCHAR2
                         , p_f_region VARCHAR2)
        IS
              SELECT xdbs.header_id,
                     xdbs.line_id,
                     xdbs.order_number,
                     xdbs.line_number,
                     xdbs.original_quantity,
                     xdbs.schedule_ship_date,
                     CASE
                         WHEN schedule_ship_date IS NULL THEN 1
                         ELSE 2
                     END sort_ordr
                FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
               WHERE     xdbs.batch_name = x_batch_name
                     AND xdbs.inventory_item_id = p_item_id
                     AND xdbs.rqst_mm = p_f_month
                     AND xdbs.channel = p_channel
                     AND xdbs.fcst_region = p_f_region
            ORDER BY sort_ordr, xdbs.hdr_creation_date DESC, xdbs.lne_creation_date DESC;
    BEGIN
        insrt_msg (
            'LOG',
               'Starting validate_d2b_data: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET schdl_qty   =
                   (SELECT NVL (SUM (original_quantity), 0)
                      FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t
                     WHERE     inventory_item_id = xdfs.ebs_inv_item_id
                           AND rqst_mm = xdfs.fcst_month
                           AND channel = xdfs.channel
                           AND fcst_region = xdfs.fcst_region
                           AND batch_name = xdfs.batch_name
                           AND schedule_ship_date IS NOT NULL),
               unsch_qty   =
                   (SELECT NVL (SUM (original_quantity), 0)
                      FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t
                     WHERE     inventory_item_id = xdfs.ebs_inv_item_id
                           AND rqst_mm = xdfs.fcst_month
                           AND channel = xdfs.channel
                           AND fcst_region = xdfs.fcst_region
                           AND batch_name = xdfs.batch_name
                           AND schedule_ship_date IS NULL)
         WHERE batch_name = x_batch_name AND status = 'N';

        insrt_msg ('LOG',
                   'Fcst table sch qty updated records: ' || SQL%ROWCOUNT,
                   'Y');
        insrt_msg (
            'LOG',
               'Updated schdl_qty and unsch_qty: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            gv_debug);

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET bulk_qty = schdl_qty + unsch_qty, qty_update = ABS (final_fcst - (schdl_qty + unsch_qty))
         WHERE batch_name = x_batch_name AND status = 'N';

        insrt_msg ('LOG',
                   'Fcst table blk qty updated records: ' || SQL%ROWCOUNT,
                   'Y');
        insrt_msg (
            'LOG',
               'Updated bulk_qty and qty_update: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            gv_debug);

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET operation   =
                   CASE
                       WHEN bulk_qty = 0 AND final_fcst > 0 THEN 'N'
                       WHEN bulk_qty < final_fcst THEN 'I'
                       WHEN bulk_qty > final_fcst THEN 'D'
                       WHEN bulk_qty = final_fcst THEN 'M'
                   END
         WHERE batch_name = x_batch_name AND status = 'N';

        insrt_msg ('LOG',
                   'Fcst table operation updated records: ' || SQL%ROWCOUNT,
                   'Y');
        insrt_msg (
            'LOG',
               'Updated operation: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            gv_debug);

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET header_id   =
                   (SELECT header_id
                      FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
                     WHERE     inventory_item_id = xdfs.ebs_inv_item_id
                           AND rqst_mm = xdfs.fcst_month
                           AND channel = xdfs.channel
                           AND fcst_region = xdfs.fcst_region
                           AND batch_name = xdfs.batch_name
                           AND hdr_creation_date =
                               (SELECT MIN (hdr_creation_date)
                                  FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t
                                 WHERE     inventory_item_id =
                                           xdbs.inventory_item_id
                                       AND rqst_mm = xdbs.rqst_mm
                                       AND channel = xdbs.channel
                                       AND fcst_region = xdbs.fcst_region
                                       AND batch_name = xdbs.batch_name)
                           AND ROWNUM = 1)
         WHERE batch_name = x_batch_name AND status = 'N' AND operation = 'I';

        insrt_msg ('LOG',
                   'Fcst table header_id updated records: ' || SQL%ROWCOUNT,
                   'Y');

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET order_number   =
                   (SELECT order_number
                      FROM oe_order_headers_all
                     WHERE header_id = xdfs.header_id),
               org_id   =
                   (SELECT org_id
                      FROM oe_order_headers_all
                     WHERE header_id = xdfs.header_id)
         WHERE     batch_name = x_batch_name
               AND status = 'N'
               AND header_id IS NOT NULL;

        insrt_msg (
            'LOG',
            'Fcst table order_number updated records: ' || SQL%ROWCOUNT,
            'Y');
        insrt_msg (
            'LOG',
               'Updated order_number in fcst: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            gv_debug);

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET order_type   =
                   (SELECT flv.attribute5
                      FROM fnd_lookup_values flv
                     WHERE     flv.lookup_type =
                               'XXDO_D2B_FORECAST_BULK_MAPPING'
                           AND flv.tag = xdfs.region
                           AND flv.attribute1 = xdfs.fcst_region
                           AND flv.attribute2 = xdfs.channel
                           AND NVL (flv.attribute3, xdfs.brand) = xdfs.brand
                           AND flv.attribute7 = 1                   --priority
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           SYSDATE)
                           AND ROWNUM = 1),
               sold_to_id   =
                   (SELECT cust_account_id
                      FROM hz_cust_accounts hca, fnd_lookup_values flv
                     WHERE     account_number = flv.attribute6
                           AND flv.lookup_type =
                               'XXDO_D2B_FORECAST_BULK_MAPPING'
                           AND flv.tag = xdfs.region
                           AND flv.attribute1 = xdfs.fcst_region
                           AND flv.attribute2 = xdfs.channel
                           AND NVL (flv.attribute3, xdfs.brand) = xdfs.brand
                           AND flv.attribute7 = 1                   --priority
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           SYSDATE)
                           AND ROWNUM = 1)
         WHERE     xdfs.batch_name = x_batch_name
               AND status = 'N'
               AND xdfs.operation = 'N';

        insrt_msg ('LOG',
                   'Fcst table order_type updated records: ' || SQL%ROWCOUNT,
                   'Y');

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET org_id   =
                   (SELECT otta.org_id
                      FROM oe_transaction_types_tl ott, oe_transaction_types_all otta
                     WHERE     ott.name = xdfs.order_type
                           AND otta.transaction_type_id =
                               ott.transaction_type_id
                           AND ott.language = USERENV ('LANG'))
         WHERE     xdfs.batch_name = x_batch_name
               AND status = 'N'
               AND xdfs.operation = 'N';

        insrt_msg ('LOG',
                   'Fcst table org_id updated records: ' || SQL%ROWCOUNT,
                   'Y');

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET ship_to_id   =
                   (SELECT site_use_id
                      FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas, hz_cust_accounts hca,
                           fnd_lookup_values flv
                     WHERE     hcsu.location = flv.attribute8
                           AND hcsu.org_id = xdfs.org_id
                           AND hcsu.cust_acct_site_id =
                               hcas.cust_acct_site_id
                           AND hcas.cust_account_id = hca.cust_account_id
                           AND hca.account_number =
                               SUBSTR (flv.attribute6,
                                       1,
                                       INSTR (flv.attribute6, '-') - 1)
                           AND flv.lookup_type =
                               'XXDO_D2B_FORECAST_BULK_MAPPING'
                           AND flv.tag = xdfs.region
                           AND flv.attribute1 = xdfs.fcst_region
                           AND flv.attribute2 = xdfs.channel
                           AND NVL (flv.attribute3, xdfs.brand) = xdfs.brand
                           AND flv.attribute7 = 1                   --priority
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           SYSDATE)
                           AND ROWNUM = 1)
         WHERE     xdfs.batch_name = x_batch_name
               AND status = 'N'
               AND xdfs.operation = 'N';

        insrt_msg ('LOG',
                   'Fcst table ship_to_id updated records: ' || SQL%ROWCOUNT,
                   'Y');

        UPDATE xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
           SET operation   = 'C'
         WHERE     original_quantity > 0
               AND batch_name = x_batch_name
               AND status = 'N'
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
                         WHERE     xdfs.ebs_inv_item_id =
                                   xdbs.inventory_item_id
                               AND xdfs.fcst_month = xdbs.rqst_mm
                               AND xdfs.channel = xdbs.channel
                               AND xdfs.fcst_region = xdbs.fcst_region
                               AND xdfs.batch_name = xdbs.batch_name);

        insrt_msg (
            'LOG',
            'Bulk table operation C updated records: ' || SQL%ROWCOUNT,
            'Y');

        COMMIT;
        --Insert C records into xxd_ont_d2b_dmnd_fcst_stg_t

        insrt_msg (
            'LOG',
               'Updated operation in bulk: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            gv_debug);

        FOR fcst_rec IN fcst_cur
        LOOP
            ln_rem_qty   := fcst_rec.qty_update;
            ln_f_cnt     := ln_f_cnt + 1;
            ln_b_cnt     := 0;

            FOR bulk_rec IN bulk_cur (fcst_rec.ebs_inv_item_id, fcst_rec.fcst_month, fcst_rec.channel
                                      , fcst_rec.fcst_region)
            LOOP
                ln_b_cnt   := ln_b_cnt + 1;

                IF bulk_rec.original_quantity >= ln_rem_qty
                THEN
                    ln_d_cnt   := ln_d_cnt + 1;

                    UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t
                       SET order_number = bulk_rec.order_number, line_number = bulk_rec.line_number
                     WHERE     ebs_inv_item_id = fcst_rec.ebs_inv_item_id
                           AND request_id = gn_request_id
                           AND status = 'N'
                           AND fcst_month = fcst_rec.fcst_month
                           AND channel = fcst_rec.channel
                           AND fcst_region = fcst_rec.fcst_region;

                    UPDATE xxdo.xxd_ont_d2b_bulk_ordr_stg_t
                       SET operation = 'D', qty_update = ln_rem_qty
                     WHERE     line_id = bulk_rec.line_id
                           AND request_id = gn_request_id
                           AND status = 'N';

                    EXIT;
                ELSE
                    UPDATE xxdo.xxd_ont_d2b_bulk_ordr_stg_t
                       SET operation = 'C', qty_update = bulk_rec.original_quantity
                     WHERE     line_id = bulk_rec.line_id
                           AND request_id = gn_request_id
                           AND status = 'N';

                    ln_rem_qty   := ln_rem_qty - bulk_rec.original_quantity;
                    ln_c_cnt     := ln_c_cnt + 1;
                END IF;
            END LOOP;

            IF ln_b_cnt > 1
            THEN
                UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t
                   SET order_number = -1, line_number = NULL
                 WHERE     ebs_inv_item_id = fcst_rec.ebs_inv_item_id
                       AND request_id = gn_request_id
                       AND status = 'N'
                       AND fcst_month = fcst_rec.fcst_month
                       AND channel = fcst_rec.channel
                       AND fcst_region = fcst_rec.fcst_region;
            END IF;
        END LOOP;

        insrt_msg ('LOG', 'Forecast D records processed : ' || ln_f_cnt, 'Y');
        insrt_msg ('LOG', 'Bulk Order lines updated D: ' || ln_d_cnt, 'Y');
        insrt_msg ('LOG', 'Bulk Order lines updated C: ' || ln_c_cnt, 'Y');

        insrt_msg (
            'LOG',
               'Updated Decrease records: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            gv_debug);

        COMMIT;

        UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
           SET status   = 'V'
         WHERE batch_name = x_batch_name AND status = 'N';

        UPDATE xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
           SET status   = 'V'
         WHERE batch_name = x_batch_name AND status = 'N';

        COMMIT;

        insrt_msg ('LOG', 'End validate_d2b_data: ' || x_ret_stat, 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_unexp;
            x_msg        := SQLERRM;
            ROLLBACK;
            insrt_msg ('LOG', 'Error in validate_d2b_data: ' || x_msg, 'Y');
    END validate_d2b_data;

    --process_order procedure
    PROCEDURE process_order (
        errbuf            OUT VARCHAR2,
        retcode           OUT VARCHAR2,
        l_hdr_rec_x       OUT oe_order_pub.header_rec_type,
        l_header_rec   IN     oe_order_pub.header_rec_type,
        l_line_tbl     IN     oe_order_pub.line_tbl_type)
    IS
        l_header_rec_x             oe_order_pub.header_rec_type;
        l_line_tbl_x               oe_order_pub.line_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_return_status            VARCHAR2 (1000);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (1000);
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        l_msg_index_out            NUMBER (10);
        l_message_data             VARCHAR2 (2000);
    BEGIN
        insrt_msg (
            'LOG',
               'Inside process_order: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            gv_debug);

        l_return_status   := NULL;
        l_msg_data        := NULL;
        l_message_data    := NULL;
        oe_msg_pub.initialize;
        oe_msg_pub.g_msg_tbl.delete;

        IF l_header_rec.operation = oe_globals.g_opr_create -- AND l_header_rec.flow_status_code = 'BOOKED'
        THEN
            l_action_request_tbl (1).request_type   :=
                oe_globals.g_book_order;
            l_action_request_tbl (1).entity_code   :=
                oe_globals.g_entity_header;
            insrt_msg (
                'LOG',
                'request_type: ' || l_action_request_tbl (1).request_type,
                'Y');
            insrt_msg (
                'LOG',
                'entity_code: ' || l_action_request_tbl (1).entity_code,
                'Y');
        END IF;

        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_true,
            p_return_values            => fnd_api.g_true,
            p_action_commit            => fnd_api.g_true,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            x_header_rec               => l_header_rec_x,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => x_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => l_line_tbl_x,
            x_line_val_tbl             => x_line_val_tbl,
            x_line_adj_tbl             => x_line_adj_tbl,
            x_line_adj_val_tbl         => x_line_adj_val_tbl,
            x_line_price_att_tbl       => x_line_price_att_tbl,
            x_line_adj_att_tbl         => x_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
            x_line_scredit_tbl         => x_line_scredit_tbl,
            x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
            x_lot_serial_tbl           => x_lot_serial_tbl,
            x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
            x_action_request_tbl       => x_action_request_tbl);

        insrt_msg ('LOG',
                   'process_order API status: ' || l_return_status,
                   gv_debug);

        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            COMMIT;
        ELSE
            ROLLBACK;

            FOR i IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                , p_msg_index_out => l_msg_index_out);

                l_message_data   :=
                    SUBSTR (l_message_data || l_msg_data, 1, 2000);
            END LOOP;

            insrt_msg ('LOG',
                       'process_order API  Error: ' || l_message_data,
                       gv_debug);
        END IF;

        retcode           := l_return_status;
        errbuf            := l_message_data;
        l_hdr_rec_x       := l_header_rec_x;
    EXCEPTION
        WHEN OTHERS
        THEN
            insrt_msg ('LOG',
                       'Unexpected Error in process_order: ' || SQLERRM,
                       'Y');
    END process_order;

    PROCEDURE submit_workers (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2, x_batch_name IN VARCHAR2
                              , x_workers IN NUMBER)
    AS
        lt_header_rec    oe_order_pub.header_rec_type;
        lt_line_tbl      oe_order_pub.line_tbl_type;
        ln_workers       NUMBER;
        ln_rec_cnt       NUMBER;
        ln_batch_cnt     NUMBER;
        ln_req_cnt       NUMBER;
        ln_bch_rec_cnt   NUMBER;
        ln_wrkr_cnt      NUMBER := 50;

        ln_ordr_sz       NUMBER := 500;
        ln_index         NUMBER := 0;
        ln_lne_cnt       NUMBER := 0;
        ln_hdr_cnt       NUMBER := 0;
        lv_prev_styl     VARCHAR2 (40);

        CURSOR ordr_org_cur IS
              SELECT DISTINCT org_id
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = x_batch_name
                     AND xdfs.operation = 'N'
                     AND xdfs.status = 'V'
            ORDER BY org_id;

        CURSOR new_hdr_cur (p_org_id NUMBER)
        IS
              SELECT DISTINCT fcst_month,
                              order_type,
                              brand,
                              sold_to_id,
                              ship_to_id,
                              organization_id,
                              inv_org_code,
                              (SELECT transaction_type_id
                                 FROM oe_transaction_types_tl
                                WHERE     name = order_type
                                      AND language = USERENV ('LANG')) ordr_typ_id
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = x_batch_name
                     AND xdfs.org_id = p_org_id
                     AND xdfs.operation = 'N'
                     AND xdfs.status = 'V'
            ORDER BY fcst_month;

        CURSOR new_ordr_cur (p_org_id NUMBER, p_mm_yr VARCHAR2, p_ordr_typ VARCHAR2
                             , p_brand VARCHAR2, p_ship_frm NUMBER)
        IS
              SELECT ebs_inv_item_id,
                     sku,
                     qty_update,
                     SUBSTR (sku,
                             1,
                               INSTR (sku, '-', 1,
                                      2)
                             - 1) style_color
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = x_batch_name
                     AND xdfs.org_id = p_org_id
                     AND xdfs.fcst_month = p_mm_yr
                     AND xdfs.order_type = p_ordr_typ
                     AND xdfs.brand = p_brand
                     AND xdfs.organization_id = p_ship_frm
                     AND xdfs.operation = 'N'
                     AND xdfs.status = 'V'
            ORDER BY style_color, sku;

        TYPE conc_ids IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        conc             conc_ids;
        phase            VARCHAR2 (240);
        status           VARCHAR2 (240);
        dev_phase        VARCHAR2 (240);
        dev_status       VARCHAR2 (240);
        MESSAGE          VARCHAR2 (240);
        req_status       BOOLEAN;
    BEGIN
        insrt_msg ('LOG', 'Inside submit_workers Procedure', 'Y');

        IF NVL (x_workers, 0) <= 0
        THEN
            ln_workers   := 1;
        ELSE
            ln_workers   := x_workers;
        END IF;

        insrt_msg (
            'LOG',
               'Submitting Cancel Workers: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');

        SELECT COUNT (*)
          INTO ln_rec_cnt
          FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
         WHERE     xdbs.batch_name = x_batch_name
               AND xdbs.operation IS NOT NULL
               AND xdbs.status = 'V';

        insrt_msg ('LOG', 'Cancel Records: ' || ln_rec_cnt, 'Y');

        IF ln_rec_cnt > 0
        THEN
            IF ln_rec_cnt <= ln_wrkr_cnt
            THEN
                ln_workers     := 1;
                ln_batch_cnt   := ln_rec_cnt;
            ELSE
                ln_batch_cnt   := CEIL (ln_rec_cnt / ln_workers);
            END IF;

            ln_req_cnt   := 0;

            FOR i IN 1 .. ln_workers
            LOOP
                UPDATE xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
                   SET batch_num = i, request_id = gn_request_id
                 WHERE     xdbs.batch_name = x_batch_name
                       AND xdbs.operation IS NOT NULL
                       AND xdbs.batch_num IS NULL
                       AND xdbs.status = 'V'
                       AND header_id IN
                               (SELECT header_id
                                  FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs1
                                 WHERE     xdbs1.batch_name = x_batch_name
                                       AND xdbs1.operation IS NOT NULL
                                       AND xdbs1.batch_num IS NULL
                                       AND xdbs1.status = 'V'
                                       AND ROWNUM <= ln_batch_cnt);

                COMMIT;

                BEGIN
                    SELECT COUNT (*)
                      INTO ln_bch_rec_cnt
                      FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
                     WHERE     xdbs.batch_name = x_batch_name
                           AND xdbs.batch_num = i
                           AND xdbs.operation IS NOT NULL
                           AND xdbs.status = 'V'
                           AND request_id = gn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_bch_rec_cnt   := 0;
                END;

                IF ln_bch_rec_cnt > 0
                THEN
                    ln_req_cnt   := ln_req_cnt + 1;
                    conc (i)     :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXD_ONT_D2B_PROCESSOR_WORKER',
                            argument1     => x_batch_name,
                            argument2     => 'CANCEL',           --p_proc_type
                            argument3     => i,                    --batch_num
                            argument4     => gv_debug,
                            argument5     => gn_request_id,
                            description   => NULL,
                            start_time    => NULL);
                END IF;
            END LOOP;

            COMMIT;

            FOR i IN 1 .. ln_req_cnt
            LOOP
                req_status   :=
                    fnd_concurrent.wait_for_request (conc (i), 10, 0,
                                                     phase, status, dev_phase
                                                     , dev_status, MESSAGE);
                insrt_msg ('LOG', 'Cancel Request: ' || conc (i), gv_debug);
                insrt_msg ('LOG', 'phase: ' || phase, gv_debug);
                insrt_msg ('LOG', 'status: ' || status, gv_debug);
                insrt_msg ('LOG', 'message: ' || MESSAGE, gv_debug);
            END LOOP;
        END IF;

        insrt_msg (
            'LOG',
               'Submitting New Line Workers: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');

        SELECT COUNT (*)
          INTO ln_rec_cnt
          FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
         WHERE     xdfs.batch_name = x_batch_name
               AND xdfs.operation = 'I'
               AND xdfs.status = 'V';

        insrt_msg ('LOG', 'New Line Records: ' || ln_rec_cnt, 'Y');

        IF ln_rec_cnt > 0
        THEN
            IF NVL (x_workers, 0) <= 0
            THEN
                ln_workers   := 1;
            ELSE
                ln_workers   := x_workers;
            END IF;

            IF ln_rec_cnt <= ln_wrkr_cnt
            THEN
                ln_workers     := 1;
                ln_batch_cnt   := ln_rec_cnt;
            ELSE
                ln_batch_cnt   := CEIL (ln_rec_cnt / ln_workers);
            END IF;

            ln_req_cnt   := 0;

            FOR i IN 1 .. ln_workers
            LOOP
                UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
                   SET batch_num = i, request_id = gn_request_id
                 WHERE     xdfs.batch_name = x_batch_name
                       AND xdfs.operation = 'I'
                       AND xdfs.batch_num IS NULL
                       AND xdfs.status = 'V'
                       AND header_id IN
                               (SELECT header_id
                                  FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs1
                                 WHERE     xdfs1.batch_name = x_batch_name
                                       AND xdfs1.operation = 'I'
                                       AND xdfs1.batch_num IS NULL
                                       AND xdfs1.status = 'V'
                                       AND ROWNUM <= ln_batch_cnt);

                COMMIT;

                BEGIN
                    SELECT COUNT (*)
                      INTO ln_bch_rec_cnt
                      FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
                     WHERE     xdfs.batch_name = x_batch_name
                           AND xdfs.batch_num = i
                           AND xdfs.operation = 'I'
                           AND xdfs.status = 'V'
                           AND request_id = gn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_bch_rec_cnt   := 0;
                END;

                IF ln_bch_rec_cnt > 0
                THEN
                    ln_req_cnt   := ln_req_cnt + 1;

                    conc (i)     :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXD_ONT_D2B_PROCESSOR_WORKER',
                            argument1     => x_batch_name,
                            argument2     => 'NEW_LINE',         --p_proc_type
                            argument3     => i,                    --batch_num
                            argument4     => gv_debug,
                            argument5     => gn_request_id,
                            description   => NULL,
                            start_time    => NULL);
                END IF;
            END LOOP;

            COMMIT;

            FOR i IN 1 .. ln_req_cnt
            LOOP
                req_status   :=
                    fnd_concurrent.wait_for_request (conc (i), 10, 0,
                                                     phase, status, dev_phase
                                                     , dev_status, MESSAGE);
                insrt_msg ('LOG', 'New Line Request: ' || conc (i), gv_debug);
                insrt_msg ('LOG', 'phase: ' || phase, gv_debug);
                insrt_msg ('LOG', 'status: ' || status, gv_debug);
                insrt_msg ('LOG', 'message: ' || MESSAGE, gv_debug);
            END LOOP;
        END IF;

        insrt_msg (
            'LOG',
               'Submitting New Order Workers: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');

        BEGIN
            SELECT TO_NUMBER (tag)
              INTO ln_ordr_sz
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXDO_D2B_FCST_BK_RPT_UTILITIES'
                   AND flv.meaning = 'Order Size'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ordr_sz   := 500;
                insrt_msg (
                    'LOG',
                       'Error while fetching Order Size from Lookup: '
                    || SQLERRM,
                    'Y');
        END;

        IF ln_wrkr_cnt > ln_ordr_sz
        THEN
            ln_wrkr_cnt   := ln_ordr_sz;
        END IF;


        SELECT COUNT (*)
          INTO ln_rec_cnt
          FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
         WHERE     xdfs.batch_name = x_batch_name
               AND xdfs.operation = 'N'
               AND xdfs.status = 'V';

        insrt_msg ('LOG', 'New Order Records: ' || ln_rec_cnt, 'Y');

        IF ln_rec_cnt > 0
        THEN
            IF NVL (x_workers, 0) <= 0 OR ln_rec_cnt <= ln_wrkr_cnt
            THEN
                ln_workers   := 1;
            ELSE
                ln_workers   := x_workers;
            END IF;

            ln_batch_cnt   := 1;

            FOR org_rec IN ordr_org_cur
            LOOP
                insrt_msg ('LOG', 'Org ID: ' || org_rec.org_id, gv_debug);

                FOR ordr_rec IN new_hdr_cur (org_rec.org_id)
                LOOP
                    lv_prev_styl   := 'NEW';
                    ln_index       := 0;

                    --insrt_msg ('LOG', 'fcst_month: '||ordr_rec.fcst_month, gv_debug);
                    FOR new_lne_rec
                        IN new_ordr_cur (org_rec.org_id,
                                         ordr_rec.fcst_month,
                                         ordr_rec.order_type,
                                         ordr_rec.brand,
                                         ordr_rec.organization_id)
                    LOOP
                        ln_index       := ln_index + 1;
                        ln_lne_cnt     := ln_lne_cnt + 1;

                        --insrt_msg ('LOG', 'lv_prev_styl: '||lv_prev_styl, gv_debug);
                        --insrt_msg ('LOG', 'style_color: '||new_lne_rec.style_color, gv_debug);

                        --Start changes v1.1
                        IF ln_index >= ln_ordr_sz
                        THEN
                            IF lv_prev_styl <> new_lne_rec.style_color
                            THEN
                                ln_index     := 0;
                                ln_hdr_cnt   := ln_hdr_cnt + 1;

                                IF ln_batch_cnt = ln_workers
                                THEN
                                    ln_batch_cnt   := 1;
                                ELSE
                                    ln_batch_cnt   := ln_batch_cnt + 1;
                                END IF;                   --ln_batch_cnt check
                            END IF;                       --lv_prev_styl check
                        END IF;                               --ln_index check

                        --End changes v1.1

                        IF lv_prev_styl <> new_lne_rec.style_color
                        THEN
                            UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
                               SET batch_num = ln_batch_cnt, header_batch = ln_hdr_cnt, request_id = gn_request_id
                             WHERE     xdfs.batch_name = x_batch_name
                                   AND xdfs.operation = 'N'
                                   AND xdfs.batch_num IS NULL
                                   AND xdfs.status = 'V'
                                   AND xdfs.org_id = org_rec.org_id
                                   AND xdfs.fcst_month = ordr_rec.fcst_month
                                   AND xdfs.order_type = ordr_rec.order_type
                                   AND xdfs.brand = ordr_rec.brand
                                   AND xdfs.organization_id =
                                       ordr_rec.organization_id
                                   AND SUBSTR (sku,
                                               1,
                                                 INSTR (sku, '-', 1,
                                                        2)
                                               - 1) = new_lne_rec.style_color;
                        --insrt_msg ('LOG', 'Updated batch_num: '||ln_batch_cnt||'for: '||SQL%ROWCOUNT, gv_debug);

                        END IF;                           --lv_prev_styl check

                        --insrt_msg ('LOG', 'ln_index: '||ln_index, gv_debug);

                        --Start changes v1.1
                        /*
           IF ln_index >= ln_ordr_sz THEN
            IF lv_prev_styl <> new_lne_rec.style_color THEN

             ln_index := 0;
             ln_hdr_cnt := ln_hdr_cnt + 1;
             IF ln_batch_cnt = ln_workers THEN
              ln_batch_cnt := 1;
             ELSE
              ln_batch_cnt := ln_batch_cnt + 1;
             END IF;  --ln_batch_cnt check
            END IF; --lv_prev_styl check
           END IF; --ln_index check
            */
                        --End changes v1.1
                        lv_prev_styl   := new_lne_rec.style_color;
                    END LOOP;

                    IF ln_index > 0
                    THEN
                        ln_hdr_cnt   := ln_hdr_cnt + 1;
                    END IF;

                    IF ln_batch_cnt = ln_workers
                    THEN
                        ln_batch_cnt   := 1;
                    ELSE
                        ln_batch_cnt   := ln_batch_cnt + 1;
                    END IF;

                    COMMIT;
                END LOOP;                                           --hdr loop
            END LOOP;                                            --org id loop
        END IF;                                             --ln_rec_cnt check

        COMMIT;

        insrt_msg ('LOG', 'Total Order Headers: ' || ln_hdr_cnt, 'Y');
        insrt_msg ('LOG', 'Total Order Lines: ' || ln_lne_cnt, 'Y');

        ln_req_cnt   := 0;

        FOR i IN 1 .. ln_workers
        LOOP
            BEGIN
                SELECT COUNT (*)
                  INTO ln_bch_rec_cnt
                  FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
                 WHERE     xdfs.batch_name = x_batch_name
                       AND xdfs.batch_num = i
                       AND xdfs.operation = 'N'
                       AND xdfs.status = 'V'
                       AND request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_bch_rec_cnt   := 0;
            END;

            IF ln_bch_rec_cnt > 0
            THEN
                ln_req_cnt   := ln_req_cnt + 1;

                conc (i)     :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_ONT_D2B_PROCESSOR_WORKER',
                        argument1     => x_batch_name,
                        argument2     => 'NEW_ORDER',            --p_proc_type
                        argument3     => i,                        --batch_num
                        argument4     => gv_debug,
                        argument5     => gn_request_id,
                        description   => NULL,
                        start_time    => NULL);
            END IF;
        END LOOP;

        COMMIT;

        FOR i IN 1 .. ln_req_cnt
        LOOP
            req_status   :=
                fnd_concurrent.wait_for_request (conc (i), 10, 0,
                                                 phase, status, dev_phase,
                                                 dev_status, MESSAGE);
            insrt_msg ('LOG', 'New Order Request: ' || conc (i), gv_debug);
            insrt_msg ('LOG', 'phase: ' || phase, gv_debug);
            insrt_msg ('LOG', 'status: ' || status, gv_debug);
            insrt_msg ('LOG', 'message: ' || MESSAGE, gv_debug);
        END LOOP;

        insrt_msg ('LOG', 'Completed submit_workers Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            insrt_msg ('LOG',
                       'Error while generating output: ' || SQLERRM,
                       'Y');
    END submit_workers;

    PROCEDURE validate_main (retcode OUT VARCHAR2, errbuff OUT VARCHAR2, p_batch_name IN VARCHAR2, p_region IN VARCHAR2, p_fcst_rgn IN VARCHAR2, p_channel IN VARCHAR2
                             , p_brand IN VARCHAR2, --p_mode                IN     VARCHAR2,
                                                    p_debug IN VARCHAR2)
    AS
        lv_err_msg       VARCHAR2 (2000);
        lv_ret_code      VARCHAR2 (1);
        lv_batch_exist   VARCHAR2 (1) := 'N';
        exPreProcess     EXCEPTION;
    BEGIN
        gv_debug   := p_debug;

        insrt_msg ('LOG', 'p_debug: ' || gv_debug, 'Y');
        insrt_msg ('LOG', 'p_batch_name: ' || p_batch_name, gv_debug);
        insrt_msg ('LOG', 'p_region: ' || p_region, gv_debug);
        insrt_msg ('LOG', 'p_fcst_rgn: ' || p_fcst_rgn, gv_debug);
        insrt_msg ('LOG', 'p_channel: ' || p_channel, gv_debug);
        insrt_msg ('LOG', 'p_brand: ' || p_brand, gv_debug);

        --insrt_msg ('LOG', 'p_mode: ' || p_mode, gv_debug);

        --validate p_batch_name and warning if not unique
        BEGIN
            SELECT 'Y'
              INTO lv_batch_exist
              FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t
             WHERE batch_name = p_batch_name;

            IF lv_batch_exist = 'N'
            THEN
                SELECT 'Y'
                  INTO lv_batch_exist
                  FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t
                 WHERE batch_name = p_batch_name;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_batch_exist   := 'N';
            WHEN OTHERS
            THEN
                lv_batch_exist   := 'Y';
        END;

        IF lv_batch_exist = 'Y'
        THEN
            RAISE exPreProcess;
        ELSE
            --IF p_mode IS NULL THEN
            archive_stg_tabs (lv_err_msg, lv_ret_code, p_region,
                              p_brand);

                           /*

collect_dmnd_fcst (lv_err_msg,
       lv_ret_code,
       p_region,
       p_fcst_rgn,
       p_channel,
       p_brand,
       p_batch_name);
       */

            pull_dmnd_fcst_data (lv_err_msg, lv_ret_code, p_region,
                                 p_fcst_rgn, p_channel, p_brand,
                                 p_batch_name);

            pull_blk_ordr_data (lv_err_msg, lv_ret_code, p_region,
                                p_fcst_rgn, p_channel, p_brand,
                                p_batch_name);

            validate_d2b_data (lv_err_msg, lv_ret_code, p_batch_name);

            generate_output (lv_err_msg, lv_ret_code, p_batch_name);
        --insrt_msg ('OUTPUT', 'p_mode: ' || p_mode, gv_debug);
        --END IF;

        END IF;
    EXCEPTION
        WHEN exPreProcess
        THEN
            retcode   := 1;
            errbuff   :=
                'Batch Name has been already used. Please use a unique batch name';
            insrt_msg ('LOG', errbuff, 'Y');
        WHEN OTHERS
        THEN
            insrt_msg ('LOG', 'Error in validate_main: ' || SQLERRM, 'Y');
    END validate_main;

    PROCEDURE process_main (retcode OUT VARCHAR2, errbuff OUT VARCHAR2, p_batch_name IN VARCHAR2
                            , --p_mode                IN     VARCHAR2,
                              p_workers IN NUMBER, p_debug IN VARCHAR2)
    AS
        lv_err_msg    VARCHAR2 (2000);
        lv_ret_code   VARCHAR2 (1);
        ln_fcst_cnt   NUMBER;
        ln_bulk_cnt   NUMBER;
    BEGIN
        gv_debug   := p_debug;

        insrt_msg ('LOG', 'p_debug: ' || gv_debug, 'Y');
        insrt_msg ('LOG', 'p_batch_name: ' || p_batch_name, gv_debug);

        -- insrt_msg ('LOG', 'p_mode: ' || p_mode, gv_debug);
        --IF p_mode IS NULL THEN
        BEGIN
            SELECT COUNT (*)
              INTO ln_bulk_cnt
              FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
             WHERE     xdbs.batch_name = p_batch_name
                   AND xdbs.operation IS NOT NULL
                   AND status = 'V';

            SELECT COUNT (*)
              INTO ln_fcst_cnt
              FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
             WHERE     xdfs.batch_name = p_batch_name
                   AND xdfs.operation IN ('N', 'I')
                   AND status = 'V';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_bulk_cnt   := 0;
                ln_fcst_cnt   := 0;
        END;

        IF ln_fcst_cnt > 0 OR ln_bulk_cnt > 0
        THEN
            submit_workers (lv_err_msg, lv_ret_code, p_batch_name,
                            p_workers);
        ELSE
            insrt_msg (
                'LOG',
                'The Batch Name provided has 0 records to be processed',
                'Y');
        END IF;
    --END IF;

    EXCEPTION
        WHEN OTHERS
        THEN
            insrt_msg ('LOG', 'Error in process_main: ' || SQLERRM, 'Y');
    END process_main;

    PROCEDURE process_worker (retcode OUT VARCHAR2, errbuff OUT VARCHAR2, p_batch_name IN VARCHAR2, p_proc_type IN VARCHAR2, p_batch_num IN NUMBER, p_debug IN VARCHAR2
                              , p_rqst_id IN NUMBER)
    AS
        lv_err_msg        VARCHAR2 (2000);
        lv_ret_code       VARCHAR2 (1);
        lt_header_rec     oe_order_pub.header_rec_type;
        lt_hdr_rec_x      oe_order_pub.header_rec_type;
        lt_line_tbl       oe_order_pub.line_tbl_type;
        ln_index          NUMBER;
        ln_resp_id        NUMBER := 0;
        ln_resp_appl_id   NUMBER := 0;
        ln_user_id        NUMBER := NVL (fnd_global.user_id, -1);
        lv_exception      EXCEPTION;
        ln_src_id         NUMBER;
        ln_seq_id         NUMBER;
        ln_hdr_cnt        NUMBER := 0;
        ln_lne_cnt        NUMBER := 0;
        ln_c_cnt          NUMBER := 0;
        ln_d_cnt          NUMBER := 0;
        ln_hdr_id         NUMBER;

        CURSOR cancel_org_cur IS
              SELECT DISTINCT org_id
                FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
               WHERE     xdbs.batch_name = p_batch_name
                     AND xdbs.batch_num = p_batch_num
                     AND xdbs.operation IS NOT NULL
                     AND xdbs.status = 'V'
                     AND request_id = p_rqst_id
            ORDER BY org_id;

        CURSOR cancel_order_cur (p_org_id NUMBER)
        IS
              SELECT DISTINCT header_id
                FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
               WHERE     xdbs.batch_name = p_batch_name
                     AND xdbs.batch_num = p_batch_num
                     AND xdbs.operation IS NOT NULL
                     AND xdbs.status = 'V'
                     AND request_id = p_rqst_id
                     AND xdbs.org_id = p_org_id
            ORDER BY header_id;

        CURSOR cancel_cur (p_org_id NUMBER, p_header_id NUMBER)
        IS
              SELECT header_id, line_id, inventory_item_id,
                     batch_num, rqst_mm, original_quantity,
                     operation, qty_update
                FROM xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
               WHERE     xdbs.batch_name = p_batch_name
                     AND xdbs.batch_num = p_batch_num
                     AND xdbs.operation IS NOT NULL
                     AND xdbs.status = 'V'
                     AND request_id = p_rqst_id
                     AND xdbs.org_id = p_org_id
                     AND xdbs.header_id = p_header_id
            ORDER BY batch_num, header_id, line_id;

        CURSOR lne_org_cur IS
              SELECT DISTINCT org_id
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = p_batch_name
                     AND xdfs.batch_num = p_batch_num
                     AND xdfs.operation = 'I'
                     AND xdfs.status = 'V'
                     AND request_id = p_rqst_id
            ORDER BY org_id;

        CURSOR lne_order_cur (p_org_id NUMBER)
        IS
              SELECT DISTINCT header_id
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = p_batch_name
                     AND xdfs.batch_num = p_batch_num
                     AND xdfs.operation = 'I'
                     AND xdfs.status = 'V'
                     AND request_id = p_rqst_id
                     AND xdfs.org_id = p_org_id
            ORDER BY header_id;

        CURSOR new_lne_cur (p_org_id NUMBER, p_header_id NUMBER)
        IS
              SELECT ebs_inv_item_id, sku, fcst_month,
                     operation, qty_update, order_number,
                     header_id
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = p_batch_name
                     AND xdfs.batch_num = p_batch_num
                     AND xdfs.operation = 'I'
                     AND xdfs.status = 'V'
                     AND request_id = p_rqst_id
                     AND xdfs.header_id = p_header_id
                     AND xdfs.org_id = p_org_id
            ORDER BY header_id, sku;

        CURSOR ordr_org_cur IS
              SELECT DISTINCT org_id
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = p_batch_name
                     AND xdfs.batch_num = p_batch_num
                     AND xdfs.operation = 'N'
                     AND xdfs.status = 'V'
                     AND request_id = p_rqst_id
            ORDER BY org_id;

        CURSOR new_hdr_cur (p_org_id NUMBER)
        IS
              SELECT DISTINCT fcst_month,
                              header_batch,
                              brand,
                              sold_to_id,
                              ship_to_id,
                              organization_id,
                              inv_org_code,
                              (SELECT transaction_type_id
                                 FROM oe_transaction_types_tl
                                WHERE     name = xdfs.order_type
                                      AND language = USERENV ('LANG')) ordr_typ_id
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = p_batch_name
                     AND xdfs.batch_num = p_batch_num
                     AND xdfs.org_id = p_org_id
                     AND xdfs.operation = 'N'
                     AND xdfs.status = 'V'
                     AND request_id = p_rqst_id
            ORDER BY fcst_month;

        CURSOR new_ordr_cur (p_org_id NUMBER, p_hdr_batch NUMBER)
        IS
              SELECT ebs_inv_item_id,
                     sku,
                     qty_update,
                     SUBSTR (sku,
                             1,
                               INSTR (sku, '-', 1,
                                      2)
                             - 1) style_color
                FROM xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               WHERE     xdfs.batch_name = p_batch_name
                     AND xdfs.batch_num = p_batch_num
                     AND xdfs.org_id = p_org_id
                     AND xdfs.header_batch = p_hdr_batch
                     AND xdfs.operation = 'N'
                     AND xdfs.status = 'V'
                     AND request_id = p_rqst_id
            ORDER BY style_color, sku;
    BEGIN
        gv_debug   := p_debug;

        insrt_msg ('LOG', 'p_debug: ' || gv_debug, 'Y');
        insrt_msg ('LOG', 'p_batch_name: ' || p_batch_name, gv_debug);
        insrt_msg ('LOG', 'p_proc_type: ' || p_proc_type, gv_debug);
        insrt_msg ('LOG', 'p_batch_num: ' || p_batch_num, gv_debug);

        IF p_proc_type = 'CANCEL'
        THEN
            insrt_msg ('LOG', 'Processing Cancel Records', 'Y');

            FOR org_rec IN cancel_org_cur
            LOOP
                ln_resp_id        := NULL;
                ln_resp_appl_id   := NULL;

                BEGIN
                    --Getting the responsibility and application to initialize and set the context
                    SELECT frv.responsibility_id, frv.application_id
                      INTO ln_resp_id, ln_resp_appl_id
                      FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                           apps.hr_organization_units hou
                     WHERE     1 = 1
                           AND hou.organization_id = org_rec.org_id
                           AND fpov.profile_option_value =
                               TO_CHAR (hou.organization_id)
                           AND fpo.profile_option_id = fpov.profile_option_id
                           AND fpo.user_profile_option_name =
                               'MO: Operating Unit'
                           AND frv.responsibility_id = fpov.level_value
                           AND frv.application_id = 660                  --ONT
                           AND frv.responsibility_name LIKE
                                   'Deckers Order Management User%' --OM Responsibility
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (frv.start_date)
                                                   AND TRUNC (
                                                           NVL (frv.end_date,
                                                                SYSDATE))
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        RAISE lv_exception;
                END;

                fnd_global.apps_initialize (user_id        => ln_user_id,
                                            resp_id        => ln_resp_id,
                                            resp_appl_id   => ln_resp_appl_id);

                mo_global.init ('ONT');
                mo_global.set_policy_context ('S', org_rec.org_id);

                FOR ordr_rec IN cancel_order_cur (org_rec.org_id)
                LOOP
                    ln_index      := 1;
                    ln_hdr_cnt    := ln_hdr_cnt + 1;
                    lt_line_tbl   := oe_order_pub.g_miss_line_tbl;

                    FOR cancel_rec
                        IN cancel_cur (org_rec.org_id, ordr_rec.header_id)
                    LOOP
                        lt_line_tbl (ln_index)          :=
                            oe_order_pub.g_miss_line_rec;
                        lt_line_tbl (ln_index).operation   :=
                            oe_globals.g_opr_update;
                        lt_line_tbl (ln_index).org_id   := org_rec.org_id;
                        lt_line_tbl (ln_index).header_id   :=
                            cancel_rec.header_id;
                        lt_line_tbl (ln_index).line_id   :=
                            cancel_rec.line_id;
                        lt_line_tbl (ln_index).change_reason   :=
                            'D2B-FORECAST'; --'D2B Forecast Bulk Cancellation'
                        lt_line_tbl (ln_index).change_comments   :=
                            'Released Bulk Units by Deckers D2B Data Load Program';

                        IF cancel_rec.operation = 'C'
                        THEN
                            lt_line_tbl (ln_index).cancelled_flag     := 'Y';
                            lt_line_tbl (ln_index).ordered_quantity   := 0;
                            ln_c_cnt                                  :=
                                ln_c_cnt + 1;
                        ELSE
                            lt_line_tbl (ln_index).ordered_quantity   :=
                                  cancel_rec.original_quantity
                                - cancel_rec.qty_update;
                            ln_d_cnt   := ln_d_cnt + 1;
                        END IF;

                        ln_index                        :=
                            ln_index + 1;
                        ln_lne_cnt                      :=
                            ln_lne_cnt + 1;
                    END LOOP;

                    process_order (lv_err_msg, lv_ret_code, lt_hdr_rec_x,
                                   lt_header_rec, lt_line_tbl);

                    UPDATE xxdo.xxd_ont_d2b_bulk_ordr_stg_t xdbs
                       SET process_mode = 'CANCEL_QTY', status = lv_ret_code, MESSAGE = lv_err_msg,
                           --request_id = gn_request_id,
                           last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     xdbs.batch_name = p_batch_name
                           AND xdbs.batch_num = p_batch_num
                           AND xdbs.operation IS NOT NULL
                           AND xdbs.status = 'V'
                           AND request_id = p_rqst_id
                           AND xdbs.header_id = ordr_rec.header_id;
                END LOOP;
            END LOOP;

            COMMIT;
            insrt_msg ('LOG', 'Total Headers Processed: ' || ln_hdr_cnt, 'Y');
            insrt_msg ('LOG',
                       'Total Lines (Cancel) Processed: ' || ln_c_cnt,
                       'Y');
            insrt_msg ('LOG',
                       'Total Lines (Qty Decrease) Processed: ' || ln_d_cnt,
                       'Y');
            insrt_msg ('LOG', 'Total Lines Processed: ' || ln_lne_cnt, 'Y');
        ELSIF p_proc_type = 'NEW_LINE'
        THEN
            insrt_msg ('LOG', 'Processing New Line Records', 'Y');

            FOR org_rec IN lne_org_cur
            LOOP
                ln_resp_id        := NULL;
                ln_resp_appl_id   := NULL;

                BEGIN
                    --Getting the responsibility and application to initialize and set the context
                    SELECT frv.responsibility_id, frv.application_id
                      INTO ln_resp_id, ln_resp_appl_id
                      FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                           apps.hr_organization_units hou
                     WHERE     1 = 1
                           AND hou.organization_id = org_rec.org_id
                           AND fpov.profile_option_value =
                               TO_CHAR (hou.organization_id)
                           AND fpo.profile_option_id = fpov.profile_option_id
                           AND fpo.user_profile_option_name =
                               'MO: Operating Unit'
                           AND frv.responsibility_id = fpov.level_value
                           AND frv.application_id = 660                  --ONT
                           AND frv.responsibility_name LIKE
                                   'Deckers Order Management User%' --OM Responsibility
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (frv.start_date)
                                                   AND TRUNC (
                                                           NVL (frv.end_date,
                                                                SYSDATE))
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        RAISE lv_exception;
                END;

                fnd_global.apps_initialize (user_id        => ln_user_id,
                                            resp_id        => ln_resp_id,
                                            resp_appl_id   => ln_resp_appl_id);

                mo_global.init ('ONT');
                mo_global.set_policy_context ('S', org_rec.org_id);

                FOR ordr_rec IN lne_order_cur (org_rec.org_id)
                LOOP
                    ln_index      := 1;
                    ln_hdr_cnt    := ln_hdr_cnt + 1;
                    lt_line_tbl   := oe_order_pub.g_miss_line_tbl;

                    FOR new_lne_rec
                        IN new_lne_cur (org_rec.org_id, ordr_rec.header_id)
                    LOOP
                        lt_line_tbl (ln_index)          :=
                            oe_order_pub.g_miss_line_rec;
                        lt_line_tbl (ln_index).operation   :=
                            oe_globals.g_opr_create;
                        lt_line_tbl (ln_index).header_id   :=
                            new_lne_rec.header_id;
                        lt_line_tbl (ln_index).org_id   := org_rec.org_id;
                        lt_line_tbl (ln_index).ordered_quantity   :=
                            new_lne_rec.qty_update;
                        --Start changes v1.2
                        lt_line_tbl (ln_index).request_date   :=
                            TRUNC (get_prd_strt_dt (new_lne_rec.fcst_month));
                        --End changes v1.2
                        lt_line_tbl (ln_index).inventory_item_id   :=
                            new_lne_rec.ebs_inv_item_id;
                        ln_index                        :=
                            ln_index + 1;
                        ln_lne_cnt                      :=
                            ln_lne_cnt + 1;
                    END LOOP;

                    process_order (lv_err_msg, lv_ret_code, lt_hdr_rec_x,
                                   lt_header_rec, lt_line_tbl);

                    UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
                       SET process_mode = 'LINE_CREATE', status = lv_ret_code, error_message = lv_err_msg,
                           --request_id = gn_request_id,
                           last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     xdfs.batch_name = p_batch_name
                           AND xdfs.batch_num = p_batch_num
                           AND xdfs.operation = 'I'
                           AND xdfs.status = 'V'
                           AND request_id = p_rqst_id
                           AND xdfs.header_id = ordr_rec.header_id;
                END LOOP;
            END LOOP;

            COMMIT;
            insrt_msg ('LOG',
                       'Total Orders (New Line) Processed: ' || ln_hdr_cnt,
                       'Y');
            insrt_msg ('LOG',
                       'Total New Lines Processed: ' || ln_lne_cnt,
                       'Y');

            UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               SET line_number   =
                       (SELECT MAX (oola.line_number) || '.' || MIN (oola.shipment_number)
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = xdfs.header_id
                               AND oola.inventory_item_id =
                                   xdfs.ebs_inv_item_id
                               AND oola.org_id = xdfs.org_id
                               AND oola.ordered_quantity = xdfs.qty_update)
             WHERE     xdfs.batch_name = p_batch_name
                   AND xdfs.batch_num = p_batch_num
                   AND xdfs.operation = 'I'
                   AND xdfs.status = 'S';

            COMMIT;

            UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               SET line_number   =
                       (SELECT MAX (oola.line_number) || '.' || MIN (oola.shipment_number)
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = xdfs.header_id
                               AND oola.inventory_item_id =
                                   xdfs.ebs_inv_item_id
                               AND oola.org_id = xdfs.org_id)
             WHERE     xdfs.batch_name = p_batch_name
                   AND xdfs.batch_num = p_batch_num
                   AND xdfs.operation = 'I'
                   AND xdfs.status = 'S'
                   AND NVL (line_number, '.') = '.'
                   AND request_id = p_rqst_id;

            COMMIT;

            UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               SET line_id   =
                       (SELECT line_id
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = xdfs.header_id
                               AND oola.inventory_item_id =
                                   xdfs.ebs_inv_item_id
                               AND oola.org_id = xdfs.org_id
                               AND xdfs.line_number =
                                      oola.line_number
                                   || '.'
                                   || oola.shipment_number)
             WHERE     xdfs.batch_name = p_batch_name
                   AND xdfs.batch_num = p_batch_num
                   AND xdfs.line_number IS NOT NULL
                   AND xdfs.operation = 'I'
                   AND xdfs.status = 'S';

            insrt_msg (
                'LOG',
                'Updated Line Number for Success New Lines: ' || SQL%ROWCOUNT,
                'Y');

            COMMIT;
        ELSIF p_proc_type = 'NEW_ORDER'
        THEN
            insrt_msg ('LOG', 'Processing New Order Records', 'Y');

            SELECT order_source_id
              INTO ln_src_id
              FROM oe_order_sources
             WHERE name =
                   (SELECT tag
                      FROM fnd_lookup_values flv
                     WHERE     flv.lookup_type =
                               'XXDO_D2B_FCST_BK_RPT_UTILITIES'
                           AND flv.meaning = 'Order Source'
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           SYSDATE));

            FOR org_rec IN ordr_org_cur
            LOOP
                ln_resp_id        := NULL;
                ln_resp_appl_id   := NULL;

                BEGIN
                    --Getting the responsibility and application to initialize and set the context
                    SELECT frv.responsibility_id, frv.application_id
                      INTO ln_resp_id, ln_resp_appl_id
                      FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                           apps.hr_organization_units hou
                     WHERE     1 = 1
                           AND hou.organization_id = org_rec.org_id
                           AND fpov.profile_option_value =
                               TO_CHAR (hou.organization_id)
                           AND fpo.profile_option_id = fpov.profile_option_id
                           AND fpo.user_profile_option_name =
                               'MO: Operating Unit'
                           AND frv.responsibility_id = fpov.level_value
                           AND frv.application_id = 660                  --ONT
                           AND frv.responsibility_name LIKE
                                   'Deckers Order Management User%' --OM Responsibility
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (frv.start_date)
                                                   AND TRUNC (
                                                           NVL (frv.end_date,
                                                                SYSDATE))
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        RAISE lv_exception;
                END;

                fnd_global.apps_initialize (user_id        => ln_user_id,
                                            resp_id        => ln_resp_id,
                                            resp_appl_id   => ln_resp_appl_id);

                mo_global.init ('ONT');
                mo_global.set_policy_context ('S', org_rec.org_id);

                FOR ordr_rec IN new_hdr_cur (org_rec.org_id)
                LOOP
                    SELECT xxdo.xxd_ont_d2b_cust_po_seq.NEXTVAL
                      INTO ln_seq_id
                      FROM DUAL;

                    ln_index                              := 1;
                    lt_line_tbl                           := oe_order_pub.g_miss_line_tbl;

                    lt_header_rec                         := oe_order_pub.g_miss_header_rec;
                    lt_header_rec.order_type_id           := ordr_rec.ordr_typ_id;
                    lt_header_rec.sold_to_org_id          := ordr_rec.sold_to_id;
                    lt_header_rec.ship_to_org_id          := ordr_rec.ship_to_id;
                    --Start changes v1.2
                    --lt_header_rec.request_date := TO_DATE(ordr_rec.fcst_month, 'YYYY-MM');
                    lt_header_rec.request_date            :=
                        TRUNC (get_prd_strt_dt (ordr_rec.fcst_month));
                    --End changes v1.2
                    --Start changes v1.3
                    /*
           lt_header_rec.cust_po_number := 'D2B-' || ordr_rec.brand ||
                                           '-' || ordr_rec.inv_org_code ||
                   '-' || TO_CHAR(lt_header_rec.request_date, 'MONYY') ||
                                           '-' || ln_seq_id;
           */
                    lt_header_rec.cust_po_number          :=
                           'D2B-'
                        || ordr_rec.brand
                        || '-'
                        || ordr_rec.inv_org_code
                        || '-'
                        || TO_CHAR (TO_DATE (ordr_rec.fcst_month, 'YYYY-MM'),
                                    'MONYY')
                        || '-'
                        || ln_seq_id;
                    --End changes v1.3
                    lt_header_rec.ordered_date            := SYSDATE;
                    lt_header_rec.operation               := oe_globals.g_opr_create;
                    --lt_header_rec.booked_flag := 'Y';
                    --lt_header_rec.flow_status_code := 'BOOKED';
                    lt_header_rec.order_source_id         := ln_src_id;
                    lt_header_rec.attribute5              := ordr_rec.brand;
                    lt_header_rec.ship_from_org_id        :=
                        ordr_rec.organization_id;
                    lt_header_rec.orig_sys_document_ref   :=
                        lt_header_rec.cust_po_number;
                    lt_header_rec.attribute1              :=
                        TO_CHAR (lt_header_rec.request_date + 60,
                                 'RRRR/MM/DD HH24:MI:SS');

                    FOR new_lne_rec
                        IN new_ordr_cur (org_rec.org_id,
                                         ordr_rec.header_batch)
                    LOOP
                        lt_line_tbl (ln_index)          :=
                            oe_order_pub.g_miss_line_rec;
                        lt_line_tbl (ln_index).operation   :=
                            oe_globals.g_opr_create;
                        lt_line_tbl (ln_index).org_id   := org_rec.org_id;
                        lt_line_tbl (ln_index).ordered_quantity   :=
                            new_lne_rec.qty_update;
                        lt_line_tbl (ln_index).inventory_item_id   :=
                            new_lne_rec.ebs_inv_item_id;
                        lt_line_tbl (ln_index).ship_from_org_id   :=
                            ordr_rec.organization_id;
                        lt_line_tbl (ln_index).request_date   :=
                            lt_header_rec.request_date;
                        lt_line_tbl (ln_index).orig_sys_line_ref   :=
                            ln_index;

                        ln_index                        :=
                            ln_index + 1;
                        ln_lne_cnt                      :=
                            ln_lne_cnt + 1;
                    --lv_prev_styl := new_lne_rec.style_color;
                    END LOOP;

                    IF ln_index > 1
                    THEN
                        process_order (lv_err_msg, lv_ret_code, lt_hdr_rec_x,
                                       lt_header_rec, lt_line_tbl);
                        ln_hdr_cnt   := ln_hdr_cnt + 1;
                    END IF;

                    ln_hdr_id                             := -1;

                    IF lv_ret_code = 'S'
                    THEN
                        ln_hdr_id   := lt_hdr_rec_x.header_id;
                    END IF;

                    UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
                       SET process_mode = 'ORDR_CREATE', header_id = ln_hdr_id, status = lv_ret_code,
                           error_message = lv_err_msg, --request_id = gn_request_id,
                                                       last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     xdfs.batch_name = p_batch_name
                           AND xdfs.batch_num = p_batch_num
                           AND xdfs.operation = 'N'
                           AND xdfs.status = 'V'
                           AND request_id = p_rqst_id
                           AND xdfs.org_id = org_rec.org_id
                           AND xdfs.header_batch = ordr_rec.header_batch;
                END LOOP;                                           --hdr loop
            END LOOP;                                            --org id loop

            COMMIT;
            insrt_msg ('LOG', 'Total Orders Processed: ' || ln_hdr_cnt, 'Y');
            insrt_msg (
                'LOG',
                'Total Lines Processed for New Orders: ' || ln_lne_cnt,
                'Y');

            UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               SET line_number   =
                       (SELECT MAX (oola.line_number) || '.' || MAX (oola.shipment_number)
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = xdfs.header_id
                               AND oola.inventory_item_id =
                                   xdfs.ebs_inv_item_id
                               AND oola.org_id = xdfs.org_id
                               AND oola.ordered_quantity = xdfs.qty_update)
             WHERE     xdfs.batch_name = p_batch_name
                   AND xdfs.batch_num = p_batch_num
                   AND xdfs.operation = 'N'
                   AND xdfs.status = 'S'
                   AND request_id = p_rqst_id;

            COMMIT;

            UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               SET line_number   =
                       (SELECT MAX (oola.line_number) || '.' || MIN (oola.shipment_number)
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = xdfs.header_id
                               AND oola.inventory_item_id =
                                   xdfs.ebs_inv_item_id
                               AND oola.org_id = xdfs.org_id)
             WHERE     xdfs.batch_name = p_batch_name
                   AND xdfs.batch_num = p_batch_num
                   AND xdfs.operation = 'N'
                   AND xdfs.status = 'S'
                   AND NVL (line_number, '.') = '.'
                   AND request_id = p_rqst_id;

            COMMIT;

            UPDATE xxdo.xxd_ont_d2b_dmnd_fcst_stg_t xdfs
               SET line_id   =
                       (SELECT line_id
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = xdfs.header_id
                               AND oola.inventory_item_id =
                                   xdfs.ebs_inv_item_id
                               AND oola.org_id = xdfs.org_id
                               AND xdfs.line_number =
                                      oola.line_number
                                   || '.'
                                   || oola.shipment_number)
             WHERE     xdfs.batch_name = p_batch_name
                   AND xdfs.batch_num = p_batch_num
                   AND xdfs.line_number IS NOT NULL
                   AND xdfs.operation = 'N'
                   AND xdfs.status = 'S'
                   AND request_id = p_rqst_id;

            insrt_msg (
                'LOG',
                   'Updated Line Number for Success New Orders: '
                || SQL%ROWCOUNT,
                'Y');

            COMMIT;
        END IF;
    EXCEPTION
        WHEN lv_exception
        THEN
            insrt_msg (
                'LOG',
                'Unexpected Error while fetching responsibility: ' || SQLERRM,
                'Y');
        WHEN OTHERS
        THEN
            insrt_msg ('LOG', 'Error in process_worker: ' || SQLERRM, 'Y');
    END process_worker;
END xxd_ont_d2b_demand_to_bulk_pkg;
/


GRANT EXECUTE ON APPS.XXD_ONT_D2B_DEMAND_TO_BULK_PKG TO SOA_INT
/
