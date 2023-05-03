--
-- XXD_RMS_ITEM_PUBLISH_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_RMS_ITEM_PUBLISH_PKG"
IS
    /**********************************************************************************************************
        file name    : XXD_RMS_ITEM_PUBLISH_PKG.pkb
                            created on   : 10-JUN-2017
                            created by   : INFOSYS
                            purpose      : package specification used for the following
                                                   1. Insert the Style/SKU/UPC creation and update message to staging table.
                                                   2. Insert the TAX creation and update message to staging table.
                        ****************************************************************************
                           Modification history:
                        *****************************************************************************
                              NAME:         XXD_RMS_ITEM_PUBLISH_PKG
                              PURPOSE:      MIAN PROCEDURE CONTROL_PROC
                              REVISIONS:
                              Version        Date        Author           Description
                              ---------  ----------  ---------------  ------------------------------------
                              1.0         06/03/2017     INFOSYS       1. Created this package body.
                        *********************************************************************
                        *********************************************************************/

    gn_userid               NUMBER := apps.fnd_global.user_id;
    gn_resp_id              NUMBER := apps.fnd_global.resp_id;
    gn_app_id               NUMBER := apps.fnd_global.prog_appl_id;
    gn_conc_request_id      NUMBER := apps.fnd_global.conc_request_id;
    g_num_login_id          NUMBER := fnd_global.login_id;
    gn_wsale_pricelist_id   NUMBER;
    gn_rtl_pricelist_id     NUMBER;
    gv_debug_enable         VARCHAR2 (10) := 'Y';
    gd_begin_date           DATE;
    gd_end_date             DATE;
    gn_master_orgid         NUMBER;
    gn_master_org_code      VARCHAR2 (200)
        := apps.fnd_profile.VALUE ('XXDO: ORGANIZATION CODE');

    /****************************************************************************
    * Procedure Name    : msg
    *
    * Description       : The purpose of this procedure is to display log
    *                     messages.
    *
    * INPUT Parameters  :
    *
    * OUTPUT Parameters :
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 6/28/2017     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE msg (pv_msg VARCHAR2, pn_level NUMBER:= 1000)
    IS
    BEGIN
        IF gv_debug_enable = 'Y'
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Error In msg procedure' || SQLERRM);
    END;

    /******************************************************************************
    * Procedure/Function Name  :  staging_table_purging
    *
    * Description              :  This procedure is used for purging staging tables
    * INPUT Parameters :
    * OUTPUT Parameters: pv_reterror
    *                    pv_retcode
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * date          author             Version  Description
    * ------------  -----------------  -------  ------------------------------
    * 10-NOV-2014     INFOSYS            1.0.1    Initial Version
    *************************************************************************/
    PROCEDURE staging_table_purging (pv_error    OUT VARCHAR2,
                                     pv_errode   OUT VARCHAR2)
    IS
        ln_err_days        NUMBER := 20;
        ln_purg_days       NUMBER := 60;
        ld_new_purg_date   DATE;
        ld_purg_date       DATE;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        ld_new_purg_date   :=
            TRUNC (
                  SYSDATE
                - NVL (apps.fnd_profile.VALUE ('XXD_RMS_ITEM_STG_PURG_DAYS'),
                       0));
        ld_purg_date   := TRUNC (SYSDATE - NVL (ln_purg_days, 60));

        --W.r.t Version 1.25
        BEGIN
            INSERT INTO xxdo.xxd_rms_item_master_stg_img xrmi (slno, servicetype, item_type, operation, inventory_item_id, organization_id, style, color, sze, item_number, brand, gender, item_status, item_description, scale_code_id, department, unit_weight, unit_height, unit_width, unit_length, dimension_uom_code, weight_uom_code, sub_division, CLASS, subclass, subclass_creation_date, subclass_update_date, subclass_updatedby, vertex_tax, vertex_creation_date, vertex_update_date, vertex_updatedby, us_region_cost, us_region_price, uk_region_cost, uk_region_price, ca_region_cost, ca_region_price, cn_region_cost, cn_region_price, jp_region_cost, jp_region_price, upc_value, process_status, transmission_date, creation_date, last_update_date, oracle_error_message, response_message, errorcode, fr_region_cost, fr_region_price, hk_region_cost, hk_region_price
                                                               , request_id)
                (SELECT slno, servicetype, item_type,
                        operation, inventory_item_id, organization_id,
                        style, color, sze,
                        item_number, brand, gender,
                        item_status, item_description, scale_code_id,
                        department, unit_weight, unit_height,
                        unit_width, unit_length, dimension_uom_code,
                        weight_uom_code, sub_division, CLASS,
                        subclass, subclass_creation_date, subclass_update_date,
                        subclass_updatedby, vertex_tax, vertex_creation_date,
                        vertex_update_date, vertex_updatedby, us_region_cost,
                        us_region_price, uk_region_cost, uk_region_price,
                        ca_region_cost, ca_region_price, cn_region_cost,
                        cn_region_price, jp_region_cost, jp_region_price,
                        upc_value, process_status, transmission_date,
                        creation_date, last_update_date, oracle_error_message,
                        response_message, errorcode, fr_region_cost,
                        fr_region_price, hk_region_cost, hk_region_price,
                        request_id
                   FROM xxdo.xxd_rms_item_master_stg xrm
                  WHERE     TRUNC (creation_date) <= ld_new_purg_date
                        AND NOT EXISTS
                                (SELECT 1
                                   FROM xxdo.xxd_rms_item_master_stg_img xrmi1
                                  WHERE xrm.slno = xrmi1.slno));
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    SUBSTR (
                           'Exception Occured while Inserting data from xxdo.xxd_rms_item_master_stg_img table:'
                        || SQLERRM,
                        1,
                        1999));
        END;

        COMMIT;


        BEGIN
            DELETE FROM xxdo.xxd_rms_item_master_stg
                  WHERE TRUNC (creation_date) <= ld_new_purg_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    SUBSTR (
                           'Exception Occured while deleting data from xxdo.xxd_rms_item_master_stg table:'
                        || SQLERRM,
                        1,
                        1999));
        END;


        BEGIN
            DELETE FROM xxdo.xxd_rms_item_master_stg_img
                  WHERE TRUNC (creation_date) <= ld_purg_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    SUBSTR (
                           'Exception Occured while deleting data from xxdo.xxd_rms_item_master_stg_img table:'
                        || SQLERRM,
                        1,
                        1999));
        --RAISE;
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error   :=
                SUBSTR (
                       'Exception Occured In staging_table_purging Proc'
                    || SQLERRM,
                    1,
                    1999);
    -- RAISE;
    END staging_table_purging;

    /****************************************************************************
    * Function Name    : Get_Last_Conc_Req_Run
    *
    * Description       : The purpose of this procedure is to display log
    *                     messages.
    *
    * INPUT Parameters  :
    *
    * OUTPUT Parameters :
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 5/28/2017     INFOSYS     1.0         Initial Version
    ***************************************************************************/

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
                   AND STATUS_CODE = 'C' --Only count completed tasks to not limit data to any erroring out.
                   AND ARGUMENT1 = 'NO'
                   AND ARGUMENT2 IS NULL
                   AND ARGUMENT3 IS NULL
                   AND ARGUMENT4 IS NULL
                   AND ARGUMENT5 IS NULL
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

    FUNCTION get_price_list_fun (p_region VARCHAR2)
        RETURN NUMBER
    IS
        l_price_list_id   NUMBER;
        l_unit_price      NUMBER;
    BEGIN
        SELECT tag
          INTO l_price_list_id
          FROM apps.fnd_lookup_values_vl lkup
         WHERE     lookup_type = 'XXDOINV_PRICE_LIST_NAME'
               AND lookup_code = p_region
               AND enabled_flag = 'Y'
               AND ROWNUM = 1;

        RETURN l_price_list_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0.01;
    END;

    PROCEDURE main_proc (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_reprocess IN VARCHAR2, pv_dummy IN VARCHAR2, pv_request_id IN VARCHAR2, pv_rundate IN VARCHAR2
                         , pv_style IN VARCHAR2)
    IS
        lv_wsdl_ip             VARCHAR2 (25);
        lv_wsdl_url            VARCHAR2 (4000);
        lv_namespace           VARCHAR2 (4000);
        lv_service             VARCHAR2 (4000);
        lv_port                VARCHAR2 (4000);
        lv_operation           VARCHAR2 (4000);
        lv_targetname          VARCHAR2 (4000);
        lx_xmltype_in          SYS.XMLTYPE;
        lx_xmltype_out         SYS.XMLTYPE;
        lc_return              CLOB;
        lv_item_mdflag         VARCHAR2 (1) := 'N';
        ln_itemstylecount      NUMBER;
        lv_op_mode             VARCHAR2 (60);
        lv_errmsg              VARCHAR2 (240);
        lv_style_status        VARCHAR2 (10) := 'N';
        lv_description         xxdoinv006_int.item_description%TYPE;
        lv_itemstatus          xxdoinv006_int.item_status%TYPE;
        lv_vertex              xxdoinv006_int.vertex_tax%TYPE;
        lv_subclass            xxdoinv006_int.subclass%TYPE;
        lv_counter             NUMBER := 0;
        lv_rec_count           NUMBER;
        lv_min_slno            NUMBER;
        lv_max_slno            NUMBER;
        lv_from_slno           NUMBER;
        lv_to_slno             NUMBER;
        lv_batch_count         NUMBER;
        ln_request_id          NUMBER := fnd_global.conc_request_id;
        lv_noof_items          NUMBER := 0;
        lv_item_cost           NUMBER := 0;
        lv_req_phase           VARCHAR2 (100);
        lv_req_status          VARCHAR2 (100);
        lv_req_dev_phase       VARCHAR2 (1000);
        lv_req_dev_status      VARCHAR2 (100);
        lv_req_message         VARCHAR2 (2400);
        lv_req_return_status   BOOLEAN;
        req_data               VARCHAR2 (20);
        lv_style_failed        VARCHAR2 (20);
        l_batch_size           NUMBER := 1;
        l_rundate              DATE := NULL;
        ld_rundate             DATE := NULL;
        ld_rundate2            DATE := NULL;
        ld_rundate1            VARCHAR2 (50);
        ln_styledupcount       NUMBER;
        l_style                VARCHAR2 (50);
        lv_next_style          VARCHAR2 (50) := 'XXXX';
        lv_error_message       VARCHAR2 (2000);
        lv_sku_status          VARCHAR2 (50);
        ln_itemskucount        VARCHAR2 (50);
        ln_itemupccount        VARCHAR2 (50);
        lv_upc_status          VARCHAR2 (50);
        lv_tax_status          VARCHAR2 (50);
        ln_tax_count           NUMBER;                           --Added 08/14
        ln_tax_exist_count     NUMBER;
        ln_tot_count           NUMBER;
        pv_error               VARCHAR2 (2000);
        pv_errode              VARCHAR2 (2000);
        ln_tot_records         NUMBER;
        ln_records             NUMBER;

        CURSOR c_tax IS
            SELECT msib.inventory_item_id, msib.organization_id, msib.style_number style,
                   msib.color_code color, msib.item_size sze, msib.inventory_item_status_code item_status,
                   msib.item_description description, msib.size_scale_id scale_code_id, mc1.segment1 vertex_tax,
                   msib.item_number, msib.brand
              FROM mtl_categories_b mc, mtl_category_sets mcs, mtl_item_categories mic,
                   apps.xxd_common_items_v msib, mtl_item_categories mic1, mtl_categories mc1,
                   mtl_category_sets mcs1, apps.mtl_parameters mp, fnd_lookup_values_vl lkp
             WHERE     1 = 1
                   AND mic.inventory_item_id = msib.inventory_item_id
                   AND mic.organization_id = msib.organization_id
                   AND mc.structure_id = mcs.structure_id
                   AND mic.category_id = mc.category_id
                   AND lkp.lookup_type = 'XXD_RMS_ITEM_STATUS'
                   AND meaning = msib.inventory_item_status_code
                   AND lkp.enabled_flag = 'Y'
                   AND mic.category_set_id = mcs.category_set_id
                   AND mp.organization_id = msib.organization_id
                   AND mp.master_organization_id = msib.organization_id
                   AND msib.inventory_item_id = mic1.inventory_item_id
                   AND msib.organization_id = mic1.organization_id
                   AND mic1.category_set_id = mcs1.category_set_id
                   AND mic1.category_id = mc1.category_id
                   AND mc1.structure_id = mcs1.structure_id
                   AND msib.style_number = NVL (pv_style, msib.style_number)
                   AND mcs1.category_set_name = 'Tax Class'
                   AND mic1.last_update_date >=
                       NVL (TO_DATE (ld_rundate1, 'DD-MON-YYYY HH24:MI:SS'),
                            mic1.last_update_date)
                   AND mcs.category_set_name = 'OM Sales Category'
                   AND NVL (msib.item_type, 'X') NOT IN ('SAMPLE', 'GENERIC')
                   AND TRUNC (mic1.last_update_date) =
                       NVL (ld_rundate2, TRUNC (mic1.last_update_date))
                   AND msib.size_scale_id IS NOT NULL
                   AND msib.upc_code IS NOT NULL
                   --AND xxdoinv006_pkg.get_dept_num_f (msib.inventory_item_id,msib.organization_id) IS NOT NULL
                   AND msib.style_number NOT IN
                           (SELECT description
                              FROM apps.fnd_lookup_values
                             WHERE     lookup_type = 'XXDOINV007_STYLE'
                                   AND enabled_flag = 'Y'
                                   AND LANGUAGE = 'US');

        CURSOR c_style IS
            SELECT organization_id, style, description,
                   scale_code_id, inventory_item_id, color,
                   upc_code, transmit_item_rms, item_status,
                   brand, department, CLASS,
                   subclass, sub_division, division,
                   unit_weight, unit_height, unit_width,
                   unit_length, dimension_uom_code, weight_uom_code,
                   sze, item_number, subclass_create_date,
                   subclass_update_date, subclass_updatedby, vertex_tax,
                   vertex_create_date, vertex_update_date, vertex_updatedby,
                   us_region_cost, uk_region_cost, jp_region_cost,
                   ca_region_cost, cn_region_cost, fr_region_cost,
                   hk_region_cost, us_region_price, ca_region_price,
                   uk_region_price, cn_region_price, jp_region_price,
                   fr_region_price, hk_region_price, row_num
              FROM (SELECT msib.organization_id, msib.style_number style, msib.item_description description,
                           msib.inventory_item_id, msib.upc_code, msib.size_scale_id scale_code_id,
                           msib.color_code color, msib.item_size sze, msib.brand,
                           msib.item_number, msib.division, msib.unit_weight,
                           msib.unit_height, msib.unit_width, msib.unit_length,
                           msib.dimension_uom_code, msib.weight_uom_code, msib.inventory_item_status_code item_status,
                           msib.item_type transmit_item_rms, msib.department, msib.master_class class,
                           msib.sub_class subclass, xxdoinv_pitem_pkg1.get_item_sub_division (msib.inventory_item_id, msib.organization_id) sub_division, --Added for change 2.1
                                                                                                                                                          NULL subclass_create_date,
                           NULL subclass_update_date, NULL subclass_updatedby, NULL vertex_tax,
                           NULL vertex_create_date, NULL vertex_update_date, NULL vertex_updatedby,
                           0.01 us_region_cost, 0.01 uk_region_cost, 0.01 jp_region_cost,
                           0.01 ca_region_cost, 0.01 cn_region_cost, 0.01 fr_region_cost,
                           0.01 hk_region_cost, NVL (do_custom.do_get_price_list_value (get_price_list_fun ('USRU'), msib.inventory_item_id), 0.01) us_region_price, NVL (do_custom.do_get_price_list_value (get_price_list_fun ('CAR'), msib.inventory_item_id), 0.01) ca_region_price,
                           NVL (do_custom.do_get_price_list_value (get_price_list_fun ('UKR'), msib.inventory_item_id), 0.01) uk_region_price, NVL (do_custom.do_get_price_list_value (get_price_list_fun ('CNR'), msib.inventory_item_id), 0.01) cn_region_price, NVL (do_custom.do_get_price_list_value (get_price_list_fun ('JPR'), msib.inventory_item_id), 0.01) jp_region_price,
                           NVL (do_custom.do_get_price_list_value (get_price_list_fun ('FRR'), msib.inventory_item_id), 0.01) fr_region_price, NVL (do_custom.do_get_price_list_value (get_price_list_fun ('HKR'), msib.inventory_item_id), 0.01) hk_region_price, RANK () OVER (PARTITION BY msib.style_number ORDER BY msib.inventory_item_id) row_num
                      FROM apps.mtl_categories_b mc, apps.mtl_item_categories mic, apps.xxd_common_items_v msib,
                           apps.mtl_parameters mp, fnd_lookup_values_vl lkp
                     WHERE     1 = 1
                           AND mic.inventory_item_id = msib.inventory_item_id
                           AND mic.organization_id = msib.organization_id
                           AND mic.category_id = mc.category_id
                           AND mp.organization_id = msib.organization_id
                           AND lkp.lookup_type = 'XXD_RMS_ITEM_STATUS'
                           AND meaning = msib.inventory_item_status_code
                           AND lkp.enabled_flag = 'Y'
                           AND mp.master_organization_id =
                               msib.organization_id
                           AND mc.structure_id =
                               (SELECT structure_id
                                  FROM mtl_category_sets
                                 WHERE category_set_name =
                                       'OM Sales Category')
                           AND NVL (msib.item_type, 'X') NOT IN
                                   ('SAMPLE', 'GENERIC')
                           AND msib.size_scale_id IS NOT NULL
                           AND msib.style_number =
                               NVL (pv_style, msib.style_number)
                           AND msib.upc_code IS NOT NULL
                           AND msib.last_update_date >=
                               NVL (
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS'),
                                   msib.last_update_date)
                           AND TRUNC (msib.last_update_date) =
                               NVL (ld_rundate2,
                                    TRUNC (msib.last_update_date))
                           -- AND xxdoinv006_pkg.get_dept_num_f (msib.inventory_item_id,msib.organization_id)IS NOT NULL
                           AND msib.style_number NOT IN
                                   (SELECT description
                                      FROM apps.fnd_lookup_values
                                     WHERE     lookup_type =
                                               'XXDOINV007_STYLE'
                                           AND enabled_flag = 'Y'
                                           AND LANGUAGE = 'US'));
    BEGIN
        req_data      := fnd_conc_global.request_data;
        ld_rundate    := TO_DATE (pv_rundate, 'YYYY/MM/DD HH24:MI:SS');
        ld_rundate1   := NULL;



        DBMS_SNAPSHOT.refresh ('apps.XXDO_RMS_ITEM_MASTER_MV', 'F');
        fnd_file.put_line (
            fnd_file.output,
            'materialized view XXDO_RMS_ITEM_MASTER_MV Refreshed :');

        IF pv_style IS NULL AND pv_rundate IS NULL AND pv_request_id IS NULL
        THEN
            l_rundate     := Get_Last_Conc_Req_Run (gn_conc_request_id);
            ld_rundate1   := TO_CHAR (l_rundate, 'DD-MON-YYYY HH24:MI:SS');
        END IF;

        IF     pv_rundate IS NOT NULL
           AND pv_style IS NULL
           AND pv_request_id IS NULL
        THEN
            ld_rundate2   :=
                TRUNC (TO_DATE (pv_rundate, 'YYYY/MM/DD HH24:MI:SS'));
            fnd_file.put_line (fnd_file.LOG, 'ld_rundate : ' || ld_rundate2);
        END IF;



        fnd_file.put_line (
            fnd_file.LOG,
            '*****************Input Parameters*********************');

        fnd_file.put_line (fnd_file.LOG, 'reprocess : ' || pv_reprocess);
        fnd_file.put_line (
            fnd_file.LOG,
               'Program Last rundate : '
            || TO_CHAR (l_rundate, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'rundate : ' || ld_rundate1);
        fnd_file.put_line (fnd_file.LOG, 'style : ' || pv_style);
        fnd_file.put_line (fnd_file.LOG, 'request_id : ' || pv_request_id);


        fnd_file.put_line (
            fnd_file.LOG,
            '*****************END Input Parameters*********************');



        IF     pv_reprocess = 'YES'
           AND pv_request_id IS NOT NULL
           AND pv_rundate IS NOT NULL
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Please enter only one from Input paramatere for reprocessing YES');
        ELSIF     pv_reprocess = 'YES'
              AND pv_request_id IS NOT NULL
              AND pv_style IS NOT NULL
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Please enter only one from Input paramatere for reprocessing YES');
        ELSIF     pv_reprocess = 'YES'
              AND pv_rundate IS NOT NULL
              AND pv_style IS NOT NULL
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Please enter only one from Input paramatere for reprocessing YES');
        ELSIF     pv_reprocess = 'YES'
              AND pv_request_id IS NULL
              AND pv_rundate IS NULL
              AND pv_style IS NULL
        THEN
            UPDATE XXDO.XXD_RMS_ITEM_MASTER_STG
               SET PROCESS_STATUS = 'N', REQUEST_ID = ln_request_id, last_update_date = SYSDATE
             WHERE     1 = 1
                   AND PROCESS_STATUS = 'E'
                   AND response_message NOT LIKE '%already%';

            ln_records   := SQL%ROWCOUNT;

            fnd_file.put_line (
                fnd_file.LOG,
                ln_records || ' records are Ready for reprocessing ');
            COMMIT;
        ELSIF     pv_reprocess = 'YES'
              AND pv_request_id IS NOT NULL
              AND pv_rundate IS NOT NULL
              AND pv_style IS NOT NULL
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Please enter only one from Input paramatere for reprocessing YES');
        ELSIF pv_reprocess = 'YES' AND pv_request_id IS NOT NULL
        THEN
            UPDATE XXDO.XXD_RMS_ITEM_MASTER_STG
               SET PROCESS_STATUS = 'N', REQUEST_ID = ln_request_id, last_update_date = SYSDATE
             WHERE REQUEST_ID = pv_request_id AND PROCESS_STATUS = 'E';

            ln_records   := SQL%ROWCOUNT;

            fnd_file.put_line (
                fnd_file.LOG,
                ln_records || ' records are Ready for reprocessing ');

            COMMIT;
        ELSIF pv_reprocess = 'YES' AND pv_style IS NOT NULL
        THEN
            UPDATE XXDO.XXD_RMS_ITEM_MASTER_STG
               SET PROCESS_STATUS = 'N', REQUEST_ID = ln_request_id, last_update_date = SYSDATE
             WHERE style = pv_style AND PROCESS_STATUS = 'E';

            ln_records   := SQL%ROWCOUNT;

            fnd_file.put_line (
                fnd_file.LOG,
                ln_records || ' records are Ready for reprocessing ');

            COMMIT;
        ELSE
            /**************************************************************
            clearing data from staging tables
            **************************************************************/
            BEGIN
                staging_table_purging (pv_error, pv_errode);

                IF pv_error IS NOT NULL OR pv_errode IS NOT NULL
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error Ocurred While Purging Staging Tables'
                        || pv_error);
                END IF;
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Cursor rec_style_rec started '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

            FOR rec_style_rec IN c_style
            LOOP
                lv_error_message    := NULL;
                ln_styledupcount    := 0;
                lv_counter          := lv_counter + 1;

                IF lv_counter = 1
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           '***Porcerssing Started ***'
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                END IF;


                SELECT COUNT (1)
                  INTO ln_styledupcount
                  FROM mtl_system_items_b
                 WHERE TO_CHAR (inventory_item_id) = rec_style_rec.style;


                IF ln_styledupcount <> 0
                THEN
                    l_style   := 'RMS-' || (rec_style_rec.style);
                ELSE
                    l_style   := rec_style_rec.style;
                END IF;

                fnd_file.put_line (fnd_file.LOG,
                                   'ln_styledupcount ' || ln_styledupcount);

                fnd_file.put_line (fnd_file.LOG, 'l_style ' || l_style);

                ln_itemstylecount   := NULL;

                SELECT COUNT (1)
                  INTO ln_itemstylecount
                  FROM item_master@xxdo_retail_rms
                 WHERE item = l_style AND item_level = 1;

                fnd_file.put_line (fnd_file.LOG,
                                   'ln_itemstylecount ' || ln_itemstylecount);

                IF ln_itemstylecount >= 1
                THEN
                    lv_op_mode   := 'ITEM_UPDATE';

                    BEGIN
                        SELECT item_desc
                          INTO lv_description
                          FROM item_master@xxdo_retail_rms
                         WHERE item_level = 1 AND item = l_style;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Exception occured while retrieing the item description ');
                    END;

                    IF ((NVL (UPPER (TRIM (lv_description)), '0') <> UPPER (TRIM (rec_style_rec.description))))
                    THEN
                        lv_style_status   := 'N';
                    ELSE
                        lv_style_status   := 'NR';
                        lv_error_message   :=
                            'No Change in description for the Style';
                    END IF;
                ELSE
                    lv_op_mode        := 'ITEM_CREATE';
                    lv_style_status   := 'N';
                    fnd_file.put_line (fnd_file.LOG,
                                       'In ELSE ' || ln_itemstylecount);
                END IF;

                IF    rec_style_rec.department IS NULL
                   OR rec_style_rec.CLASS IS NULL
                   OR rec_style_rec.scale_code_id IS NULL
                   OR rec_style_rec.subclass IS NULL
                THEN
                    lv_style_status   := 'NOCLASS';
                    lv_error_message   :=
                        'Mandatory columns like Department, Class, Scale Code id either one or all of them is missing  for Style';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Mandatory columns like Department, Class, Scale Code id either one or all of them is missing  for Style'
                        || rec_style_rec.style);
                END IF;

                IF l_style <> lv_next_style
                THEN
                    IF lv_style_status <> 'NR'
                    THEN
                        BEGIN
                            INSERT INTO XXDO.XXD_RMS_ITEM_MASTER_STG (
                                            slno,
                                            servicetype,
                                            item_type,
                                            operation,
                                            organization_id,
                                            style,
                                            brand,
                                            color,
                                            sze,
                                            item_description,
                                            scale_code_id,
                                            department,
                                            CLASS,
                                            subclass,
                                            sub_division,
                                            unit_weight,
                                            unit_height,
                                            unit_width,
                                            unit_length,
                                            dimension_uom_code,
                                            weight_uom_code,
                                            gender,
                                            subclass_creation_date,
                                            subclass_update_date,
                                            subclass_updatedby,
                                            vertex_tax,
                                            vertex_creation_date,
                                            vertex_update_date,
                                            vertex_updatedby,
                                            us_region_cost,
                                            us_region_price,
                                            uk_region_cost,
                                            uk_region_price,
                                            ca_region_cost,
                                            ca_region_price,
                                            cn_region_cost,
                                            cn_region_price,
                                            jp_region_cost,
                                            jp_region_price,
                                            fr_region_cost,
                                            fr_region_price,
                                            hk_region_cost,
                                            hk_region_price,
                                            item_status,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            last_update_date,
                                            ORACLE_ERROR_MESSAGE)
                                 VALUES (xxdoinv006_int_s.NEXTVAL, 'ITEM', 'STYLE', lv_op_mode, rec_style_rec.organization_id, l_style, rec_style_rec.brand, 'ALL COLORS', '9999', rec_style_rec.description, rec_style_rec.scale_code_id, rec_style_rec.department, rec_style_rec.CLASS, rec_style_rec.subclass, rec_style_rec.sub_division, rec_style_rec.unit_weight, rec_style_rec.unit_height, rec_style_rec.unit_width, rec_style_rec.unit_length, rec_style_rec.dimension_uom_code, rec_style_rec.weight_uom_code, rec_style_rec.division, rec_style_rec.subclass_create_date, rec_style_rec.subclass_update_date, rec_style_rec.subclass_updatedby, rec_style_rec.vertex_tax, rec_style_rec.vertex_create_date, rec_style_rec.vertex_update_date, rec_style_rec.vertex_updatedby, rec_style_rec.us_region_cost, rec_style_rec.us_region_price, rec_style_rec.uk_region_cost, rec_style_rec.uk_region_price, rec_style_rec.ca_region_cost, rec_style_rec.ca_region_price, rec_style_rec.cn_region_cost, rec_style_rec.cn_region_price, rec_style_rec.jp_region_cost, rec_style_rec.jp_region_price, rec_style_rec.fr_region_cost, rec_style_rec.fr_region_price, rec_style_rec.hk_region_cost, rec_style_rec.hk_region_price, NULL, lv_style_status, ln_request_id, SYSDATE, SYSDATE
                                         , lv_error_message);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_style_failed   := 'Y';
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to insret record for Style'
                                    || rec_style_rec.style
                                    || ' Error '
                                    || SQLERRM);
                        END;
                    END IF;
                END IF;

                lv_next_style       := l_style;


                -----------SKU POPULATE---
                --------------------------
                IF NVL (lv_style_failed, 'N') <> 'Y'
                THEN
                    ln_itemskucount    := NULL;
                    lv_error_message   := NULL;

                    SELECT COUNT (1)
                      INTO ln_itemskucount
                      --FROM item_master@xxdo_retail_rms
                      FROM APPS.XXDO_RMS_ITEM_MASTER_MV
                     WHERE     item =
                               TO_CHAR (rec_style_rec.inventory_item_id)
                           AND item_level = 2;

                    IF ln_itemskucount >= 1
                    THEN
                        lv_op_mode   := 'ITEM_UPDATE';

                        BEGIN
                            SELECT SUBSTR (item_desc, (INSTR (item_desc, ':', -1) + 1)), status
                              INTO lv_description, lv_itemstatus
                              --FROM item_master@xxdo_retail_rms
                              FROM APPS.XXDO_RMS_ITEM_MASTER_MV
                             WHERE     item =
                                       TO_CHAR (
                                           rec_style_rec.inventory_item_id)
                                   AND item_level = 2;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception occured while retrieing the item description ');
                        END;

                        IF ((NVL (UPPER (TRIM (lv_description)), '0') <> UPPER (TRIM (rec_style_rec.description))))
                        THEN
                            lv_sku_status   := 'N';
                        ELSE
                            lv_sku_status   := 'NR';
                        END IF;
                    ELSE
                        lv_op_mode      := 'ITEM_CREATE';
                        lv_sku_status   := 'N';
                    END IF;

                    IF    rec_style_rec.department IS NULL
                       OR rec_style_rec.CLASS IS NULL
                       OR rec_style_rec.scale_code_id IS NULL
                       OR rec_style_rec.SUBCLASS IS NULL
                    THEN
                        lv_sku_status   := 'NOCLASS';
                        lv_error_message   :=
                            'Mandatory columns like Department, Class, Scale Code id either one or all of them is missing  for Item';
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Mandatory columns like Department, Class, Scale Code id either one or all of them is missing  for Item'
                            || rec_style_rec.inventory_item_id);
                    END IF;

                    IF lv_sku_status <> 'NR'
                    THEN
                        BEGIN
                            INSERT INTO XXDO.XXD_RMS_ITEM_MASTER_STG (
                                            slno,
                                            servicetype,
                                            item_type,
                                            operation,
                                            inventory_item_id,
                                            organization_id,
                                            style,
                                            color,
                                            sze,
                                            brand,
                                            item_status,
                                            item_number,
                                            process_status,
                                            item_description,
                                            scale_code_id,
                                            department,
                                            CLASS,
                                            subclass,
                                            unit_weight,
                                            unit_height,
                                            unit_width,
                                            unit_length,
                                            dimension_uom_code,
                                            weight_uom_code,
                                            gender,
                                            subclass_creation_date,
                                            subclass_update_date,
                                            subclass_updatedby,
                                            vertex_tax,
                                            vertex_creation_date,
                                            vertex_update_date,
                                            vertex_updatedby,
                                            us_region_cost,
                                            us_region_price,
                                            uk_region_cost,
                                            uk_region_price,
                                            ca_region_cost,
                                            ca_region_price,
                                            cn_region_cost,
                                            cn_region_price,
                                            jp_region_cost,
                                            jp_region_price,
                                            fr_region_cost,
                                            fr_region_price,
                                            hk_region_cost,
                                            hk_region_price,
                                            request_id,
                                            sub_division, --Added for change 2.1
                                            creation_date,
                                            last_update_date,
                                            ORACLE_ERROR_MESSAGE)
                                     VALUES (
                                                xxdoinv006_int_s.NEXTVAL,
                                                'ITEM',
                                                'SKU',
                                                lv_op_mode,
                                                rec_style_rec.inventory_item_id,
                                                rec_style_rec.organization_id,
                                                l_style,
                                                rec_style_rec.color,
                                                rec_style_rec.sze,
                                                rec_style_rec.brand,
                                                rec_style_rec.item_status,
                                                rec_style_rec.item_number,
                                                lv_sku_status,
                                                rec_style_rec.description,
                                                rec_style_rec.scale_code_id,
                                                rec_style_rec.department,
                                                rec_style_rec.CLASS,
                                                rec_style_rec.subclass,
                                                rec_style_rec.unit_weight,
                                                rec_style_rec.unit_height,
                                                rec_style_rec.unit_width,
                                                rec_style_rec.unit_length,
                                                rec_style_rec.dimension_uom_code,
                                                rec_style_rec.weight_uom_code,
                                                rec_style_rec.division,
                                                rec_style_rec.subclass_create_date,
                                                rec_style_rec.subclass_update_date,
                                                rec_style_rec.subclass_updatedby,
                                                rec_style_rec.vertex_tax,
                                                NVL (
                                                    rec_style_rec.vertex_create_date,
                                                    NULL),
                                                NVL (
                                                    rec_style_rec.vertex_update_date,
                                                    NULL),
                                                NVL (
                                                    rec_style_rec.vertex_updatedby,
                                                    NULL),
                                                rec_style_rec.us_region_cost,
                                                rec_style_rec.us_region_price,
                                                rec_style_rec.uk_region_cost,
                                                rec_style_rec.uk_region_price,
                                                rec_style_rec.ca_region_cost,
                                                rec_style_rec.ca_region_price,
                                                rec_style_rec.cn_region_cost,
                                                rec_style_rec.cn_region_price,
                                                rec_style_rec.jp_region_cost,
                                                rec_style_rec.jp_region_price,
                                                rec_style_rec.fr_region_cost,
                                                rec_style_rec.fr_region_price,
                                                rec_style_rec.hk_region_cost,
                                                rec_style_rec.hk_region_price,
                                                ln_request_id,
                                                rec_style_rec.sub_division, --Added for change 2.1
                                                SYSDATE,
                                                SYSDATE,
                                                lv_error_message);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_style_failed   := 'Y';
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to insret record for UPC Item'
                                    || rec_style_rec.item_number
                                    || ' Error '
                                    || SQLERRM);
                        END;
                    END IF;

                    ---------------UPC POPULATE IN STAGING---------------
                    ------------------------------------------
                    lv_error_message   := NULL;

                    SELECT COUNT (1)
                      INTO ln_itemupccount
                      --FROM item_master@xxdo_retail_rms
                      FROM APPS.XXDO_RMS_ITEM_MASTER_MV
                     WHERE     item = TO_CHAR (rec_style_rec.upc_code)
                           AND item_parent =
                               TO_CHAR (rec_style_rec.inventory_item_id)
                           AND item_level = 3;

                    IF ln_itemupccount >= 1
                    THEN
                        lv_op_mode   := 'ITEM_UPDATE';

                        BEGIN
                            SELECT SUBSTR (item_desc, (INSTR (item_desc, ':', -1) + 1)), status
                              INTO lv_description, lv_itemstatus
                              --FROM item_master@xxdo_retail_rms
                              FROM APPS.XXDO_RMS_ITEM_MASTER_MV
                             WHERE     item =
                                       TO_CHAR (rec_style_rec.upc_code)
                                   AND item_parent =
                                       TO_CHAR (
                                           rec_style_rec.inventory_item_id)
                                   AND item_level = 3;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception occured while retrieing the item description FROM RMS DB LINK ');
                                lv_error_message   :=
                                    'Exception occured while retrieing the item description FROM RMS DB LINK';
                        END;

                        IF ((NVL (UPPER (TRIM (lv_description)), '0') <> UPPER (TRIM (rec_style_rec.description))))
                        THEN
                            lv_upc_status   := 'N';
                        ELSE
                            lv_upc_status   := 'NR';
                            lv_error_message   :=
                                'No Change in description for the SKU';
                        END IF;
                    ELSE
                        lv_op_mode      := 'ITEM_CREATE';
                        lv_upc_status   := 'N';
                    END IF;

                    IF lv_upc_status <> 'NR'
                    THEN
                        BEGIN
                            INSERT INTO XXDO.XXD_RMS_ITEM_MASTER_STG (
                                            slno,
                                            servicetype,
                                            item_type,
                                            operation,
                                            inventory_item_id,
                                            organization_id,
                                            style,
                                            color,
                                            sze,
                                            brand,
                                            item_status,
                                            item_number,
                                            item_description,
                                            scale_code_id,
                                            department,
                                            CLASS,
                                            subclass,
                                            sub_division,
                                            unit_weight,
                                            unit_height,
                                            unit_width,
                                            unit_length,
                                            dimension_uom_code,
                                            weight_uom_code,
                                            gender,
                                            subclass_creation_date,
                                            subclass_update_date,
                                            subclass_updatedby,
                                            vertex_tax,
                                            vertex_creation_date,
                                            vertex_update_date,
                                            vertex_updatedby,
                                            us_region_cost,
                                            us_region_price,
                                            uk_region_cost,
                                            uk_region_price,
                                            ca_region_cost,
                                            ca_region_price,
                                            cn_region_cost,
                                            cn_region_price,
                                            jp_region_cost,
                                            jp_region_price,
                                            fr_region_cost,
                                            fr_region_price,
                                            hk_region_cost,
                                            hk_region_price,
                                            upc_value,
                                            request_id,
                                            creation_date,
                                            last_update_date,
                                            process_status,
                                            ORACLE_ERROR_MESSAGE)
                                 VALUES (xxdoinv006_int_s.NEXTVAL, 'ITEM ', 'UPC', lv_op_mode, rec_style_rec.inventory_item_id, rec_style_rec.organization_id, l_style, rec_style_rec.color, rec_style_rec.sze, rec_style_rec.brand, rec_style_rec.item_status, rec_style_rec.item_number, rec_style_rec.description, rec_style_rec.scale_code_id, rec_style_rec.department, rec_style_rec.CLASS, rec_style_rec.subclass, rec_style_rec.sub_division, rec_style_rec.unit_weight, rec_style_rec.unit_height, rec_style_rec.unit_width, rec_style_rec.unit_length, rec_style_rec.dimension_uom_code, rec_style_rec.weight_uom_code, rec_style_rec.division, rec_style_rec.subclass_create_date, rec_style_rec.subclass_update_date, rec_style_rec.subclass_updatedby, rec_style_rec.vertex_tax, rec_style_rec.vertex_create_date, rec_style_rec.vertex_update_date, rec_style_rec.vertex_updatedby, rec_style_rec.us_region_cost, rec_style_rec.us_region_price, rec_style_rec.uk_region_cost, rec_style_rec.uk_region_price, rec_style_rec.ca_region_cost, rec_style_rec.ca_region_price, rec_style_rec.cn_region_cost, rec_style_rec.cn_region_price, rec_style_rec.jp_region_cost, rec_style_rec.jp_region_price, rec_style_rec.fr_region_cost, rec_style_rec.fr_region_price, rec_style_rec.hk_region_cost, rec_style_rec.hk_region_price, rec_style_rec.upc_code, ln_request_id, SYSDATE, SYSDATE, lv_upc_status
                                         , lv_error_message);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_style_failed   := 'Y';
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to insret record for UPC'
                                    || rec_style_rec.upc_code
                                    || ' Error '
                                    || SQLERRM);
                        END;
                    END IF;
                END IF;

                COMMIT;
            END LOOP;


            --***********TAX****************
            --******************************

            FOR rec_tax_rec IN c_tax
            LOOP
                lv_error_message     := NULL;

                SELECT COUNT (1)
                  INTO ln_styledupcount
                  FROM mtl_system_items_b
                 WHERE TO_CHAR (inventory_item_id) = rec_tax_rec.style;


                IF ln_styledupcount <> 0
                THEN
                    l_style   := 'RMS-' || (rec_tax_rec.style);
                ELSE
                    l_style   := rec_tax_rec.style;
                END IF;

                /* Start of Added on 08/14 for TAX CREATE message*/
                ln_tax_count         := 0;
                ln_tax_exist_count   := 0;

                SELECT COUNT (1)
                  INTO ln_tax_count
                  FROM uda_item_ff@xxdo_retail_rms
                 WHERE     item = TO_CHAR (rec_tax_rec.inventory_item_id)
                       AND uda_id = 1;

                IF ln_tax_count >= 1
                THEN
                    lv_op_mode   := 'TAX_UPDATE';

                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_tax_exist_count
                          FROM uda_item_ff@xxdo_retail_rms
                         WHERE     item =
                                   TO_CHAR (rec_tax_rec.inventory_item_id)
                               AND UDA_TEXT = rec_tax_rec.vertex_tax
                               AND uda_id = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_tax_exist_count   := 0;
                    END;
                ELSE
                    lv_op_mode   := 'TAX_CREATE';
                END IF;

                --lv_op_mode := 'TAX_UPDATE'

                /* End of Added on 08/14 for TAX CREATE message*/
                lv_counter           := lv_counter + 1;

                IF ln_tax_exist_count = 0
                THEN
                    BEGIN
                        INSERT INTO XXDO.XXD_RMS_ITEM_MASTER_STG (
                                        slno,
                                        servicetype,
                                        item_type,
                                        operation,
                                        inventory_item_id,
                                        organization_id,
                                        style,
                                        color,
                                        sze,
                                        brand,
                                        item_status,
                                        item_number,
                                        item_description,
                                        scale_code_id,
                                        vertex_tax,
                                        request_id,
                                        creation_date,
                                        last_update_date,
                                        process_status,
                                        ORACLE_ERROR_MESSAGE)
                             VALUES (xxdoinv006_int_s.NEXTVAL, 'ITEM ', 'SKU', lv_op_mode, rec_tax_rec.inventory_item_id, rec_tax_rec.organization_id, l_style, --rec_tax_rec.style, --commented on 08/14
                                                                                                                                                                rec_tax_rec.color, rec_tax_rec.sze, rec_tax_rec.brand, rec_tax_rec.item_status, rec_tax_rec.item_number, rec_tax_rec.description, rec_tax_rec.scale_code_id, rec_tax_rec.vertex_tax, ln_request_id, SYSDATE, SYSDATE
                                     , 'N', lv_error_message);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_style_failed   := 'Y';
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insret record for TAX'
                                || l_style
                                || ' Error '
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        END IF;

        COMMIT;

        BEGIN
            SELECT COUNT (1)
              INTO ln_tot_records
              FROM xxdo.xxd_rms_item_master_stg
             WHERE request_id = ln_request_id;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'Total Number of Records Porcessed :' || ln_tot_records);
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_style_failed   := 'Y';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpecetd Exception Please check the program/data'
                || ' Error '
                || SQLERRM);
    END main_proc;
END XXD_RMS_ITEM_PUBLISH_PKG;
/
