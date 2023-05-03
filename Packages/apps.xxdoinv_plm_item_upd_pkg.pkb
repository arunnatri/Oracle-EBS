--
-- XXDOINV_PLM_ITEM_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINV_PLM_ITEM_UPD_PKG"
AS
    /**********************************************************************************************************
    * Package Name     : xxdoinv_plm_item_upd_pkg
    *
    * File Type        : Package Body
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR           Version     Description
    * ---------     -------          -------     ---------------
    * 9/28/2016     INFOSYS           1.0         Initial Version
    * 1/24/2017     Bala Murugesan    2.0         Modified to handle the exceptions
    *                                             in case of PO item category update;
    *                                             Changes identified by ERROR_HANDLE
    * 1/25/2017     Bala Murugesan    2.0         Modified to initialize the global tables;
    *                                             Changes identified by GLOBAL_RESET_TABLES
    * 1/27/2017     Bala Murugesan    2.0         Modified to disable the Old inventory item category
    *                                             of ILR items;
    *                                             Changes identified by DISABLE_ILR_CATEGORIES
    * 2/8/2017     Bala Murugesan     3.0         Modified to fix the bug - other styles having the required
    *                                             style number as a part of their style numbers are updated
    *                                             Ex: U1647 is incorrectly updated with 1647;
    *                                             Changes identified by STYLE_SEARCH
    * 2/8/2017     Bala Murugesan     3.0         Modified to disable the inventory item categories of
    *                                             Generic items;
    *                                             Changes identified by DISABLE_GENERIC_CATEGORIES
    * 2/8/2017     Bala Murugesan     3.0         Modified to enable item categories if already exist;
    *                                             Changes identified by ENABLE_OLD_CATEGORY
    * 2/9/2017     Bala Murugesan     3.0         Modified to initialize the API message list and use
    *                                             correct APIs to get error messages ;
    *                                             Changes identified by INIT_API_MSG_LIST
    * 2/9/2017     Bala Murugesan     3.0         Modified not to update the categories if the same hierarchy sent
    *                                             multiple times from PLM;
    *                                             Changes identified by NO_UPDATE_CHECK
    * 2/9/2017     Bala Murugesan     3.0         Modified not to create price list lines when new OM Sales category
    *                                             is not found;
    *                                             Changes identified by NO_CAT_FOUND
    * 2/9/2017     Bala Murugesan     3.0         Modified not to create price list lines for each color of the same
    *                                             OM Sales Category;
    *                                             Changes identified by SAME_PLL_EXISTS
    * 2/9/2017     Bala Murugesan     3.0         Modified not to disable the OM sales category if it did not change;
    *                                             Changes identified by NO_OM_SALES_CAT_CHANGE
    * 2/10/2017    Bala Murugesan    3.0         Modified to create categories for samples of Non Footwear styles;
    *                                             Changes identified by NON_FOOTWEAR_SAMPLE
    * 6/6/2017     Bala Murugesan    4.0         Modified to fix the sizes (of same style/color) which have


    *                                             different hierarchies;
    *                                             Changes identified by SIZES_DIFF_HIERARCHIES
    * 08/23/2017  Arun N Murthy      5.0         Added Update_price procedure inorder to end date the old price list for old category
    ***********************************************************************************************************/

    gn_record_id                     NUMBER := NULL;
    gn_conc_request_id               NUMBER := apps.fnd_global.conc_request_id;
    gv_debug_enable                  VARCHAR2 (1) := 'Y';
    gv_log_debug_enable              VARCHAR2 (1);
    gv_reterror                      VARCHAR2 (2000) := NULL;
    gv_retcode                       VARCHAR2 (2000) := NULL;
    gv_error_desc                    VARCHAR2 (4000) := NULL;
    gv_plm_style                     VARCHAR2 (100);
    gv_color_code                    VARCHAR2 (100);
    g_item_search                    VARCHAR2 (100) := NULL;
    g_l_item_search                  VARCHAR2 (100) := NULL;
    g_r_item_search                  VARCHAR2 (100) := NULL;
    g_sr_item_search                 VARCHAR2 (100) := NULL;
    g_sl_item_search                 VARCHAR2 (100) := NULL;
    g_ss_item_search                 VARCHAR2 (100) := NULL;
    g_s_item_search                  VARCHAR2 (100) := NULL;
    g_bg_item_search                 VARCHAR2 (100) := NULL;
    gv_season                        VARCHAR2 (100);
    gn_plm_rec_id                    NUMBER;
    gv_colorway_state                VARCHAR2 (100);
    g_style                          VARCHAR2 (100);
    g_colorway                       VARCHAR2 (100);
    g_style_name                     VARCHAR2 (100);
    g_style_name_upr                 VARCHAR2 (100);
    gn_userid                        NUMBER := apps.fnd_global.user_id;
    gv_package_name                  VARCHAR2 (200) := 'XXDOINV_PLM_ITEM_UPD_PKG';
    gv_sku_flag                      VARCHAR2 (100);
    g_user_id                        NUMBER := fnd_global.user_id;
    g_resp_id                        NUMBER := fnd_global.resp_id;
    g_resp_appl_id                   NUMBER := fnd_global.resp_appl_id;
    gn_master_org_code               VARCHAR2 (200)
        := apps.fnd_profile.VALUE ('XXDO: ORGANIZATION CODE');
    gn_master_orgid                  NUMBER;
    g_tab_temp_req                   tabtype_request_id;
    gv_inventory_set_name   CONSTANT VARCHAR2 (30) := 'Inventory';
    gn_inventory_set_id              NUMBER := NULL;
    gn_inventory_structure_id        NUMBER := NULL;
    gv_om_sales_set_name    CONSTANT VARCHAR2 (30) := 'OM Sales Category';
    gn_om_sales_set_id               NUMBER := NULL;
    gn_om_sales_structure_id         NUMBER := NULL;
    gn_po_item_set_name     CONSTANT VARCHAR2 (30) := 'PO Item Category';
    gn_po_item_set_id                NUMBER := NULL;
    gn_po_item_structure_id          NUMBER := NULL;
    gn_cat_process_id                NUMBER := 1;
    gn_cat_process_count             NUMBER := 1;
    gn_cat_process_flag              VARCHAR2 (200) := 'N';
    gn_cat_process_works             NUMBER := 1;
    gn_tot_records_procs             NUMBER := 1;
    gv_cat_asgn_err_cnt              NUMBER := 0;
    gv_src_rule_upd_err_cnt          NUMBER := 0;
    gv_prc_list_upd_err_cnt          NUMBER := 0;
    gv_inv_oldnew_cat_cnt            NUMBER := 1;
    gv_inv_error_cnt                 NUMBER := 1;
    gv_omsales_error_cnt             NUMBER := 1;
    gv_po_error_cnt                  NUMBER := 1;
    gv_po_cat_updated                VARCHAR2 (1) := 'N';
    gv_oms_oldnew_cat_cnt            NUMBER := 1;
    gv_old_om_cat_upd_err_cnt        NUMBER := 1;
    gv_old_inv_cat_upd_err_cnt       NUMBER := 1;
    gv_old_po_cat_upd_err_cnt        NUMBER := 1;
    gv_sub_division_updated          VARCHAR2 (1) := 'N'; -- NO_UPDATE_CHECK - Start - End
    g_old_om_cat_table               ego_item_pub.category_assignment_tbl_type;
    g_old_inv_cat_table              ego_item_pub.category_assignment_tbl_type;
    g_old_po_cat_table               ego_item_pub.category_assignment_tbl_type;
    --Start Changes V5.0
    gv_old_style_number              VARCHAR2 (100) := 'ABCD';
    gn_style_cnt                     NUMBER := 0;
    gn_old_style_cnt                 NUMBER := 0;
    --End Changes V5.0


    -- DISABLE_ILR_CATEGORIES - Start
    g_old_gen_inv_cat_table          ego_item_pub.category_assignment_tbl_type;

    -- DISABLE_ILR_CATEGORIES - End
    -- SIZES_DIFF_HIERARCHIES - Start
    g_all_sizes_fixed                VARCHAR2 (1);

    -- SIZES_DIFF_HIERARCHIES - End

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
    * 9/28/2016     INFOSYS     1.0         Initial Version
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

    /****************************************************************************
    * Procedure Name    : log
    *
    * Description       : The purpose of this procedure is to display log
    *                     messages when debug is enabled.
    *
    * INPUT Parameters  :
    *
    * OUTPUT Parameters :
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE LOG (pv_msg VARCHAR2, pn_level NUMBER:= 1000)
    IS
    BEGIN
        IF gv_log_debug_enable = 'Y'
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
            DBMS_OUTPUT.put_line (pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Error In log procedure' || SQLERRM);
    END;

    --ENABLE_OLD_CATEGORY --Start



    /****************************************************************************
 * Procedure Name    : enable_category
 *
 * Description       : This procedure is to enable the old categories

 *
 * INPUT Parameters  : pv_category_id

 *
 * OUTPUT Parameters : pv_retcode


 *                     pv_reterror
 *
 * DEVELOPMENT and MAINTENANCE HISTORY

 *
 * DATE          AUTHOR      Version     Description
 * ---------     -------     -------     ---------------
 *2/8/2017     Bala Murugesan     1.0         Initial Version
 ****************************************************************************/
    PROCEDURE enable_category (pv_category_id NUMBER, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2)
    IS
        lv_pn              VARCHAR2 (240) := gv_package_name || '.enable_category';
        lv_category_rec    apps.inv_item_category_pub.category_rec_type;
        ln_sys_resp_id     NUMBER := apps.fnd_global.resp_id;
        ln_sys_appl_id     NUMBER := apps.fnd_global.resp_id;
        ln_category_id     NUMBER := 0;
        x_return_status    VARCHAR2 (1) := NULL;
        x_msg_count        NUMBER := 0;
        x_errorcode        NUMBER := 0;
        x_msg_data         VARCHAR2 (4000);
        lv_error_message   VARCHAR2 (4000);
        ln_msg_count       NUMBER := 0;
    BEGIN
        lv_error_message               := NULL;
        x_return_status                := NULL;
        x_msg_count                    := 0;
        x_msg_data                     := NULL;
        pv_retcode                     := NULL;
        pv_reterror                    := NULL;
        ln_category_id                 := pv_category_id;


        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_sys_resp_id, ln_sys_appl_id
              FROM fnd_responsibility
             WHERE responsibility_key =
                   apps.fnd_profile.VALUE ('XXDO_SYS_ADMIN_RESP');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_sys_resp_id   := apps.fnd_global.resp_id;
                ln_sys_appl_id   := apps.fnd_global.prog_appl_id;
        END;

        apps.fnd_global.apps_initialize (apps.fnd_global.user_id,
                                         ln_sys_resp_id,
                                         ln_sys_appl_id);


        lv_category_rec.category_id    := ln_category_id;
        lv_category_rec.disable_date   := NULL;

        -- Calling the api to update category --
        fnd_msg_pub.delete_msg (NULL);
        inv_item_category_pub.update_category (
            p_api_version     => 1.0,
            p_init_msg_list   => fnd_api.g_true,
            p_commit          => fnd_api.g_false,
            x_return_status   => x_return_status,
            x_errorcode       => x_errorcode,
            x_msg_count       => ln_msg_count,
            x_msg_data        => x_msg_data,
            p_category_rec    => lv_category_rec);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            COMMIT;
        ELSE
            INSERT INTO xxdo.xxdo_plm_item_upd_errors
                     VALUES (
                                gn_record_id,
                                g_style,
                                g_colorway,
                                gn_master_orgid,
                                   'Old Category Enable Error: Category ID: '
                                || lv_category_rec.category_id
                                || ' while enabling. ',
                                SYSDATE);

            COMMIT;

            FOR k IN 1 .. ln_msg_count
            LOOP
                x_msg_data   :=
                    fnd_msg_pub.get (p_msg_index => k, p_encoded => 'F');
                lv_error_message   :=
                    SUBSTR (
                           'Error in API while enabling the category : '
                        || k
                        || ' is : '
                        || x_msg_data,
                        0,
                        1000);
                msg (SUBSTR (lv_error_message, 1, 900));
            END LOOP;

            pv_retcode    := 2;
            pv_reterror   := SUBSTR (lv_error_message, 0, 1000);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;
    END enable_category;

    --ENABLE_OLD_CATEGORY --End

    /****************************************************************************
    * Procedure Name    : update_description
    *
    * Description       : Procedure to update Item description
    *
    * INPUT Parameters  : p_inv_item_id
    *                     p_item
    *                     p_item_description
    *                     p_org_id
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE update_description (p_item_description VARCHAR2, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2)
    IS
        l_item_table           ego_item_pub.item_tbl_type;
        x_item_table           ego_item_pub.item_tbl_type;
        x_return_status        VARCHAR2 (1);
        x_msg_count            NUMBER (10);
        x_msg_data             VARCHAR2 (1000);
        x_message_list         error_handler.error_tbl_type;

        /*******************************************************************************
        Cursor to fetch all inventory items with given style and color combination
        *******************************************************************************/
        CURSOR csr_items IS
              SELECT *
                FROM apps.mtl_system_items_b           -- STYLE_SEARCH - Start
               WHERE     (   (segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC'))
                          OR (segment1 LIKE g_l_item_search)
                          OR (segment1 LIKE g_r_item_search)
                          OR (segment1 LIKE g_sr_item_search)
                          OR (segment1 LIKE g_sl_item_search)
                          OR (segment1 LIKE g_ss_item_search)
                          OR (    segment1 LIKE g_s_item_search
                              AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                  'GENERIC'))
                          OR (segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                             )
                     AND organization_id = gn_master_orgid
            ORDER BY segment1;

        lv_item_description    VARCHAR2 (400) := NULL;
        lv_item_desc_err_cnt   NUMBER := 0;
        i                      NUMBER := 0;
    BEGIN
        lv_item_description   := p_item_description;

        FOR rec_csr_items IN csr_items
        LOOP
            IF UPPER (rec_csr_items.description) <>
               UPPER (lv_item_description)
            THEN
                i                                    := i + 1;

                l_item_table (i).transaction_type    := 'UPDATE';
                l_item_table (i).inventory_item_id   :=
                    rec_csr_items.inventory_item_id;
                l_item_table (i).segment1            :=
                    rec_csr_items.segment1;
                l_item_table (i).description         := lv_item_description;
                l_item_table (i).organization_id     := gn_master_orgid;
            ELSE
                msg (
                       'New Description "'
                    || lv_item_description
                    || '" matches with Old Description "'
                    || rec_csr_items.description
                    || '" for the Item :: '
                    || rec_csr_items.segment1);
                msg ('');
            END IF;
        END LOOP;


        fnd_msg_pub.delete_msg (NULL);
        ego_item_pub.process_items (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_true, p_item_tbl => l_item_table, x_item_tbl => x_item_table, x_return_status => x_return_status
                                    , x_msg_count => x_msg_count);


        FOR i IN 1 .. x_item_table.COUNT
        LOOP
            msg (
                '     => Return Status :: ' || x_item_table (i).return_status);

            IF (x_item_table (i).return_status = fnd_api.g_ret_sts_success)
            THEN
                msg (
                       '     => Item Description updated successfully for the Inventory Item "'
                    || TO_CHAR (x_item_table (i).segment1)
                    || '" Inventory Item ID: '
                    || TO_CHAR (x_item_table (i).inventory_item_id));

                msg ('');
            ELSE
                lv_item_desc_err_cnt   := lv_item_desc_err_cnt + 1;


                msg (
                       '     => Item Description update failed for the Inventory Item "'
                    || TO_CHAR (x_item_table (i).segment1)
                    || '" Inventory Item ID: '
                    || TO_CHAR (x_item_table (i).inventory_item_id));

                msg ('');

                BEGIN
                    INSERT INTO xxdo.xxdo_plm_item_upd_errors
                             VALUES (
                                        gn_record_id,
                                        g_style,
                                        g_colorway,
                                        gn_master_orgid,
                                           'Item Description update failed for the Inventory Item "'
                                        || TO_CHAR (
                                               x_item_table (i).segment1)
                                        || '" Inventory Item ID: '
                                        || TO_CHAR (
                                               x_item_table (i).inventory_item_id)
                                        || '. ',
                                        SYSDATE);

                    COMMIT;
                END;

                msg ('     => Error Messages: ');
                error_handler.get_message_list (
                    x_message_list => x_message_list);

                FOR i IN 1 .. x_message_list.COUNT
                LOOP
                    msg ('     => ' || x_message_list (i).MESSAGE_TEXT);
                END LOOP;

                msg ('');
            END IF;
        END LOOP;

        IF lv_item_desc_err_cnt = 0
        THEN
            pv_retcode    := 0;
            pv_reterror   := NULL;
        ELSE
            pv_retcode    := 1;
            pv_reterror   := SQLERRM;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;


            msg (
                   'Exception during Item Description Update '
                || SUBSTR (SQLERRM, 1, 200));
    END update_description;

    /****************************************************************************
    * Procedure Name    : update_poreq_item_desc
    *
    * Description       : Procedure to update PO Requisition Item description
    *
    * INPUT Parameters  : p_item_desc
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/

    PROCEDURE update_poreq_item_desc (p_item_desc VARCHAR2, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2)
    IS
        l_req_hdr         po_requisition_update_pub.req_hdr;
        l_req_line_tbl    po_requisition_update_pub.req_line_tbl;
        l_req_dist_tbl    po_requisition_update_pub.req_dist_tbl;

        l_return_status   VARCHAR2 (4000);
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (4000);
        l_req_po_cnt      NUMBER;
        l_intf_upd_cnt    NUMBER;
        l_req_upd_cnt     NUMBER;
        l_req_upd_temp    NUMBER;

        CURSOR cur_req_det IS
              SELECT prh.segment1, prh.org_id, prla.requisition_header_id,
                     prla.requisition_line_id, prla.line_num, msib.inventory_item_id
                FROM po_requisition_headers_all prh, po_requisition_lines_all prla, mtl_system_items_b msib
               WHERE     item_id = msib.inventory_item_id
                     AND prh.requisition_header_id = prla.requisition_header_id
                     AND prh.authorization_status NOT IN
                             ('CANCELLED', 'REJECTED')
                     AND msib.organization_id = gn_master_orgid -- STYLE_SEARCH - Start
                     AND (   (msib.segment1 LIKE g_item_search AND msib.attribute28 IN ('PROD', 'GENERIC'))
                          OR (msib.segment1 LIKE g_l_item_search)
                          OR (msib.segment1 LIKE g_r_item_search)
                          OR (msib.segment1 LIKE g_sr_item_search)
                          OR (msib.segment1 LIKE g_sl_item_search)
                          OR (msib.segment1 LIKE g_ss_item_search)
                          OR (    msib.segment1 LIKE g_s_item_search
                              AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                  'GENERIC'))
                          OR (msib.segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                                  )
            ORDER BY prh.creation_date DESC;
    BEGIN
        pv_retcode       := 0;
        pv_reterror      := NULL;
        l_intf_upd_cnt   := 0;
        l_req_upd_cnt    := 0;

        BEGIN
            UPDATE apps.po_requisitions_interface_all
               SET item_description   = p_item_desc
             WHERE item_id IN
                       (SELECT inventory_item_id
                          FROM apps.mtl_system_items_b -- STYLE_SEARCH - Start
                         WHERE (   (segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC'))
                                OR (segment1 LIKE g_l_item_search)
                                OR (segment1 LIKE g_r_item_search)
                                OR (segment1 LIKE g_sr_item_search)
                                OR (segment1 LIKE g_sl_item_search)
                                OR (segment1 LIKE g_ss_item_search)
                                OR (    segment1 LIKE g_s_item_search
                                    AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                        'GENERIC'))
                                OR (segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                                   ));

            l_intf_upd_cnt   := SQL%ROWCOUNT;

            COMMIT;

            IF l_intf_upd_cnt > 0
            THEN
                msg (
                       '     => Successfully Updated '
                    || l_intf_upd_cnt
                    || ' record(s) on PO_REQUISITIONS_INTERFACE_ALL Table with new Item Description');

                msg ('');
            END IF;
        END;

        FOR rec_cur_req_det IN cur_req_det
        LOOP
            l_req_po_cnt     := 0;
            l_req_upd_temp   := 0;

            SELECT COUNT (*)
              INTO l_req_po_cnt
              FROM po_headers_all pha, po_lines_all pla, po_distributions_all pda,
                   po_requisition_headers_all pra, po_requisition_lines_all prla, po_req_distributions_all prda
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pla.po_line_id = pda.po_line_id
                   AND pda.req_distribution_id = prda.distribution_id
                   AND prda.requisition_line_id = prla.requisition_line_id
                   AND prla.requisition_header_id = pra.requisition_header_id
                   AND prda.requisition_line_id =
                       rec_cur_req_det.requisition_line_id
                   AND prla.requisition_header_id =
                       rec_cur_req_det.requisition_header_id
                   AND pra.segment1 = rec_cur_req_det.segment1;

            IF l_req_po_cnt = 0
            THEN
                BEGIN
                    UPDATE apps.po_requisition_lines_all
                       SET item_description   = p_item_desc
                     WHERE     requisition_line_id =
                               rec_cur_req_det.requisition_line_id
                           AND requisition_header_id =
                               rec_cur_req_det.requisition_header_id;

                    l_req_upd_temp   := SQL%ROWCOUNT;
                    l_req_upd_cnt    := l_req_upd_cnt + l_req_upd_temp;

                    COMMIT;
                END;
            END IF;
        END LOOP;

        IF l_req_upd_cnt > 0
        THEN
            msg (
                   '     => Successfully Updated '
                || l_req_upd_cnt
                || ' record(s) on PO_REQUISITION_LINES_ALL Table with new Item Description');

            msg ('');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;


            msg (
                   'Exception during PO Requisition Item Description Update '
                || SUBSTR (SQLERRM, 1, 200));
    END update_poreq_item_desc;

    /****************************************************************************
    * Procedure Name    : get_category_set_details
    *
    * Description       : The purpose of this procedure is to fetch
    *                     category set details.
    *
    * INPUT Parameters  : pv_cat_set_name
    *
    * OUTPUT Parameters : pn_cat_set_id
    *                     pn_structure_id
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE get_category_set_details (pv_cat_set_name IN VARCHAR2, pn_cat_set_id OUT NUMBER, pn_structure_id OUT NUMBER)
    IS
    BEGIN
        SELECT category_set_id, structure_id
          INTO pn_cat_set_id, pn_structure_id
          FROM mtl_category_sets
         WHERE UPPER (category_set_name) = UPPER (pv_cat_set_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_cat_set_id     := NULL;
            pn_structure_id   := NULL;


            msg (
                   'Error while retrieving details for Category Set : '
                || pv_cat_set_name);
            msg (
                'Error Code : ' || SQLCODE || '. Error Message : ' || SQLERRM);
    END get_category_set_details;

    /****************************************************************************
    * Procedure Name    : create_price
    *
    * Description       : The purpose of this procedure to end date existing
    *                     OM Sales Category price list line and create a new
    *                     line with new Category.
    *
    * INPUT Parameters  : pv_style
    *                     pv_pricelistid
    *                     pv_list_line_id
    *                     pv_pricing_attr_id
    *                     pv_uom
    *                     pv_item_id
    *                     pn_org_id
    *                     pn_price
    *                     pv_begin_date
    *                     pv_end_date
    *                     pv_mode
    *                     pv_brand
    *                     pv_current_season
    *                     pv_precedence
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE create_price (pv_style VARCHAR2, pv_pricelistid NUMBER, pv_list_line_id NUMBER, pv_pricing_attr_id NUMBER, pv_uom VARCHAR2, pv_item_id VARCHAR2, pn_org_id NUMBER, pn_price NUMBER, pv_begin_date DATE, pv_end_date DATE, pv_mode VARCHAR2, pv_brand VARCHAR2, pv_current_season VARCHAR2, pv_precedence NUMBER, pv_retcode OUT VARCHAR2
                            , pv_reterror OUT VARCHAR2)
    IS
        lv_pn                       VARCHAR2 (240) := gv_package_name || '.create_price';
        ln_price                    NUMBER;
        lv_return_status            VARCHAR2 (1) := NULL;
        x_msg_count                 NUMBER := 0;
        x_return_status             VARCHAR2 (1) := NULL;
        ln_line_id                  NUMBER;
        x_msg_data                  VARCHAR2 (4000);
        lv_error_message            VARCHAR2 (4000);
        ld_begin_date               DATE;
        ld_end_date                 DATE;
        lv_structure_code           VARCHAR2 (100) := 'PRICELIST_ITEM_CATEGORIES';
        l_price_list_rec            qp_price_list_pub.price_list_rec_type;
        l_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        l_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
        l_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        l_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
        l_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
        l_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
        x_price_list_rec            qp_price_list_pub.price_list_rec_type;
        x_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
        k                           NUMBER := 1;
        j                           NUMBER := 1;
        ln_category_id              NUMBER := NULL;
        ln_sys_resp_id              NUMBER := apps.fnd_global.resp_id;
        ln_sys_appl_id              NUMBER := apps.fnd_global.resp_id;
        ln_msg_count                NUMBER := 0;


        ln_price_line_found         NUMBER := 0;            -- SAME_PLL_EXISTS
    BEGIN
        lv_error_message                                := NULL;
        x_return_status                                 := NULL;



        x_msg_count                                     := 0;
        x_msg_data                                      := NULL;
        pv_retcode                                      := NULL;
        pv_reterror                                     := NULL;
        l_price_list_rec.list_header_id                 := pv_pricelistid;
        l_price_list_rec.list_type_code                 := 'PRL';
        l_price_list_line_tbl (1).list_line_type_code   := 'PLL';
        l_price_list_line_tbl (1).list_header_id        := pv_pricelistid;



        LOG ('pv_mode : ' || pv_mode);
        LOG ('pv_pricelistid : ' || pv_pricelistid);
        LOG ('pv_item_id : ' || pv_item_id);
        LOG ('pv_begin_date : ' || pv_begin_date);
        LOG ('pv_end_date : ' || pv_end_date);
        LOG ('pn_price : ' || pn_price);
        LOG ('pv_brand : ' || pv_brand);
        LOG ('pv_current_season : ' || pv_current_season);


        -- SAME_PLL_EXISTS - Start
        BEGIN
            SELECT COUNT (1)
              INTO ln_price_line_found
              FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
             WHERE     qpa.list_line_id = qll.list_line_id
                   AND qll.list_header_id = qlh.list_header_id
                   AND qpa.product_attribute_context = 'ITEM'
                   AND qpa.product_attribute = 'PRICING_ATTRIBUTE2'
                   AND qpa.product_attr_value = TO_CHAR (pv_item_id)
                   AND qlh.list_header_id = pv_pricelistid
                   AND NVL (qll.start_date_active, '01-JAN-1960') =
                       NVL (pv_begin_date, '01-JAN-1960')
                   AND NVL (qll.end_date_active, '01-JAN-1960') =
                       NVL (pv_end_date, '01-JAN-1960')
                   AND qpa.product_uom_code = pv_uom
                   AND qll.operand = pn_price
                   AND NVL (qll.attribute1, 'X') = NVL (pv_brand, 'X')
                   AND NVL (qll.attribute2, 'X') =
                       NVL (pv_current_season, 'X');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_price_line_found   := 0;
        END;



        IF ln_price_line_found = 0
        THEN
            ld_begin_date                                      := pv_begin_date;



            IF pv_mode = 'CREATE'
            THEN
                l_price_list_line_tbl (1).operation            :=
                    qp_globals.g_opr_create;
                l_price_list_line_tbl (1).list_line_id         :=
                    fnd_api.g_miss_num;
                l_price_list_line_tbl (1).attribute1           := pv_brand;
                l_price_list_line_tbl (1).attribute2           := pv_current_season;
                l_price_list_line_tbl (1).product_precedence   :=
                    pv_precedence;


                l_pricing_attr_tbl (1).operation               :=
                    qp_globals.g_opr_create;
                l_pricing_attr_tbl (1).pricing_attribute_id    :=
                    fnd_api.g_miss_num;
                l_pricing_attr_tbl (1).list_line_id            :=
                    fnd_api.g_miss_num;
                l_pricing_attr_tbl (1).excluder_flag           := 'N';
                l_pricing_attr_tbl (1).attribute_grouping_no   := 1;


                l_pricing_attr_tbl (1).price_list_line_index   := 1;
            ELSE
                l_price_list_line_tbl (1).operation      :=
                    apps.qp_globals.g_opr_update;
                l_price_list_line_tbl (1).list_line_id   := pv_list_line_id;
                l_pricing_attr_tbl (1).operation         :=
                    apps.qp_globals.g_opr_update;
                l_pricing_attr_tbl (1).pricing_attribute_id   :=
                    pv_pricing_attr_id;
                l_pricing_attr_tbl (1).list_line_id      :=
                    pv_list_line_id;
            END IF;

            BEGIN
                SELECT responsibility_id, application_id
                  INTO ln_sys_resp_id, ln_sys_appl_id
                  FROM fnd_responsibility
                 WHERE responsibility_key =
                       apps.fnd_profile.VALUE ('XXDO_SYS_ADMIN_RESP');
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sys_resp_id   := apps.fnd_global.resp_id;
                    ln_sys_appl_id   := apps.fnd_global.prog_appl_id;
            END;

            apps.fnd_global.apps_initialize (apps.fnd_global.user_id,
                                             ln_sys_resp_id,
                                             ln_sys_appl_id);
            --          ld_begin_date:=nvl(pv_begin_date, '01-JAN-1960');
            l_price_list_line_tbl (1).operand                  := pn_price;
            l_price_list_line_tbl (1).arithmetic_operator      := 'UNIT_PRICE';
            l_price_list_line_tbl (1).start_date_active        := ld_begin_date;
            l_price_list_line_tbl (1).end_date_active          := pv_end_date;
            l_price_list_line_tbl (1).organization_id          := pn_org_id;
            l_pricing_attr_tbl (1).product_attribute_context   := 'ITEM';
            l_pricing_attr_tbl (1).product_attribute           :=
                'PRICING_ATTRIBUTE2';
            l_pricing_attr_tbl (1).product_attr_value          := pv_item_id;
            l_pricing_attr_tbl (1).product_uom_code            := pv_uom;



            fnd_msg_pub.delete_msg (NULL);
            qp_price_list_pub.process_price_list (
                p_api_version_number        => 1,
                p_init_msg_list             => fnd_api.g_true,
                p_return_values             => fnd_api.g_false,
                p_commit                    => fnd_api.g_false,
                x_return_status             => x_return_status,
                x_msg_count                 => ln_msg_count,
                x_msg_data                  => x_msg_data,
                p_price_list_rec            => l_price_list_rec,
                p_price_list_line_tbl       => l_price_list_line_tbl,
                p_pricing_attr_tbl          => l_pricing_attr_tbl,
                x_price_list_rec            => x_price_list_rec,
                x_price_list_val_rec        => x_price_list_val_rec,
                x_price_list_line_tbl       => x_price_list_line_tbl,
                x_qualifiers_tbl            => x_qualifiers_tbl,
                x_qualifiers_val_tbl        => x_qualifiers_val_tbl,
                x_pricing_attr_tbl          => x_pricing_attr_tbl,
                x_pricing_attr_val_tbl      => x_pricing_attr_val_tbl,
                x_price_list_line_val_tbl   => x_price_list_line_val_tbl);



            IF x_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
            ELSE
                INSERT INTO xxdo.xxdo_plm_item_upd_errors
                         VALUES (
                                    gn_record_id,
                                    g_style,
                                    g_colorway,
                                    l_price_list_line_tbl (1).organization_id,
                                       'Price List Error: Price List Header ID: '
                                    || l_price_list_rec.list_header_id
                                    || ' while processing List Line ID in '
                                    || pv_mode
                                    || ' mode. ',
                                    SYSDATE);

                COMMIT;

                FOR k IN 1 .. ln_msg_count
                LOOP
                    x_msg_data   :=
                        oe_msg_pub.get (p_msg_index => k, p_encoded => 'F');
                    lv_error_message   :=
                        SUBSTR (
                               'Error in API while loading list line with new category : '
                            || k
                            || ' is : '
                            || x_msg_data,
                            0,
                            1000);
                    msg (SUBSTR (lv_error_message, 1, 900));
                END LOOP;

                pv_retcode    := 2;
                pv_reterror   := SUBSTR (lv_error_message, 0, 1000);
            END IF;
        END IF;                                       -- SAME_PLL_EXISTS - End
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;
    END create_price;

    -- Start changes of V5.0
    /****************************************************************************
       * Procedure Name    :Update _price
       *
       * Description       : The purpose of this procedure to end date existing
       *                     OM Sales Category price list line
       *
       * INPUT Parameters  : pv_style
       *                     pv_pricelistid
       *                     pv_list_line_id
       *                     pv_pricing_attr_id
       *                     pv_uom
       *                     pv_item_id
       *                     pn_org_id
       *                     pn_price
       *                     pv_begin_date
       *                     pv_end_date
       *                     pv_mode
       *                     pv_brand
       *                     pv_current_season
       *                     pv_precedence
       *
       * OUTPUT Parameters : pv_retcode
       *                     pv_reterror
       *
       * DEVELOPMENT and MAINTENANCE HISTORY
       *
       * DATE          AUTHOR      Version     Description
       * ---------     -------     -------     ---------------
       * 8/23/2017    Arun N Murthy  5.0
       ****************************************************************************/
    PROCEDURE update_price (pv_style VARCHAR2, pv_pricelistid NUMBER, pv_list_line_id NUMBER, pv_pricing_attr_id NUMBER, pv_uom VARCHAR2, pv_item_id VARCHAR2, pn_org_id NUMBER, pn_price NUMBER, pv_begin_date DATE, pv_end_date DATE, pv_mode VARCHAR2, pv_brand VARCHAR2, pv_current_season VARCHAR2, pv_precedence NUMBER, pv_retcode OUT VARCHAR2
                            , pv_reterror OUT VARCHAR2)
    IS
        lv_pn                       VARCHAR2 (240) := gv_package_name || '.update_price';
        ln_price                    NUMBER;
        lv_return_status            VARCHAR2 (1) := NULL;
        x_msg_count                 NUMBER := 0;
        x_return_status             VARCHAR2 (1) := NULL;
        ln_line_id                  NUMBER;
        x_msg_data                  VARCHAR2 (4000);
        lv_error_message            VARCHAR2 (4000);
        ld_begin_date               DATE;
        ld_end_date                 DATE;
        lv_structure_code           VARCHAR2 (100) := 'PRICELIST_ITEM_CATEGORIES';
        l_price_list_rec            qp_price_list_pub.price_list_rec_type;
        l_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        l_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
        l_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        l_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
        l_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
        l_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
        x_price_list_rec            qp_price_list_pub.price_list_rec_type;
        x_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
        k                           NUMBER := 1;
        j                           NUMBER := 1;
        ln_category_id              NUMBER := NULL;
        ln_sys_resp_id              NUMBER := apps.fnd_global.resp_id;
        ln_sys_appl_id              NUMBER := apps.fnd_global.resp_id;
        ln_msg_count                NUMBER := 0;

        ln_price_line_found         NUMBER := 0;            -- SAME_PLL_EXISTS
    BEGIN
        l_price_list_line_tbl.delete;
        l_pricing_attr_tbl.delete;

        lv_error_message                              := NULL;
        x_return_status                               := NULL;
        x_msg_count                                   := 0;
        x_msg_data                                    := NULL;
        pv_retcode                                    := NULL;
        pv_reterror                                   := NULL;
        l_price_list_rec.operation                    := apps.qp_globals.g_opr_update;
        l_price_list_rec.list_header_id               := pv_pricelistid;
        l_price_list_rec.list_type_code               := 'PRL';
        --      l_price_list_line_tbl (1).list_line_type_code      := 'PLL';
        l_price_list_line_tbl (1).list_header_id      := pv_pricelistid;

        LOG ('pv_style : ' || pv_style);
        LOG ('pv_mode : ' || pv_mode);
        LOG ('pv_pricelistid : ' || pv_pricelistid);
        LOG ('pv_item_id : ' || pv_item_id);
        LOG ('pv_begin_date : ' || pv_begin_date);
        LOG ('pv_end_date : ' || pv_end_date);
        LOG ('pn_price : ' || pn_price);
        LOG ('pv_brand : ' || pv_brand);
        LOG ('pv_list_line_id : ' || pv_list_line_id);
        LOG ('pv_pricing_attr_id : ' || pv_pricing_attr_id);
        LOG ('pv_uom : ' || pv_uom);
        LOG ('pn_org_id : ' || pn_org_id);
        LOG ('pv_current_season : ' || pv_current_season);


        -- SAME_PLL_EXISTS - Start
        BEGIN
            SELECT COUNT (1)
              INTO ln_price_line_found
              FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
             WHERE     qpa.list_line_id = qll.list_line_id
                   AND qll.list_header_id = qlh.list_header_id
                   AND qpa.product_attribute_context = 'ITEM'
                   AND qpa.product_attribute = 'PRICING_ATTRIBUTE2'
                   AND qpa.product_attr_value = TO_CHAR (pv_item_id)
                   AND qlh.list_header_id = pv_pricelistid
                   AND NVL (qll.start_date_active,
                            TO_DATE ('01-JAN-1960', 'DD-MON-RRRR')) =
                       NVL (pv_begin_date,
                            TO_DATE ('01-JAN-1960', 'DD-MON-RRRR'))
                   AND NVL (qll.end_date_active, fnd_api.g_miss_date) =
                       NVL (pv_end_date, fnd_api.g_miss_date)
                   AND qpa.product_uom_code = pv_uom
                   AND qll.operand = pn_price
                   AND NVL (qll.attribute1, 'X') = NVL (pv_brand, 'X')
                   AND NVL (qll.attribute2, 'X') =
                       NVL (pv_current_season, 'X');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_price_line_found   := 0;
        END;


        IF ln_price_line_found != 0
        THEN
            IF pv_begin_date > SYSDATE
            THEN
                ld_begin_date   := pv_begin_date;
                ld_end_date     := pv_begin_date;
            ELSE
                ld_begin_date   := pv_begin_date;
                ld_end_date     :=
                    GREATEST (
                        NVL (ld_begin_date,
                             TO_DATE ('01-JAN-1960', 'DD-MON-RRRR')),
                        LEAST (
                            NVL (pv_end_date,
                                 TO_DATE ('31-MAR-4712', 'DD-MON-RRRR')),
                            SYSDATE));
            END IF;


            LOG ('ld_begin_date  -- ' || ld_begin_date);

            --                 l_price_list_line_tbl (1).operation            := qp_globals.g_opr_update;
            --                 l_price_list_line_tbl (1).list_line_id         := fnd_api.g_miss_num;
            --                 l_price_list_line_tbl (1).attribute1           := pv_brand;
            --                 l_price_list_line_tbl (1).attribute2           := pv_current_season;
            --                 l_price_list_line_tbl (1).product_precedence   := pv_precedence;
            --                 l_pricing_attr_tbl (1).excluder_flag           := 'N';
            --                 l_pricing_attr_tbl (1).attribute_grouping_no   := 1;
            --                 l_pricing_attr_tbl (1).price_list_line_index   := 1;
            l_price_list_line_tbl (1).operation      :=
                apps.qp_globals.g_opr_update;
            l_price_list_line_tbl (1).list_line_id   := pv_list_line_id;
            l_pricing_attr_tbl (1).operation         :=
                apps.qp_globals.g_opr_update;
            l_pricing_attr_tbl (1).pricing_attribute_id   :=
                pv_pricing_attr_id;
        --                 l_pricing_attr_tbl (1).list_line_id           := pv_list_line_id;
        END IF;

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_sys_resp_id, ln_sys_appl_id
              FROM fnd_responsibility
             WHERE responsibility_key =
                   apps.fnd_profile.VALUE ('XXDO_SYS_ADMIN_RESP');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_sys_resp_id   := apps.fnd_global.resp_id;
                ln_sys_appl_id   := apps.fnd_global.prog_appl_id;
        END;

        apps.fnd_global.apps_initialize (apps.fnd_global.user_id,
                                         ln_sys_resp_id,
                                         ln_sys_appl_id);
        l_price_list_line_tbl (1).operand             :=
            NVL (pn_price, fnd_api.g_miss_num);
        --              l_price_list_line_tbl (1).arithmetic_operator      := 'UNIT_PRICE';
        l_price_list_line_tbl (1).start_date_active   := ld_begin_date;
        l_price_list_line_tbl (1).end_date_active     := ld_end_date;
        LOG (
               'ANM begin_date  -- '
            || l_price_list_line_tbl (1).start_date_active);
        LOG (
            'ANM End_date  -- ' || l_price_list_line_tbl (1).end_date_active);
        --              l_price_list_line_tbl (1).organization_id          := pn_org_id;
        --              l_pricing_attr_tbl (1).product_attribute_context   := 'ITEM';
        --              l_pricing_attr_tbl(1).pricing_attribute_id         := pn_pricing_attribute_id;
        --              l_pricing_attr_tbl (1).product_attribute           :=
        --                 'PRICING_ATTRIBUTE2';
        --              l_pricing_attr_tbl (1).product_attr_value          := pv_item_id;
        l_pricing_attr_tbl (1).product_uom_code       := pv_uom;



        fnd_msg_pub.delete_msg (NULL);
        qp_price_list_pub.process_price_list (
            p_api_version_number        => 1,
            p_init_msg_list             => fnd_api.g_true,
            p_return_values             => fnd_api.g_false,
            p_commit                    => fnd_api.g_false,
            x_return_status             => x_return_status,
            x_msg_count                 => ln_msg_count,
            x_msg_data                  => x_msg_data,
            p_price_list_rec            => l_price_list_rec,
            p_price_list_line_tbl       => l_price_list_line_tbl,
            p_pricing_attr_tbl          => l_pricing_attr_tbl,
            x_price_list_rec            => x_price_list_rec,
            x_price_list_val_rec        => x_price_list_val_rec,
            x_price_list_line_tbl       => x_price_list_line_tbl,
            x_qualifiers_tbl            => x_qualifiers_tbl,
            x_qualifiers_val_tbl        => x_qualifiers_val_tbl,
            x_pricing_attr_tbl          => x_pricing_attr_tbl,
            x_pricing_attr_val_tbl      => x_pricing_attr_val_tbl,
            x_price_list_line_val_tbl   => x_price_list_line_val_tbl);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            COMMIT;
        ELSE
            FOR k IN 1 .. ln_msg_count
            LOOP
                x_msg_data   :=
                    oe_msg_pub.get (p_msg_index => k, p_encoded => 'F');
                lv_error_message   :=
                    SUBSTR (
                           'Error in API while end dating the list line with old category : '
                        || k
                        || ' is : '
                        || x_msg_data,
                        0,
                        1000);
                msg (SUBSTR (lv_error_message, 1, 900));
            END LOOP;

            INSERT INTO xxdo.xxdo_plm_item_upd_errors
                     VALUES (
                                gn_record_id,
                                g_style,
                                g_colorway,
                                l_price_list_line_tbl (1).organization_id,
                                   'Price List Error: Price List Header ID: '
                                || l_price_list_rec.list_header_id
                                || ' while processing List Line ID in '
                                || pv_mode
                                || ' mode. '
                                || x_msg_data,
                                SYSDATE);

            COMMIT;

            pv_retcode    := 2;
            pv_reterror   := SUBSTR (lv_error_message, 0, 1000);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;
    END update_price;

    --End Changes of V5.0



    /****************************************************************************
    * Procedure Name    : validate_valueset
    *
    * Description       : The purpose of this procedure to maintain
    *                     value set values.
    *
    * INPUT Parameters  : pv_segment1
    *                     pv_value_set
    *                     pv_description
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *                     pv_final_value
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE validate_valueset (pv_segment1 VARCHAR2, pv_value_set VARCHAR2, pv_description VARCHAR2
                                 , pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2, pv_final_value OUT VARCHAR2)
    IS
        lv_pn                    VARCHAR2 (240) := gv_package_name || '.validate_valueset';
        ln_styleflexvalueid      NUMBER;
        ln_styleflexvaluesetid   NUMBER;
        lv_row_id                VARCHAR2 (100);
        ln_description           VARCHAR2 (1000);
        lv_flex_values           fnd_flex_values_vl%ROWTYPE;
        lv_flex_value            VARCHAR2 (150) := NULL;
        lv_description           VARCHAR2 (1000);
    BEGIN
        BEGIN
            SELECT flex_value_set_id
              INTO ln_styleflexvaluesetid
              FROM apps.fnd_flex_value_sets
             WHERE UPPER (flex_value_set_name) = UPPER (pv_value_set);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_retcode   := SQLCODE;
                pv_reterror   :=
                    pv_value_set || ' Flex value not present ' || SQLERRM;
            WHEN OTHERS
            THEN
                pv_retcode   := SQLCODE;
                pv_reterror   :=
                       ' Error occurred while fetching flex value set id for value set :: '
                    || pv_value_set
                    || ' '
                    || SQLERRM;
        END;

        pv_final_value   := NULL;

        BEGIN
            SELECT flex_value
              INTO pv_final_value
              FROM apps.fnd_flex_values_vl
             WHERE     flex_value_set_id = ln_styleflexvaluesetid
                   AND flex_value = TRIM (pv_segment1)
                   AND NVL (enabled_flag, 'Y') = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_final_value   := NULL;

                BEGIN
                    SELECT flex_value
                      INTO pv_final_value
                      FROM apps.fnd_flex_values_vl
                     WHERE     flex_value_set_id = ln_styleflexvaluesetid
                           AND flex_value =
                               TO_CHAR (TRIM (UPPER (pv_segment1)))
                           AND NVL (enabled_flag, 'Y') = 'Y';
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        BEGIN
                            SELECT apps.fnd_flex_values_s.NEXTVAL
                              INTO ln_styleflexvalueid
                              FROM DUAL;

                            --*****************************************
                            -- Inserting values to value set
                            --*****************************************
                            fnd_msg_pub.delete_msg (NULL);
                            apps.fnd_flex_values_pkg.insert_row (
                                x_rowid                        => lv_row_id,
                                x_flex_value_id                => ln_styleflexvalueid,
                                x_attribute_sort_order         => NULL,
                                x_flex_value_set_id            =>
                                    ln_styleflexvaluesetid,
                                x_flex_value                   =>
                                    UPPER (TRIM (pv_segment1)),
                                x_enabled_flag                 => 'Y',
                                x_summary_flag                 => 'N',
                                x_start_date_active            => NULL,
                                x_end_date_active              => NULL,
                                x_parent_flex_value_low        => NULL,
                                x_parent_flex_value_high       => NULL,
                                x_structured_hierarchy_level   => NULL,
                                x_hierarchy_level              => NULL,
                                x_compiled_value_attributes    => NULL,
                                x_value_category               => NULL,
                                x_attribute1                   => NULL,
                                x_attribute2                   => NULL,
                                x_attribute3                   => NULL,
                                x_attribute4                   => NULL,
                                x_attribute5                   => NULL,
                                x_attribute6                   => NULL,
                                x_attribute7                   => NULL,
                                x_attribute8                   => NULL,
                                x_attribute9                   => NULL,
                                x_attribute10                  => NULL,
                                x_attribute11                  => NULL,
                                x_attribute12                  => NULL,
                                x_attribute13                  => NULL,
                                x_attribute14                  => NULL,
                                x_attribute15                  => NULL,
                                x_attribute16                  => NULL,
                                x_attribute17                  => NULL,
                                x_attribute18                  => NULL,
                                x_attribute19                  => NULL,
                                x_attribute20                  => NULL,
                                x_attribute21                  => NULL,
                                x_attribute22                  => NULL,
                                x_attribute23                  => NULL,
                                x_attribute24                  => NULL,
                                x_attribute25                  => NULL,
                                x_attribute26                  => NULL,
                                x_attribute27                  => NULL,
                                x_attribute28                  => NULL,
                                x_attribute29                  => NULL,
                                x_attribute30                  => NULL,
                                x_attribute31                  => NULL,
                                x_attribute32                  => NULL,
                                x_attribute33                  => NULL,
                                x_attribute34                  => NULL,
                                x_attribute35                  => NULL,
                                x_attribute36                  => NULL,
                                x_attribute37                  => NULL,
                                x_attribute38                  => NULL,
                                x_attribute39                  => NULL,
                                x_attribute40                  => NULL,
                                x_attribute41                  => NULL,
                                x_attribute42                  => NULL,
                                x_attribute43                  => NULL,
                                x_attribute44                  => NULL,
                                x_attribute45                  => NULL,
                                x_attribute46                  => NULL,
                                x_attribute47                  => NULL,
                                x_attribute48                  => NULL,
                                x_attribute49                  => NULL,
                                x_attribute50                  => NULL,
                                x_flex_value_meaning           =>
                                    UPPER (TRIM (pv_segment1)),
                                x_description                  =>
                                    pv_description,
                                x_creation_date                => SYSDATE,
                                x_created_by                   => gn_userid,
                                x_last_update_date             => SYSDATE,
                                x_last_updated_by              => gn_userid,
                                x_last_update_login            =>
                                    apps.fnd_global.login_id);
                            COMMIT;
                            pv_final_value   := UPPER (TRIM (pv_segment1));


                            msg (
                                   '      => Newly created valueset value : '
                                || pv_final_value);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_final_value   := NULL;
                                pv_retcode       := SQLCODE;

                                pv_reterror      :=
                                       'Error In validate_valueset while Creating value set '
                                    || pv_value_set
                                    || ' when other exception : '
                                    || SQLERRM;
                                msg (pv_reterror);
                        END;
                    WHEN OTHERS
                    THEN
                        pv_final_value   := NULL;
                        pv_retcode       := SQLCODE;
                        pv_reterror      :=
                               'Error In Fetching Validation Value in Upper Case :: '
                            || SQLERRM;
                END;
            WHEN OTHERS
            THEN
                pv_final_value   := NULL;
                pv_retcode       := SQLCODE;
                pv_reterror      :=
                    'Error In fetching Flex Value :: ' || SQLERRM;
        END;
    END validate_valueset;

    /****************************************************************************
    * Procedure Name    : validate_lookup_val
    *
    * Description       : The purpose of this procedure to create new values
    *                     to the lookup.
    *
    * INPUT Parameters  : pv_lookup_type
    *                     pv_lookup_code
    *                     pv_lookup_mean
    *
    * OUTPUT Parameters : pv_reterror
    *                     pv_retcode
    *                     pv_final_code
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE validate_lookup_val (pv_lookup_type IN VARCHAR2, pv_lookup_code IN VARCHAR2, pv_lookup_mean IN VARCHAR2
                                   , pv_reterror OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_final_code OUT VARCHAR2)
    IS
        CURSOR get_lookup_details IS
            SELECT ltype.application_id, ltype.customization_level, ltype.creation_date,
                   ltype.created_by, ltype.last_update_date, ltype.last_updated_by,
                   ltype.last_update_login, tl.lookup_type, tl.security_group_id,
                   tl.view_application_id, tl.description, tl.meaning
              FROM fnd_lookup_types_tl tl, fnd_lookup_types ltype
             WHERE     ltype.lookup_type = pv_lookup_type
                   AND ltype.lookup_type = tl.lookup_type
                   AND language = 'US';

        l_rowid          VARCHAR2 (100) := 0;
        lv_exists        VARCHAR2 (1) := 'Y';
        lv_lookup_code   VARCHAR2 (30) := NULL;
    BEGIN
        BEGIN
            SELECT lookup_code
              INTO pv_final_code
              FROM fnd_lookup_values
             WHERE     lookup_type = pv_lookup_type
                   AND UPPER (lookup_code) = UPPER (pv_lookup_code)
                   AND language = 'US'
                   AND enabled_flag = 'Y'
                   AND NVL (start_date_active, TRUNC (SYSDATE - 1)) >=
                       NVL (start_date_active, TRUNC (SYSDATE - 1))
                   AND NVL (end_date_active, TRUNC (SYSDATE + 1)) <=
                       NVL (end_date_active, TRUNC (SYSDATE + 1));
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_exists   := 'N';
            WHEN OTHERS
            THEN
                lv_exists   := NULL;


                msg (
                       'Error in Fetching Lookup Code in lookup :: '
                    || pv_lookup_type
                    || ' :: '
                    || SQLERRM);
        END;

        IF lv_exists = 'N'
        THEN
            FOR i IN get_lookup_details
            LOOP
                l_rowid   := NULL;

                BEGIN
                    fnd_msg_pub.delete_msg (NULL);
                    fnd_lookup_values_pkg.insert_row (
                        x_rowid                 => l_rowid,
                        x_lookup_type           => i.lookup_type,
                        x_security_group_id     => i.security_group_id,
                        x_view_application_id   => i.view_application_id,
                        x_lookup_code           => pv_lookup_code,
                        x_tag                   => NULL,
                        x_attribute_category    => NULL,
                        x_attribute1            => NULL,
                        x_attribute2            => NULL,
                        x_attribute3            => NULL,
                        x_attribute4            => NULL,
                        x_enabled_flag          => 'Y',
                        x_start_date_active     =>
                            TO_DATE ('01-JAN-1950', 'DD-MON-YYYY'),
                        x_end_date_active       => NULL,
                        x_territory_code        => NULL,
                        x_attribute5            => NULL,
                        x_attribute6            => NULL,
                        x_attribute7            => NULL,
                        x_attribute8            => NULL,
                        x_attribute9            => NULL,
                        x_attribute10           => NULL,
                        x_attribute11           => NULL,
                        x_attribute12           => NULL,
                        x_attribute13           => NULL,
                        x_attribute14           => NULL,
                        x_attribute15           => NULL,
                        x_meaning               => pv_lookup_mean,
                        x_description           => pv_lookup_code,
                        x_creation_date         => SYSDATE,
                        x_created_by            => i.created_by,
                        x_last_update_date      => i.last_update_date,
                        x_last_updated_by       => i.last_updated_by,
                        x_last_update_login     => i.last_update_login);
                    COMMIT;
                    pv_final_code   := pv_lookup_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                               'validate_lookup_val Inner Exception: '
                            || SQLERRM);
                END;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;
            msg ('Exception occurred in validate_lookup_val : ' || SQLERRM);
    END validate_lookup_val;

    /****************************************************************************
    * Procedure Name    : create_inventory_category
    *
    * Description       : The purpose of this procedure to create inventory
    *                     category.
    *
    * INPUT Parameters  : pv_brand
    *                     pv_gender
    *                     pv_prodsubgroup
    *                     pv_class
    *                     pv_sub_class
    *                     pv_master_style
    *                     pv_style_name
    *                     pv_colorway
    *                     pv_clrway
    *                     pv_sub_division
    *                     pv_detail_silhouette
    *                     pv_style
    *                     pv_structure_id
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE create_inventory_category (pv_brand VARCHAR2, pv_gender VARCHAR2, pv_prodsubgroup VARCHAR2, pv_class VARCHAR2, pv_sub_class VARCHAR2, pv_master_style VARCHAR2, pv_style_name VARCHAR2, pv_colorway VARCHAR2, pv_clrway VARCHAR2, pv_sub_division VARCHAR2, pv_detail_silhouette VARCHAR2, pv_style VARCHAR2
                                         , pv_structure_id NUMBER, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2)
    IS
        lv_pn                  VARCHAR2 (240)
                                   := gv_package_name || '.create_inventory_category';
        ln_inventorycatid      NUMBER;
        lv_category            apps.inv_item_category_pub.category_rec_type;
        lv_ret_status          VARCHAR2 (1);
        lv_error_code          NUMBER;
        x_msg_count            NUMBER;
        lv_msg_data            VARCHAR2 (2000);
        ln_category_id         VARCHAR2 (40);
        ln_cat_set_id          NUMBER;
        ln_structure_id        NUMBER;
        lv_message             VARCHAR2 (2000);
        ln_msg_count           NUMBER;
        lv_tax_category        VARCHAR2 (100);
        lv_sub_division        VARCHAR2 (100);
        lv_detail_silhouette   VARCHAR2 (100);
        l_dte_disable_date     DATE;
    BEGIN
        x_msg_count         := 0;
        ln_msg_count        := 0;
        ln_cat_set_id       := gn_inventory_set_id;
        ln_structure_id     := gn_inventory_structure_id;
        ln_inventorycatid   := NULL;



        BEGIN
            SELECT category_id, disable_date
              INTO ln_inventorycatid, l_dte_disable_date
              FROM apps.mtl_categories
             WHERE     segment1 = pv_brand
                   AND segment2 = pv_gender
                   AND segment3 = pv_prodsubgroup
                   AND segment4 = pv_class
                   AND segment5 = pv_sub_class
                   AND segment6 = pv_master_style
                   AND segment7 = pv_style_name
                   AND segment8 = pv_colorway
                   AND structure_id = ln_structure_id
                   AND NVL (enabled_flag, 'Y') = 'Y';


            -- ENABLE_OLD_CATEGORY -- Start
            IF NVL (l_dte_disable_date, SYSDATE + 1) < SYSDATE
            THEN
                -- Logic to enable the old category
                enable_category (ln_inventorycatid, gv_retcode, gv_reterror);



                IF (gv_retcode IS NULL AND gv_reterror IS NULL)
                THEN
                    msg (
                           '     => Old Inventory Item Category ID "'
                        || ln_inventorycatid
                        || '" has been enabled successfully. ');



                    msg ('');
                END IF;
            END IF;
        -- ENABLE_OLD_CATEGORY -- End



        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                      SELECT mc.attribute1, mc.attribute5, mc.attribute6
                        INTO lv_tax_category, lv_sub_division, lv_detail_silhouette
                        FROM mtl_categories_b mc, mtl_item_categories mic, mtl_system_items_b msib
                       WHERE     mc.category_id = mic.category_id
                             AND mic.inventory_item_id = msib.inventory_item_id
                             AND msib.organization_id = 106
                             AND msib.segment1 LIKE
                                     pv_style || '-' || pv_clrway || '%'
                             AND mc.attribute7 = pv_style
                             AND mc.attribute8 = pv_clrway
                             AND mc.structure_id = 101
                    GROUP BY mc.attribute1, mc.attribute5, mc.attribute6;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_tax_category        := NULL;
                        lv_sub_division        := NULL;
                        lv_detail_silhouette   := NULL;
                    WHEN OTHERS
                    THEN
                        lv_tax_category        := NULL;
                        lv_sub_division        := NULL;
                        lv_detail_silhouette   := NULL;


                        msg (
                               'Exception occurred while retreiving Category DFF Details :: '
                            || SQLERRM);
                END;

                BEGIN
                    lv_category.structure_id         := ln_structure_id;
                    lv_category.segment1             := pv_brand;
                    lv_category.segment2             := pv_gender;
                    lv_category.segment3             := pv_prodsubgroup;
                    lv_category.segment4             := pv_class;
                    lv_category.segment5             := pv_sub_class;
                    lv_category.segment6             := pv_master_style;
                    lv_category.segment7             := pv_style_name;
                    lv_category.segment8             := pv_colorway;
                    lv_category.start_date_active    := SYSDATE;
                    lv_category.description          :=
                           pv_brand
                        || '.'
                        || pv_gender
                        || '.'
                        || pv_prodsubgroup
                        || '.'
                        || pv_class
                        || '.'
                        || pv_sub_class
                        || '.'
                        || pv_master_style
                        || '.'
                        || pv_style_name
                        || '.'
                        || pv_colorway;
                    lv_category.attribute_category   := 'Item Categories';
                    lv_category.attribute1           := lv_tax_category;
                    lv_category.attribute5           :=
                        NVL (pv_sub_division, lv_sub_division);
                    lv_category.attribute6           :=
                        NVL (pv_detail_silhouette, lv_detail_silhouette);
                    lv_category.attribute7           := pv_style;
                    lv_category.attribute8           := pv_clrway;
                    lv_category.summary_flag         := 'N';
                    lv_category.enabled_flag         := 'Y';
                    /************************************************************
                    calling API to create inventory category
                    **************************************************************/
                    fnd_msg_pub.delete_msg (NULL);
                    apps.inv_item_category_pub.create_category (
                        p_api_version     => 1.0,
                        p_init_msg_list   => apps.fnd_api.g_true,
                        x_return_status   => lv_ret_status,
                        x_errorcode       => lv_error_code,
                        x_msg_count       => ln_msg_count,
                        x_msg_data        => lv_msg_data,
                        p_category_rec    => lv_category,
                        x_category_id     => ln_category_id);
                    COMMIT;
                    LOG ('New Inventory Category ID : ' || ln_category_id);

                    IF (lv_ret_status <> apps.wsh_util_core.g_ret_sts_success)
                    THEN
                        FOR i IN 1 .. ln_msg_count
                        LOOP
                            lv_message   := apps.fnd_msg_pub.get (i, 'F');
                            lv_message   :=
                                REPLACE (lv_msg_data, CHR (0), ' ');



                            msg (
                                SUBSTR (
                                       'Inside create_inventory_category Error  '
                                    || lv_message,
                                    1,
                                    900));
                        END LOOP;

                        pv_retcode    := SQLCODE;
                        pv_reterror   := lv_message;
                        apps.fnd_msg_pub.delete_msg ();
                    END IF;


                    ln_msg_count                     := 0;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := SQLCODE;
                        pv_reterror   :=
                            'Error in ' || lv_pn || '  ' || SQLERRM;
                END;
            WHEN TOO_MANY_ROWS
            THEN
                ln_inventorycatid   := NULL;
                pv_retcode          := SQLCODE;
                pv_reterror         :=
                       'Multiple categories found for the style : '
                    || gv_plm_style
                    || ' : '
                    || SQLERRM;
            WHEN OTHERS
            THEN
                ln_inventorycatid   := NULL;
                pv_retcode          := SQLCODE;
                pv_reterror         :=
                    'Error in ' || lv_pn || '  ' || SQLERRM;
        END;

        IF ln_inventorycatid IS NOT NULL AND pv_clrway IS NOT NULL
        THEN
            BEGIN
                lv_category.category_id          := ln_inventorycatid;
                lv_category.attribute_category   := 'Item Categories';
                lv_category.attribute5           := pv_sub_division;
                lv_category.attribute6           := pv_detail_silhouette;
                lv_category.attribute7           := pv_style;
                lv_category.attribute8           := pv_clrway;
                fnd_msg_pub.delete_msg (NULL);
                apps.inv_item_category_pub.update_category (
                    p_api_version     => 1.0,
                    p_init_msg_list   => apps.fnd_api.g_true,
                    p_commit          => apps.fnd_api.g_true,
                    x_return_status   => lv_ret_status,
                    x_errorcode       => lv_error_code,
                    x_msg_count       => ln_msg_count,
                    x_msg_data        => lv_msg_data,
                    p_category_rec    => lv_category);

                IF (lv_ret_status <> apps.wsh_util_core.g_ret_sts_success)
                THEN
                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lv_message   := apps.fnd_msg_pub.get (i, 'F');
                        lv_message   := REPLACE (lv_msg_data, CHR (0), ' ');



                        msg (
                            SUBSTR (
                                   'Inside update_category Error  '
                                || lv_message,
                                1,
                                900));
                    END LOOP;

                    pv_retcode    := SQLCODE;
                    pv_reterror   := lv_message;
                    apps.fnd_msg_pub.delete_msg ();
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error while Updating Inventory Category :: '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                'Error in Create Inventory Category Procedure :: ' || SQLERRM);
    END create_inventory_category;

    /****************************************************************************
    * Procedure Name    : create_category
    *
    * Description       : This procedure is to create OM Sales and PO Item
    *                     categories.
    *
    * INPUT Parameters  : pv_segment1
    *                     pv_segment2
    *                     pv_segment3
    *                     pv_segment4
    *                     pv_segment5
    *                     pv_category_set
    *                     pv_structure_id
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE create_category (pv_segment1 VARCHAR2, pv_segment2 VARCHAR2, pv_segment3 VARCHAR2, pv_segment4 VARCHAR2, pv_segment5 VARCHAR2, pv_category_set VARCHAR2
                               , pv_structure_id NUMBER, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2)
    IS
        lv_pn                VARCHAR2 (240) := gv_package_name || '.create_category';
        ln_stylecatid        NUMBER;
        lv_category          apps.inv_item_category_pub.category_rec_type;
        lv_ret_status        VARCHAR2 (1);
        lv_error_code        NUMBER;
        x_msg_count          NUMBER;
        ln_cat_set_id        NUMBER;
        ln_cat_struc_id      NUMBER;
        lv_msg_data          VARCHAR2 (2000);
        lv_message           VARCHAR2 (2000);
        ln_category_id       NUMBER;
        lv_segment1          VARCHAR2 (500) := pv_segment1;
        lv_segment2          VARCHAR2 (500) := pv_segment2;
        lv_segment3          VARCHAR2 (500) := pv_segment3;
        lv_segment4          VARCHAR2 (500) := pv_segment4;
        lv_segment5          VARCHAR2 (500) := pv_segment5;
        ln_msg_count         NUMBER;
        l_dte_disable_date   DATE;        -- ENABLE_OLD_CATEGORY - Start - End
    BEGIN
        x_msg_count    := 0;
        ln_msg_count   := 0;

        BEGIN
            IF pv_category_set = 'OM Sales Category'
            THEN
                lv_category.segment1      := lv_segment1;
                lv_category.description   := lv_segment1;
                ln_cat_struc_id           := gn_om_sales_structure_id;

                SELECT category_id, disable_date
                  INTO ln_category_id, l_dte_disable_date
                  FROM apps.mtl_categories
                 WHERE     segment1 = lv_segment1
                       AND structure_id = ln_cat_struc_id
                       AND NVL (enabled_flag, 'Y') = 'Y';
            ELSIF pv_category_set = 'PO Item Category'
            THEN
                lv_category.segment1      := lv_segment1;
                lv_category.segment2      := lv_segment2;
                lv_category.segment3      := lv_segment3;
                lv_category.description   :=
                    lv_segment1 || '.' || lv_segment2 || '.' || lv_segment3;
                ln_cat_struc_id           := gn_po_item_structure_id;

                SELECT category_id, disable_date
                  INTO ln_category_id, l_dte_disable_date
                  FROM apps.mtl_categories
                 WHERE     segment1 = lv_segment1
                       AND segment2 = lv_segment2
                       AND segment3 = lv_segment3
                       AND structure_id = ln_cat_struc_id
                       AND NVL (enabled_flag, 'Y') = 'Y';
            END IF;


            -- ENABLE_OLD_CATEGORY -- Start
            IF NVL (l_dte_disable_date, SYSDATE + 1) < SYSDATE
            THEN
                -- Logic to enable the old category
                enable_category (ln_category_id, gv_retcode, gv_reterror);



                IF (gv_retcode IS NULL AND gv_reterror IS NULL)
                THEN
                    msg (
                           '     => Old Category ID "'
                        || ln_category_id
                        || '" has been enabled successfully. ');



                    msg ('');
                END IF;
            END IF;
        -- ENABLE_OLD_CATEGORY -- End


        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    lv_category.structure_id   := ln_cat_struc_id;
                    lv_category.summary_flag   := 'N';
                    lv_category.enabled_flag   := 'Y';
                    /***************************************************************
                    calling API to create category
                    ****************************************************************/
                    fnd_msg_pub.delete_msg (NULL);
                    apps.inv_item_category_pub.create_category (
                        p_api_version     => '1.0',
                        p_init_msg_list   => apps.fnd_api.g_true,
                        p_commit          => apps.fnd_api.g_false,
                        x_return_status   => lv_ret_status,
                        x_errorcode       => lv_error_code,
                        x_msg_count       => ln_msg_count,
                        x_msg_data        => lv_msg_data,
                        p_category_rec    => lv_category,
                        x_category_id     => ln_category_id);


                    COMMIT;
                    LOG (
                           'New '
                        || pv_category_set
                        || ' ID : '
                        || ln_category_id);

                    IF (lv_ret_status <> apps.wsh_util_core.g_ret_sts_success)
                    THEN
                        FOR i IN 1 .. ln_msg_count
                        LOOP
                            lv_message   := apps.fnd_msg_pub.get (i, 'F');

                            lv_message   :=
                                SUBSTR (REPLACE (lv_msg_data, CHR (0), ' '),
                                        2000);
                        END LOOP;



                        msg (
                            SUBSTR (
                                ' Error in create_category  ' || lv_message,
                                1,
                                900));
                        pv_retcode    := SQLCODE;
                        pv_reterror   := lv_message;
                        apps.fnd_msg_pub.delete_msg ();
                    END IF;


                    ln_msg_count               := 0;
                    apps.fnd_msg_pub.delete_msg ();
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode    := SQLCODE;
                        pv_reterror   := 'Error in' || lv_pn || SQLERRM;
                END;
            WHEN TOO_MANY_ROWS
            THEN
                pv_retcode   := SQLCODE;
                pv_reterror   :=
                       'Multiple categories found for the style : '
                    || gv_plm_style
                    || ' in '
                    || lv_pn
                    || SQLERRM;
            WHEN OTHERS
            THEN
                pv_retcode    := SQLCODE;
                pv_reterror   := 'Error in' || lv_pn || SQLERRM;
        END;
    END create_category;

    /****************************************************************************
    * Procedure Name    : update_category
    *
    * Description       : This procedure is to update Disable Date for categories.
    *
    * INPUT Parameters  : pv_category_id
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE update_category (pv_category_id NUMBER, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2)
    IS
        lv_pn              VARCHAR2 (240) := gv_package_name || '.update_category';
        lv_category_rec    apps.inv_item_category_pub.category_rec_type;
        ln_sys_resp_id     NUMBER := apps.fnd_global.resp_id;
        ln_sys_appl_id     NUMBER := apps.fnd_global.resp_id;
        ln_category_id     NUMBER := 0;
        x_return_status    VARCHAR2 (1) := NULL;
        x_msg_count        NUMBER := 0;
        x_errorcode        NUMBER := 0;
        x_msg_data         VARCHAR2 (4000);
        lv_error_message   VARCHAR2 (4000);
        ln_msg_count       NUMBER := 0;
    BEGIN
        lv_error_message               := NULL;
        x_return_status                := NULL;
        x_msg_count                    := 0;
        x_msg_data                     := NULL;
        pv_retcode                     := NULL;
        pv_reterror                    := NULL;
        ln_category_id                 := pv_category_id;


        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_sys_resp_id, ln_sys_appl_id
              FROM fnd_responsibility
             WHERE responsibility_key =
                   apps.fnd_profile.VALUE ('XXDO_SYS_ADMIN_RESP');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_sys_resp_id   := apps.fnd_global.resp_id;
                ln_sys_appl_id   := apps.fnd_global.prog_appl_id;
        END;

        apps.fnd_global.apps_initialize (apps.fnd_global.user_id,
                                         ln_sys_resp_id,
                                         ln_sys_appl_id);


        lv_category_rec.category_id    := ln_category_id;
        lv_category_rec.disable_date   := SYSDATE;

        -- Calling the api to update category --
        fnd_msg_pub.delete_msg (NULL);
        inv_item_category_pub.update_category (
            p_api_version     => 1.0,
            p_init_msg_list   => fnd_api.g_true,
            p_commit          => fnd_api.g_false,
            x_return_status   => x_return_status,
            x_errorcode       => x_errorcode,
            x_msg_count       => ln_msg_count,
            x_msg_data        => x_msg_data,
            p_category_rec    => lv_category_rec);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            COMMIT;
        ELSE
            INSERT INTO xxdo.xxdo_plm_item_upd_errors
                     VALUES (
                                gn_record_id,
                                g_style,
                                g_colorway,
                                gn_master_orgid,
                                   'Old Category Update Error: Category ID: '
                                || lv_category_rec.category_id
                                || ' while updating disable date. ',
                                SYSDATE);

            COMMIT;

            FOR k IN 1 .. ln_msg_count
            LOOP
                --            x_msg_data   := oe_msg_pub.get (p_msg_index => k, p_encoded => 'F'); --INIT_API_MSG_LIST - Start
                x_msg_data   :=
                    fnd_msg_pub.get (p_msg_index => k, p_encoded => 'F'); --INIT_API_MSG_LIST - End

                lv_error_message   :=
                    SUBSTR (
                           'Error in API while updating disable date for category : '
                        || k
                        || ' is : '
                        || x_msg_data,
                        0,
                        1000);
                msg (SUBSTR (lv_error_message, 1, 900));
            END LOOP;

            pv_retcode    := 2;
            pv_reterror   := SUBSTR (lv_error_message, 0, 1000);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;
    END update_category;

    /****************************************************************************
    * Procedure Name    : assign_inventory_category
    *
    * Description       : The purpose of this procedure to assign inventory
    *                     category to Item.
    *
    * INPUT Parameters  : pv_brand
    *                     pv_division
    *                     pv_sub_group
    *                     pv_class
    *                     pv_sub_class
    *                     pv_master_style
    *                     pv_style
    *                     pv_colorway
    *                     pn_organizationid
    *                     pv_introseason
    *                     pv_colorwaystatus
    *                     pv_size
    *                     pn_item_id
    *                     pn_segment1
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE assign_inventory_category (pv_brand VARCHAR2, pv_division VARCHAR2, pv_sub_group VARCHAR2, pv_class VARCHAR2, pv_sub_class VARCHAR2, pv_master_style VARCHAR2, pv_style VARCHAR2, pv_colorway VARCHAR2, pn_organizationid NUMBER, pv_introseason VARCHAR2, pv_colorwaystatus VARCHAR2, pv_size VARCHAR2, pn_item_id NUMBER, pn_segment1 VARCHAR2, pv_retcode OUT VARCHAR2
                                         , pv_reterror OUT VARCHAR2)
    --**************************************************************************
    --procedure to assign inventory items to inventory category
    --**************************************************************************
    IS
        lv_pn               VARCHAR2 (240)
                                := gv_package_name || '.ASSIGN_INVENTORY_CATEGORY';
        eusererror          EXCEPTION;
        ln_invcatid         NUMBER := 0;
        ln_cat_set_id       NUMBER := NULL;
        ln_struc_id         NUMBER := NULL;
        ln_count            NUMBER := NULL;
        ln_oldcatid         NUMBER := 0;
        ln_masterorg        NUMBER := 0;
        ln_default_cat_id   NUMBER := 0;
        lv_old_segment1     VARCHAR2 (400) := NULL;
        lv_old_segment5     VARCHAR2 (400) := NULL;
        lv_new_segment1     VARCHAR2 (400) := NULL;
        lv_new_segment2     VARCHAR2 (400) := NULL;
        lv_new_segment3     VARCHAR2 (400) := NULL;
        lv_new_segment4     VARCHAR2 (400) := NULL;
        lv_new_segment5     VARCHAR2 (400) := NULL;
        lv_new_segment6     VARCHAR2 (400) := NULL;
        lv_new_segment7     VARCHAR2 (400) := NULL;
        lv_new_segment8     VARCHAR2 (400) := NULL;
        lv_new_cat_desc     VARCHAR2 (400) := NULL;
        ln_mod_inv_cat      VARCHAR2 (400) := NULL;
        ln_invcatid1        NUMBER := 0;
        ln_organizationid   NUMBER := gn_master_orgid;
        lv_errcode          VARCHAR2 (1000) := NULL;
        lv_error            VARCHAR2 (1000) := NULL;
        pv_errcode          VARCHAR2 (1000) := NULL;
        pv_error            VARCHAR2 (1000) := NULL;
        lv_return_status    VARCHAR2 (1000) := NULL;
        lv_error_message    VARCHAR2 (3000) := NULL;
        lv_error_code       VARCHAR2 (1000) := NULL;
        x_msg_count         NUMBER := 0;
        x_msg_data          VARCHAR2 (3000) := NULL;
        ln_msg_count        NUMBER := 0;
        lv_msg_data         VARCHAR2 (3000) := NULL;
        ln_msg_index_out    VARCHAR2 (3000) := NULL;
        lv_attr_style       VARCHAR2 (1000) := NULL;
        ln_error_code       NUMBER := 0;
    BEGIN
        x_msg_count        := 0;
        ln_msg_count       := 0;
        lv_error_message   := NULL;
        lv_attr_style      := pv_size;
        ln_cat_set_id      := gn_inventory_set_id;
        ln_struc_id        := gn_inventory_structure_id;

        --****************************************************************************
        --Retrieving category id for 'inventory' category
        --***************************************************************************
        BEGIN
            SELECT category_id, segment1, segment2,
                   segment3, segment4, segment5,
                   segment6, segment7, segment8,
                   description
              INTO ln_invcatid, lv_new_segment1, lv_new_segment2, lv_new_segment3,
                              lv_new_segment4, lv_new_segment5, lv_new_segment6,
                              lv_new_segment7, lv_new_segment8, lv_new_cat_desc
              FROM apps.mtl_categories
             WHERE     segment1 = pv_brand
                   AND segment2 = pv_division
                   AND segment3 = pv_sub_group
                   AND segment4 = pv_class
                   AND segment5 = pv_sub_class
                   AND segment6 = pv_master_style
                   AND segment7 = pv_style
                   AND segment8 = pv_colorway
                   AND structure_id = ln_struc_id
                   AND NVL (enabled_flag, 'Y') = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_invcatid   := 0;
                pv_errcode    := SQLCODE;
                pv_error      :=
                    ' Inventory Category Id Not present ' || SQLERRM;
            WHEN TOO_MANY_ROWS
            THEN
                ln_invcatid   := 0;
                pv_errcode    := SQLCODE;
                pv_error      :=
                       'Multiple Inventory category codes found for style : '
                    || gv_plm_style
                    || '. '
                    || SQLERRM;
            WHEN OTHERS
            THEN
                ln_invcatid   := 0;
                pv_retcode    := SQLCODE;
                pv_reterror   :=
                       'Exception occurred while retreiving Category id in Assign Inventory Category'
                    || SQLERRM;
        END;

        /*****************************************************************************************
        Retrieving old category assigned to item category
        ****************************************************************************************/
        BEGIN
            SELECT category_id
              INTO ln_oldcatid
              FROM apps.mtl_item_categories
             WHERE     inventory_item_id = pn_item_id
                   AND organization_id = ln_organizationid
                   AND category_set_id = ln_cat_set_id;

            IF ln_oldcatid <> ln_invcatid AND ln_invcatid <> 0
            THEN
                BEGIN
                    fnd_msg_pub.delete_msg (NULL);

                    inv_item_category_pub.update_category_assignment (
                        p_api_version         => 1.0,
                        --                  p_init_msg_list       => fnd_api.g_false, -- INIT_API_MSG_LIST - Start
                        p_init_msg_list       => fnd_api.g_true, -- INIT_API_MSG_LIST - end
                        p_commit              => fnd_api.g_true,
                        x_return_status       => lv_return_status,
                        x_errorcode           => lv_error_code,
                        x_msg_count           => ln_msg_count,
                        x_msg_data            => lv_msg_data,
                        p_category_id         => ln_invcatid,
                        p_category_set_id     => ln_cat_set_id,
                        p_inventory_item_id   => pn_item_id,
                        p_organization_id     => ln_organizationid,
                        p_old_category_id     => ln_oldcatid);



                    --INIT_API_MSG_LIST - Start
                    /*               FOR k IN 1 .. ln_msg_count


                                   LOOP
                                      x_msg_data      :=
                                         oe_msg_pub.get (p_msg_index => k, p_encoded => 'F');




                                      msg
                                      (
                                         SUBSTR
                                         (
                                               'Error in API while assigning new category : '


                                            || k
                                            || ' is : '
                                            || x_msg_data,





                                            0,
                                            1000
                                         )
                                      );
                                   END LOOP;
                    */
                    --INIT_API_MSG_LIST - End

                    IF lv_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        FOR k IN 1 .. ln_msg_count
                        LOOP
                            x_msg_data   :=
                                --                     oe_msg_pub.get (p_msg_index => k, p_encoded => 'F'); --INIT_API_MSG_LIST - Start
                                 fnd_msg_pub.get (p_msg_index   => k,
                                                  p_encoded     => 'F'); --INIT_API_MSG_LIST - End



                            msg (
                                SUBSTR (
                                       'Error in API while assigning new category : '
                                    || k
                                    || ' is : '
                                    || x_msg_data,
                                    0,
                                    1000));
                        END LOOP;

                        BEGIN
                            INSERT INTO xxdo.xxdo_plm_item_upd_errors
                                     VALUES (
                                                gn_record_id,
                                                g_style,
                                                g_colorway,
                                                ln_organizationid,
                                                   'Error Assigning Inventory Category for the item :: '
                                                || pn_segment1
                                                || '. ',
                                                SYSDATE);

                            COMMIT;
                        END;
                    ELSE
                        msg (
                               '     => Assigning '
                            || gv_inventory_set_name
                            || ' Category ID "'
                            || lv_new_cat_desc
                            || '" for the Item "'
                            || pn_segment1
                            || '"');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := SQLCODE;
                        pv_reterror   :=
                               pv_reterror
                            || 'Exception while assigning Inventory Category. '
                            || SQLERRM;



                        msg (
                            SUBSTR (
                                   '     => Error occurred while assigning Inventory Category for the Item : '
                                || pn_segment1
                                || ' :: '
                                || SQLERRM,
                                1,
                                900));
                END;
            ELSE
                msg (
                       '     => Old Inventory Category matches with New Inventory Category for the item :: '
                    || pn_segment1);


                LOG ('pv_brand : ' || pv_brand);
                LOG ('pv_division : ' || pv_division);
                LOG ('pv_sub_group : ' || pv_sub_group);
                LOG ('pv_class : ' || pv_class);
                LOG ('pv_sub_class : ' || pv_sub_class);
                LOG ('pv_master_style : ' || pv_master_style);
                LOG ('pv_style : ' || pv_style);
                LOG ('pv_colorway : ' || pv_colorway);
                LOG ('ln_oldcatid : ' || ln_oldcatid);
                LOG ('ln_invcatid : ' || ln_invcatid);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    fnd_msg_pub.delete_msg (NULL);
                    inv_item_category_pub.create_category_assignment (
                        p_api_version         => 1,
                        p_init_msg_list       => fnd_api.g_false,
                        p_commit              => fnd_api.g_false,
                        x_return_status       => lv_return_status,
                        x_errorcode           => ln_error_code,
                        x_msg_count           => ln_msg_count,
                        x_msg_data            => lv_msg_data,
                        p_category_id         => ln_invcatid,
                        p_category_set_id     => ln_cat_set_id,
                        p_inventory_item_id   => pn_item_id,
                        p_organization_id     => ln_organizationid);

                    IF lv_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        BEGIN
                            INSERT INTO xxdo.xxdo_plm_item_upd_errors
                                     VALUES (
                                                gn_record_id,
                                                g_style,
                                                g_colorway,
                                                ln_organizationid,
                                                   'Error Assigning Inventory Category for the item :: '
                                                || pn_segment1
                                                || '. ',
                                                SYSDATE);

                            COMMIT;
                        END;
                    ELSE
                        msg (
                               '     => Assigning '
                            || gv_inventory_set_name
                            || ' Category ID "'
                            || lv_new_cat_desc
                            || '" for the Item "'
                            || pn_segment1
                            || '"');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := SQLCODE;
                        pv_reterror   :=
                               pv_reterror
                            || 'Exception while assigning Inventory Category. '
                            || SQLERRM;
                END;
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := SQLCODE;
            pv_reterror   :=
                   'Unexpected error occurred while assigning Inventory Category '
                || SQLERRM;
    END assign_inventory_category;

    /****************************************************************************
    * Procedure Name    : assign_category
    *
    * Description       : The purpose of this procedure to assign OM Sales and
    *                     PO Item categories to Item.
    *
    * INPUT Parameters  : pv_segment1
    *                     pv_segment2
    *                     pv_segment3
    *                     pv_segment5
    *                     pn_item_id
    *                     pn_organizationid
    *                     pv_colorwaystatus
    *                     pv_cat_set
    *                     pn_segment1
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE assign_category (pv_segment1 VARCHAR2, pv_segment2 VARCHAR2, pv_segment3 VARCHAR2, pv_segment4 VARCHAR2, pv_segment5 VARCHAR2, pn_item_id NUMBER, pn_organizationid NUMBER, pv_colorwaystatus VARCHAR2, pv_cat_set VARCHAR2
                               , pn_segment1 VARCHAR2, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2)
    /*************************************************************************************
    procedure to assign inventory items to product family categories
    ***********************************************************************************/
    IS
        lv_pn                   VARCHAR2 (240) := gv_package_name || '.assign_category';
        lv_product_attr_value   VARCHAR2 (100);
        ln_stylecatid           NUMBER := 0;
        ln_cat_set_id           NUMBER := 0;
        ln_struc_id             NUMBER := 0;
        ln_count                NUMBER := 0;
        ln_oldcatid             NUMBER := 0;
        ln_old_cat_set_id       NUMBER := 0;
        ln_newcat_id            NUMBER := 0;
        lv_new_cat_desc         VARCHAR2 (100) := NULL;
        lv_style                VARCHAR2 (40) := NULL;
        lv_firstchar            VARCHAR2 (1) := NULL;
        lv_lastchar             VARCHAR2 (2) := NULL;
        ln_masterorg            NUMBER := 0;
        ln_organizationid       NUMBER := gn_master_orgid;
        pv_errcode              VARCHAR2 (1000) := NULL;
        pv_error                VARCHAR2 (1000) := NULL;
        lv_return_status        VARCHAR2 (1000) := NULL;
        lv_error_message        VARCHAR2 (3000) := NULL;
        lv_error_code           VARCHAR2 (1000) := NULL;
        x_msg_count             NUMBER := 0;
        x_msg_data              VARCHAR2 (3000) := NULL;
        ln_msg_count            NUMBER := 0;
        lv_msg_data             VARCHAR2 (3000) := NULL;
        ln_msg_index_out        VARCHAR2 (3000) := NULL;
        ln_error_code           NUMBER := 0;
    BEGIN
        lv_error_message   := NULL;
        x_msg_count        := 0;
        ln_msg_count       := 0;
        lv_msg_data        := NULL;

        msg (' pv_segment1         ' || pv_segment1);
        msg (' pv_segment2         ' || pv_segment2);
        msg (' pv_segment3         ' || pv_segment3);
        msg (' pv_segment4         ' || pv_segment4);
        msg (' pv_segment5         ' || pv_segment5);
        msg (' pn_item_id         ' || pn_item_id);
        msg (' pn_organizationid         ' || pn_organizationid);
        msg (' pv_colorwaystatus         ' || pv_colorwaystatus);
        msg (' pv_cat_set         ' || pv_cat_set);
        msg (' pn_segment1         ' || pn_segment1);

        /****************************************************************************
        Retrieving OM Sales category id
        **************************************************************************/
        BEGIN
            IF pv_cat_set = 'OM Sales Category'
            THEN
                ln_cat_set_id   := gn_om_sales_set_id;
                ln_struc_id     := gn_om_sales_structure_id;

                SELECT category_id, description
                  INTO ln_newcat_id, lv_new_cat_desc
                  FROM apps.mtl_categories
                 WHERE     segment1 = pv_segment1
                       AND structure_id = ln_struc_id
                       AND NVL (enabled_flag, 'Y') = 'Y';
            ELSIF pv_cat_set = 'PO Item Category'
            THEN
                ln_cat_set_id   := gn_po_item_set_id;
                ln_struc_id     := gn_po_item_structure_id;

                SELECT category_id, description
                  INTO ln_newcat_id, lv_new_cat_desc
                  FROM apps.mtl_categories
                 WHERE     segment1 = pv_segment1
                       AND segment2 = pv_segment2
                       AND segment3 = pv_segment3
                       AND structure_id = ln_struc_id
                       AND NVL (enabled_flag, 'Y') = 'Y';
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_newcat_id   := 0;
                pv_errcode     := SQLCODE;
                pv_error       :=
                       'Category Id Not present'
                    || 'For Item '
                    || pn_segment1
                    || ' '
                    || SQLERRM;
            WHEN TOO_MANY_ROWS
            THEN
                ln_newcat_id   := 0;
                pv_errcode     := SQLCODE;
                pv_error       :=
                       'Multiple Categories exists for Item : '
                    || pn_segment1
                    || '. '
                    || SQLERRM;
            WHEN OTHERS
            THEN
                pv_retcode   := SQLCODE;
                pv_reterror   :=
                       'Exception occurred while retreiving Category id in Assign Category'
                    || ' Category Id Not present'
                    || 'For Item '
                    || pn_segment1
                    || ' '
                    || SQLERRM;
        END;

        /*****************************************************************************************
        Retrieving old category assigned to style category
        ****************************************************************************************/
        BEGIN
            SELECT category_id
              INTO ln_oldcatid
              FROM apps.mtl_item_categories
             WHERE     inventory_item_id = pn_item_id
                   AND organization_id = ln_organizationid
                   AND category_set_id = ln_cat_set_id;

            LOG ('ln_newcat_id - ' || ln_newcat_id);
            LOG ('ln_oldcatid - ' || ln_oldcatid);



            IF ln_oldcatid <> ln_newcat_id AND ln_newcat_id <> 0
            THEN
                BEGIN
                    fnd_msg_pub.delete_msg (NULL);
                    inv_item_category_pub.update_category_assignment (
                        p_api_version         => 1.0,
                        p_init_msg_list       => fnd_api.g_false,
                        p_commit              => fnd_api.g_true,
                        x_return_status       => lv_return_status,
                        x_errorcode           => lv_error_code,
                        x_msg_count           => ln_msg_count,
                        x_msg_data            => lv_msg_data,
                        p_category_id         => ln_newcat_id,
                        p_category_set_id     => ln_cat_set_id,
                        p_inventory_item_id   => pn_item_id,
                        p_organization_id     => ln_organizationid,
                        p_old_category_id     => ln_oldcatid);

                    IF lv_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        BEGIN
                            -- ERROR_HANDLE - Start



                            pv_retcode    := lv_return_status;
                            pv_reterror   := lv_msg_data;


                            -- ERROR_HANDLE - End

                            INSERT INTO xxdo.xxdo_plm_item_upd_errors
                                     VALUES (
                                                gn_record_id,
                                                g_style,
                                                g_colorway,
                                                ln_organizationid,
                                                   'Error Assigning '
                                                || pv_cat_set
                                                || ' for the item '
                                                || pn_segment1
                                                || '. ',
                                                SYSDATE);

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := SQLCODE;

                                pv_reterror   :=
                                       pv_reterror
                                    || 'Exception while assigning '
                                    || pv_cat_set
                                    || SQLERRM;



                                msg (
                                    SUBSTR (
                                           '     => Error occurred while assigning '
                                        || pv_cat_set
                                        || ' for the item : '
                                        || pn_segment1
                                        || ' :: '
                                        || SQLERRM,
                                        1,
                                        900));
                        END;
                    ELSE
                        msg (
                               '     => Assigning '
                            || pv_cat_set
                            || ' ID "'
                            || lv_new_cat_desc
                            || '" for the Item "'
                            || pn_segment1
                            || '"');

                        -- ERROR_HANDLE - Start
                        pv_retcode          := NULL;
                        pv_reterror         := NULL;
                        --                 gv_po_error_cnt := 0;
                        gv_po_cat_updated   := 'Y';
                    -- ERROR_HANDLE - End


                    END IF;
                END;
            ELSE
                msg (
                       '     => Old '
                    || pv_cat_set
                    || ' matches with New '
                    || pv_cat_set
                    || ' for the item :: '
                    || pn_segment1);

                -- ERROR_HANDLE - Start
                pv_retcode        := NULL;
                pv_reterror       := NULL;

                gv_po_error_cnt   := 0;
            --                  gv_po_cat_updated := 'N';
            -- ERROR_HANDLE - End

            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    fnd_msg_pub.delete_msg (NULL);
                    inv_item_category_pub.create_category_assignment (
                        p_api_version         => 1,
                        p_init_msg_list       => fnd_api.g_false,
                        p_commit              => fnd_api.g_false,
                        x_return_status       => lv_return_status,
                        x_errorcode           => ln_error_code,
                        x_msg_count           => ln_msg_count,
                        x_msg_data            => lv_msg_data,
                        p_category_id         => ln_newcat_id,
                        p_category_set_id     => ln_cat_set_id,
                        p_inventory_item_id   => pn_item_id,
                        p_organization_id     => ln_organizationid);

                    IF lv_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        BEGIN
                            INSERT INTO xxdo.xxdo_plm_item_upd_errors
                                     VALUES (
                                                gn_record_id,
                                                g_style,
                                                g_colorway,
                                                ln_organizationid,
                                                   'Error Assigning '
                                                || pv_cat_set
                                                || ' for the item '
                                                || pn_segment1
                                                || '. ',
                                                SYSDATE);

                            COMMIT;
                        END;
                    ELSE
                        msg (
                               '     => Assigning '
                            || pv_cat_set
                            || ' "'
                            || lv_new_cat_desc
                            || '" for the Item "'
                            || pn_segment1
                            || '"');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                            SUBSTR (
                                   '     => Error occurred while assigning '
                                || pv_cat_set
                                || ' for the item : '
                                || pn_segment1
                                || ' :: '
                                || SQLERRM,
                                1,
                                900));
                END;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;
    END assign_category;

    /****************************************************************************
    * Procedure Name    : pre_process_validation
    *
    * Description       : This procedure will create categories.
    *
    * INPUT Parameters  : p_brand_v
    *                     p_style_v
    *
    * OUTPUT Parameters : pv_retcode
    *                     pv_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE pre_process_validation (p_brand_v IN VARCHAR2, p_style_v IN VARCHAR2, pv_reterror OUT VARCHAR2
                                      , pv_retcode OUT VARCHAR2)
    IS
        CURSOR csr_pros_cat IS
            SELECT *
              FROM xxdo.xxdo_plm_staging xps
             WHERE record_id = gn_record_id;

        CURSOR csr_region_cat (pn_record_id NUMBER)
        IS
            SELECT *
              FROM xxdo.xxdo_plm_region_stg xpr
             WHERE     request_id = gn_conc_request_id
                   AND parent_record_id = pn_record_id;

        CURSOR csr_size_cat IS
            --Start changes V5.0 on 07-Sep-2017 Cursor to fetch at Style Level rather than style color level
            SELECT *
              FROM apps.mtl_system_items_b msib
             WHERE     (   (segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                        OR (segment1 LIKE g_l_item_search)
                        OR (segment1 LIKE g_r_item_search)
                        OR (segment1 LIKE g_sr_item_search)
                        OR (segment1 LIKE g_sl_item_search)
                        OR (segment1 LIKE g_ss_item_search)
                        OR (    segment1 LIKE g_s_item_search
                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                'GENERIC'))
                        OR (segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                           )
                   AND organization_id = gn_master_orgid
                   AND UPPER (attribute28) IN ('SAMPLE')
                   AND ROWNUM <= 1
            UNION
            SELECT *
              FROM apps.mtl_system_items_b msib
             WHERE     (   (segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                        OR (segment1 LIKE g_l_item_search)
                        OR (segment1 LIKE g_r_item_search)
                        OR (segment1 LIKE g_sr_item_search)
                        OR (segment1 LIKE g_sl_item_search)
                        OR (segment1 LIKE g_ss_item_search)
                        OR (    segment1 LIKE g_s_item_search
                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                'GENERIC'))
                        OR (segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                           )
                   AND organization_id = gn_master_orgid
                   AND UPPER (attribute28) IN ('SAMPLE-L')
                   AND ROWNUM <= 1
            UNION
            SELECT *
              FROM apps.mtl_system_items_b msib
             WHERE     (   (segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                        OR (segment1 LIKE g_l_item_search)
                        OR (segment1 LIKE g_r_item_search)
                        OR (segment1 LIKE g_sr_item_search)
                        OR (segment1 LIKE g_sl_item_search)
                        OR (segment1 LIKE g_ss_item_search)
                        OR (    segment1 LIKE g_s_item_search
                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                'GENERIC'))
                        OR (segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                           )
                   AND organization_id = gn_master_orgid
                   AND UPPER (attribute28) IN ('SAMPLE-R')
                   AND ROWNUM <= 1
            UNION
            SELECT *
              FROM apps.mtl_system_items_b msib
             WHERE     (   (segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                        OR (segment1 LIKE g_l_item_search)
                        OR (segment1 LIKE g_r_item_search)
                        OR (segment1 LIKE g_sr_item_search)
                        OR (segment1 LIKE g_sl_item_search)
                        OR (segment1 LIKE g_ss_item_search)
                        OR (    segment1 LIKE g_s_item_search
                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                'GENERIC'))
                        OR (segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                           )
                   AND organization_id = gn_master_orgid
                   AND UPPER (attribute28) IN ('B-GRADE', 'BGRADE')
                   AND ROWNUM <= 1;

        --Start changes V5.0 on 07-Sep-2017 Cursor to fetch at Style Level rather than style color level for OM Sales Category
        CURSOR csr_size_om_cat IS
            SELECT *
              FROM apps.mtl_system_items_b msi
             WHERE     (   (msi.segment1 LIKE p_style_v || '-%' AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                        OR (msi.segment1 LIKE 'S' || p_style_v || 'L-%')
                        OR (msi.segment1 LIKE 'S' || p_style_v || 'R-%')
                        OR (msi.segment1 LIKE 'SR' || p_style_v || '-%')
                        OR (msi.segment1 LIKE 'SL' || p_style_v || '-%')
                        OR (msi.segment1 LIKE 'SS' || p_style_v || '-%')
                        OR (    msi.segment1 LIKE 'S' || p_style_v || '-%'
                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                'GENERIC'))
                        OR (msi.segment1 LIKE 'BG' || p_style_v || '-%'))
                   AND organization_id = gn_master_orgid
                   AND UPPER (attribute28) IN ('SAMPLE')
                   AND ROWNUM <= 1
            UNION
            SELECT *
              FROM apps.mtl_system_items_b msi
             WHERE     (   (msi.segment1 LIKE p_style_v || '-%' AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                        OR (msi.segment1 LIKE 'S' || p_style_v || 'L-%')
                        OR (msi.segment1 LIKE 'S' || p_style_v || 'R-%')
                        OR (msi.segment1 LIKE 'SR' || p_style_v || '-%')
                        OR (msi.segment1 LIKE 'SL' || p_style_v || '-%')
                        OR (msi.segment1 LIKE 'SS' || p_style_v || '-%')
                        OR (    msi.segment1 LIKE 'S' || p_style_v || '-%'
                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                'GENERIC'))
                        OR (msi.segment1 LIKE 'BG' || p_style_v || '-%'))
                   AND organization_id = gn_master_orgid
                   AND UPPER (attribute28) IN ('SAMPLE-L')
                   AND ROWNUM <= 1
            UNION
            SELECT *
              FROM apps.mtl_system_items_b msi
             WHERE     1 = 1
                   AND (   (msi.segment1 LIKE p_style_v || '-%' AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                        OR (msi.segment1 LIKE 'S' || p_style_v || 'L-%')
                        OR (msi.segment1 LIKE 'S' || p_style_v || 'R-%')
                        OR (msi.segment1 LIKE 'SR' || p_style_v || '-%')
                        OR (msi.segment1 LIKE 'SL' || p_style_v || '-%')
                        OR (msi.segment1 LIKE 'SS' || p_style_v || '-%')
                        OR (    msi.segment1 LIKE 'S' || p_style_v || '-%'
                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                'GENERIC'))
                        OR (msi.segment1 LIKE 'BG' || p_style_v || '-%'))
                   AND organization_id = gn_master_orgid
                   AND UPPER (attribute28) IN ('SAMPLE-R')
                   AND ROWNUM <= 1
            UNION
            SELECT *
              FROM apps.mtl_system_items_b msi
             WHERE     1 = 1
                   AND (   (msi.segment1 LIKE p_style_v || '-%' AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                        OR (msi.segment1 LIKE 'S' || p_style_v || 'L-%')
                        OR (msi.segment1 LIKE 'S' || p_style_v || 'R-%')
                        OR (msi.segment1 LIKE 'SR' || p_style_v || '-%')
                        OR (msi.segment1 LIKE 'SL' || p_style_v || '-%')
                        OR (msi.segment1 LIKE 'SS' || p_style_v || '-%')
                        OR (    msi.segment1 LIKE 'S' || p_style_v || '-%'
                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                'GENERIC'))
                        OR (msi.segment1 LIKE 'BG' || p_style_v || '-%'))
                   AND organization_id = gn_master_orgid
                   AND UPPER (attribute28) IN ('B-GRADE', 'BGRADE')
                   AND ROWNUM <= 1;

        --End Changes V5.0 on 07-Sep-2017

        ln_flexvalueid          VARCHAR2 (2) := NULL;
        ln_catid                NUMBER := 0;
        ln_wsale_pricelist_id   NUMBER := 0;
        ln_sampprice            NUMBER := 0;
        ln_price                NUMBER := 0;
        ln_rtl_pricelist_id     NUMBER := 0;
        lv_error_message        VARCHAR2 (3000) := NULL;
        lv_pn                   VARCHAR2 (100) := 'pre_process_validation';
        -- Start
        lv_brand                VARCHAR2 (150) := NULL;
        lv_division             VARCHAR2 (150) := NULL;
        lv_product_group        VARCHAR2 (150) := NULL;
        lv_class                VARCHAR2 (150) := NULL;
        lv_sub_class            VARCHAR2 (150) := NULL;
        lv_master_style         VARCHAR2 (150) := NULL;
        lv_style_desc           VARCHAR2 (150) := NULL;
        lv_style_option         VARCHAR2 (150) := NULL;
        lv_style                VARCHAR2 (150) := NULL;
        lv_curr_season          VARCHAR2 (150) := NULL;
        lv_supp_ascp            VARCHAR2 (150) := NULL;
        lv_src_factory          VARCHAR2 (150) := NULL;
        lv_prod_line            VARCHAR2 (150) := NULL;
        lv_tariff               VARCHAR2 (150) := NULL;
        lv_current_season       VARCHAR2 (150) := NULL;
        lv_project_type         VARCHAR2 (150) := NULL;
        lv_collection           VARCHAR2 (150) := NULL;
        lv_item_type            VARCHAR2 (150) := NULL;
        lv_region_name          VARCHAR2 (150) := NULL;
        lv_colorway_status      VARCHAR2 (150) := NULL;
        lv_sub_division         VARCHAR2 (150) := NULL;
        lv_detail_silhouette    VARCHAR2 (150) := NULL;
        lv_user_item_type       VARCHAR2 (150) := NULL;
        lv_colour_code          VARCHAR2 (150) := NULL;
        lv_inv_item_type        VARCHAR2 (150) := NULL;
        lv_style_name           VARCHAR2 (150) := NULL;
        -- NO_UPDATE_CHECK - Start
        lv_no_of_items_fixed    NUMBER := 0;
        lv_sub_division_stg     VARCHAR2 (150) := NULL;
        lv_sub_division_db      VARCHAR2 (150) := NULL;
        -- NO_UPDATE_CHECK - End
        -- SIZES_DIFF_HIERARCHIES - Start
        lv_no_of_items          NUMBER := 0;
    -- SIZES_DIFF_HIERARCHIES - End
    -- End
    BEGIN
        --Brand Validation
        FOR rec_pros_cat IN csr_pros_cat
        LOOP
            gv_retcode             := NULL;
            gv_reterror            := NULL;
            lv_division            := NULL;
            lv_brand               := NULL;
            lv_product_group       := NULL;
            lv_class               := NULL;
            lv_sub_class           := NULL;
            lv_master_style        := NULL;
            lv_style_desc          := NULL;
            lv_style_option        := NULL;
            lv_sub_division        := NULL;
            lv_detail_silhouette   := NULL;
            lv_tariff              := NULL;
            lv_current_season      := NULL;
            lv_project_type        := NULL;
            lv_collection          := NULL;
            lv_item_type           := NULL;
            lv_region_name         := NULL;
            lv_colorway_status     := NULL;
            lv_user_item_type      := NULL;
            lv_colour_code         := NULL;
            lv_inv_item_type       := NULL;
            lv_style_name          := NULL;
            gv_plm_style           := rec_pros_cat.style;
            gv_color_code          := rec_pros_cat.colorway;
            gv_season              := rec_pros_cat.current_season;
            gn_plm_rec_id          := rec_pros_cat.record_id;
            gv_colorway_state      := UPPER (rec_pros_cat.colorway_state);

            IF rec_pros_cat.brand IS NULL
            THEN
                gv_retcode   := 2;
                gv_reterror   :=
                    SUBSTR (
                           'Error occurred While updating PLM staging Table With Error When Brand Is Null'
                        || SQLERRM,
                        1,
                        1999);
            END IF;

            IF    rec_pros_cat.brand IS NULL
               OR rec_pros_cat.division IS NULL
               OR rec_pros_cat.product_group IS NULL
               OR rec_pros_cat.class IS NULL
               OR rec_pros_cat.sub_class IS NULL
               OR rec_pros_cat.master_style IS NULL
               OR rec_pros_cat.style IS NULL
               OR rec_pros_cat.style_name IS NULL
               OR rec_pros_cat.color_description IS NULL
            THEN
                msg ('One of the inventory category segments is NULL');
                gv_retcode   := 2;
                gv_reterror   :=
                    SUBSTR (
                           'One of the inventory category segments is NULL '
                        || SQLERRM,
                        1,
                        1999);
            ELSE
                LOG (
                    'All the inventory category segments are valid. Proceeding with inventory category creation.');

                LOG ('');


                -- NO_UPDATE_CHECK - Start


                BEGIN
                    SELECT COUNT (1)
                      INTO lv_no_of_items_fixed
                      FROM apps.mtl_system_items_b msi, apps.mtl_categories mc, apps.mtl_item_categories mic,
                           xxdo.xxdo_plm_staging stg
                     WHERE     ((msi.segment1 LIKE g_item_search) OR (msi.segment1 LIKE g_l_item_search) OR (msi.segment1 LIKE g_r_item_search) OR (msi.segment1 LIKE g_sr_item_search) OR (msi.segment1 LIKE g_sl_item_search) OR (msi.segment1 LIKE g_ss_item_search) OR (msi.segment1 LIKE g_s_item_search))
                           AND msi.organization_id = gn_master_orgid
                           AND msi.inventory_item_id = mic.inventory_item_id
                           AND msi.organization_id = mic.organization_id
                           AND mic.category_set_id = 1
                           AND mc.category_id = mic.category_id
                           AND mc.structure_id = 101
                           AND NVL (mc.disable_Date, SYSDATE + 1) > SYSDATE
                           AND mc.enabled_flag = 'Y'
                           AND stg.record_id = gn_record_id
                           AND mc.segment1 = UPPER (stg.brand)
                           AND mc.segment2 = UPPER (stg.division)
                           AND mc.segment3 = UPPER (stg.product_group)
                           AND mc.segment4 = UPPER (stg.class)
                           AND mc.segment5 = UPPER (stg.sub_class)
                           AND mc.segment6 = UPPER (stg.master_style)
                           AND mc.segment7 IN
                                   (UPPER (stg.style_name),
                                    UPPER ('SS' || stg.style_name),
                                    UPPER ('SR' || stg.style_name),
                                    UPPER ('SL' || stg.style_name),
                                       UPPER (   'S'
                                              || REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                , 1)
                                              || 'R-')
                                    || UPPER (REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                             , 2)),
                                       UPPER (   'S'
                                              || REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                , 1)
                                              || 'L-')
                                    || UPPER (REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                             , 2)),
                                    UPPER ('S' || stg.style_name))
                           AND mc.segment8 = UPPER (stg.color_description);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_no_of_items_fixed   := 0;
                END;

                BEGIN
                    SELECT COUNT (1)
                      INTO lv_no_of_items
                      FROM apps.mtl_system_items_b msi
                     WHERE     ((msi.segment1 LIKE g_item_search) OR (msi.segment1 LIKE g_l_item_search) OR (msi.segment1 LIKE g_r_item_search) OR (msi.segment1 LIKE g_sr_item_search) OR (msi.segment1 LIKE g_sl_item_search) OR (msi.segment1 LIKE g_ss_item_search) OR (msi.segment1 LIKE g_s_item_search))
                           AND msi.organization_id = gn_master_orgid;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_no_of_items   := 0;
                END;

                LOG ('Total Number of items : ' || lv_no_of_items);
                LOG (
                       'Number of items fixed already : '
                    || lv_no_of_items_fixed);



                IF lv_no_of_items = lv_no_of_items_fixed
                THEN
                    g_all_sizes_fixed   := 'Y';
                ELSE
                    g_all_sizes_fixed   := 'N';
                END IF;



                lv_sub_division_stg       := NULL;
                lv_sub_division_db        := NULL;
                gv_sub_division_updated   := 'N';

                IF NVL (lv_no_of_items_fixed, 0) = NVL (lv_no_of_items, 0)
                THEN
                    pv_reterror   := 'No Update Required';
                    pv_retcode    := '2';


                    BEGIN
                        SELECT UPPER (sub_group)
                          INTO lv_sub_division_stg
                          FROM xxdo.xxdo_plm_staging stg
                         WHERE stg.record_id = gn_record_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_sub_division_stg   := NULL;
                    END;

                    --                IF lv_sub_division_stg IS NOT NULL THEN

                    BEGIN
                        SELECT DISTINCT UPPER (mc.attribute5)
                          INTO lv_sub_division_db
                          FROM apps.mtl_system_items_b msi, apps.mtl_categories mc, apps.mtl_item_categories mic,
                               xxdo.xxdo_plm_staging stg
                         WHERE     msi.segment1 LIKE g_item_search
                               AND msi.organization_id = gn_master_orgid
                               AND msi.inventory_item_id =
                                   mic.inventory_item_id
                               AND msi.organization_id = mic.organization_id
                               AND mic.category_set_id = 1
                               AND mc.category_id = mic.category_id
                               AND mc.structure_id = 101
                               AND NVL (mc.disable_Date, SYSDATE + 1) >
                                   SYSDATE
                               AND mc.enabled_flag = 'Y'
                               AND stg.record_id = gn_record_id
                               AND mc.segment1 = UPPER (stg.brand)
                               AND mc.segment2 = UPPER (stg.division)
                               AND mc.segment3 = UPPER (stg.product_group)
                               AND mc.segment4 = UPPER (stg.class)
                               AND mc.segment5 = UPPER (stg.sub_class)
                               AND mc.segment6 = UPPER (stg.master_style)
                               AND mc.segment7 IN
                                       (UPPER (stg.style_name),
                                        UPPER ('SS' || stg.style_name),
                                        UPPER ('SR' || stg.style_name),
                                        UPPER ('SL' || stg.style_name),
                                           UPPER (   'S'
                                                  || REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                    , 1)
                                                  || 'R-')
                                        || UPPER (REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                 , 2)),
                                           UPPER (   'S'
                                                  || REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                    , 1)
                                                  || 'L-')
                                        || UPPER (REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                 , 2)))
                               AND mc.segment8 =
                                   UPPER (stg.color_description);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_sub_division_db   := NULL;
                        WHEN TOO_MANY_ROWS
                        THEN
                            lv_sub_division_db   := NULL;
                        WHEN OTHERS
                        THEN
                            lv_sub_division_db   := NULL;
                    END;

                    IF NVL (lv_sub_division_db, 'X') <>
                       NVL (lv_sub_division_stg, 'X')
                    THEN
                        UPDATE inv.mtl_categories_b mc
                           SET attribute5 = lv_sub_division_stg, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
                         WHERE     mc.structure_id = 101
                               AND NVL (mc.disable_Date, SYSDATE + 1) >
                                   SYSDATE
                               AND mc.enabled_flag = 'Y'
                               AND (mc.segment1, mc.segment2, mc.segment3,
                                    mc.segment4, mc.segment5, mc.segment6,
                                    mc.segment7, mc.segment8) IN
                                       (SELECT UPPER (stg.brand), UPPER (stg.division), UPPER (stg.product_group),
                                               UPPER (stg.class), UPPER (stg.sub_class), UPPER (stg.master_style),
                                               UPPER (stg.style_name), UPPER (stg.color_description)
                                          FROM xxdo.xxdo_plm_staging stg
                                         WHERE stg.record_id = gn_record_id
                                        UNION ALL
                                        SELECT UPPER (stg.brand), UPPER (stg.division), UPPER (stg.product_group),
                                               UPPER (stg.class), UPPER (stg.sub_class), UPPER (stg.master_style),
                                               UPPER ('SS' || stg.style_name), UPPER (stg.color_description)
                                          FROM xxdo.xxdo_plm_staging stg
                                         WHERE stg.record_id = gn_record_id
                                        UNION ALL
                                        SELECT UPPER (stg.brand), UPPER (stg.division), UPPER (stg.product_group),
                                               UPPER (stg.class), UPPER (stg.sub_class), UPPER (stg.master_style),
                                               UPPER ('SR' || stg.style_name), UPPER (stg.color_description)
                                          FROM xxdo.xxdo_plm_staging stg
                                         WHERE stg.record_id = gn_record_id
                                        UNION ALL
                                        SELECT UPPER (stg.brand), UPPER (stg.division), UPPER (stg.product_group),
                                               UPPER (stg.class), UPPER (stg.sub_class), UPPER (stg.master_style),
                                               UPPER ('SL' || stg.style_name), UPPER (stg.color_description)
                                          FROM xxdo.xxdo_plm_staging stg
                                         WHERE stg.record_id = gn_record_id
                                        UNION ALL
                                        SELECT UPPER (stg.brand),
                                               UPPER (stg.division),
                                               UPPER (stg.product_group),
                                               UPPER (stg.class),
                                               UPPER (stg.sub_class),
                                               UPPER (stg.master_style),
                                                  UPPER (
                                                         'S'
                                                      || REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                        , 1)
                                                      || 'R-')
                                               || UPPER (REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                        , 2)),
                                               UPPER (stg.color_description)
                                          FROM xxdo.xxdo_plm_staging stg
                                         WHERE stg.record_id = gn_record_id
                                        UNION ALL
                                        SELECT UPPER (stg.brand),
                                               UPPER (stg.division),
                                               UPPER (stg.product_group),
                                               UPPER (stg.class),
                                               UPPER (stg.sub_class),
                                               UPPER (stg.master_style),
                                                  UPPER (
                                                         'S'
                                                      || REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                        , 1)
                                                      || 'L-')
                                               || UPPER (REGEXP_SUBSTR (stg.style_name, '[^-]+', 1
                                                                        , 2)),
                                               UPPER (stg.color_description)
                                          FROM xxdo.xxdo_plm_staging stg
                                         WHERE stg.record_id = gn_record_id);

                        COMMIT;
                        gv_sub_division_updated   := 'Y';
                    END IF;

                    --               RETURN;


                    --             END IF;
                    RETURN;
                END IF;



                -- NO_UPDATE_CHECK - End

                BEGIN
                    IF rec_pros_cat.colorway IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.colorway,
                                           'DO_COLOR_CODE',
                                           rec_pros_cat.colorway,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_division);

                        LOG ('Validated Colorway : ' || lv_division);
                    END IF;

                    IF rec_pros_cat.style IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.style,
                                           'DO_STYLE_NUM',
                                           rec_pros_cat.style,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_division);

                        LOG ('Validated Style : ' || lv_division);
                    END IF;

                    IF rec_pros_cat.brand IS NOT NULL
                    THEN
                        validate_lookup_val ('DO_BRANDS',
                                             rec_pros_cat.brand,
                                             rec_pros_cat.brand,
                                             gv_retcode,
                                             gv_reterror,
                                             lv_brand);
                        LOG ('Validated Brand : ' || lv_brand);
                    END IF;

                    IF rec_pros_cat.division IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.division,
                                           'DO_DIVISION_CAT',
                                           rec_pros_cat.division,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_division);

                        LOG ('Validated Division : ' || lv_division);
                    END IF;

                    IF rec_pros_cat.product_group IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.product_group,
                                           'DO_DEPARTMENT_CAT',
                                           rec_pros_cat.product_group,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_product_group);

                        LOG ('Validated Department : ' || lv_product_group);
                    END IF;

                    IF rec_pros_cat.class IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.class,
                                           'DO_CLASS_CAT',
                                           rec_pros_cat.class,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_class);
                        LOG ('Validated Class : ' || lv_class);
                    END IF;

                    IF rec_pros_cat.sub_class IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.sub_class,
                                           'DO_SUBCLASS_CAT',
                                           rec_pros_cat.sub_class,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_sub_class);

                        LOG ('Validated Sub Class : ' || lv_sub_class);
                    END IF;

                    IF rec_pros_cat.master_style IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.master_style,
                                           'DO_MASTER_STYLE_CAT',
                                           rec_pros_cat.master_style,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_master_style);

                        LOG ('Validated Master Style : ' || lv_master_style);
                    END IF;

                    IF rec_pros_cat.sub_group IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.sub_group,
                                           'DO_SUB_DIVISION',
                                           rec_pros_cat.sub_group,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_sub_division);

                        LOG ('Validated Sub Group : ' || lv_sub_division);
                    END IF;

                    IF rec_pros_cat.detail_silhouette IS NOT NULL
                    THEN
                        validate_valueset (rec_pros_cat.detail_silhouette,
                                           'DO_DETAIL_SILHOUETTE',
                                           rec_pros_cat.detail_silhouette,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_detail_silhouette);

                        LOG (
                            'Validated Silhouette : ' || lv_detail_silhouette);
                    END IF;

                    IF rec_pros_cat.color_description IS NOT NULL
                    THEN
                        LOG ('Color Desscription IS NOT NULL');

                        FOR rec_size_cat IN csr_size_cat
                        LOOP
                            LOG (
                                'Entered into Item Type SAMPLE or B-GRADE Loop');
                            lv_colour_code   :=
                                rec_pros_cat.color_description;
                            LOG ('Color Description : ' || lv_colour_code);

                            IF UPPER (rec_size_cat.attribute28) = 'SAMPLE'
                            THEN
                                LOG ('Item Type :: SAMPLE');
                                validate_valueset (
                                    lv_colour_code,
                                    'DO_STYLEOPTION_CAT',
                                    rec_pros_cat.color_description,
                                    gv_retcode,
                                    gv_reterror,
                                    lv_style_option);



                                LOG (
                                       'Validated Color Description : '
                                    || lv_style_option);

                                IF UPPER (rec_pros_cat.product_group) <>
                                   'FOOTWEAR'
                                THEN
                                    LOG ('Item Type is not FOOTWEAR');

                                    -- NON_FOOTWEAR_SAMPLE - Start
                                    --                               lv_style_name   := 'SS' || rec_pros_cat.style_name;
                                    --                               LOG ('SS Style Name : ' || lv_style_name);
                                    IF rec_size_cat.segment1 LIKE
                                           g_ss_item_search
                                    THEN
                                        lv_style_name   :=
                                            'SS' || rec_pros_cat.style_name;
                                        LOG (
                                               'SS Style Name : '
                                            || lv_style_name);
                                    ELSE
                                        lv_style_name   :=
                                            'S' || rec_pros_cat.style_name;
                                        LOG (
                                               'S Style Name : '
                                            || lv_style_name);
                                    END IF;

                                    -- NON_FOOTWEAR_SAMPLE - End


                                    validate_valueset (lv_style_name,
                                                       'DO_STYLE_CAT',
                                                       lv_style_name,
                                                       gv_retcode,
                                                       gv_reterror,
                                                       lv_style_desc);
                                    LOG (
                                           'Validated SS/S Style Name : '
                                        || lv_style_desc);
                                    create_inventory_category (
                                        lv_brand,
                                        lv_division,
                                        lv_product_group,
                                        lv_class,
                                        lv_sub_class,
                                        lv_master_style,
                                        lv_style_desc,
                                        lv_style_option,
                                        rec_pros_cat.colorway,
                                        lv_sub_division,
                                        lv_detail_silhouette, -- NON_FOOTWEAR_SAMPLE - Start
                                        --                              'SS' || rec_pros_cat.style ,



                                        CASE
                                            WHEN rec_size_cat.segment1 LIKE
                                                     g_ss_item_search
                                            THEN
                                                'SS' || rec_pros_cat.style  --
                                            ELSE
                                                'S' || rec_pros_cat.style
                                        END,      -- NON_FOOTWEAR_SAMPLE - End
                                        NULL,
                                        gv_retcode,
                                        gv_reterror);

                                    --Start Changes V5.0
                                    --                           IF gn_old_style_cnt = 1
                                    --                           THEN
                                    --                              --END Changes V5.0
                                    --                              create_category (lv_style_desc,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               'OM Sales Category',
                                    --                                               NULL,
                                    --                                               gv_retcode,
                                    --                                               gv_reterror);
                                    --                           --Start V5.0
                                    --                           END IF;

                                    --End V5.0
                                    create_category ('Trade',
                                                     lv_class,
                                                     lv_style_desc,
                                                     NULL,
                                                     NULL,
                                                     'PO Item Category',
                                                     NULL,
                                                     gv_retcode,
                                                     gv_reterror);
                                ELSIF UPPER (rec_pros_cat.product_group) =
                                      'FOOTWEAR'
                                THEN
                                    LOG ('Item Type :: FOOTWEAR');
                                    lv_style_name   :=
                                        'SL' || rec_pros_cat.style_name;
                                    LOG ('SL Style Name : ' || lv_style_name);
                                    validate_valueset (lv_style_name,
                                                       'DO_STYLE_CAT',
                                                       lv_style_name,
                                                       gv_retcode,
                                                       gv_reterror,
                                                       lv_style_desc);
                                    LOG (
                                           'Validated SL Style Name : '
                                        || lv_style_desc);
                                    LOG ('');
                                    create_inventory_category (
                                        lv_brand,
                                        lv_division,
                                        lv_product_group,
                                        lv_class,
                                        lv_sub_class,
                                        lv_master_style,
                                        lv_style_desc,
                                        lv_style_option,
                                        rec_pros_cat.colorway,
                                        lv_sub_division,
                                        lv_detail_silhouette,
                                        'SL' || rec_pros_cat.style,
                                        NULL,
                                        gv_retcode,
                                        gv_reterror);

                                    --Start Changes V5.0
                                    --                           IF gn_old_style_cnt = 1
                                    --                           THEN
                                    --                              --END Changes V5.0
                                    --                              create_category (lv_style_desc,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               'OM Sales Category',
                                    --                                               NULL,
                                    --                                               gv_retcode,
                                    --                                               gv_reterror);
                                    --                           --Start Changes V5.0
                                    --                           END IF;

                                    --End Changes V5.0
                                    create_category ('Trade',
                                                     lv_class,
                                                     lv_style_desc,
                                                     NULL,
                                                     NULL,
                                                     'PO Item Category',
                                                     NULL,
                                                     gv_retcode,
                                                     gv_reterror);
                                    lv_style_name   :=
                                        'SR' || rec_pros_cat.style_name;
                                    LOG ('');
                                    LOG ('SR Style Name : ' || lv_style_name);
                                    validate_valueset (lv_style_name,
                                                       'DO_STYLE_CAT',
                                                       lv_style_name,
                                                       gv_retcode,
                                                       gv_reterror,
                                                       lv_style_desc);
                                    LOG (
                                           'Validated SR Style Name : '
                                        || lv_style_desc);
                                    LOG ('');
                                    create_inventory_category (
                                        lv_brand,
                                        lv_division,
                                        lv_product_group,
                                        lv_class,
                                        lv_sub_class,
                                        lv_master_style,
                                        lv_style_desc,
                                        lv_style_option,
                                        rec_pros_cat.colorway,
                                        lv_sub_division,
                                        lv_detail_silhouette,
                                        'SR' || rec_pros_cat.style,
                                        NULL,
                                        gv_retcode,
                                        gv_reterror);

                                    --Start Changes V5.0
                                    --                           IF gn_old_style_cnt = 1
                                    --                           THEN
                                    --                              --END Changes V5.0
                                    --                              create_category (lv_style_desc,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               'OM Sales Category',
                                    --                                               NULL,
                                    --                                               gv_retcode,
                                    --                                               gv_reterror);
                                    --                           --Start Changes V5.0
                                    --                           END IF;

                                    --End Changes V5.0
                                    create_category ('Trade',
                                                     lv_class,
                                                     lv_style_desc,
                                                     NULL,
                                                     NULL,
                                                     'PO Item Category',
                                                     NULL,
                                                     gv_retcode,
                                                     gv_reterror);
                                    lv_style_name   :=
                                        'SS' || rec_pros_cat.style_name;
                                    LOG ('');
                                    LOG ('SS Style Name : ' || lv_style_name);
                                    validate_valueset (lv_style_name,
                                                       'DO_STYLE_CAT',
                                                       lv_style_name,
                                                       gv_retcode,
                                                       gv_reterror,
                                                       lv_style_desc);
                                    LOG (
                                           'Validated SS Style Name : '
                                        || lv_style_desc);
                                    LOG ('');
                                    create_inventory_category (
                                        lv_brand,
                                        lv_division,
                                        lv_product_group,
                                        lv_class,
                                        lv_sub_class,
                                        lv_master_style,
                                        lv_style_desc,
                                        lv_style_option,
                                        rec_pros_cat.colorway,
                                        lv_sub_division,
                                        lv_detail_silhouette,
                                        'SS' || rec_pros_cat.style,
                                        NULL,
                                        gv_retcode,
                                        gv_reterror);

                                    --Start Changes V5.0
                                    --                           IF gn_old_style_cnt = 1
                                    --                           THEN
                                    --                              --END Changes V5.0
                                    --                              create_category (lv_style_desc,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               NULL,
                                    --                                               'OM Sales Category',
                                    --                                               NULL,
                                    --                                               gv_retcode,
                                    --                                               gv_reterror);
                                    --                           --Start Changes V5.0
                                    --                           END IF;

                                    --ENd Changes V5.0

                                    create_category ('Trade',
                                                     lv_class,
                                                     lv_style_desc,
                                                     NULL,
                                                     NULL,
                                                     'PO Item Category',
                                                     NULL,
                                                     gv_retcode,
                                                     gv_reterror);
                                END IF;
                            ELSIF UPPER (rec_size_cat.attribute28) =
                                  'SAMPLE-L'
                            THEN
                                LOG ('Item Type :: SAMPLE-L');
                                validate_valueset (
                                    lv_colour_code,
                                    'DO_STYLEOPTION_CAT',
                                    rec_pros_cat.color_description,
                                    gv_retcode,
                                    gv_reterror,
                                    lv_style_option);



                                LOG (
                                       'Validated Color Description : '
                                    || lv_style_option);
                                --SAMPLE-L START

                                lv_style_name   :=
                                       'S'
                                    || SUBSTR (
                                           rec_pros_cat.style_name,
                                           1,
                                             (INSTR (rec_pros_cat.style_name, '-', 1))
                                           - 1)
                                    || 'L'
                                    || SUBSTR (
                                           rec_pros_cat.style_name,
                                           INSTR (rec_pros_cat.style_name,
                                                  '-'));

                                LOG ('');
                                LOG (
                                    'SAMPLE-L Style Name : ' || lv_style_name);
                                validate_valueset (lv_style_name,
                                                   'DO_STYLE_CAT',
                                                   lv_style_name,
                                                   gv_retcode,
                                                   gv_reterror,
                                                   lv_style_desc);
                                LOG (
                                       'Validated SAMPLE-L Style Name : '
                                    || lv_style_desc);
                                LOG ('');
                                create_inventory_category (
                                    lv_brand,
                                    lv_division,
                                    lv_product_group,
                                    lv_class,
                                    lv_sub_class,
                                    lv_master_style,
                                    lv_style_desc,
                                    lv_style_option,
                                    rec_pros_cat.colorway,
                                    lv_sub_division,
                                    lv_detail_silhouette,
                                    'S' || rec_pros_cat.style || 'L',
                                    NULL,
                                    gv_retcode,
                                    gv_reterror);

                                --Start Changes V5.0
                                --                        IF gn_old_style_cnt = 1
                                --                        THEN
                                --                           --END Changes V5.0
                                --                           create_category (lv_style_desc,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            'OM Sales Category',
                                --                                            NULL,
                                --                                            gv_retcode,
                                --                                            gv_reterror);
                                --                        --Start Changes V5.0
                                --                        END IF;

                                -- End Changes V5.0
                                create_category ('Trade',
                                                 lv_class,
                                                 lv_style_desc,
                                                 NULL,
                                                 NULL,
                                                 'PO Item Category',
                                                 NULL,
                                                 gv_retcode,
                                                 gv_reterror);
                            --SAMPLE-L END
                            ELSIF UPPER (rec_size_cat.attribute28) =
                                  'SAMPLE-R'
                            THEN
                                LOG ('Item Type :: SAMPLE-R');
                                validate_valueset (
                                    lv_colour_code,
                                    'DO_STYLEOPTION_CAT',
                                    rec_pros_cat.color_description,
                                    gv_retcode,
                                    gv_reterror,
                                    lv_style_option);



                                LOG (
                                       'Validated Color Description : '
                                    || lv_style_option);
                                --SAMPLE-R START

                                lv_style_name   :=
                                       'S'
                                    || SUBSTR (
                                           rec_pros_cat.style_name,
                                           1,
                                             (INSTR (rec_pros_cat.style_name, '-', 1))
                                           - 1)
                                    || 'R'
                                    || SUBSTR (
                                           rec_pros_cat.style_name,
                                           INSTR (rec_pros_cat.style_name,
                                                  '-'));

                                LOG ('');
                                LOG (
                                    'SAMPLE-R Style Name : ' || lv_style_name);
                                validate_valueset (lv_style_name,
                                                   'DO_STYLE_CAT',
                                                   lv_style_name,
                                                   gv_retcode,
                                                   gv_reterror,
                                                   lv_style_desc);
                                LOG (
                                       'Validated SAMPLE-R Style Name : '
                                    || lv_style_desc);
                                LOG ('');
                                create_inventory_category (
                                    lv_brand,
                                    lv_division,
                                    lv_product_group,
                                    lv_class,
                                    lv_sub_class,
                                    lv_master_style,
                                    lv_style_desc,
                                    lv_style_option,
                                    rec_pros_cat.colorway,
                                    lv_sub_division,
                                    lv_detail_silhouette,
                                    'S' || rec_pros_cat.style || 'R',
                                    NULL,
                                    gv_retcode,
                                    gv_reterror);

                                --Start Changes V5.0
                                --                        IF gn_old_style_cnt = 1
                                --                        THEN
                                --                           --END Changes V5.0
                                --                           create_category (lv_style_desc,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            'OM Sales Category',
                                --                                            NULL,
                                --                                            gv_retcode,
                                --                                            gv_reterror);
                                --                        --Start Changes V5.0
                                --                        END IF;

                                --End Changes V5.0
                                create_category ('Trade',
                                                 lv_class,
                                                 lv_style_desc,
                                                 NULL,
                                                 NULL,
                                                 'PO Item Category',
                                                 NULL,
                                                 gv_retcode,
                                                 gv_reterror);
                            --SAMPLE-R END
                            ELSIF UPPER (rec_size_cat.attribute28) IN
                                      ('B-GRADE', 'BGRADE')
                            THEN
                                LOG ('Item Type :: B-GRADE');
                                validate_valueset (
                                    lv_colour_code,
                                    'DO_STYLEOPTION_CAT',
                                    rec_pros_cat.color_description,
                                    gv_retcode,
                                    gv_reterror,
                                    lv_style_option);



                                LOG (
                                       'Validated Color Description : '
                                    || lv_style_option);
                                lv_style_name   :=
                                    'BG' || rec_pros_cat.style_name;
                                LOG ('');
                                LOG ('BG Style Name : ' || lv_style_name);
                                validate_valueset (lv_style_name,
                                                   'DO_STYLE_CAT',
                                                   lv_style_name,
                                                   gv_retcode,
                                                   gv_reterror,
                                                   lv_style_desc);
                                LOG (
                                       'Validated BG Style Name : '
                                    || lv_style_desc);
                                LOG ('');
                                create_inventory_category (
                                    lv_brand,
                                    lv_division,
                                    lv_product_group,
                                    lv_class,
                                    lv_sub_class,
                                    lv_master_style,
                                    lv_style_desc,
                                    lv_style_option,
                                    rec_pros_cat.colorway,
                                    lv_sub_division,
                                    lv_detail_silhouette,
                                    'BG' || rec_pros_cat.style,
                                    NULL,
                                    gv_retcode,
                                    gv_reterror);

                                --Start Changes V5.0
                                --                        IF gn_old_style_cnt = 1
                                --                        THEN
                                --                           --END Changes V5.0
                                --                           create_category (lv_style_desc,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            NULL,
                                --                                            'OM Sales Category',
                                --                                            NULL,
                                --                                            gv_retcode,
                                --                                            gv_reterror);
                                --                        --Start Changes V5.0
                                --                        END IF;

                                --ENd Changes V5.0
                                create_category ('Trade',
                                                 lv_class,
                                                 lv_style_desc,
                                                 NULL,
                                                 NULL,
                                                 'PO Item Category',
                                                 NULL,
                                                 gv_retcode,
                                                 gv_reterror);
                            END IF;
                        END LOOP;

                        --Start changes V5.0 for OM Sales Category which is handled at Style level rather than style-color level
                        IF gn_old_style_cnt = 1
                        THEN
                            FOR rec_size_om_cat IN csr_size_om_cat
                            LOOP
                                LOG (
                                    'Entered into Item Type SAMPLE or B-GRADE Loop');
                                lv_colour_code   :=
                                    rec_pros_cat.color_description;
                                LOG (
                                    'Color Description : ' || lv_colour_code);

                                IF UPPER (rec_size_om_cat.attribute28) =
                                   'SAMPLE'
                                THEN
                                    LOG ('Item Type :: SAMPLE');
                                    validate_valueset (
                                        lv_colour_code,
                                        'DO_STYLEOPTION_CAT',
                                        rec_pros_cat.color_description,
                                        gv_retcode,
                                        gv_reterror,
                                        lv_style_option);



                                    LOG (
                                           'Validated Color Description : '
                                        || lv_style_option);

                                    IF UPPER (rec_pros_cat.product_group) <>
                                       'FOOTWEAR'
                                    THEN
                                        LOG ('Item Type is not FOOTWEAR');

                                        -- NON_FOOTWEAR_SAMPLE - Start
                                        --                               lv_style_name   := 'SS' || rec_pros_cat.style_name;
                                        --                               LOG ('SS Style Name : ' || lv_style_name);
                                        IF rec_size_om_cat.segment1 LIKE
                                               g_ss_item_search
                                        THEN
                                            lv_style_name   :=
                                                   'SS'
                                                || rec_pros_cat.style_name;
                                            LOG (
                                                   'SS Style Name : '
                                                || lv_style_name);
                                        ELSE
                                            lv_style_name   :=
                                                   'S'
                                                || rec_pros_cat.style_name;
                                            LOG (
                                                   'S Style Name : '
                                                || lv_style_name);
                                        END IF;

                                        -- NON_FOOTWEAR_SAMPLE - End


                                        validate_valueset (lv_style_name,
                                                           'DO_STYLE_CAT',
                                                           lv_style_name,
                                                           gv_retcode,
                                                           gv_reterror,
                                                           lv_style_desc);
                                        LOG (
                                               'Validated SS/S Style Name : '
                                            || lv_style_desc);


                                        create_category (lv_style_desc,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         'OM Sales Category',
                                                         NULL,
                                                         gv_retcode,
                                                         gv_reterror);
                                    ELSIF UPPER (rec_pros_cat.product_group) =
                                          'FOOTWEAR'
                                    THEN
                                        LOG ('Item Type :: FOOTWEAR');
                                        lv_style_name   :=
                                            'SL' || rec_pros_cat.style_name;
                                        LOG (
                                               'SL Style Name : '
                                            || lv_style_name);
                                        validate_valueset (lv_style_name,
                                                           'DO_STYLE_CAT',
                                                           lv_style_name,
                                                           gv_retcode,
                                                           gv_reterror,
                                                           lv_style_desc);
                                        LOG (
                                               'Validated SL Style Name : '
                                            || lv_style_desc);
                                        LOG ('');

                                        create_category (lv_style_desc,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         'OM Sales Category',
                                                         NULL,
                                                         gv_retcode,
                                                         gv_reterror);


                                        lv_style_name   :=
                                            'SR' || rec_pros_cat.style_name;
                                        LOG ('');
                                        LOG (
                                               'SR Style Name : '
                                            || lv_style_name);
                                        validate_valueset (lv_style_name,
                                                           'DO_STYLE_CAT',
                                                           lv_style_name,
                                                           gv_retcode,
                                                           gv_reterror,
                                                           lv_style_desc);
                                        LOG (
                                               'Validated SR Style Name : '
                                            || lv_style_desc);
                                        LOG ('');


                                        create_category (lv_style_desc,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         'OM Sales Category',
                                                         NULL,
                                                         gv_retcode,
                                                         gv_reterror);


                                        lv_style_name   :=
                                            'SS' || rec_pros_cat.style_name;
                                        LOG ('');
                                        LOG (
                                               'SS Style Name : '
                                            || lv_style_name);
                                        validate_valueset (lv_style_name,
                                                           'DO_STYLE_CAT',
                                                           lv_style_name,
                                                           gv_retcode,
                                                           gv_reterror,
                                                           lv_style_desc);
                                        LOG (
                                               'Validated SS Style Name : '
                                            || lv_style_desc);
                                        LOG ('');



                                        create_category (lv_style_desc,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         'OM Sales Category',
                                                         NULL,
                                                         gv_retcode,
                                                         gv_reterror);
                                    END IF;
                                ELSIF UPPER (rec_size_om_cat.attribute28) =
                                      'SAMPLE-L'
                                THEN
                                    LOG ('Item Type :: SAMPLE-L');
                                    validate_valueset (
                                        lv_colour_code,
                                        'DO_STYLEOPTION_CAT',
                                        rec_pros_cat.color_description,
                                        gv_retcode,
                                        gv_reterror,
                                        lv_style_option);



                                    LOG (
                                           'Validated Color Description : '
                                        || lv_style_option);
                                    --SAMPLE-L START

                                    lv_style_name   :=
                                           'S'
                                        || SUBSTR (
                                               rec_pros_cat.style_name,
                                               1,
                                                 (INSTR (rec_pros_cat.style_name, '-', 1))
                                               - 1)
                                        || 'L'
                                        || SUBSTR (
                                               rec_pros_cat.style_name,
                                               INSTR (
                                                   rec_pros_cat.style_name,
                                                   '-'));

                                    LOG ('');
                                    LOG (
                                           'SAMPLE-L Style Name : '
                                        || lv_style_name);
                                    validate_valueset (lv_style_name,
                                                       'DO_STYLE_CAT',
                                                       lv_style_name,
                                                       gv_retcode,
                                                       gv_reterror,
                                                       lv_style_desc);
                                    LOG (
                                           'Validated SAMPLE-L Style Name : '
                                        || lv_style_desc);
                                    LOG ('');

                                    create_category (lv_style_desc,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     'OM Sales Category',
                                                     NULL,
                                                     gv_retcode,
                                                     gv_reterror);
                                --SAMPLE-L END
                                ELSIF UPPER (rec_size_om_cat.attribute28) =
                                      'SAMPLE-R'
                                THEN
                                    LOG ('Item Type :: SAMPLE-R');
                                    validate_valueset (
                                        lv_colour_code,
                                        'DO_STYLEOPTION_CAT',
                                        rec_pros_cat.color_description,
                                        gv_retcode,
                                        gv_reterror,
                                        lv_style_option);



                                    LOG (
                                           'Validated Color Description : '
                                        || lv_style_option);
                                    --SAMPLE-R START

                                    lv_style_name   :=
                                           'S'
                                        || SUBSTR (
                                               rec_pros_cat.style_name,
                                               1,
                                                 (INSTR (rec_pros_cat.style_name, '-', 1))
                                               - 1)
                                        || 'R'
                                        || SUBSTR (
                                               rec_pros_cat.style_name,
                                               INSTR (
                                                   rec_pros_cat.style_name,
                                                   '-'));

                                    LOG ('');
                                    LOG (
                                           'SAMPLE-R Style Name : '
                                        || lv_style_name);
                                    validate_valueset (lv_style_name,
                                                       'DO_STYLE_CAT',
                                                       lv_style_name,
                                                       gv_retcode,
                                                       gv_reterror,
                                                       lv_style_desc);
                                    LOG (
                                           'Validated SAMPLE-R Style Name : '
                                        || lv_style_desc);
                                    LOG ('');

                                    create_category (lv_style_desc,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     'OM Sales Category',
                                                     NULL,
                                                     gv_retcode,
                                                     gv_reterror);
                                --SAMPLE-R END
                                ELSIF UPPER (rec_size_om_cat.attribute28) IN
                                          ('B-GRADE', 'BGRADE')
                                THEN
                                    LOG ('Item Type :: B-GRADE');
                                    validate_valueset (
                                        lv_colour_code,
                                        'DO_STYLEOPTION_CAT',
                                        rec_pros_cat.color_description,
                                        gv_retcode,
                                        gv_reterror,
                                        lv_style_option);



                                    LOG (
                                           'Validated Color Description : '
                                        || lv_style_option);
                                    lv_style_name   :=
                                        'BG' || rec_pros_cat.style_name;
                                    LOG ('');
                                    LOG ('BG Style Name : ' || lv_style_name);
                                    validate_valueset (lv_style_name,
                                                       'DO_STYLE_CAT',
                                                       lv_style_name,
                                                       gv_retcode,
                                                       gv_reterror,
                                                       lv_style_desc);
                                    LOG (
                                           'Validated BG Style Name : '
                                        || lv_style_desc);
                                    LOG ('');

                                    create_category (lv_style_desc,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     'OM Sales Category',
                                                     NULL,
                                                     gv_retcode,
                                                     gv_reterror);
                                END IF;
                            END LOOP;
                        END IF;

                        --End changes V5.0 for OM Sales Category which is handled at Style level rather than style-color level

                        lv_style_name    := rec_pros_cat.style_name;
                        LOG ('');
                        LOG (
                            'Main Categories creation after Item Type Loop.');
                        LOG ('Main Style Name : ' || lv_style_name);
                        validate_valueset (lv_style_name,
                                           'DO_STYLE_CAT',
                                           lv_style_name,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_style_desc);

                        LOG ('Validated Main Style Name : ' || lv_style_desc);
                        lv_colour_code   := rec_pros_cat.color_description;
                        LOG ('Color Description : ' || lv_colour_code);
                        validate_valueset (lv_colour_code,
                                           'DO_STYLEOPTION_CAT',
                                           rec_pros_cat.color_description,
                                           gv_retcode,
                                           gv_reterror,
                                           lv_style_option);

                        LOG (
                               'Validated Color Description : '
                            || lv_style_option);
                    END IF;

                    BEGIN
                        LOG (
                            'Updating Staging Table with All validated category segment values');


                        UPDATE xxdo.xxdo_plm_staging
                           SET brand = lv_brand, division = lv_division, product_group = lv_product_group,
                               class = lv_class, sub_class = lv_sub_class, master_style = lv_master_style,
                               color_description = lv_style_option, sub_group = lv_sub_division, detail_silhouette = lv_detail_silhouette,
                               style_name = lv_style_desc
                         WHERE record_id = rec_pros_cat.record_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                'Exception in Updating Staging Table with All validated category segment values');



                            msg (
                                   'Error in Updating Inv Cat Values to Stg Table :: '
                                || SQLERRM);
                    END;

                    COMMIT;
                    LOG ('');
                    LOG ('Creating Main Inventory Category');
                    create_inventory_category (lv_brand,
                                               lv_division,
                                               lv_product_group,
                                               lv_class,
                                               lv_sub_class,
                                               lv_master_style,
                                               lv_style_desc,
                                               lv_style_option,
                                               rec_pros_cat.colorway,
                                               lv_sub_division,
                                               lv_detail_silhouette,
                                               rec_pros_cat.style,
                                               NULL,
                                               gv_retcode,
                                               gv_reterror);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gv_retcode   := SQLCODE;
                        gv_reterror   :=
                            SUBSTR (
                                   'Exception in Creating Inventory Category'
                                || rec_pros_cat.master_style
                                || ' '
                                || SQLERRM,
                                1,
                                1999);
                END;
            END IF;

            IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
            THEN
                lv_error_message   :=
                    SUBSTR (
                           'Error occurred While creating inventory category'
                        || gv_reterror,
                        1,
                        1999);

                BEGIN
                    gv_error_desc   :=
                           gv_error_desc
                        || 'Error occurred while creating Inventory Category. ';

                    UPDATE xxdo.xxdo_plm_staging
                       SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                     WHERE record_id = gn_record_id;

                    COMMIT;
                END;
            END IF;

            -----------------------------------------------------------
            --Creating OM sales Category
            -----------------------------------------------------------
            gv_retcode             := NULL;
            gv_reterror            := NULL;
            LOG ('');
            LOG ('Creating Main OM Sales Category');

            IF rec_pros_cat.style_name IS NOT NULL
            THEN
                BEGIN
                    validate_valueset (rec_pros_cat.style_name, 'DO_STYLE_CAT', rec_pros_cat.style_name
                                       , gv_retcode, gv_reterror, lv_style);
                    LOG ('Validated OM Sales Style Name : ' || lv_style);

                    --Start Changes V5.0
                    IF gn_old_style_cnt = 1
                    THEN
                        --END Changes V5.0
                        create_category (lv_style, NULL, NULL,
                                         NULL, NULL, 'OM Sales Category',
                                         NULL, gv_retcode, gv_reterror);
                    --Start Changes V5.0
                    END IF;
                --End Changes V5.0
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gv_reterror   :=
                            SUBSTR (
                                   'Exception occurred While creating OM Sales Category. '
                                || SQLERRM,
                                1,
                                1999);
                END;
            END IF;


            IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
            THEN
                lv_error_message   :=
                    SUBSTR (
                           'Error occurred while creating OM Sales Category '
                        || gv_reterror,
                        1,
                        1999);

                BEGIN
                    gv_error_desc   :=
                           gv_error_desc
                        || 'Error occurred while creating OM Sales Category. ';

                    UPDATE xxdo.xxdo_plm_staging
                       SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                     WHERE record_id = gn_record_id;

                    COMMIT;
                END;
            END IF;

            -----------------------------------------------------------
            --Creating PO Item Category
            ------------------------------------------------------------
            LOG ('');
            LOG ('Creating Main PO Item Category');

            BEGIN
                gv_retcode    := NULL;
                gv_reterror   := NULL;
                create_category ('Trade', lv_class, lv_style_desc,
                                 NULL, NULL, 'PO Item Category',
                                 NULL, gv_retcode, gv_reterror);
            EXCEPTION
                WHEN OTHERS
                THEN
                    gv_reterror   :=
                        SUBSTR (
                               ' Exception occurred While creating PO Item category '
                            || SQLCODE
                            || ' : '
                            || SQLERRM,
                            1,
                            1999);
            END;



            IF gv_retcode IS NOT NULL OR gv_reterror IS NOT NULL
            THEN
                lv_error_message   :=
                    SUBSTR (
                           'Error occurred While creating PO Item category'
                        || gv_reterror,
                        1,
                        1999);

                BEGIN
                    gv_error_desc   :=
                           gv_error_desc
                        || 'Error occurred While creating PO Item Category. ';

                    UPDATE xxdo.xxdo_plm_staging
                       SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                     WHERE record_id = gn_record_id;

                    COMMIT;
                END;
            END IF;
        END LOOP;

        msg ('');
        msg ('Pre Process Validation Return Error : ' || gv_reterror);
        msg ('Pre Process Validation Return Code  : ' || gv_retcode);
        pv_retcode    := gv_retcode;
        pv_reterror   := gv_reterror;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode    := SQLCODE;
            pv_reterror   := SQLERRM;


            msg (
                   'Unknown Exception Occurred In pre_process_validation :: '
                || SQLERRM);
    END pre_process_validation;

    /****************************************************************************
    * Procedure Name    : main
    *
    * Description       : Main procedure to update Item description,
    *                     create and assign item categories, price lists
    *                     and sourcing rules update.
    *
    * INPUT Parameters  : p_style_v
    *                     p_color_v
    *                     pn_conc_request_id
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/
    PROCEDURE main (p_reterror OUT VARCHAR2, p_retcode OUT NUMBER, p_style_v IN VARCHAR2
                    , p_color_v IN VARCHAR2, pn_conc_request_id IN NUMBER)
    IS
        /*******************************************************************************
        Cursor to fetch staging table record details for the item
        *******************************************************************************/
        CURSOR csr_stg_table (record_id NUMBER)
        IS
            SELECT *
              FROM xxdo.xxdo_plm_staging
             WHERE record_id = gn_record_id;

        /*******************************************************************************
        Cursor to fetch items to assign categories
        *******************************************************************************/
        CURSOR csr_item_cat_assign IS
              SELECT                       --Start changes V5.0 Added distinct
                     DISTINCT --End Changes V5.0
                              stg.brand brand,
                              stg.division gender,
                              stg.product_group product_group,
                              stg.class class,
                              stg.sub_class sub_class,
                              stg.master_style master_style,
                              (CASE
                                   WHEN     SUBSTR (msi.segment1, 1, 2) = 'SS'
                                        AND msi.attribute28 = 'SAMPLE' -- STYLE_SEARCH - Start - End
                                   THEN
                                       'SS' || style_name
                                   WHEN SUBSTR (msi.segment1, 1, 2) = 'SL'
                                   THEN
                                       'SL' || style_name
                                   WHEN SUBSTR (msi.segment1, 1, 2) = 'SR'
                                   THEN
                                       'SR' || style_name
                                   WHEN SUBSTR (msi.segment1, 1, 2) = 'BG'
                                   THEN
                                       'BG' || style_name -- STYLE_SEARCH -- Start
                                   --                      WHEN msi.attribute28 = 'SAMPLE-L'

                                   --                      THEN
                                   WHEN msi.segment1 LIKE
                                               'S'
                                            || SUBSTR (
                                                   style_name,
                                                   1,
                                                     (INSTR (style_name, '-', 1))
                                                   - 1)
                                            || 'L-%'
                                   THEN                 -- STYLE_SEARCH -- End
                                          'S'
                                       || SUBSTR (
                                              style_name,
                                              1,
                                              (INSTR (style_name, '-', 1)) - 1)
                                       || 'L'
                                       || SUBSTR (style_name,
                                                  INSTR (style_name, '-'))
                                   --                      WHEN msi.attribute28 = 'SAMPLE-R'       -- STYLE_SEARCH -- Start

                                   --                      THEN
                                   WHEN msi.segment1 LIKE
                                               'S'
                                            || SUBSTR (
                                                   style_name,
                                                   1,
                                                     (INSTR (style_name, '-', 1))
                                                   - 1)
                                            || 'R-%'
                                   THEN                 -- STYLE_SEARCH -- End
                                          'S'
                                       || SUBSTR (
                                              style_name,
                                              1,
                                              (INSTR (style_name, '-', 1)) - 1)
                                       || 'R'
                                       || SUBSTR (style_name,
                                                  INSTR (style_name, '-'))
                                   WHEN msi.segment1 LIKE
                                               'S'
                                            || SUBSTR -- STYLE_SEARCH -- Start
                                                      (
                                                   style_name,
                                                   1,
                                                     (INSTR (style_name, '-', 1))
                                                   - 1)
                                            || '-%'
                                   THEN
                                          'S'
                                       || SUBSTR (
                                              style_name,
                                              1,
                                              (INSTR (style_name, '-', 1)) - 1)
                                       || SUBSTR (style_name,
                                                  INSTR (style_name, '-')) -- STYLE_SEARCH -- end
                                   ELSE
                                       style_name
                               END) style_name,
                              stg.color_description colorway,
                              msi.organization_id organization_id,
                              msi.attribute1 currentseason,
                              stg.colorway_status colorwaystatus,
                              SUBSTR (msi.segment1,
                                      1,
                                        INSTR (msi.segment1, '-', 1,
                                               1)
                                      - 1) style,
                              msi.inventory_item_id item_id,
                              msi.segment1
                FROM mtl_system_items_b msi, xxdo.xxdo_plm_staging stg, mtl_item_categories mic
               WHERE     1 = 1
                     AND (   (msi.segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                          OR (msi.segment1 LIKE g_l_item_search)
                          OR (msi.segment1 LIKE g_r_item_search)
                          OR (msi.segment1 LIKE g_sr_item_search)
                          OR (msi.segment1 LIKE g_sl_item_search)
                          OR (msi.segment1 LIKE g_ss_item_search)
                          OR (    msi.segment1 LIKE g_s_item_search
                              AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                  'GENERIC'))
                          OR (msi.segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                                 )
                     AND msi.organization_id = gn_master_orgid
                     --Start Changes V5.0-- Added Attribute4 condition
                     AND stg.attribute4 = 'HIERARCHY_UPDATE'
                     --End changes V5.0
                     AND stg.style = g_style
                     AND stg.colorway = g_colorway
                     AND stg.record_id = gn_record_id
                     AND msi.inventory_item_id = mic.inventory_item_id
                     AND mic.organization_id = msi.organization_id
            ORDER BY msi.segment1;

        /*******************************************************************************
        Cursor to fetch Sourcing Rules
        *******************************************************************************/
        CURSOR csr_src_rule_upd IS
              SELECT                                      --Start Changes V5.0
                     DISTINCT                               --End Changes V5.0
                              stg.brand, stg.division, stg.product_group,
                              stg.class, stg.sub_class, stg.master_style,
                              msr.sourcing_rule_name, stg.style_name, stg.color_description,
                              msa.assignment_set_id, msa.assignment_id, msa.organization_id,
                              msr.sourcing_rule_id, mc.category_id
                FROM mrp_sourcing_rules msr, mrp_sr_assignments msa, mtl_categories mc,
                     xxdo.xxdo_plm_staging stg
               WHERE     msr.sourcing_rule_id = msa.sourcing_rule_id
                     AND msa.category_id = mc.category_id
                     AND ((msr.sourcing_rule_name LIKE g_item_search) OR (msr.sourcing_rule_name LIKE g_l_item_search) OR (msr.sourcing_rule_name LIKE g_r_item_search) OR (msr.sourcing_rule_name LIKE g_sr_item_search) OR (msr.sourcing_rule_name LIKE g_sl_item_search) OR (msr.sourcing_rule_name LIKE g_ss_item_search) OR (msr.sourcing_rule_name LIKE g_s_item_search) OR (msr.sourcing_rule_name LIKE g_bg_item_search))
                     AND stg.color_description = mc.segment8
                     AND stg.style = g_style
                     AND stg.colorway = g_colorway
                     AND stg.record_id = gn_record_id
            ORDER BY mc.category_id DESC;

        /*******************************************************************************
        Cursor to fetch old OM Sales Category values for Price List Lines Update
        *******************************************************************************/

        CURSOR csr_om_cat_old IS
              --Start changes V5.0 -- Commented the query for price list changes
              /* SELECT DISTINCT
                      mc.category_id,
                      mic.category_set_id,
                      --                  msi.attribute28,
                      DECODE (msi.attribute28, 'GENERIC', 'PROD', msi.attribute28)
                         attribute28,
                      MIN (REGEXP_SUBSTR (msi.segment1,
                                          '[^-]+',
                                          1,
                                          1))
                         style_number
                 FROM mtl_categories mc,
                      mtl_item_categories mic,
                      mtl_system_items_b msi
                WHERE     1 = 1
                      AND mc.structure_id = gn_om_sales_structure_id
                      AND mc.enabled_flag = 'Y'
                      AND SYSDATE BETWEEN NVL (mc.start_date_active, SYSDATE - 1)
                                      AND NVL (mc.end_date_active, SYSDATE + 1)
                      AND msi.organization_id = mic.organization_id
                      AND msi.inventory_item_id = mic.inventory_item_id
                      AND (                   (    msi.segment1 LIKE g_item_search
                                                         AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                                                     OR (msi.segment1 LIKE g_l_item_search)
                                                     OR (msi.segment1 LIKE g_r_item_search)
                                                     OR (msi.segment1 LIKE g_sr_item_search)
                                                     OR (msi.segment1 LIKE g_sl_item_search)
                                                     OR (msi.segment1 LIKE g_ss_item_search)
                                                     OR (    msi.segment1 LIKE g_s_item_search
                                                         AND attribute28 IN ('SAMPLE',
                                                                             'SAMPLE-L',
                                                                             'SAMPLE-R',
                                                                             'GENERIC'))
                                                     OR (msi.segment1 LIKE g_bg_item_search)) -- STYLE_SEARCH - End
                      AND msi.organization_id = gn_master_orgid
                      AND mic.category_set_id = gn_om_sales_set_id
                      AND mc.category_id = mic.category_id
             --                           AND msi.attribute28 <> 'GENERIC'
             GROUP BY mc.category_id, mic.category_set_id, msi.attribute28;
             */
              SELECT DISTINCT mc.category_id,
                              mic.category_set_id,
                              --                  msi.attribute28,
                              CASE
                                  WHEN     msi.segment1 LIKE
                                               'S' || g_style || 'L-%'
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE-L'
                                  WHEN     msi.segment1 LIKE
                                               'S' || g_style || 'R-%'
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE-R'
                                  WHEN     msi.segment1 LIKE
                                               'SR' || g_style || '-%'
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE
                                               'S' || g_style || '-%'
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE
                                               'SL' || g_style || '-%'
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE
                                               'SS' || g_style || '-%'
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE
                                               'BG' || g_style || '-%'
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'BGRADE'
                                  WHEN     msi.segment1 LIKE g_style || '-%'
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'PROD'
                                  ELSE
                                      msi.attribute28
                              END attribute28,
                              MIN (REGEXP_SUBSTR (msi.segment1, '[^-]+', 1,
                                                  1)) style_number
                FROM mtl_categories mc, mtl_item_categories mic, mtl_system_items_b msi
               WHERE     1 = 1
                     AND mc.structure_id = gn_om_sales_structure_id
                     AND mc.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (mc.start_date_active,
                                              SYSDATE - 1)
                                     AND NVL (mc.end_date_active, SYSDATE + 1)
                     AND msi.organization_id = mic.organization_id
                     AND msi.inventory_item_id = mic.inventory_item_id
                     AND (   (msi.segment1 LIKE g_style || '-%' AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                          OR (msi.segment1 LIKE 'S' || g_style || 'L-%')
                          OR (msi.segment1 LIKE 'S' || g_style || 'R-%')
                          OR (msi.segment1 LIKE 'SR' || g_style || '-%')
                          OR (msi.segment1 LIKE 'SL' || g_style || '-%')
                          OR (msi.segment1 LIKE 'SS' || g_style || '-%')
                          OR (    msi.segment1 LIKE 'S' || g_style || '-%'
                              AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                  'GENERIC'))
                          OR (msi.segment1 LIKE 'BG' || g_style || '-%'))
                     AND msi.organization_id = gn_master_orgid
                     AND mic.category_set_id = gn_om_sales_set_id
                     AND mc.category_id = mic.category_id
            --                           AND msi.attribute28 <> 'GENERIC'
            GROUP BY mc.category_id,
                     mic.category_set_id,
                     CASE
                         WHEN     msi.segment1 LIKE 'S' || g_style || 'L-%'
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE-L'
                         WHEN     msi.segment1 LIKE 'S' || g_style || 'R-%'
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE-R'
                         WHEN     msi.segment1 LIKE 'SR' || g_style || '-%'
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE 'S' || g_style || '-%'
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE 'SL' || g_style || '-%'
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE 'SS' || g_style || '-%'
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE 'BG' || g_style || '-%'
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'BGRADE'
                         WHEN     msi.segment1 LIKE g_style || '-%'
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'PROD'
                         ELSE
                             msi.attribute28
                     END;

        --         End Changes V5.0

        /*******************************************************************************
        Cursor to fetch old Inventory Category values for Sourcing Rule Update
        *******************************************************************************/
        CURSOR csr_inv_cat_old IS
              SELECT DISTINCT mc.category_id,
                              mic.category_set_id,
                              --Start changes V5.0 to include Generic Items
                              --            msi.attribute28
                              CASE
                                  WHEN     msi.segment1 LIKE g_l_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE-L'
                                  WHEN     msi.segment1 LIKE g_r_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE-R'
                                  WHEN     msi.segment1 LIKE g_sr_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE g_sl_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE g_ss_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE g_s_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE g_bg_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'BGRADE'
                                  WHEN     msi.segment1 LIKE g_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'PROD'
                                  ELSE
                                      msi.attribute28
                              END attribute28
                --End Changes V5.0 to include Generic Items
                FROM mtl_categories mc, mtl_item_categories mic, mtl_system_items_b msi
               WHERE     1 = 1
                     AND mc.structure_id = gn_inventory_structure_id
                     AND mc.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (mc.start_date_active,
                                              SYSDATE - 1)
                                     AND NVL (mc.end_date_active, SYSDATE + 1)
                     AND msi.organization_id = mic.organization_id
                     AND msi.inventory_item_id = mic.inventory_item_id
                     AND (   (msi.segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                          OR (msi.segment1 LIKE g_l_item_search)
                          OR (msi.segment1 LIKE g_r_item_search)
                          OR (msi.segment1 LIKE g_sr_item_search)
                          OR (msi.segment1 LIKE g_sl_item_search)
                          OR (msi.segment1 LIKE g_ss_item_search)
                          OR (    msi.segment1 LIKE g_s_item_search
                              AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                  'GENERIC'))
                          OR (msi.segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                                 )
                     AND msi.organization_id = gn_master_orgid
                     AND mic.category_set_id = gn_inventory_set_id
                     AND mc.category_id = mic.category_id
            --                  AND msi.attribute28 <> 'GENERIC'
            GROUP BY mc.category_id,
                     mic.category_set_id,
                     CASE
                         WHEN     msi.segment1 LIKE g_l_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE-L'
                         WHEN     msi.segment1 LIKE g_r_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE-R'
                         WHEN     msi.segment1 LIKE g_sr_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE g_sl_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE g_ss_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE g_s_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE g_bg_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'BGRADE'
                         WHEN     msi.segment1 LIKE g_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'PROD'
                         ELSE
                             msi.attribute28
                     END;

        /*******************************************************************************
        Cursor to fetch old PO Item Category values
        *******************************************************************************/
        CURSOR csr_po_item_cat_old IS
              SELECT DISTINCT mc.category_id,
                              mic.category_set_id,
                              --Start changes V5.0 to include Generic Items
                              --            msi.attribute28
                              CASE
                                  WHEN     msi.segment1 LIKE g_l_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE-L'
                                  WHEN     msi.segment1 LIKE g_r_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE-R'
                                  WHEN     msi.segment1 LIKE g_sr_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE g_sl_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE g_ss_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE g_s_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'SAMPLE'
                                  WHEN     msi.segment1 LIKE g_bg_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'BGRADE'
                                  WHEN     msi.segment1 LIKE g_item_search
                                       AND msi.attribute28 = 'GENERIC'
                                  THEN
                                      'PROD'
                                  ELSE
                                      msi.attribute28
                              END attribute28
                --End Changes V5.0 to include Generic Items
                FROM mtl_categories mc, mtl_item_categories mic, mtl_system_items_b msi
               WHERE     1 = 1
                     AND mc.structure_id = gn_po_item_structure_id
                     AND mc.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (mc.start_date_active,
                                              SYSDATE - 1)
                                     AND NVL (mc.end_date_active, SYSDATE + 1)
                     AND msi.organization_id = mic.organization_id
                     AND msi.inventory_item_id = mic.inventory_item_id
                     AND (   (msi.segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                          OR (msi.segment1 LIKE g_l_item_search)
                          OR (msi.segment1 LIKE g_r_item_search)
                          OR (msi.segment1 LIKE g_sr_item_search)
                          OR (msi.segment1 LIKE g_sl_item_search)
                          OR (msi.segment1 LIKE g_ss_item_search)
                          OR (    msi.segment1 LIKE g_s_item_search
                              AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                  'GENERIC'))
                          OR (msi.segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                                 )
                     AND msi.organization_id = gn_master_orgid
                     AND mic.category_set_id = gn_po_item_set_id
                     AND mc.category_id = mic.category_id
            --                  AND msi.attribute28 <> 'GENERIC'
            GROUP BY mc.category_id,
                     mic.category_set_id,
                     CASE
                         WHEN     msi.segment1 LIKE g_l_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE-L'
                         WHEN     msi.segment1 LIKE g_r_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE-R'
                         WHEN     msi.segment1 LIKE g_sr_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE g_sl_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE g_ss_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE g_s_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'SAMPLE'
                         WHEN     msi.segment1 LIKE g_bg_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'BGRADE'
                         WHEN     msi.segment1 LIKE g_item_search
                              AND msi.attribute28 = 'GENERIC'
                         THEN
                             'PROD'
                         ELSE
                             msi.attribute28
                     END;

        /*******************************************************************************
        Cursor to fetch price list lines for old category
        *******************************************************************************/
        CURSOR csr_prc_list (ln_loop_cat_id NUMBER)
        IS
              SELECT qlh.list_header_id, qll.list_line_id, qpa.pricing_attribute_id,
                     qll.operand, qll.start_date_active, qll.end_date_active,
                     qll.attribute2, qll.attribute1, qpa.product_uom_code,
                     qpa.product_attr_value, qll.product_precedence, qlh.name
                FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
               WHERE     qpa.list_line_id = qll.list_line_id
                     AND qll.list_header_id = qlh.list_header_id
                     AND qpa.product_attribute_context = 'ITEM'
                     AND qpa.product_attribute = 'PRICING_ATTRIBUTE2'
                     AND qpa.product_attr_value = TO_CHAR (ln_loop_cat_id)
            ORDER BY qll.end_date_active;

        /*******************************************************************************
        Cursor to fetch staging table record details for the item
        *******************************************************************************/
        CURSOR csr_log_table (record_id NUMBER)
        IS
            SELECT *
              FROM xxdo.xxdo_plm_item_upd_errors
             WHERE record_id = gn_record_id;


        -- DISABLE_ILR_CATEGORIES - Start


        /*******************************************************************************
        Cursor to fetch old Inventory Category values of ILR style / colors
        *******************************************************************************/
        CURSOR csr_inv_cat_old_gen IS
              SELECT mc.category_id, mic.category_set_id, msi.attribute28
                FROM mtl_categories mc, mtl_item_categories mic, mtl_system_items_b msi
               WHERE     1 = 1
                     AND mc.structure_id = gn_inventory_structure_id
                     AND mc.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (mc.start_date_active,
                                              SYSDATE - 1)
                                     AND NVL (mc.end_date_active, SYSDATE + 1)
                     AND msi.organization_id = mic.organization_id
                     AND msi.inventory_item_id = mic.inventory_item_id
                     AND (   (msi.segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                          OR (msi.segment1 LIKE g_l_item_search)
                          OR (msi.segment1 LIKE g_r_item_search)
                          OR (msi.segment1 LIKE g_sr_item_search)
                          OR (msi.segment1 LIKE g_sl_item_search)
                          OR (msi.segment1 LIKE g_ss_item_search)
                          OR (    msi.segment1 LIKE g_s_item_search
                              AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                  'GENERIC'))
                          OR (msi.segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                                 )
                     AND msi.organization_id = gn_master_orgid
                     AND mic.category_set_id = gn_inventory_set_id
                     AND mc.category_id = mic.category_id
                     AND msi.attribute28 = 'GENERIC'
                     AND NOT EXISTS
                             (SELECT 1
                                FROM mtl_item_categories mic_i, mtl_system_items_b msi_i
                               WHERE     mic_i.category_id = mic.category_id
                                     AND msi_i.inventory_item_id =
                                         mic_i.inventory_item_id
                                     AND msi_i.organization_id =
                                         gn_master_orgid
                                     AND msi_i.organization_id =
                                         mic_i.organization_id
                                     AND mic_i.category_set_id =
                                         gn_inventory_structure_id
                                     AND msi_i.attribute28 <> 'GENERIC')
            GROUP BY mc.category_id, mic.category_set_id, msi.attribute28;


        -- DISABLE_ILR_CATEGORIES - End



        v_org_id                    NUMBER := NULL;
        p_brand_v                   VARCHAR2 (100) := NULL;
        v_item_description          VARCHAR2 (400) := NULL;
        v_inv_item_id               NUMBER;
        ln_old_category_id          NUMBER;
        ln_new_category_id          NUMBER;
        ln_new_src_rule_cat_id      NUMBER;
        ln_old_prc_om_cat_id        NUMBER := NULL;
        ln_new_prc_om_cat_id        NUMBER := NULL;
        ln_loop_cat_id              NUMBER := NULL;
        ln_old_om_cat_id            NUMBER := NULL;
        ln_old_inv_cat_id           NUMBER := NULL;
        ln_old_po_cat_id            NUMBER := NULL;
        ln_loop_item_type           VARCHAR2 (100) := NULL;
        ln_old_prc_om_cat           VARCHAR2 (100) := NULL;
        ln_new_prc_om_cat           VARCHAR2 (100) := NULL;
        ln_om_cnt                   NUMBER := 0;
        ln_inv_cnt                  NUMBER := 0;
        l_item_cnt                  NUMBER := 0;
        l_rec_cnt                   NUMBER := 0;
        ln_po_cnt                   NUMBER := 0;
        ln_new_src_cat_name         VARCHAR2 (100) := NULL;
        ln_list_line_id             NUMBER;
        ln_pricing_attr_id          NUMBER;
        pv_reterror                 VARCHAR2 (2000) := NULL;
        pv_retcode                  VARCHAR2 (2000) := NULL;
        lv_desc_upd_reterror        VARCHAR2 (2000) := NULL;
        lv_desc_upd_retcode         NUMBER := 0;
        lv_po_desc_upd_reter        VARCHAR2 (2000) := NULL;
        lv_po_desc_upd_retcode      NUMBER := 0;
        v_message                   VARCHAR2 (8000);
        v_return_status             VARCHAR2 (100);
        v_sl                        NUMBER;
        v_assignment_set_rec        mrp_src_assignment_pub.assignment_set_rec_type;
        v_assignment_set_val_rec    mrp_src_assignment_pub.assignment_set_val_rec_type;
        v_assignment_tbl            mrp_src_assignment_pub.assignment_tbl_type;
        v_assignment_val_tbl        mrp_src_assignment_pub.assignment_val_tbl_type;
        x_assignment_set_rec        mrp_src_assignment_pub.assignment_set_rec_type;
        x_assignment_set_val_rec    mrp_src_assignment_pub.assignment_set_val_rec_type;
        x_assignment_tbl            mrp_src_assignment_pub.assignment_tbl_type;
        x_assignment_val_tbl        mrp_src_assignment_pub.assignment_val_tbl_type;
        x_msg_count                 NUMBER := 0;
        x_msg_data                  VARCHAR2 (1000);
        ln_req_id                   NUMBER := NULL;
        ln_error_mesg               VARCHAR2 (600) := NULL;
        ln_error_flag               VARCHAR2 (150) := NULL;
        ln_max_rec_id               NUMBER := 0;
        ln_oldcat_id                NUMBER := 0;
        ln_newcatid                 NUMBER := 0;
        ln_oldinvcatid              NUMBER := 0;
        ln_newinvcatid              NUMBER := 0;
        ln_no_of_assigned_items     NUMBER := 0;
        ln_oms_no_of_assign_items   NUMBER := 0;
        ln_po_no_of_assign_items    NUMBER := 0;
    BEGIN
        msg (
               '*** Hierarchy Update Program for Style "'
            || p_style_v
            || '" and Color "'
            || p_color_v
            || '" Start at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        msg ('');



        g_style              := NULL;
        g_colorway           := NULL;
        g_style_name         := NULL;
        g_style_name_upr     := NULL;
        LOG ('Request ID: ' || gn_conc_request_id);
        LOG ('');
        g_style              := p_style_v;
        g_colorway           := p_color_v;
        LOG ('Item Style: ' || g_style);
        LOG ('Item Color: ' || g_colorway);
        LOG ('');
        v_item_description   := NULL;

        LOG (
            'Value for Style is: ' || g_style || ' Color is: ' || g_colorway);


        --Start Changes V5.0 --Commenting as this is handled in MAIN_PRC
        /*BEGIN

           l_rec_cnt := 0;

           SELECT COUNT (*)
             INTO l_rec_cnt
             FROM xxdo.xxdo_plm_staging
            WHERE     style = g_style
                  AND colorway = g_colorway
                  AND oracle_status = 'N'
                  AND attribute4 = 'HIERARCHY_UPDATE'
                  AND request_id IS NULL;
        EXCEPTION
           WHEN OTHERS
           THEN
              msg (
                    'Unexpected Error while fetching valid record count for Style "'
                 || g_style
                 || '" and Color "'
                 || g_colorway
                 || '". Exiting the program...');

              msg ('');
        END;

        ln_max_rec_id := 0;

        IF l_rec_cnt > 1
        THEN
           BEGIN
              SELECT MAX (record_id)
                INTO ln_max_rec_id
                FROM xxdo.xxdo_plm_staging
               WHERE     style = g_style
                     AND colorway = g_colorway
                     AND oracle_status = 'N'
                     AND attribute4 = 'HIERARCHY_UPDATE'
                     AND request_id IS NULL;
           EXCEPTION
              WHEN NO_DATA_FOUND
              THEN
                 msg (
                       'No Data Found While Fetching Max Record Id for Style "'
                    || g_style
                    || '" and Color "'
                    || g_colorway);
                 msg ('');
              WHEN OTHERS
              THEN
                 msg (
                       'Unexpected Error while fetching Max Record Id for Style "'
                    || g_style
                    || '" and Color "'
                    || g_colorway
                    || '". Exiting the program...');

                 msg ('');
           END;

           BEGIN
              UPDATE xxdo.xxdo_plm_staging
                 SET oracle_status = 'E',
                     oracle_error_message = 'Duplicate Record',
                     date_updated = SYSDATE
               WHERE     style = g_style
                     AND colorway = g_colorway
                     AND oracle_status = 'N'
                     AND attribute4 = 'HIERARCHY_UPDATE'
                     AND record_id <> ln_max_rec_id
                     AND request_id IS NULL;

              COMMIT;

              l_rec_cnt := 1;
           EXCEPTION
              WHEN NO_DATA_FOUND
              THEN
                 msg (
                       'No Data Found While Updating Duplicate Records With Style "'
                    || g_style
                    || '" and Color "'
                    || g_colorway);
                 msg ('');
              WHEN OTHERS
              THEN
                 msg (
                       'Unexpected Error while Updating Duplicate Records Status for Style "'
                    || g_style
                    || '" and Color "'
                    || g_colorway
                    || '". Exiting the program...');

                 msg ('');
           END;
        END IF;*/
        --End Changes V5.0

        BEGIN
            SELECT record_id, style_name, TRIM (UPPER (style_name))
              INTO gn_record_id, g_style_name, g_style_name_upr
              FROM xxdo.xxdo_plm_staging
             WHERE     style = g_style
                   AND colorway = g_colorway
                   AND oracle_status = 'N'
                   AND attribute4 = 'HIERARCHY_UPDATE'
                   AND request_id IS NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                msg (
                       'Valid record does not exist in staging table for Style "'
                    || g_style
                    || '" and Color "'
                    || g_colorway
                    || '". Exiting the program...');

                msg ('');
            WHEN OTHERS
            THEN
                msg (
                       'Unexpected Error while fetching the staging table record for Style "'
                    || g_style
                    || '" and Color "'
                    || g_colorway
                    || '". Exiting the program...');

                msg ('');
        END;

        IF gn_record_id IS NOT NULL
        THEN
            msg ('Processing Record ID : ' || gn_record_id);
            msg ('');
            LOG ('Style Name: ' || g_style_name);
            LOG ('Formatted Style Name: ' || g_style_name_upr);
            LOG ('');

            gn_master_orgid   := NULL;

            BEGIN
                SELECT organization_id
                  INTO gn_master_orgid
                  FROM org_organization_definitions
                 WHERE organization_code = gn_master_org_code;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    msg (
                        'XXDO: ORGANIZATION CODE profile has not been setup to find Master Org ID. Exiting the program...');

                    msg ('');
                WHEN OTHERS
                THEN
                    msg (
                        'Unexpected Error while fetching Master Org ID. Exiting the program...');

                    msg ('');
            END;

            IF gn_master_orgid IS NOT NULL
            THEN
                LOG ('Master Organization ID: ' || gn_master_orgid);
                LOG ('');
                -- STYLE_SEARCH -- Start
                --            g_item_search     := '%' || g_style || '-' || g_colorway || '%';
                g_item_search   := g_style || '-' || g_colorway || '-%';
                LOG ('Regular Item Search Criteria: ' || g_item_search);
                LOG ('');
                --            g_l_item_search   := '%' || g_style || 'L-' || g_colorway || '%';
                g_l_item_search   :=
                    'S' || g_style || 'L-' || g_colorway || '-%';

                LOG ('Sample L Item Search Criteria: ' || g_l_item_search);
                LOG ('');

                --            g_r_item_search   := '%' || g_style || 'R-' || g_colorway || '%';
                g_r_item_search   :=
                    'S' || g_style || 'R-' || g_colorway || '-%';
                LOG ('Sample R Item Search Criteria: ' || g_r_item_search);
                LOG ('');

                g_sr_item_search   :=
                    'SR' || g_style || '-' || g_colorway || '-%';
                LOG ('Sample SR Item Search Criteria: ' || g_sr_item_search);
                LOG ('');


                g_sl_item_search   :=
                    'SL' || g_style || '-' || g_colorway || '-%';
                LOG ('Sample SL Item Search Criteria: ' || g_sl_item_search);
                LOG ('');

                g_ss_item_search   :=
                    'SS' || g_style || '-' || g_colorway || '-%';
                LOG ('Sample SS Item Search Criteria: ' || g_ss_item_search);
                LOG ('');


                g_s_item_search   :=
                    'S' || g_style || '-' || g_colorway || '-%';
                LOG ('Sample S Item Search Criteria: ' || g_s_item_search);
                LOG ('');


                g_bg_item_search   :=
                    'BG' || g_style || '-' || g_colorway || '-%';
                LOG ('Bgrade Item Search Criteria: ' || g_bg_item_search);
                LOG ('');

                -- STYLE_SEARCH -- End
                --Start Changes V5.0 Commented the invalid style color combination as this is handled in the Main_prc
                BEGIN
                    l_item_cnt   := 0;

                    SELECT COUNT (*)
                      INTO l_item_cnt
                      FROM apps.mtl_system_items_b
                     WHERE     (   (segment1 LIKE g_item_search AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                                OR (segment1 LIKE g_l_item_search)
                                OR (segment1 LIKE g_r_item_search)
                                OR (segment1 LIKE g_sr_item_search)
                                OR (segment1 LIKE g_sl_item_search)
                                OR (segment1 LIKE g_ss_item_search)
                                OR (    segment1 LIKE g_s_item_search
                                    AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                        'GENERIC'))
                                OR (segment1 LIKE g_bg_item_search) -- STYLE_SEARCH - End
                                                                   )
                           AND organization_id = gn_master_orgid;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                               'Unexpected Error while fetching the Master Item for Style "'
                            || g_style
                            || '" and color "'
                            || g_colorway
                            || '". Exiting the program...');

                        msg ('');
                END;


                IF l_item_cnt = 0
                THEN
                    BEGIN
                        UPDATE xxdo.xxdo_plm_staging
                           SET oracle_status = 'E', date_updated = SYSDATE, request_id = gn_conc_request_id,
                               oracle_error_message = ('Style ' || g_style || ' and Color ' || g_colorway || ' does not exist in Item Master. ')
                         WHERE record_id = gn_record_id;

                        COMMIT;
                    END;

                    msg (
                           'Style "'
                        || g_style
                        || '" and Color "'
                        || g_colorway
                        || '" does not exist in Item Master. Exiting the program...');
                    msg ('');
                ELSE
                    LOG (
                        'Start Updating Staging Table with Request ID and other attributes.');

                    LOG ('');

                    BEGIN
                        UPDATE xxdo.xxdo_plm_staging xps
                           SET xps.request_id = gn_conc_request_id, style_name = TRIM (SUBSTR (style_name, 0, 40)), master_style = TRIM (SUBSTR (master_style, 0, 40)),
                               collection = TRIM (SUBSTR (collection, 0, 40)), production_line = TRIM (SUBSTR (production_line, 0, 40)), sub_class = TRIM (SUBSTR (sub_class, 0, 40)),
                               supplier = TRIM (SUBSTR (supplier, 0, 40)), sourcing_factory = TRIM (SUBSTR (sourcing_factory, 0, 40))
                         WHERE record_id = gn_record_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_error_flag   := 'E';
                            ln_error_mesg   :=
                                'Error occurred while updating staging table with Concurrent Request ID and other attributes.';


                            msg (
                                   'Error occurred while updating staging table with Concurrent Request id - '
                                || SQLERRM);
                            p_retcode       := 2;
                    END;

                    --Start changes V5.0

                    IF gv_old_style_number != g_style
                    THEN
                        BEGIN
                            SELECT COUNT (*)
                              INTO gn_style_cnt
                              FROM xxdo.xxdo_plm_staging xps
                             WHERE     1 = 1
                                   AND style = p_style_v
                                   AND oracle_status = 'N'
                                   AND attribute4 = 'HIERARCHY_UPDATE'--                            AND request_id = gn_conc_request_id
                                                                      --                            AND EXISTS
                                                                      --                                   (SELECT 1
                                                                      --                                      FROM xxd_common_items_v xci
                                                                      --                                     WHERE     1 = 1
                                                                      --                                           AND xps.style = xci.style_number
                                                                      --                                           AND xps.colorway = xci.color_code)
                                                                      ;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                LOG (
                                       'Error while getting the count of style '
                                    || g_style
                                    || '- - '
                                    || SQLERRM);
                        END;

                        --Start Changes V5.0
                        IF g_old_om_cat_table.EXISTS (1)
                        THEN
                            g_old_om_cat_table.DELETE;
                        END IF;

                        --END Changes V5.0

                        gn_old_style_cnt   := 0;
                    END IF;

                    gv_old_style_number   := g_style;

                    --End Changes V5.0

                    FOR rec_csr_stg_table IN csr_stg_table (gn_record_id)
                    LOOP
                        LOG (
                            'Request ID        : ' || rec_csr_stg_table.request_id);
                        LOG (
                            'Style Name        : ' || rec_csr_stg_table.style_name);
                        LOG (
                            'Master Style      : ' || rec_csr_stg_table.master_style);
                        LOG (
                            'Collection        : ' || rec_csr_stg_table.collection);
                        LOG (
                            'Production Line   : ' || rec_csr_stg_table.production_line);
                        LOG (
                            'Sub Class         : ' || rec_csr_stg_table.sub_class);
                        LOG (
                            'Supplier          : ' || rec_csr_stg_table.supplier);


                        LOG (
                            'Sourcing Factory  : ' || rec_csr_stg_table.sourcing_factory);
                    END LOOP;

                    LOG ('');


                    LOG (
                        'End Updating Staging Table with Request ID and other attributes.');

                    LOG ('');

                    BEGIN
                        SELECT UPPER (style_description)
                          INTO v_item_description
                          FROM xxdo.xxdo_plm_staging
                         WHERE record_id = gn_record_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            msg (
                                   'Item Description is NULL for style '
                                || g_style
                                || ' and color '
                                || g_colorway);
                        WHEN OTHERS
                        THEN
                            msg (
                                   'Unexpected Error while fetching the Item Description for style '
                                || g_style
                                || ' and color '
                                || g_colorway);
                    END;

                    msg ('New Item Description: ' || v_item_description);
                    msg ('');


                    msg (
                           '*** Begin Item Description Update Process at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        || ' ***');
                    msg ('');

                    BEGIN
                        IF v_item_description IS NOT NULL
                        THEN
                            update_description (v_item_description,
                                                lv_desc_upd_retcode,
                                                lv_desc_upd_reterror);


                            IF lv_desc_upd_retcode = 0
                            THEN
                                BEGIN
                                    gv_error_desc   := NULL;

                                    UPDATE xxdo.xxdo_plm_staging
                                       SET oracle_status = 'P', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                     WHERE record_id = gn_record_id;

                                    COMMIT;
                                END;
                            ELSE
                                BEGIN
                                    gv_error_desc   :=
                                           gv_error_desc
                                        || 'Item Description Update Failed. ';

                                    UPDATE xxdo.xxdo_plm_staging
                                       SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                     WHERE record_id = gn_record_id;

                                    COMMIT;
                                END;
                            END IF;
                        ELSE
                            msg (
                                'New Item Description is NULL. Skipping Item Description Update');

                            msg ('');
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                   'Exception while updating the Item Desciption :: '
                                || SQLERRM);
                    END;



                    msg (
                           '*** End Item Description Update Process at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        || ' ***');
                    msg ('');



                    msg (
                           '*** Begin PO Requisition Lines Item Description Update Process at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        || ' ***');
                    msg ('');

                    BEGIN
                        IF ((v_item_description IS NOT NULL) AND (lv_desc_upd_retcode = 0))
                        THEN
                            update_poreq_item_desc (v_item_description,
                                                    lv_po_desc_upd_retcode,
                                                    lv_po_desc_upd_reter);


                            IF lv_po_desc_upd_retcode = 0
                            THEN
                                BEGIN
                                    UPDATE xxdo.xxdo_plm_staging
                                       SET oracle_status = 'P', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                     WHERE record_id = gn_record_id;

                                    COMMIT;
                                END;
                            ELSE
                                BEGIN
                                    gv_error_desc   :=
                                           gv_error_desc
                                        || 'PO Requisition Lines Item Description Update failed. ';

                                    UPDATE xxdo.xxdo_plm_staging
                                       SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                     WHERE record_id = gn_record_id;

                                    COMMIT;
                                END;
                            END IF;
                        ELSE
                            msg (
                                'Skipping PO Requisition Lines Item Description Update since Item Description IS NULL or Item Description Update failed...');

                            msg ('');
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                   'Exception while updating PO Requisition Lines Item Description :: '
                                || SQLERRM);
                    END;



                    msg (
                           '*** End PO Requisition Lines Item Description Update Process at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        || ' ***');
                    msg ('');



                    msg (
                           '*** Start Category Creation at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        || ' ***');
                    msg ('');

                    -- Fetching Category Set Details for OM SALES CATEGORY.
                    BEGIN
                        get_category_set_details (gv_om_sales_set_name,
                                                  gn_om_sales_set_id,
                                                  gn_om_sales_structure_id);



                        LOG (
                               'OM Sales Category Set Name: '
                            || gv_om_sales_set_name);
                        LOG (
                               'OM Sales Category Set ID: '
                            || gn_om_sales_set_id);


                        LOG (
                               'OM Sales Category Structure ID: '
                            || gn_om_sales_structure_id);
                        LOG ('');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            gn_om_sales_set_id         := NULL;
                            gn_om_sales_structure_id   := NULL;
                    END;

                    -- Fetching the old OM Sales Category Assignment values
                    BEGIN
                        --Start Cahnges V5.0

                        gn_old_style_cnt   := gn_old_style_cnt + 1;

                        LOG ('gn_old_style_cnt - ' || gn_old_style_cnt);
                        LOG ('gn_style_cnt - ' || gn_style_cnt);

                        IF gn_old_style_cnt = 1
                        THEN
                            --End Changes V5.0
                            FOR rec_csr_om_cat_old IN csr_om_cat_old
                            LOOP
                                ln_om_cnt   := ln_om_cnt + 1;
                                g_old_om_cat_table (ln_om_cnt).category_id   :=
                                    rec_csr_om_cat_old.category_id;
                                g_old_om_cat_table (ln_om_cnt).category_set_id   :=
                                    rec_csr_om_cat_old.category_set_id;
                                g_old_om_cat_table (ln_om_cnt).item_number   :=
                                    rec_csr_om_cat_old.attribute28;



                                g_old_om_cat_table (ln_om_cnt).segment1   :=
                                    rec_csr_om_cat_old.style_number;
                            END LOOP;
                        --Start Changes V5.0
                        END IF;

                        --End Changes V5.0



                        FOR i IN 1 .. g_old_om_cat_table.COUNT
                        LOOP
                            LOG (
                                   'Category ID :: '
                                || g_old_om_cat_table (i).category_id
                                || ' Category Set ID :: '
                                || g_old_om_cat_table (i).category_set_id
                                || ' Item Type :: '
                                || g_old_om_cat_table (i).item_number);
                            LOG ('');
                        END LOOP;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                'Exception raised while fetching old OM Sales Category Assignment values');

                            ln_error_flag   := 'E';
                            ln_error_mesg   :=
                                'Exception raised while fetching old OM Sales Category Assignment values. ';

                            p_retcode       := 2;
                    END;

                    -- Fetching Category Set Details for INVENTORY.
                    BEGIN
                        get_category_set_details (gv_inventory_set_name,
                                                  gn_inventory_set_id,
                                                  gn_inventory_structure_id);



                        LOG (
                               'Inventory Category Set Name: '
                            || gv_inventory_set_name);
                        LOG (
                               'Inventory Category Set ID: '
                            || gn_inventory_set_id);


                        LOG (
                               'Inventory Category Structure ID: '
                            || gn_inventory_structure_id);
                        LOG ('');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            gn_inventory_set_id         := NULL;
                            gn_inventory_structure_id   := NULL;
                    END;

                    -- Fetching the old Inventory Category Assignment values
                    BEGIN
                        FOR rec_csr_inv_cat_old IN csr_inv_cat_old
                        LOOP
                            ln_inv_cnt   := ln_inv_cnt + 1;
                            g_old_inv_cat_table (ln_inv_cnt).category_id   :=
                                rec_csr_inv_cat_old.category_id;
                            g_old_inv_cat_table (ln_inv_cnt).category_set_id   :=
                                rec_csr_inv_cat_old.category_set_id;
                            g_old_inv_cat_table (ln_inv_cnt).item_number   :=
                                rec_csr_inv_cat_old.attribute28;
                        END LOOP;

                        FOR i IN 1 .. g_old_inv_cat_table.COUNT
                        LOOP
                            msg (
                                   'Category ID :: '
                                || g_old_inv_cat_table (i).category_id
                                || ' Category Set ID :: '
                                || g_old_inv_cat_table (i).category_set_id
                                || ' Item Type :: '
                                || g_old_inv_cat_table (i).item_number);
                            msg ('');
                        END LOOP;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                'Exception raised while fetching old Inventory Category Assignment values');

                            ln_error_flag   := 'E';
                            ln_error_mesg   :=
                                'Exception raised while fetching old Inventory Category Assignment values. ';

                            p_retcode       := 2;
                    END;

                    -- DISABLE_ILR_CATEGORIES - Start
                    --DISABLE_GENERIC_CATEGORIES -- Start
                    --                IF TRANSLATE(g_colorway, '0123456789', '@@@@@@@@@@') like '%@%' THEN
                    IF g_old_gen_inv_cat_table.EXISTS (1)
                    THEN
                        g_old_gen_inv_cat_table.DELETE;
                    END IF;



                    ln_inv_cnt            := 0;

                    -- Fetching the old Inventory Category Assignment values for ILR Generic items
                    BEGIN
                        FOR rec_csr_inv_cat_old_gen IN csr_inv_cat_old_gen
                        LOOP
                            ln_inv_cnt   := ln_inv_cnt + 1;
                            g_old_gen_inv_cat_table (ln_inv_cnt).category_id   :=
                                rec_csr_inv_cat_old_gen.category_id;
                            g_old_gen_inv_cat_table (ln_inv_cnt).category_set_id   :=
                                rec_csr_inv_cat_old_gen.category_set_id;
                            g_old_gen_inv_cat_table (ln_inv_cnt).item_number   :=
                                rec_csr_inv_cat_old_gen.attribute28;
                        END LOOP;

                        IF g_old_gen_inv_cat_table.EXISTS (1)
                        THEN
                            FOR i IN 1 .. g_old_gen_inv_cat_table.COUNT
                            LOOP
                                msg (
                                       'ILR Item Category ID :: '
                                    || g_old_gen_inv_cat_table (i).category_id
                                    || ' Category Set ID :: '
                                    || g_old_gen_inv_cat_table (i).category_set_id
                                    || ' Item Type :: '
                                    || g_old_gen_inv_cat_table (i).item_number);



                                msg ('');
                            END LOOP;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                'Exception raised while fetching old Inventory Category Assignment values');

                            ln_error_flag   := 'E';

                            ln_error_mesg   :=
                                'Exception raised while fetching old Inventory Category Assignment values. ';



                            p_retcode       := 2;
                    END;

                    --                ELSE                      -- DISABLE_GENERIC_CATEGORIES -- Start
                    --                   IF g_old_gen_inv_cat_table.EXISTS(1) THEN
                    --                      g_old_gen_inv_cat_table.DELETE;
                    --                   END IF;
                    -- DISABLE_GENERIC_CATEGORIES -End
                    --                END IF;
                    -- DISABLE_ILR_CATEGORIES - End


                    -- Fetching Category Set Details for PO ITEM CATEGORY.

                    BEGIN
                        get_category_set_details (gn_po_item_set_name,
                                                  gn_po_item_set_id,
                                                  gn_po_item_structure_id);

                        LOG (
                               'PO Item Category Set Name: '
                            || gn_po_item_set_name);
                        LOG (
                            'PO Item Category Set ID: ' || gn_po_item_set_id);


                        LOG (
                               'PO Item Category Structure ID: '
                            || gn_po_item_structure_id);
                        LOG ('');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            gn_po_item_set_id         := NULL;
                            gn_po_item_structure_id   := NULL;
                    END;

                    -- Fetching the old PO Item Category Assignment values
                    BEGIN
                        FOR rec_csr_po_item_cat_old IN csr_po_item_cat_old
                        LOOP
                            ln_po_cnt   := ln_po_cnt + 1;
                            g_old_po_cat_table (ln_po_cnt).category_id   :=
                                rec_csr_po_item_cat_old.category_id;
                            g_old_po_cat_table (ln_po_cnt).category_set_id   :=
                                rec_csr_po_item_cat_old.category_set_id;
                            g_old_po_cat_table (ln_po_cnt).item_number   :=
                                rec_csr_po_item_cat_old.attribute28;
                        END LOOP;

                        FOR i IN 1 .. g_old_po_cat_table.COUNT
                        LOOP
                            msg (
                                   'Category ID :: '
                                || g_old_po_cat_table (i).category_id
                                || ' Category Set ID :: '
                                || g_old_po_cat_table (i).category_set_id
                                || ' Item Type :: '
                                || g_old_po_cat_table (i).item_number);
                            msg ('');
                        END LOOP;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                'Exception raised while fetching old PO Item Category Assignment values');

                            ln_error_flag   := 'E';
                            ln_error_mesg   :=
                                'Exception raised while fetching old PO Item Category Assignment values. ';

                            p_retcode       := 2;
                    END;

                    -- Fetching the Brand
                    BEGIN
                        SELECT brand
                          INTO p_brand_v
                          FROM xxdo.xxdo_plm_staging
                         WHERE record_id = gn_record_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg ('Exception raised while fetching Brand.');
                            ln_error_flag   := 'E';
                            ln_error_mesg   :=
                                'Error occurred while fetching Brand. ';


                            p_retcode       := 2;
                    END;

                    LOG ('Brand : ' || p_brand_v);
                    LOG ('');
                    --**********************************************************************************
                    -- Calling  pre_process_validation procedure to create categories
                    --**********************************************************************************


                    msg (
                           '*** Start Pre Process Validation at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        || ' ***');
                    msg ('');

                    SAVEPOINT start_main;

                    BEGIN
                        pre_process_validation (p_brand_v, p_style_v, pv_reterror
                                                , pv_retcode);



                        IF     (pv_reterror IS NOT NULL OR pv_retcode IS NOT NULL)
                           AND NVL (pv_reterror, 'X') <> 'No Update Required'
                        THEN
                            msg ('');
                            msg (
                                   'Error in Pre Process Validation'
                                || pv_reterror);

                            BEGIN
                                gv_error_desc   :=
                                       gv_error_desc
                                    || 'Error in Pre Process Validation. ';

                                UPDATE xxdo.xxdo_plm_staging
                                   SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                 WHERE record_id = gn_record_id;

                                COMMIT;
                            END;
                        ELSE
                            BEGIN
                                msg ('');
                                msg (
                                       'Pre Process Validation Success'
                                    || pv_reterror);

                                UPDATE xxdo.xxdo_plm_staging
                                   SET oracle_status = 'P', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                 WHERE record_id = gn_record_id;

                                COMMIT;



                                IF NVL (pv_reterror, 'X') =
                                   'No Update Required'
                                THEN
                                    LOG (
                                        'No Category Update is required. Items have the same categories already');

                                    IF gv_sub_division_updated = 'Y'
                                    THEN
                                        LOG (
                                            'Sub Division is updated on Inventory Item Categories DFF');
                                    END IF;

                                    gv_sub_division_updated   := 'N';
                                END IF;
                            END;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                   ' Exception while Pre Process Validation :: '
                                || SQLERRM);
                    END;

                    msg ('');


                    msg (
                           '*** End Pre Process Validation at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        || ' ***');
                    msg ('');


                    msg (
                           '*** End Category Creation at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        || ' ***');
                    msg ('');

                    IF gv_retcode > 0
                    THEN
                        msg (
                            'Skipping Category Assignment since Category Creation process is unsuccessful...');

                        msg ('');
                    ELSE
                        --*************************************************
                        -- Assigning Categories
                        --************************************************


                        msg (
                               '*** Start Category Assignment at :: '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                            || ' ***');
                        msg ('');

                        gv_cat_asgn_err_cnt     := 0;
                        gv_inv_error_cnt        := 0;
                        gv_inv_oldnew_cat_cnt   := 0;
                        gv_omsales_error_cnt    := 0;

                        gv_po_error_cnt         := 0;
                        gv_oms_oldnew_cat_cnt   := 0;
                        ln_oldcat_id            := 0;

                        ln_newcatid             := 0;

                        BEGIN
                            FOR items_cat_assi_rec IN csr_item_cat_assign
                            LOOP
                                --*************************************************
                                -- Assigning Inventory Category
                                --************************************************
                                BEGIN
                                    gv_retcode    := NULL;
                                    gv_reterror   := NULL;

                                    BEGIN
                                        SELECT category_id
                                          INTO ln_newinvcatid
                                          FROM apps.mtl_categories
                                         WHERE     segment1 =
                                                   items_cat_assi_rec.brand
                                               AND segment2 =
                                                   items_cat_assi_rec.gender
                                               AND segment3 =
                                                   items_cat_assi_rec.product_group
                                               AND segment4 =
                                                   items_cat_assi_rec.class
                                               AND segment5 =
                                                   items_cat_assi_rec.sub_class
                                               AND segment6 =
                                                   items_cat_assi_rec.master_style
                                               AND segment7 =
                                                   items_cat_assi_rec.style_name
                                               AND segment8 =
                                                   items_cat_assi_rec.colorway
                                               AND structure_id =
                                                   gn_inventory_structure_id
                                               AND NVL (enabled_flag, 'Y') =
                                                   'Y';
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_newinvcatid   := 0;
                                        WHEN OTHERS
                                        THEN
                                            msg (
                                                   'Unexpected error while fetching new Inventory Category for the item :: '
                                                || items_cat_assi_rec.style_name);
                                    END;

                                    BEGIN
                                        SELECT category_id
                                          INTO ln_oldinvcatid
                                          FROM apps.mtl_item_categories
                                         WHERE     inventory_item_id =
                                                   items_cat_assi_rec.item_id
                                               AND organization_id =
                                                   items_cat_assi_rec.organization_id
                                               AND category_set_id =
                                                   gn_inventory_set_id;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_oldinvcatid   := 0;
                                        WHEN OTHERS
                                        THEN
                                            msg (
                                                   'Unexpected error while fetching Old Inventory Category for the item :: '
                                                || items_cat_assi_rec.style_name);
                                    END;


                                    IF ln_newinvcatid = ln_oldinvcatid
                                    THEN
                                        gv_inv_oldnew_cat_cnt   :=
                                            gv_inv_oldnew_cat_cnt + 1;
                                    END IF;

                                    assign_inventory_category (items_cat_assi_rec.brand, items_cat_assi_rec.gender, items_cat_assi_rec.product_group, items_cat_assi_rec.class, items_cat_assi_rec.sub_class, items_cat_assi_rec.master_style, items_cat_assi_rec.style_name, items_cat_assi_rec.colorway, items_cat_assi_rec.organization_id, items_cat_assi_rec.currentseason, UPPER (TRIM (items_cat_assi_rec.colorwaystatus)), items_cat_assi_rec.style, items_cat_assi_rec.item_id, items_cat_assi_rec.segment1, gv_retcode
                                                               , gv_reterror);

                                    IF    gv_retcode IS NOT NULL
                                       OR gv_reterror IS NOT NULL
                                    THEN
                                        gv_inv_error_cnt   :=
                                            gv_inv_error_cnt + 1;
                                        gv_cat_asgn_err_cnt   :=
                                            gv_cat_asgn_err_cnt + 1;



                                        msg (
                                               'Error Ocurred While assigning Inventory category for '
                                            || items_cat_assi_rec.segment1
                                            || '. ');
                                    END IF;
                                END;

                                --*************************************************
                                -- Assign OM SALES Category
                                --************************************************
                                BEGIN
                                    gv_retcode    := NULL;
                                    gv_reterror   := NULL;

                                    -- Assigning OM Sales Category

                                    BEGIN
                                        SELECT category_id
                                          INTO ln_newcatid
                                          FROM apps.mtl_categories
                                         WHERE     segment1 =
                                                   items_cat_assi_rec.style_name
                                               AND structure_id =
                                                   gn_om_sales_structure_id
                                               AND NVL (enabled_flag, 'Y') =
                                                   'Y';
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_newcatid   := 0;
                                        WHEN OTHERS
                                        THEN
                                            msg (
                                                   'Unexpected error while fetching new OM Sales Category for the item :: '
                                                || items_cat_assi_rec.style_name);
                                    END;


                                    BEGIN
                                        SELECT category_id
                                          INTO ln_oldcat_id
                                          FROM apps.mtl_item_categories
                                         WHERE     inventory_item_id =
                                                   items_cat_assi_rec.item_id -- pn_item_id
                                               AND organization_id =
                                                   items_cat_assi_rec.organization_id
                                               AND category_set_id =
                                                   gn_om_sales_set_id;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_oldcat_id   := 0;
                                        WHEN OTHERS
                                        THEN
                                            msg (
                                                   'Unexpected error while fetching Old OM Sales Category for the item :: '
                                                || items_cat_assi_rec.style_name);
                                    END;


                                    IF ln_newcatid = ln_oldcat_id
                                    THEN
                                        gv_oms_oldnew_cat_cnt   :=
                                            gv_oms_oldnew_cat_cnt + 1;
                                    ELSE
                                        gv_oms_oldnew_cat_cnt   :=
                                            gv_oms_oldnew_cat_cnt - 9999;
                                    END IF;

                                    assign_category (
                                        items_cat_assi_rec.style_name,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        items_cat_assi_rec.item_id,
                                        items_cat_assi_rec.organization_id,
                                        items_cat_assi_rec.colorwaystatus,
                                        'OM Sales Category',
                                        items_cat_assi_rec.segment1,
                                        gv_retcode,
                                        gv_reterror);

                                    IF    gv_retcode IS NOT NULL
                                       OR gv_reterror IS NOT NULL
                                    THEN
                                        gv_omsales_error_cnt   :=
                                            gv_omsales_error_cnt + 1;

                                        gv_cat_asgn_err_cnt   :=
                                            gv_cat_asgn_err_cnt + 1;



                                        msg (
                                               'Error Ocurred While assigning OM Sales category for '
                                            || items_cat_assi_rec.segment1
                                            || '. ');
                                    END IF;
                                END;

                                --*************************************************
                                -- Assign PO Item category
                                --************************************************
                                BEGIN
                                    --lv_error_mesg := NULL;
                                    gv_retcode    := NULL;
                                    gv_reterror   := NULL;
                                    -- Assigning PO Item Category

                                    assign_category (
                                        'Trade',
                                        items_cat_assi_rec.class,
                                        items_cat_assi_rec.style_name,
                                        NULL,
                                        NULL,
                                        items_cat_assi_rec.item_id,
                                        items_cat_assi_rec.organization_id,
                                        UPPER (
                                            TRIM (
                                                items_cat_assi_rec.colorwaystatus)),
                                        'PO Item Category',
                                        items_cat_assi_rec.segment1,
                                        gv_retcode,
                                        gv_reterror);

                                    IF    gv_retcode IS NOT NULL
                                       OR gv_reterror IS NOT NULL
                                    THEN
                                        gv_po_error_cnt   :=
                                            gv_po_error_cnt + 1;
                                        gv_cat_asgn_err_cnt   :=
                                            gv_cat_asgn_err_cnt + 1;



                                        msg (
                                               'Error Ocurred While assigning PO Item category for '
                                            || items_cat_assi_rec.segment1
                                            || '. ');
                                    END IF;
                                END;

                                msg ('');
                            END LOOP;                   -- csr_item_cat_assign

                            IF gv_cat_asgn_err_cnt = 0
                            THEN
                                msg (
                                       'Category Assignment Success for all the items with the Style :: '
                                    || g_style
                                    || ' and Color :: '
                                    || g_colorway
                                    || ' combination.');
                                msg ('');
                            ELSE
                                msg (
                                       'Category Assignment failed for one or more items with the Style :: '
                                    || g_style
                                    || ' and Color :: '
                                    || g_colorway
                                    || ' combination.');
                                msg ('');

                                gv_error_desc   :=
                                       gv_error_desc
                                    || 'Error Ocurred While Category Assignment. ';

                                BEGIN
                                    UPDATE xxdo.xxdo_plm_staging
                                       SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                     WHERE record_id = gn_record_id;

                                    COMMIT;
                                END;
                            END IF;



                            msg (
                                   '*** End Category Assignment at :: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS')
                                || ' ***');
                            msg ('');
                        END;
                    END IF;


                    --               IF gv_inv_oldnew_cat_cnt > 0



                    --               THEN
                    --                  msg
                    --                  (
                    --                     'Skipping Sourcing Rule Update since Inventory Category did not change...'

                    --                  );
                    --                  msg ('');
                    --               ELSIF gv_inv_error_cnt > 0
                    IF gv_inv_error_cnt > 0
                    THEN
                        msg (
                            'Inventory Cateogory assignment is unsuccessful for one or more items. Skipping Sourcing Rule Update... ');
                    ELSE
                        BEGIN
                            msg (
                                   '*** Start Sourcing Rule Update at :: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS')
                                || ' ***');
                            msg ('');
                            msg ('');

                            gv_src_rule_upd_err_cnt   := 0;

                            FOR csr_src_rule_upd_rec IN csr_src_rule_upd
                            LOOP
                                v_sl                     := 1;
                                v_message                := NULL;
                                v_return_status          := NULL;
                                ln_new_src_rule_cat_id   := 0;
                                ln_new_src_cat_name      := NULL;
                                v_assignment_tbl         :=
                                    mrp_src_assignment_pub.g_miss_assignment_tbl;

                                --Start Changes V5.0
                                IF v_assignment_tbl.COUNT <> 0
                                THEN
                                    v_assignment_tbl.delete;
                                END IF;

                                --End Changes V5.0

                                BEGIN
                                    SELECT category_id, segment7
                                      INTO ln_new_src_rule_cat_id, ln_new_src_cat_name
                                      FROM mtl_categories
                                     WHERE     structure_id = 101
                                           AND segment1 =
                                               csr_src_rule_upd_rec.brand
                                           AND segment2 =
                                               csr_src_rule_upd_rec.division
                                           AND segment3 =
                                               csr_src_rule_upd_rec.product_group
                                           AND segment4 =
                                               csr_src_rule_upd_rec.class
                                           AND segment5 =
                                               csr_src_rule_upd_rec.sub_class
                                           AND segment6 =
                                               csr_src_rule_upd_rec.master_style
                                           AND segment7 =
                                               DECODE (
                                                   SUBSTR (
                                                       csr_src_rule_upd_rec.sourcing_rule_name,
                                                       1,
                                                       2),
                                                   'BG',    'BG'
                                                         || csr_src_rule_upd_rec.style_name,
                                                   'SS',    'SS'
                                                         || csr_src_rule_upd_rec.style_name,
                                                   'SR',    'SR'
                                                         || csr_src_rule_upd_rec.style_name,
                                                   'SL',    'SL'
                                                         || csr_src_rule_upd_rec.style_name,
                                                   csr_src_rule_upd_rec.style_name)
                                           AND segment8 =
                                               csr_src_rule_upd_rec.color_description;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        msg (
                                               'New Inventory Category not found for style '
                                            || g_style
                                            || ' and color '
                                            || g_colorway);
                                    WHEN OTHERS
                                    THEN
                                        msg (
                                               'Unexpected Error while fetching New Inventory Category for style '
                                            || g_style
                                            || ' and color '
                                            || g_colorway);
                                END;


                                IF csr_src_rule_upd_rec.category_id <>
                                   ln_new_src_rule_cat_id
                                THEN
                                    --*************************************************
                                    -- Calling API for Sourcing Rule Update
                                    --************************************************
                                    BEGIN
                                        v_assignment_tbl   :=
                                            mrp_src_assignment_pub.g_miss_assignment_tbl;
                                        v_assignment_tbl (v_sl).assignment_set_id   :=
                                            csr_src_rule_upd_rec.assignment_set_id;

                                        v_assignment_tbl (v_sl).assignment_id   :=
                                            csr_src_rule_upd_rec.assignment_id;



                                        v_assignment_tbl (v_sl).assignment_type   :=
                                            5;
                                        v_assignment_tbl (v_sl).sourcing_rule_type   :=
                                            1;
                                        v_assignment_tbl (v_sl).category_id   :=
                                            ln_new_src_rule_cat_id;
                                        v_assignment_tbl (v_sl).category_set_id   :=
                                            1;
                                        v_assignment_tbl (v_sl).organization_id   :=
                                            csr_src_rule_upd_rec.organization_id;
                                        v_assignment_tbl (v_sl).sourcing_rule_id   :=
                                            csr_src_rule_upd_rec.sourcing_rule_id;



                                        v_assignment_tbl (v_sl).operation   :=
                                            'UPDATE';
                                        fnd_msg_pub.delete_msg (NULL);
                                        mrp_src_assignment_pub.process_assignment (
                                            p_api_version_number   => 1.0,
                                            p_init_msg_list        =>
                                                fnd_api.g_true,
                                            p_return_values        =>
                                                fnd_api.g_true,
                                            p_commit               =>
                                                fnd_api.g_true,
                                            x_return_status        =>
                                                v_return_status,
                                            x_msg_count            =>
                                                x_msg_count,
                                            x_msg_data             =>
                                                x_msg_data,
                                            p_assignment_set_rec   =>
                                                v_assignment_set_rec,
                                            p_assignment_set_val_rec   =>
                                                v_assignment_set_val_rec,
                                            p_assignment_tbl       =>
                                                v_assignment_tbl,
                                            p_assignment_val_tbl   =>
                                                v_assignment_val_tbl,
                                            x_assignment_set_rec   =>
                                                x_assignment_set_rec,
                                            x_assignment_set_val_rec   =>
                                                x_assignment_set_val_rec,
                                            x_assignment_tbl       =>
                                                x_assignment_tbl,
                                            x_assignment_val_tbl   =>
                                                x_assignment_val_tbl);
                                    END;



                                    IF (v_return_status = fnd_api.g_ret_sts_success)
                                    THEN
                                        msg (
                                               '     => Sourcing Rule "'
                                            || csr_src_rule_upd_rec.sourcing_rule_name
                                            || '" with Sourcing Rule ID "'
                                            || csr_src_rule_upd_rec.sourcing_rule_id
                                            || '" under organization "'
                                            || csr_src_rule_upd_rec.organization_id
                                            || '" has been updated with Category "'
                                            || ln_new_src_cat_name
                                            || '"');
                                        msg (
                                               '     => Return Status :: '
                                            || v_return_status);
                                        msg ('');
                                    ELSE
                                        gv_src_rule_upd_err_cnt   :=
                                            gv_src_rule_upd_err_cnt + 1;
                                        msg (
                                               '     => Sourcing Rule "'
                                            || csr_src_rule_upd_rec.sourcing_rule_name
                                            || '" with Sourcing Rule ID "'
                                            || csr_src_rule_upd_rec.sourcing_rule_id
                                            || '" under organization "'
                                            || csr_src_rule_upd_rec.organization_id
                                            || '" has not been updated with Category "'
                                            || ln_new_src_cat_name
                                            || '"');
                                        msg (
                                               '     => Return Status :: '
                                            || v_return_status);
                                        msg ('');



                                        INSERT INTO xxdo.xxdo_plm_item_upd_errors
                                                 VALUES (
                                                            gn_record_id,
                                                            g_style,
                                                            g_colorway,
                                                            csr_src_rule_upd_rec.organization_id,
                                                               'Sourcing Rule Error: Sourcing Rule Name: '
                                                            || csr_src_rule_upd_rec.sourcing_rule_name
                                                            || ' Error: '
                                                            || v_return_status,
                                                            SYSDATE);

                                        COMMIT;
                                    END IF;
                                END IF;              -- Category Id same check
                            END LOOP;

                            IF gv_src_rule_upd_err_cnt = 0
                            THEN
                                msg (
                                       'Sourcing Rule Update Process Success for all the Sourcing Rules with the Style :: '
                                    || g_style
                                    || ' and Color :: '
                                    || g_colorway
                                    || ' combination.');
                                msg ('');
                            ELSE
                                msg (
                                       'Sourcing Rule Update Process failed for one or more Sourcing Rules with the Style :: '
                                    || g_style
                                    || ' and Color :: '
                                    || g_colorway
                                    || ' combination.');
                                msg ('');

                                BEGIN
                                    gv_error_desc   :=
                                           gv_error_desc
                                        || 'Error during Sourcing Rule Update Process. ';

                                    UPDATE xxdo.xxdo_plm_staging
                                       SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                     WHERE record_id = gn_record_id;

                                    COMMIT;
                                END;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                msg (
                                       ' Exception in Sourcing Rule Update Process :: '
                                    || SQLERRM);
                                msg ('');
                        END;



                        msg (
                               '*** End Sourcing Rule Update at :: '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                            || ' ***');
                        msg ('');
                    END IF;

                    IF gn_old_style_cnt = gn_style_cnt
                    THEN
                        IF gv_oms_oldnew_cat_cnt > 0
                        THEN
                            msg (
                                'Skipping Price List Lines Update since OM Sales Category did not change...');

                            msg ('');
                            LOG (
                                   'gv_oms_oldnew_cat_cnt:'
                                || gv_oms_oldnew_cat_cnt);
                        ELSIF gv_omsales_error_cnt > 0
                        THEN
                            msg (
                                'OM Sales Cateogory assignment is unsuccessful for one or more items. Skipping Price List Lines update... ');

                            LOG (
                                   'gv_omsales_error_cnt:'
                                || gv_omsales_error_cnt);
                        ELSE
                            LOG (
                                   'gv_oms_oldnew_cat_cnt:'
                                || gv_oms_oldnew_cat_cnt);
                            LOG (
                                   'gv_omsales_error_cnt:'
                                || gv_omsales_error_cnt);

                            BEGIN
                                msg (
                                       '*** Start Price List Lines Update at :: '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS')
                                    || ' ***');
                                msg ('');

                                gv_retcode    := NULL;
                                gv_reterror   := NULL;

                                FOR i IN 1 .. g_old_om_cat_table.COUNT
                                LOOP
                                    ln_loop_cat_id            :=
                                        g_old_om_cat_table (i).category_id;
                                    ln_loop_item_type         :=
                                        g_old_om_cat_table (i).item_number;
                                    msg (
                                           '$ Loop Category ID :: '
                                        || ln_loop_cat_id);
                                    msg ('');

                                    gv_prc_list_upd_err_cnt   := 0;

                                    FOR rec_csr_prc_list
                                        IN csr_prc_list (ln_loop_cat_id)
                                    LOOP
                                        LOG (
                                               'rec_csr_prc_list.product_attr_value:'
                                            || rec_csr_prc_list.product_attr_value);


                                        BEGIN
                                            SELECT category_id, segment1
                                              INTO ln_old_prc_om_cat_id, ln_old_prc_om_cat
                                              FROM apps.mtl_categories
                                             WHERE     category_id =
                                                       rec_csr_prc_list.product_attr_value
                                                   AND structure_id =
                                                       gn_om_sales_structure_id
                                                   AND NVL (enabled_flag,
                                                            'Y') =
                                                       'Y';



                                            msg (
                                                   '~~ Old Category :: '
                                                || ln_old_prc_om_cat);
                                            msg ('');
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                msg (
                                                       'Unexpected Error while fetching the Category Details for the Old Category ID '
                                                    || rec_csr_prc_list.product_attr_value);
                                        END;

                                        BEGIN
                                            SELECT category_id, segment1
                                              INTO ln_new_prc_om_cat_id, ln_new_prc_om_cat
                                              FROM apps.mtl_categories
                                             WHERE     segment1 =
                                                       (CASE
                                                            WHEN SUBSTR (ln_old_prc_om_cat, 1, 2) = 'BG'
                                                            THEN
                                                                'BG' || g_style_name_upr
                                                            WHEN SUBSTR (ln_old_prc_om_cat, 1, 2) = 'SS' AND ln_loop_item_type = 'SAMPLE' -- STYLE_SEARCH
                                                            THEN
                                                                'SS' || g_style_name_upr
                                                            WHEN SUBSTR (ln_old_prc_om_cat, 1, 2) = 'SL'
                                                            THEN
                                                                'SL' || g_style_name_upr
                                                            WHEN SUBSTR (ln_old_prc_om_cat, 1, 2) = 'SR'
                                                            THEN
                                                                'SR' || g_style_name_upr
                                                            WHEN ln_loop_item_type = 'SAMPLE-L'
                                                            THEN
                                                                'S' || SUBSTR (g_style_name_upr, 1, (INSTR (g_style_name_upr, '-', 1)) - 1) || 'L' || SUBSTR (g_style_name_upr, INSTR (g_style_name_upr, '-'))
                                                            WHEN ln_loop_item_type = 'SAMPLE-R'
                                                            THEN
                                                                'S' || SUBSTR (g_style_name_upr, 1, (INSTR (g_style_name_upr, '-', 1)) - 1) || 'R' || SUBSTR (g_style_name_upr, INSTR (g_style_name_upr, '-'))
                                                            WHEN ln_loop_item_type = 'SAMPLE' --STYLE_SEARCH - Start
                                                            THEN
                                                                'S' || SUBSTR (g_style_name_upr, 1, (INSTR (g_style_name_upr, '-', 1)) - 1) || SUBSTR (g_style_name_upr, INSTR (g_style_name_upr, '-'))
                                                            ELSE --STYLE_SEARCH - End
                                                                g_style_name_upr
                                                        END)
                                                   AND structure_id =
                                                       gn_om_sales_structure_id
                                                   AND NVL (enabled_flag,
                                                            'Y') =
                                                       'Y';



                                            msg (
                                                   '~~ New Category :: '
                                                || ln_new_prc_om_cat);
                                            msg ('');
                                        EXCEPTION
                                            WHEN NO_DATA_FOUND
                                            THEN
                                                msg (
                                                    'Category details does not exist for the new category ');

                                                ln_new_prc_om_cat_id   :=
                                                    NULL;      -- NO_CAT_FOUND
                                            WHEN TOO_MANY_ROWS
                                            THEN
                                                msg (
                                                    'More than one record exist for category ');

                                                ln_new_prc_om_cat_id   :=
                                                    NULL;       --NO_CAT_FOUND
                                            WHEN OTHERS
                                            THEN
                                                msg (
                                                    'Unexpected Error while fetching the category details for the category ');

                                                ln_new_prc_om_cat_id   :=
                                                    NULL;      -- NO_CAT_FOUND
                                        END;

                                        IF ln_old_prc_om_cat_id <>
                                           ln_new_prc_om_cat_id
                                        THEN --                              IF ln_old_style != g_old_om_cat_table.segment1
                                            --                              THEN
                                            BEGIN
                                                ln_list_line_id      := NULL;
                                                ln_pricing_attr_id   := NULL;
                                                create_price (g_style, rec_csr_prc_list.list_header_id, ln_list_line_id, ln_pricing_attr_id, rec_csr_prc_list.product_uom_code, ln_new_prc_om_cat_id, gn_master_orgid, rec_csr_prc_list.operand, rec_csr_prc_list.start_date_active, rec_csr_prc_list.end_date_active, 'CREATE', rec_csr_prc_list.attribute1, rec_csr_prc_list.attribute2, rec_csr_prc_list.product_precedence, gv_retcode
                                                              , gv_reterror);

                                                IF (gv_retcode IS NULL AND gv_reterror IS NULL)
                                                THEN
                                                    msg (
                                                           '     => New Price List Line with "'
                                                        || ln_new_prc_om_cat
                                                        || '" category '
                                                        || ' has been created successfully for the Price List "'
                                                        || rec_csr_prc_list.name
                                                        || '"');
                                                    msg ('');
                                                ELSE
                                                    gv_prc_list_upd_err_cnt   :=
                                                          gv_prc_list_upd_err_cnt
                                                        + 1;


                                                    msg (
                                                           '     => New Price List Line with "'
                                                        || ln_new_prc_om_cat
                                                        || '" category '
                                                        || ' has not been created for the Price List "'
                                                        || rec_csr_prc_list.name
                                                        || '". Please check log for errors');



                                                    msg (
                                                           '     => Return Code :: '
                                                        || gv_retcode);
                                                    msg ('');
                                                END IF;
                                            END;

                                            --Start Changes V5.0
                                            BEGIN
                                                ln_list_line_id      := NULL;
                                                ln_pricing_attr_id   := NULL;


                                                update_price (g_style, rec_csr_prc_list.list_header_id, rec_csr_prc_list.list_line_id, rec_csr_prc_list.pricing_attribute_id, rec_csr_prc_list.product_uom_code, ln_old_prc_om_cat_id, gn_master_orgid, rec_csr_prc_list.operand, rec_csr_prc_list.start_date_active, rec_csr_prc_list.end_date_active, 'UPDATE', rec_csr_prc_list.attribute1, rec_csr_prc_list.attribute2, rec_csr_prc_list.product_precedence, gv_retcode
                                                              , gv_reterror);

                                                IF (gv_retcode IS NULL AND gv_reterror IS NULL)
                                                THEN
                                                    msg (
                                                           '     => Price List Line with "'
                                                        || ln_old_prc_om_cat
                                                        || '" category '
                                                        || ' has been updated successfully for the Price List "'
                                                        || rec_csr_prc_list.name
                                                        || '"');
                                                    msg ('');
                                                ELSE
                                                    gv_prc_list_upd_err_cnt   :=
                                                          gv_prc_list_upd_err_cnt
                                                        + 1;
                                                    msg (
                                                           '     => Old Price List Line with "'
                                                        || ln_old_prc_om_cat
                                                        || '" category '
                                                        || ' has not been updated for the Price List "'
                                                        || rec_csr_prc_list.name
                                                        || '". Please check log for errors');
                                                    msg (
                                                           '     => Return Code :: '
                                                        || gv_retcode);
                                                    msg ('');
                                                END IF;
                                            END;
                                        --                           --End Changes V5.0

                                        END IF;
                                    END LOOP;



                                    msg (
                                           '$ End of Loop Category ID :: '
                                        || ln_loop_cat_id);
                                    msg ('');
                                END LOOP;

                                IF gv_prc_list_upd_err_cnt = 0
                                THEN
                                    msg (
                                        'Price List Update Process Success for all the Price List Lines');

                                    msg ('');
                                ELSE
                                    msg (
                                        'Price List Update Process Failed for one or more Price List Lines');

                                    msg ('');

                                    BEGIN
                                        gv_error_desc   :=
                                               gv_error_desc
                                            || 'Error during Price List Update Process. ';

                                        UPDATE xxdo.xxdo_plm_staging
                                           SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                         WHERE record_id = gn_record_id;

                                        COMMIT;
                                    END;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           ' Error in Price List Update Process :: '
                                        || SQLERRM);
                                    msg ('');
                            END;



                            msg (
                                   '*** End Price List Update at :: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS')
                                || ' ***');
                            msg ('');
                        END IF;

                        IF gv_prc_list_upd_err_cnt > 0
                        THEN
                            msg (
                                'Skipping Old OM Sales Category Disable Date update since Price List Update Process is unsuccessful for one or more items...');

                            msg ('');
                        ELSIF gv_oms_oldnew_cat_cnt > 0 -- NO_OM_SALES_CAT_CHANGE - Start
                                            -- SIZES_DIFF_HIERARCHIES -- Start
                               OR g_all_sizes_fixed = 'Y'
                        -- SIZES_DIFF_HIERARCHIES -- End



                        THEN
                            msg (
                                'Skipping Old OM Sales Category Disable Date update since OM Sales Category did not change...');

                            msg ('');
                        -- -- NO_OM_SALES_CAT_CHANGE - End
                        ELSE
                            BEGIN
                                msg (
                                       '*** Start Old OM Sales Category Disable Date update at :: '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS')
                                    || ' ***');
                                msg ('');



                                gv_retcode                  := NULL;
                                gv_reterror                 := NULL;
                                gv_old_om_cat_upd_err_cnt   := 0;

                                FOR i IN 1 .. g_old_om_cat_table.COUNT
                                LOOP
                                    ln_old_om_cat_id            :=
                                        g_old_om_cat_table (i).category_id;



                                    msg (
                                           '$ Old OM Sales Category ID :: '
                                        || ln_old_om_cat_id);
                                    msg ('');

                                    ln_oms_no_of_assign_items   := 0;


                                    BEGIN
                                        SELECT COUNT (1)
                                          INTO ln_oms_no_of_assign_items
                                          FROM mtl_item_categories
                                         WHERE     category_set_id =
                                                   1100000050
                                               AND category_id =
                                                   ln_old_om_cat_id
                                               AND organization_id = 106;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_oms_no_of_assign_items   := 0;
                                    END;


                                    BEGIN
                                        IF ln_oms_no_of_assign_items = 0
                                        THEN
                                            update_category (
                                                ln_old_om_cat_id,
                                                gv_retcode,
                                                gv_reterror);

                                            IF (gv_retcode IS NULL AND gv_reterror IS NULL)
                                            THEN
                                                msg (
                                                       '     => Old OM Sales Category ID "'
                                                    || ln_old_om_cat_id
                                                    || '" has been disabled successfully. ');



                                                msg ('');
                                            ELSE
                                                gv_old_om_cat_upd_err_cnt   :=
                                                      gv_old_om_cat_upd_err_cnt
                                                    + 1;


                                                msg (
                                                       '     => Old OM Sales Category ID "'
                                                    || ln_old_om_cat_id
                                                    || '" has not been disabled. Please check log for errors');

                                                msg (
                                                       '     => Return Code :: '
                                                    || gv_retcode);

                                                msg ('');
                                            END IF;
                                        END IF;
                                    END;
                                END LOOP;

                                IF gv_old_om_cat_upd_err_cnt = 0
                                THEN
                                    msg (
                                           'Old OM Sales Category Disable Date Update Process Success for all the old OM Sales Categories at :: '
                                        || TO_CHAR (SYSDATE,
                                                    'DD-MON-YYYY HH24:MI:SS')
                                        || ' ***');
                                    msg ('');
                                ELSE
                                    msg (
                                        'Old OM Sales Category Disable Date Update Process Failed for one or more OM Sales Categories. ');

                                    msg ('');

                                    BEGIN
                                        gv_error_desc   :=
                                               gv_error_desc
                                            || 'Error during Old OM Sales Category Disable Date Update Process. ';

                                        UPDATE xxdo.xxdo_plm_staging
                                           SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                         WHERE record_id = gn_record_id;

                                        COMMIT;
                                    END;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           ' Error in Old OM Sales Category Disable Date Update Process :: '
                                        || SQLERRM);
                                    msg ('');
                            END;



                            msg (
                                   '*** End Old OM Sales Category Disable Date update at :: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS')
                                || ' ***');
                            msg ('');
                        END IF;

                        --Start Changes V5.0
                        IF g_old_om_cat_table.EXISTS (1)
                        THEN
                            g_old_om_cat_table.DELETE;
                        END IF;
                    --END Changes V5.0
                    END IF;

                    IF gv_src_rule_upd_err_cnt > 0
                    THEN
                        msg (
                            'Skipping Old Inventory Category Disable Date update since Sourcing Rule Update Process is unsuccessful for one or more items...');

                        msg ('');
                    -- SIZES_DIFF_HIERACHIES - Start
                    ELSIF g_all_sizes_fixed = 'Y'
                    THEN
                        msg (
                            'Skipping Old Inventory Category Disable Date update since inventory item category did not change...');

                        msg ('');
                    -- SIZES_DIFF_HIERACHIES - End
                    ELSE
                        BEGIN
                            msg (
                                   '*** Start Old Inventory Category Disable Date update at :: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS')
                                || ' ***');
                            msg ('');



                            gv_retcode                   := NULL;
                            gv_reterror                  := NULL;
                            gv_old_inv_cat_upd_err_cnt   := 0;

                            FOR i IN 1 .. g_old_inv_cat_table.COUNT
                            LOOP
                                ln_old_inv_cat_id         :=
                                    g_old_inv_cat_table (i).category_id;


                                msg (
                                       '$ Old Inventory Category ID :: '
                                    || ln_old_inv_cat_id);
                                msg ('');

                                ln_no_of_assigned_items   := 0;


                                BEGIN
                                    SELECT COUNT (1)
                                      INTO ln_no_of_assigned_items
                                      FROM mtl_item_categories
                                     WHERE     category_set_id = 1
                                           AND category_id =
                                               ln_old_inv_cat_id
                                           AND organization_id = 106;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_no_of_assigned_items   := 0;
                                END;



                                IF ln_no_of_assigned_items = 0
                                THEN
                                    BEGIN
                                        update_category (ln_old_inv_cat_id,
                                                         gv_retcode,
                                                         gv_reterror);

                                        IF (gv_retcode IS NULL AND gv_reterror IS NULL)
                                        THEN
                                            msg (
                                                   '     => Old Inventory Category ID "'
                                                || ln_old_inv_cat_id
                                                || '" has been disabled successfully. ');



                                            msg ('');
                                        ELSE
                                            gv_old_inv_cat_upd_err_cnt   :=
                                                  gv_old_inv_cat_upd_err_cnt
                                                + 1;


                                            msg (
                                                   '     => Old Inventory Category ID "'
                                                || ln_old_inv_cat_id
                                                || '" has not been disabled. Please check log for errors');

                                            msg (
                                                   '     => Return Code :: '
                                                || gv_retcode);



                                            msg ('');
                                        END IF;
                                    END;
                                END IF;
                            END LOOP;

                            IF gv_old_inv_cat_upd_err_cnt = 0
                            THEN
                                msg (
                                       'Old Inventory Category Disable Date Update Process Success for all the old Inventory Categories at :: '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS')
                                    || ' ***');
                                msg ('');
                            ELSE
                                msg (
                                    'Old Inventory Category Disable Date Update Process Failed for one or more Inventory Categories. ');

                                msg ('');

                                BEGIN
                                    gv_error_desc   :=
                                           gv_error_desc
                                        || 'Error during Old Inventory Category Disable Date Update Process. ';

                                    UPDATE xxdo.xxdo_plm_staging
                                       SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                     WHERE record_id = gn_record_id;

                                    COMMIT;
                                END;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                msg (
                                       ' Error in Old Inventory Category Disable Date Update Process :: '
                                    || SQLERRM);
                                msg ('');
                        END;



                        msg (
                               '*** End Old Inventory Category Disable Date update at :: '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                            || ' ***');
                        msg ('');

                        -- DISABLE_ILR_CATEGORIES - Start
                        -- Logic to disable the inventory category for ILR Items
                        IF g_old_gen_inv_cat_table.EXISTS (1)
                        THEN
                            BEGIN
                                msg (
                                       '*** Start Old Inventory Category Disable Date update for ILR Items at :: '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS')
                                    || ' ***');
                                msg ('');



                                gv_retcode                   := NULL;
                                gv_reterror                  := NULL;
                                gv_old_inv_cat_upd_err_cnt   := 0;



                                FOR i IN 1 .. g_old_gen_inv_cat_table.COUNT
                                LOOP
                                    ln_old_inv_cat_id         :=
                                        g_old_gen_inv_cat_table (i).category_id;


                                    msg (
                                           '$ Old Inventory Category ID :: '
                                        || ln_old_inv_cat_id);



                                    msg ('');

                                    ln_no_of_assigned_items   := 0;



                                    BEGIN
                                        SELECT COUNT (1)
                                          INTO ln_no_of_assigned_items
                                          FROM mtl_item_categories
                                         WHERE     category_set_id = 1
                                               AND category_id =
                                                   ln_old_inv_cat_id
                                               AND organization_id = 106;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_no_of_assigned_items   := 0;
                                    END;



                                    IF ln_no_of_assigned_items = 0
                                    THEN
                                        BEGIN
                                            update_category (
                                                ln_old_inv_cat_id,
                                                gv_retcode,
                                                gv_reterror);



                                            IF (gv_retcode IS NULL AND gv_reterror IS NULL)
                                            THEN
                                                msg (
                                                       '     => Old Inventory Category ID "'
                                                    || ln_old_inv_cat_id
                                                    || '" has been disabled successfully. ');
                                                msg ('');
                                            ELSE
                                                gv_old_inv_cat_upd_err_cnt   :=
                                                      gv_old_inv_cat_upd_err_cnt
                                                    + 1;
                                                msg (
                                                       '     => Old Inventory Category ID "'
                                                    || ln_old_inv_cat_id
                                                    || '" has not been disabled. Please check log for errors');
                                                msg (
                                                       '     => Return Code :: '
                                                    || gv_retcode);
                                                msg ('');
                                            END IF;
                                        END;
                                    END IF;
                                END LOOP;



                                IF gv_old_inv_cat_upd_err_cnt = 0
                                THEN
                                    msg (
                                           'Old Inventory Category Disable Date Update Process Success for all the old Inventory Categories at :: '
                                        || TO_CHAR (SYSDATE,
                                                    'DD-MON-YYYY HH24:MI:SS')
                                        || ' ***');
                                    msg ('');
                                ELSE
                                    msg (
                                        'Old Inventory Category Disable Date Update Process Failed for one or more Inventory Categories. ');
                                    msg ('');



                                    BEGIN
                                        gv_error_desc   :=
                                               gv_error_desc
                                            || 'Error during Old Inventory Category Disable Date Update Process. ';



                                        UPDATE xxdo.xxdo_plm_staging
                                           SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                         WHERE record_id = gn_record_id;

                                        COMMIT;
                                    END;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           ' Error in Old Inventory Category Disable Date Update Process :: '
                                        || SQLERRM);
                                    msg ('');
                            END;

                            msg (
                                   '*** End Old Inventory Category Disable Date update for ILR Items at :: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS')
                                || ' ***');
                            msg ('');
                        END IF;
                    -- DISABLE_ILR_CATEGORIES - End


                    END IF;

                    IF gv_po_error_cnt > 0
                    THEN
                        msg (
                            'Skipping Old PO Item Category Disable Date update since PO Item Category Assignment Process is unsuccessful for one or more items...');

                        msg ('');
                    -- SIZES_DIFF_HIERACHIES - Start
                    ELSIF g_all_sizes_fixed = 'Y'
                    THEN
                        msg (
                            'Skipping Old PO Item Category Disable Date update since PO Item Category did not change...');

                        msg ('');
                    -- SIZES_DIFF_HIERACHIES - End

                    ELSE
                        IF gv_po_cat_updated = 'Y'
                        THEN
                            BEGIN
                                msg (
                                       '*** Start Old PO Item Category Disable Date update at :: '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS')
                                    || ' ***');
                                msg ('');



                                gv_retcode                  := NULL;
                                gv_reterror                 := NULL;
                                gv_old_po_cat_upd_err_cnt   := 0;


                                FOR i IN 1 .. g_old_po_cat_table.COUNT
                                LOOP
                                    ln_old_po_cat_id           :=
                                        g_old_po_cat_table (i).category_id;
                                    msg (
                                           '$ Old PO Item Category ID :: '
                                        || ln_old_po_cat_id);
                                    msg ('');

                                    ln_po_no_of_assign_items   := 0;



                                    BEGIN
                                        SELECT COUNT (1)
                                          INTO ln_po_no_of_assign_items
                                          FROM mtl_item_categories
                                         WHERE     category_set_id =
                                                   1100000051
                                               AND category_id =
                                                   ln_old_po_cat_id
                                               AND organization_id = 106;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_po_no_of_assign_items   := 0;
                                    END;



                                    IF ln_po_no_of_assign_items = 0
                                    THEN
                                        BEGIN
                                            update_category (
                                                ln_old_po_cat_id,
                                                gv_retcode,
                                                gv_reterror);



                                            IF (gv_retcode IS NULL AND gv_reterror IS NULL)
                                            THEN
                                                msg (
                                                       '     => Old PO Item Category ID "'
                                                    || ln_old_po_cat_id
                                                    || '" has been disabled successfully. ');
                                                msg ('');
                                            ELSE
                                                gv_old_po_cat_upd_err_cnt   :=
                                                      gv_old_po_cat_upd_err_cnt
                                                    + 1;
                                                msg (
                                                       '     => Old PO Item Category ID "'
                                                    || ln_old_po_cat_id
                                                    || '" has not been disabled. Please check log for errors');
                                                msg (
                                                       '     => Return Code :: '
                                                    || gv_retcode);
                                                msg ('');
                                            END IF;
                                        END;
                                    END IF;
                                END LOOP;



                                IF gv_old_po_cat_upd_err_cnt = 0
                                THEN
                                    msg (
                                           'Old PO Item Category Disable Date Update Process Success for all the old PO Item Categories at :: '
                                        || TO_CHAR (SYSDATE,
                                                    'DD-MON-YYYY HH24:MI:SS')
                                        || ' ***');
                                    msg ('');
                                ELSE
                                    msg (
                                        'Old PO Item Category Disable Date Update Process Failed for one or more PO Item Categories. ');
                                    msg ('');



                                    BEGIN
                                        gv_error_desc   :=
                                               gv_error_desc
                                            || 'Error during Old PO Item Category Disable Date Update Process. ';



                                        UPDATE xxdo.xxdo_plm_staging
                                           SET oracle_status = 'E', date_updated = SYSDATE, oracle_error_message = gv_error_desc
                                         WHERE record_id = gn_record_id;



                                        COMMIT;
                                    END;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           ' Error in Old PO Item Category Disable Date Update Process :: '
                                        || SQLERRM);
                                    msg ('');
                            END;

                            msg (
                                   '*** End Old PO Item Category Disable Date update at :: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS')
                                || ' ***');
                            msg ('');
                        END IF;
                    END IF;

                    BEGIN
                        IF gv_error_desc IS NOT NULL
                        THEN
                            msg ('Error Messages:');
                            msg ('---------------');
                            msg ('');

                            FOR rec_csr_log_table
                                IN csr_log_table (gn_record_id)
                            LOOP
                                msg ('* ' || rec_csr_log_table.error_message);
                                msg ('');
                            END LOOP;
                        END IF;
                    END;
                END IF;
            END IF;
        END IF;



        msg (
               '*** Hierarchy Update Program for Style "'
            || p_style_v
            || '" and Color "'
            || p_color_v
            || '" End at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        msg ('');
    END;

    /****************************************************************************
    * Procedure Name   : main_prc
    *
    * Description      : Main procedure to find valid staging table records
    *
    * INPUT Parameters  : pv_style_v
    *                     pv_color_v
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/

    PROCEDURE main_prc (p_reterror OUT VARCHAR2, p_retcode OUT NUMBER, pv_style_v IN VARCHAR2
                        , pv_color_v IN VARCHAR2, pv_debug_v IN VARCHAR2)
    IS
        CURSOR cur_rec IS
              SELECT *
                FROM xxdo.xxdo_plm_staging
               WHERE     oracle_status = 'N'
                     AND attribute4 = 'HIERARCHY_UPDATE'
                     AND style = NVL (pv_style_v, style)
                     AND colorway = NVL (pv_color_v, colorway)
                     AND request_id IS NULL
            ORDER BY style, record_id;

        lv_reterror    VARCHAR2 (4000);
        lv_retcode     NUMBER;
        l_temp_date1   DATE := TO_DATE ('01-JAN-1950');
        l_temp_date2   DATE := TO_CHAR (TRUNC (SYSDATE));
        l_temp_date3   DATE
            := TRUNC (TO_DATE (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
    BEGIN
        msg (
               '*** Main Program Start at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        msg ('');

        IF UPPER (pv_debug_v) = 'YES'
        THEN
            gv_log_debug_enable   := 'Y';
        ELSE
            gv_log_debug_enable   := 'N';
        END IF;

        --Start Changes V5.0 Updating the invalid records
        BEGIN
            --Update Duplicate records
            UPDATE xxdo.xxdo_plm_staging xps1
               SET oracle_status = 'E', oracle_error_message = 'Duplicate Record', date_updated = SYSDATE
             WHERE     1 = 1
                   AND oracle_status = 'N'
                   AND request_id IS NULL
                   AND attribute4 = 'HIERARCHY_UPDATE'
                   AND style = NVL (pv_style_v, style)
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_plm_staging xps2
                             WHERE     1 = 1
                                   AND xps2.oracle_status = 'N'
                                   AND xps2.request_id IS NULL
                                   AND xps2.attribute4 = 'HIERARCHY_UPDATE'
                                   AND xps2.style = NVL (pv_style_v, style)
                                   AND xps2.style = xps1.style
                                   AND xps2.colorway = xps1.colorway
                                   AND xps2.record_id > xps1.record_id);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                LOG (
                       'Error while updating the Duplicate records - '
                    || SQLERRM);
        END;

        --Update invalid style-color combination
        BEGIN
            UPDATE xxdo.xxdo_plm_staging xps1
               SET oracle_status = 'E', oracle_error_message = 'Style - ' || xps1.style || ' and color - ' || xps1.colorway || ' does not exist.', date_updated = SYSDATE
             WHERE     1 = 1
                   AND oracle_status = 'N'
                   AND request_id IS NULL
                   AND attribute4 = 'HIERARCHY_UPDATE'
                   AND style = NVL (pv_style_v, style)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_system_items_b msi
                             WHERE     1 = 1
                                   AND organization_id =
                                       (SELECT organization_id
                                          FROM org_organization_definitions
                                         WHERE organization_code =
                                               gn_master_org_code)
                                   AND (   (msi.segment1 LIKE xps1.style || '-' || xps1.colorway || '%' AND attribute28 IN ('PROD', 'GENERIC')) -- STYLE_SEARCH - Start
                                        OR (msi.segment1 LIKE 'S' || xps1.style || 'L-' || xps1.colorway || '%')
                                        OR (msi.segment1 LIKE 'S' || xps1.style || 'R-' || xps1.colorway || '%')
                                        OR (msi.segment1 LIKE 'SR' || xps1.style || '-' || xps1.colorway || '%')
                                        OR (msi.segment1 LIKE 'SL' || xps1.style || '-' || xps1.colorway || '%')
                                        OR (msi.segment1 LIKE 'SS' || xps1.style || '-' || xps1.colorway || '%')
                                        OR (    msi.segment1 LIKE
                                                       'S'
                                                    || xps1.style
                                                    || '-'
                                                    || xps1.colorway
                                                    || '%'
                                            AND attribute28 IN ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R',
                                                                'GENERIC'))
                                        OR (msi.segment1 LIKE 'BG' || xps1.style || '-' || xps1.colorway || '%')));

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                LOG (
                       'Error while updating No Style Color combination exists in EBS - '
                    || SQLERRM);
        END;

        --End Changes V5.0

        FOR rec_cur_rec IN cur_rec
        LOOP
            --Resetting The Global Varaible Values

            gn_po_item_set_id           := NULL;
            gn_po_item_structure_id     := NULL;
            gn_om_sales_set_id          := NULL;
            gn_om_sales_structure_id    := NULL;
            gn_inventory_set_id         := NULL;
            gn_inventory_structure_id   := NULL;
            gn_master_orgid             := NULL;
            gv_sku_flag                 := NULL;
            gn_record_id                := NULL;
            gv_reterror                 := NULL;
            gv_retcode                  := NULL;
            gv_error_desc               := NULL;
            gv_plm_style                := NULL;
            gv_color_code               := NULL;
            g_item_search               := NULL;
            gv_season                   := NULL;
            gn_plm_rec_id               := NULL;
            gv_colorway_state           := NULL;

            g_style                     := NULL;
            g_colorway                  := NULL;
            g_style_name                := NULL;
            g_style_name_upr            := NULL;
            gv_po_cat_updated           := 'N';


            -- GLOBAL_RESET_TABLES - Start

            --         IF g_old_om_cat_table.EXISTS (1)
            --         THEN
            --            g_old_om_cat_table.DELETE;
            --         END IF;


            IF g_old_inv_cat_table.EXISTS (1)
            THEN
                g_old_inv_cat_table.DELETE;
            END IF;


            IF g_old_po_cat_table.EXISTS (1)
            THEN
                g_old_po_cat_table.DELETE;
            END IF;



            IF g_old_gen_inv_cat_table.EXISTS (1)
            THEN
                g_old_gen_inv_cat_table.DELETE;
            END IF;

            -- GLOBAL_RESET_TABLES - End


            BEGIN
                main (lv_reterror, lv_retcode, rec_cur_rec.style,
                      rec_cur_rec.colorway, NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg ('Entered Into The Exception');
                    msg ('Exception Error :: ' || SQLERRM);


                    msg (
                           'Return Error :: '
                        || lv_reterror
                        || ' with Return Code :: '
                        || lv_retcode);
            END;
        END LOOP;



        msg (
               '*** Main Program End at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        msg ('');
    END;
END xxdoinv_plm_item_upd_pkg;
/
