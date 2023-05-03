--
-- XXD_CM_CALC_OH_PERCNT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_CM_CALC_OH_PERCNT_PKG"
IS
      /******************************************************************************************
 NAME           : XXD_CM_CALC_OH_PERCNT_PKG
 PROGRAM NAME   : Deckers CM Calculate OH Percentage

 REVISIONS:
 Date        Author             Version  Description
 ----------  ----------         -------  ---------------------------------------------------
 23-JAN-2022 Damodara Gupta     1.0      Created this package using XXD_CM_CALC_OH_PERCNT_PKG
                                         to calculate the OH NONDuty
*********************************************************************************************/
    PROCEDURE write_log_prc (pv_msg IN VARCHAR2)
    IS
        /****************************************************
  -- PROCEDURE write_log_prc
  -- PURPOSE: This Procedure write the log messages
  *****************************************************/
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in write_log_prc Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in write_log_prc Procedure -' || SQLERRM);
    END write_log_prc;

    /***************************************************************************
  -- PROCEDURE main_prc
  -- PURPOSE: This Procedure is Concurrent Program.
  ****************************************************************************/
    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_date IN VARCHAR2, pv_start_date IN VARCHAR2, pv_end_date IN VARCHAR2, pv_mode IN VARCHAR2, pv_int_adj_percnt IN NUMBER DEFAULT 0, pv_dom_adj_percnt IN NUMBER DEFAULT 0, pv_expense_adj_percnt IN NUMBER DEFAULT 0
                        , pv_expense_adj_amt IN NUMBER DEFAULT 0)
    IS
        CURSOR oh_calc_int_cur IS
              SELECT ffvl.attribute1 inv_org_id, ffvl.attribute2 operating_unit, attribute3 oh_percent,
                     ffvl.attribute4 update_oh_ele, ffvl.attribute5 TYPE
                FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
               WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                     AND fvs.flex_value_set_name = 'XXD_CM_OH_CALCULATE_VS'
                     AND ffvl.enabled_flag = 'Y'
                     AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                         TRUNC (SYSDATE)
                     AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                         TRUNC (SYSDATE)
                     AND UPPER (ffvl.attribute5) = 'INTERNATIONAL'
            ORDER BY ffvl.attribute1;

        CURSOR stg_rec_cur IS
              SELECT stg.ROWID row_id, stg.*
                FROM xxdo.xxd_cm_calc_percnt_stg_t stg
               WHERE request_id = gn_request_id
            ORDER BY brand;

        --TYPE stg_rec_type stg_rec_cur%rowtype;
        v_stg_rec                     stg_rec_cur%ROWTYPE;

        CURSOR lkp_cur IS
              SELECT ffvl.attribute1 inv_org_id, ffvl.attribute4
                FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
               WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                     AND fvs.flex_value_set_name = 'XXD_CM_OH_CALCULATE_VS'
                     AND ffvl.enabled_flag = 'Y'
                     AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                         TRUNC (SYSDATE)
                     AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                         TRUNC (SYSDATE)
                     AND UPPER (ffvl.attribute5) = 'DOMESTIC'
            ORDER BY ffvl.attribute1;

        ln_hyp_total                  NUMBER := 0;
        ln_int_org_fob_tot            NUMBER := 0;
        ln_int_org_fob_pcnet          NUMBER := 0;
        ln_int_fob_pcnet_tot          NUMBER := 0;
        ln_hyp_int_fob_tot_diff       NUMBER := 0;
        ln_hyp_int_fob_avg            NUMBER := 0;
        ln_total_forecast_value       NUMBER := 0;
        ln_total_forecast_value_tot   NUMBER := 0;
        ln_forecast_global_value      NUMBER := 0;
        ln_total_forecast_percnt      NUMBER := 0;
        ln_oh_nonduty                 NUMBER := 0;
        ln_dom_org_fob_sum            NUMBER := 0;
        v_report_date                 VARCHAR2 (100);
        lv_sql                        VARCHAR2 (32000);
        -- lv_sql                            CLOB;
        lv_where_clause               VARCHAR2 (32000);
        lv_start_date                 VARCHAR2 (100);
        lv_end_date                   VARCHAR2 (100);
        ln_updt_cnt                   NUMBER := 0;
        ln_total                      NUMBER := 0;
        lv_organization_code          VARCHAR2 (1000);
    BEGIN
        write_log_prc (
               'Main Process Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

                     /*IF pv_date = 'REQUESTED_XF_DATE'
THEN
    lv_where_clause := 'NVL (requested_xf_date, promise_expected_receipt_date)';
ELSIF pv_date = 'CONFIRMED_XF_DATE'
THEN
    lv_where_clause := 'NVL (confirmed_xf_date, promise_expected_receipt_date)';
ELSIF pv_date = 'XF_SHIPMENT_DATE'
THEN
    lv_where_clause := 'NVL (xf_shipment_date, promise_expected_receipt_date)';
ELSIF pv_date = 'INTRANSIT_RECEIPT_DATE'
THEN
    lv_where_clause := 'NVL (intransit_receipt_date, promise_expected_receipt_date)';
ELSE
    lv_where_clause := 'promise_expected_receipt_date';
END IF;*/

        IF pv_date = 'REQUESTED_XF_DATE'
        THEN
            lv_where_clause   :=
                   '(('''
                || pv_start_date
                || ''' IS NOT NULL AND NVL (TO_DATE (requested_xf_date, ''RRRR/MM/DD HH24:MI:SS''), promise_expected_receipt_date) BETWEEN TO_DATE ('''
                || pv_start_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'') AND TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS''))
											                     OR ('''
                || pv_start_date
                || ''' IS NULL AND NVL (requested_xf_date, promise_expected_receipt_date) <= TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'')))';
        ELSIF pv_date = 'CONFIRMED_XF_DATE'
        THEN
            lv_where_clause   :=
                   '(('''
                || pv_start_date
                || ''' IS NOT NULL AND NVL (TO_DATE (confirmed_xf_date, ''RRRR/MM/DD HH24:MI:SS''), promise_expected_receipt_date) BETWEEN TO_DATE ('''
                || pv_start_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'') AND TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS''))
											                     OR ('''
                || pv_start_date
                || ''' IS NULL AND NVL (confirmed_xf_date, promise_expected_receipt_date) <= TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'')))';
        ELSIF pv_date = 'XF_SHIPMENT_DATE'
        THEN
            lv_where_clause   :=
                   '(('''
                || pv_start_date
                || ''' IS NOT NULL AND NVL (TO_DATE (xf_shipment_date, ''RRRR/MM/DD HH24:MI:SS''), promise_expected_receipt_date) BETWEEN TO_DATE ('''
                || pv_start_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'') AND TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS''))
											                     OR ('''
                || pv_start_date
                || ''' IS NULL AND NVL (xf_shipment_date, promise_expected_receipt_date) <= TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'')))';
        ELSIF pv_date = 'INTRANSIT_RECEIPT_DATE'
        THEN
            lv_where_clause   :=
                   '(('''
                || pv_start_date
                || ''' IS NOT NULL AND NVL (intransit_receipt_date, promise_expected_receipt_date) BETWEEN TO_DATE ('''
                || pv_start_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'') AND TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS''))
											                     OR ('''
                || pv_start_date
                || ''' IS NULL AND NVL (intransit_receipt_date, promise_expected_receipt_date) <= TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'')))';
        ELSIF pv_date = 'PROMISE_EXPECTED_RECEIPT_DATE'
        THEN
            lv_where_clause   :=
                   '(('''
                || pv_start_date
                || ''' IS NOT NULL AND promise_expected_receipt_date BETWEEN TO_DATE ('''
                || pv_start_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'') AND TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS''))
											                     OR ('''
                || pv_start_date
                || ''' IS NULL AND promise_expected_receipt_date <= TO_DATE ('''
                || pv_end_date
                || ''', ''RRRR/MM/DD HH24:MI:SS'')))';
        END IF;

        BEGIN
            ln_hyp_total   := 0;

            SELECT SUM (budget_amount) * ((NVL (pv_expense_adj_percnt, 0) + 100) / 100) + NVL (pv_expense_adj_amt, 0)
              INTO ln_hyp_total
              FROM xxdo.xxd_hyp_inb_forecast_stg_t
             -- WHERE period_start_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')
             WHERE     1 = 1
                   AND ((pv_start_date IS NOT NULL AND period_start_date BETWEEN TO_DATE (pv_start_date, 'RRRR/MM/DD HH24:MI:SS') AND TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')) OR (pv_start_date IS NULL AND period_start_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')))
                   AND active_flag = 'Y'
                   AND consumed_flag = 'N';

            write_log_prc ('Hyperion Total-' || ln_hyp_total);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc ('Unable to derive Hyperion Total-' || SQLERRM);
                ln_hyp_total   := 0;
        END;

        BEGIN
            ln_int_org_fob_tot   := 0;
                                   /*SELECT SUM (fob_value_in_usd)
 INTO ln_int_org_fob_tot
 FROM xxdo.xxd_po_proj_forecast_stg_t
-- WHERE promise_expected_receipt_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')
  AND calculated_flag = 'N'
  AND override_status = 'NEW';*/

            lv_sql               := NULL;
            lv_sql               := 'SELECT SUM (fob_value_in_usd) 
																										FROM xxdo.xxd_po_proj_forecast_stg_t
																									 WHERE 1 = 1
																										 AND ' || lv_where_clause || '
																											AND calculated_flag = ''N''
																											AND override_status = ''NEW''';


            EXECUTE IMMEDIATE lv_sql
                INTO ln_int_org_fob_tot;

            write_log_prc ('PO ForeCast Total-' || ln_int_org_fob_tot);
        -- write_log_prc (lv_sql);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Unable to derive PO ForeCast Total-' || SQLERRM);
                ln_int_org_fob_tot   := 0;
        -- write_log_prc (lv_sql);
        END;

        IF NVL (ln_hyp_total, 0) = 0 OR NVL (ln_int_org_fob_tot, 0) = 0
        THEN
            write_log_prc (
                   'Report Cannot be Generated Since Hyperion Forecast Data/PO ForeCast Data are already Consumed till the Period Date:-'
                || pv_end_date);
        ELSIF NVL (ln_hyp_total, 0) > 0 AND NVL (ln_int_org_fob_tot, 0) > 0
        THEN
            BEGIN
                FOR i IN oh_calc_int_cur
                LOOP
                    lv_organization_code   := NULL;

                    BEGIN
                        SELECT organization_code
                          INTO lv_organization_code
                          FROM apps.org_organization_definitions
                         WHERE organization_id = i.inv_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log_prc (
                                   'Unable to derive organization_code for the Inv Org-'
                                || i.inv_org_id
                                || '-'
                                || SQLERRM);
                            lv_organization_code   := NULL;
                    END;


                    write_log_prc (
                           'International Organization-'
                        || i.inv_org_id
                        || '-'
                        || lv_organization_code);

                    BEGIN
                                                                          /*SELECT SUM (fob_value_in_usd)
 INTO ln_int_org_fob_tot
 FROM xxdo.xxd_po_proj_forecast_stg_t
WHERE promise_expected_receipt_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')
  AND calculated_flag = 'N'
  AND override_status = 'NEW'
  AND destination_org = (SELECT organization_name
                           FROM apps.org_organization_definitions
                          WHERE organization_id = i.inv_org_id);*/
                        ln_int_org_fob_tot   := 0;
                        lv_sql               := NULL;
                        lv_sql               :=
                               'SELECT SUM (fob_value_in_usd) * ((NVL ('
                            || pv_int_adj_percnt
                            || ', 0) + 100)/100)
																																				FROM xxdo.xxd_po_proj_forecast_stg_t
																																			WHERE 1 = 1
																																					AND '
                            || lv_where_clause
                            || '
																																					AND calculated_flag = ''N''
																																					AND override_status = ''NEW''
																																					AND destination_org = (SELECT organization_name
																																																														FROM apps.org_organization_definitions
																																																													WHERE organization_id = '
                            || i.inv_org_id
                            || ')';

                        -- AND '||lv_where_clause||' <= TO_DATE ('''||pv_end_date||''', ''RRRR/MM/DD HH24:MI:SS'')

                        -- write_log_prc (lv_sql);
                        EXECUTE IMMEDIATE lv_sql
                            INTO ln_int_org_fob_tot;

                        write_log_prc (
                               'International Org wise FOB Total-'
                            || ln_int_org_fob_tot);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log_prc (
                                   'Unable to derive PO Forecast Total for the International Inv Org-'
                                || i.inv_org_id
                                || '-'
                                || SQLERRM);
                            ln_int_org_fob_tot   := 0;
                    -- write_log_prc (lv_sql);
                    END;

                    ln_int_org_fob_pcnet   :=
                        (i.oh_percent / 100) * ln_int_org_fob_tot;

                    write_log_prc (
                        'International Org OH percentage-' || i.oh_percent);
                    write_log_prc (
                           i.inv_org_id
                        || ' Org FOB Percentage-'
                        || ln_int_org_fob_pcnet);
                    write_log_prc (
                        '---------------------------------------------------------');
                    ln_int_fob_pcnet_tot   :=
                          NVL (ln_int_fob_pcnet_tot, 0)
                        + NVL (ln_int_org_fob_pcnet, 0);
                END LOOP;

                write_log_prc (
                       'International FOB Percentage Total-'
                    || ln_int_fob_pcnet_tot);
                ln_hyp_int_fob_tot_diff   :=
                    ln_hyp_total - ln_int_fob_pcnet_tot;
                write_log_prc (
                       'Difference of Hyp Total, FOB percent Total-'
                    || ln_hyp_int_fob_tot_diff);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           SQLERRM
                        || '-Excepion occurred while calculate the FOB Percentage Total');
            END;

            BEGIN
                ln_dom_org_fob_sum   := 0;
                                            /*SELECT SUM (fob_value_in_usd)
 INTO ln_dom_org_fob_sum
 FROM xxdo.xxd_po_proj_forecast_stg_t
WHERE promise_expected_receipt_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')
  AND calculated_flag = 'N'
  AND override_status = 'NEW'
  AND destination_org IN (SELECT odd.organization_name
                            FROM apps.fnd_flex_value_sets  fvs,
                                 apps.fnd_flex_values_vl   ffvl,
                                 apps.org_organization_definitions odd
                           WHERE fvs.flex_value_set_id = ffvl.flex_value_set_id
                             AND fvs.flex_value_set_name = 'XXD_CM_OH_CALCULATE_VS'
                             AND NVL (TRUNC (ffvl.start_date_active),TRUNC (SYSDATE)) <=TRUNC (SYSDATE)
                             AND NVL (TRUNC (ffvl.end_date_active),TRUNC (SYSDATE)) >=TRUNC (SYSDATE)
                             AND ffvl.enabled_flag = 'Y'
                             AND ffvl.attribute5 = 'Domestic'
                             AND ffvl.attribute1 = odd.organization_id);*/

                lv_sql               := NULL;
                lv_sql               :=
                       'SELECT SUM (fob_value_in_usd) * ((NVL ('
                    || pv_dom_adj_percnt
                    || ', 0) + 100)/100)
																											FROM xxdo.xxd_po_proj_forecast_stg_t
																										WHERE 1 = 1
																												AND '
                    || lv_where_clause
                    || '
																												AND calculated_flag = ''N''
																												AND override_status = ''NEW''
																												AND destination_org IN (SELECT odd.organization_name
																																																						FROM apps.fnd_flex_value_sets  fvs,
																																																											apps.fnd_flex_values_vl   ffvl,
																																																											apps.org_organization_definitions odd
																																																					WHERE fvs.flex_value_set_id = ffvl.flex_value_set_id
																																																							AND fvs.flex_value_set_name = ''XXD_CM_OH_CALCULATE_VS''
																																																							AND NVL (TRUNC (ffvl.start_date_active),TRUNC (SYSDATE)) <=TRUNC (SYSDATE)
																																																							AND NVL (TRUNC (ffvl.end_date_active),TRUNC (SYSDATE)) >=TRUNC (SYSDATE)
																																																							AND ffvl.enabled_flag = ''Y''
																																																							AND ffvl.attribute5 = ''Domestic''
																																																							AND ffvl.attribute1 = odd.organization_id)';

                -- AND '||lv_where_clause||' <= TO_DATE ('''||pv_end_date||''', ''RRRR/MM/DD HH24:MI:SS'')

                -- write_log_prc (lv_sql);
                EXECUTE IMMEDIATE lv_sql
                    INTO ln_dom_org_fob_sum;

                write_log_prc ('Domestic Org FOB Sum-' || ln_dom_org_fob_sum);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           'Unable to derive PO Forecast Total for Domestic Org-'
                        || SQLERRM);
                    ln_dom_org_fob_sum   := 0;
            -- write_log_prc (lv_sql);
            END;

            -- ln_hyp_int_fob_avg := ln_hyp_int_fob_tot_diff / ln_dom_org_fob_sum;
            -- write_log_prc ('Hyperion FOB Average-'||ln_hyp_int_fob_avg);

            BEGIN
                ln_hyp_int_fob_avg   := 0;

                lv_sql               := NULL;
                lv_sql               :=
                       'SELECT SUM (quantity) * ((NVL ('
                    || pv_dom_adj_percnt
                    || ', 0) + 100)/100)
																											FROM xxdo.xxd_po_proj_forecast_stg_t
																										WHERE 1 = 1
																												AND '
                    || lv_where_clause
                    || '
																												AND calculated_flag = ''N''
																												AND override_status = ''NEW''
																												AND destination_org IN (SELECT odd.organization_name
																																																						FROM apps.fnd_flex_value_sets  fvs,
																																																											apps.fnd_flex_values_vl   ffvl,
																																																											apps.org_organization_definitions odd
																																																					WHERE fvs.flex_value_set_id = ffvl.flex_value_set_id
																																																							AND fvs.flex_value_set_name = ''XXD_CM_OH_CALCULATE_VS''
																																																							AND NVL (TRUNC (ffvl.start_date_active),TRUNC (SYSDATE)) <=TRUNC (SYSDATE)
																																																							AND NVL (TRUNC (ffvl.end_date_active),TRUNC (SYSDATE)) >=TRUNC (SYSDATE)
																																																							AND ffvl.enabled_flag = ''Y''
																																																							AND ffvl.attribute5 = ''Domestic''
																																																							AND ffvl.attribute1 = odd.organization_id)';

                -- AND '||lv_where_clause||' <= TO_DATE ('''||pv_end_date||''', ''RRRR/MM/DD HH24:MI:SS'')

                -- write_log_prc (lv_sql);
                EXECUTE IMMEDIATE lv_sql
                    INTO ln_hyp_int_fob_avg;

                write_log_prc (
                    'Domestic Org Quantity Sum-' || ln_hyp_int_fob_avg);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           'Unable to derive PO Forecast Quantity Total for Domestic Org-'
                        || SQLERRM);
                    ln_hyp_int_fob_avg   := 0;
            -- write_log_prc (lv_sql);
            END;

            BEGIN
                /*INSERT INTO xxdo.xxd_cm_calc_percnt_stg_t ( brand
              ,forecast_amount
              ,forecast_qty
              ,rec_status
              ,error_msg
              ,created_by
              ,creation_date
              ,last_updated_by
              ,last_update_date
              ,request_id)
              SELECT brand
                    ,SUM (fob_value_in_usd)
                    ,SUM (quantity)
                    ,'N'
                    ,NULL
                    ,gn_user_id
                    ,TRUNC (SYSDATE)
                    ,gn_user_id
                    ,TRUNC (SYSDATE)
                    ,gn_request_id
                FROM xxdo.xxd_po_proj_forecast_stg_t
               WHERE promise_expected_receipt_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')                              -- Creation Date need to change
                 AND calculated_flag = 'N'
                 AND override_status = 'NEW'
                 AND destination_org IN (SELECT odd.organization_name
                                           FROM apps.fnd_flex_value_sets fvs,
                                                apps.fnd_flex_values_vl ffvl,
                                                apps.org_organization_definitions odd
                                          WHERE fvs.flex_value_set_id = ffvl.flex_value_set_id
                                            AND fvs.flex_value_set_name = 'XXD_CM_OH_CALCULATE_VS'
                                            AND NVL (TRUNC (ffvl.start_date_active),TRUNC (SYSDATE)) <=TRUNC (SYSDATE)
                                            AND NVL (TRUNC (ffvl.end_date_active),TRUNC (SYSDATE)) >=TRUNC (SYSDATE)
                                            AND ffvl.enabled_flag = 'Y'
                                            AND ffvl.attribute5 = 'Domestic'
                                            AND ffvl.attribute1 = odd.organization_id)
            GROUP BY brand
                    ,'N'
                    ,gn_user_id
                    ,SYSDATE
                    ,gn_request_id;*/
                lv_sql   := NULL;
                lv_sql   :=
                       'INSERT INTO xxdo.xxd_cm_calc_percnt_stg_t ( brand
																																																																					,forecast_amount
																																																																					,forecast_qty
																																																																					,rec_status
																																																																					,created_by
																																																																					,creation_date
																																																																					,last_updated_by
																																																																					,last_update_date
																																																																					,request_id)
																																																																					SELECT brand
																																																																											,SUM (fob_value_in_usd) * ((NVL ('
                    || pv_dom_adj_percnt
                    || ', 0) + 100)/100)
																																																																											,SUM (quantity) * ((NVL ('
                    || pv_dom_adj_percnt
                    || ', 0) + 100)/100)
																																																																											,''N''
																																																																											,'
                    || gn_user_id
                    || '
																																																																											,TRUNC (SYSDATE)
																																																																											,'
                    || gn_user_id
                    || '
																																																																											,TRUNC (SYSDATE)
																																																																											,'
                    || gn_request_id
                    || '
																																																																							FROM xxdo.xxd_po_proj_forecast_stg_t
																																																																						WHERE 1 = 1
																																																																						  AND '
                    || lv_where_clause
                    || '
																																																																								AND calculated_flag = ''N''
																																																																								AND override_status = ''NEW''
																																																																								AND destination_org IN (SELECT odd.organization_name
																																																																																																		FROM apps.fnd_flex_value_sets fvs,
																																																																																																							apps.fnd_flex_values_vl ffvl,
																																																																																																							apps.org_organization_definitions odd
																																																																																																	WHERE fvs.flex_value_set_id = ffvl.flex_value_set_id
																																																																																																			AND fvs.flex_value_set_name = ''XXD_CM_OH_CALCULATE_VS''
																																																																																																			AND NVL (TRUNC (ffvl.start_date_active),TRUNC (SYSDATE)) <=TRUNC (SYSDATE)
																																																																																																			AND NVL (TRUNC (ffvl.end_date_active),TRUNC (SYSDATE)) >=TRUNC (SYSDATE)
																																																																																																			AND ffvl.enabled_flag = ''Y''
																																																																																																			AND ffvl.attribute5 = ''Domestic''
																																																																																																			AND ffvl.attribute1 = odd.organization_id)
																																																																			GROUP BY brand';

                -- write_log_prc (lv_sql);
                EXECUTE IMMEDIATE lv_sql;

                write_log_prc (
                    SQL%ROWCOUNT || ' Records Inserted into Stg Table');
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           SQLERRM
                        || '-Excepion occurred while inserting data into Stg table');
            -- write_log_prc (lv_sql);
            END;

                              /*BEGIN

     FOR i in stg_rec_cur
     LOOP
         ln_total_forecast_value := 0;
         ln_total_forecast_value := i.forecast_amount * i.forecast_qty;
         write_log_prc ('Domestic Brand FOB multiply Quantity-'||ln_total_forecast_value);

         BEGIN
              UPDATE xxdo.xxd_cm_calc_percnt_stg_t
                 SET total_forecast_value = ln_total_forecast_value
               WHERE rowid = i.row_id
                 AND request_id = gn_request_id;

              write_log_prc (SQL%ROWCOUNT||' Records updated with brand_fob_mul_qty for each Rowid');
         EXCEPTION
              WHEN OTHERS
              THEN
                  write_log_prc (SQLERRM||'-Excepion occurred while Updating data into Stg table');
         END;
     END LOOP;
     COMMIT;

EXCEPTION
     WHEN OTHERS
     THEN
         write_log_prc (SQLERRM||'-Excepion occurred while calculate the forecast value');
END;

BEGIN
     ln_total_forecast_value_tot := 0;

     SELECT SUM (total_forecast_value)
       INTO ln_total_forecast_value_tot
       FROM xxdo.xxd_cm_calc_percnt_stg_t
      WHERE request_id = gn_request_id;

     write_log_prc ('FOB multiply Quantity Total-'||ln_total_forecast_value_tot);

EXCEPTION
     WHEN OTHERS
     THEN
         write_log_prc (SQLERRM||'-Excepion occurred while Retriving Sum of total_forecast_value');
         ln_total_forecast_value_tot := 0;
END;*/

            FOR i IN stg_rec_cur
            LOOP
                ln_total_forecast_percnt   := 0;
                ln_forecast_global_value   := 0;

                write_log_prc (
                    '---------------------------------------------------------');
                -- ln_total_forecast_percnt := i.total_forecast_value / ln_total_forecast_value_tot;
                ln_total_forecast_percnt   :=
                    i.forecast_amount / ln_dom_org_fob_sum;
                write_log_prc (
                    'Total ForeCast Percentage -' || ln_total_forecast_percnt);
                ln_forecast_global_value   :=
                    ln_total_forecast_percnt * ln_hyp_int_fob_tot_diff;
                write_log_prc (
                    'Forecast Global Value -' || ln_forecast_global_value);
                -- ln_oh_nonduty := ln_forecast_global_value / i.forecast_amount;
                ln_oh_nonduty              :=
                    ln_forecast_global_value / i.forecast_qty;
                write_log_prc ('OH NonDuty-' || ln_oh_nonduty);

                BEGIN
                    UPDATE xxdo.xxd_cm_calc_percnt_stg_t
                       SET total_forecast_percnt = ln_total_forecast_percnt, forecast_global_value = ln_forecast_global_value, oh_nonduty = ln_oh_nonduty
                     WHERE ROWID = i.row_id AND request_id = gn_request_id;

                    write_log_prc (
                           SQL%ROWCOUNT
                        || ' Records updated with total_forecast_percnt, forecast_global_value, oh_nonduty for the Brand - '
                        || i.brand);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                               SQLERRM
                            || '-Excepion occurred while Updating data into Stg table with total_forecast_percnt, forecast_global_value, oh_nonduty');
                END;
            END LOOP;

            COMMIT;

            -- Generate XML output for run mode : Report, Review
            fnd_file.put_line (
                fnd_file.LOG,
                   'XML Output starts'
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

            BEGIN
                BEGIN
                    SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                      INTO v_report_date
                      FROM sys.DUAL;
                END;

                lv_start_date   :=
                    TO_CHAR (
                        TO_DATE (pv_start_date, 'RRRR/MM/DD HH24:MI:SS'),
                        'DD-MON-RRRR');
                lv_end_date   :=
                    TO_CHAR (TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS'),
                             'DD-MON-RRRR');

                apps.fnd_file.put_line (
                    fnd_file.output,
                    '<?xml version="1.0" encoding="US-ASCII"?>');
                apps.fnd_file.put_line (apps.fnd_file.output, '<MAIN>');
                apps.fnd_file.put_line (fnd_file.output, '<OUTPUT>');

                apps.fnd_file.put_line (apps.fnd_file.output, '<PARAMGRP>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<DC>'
                    || DBMS_XMLGEN.CONVERT ('DECKERS CORPORATION')
                    || '</DC>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<RN>'
                    || DBMS_XMLGEN.CONVERT (
                           'Report Name : Deckers CM Calculate OH Percentage')
                    || '</RN>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<RD>'
                    || DBMS_XMLGEN.CONVERT (
                           'Report Date - : ' || v_report_date)
                    || '</RD>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<SD>'
                    || DBMS_XMLGEN.CONVERT ('Select Date : ' || pv_date)
                    || '</SD>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<PSD>'
                    || DBMS_XMLGEN.CONVERT ('Start Date : ' || lv_start_date)
                    || '</PSD>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<PED>'
                    || DBMS_XMLGEN.CONVERT ('End Date : ' || lv_end_date)
                    || '</PED>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<MODE>'
                    || DBMS_XMLGEN.CONVERT ('Mode : ' || pv_mode)
                    || '</MODE>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<INTP>'
                    || DBMS_XMLGEN.CONVERT (
                           'International Percent% : ' || pv_int_adj_percnt)
                    || '</INTP>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<DOMP>'
                    || DBMS_XMLGEN.CONVERT (
                           'Domestic Percent% : ' || pv_dom_adj_percnt)
                    || '</DOMP>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<EXPP>'
                    || DBMS_XMLGEN.CONVERT (
                           'Expense Percent% : ' || pv_expense_adj_percnt)
                    || '</EXPP>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<EXPA>'
                    || DBMS_XMLGEN.CONVERT (
                           'Expense Amount$ : ' || pv_expense_adj_amt)
                    || '</EXPA>');
                -- apps.fnd_file.put_line (apps.fnd_file.output,'<SM>'||dbms_xmlgen.convert('Send Mail : '||pv_send_mail)||'</SM>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<INT>'
                    || DBMS_XMLGEN.CONVERT ('International')
                    || '</INT>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                    '<DOM>' || DBMS_XMLGEN.CONVERT ('Domestic') || '</DOM>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<HYPTOT>'
                    || DBMS_XMLGEN.CONVERT (ln_hyp_total)
                    || '</HYPTOT>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<FCTOTINT>'
                    || DBMS_XMLGEN.CONVERT (ln_int_fob_pcnet_tot)
                    || '</FCTOTINT>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<DIFF>'
                    || DBMS_XMLGEN.CONVERT (ln_hyp_int_fob_tot_diff)
                    || '</DIFF>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<SUM>'
                    || DBMS_XMLGEN.CONVERT (ln_dom_org_fob_sum)
                    || '</SUM>');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       '<SUMPERCNT>'
                    || DBMS_XMLGEN.CONVERT (ln_hyp_int_fob_avg)
                    || '</SUMPERCNT>');
                apps.fnd_file.put_line (apps.fnd_file.output, '</PARAMGRP>');

                OPEN stg_rec_cur;

                LOOP
                    FETCH stg_rec_cur INTO v_stg_rec;

                    EXIT WHEN stg_rec_cur%NOTFOUND;

                    fnd_file.put_line (fnd_file.output, '<ROW>');
                    fnd_file.put_line (
                        fnd_file.output,
                           '<BRAND>'
                        || DBMS_XMLGEN.CONVERT (v_stg_rec.brand)
                        || '</BRAND>');
                    fnd_file.put_line (
                        fnd_file.output,
                           '<FA>'
                        || DBMS_XMLGEN.CONVERT (v_stg_rec.forecast_amount)
                        || '</FA>');
                    fnd_file.put_line (
                        fnd_file.output,
                           '<FQ>'
                        || DBMS_XMLGEN.CONVERT (v_stg_rec.forecast_qty)
                        || '</FQ>');
                    -- fnd_file.put_line(fnd_file.output,'<TFV>'||dbms_xmlgen.convert(v_stg_rec.total_forecast_value)||'</TFV>');
                    fnd_file.put_line (
                        fnd_file.output,
                           '<TFP>'
                        || DBMS_XMLGEN.CONVERT (
                               v_stg_rec.total_forecast_percnt)
                        || '</TFP>');
                    fnd_file.put_line (
                        fnd_file.output,
                           '<FGV>'
                        || DBMS_XMLGEN.CONVERT (
                               v_stg_rec.forecast_global_value)
                        || '</FGV>');
                    fnd_file.put_line (
                        fnd_file.output,
                           '<OHND>'
                        || DBMS_XMLGEN.CONVERT (v_stg_rec.oh_nonduty)
                        || '</OHND>');
                    fnd_file.put_line (fnd_file.output, '</ROW>');
                END LOOP;

                CLOSE stg_rec_cur;


                fnd_file.put_line (fnd_file.output, '</OUTPUT>');
                fnd_file.put_line (fnd_file.output, '</MAIN>');
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exception while generate the XML:-' || SQLERRM);
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'XML Output Ends'
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

            IF pv_mode = 'Calculate'
            THEN
                BEGIN
                    FOR i IN stg_rec_cur
                    LOOP
                        FOR j IN lkp_cur
                        LOOP
                            IF UPPER (j.attribute4) = 'YES'
                            THEN
                                -- BEGIN
                                lv_organization_code   := NULL;

                                BEGIN
                                    SELECT organization_code
                                      INTO lv_organization_code
                                      FROM apps.org_organization_definitions
                                     WHERE organization_id = j.inv_org_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        write_log_prc (
                                               'Unable to derive organization_code for the Inv Org-'
                                            || j.inv_org_id
                                            || '-'
                                            || SQLERRM);
                                        lv_organization_code   := NULL;
                                END;

                                UPDATE apps.fnd_flex_values_vl ffvl
                                   SET ffvl.attribute6 = ROUND (i.oh_nonduty * NVL (ffvl.attribute15, 1), 2), ffvl.attribute14 = TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'), ffvl.last_update_date = TRUNC (SYSDATE),
                                       ffvl.last_updated_by = gn_user_id
                                 WHERE     NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y'
                                       AND ffvl.attribute2 = i.brand
                                       AND ffvl.attribute8 = j.inv_org_id
                                       AND ffvl.flex_value_set_id =
                                           (SELECT flex_value_set_id
                                              FROM apps.fnd_flex_value_sets
                                             WHERE flex_value_set_name =
                                                   'XXD_CST_OH_ELEMENTS_VS');

                                write_log_prc (
                                       SQL%ROWCOUNT
                                    || ' Records Updated in XXD_CST_OH_ELEMENTS_VS with OH NON DUTY for the Org-'
                                    || j.inv_org_id
                                    || '-'
                                    || lv_organization_code
                                    || ' and Brand-'
                                    || i.brand);

                                ln_updt_cnt            := 0;

                                UPDATE xxdo.xxd_cst_duty_ele_upld_stg_t
                                   SET rec_status = 'N'-- ,oh_nonduty = ROUND (i.oh_nonduty, 10)
                                                       , last_update_date = TRUNC (SYSDATE), last_updated_by = gn_user_id
                                 WHERE     active_flag = 'Y'
                                       AND inventory_org_id = j.inv_org_id
                                       AND additional_field1 = i.brand;

                                write_log_prc (
                                       SQL%ROWCOUNT
                                    || ' Records Updated in xxdo.xxd_cst_duty_ele_upld_stg_t with OH NON DUTY for the Org-'
                                    || j.inv_org_id
                                    || '-'
                                    || lv_organization_code
                                    || ' and Brand-'
                                    || i.brand);
                                ln_updt_cnt            := SQL%ROWCOUNT;
                                ln_total               :=
                                    ln_total + ln_updt_cnt;
                            -- COMMIT;

                            -- EXCEPTION
                            -- WHEN OTHERS
                            -- THEN
                            -- write_log_prc (SQLERRM||'Excepion occurred while Updating OH NONDUTY');
                            -- END;

                            END IF;
                        END LOOP;
                    END LOOP;

                    write_log_prc (
                           'Total Number of Records Updated in xxdo.xxd_cst_duty_ele_upld_stg_t Stg Table :'
                        || ln_total);

                    UPDATE xxdo.xxd_hyp_inb_forecast_stg_t
                       SET consumed_flag = 'Y', last_update_date = TRUNC (SYSDATE), last_updated_by = gn_user_id
                     -- WHERE period_start_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')
                     WHERE     1 = 1
                           AND ((pv_start_date IS NOT NULL AND period_start_date BETWEEN TO_DATE (pv_start_date, 'RRRR/MM/DD HH24:MI:SS') AND TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')) OR (pv_start_date IS NULL AND period_start_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')))
                           AND active_flag = 'Y'
                           AND consumed_flag = 'N';

                    write_log_prc (
                           SQL%ROWCOUNT
                        || ' Records Updated in xxdo.xxd_hyp_inb_forecast_stg_t with consumed_flag Y');

                                                        /*UPDATE xxdo.xxd_po_proj_forecast_stg_t
  SET calculated_flag = 'Y'
WHERE promise_expected_receipt_date <= TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS')           -- creation need to change
  AND calculated_flag = 'N'
  AND override_status = 'NEW'; */

                    lv_sql   := NULL;
                    lv_sql   :=
                           'UPDATE xxdo.xxd_po_proj_forecast_stg_t
																																SET calculated_flag = ''Y''
																																			,last_update_date = TRUNC (SYSDATE)
																																			,last_updated_by = '
                        || gn_user_id
                        || '
																														WHERE 1 = 1
																														  AND '
                        || lv_where_clause
                        || '
																																AND calculated_flag = ''N''
																																AND override_status = ''NEW''';

                    -- AND '||lv_where_clause||' <= TO_DATE ('''||pv_end_date||''', ''RRRR/MM/DD HH24:MI:SS'')

                    -- write_log_prc (lv_sql);
                    EXECUTE IMMEDIATE lv_sql;

                    write_log_prc (
                           SQL%ROWCOUNT
                        || ' Records Updated in xxdo.xxd_po_proj_forecast_stg_t with calculated_flag Y');

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                            SQLERRM || '-Excepion occurred in Update block');
                        ROLLBACK;
                -- write_log_prc (lv_sql);
                END;
            END IF;
        END IF;                                       -- NVL (ln_hyp_total, 0)
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                SQLERRM || '-Excepion occurred in procedure main_prc');
    END main_prc;
END xxd_cm_calc_oh_percnt_pkg;
/
