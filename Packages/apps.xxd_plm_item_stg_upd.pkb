--
-- XXD_PLM_ITEM_STG_UPD  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PLM_ITEM_STG_UPD"
IS
    /**********************************************************************************************************
       file name    : XXD_PLM_ITEM_STG_UPD.pkb
       created on   : 01-JAN-2017
       created by   : INFOSYS
       purpose      : package body used for the following
                              1. clean up MTL table
                              2.update staging table status for styles where only sample items dsnt have cost
      ***********************************************************************************************************
      Modification history:
     *****************************************************************************
         NAME:        XXD_PLM_ITEM_STG_UPD
         PURPOSE:

         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  ------------------------------------
         1.0         08-JAN-2017     INFOSYS       1. Created this body Specification.
    *********************************************************************
    *********************************************************************/
    PROCEDURE update_stg_tab_active_items (pv_reterror OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_operation IN VARCHAR2, pv_style IN VARCHAR2, pv_color IN VARCHAR2, pn_cleanup_days IN NUMBER
                                           , pv_commit IN VARCHAR2)
    IS
        /**************************************************************************************
          cursor to fetch records from main staging table
         ****************************************************************************************/
        CURSOR csr_items_data IS
              SELECT stg.*, NVL (siz.size_val, 'ALL') size_num, UPPER (SUBSTR (stg.attribute1, 0, 4) -- Added UPPER case for cost type W.r.t version 1.6
                                                                                                     || SUBSTR (stg.attribute1, -2)) cst_type,
                     siz.item_type inv_item_type, siz.sequence_num size_sort_code
                FROM xxdo.xxdo_plm_staging stg, xxdo.xxdo_plm_size_stg siz
               WHERE     1 = 1
                     AND oracle_status = 'E'
                     AND colorway = NVL (pv_color, colorway)
                     AND style = NVL (pv_style, style)
                     AND NVL (stg.attribute4, 'XX') <> 'HIERARCHY_UPDATE' --w.r.t version 1.34
                     AND stg.record_id = siz.parent_record_id(+)
            ORDER BY record_id, size_num;

        CURSOR csr_style_upd IS
              SELECT DISTINCT style, colorway
                FROM xxdo.xxdo_plm_staging
               WHERE     1 = 1
                     AND oracle_status = 'E'
                     AND colorway = NVL (pv_color, colorway)
                     AND style = NVL (pv_style, style)
            ORDER BY style;

        CURSOR csr_pland_items (cv_style IN VARCHAR2)
        IS
              SELECT /*+ PARALLEL(2) */
                     msi.segment1, organization_code, msi.organization_id,
                     inventory_item_id, inventory_item_status_code, item_type
                FROM mtl_system_items_b msi, mtl_parameters mp, fnd_lookup_values_vl fn
               WHERE     segment1 LIKE '%' || cv_style || '-' || '%'
                     AND mp.organization_id = msi.organization_id
                     AND inventory_item_status_code IN ('Planned', 'Active')
                     AND lookup_type = 'XXDO_ORG_LIST_INCL_COSTING'
                     AND fn.description = mp.organization_code
                     AND NVL (fn.enabled_flag, 'Y') = 'Y'
            ORDER BY msi.segment1, msi.organization_id;


        ln_count             NUMBER;
        lv_item_number       VARCHAR2 (200);
        lv_item_type         VARCHAR2 (200);
        lv_style             VARCHAR2 (200);
        lv_mat_overhead      VARCHAR2 (150) := 'Material Overhead';
        ln_orgn_id           NUMBER;
        ln_count_item_cost   NUMBER := 0;
        lv_org_inc_org       VARCHAR2 (10) := 'N';
        ln_cost_status       VARCHAR2 (10) := 'Y';
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'pv_operation ' || pv_operation);
        fnd_file.put_line (fnd_file.LOG, 'pv_style ' || pv_style);
        fnd_file.put_line (fnd_file.LOG, 'pv_color ' || pv_color);

        IF pv_operation = 'MTL CLEANUP'
        THEN
            BEGIN
                DELETE FROM
                    INV.MTL_ITEM_CATEGORIES_INTERFACE
                      WHERE creation_date <
                            SYSDATE - NVL (pn_cleanup_days, 10);

                DELETE FROM
                    INV.MTL_ITEM_REVISIONS_INTERFACE
                      WHERE creation_date <
                            SYSDATE - NVL (pn_cleanup_days, 10);

                DELETE FROM
                    INV.MTL_INTERFACE_ERRORS
                      WHERE creation_date <
                            SYSDATE - NVL (pn_cleanup_days, 10);

                DELETE FROM
                    INV.MTL_SYSTEM_ITEMS_INTERFACE
                      WHERE creation_date <
                            SYSDATE - NVL (pn_cleanup_days, 10);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error while cleaningup Interface tables ' || SQLERRM);
            END;
        ELSIF pv_operation = 'SPECIFIC STYLE UPDATE'
        THEN
            IF pv_style IS NOT NULL AND pv_color IS NOT NULL
            THEN
                BEGIN
                    UPDATE xxdo.xxdo_plm_staging plm1
                       SET oracle_status = 'N', request_id = NULL, date_updated = SYSDATE
                     WHERE record_id =
                           (SELECT MAX (record_id)
                              FROM xxdo.xxdo_plm_staging
                             WHERE style = pv_style AND colorway = pv_color);

                    UPDATE xxdo.xxdo_plm_size_stg
                       SET request_id   = NULL
                     WHERE parent_record_id IN
                               (SELECT MAX (record_id)
                                  FROM xxdo.xxdo_plm_staging
                                 WHERE     style = pv_style
                                       AND colorway = pv_color);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while updating the PLM tables ' || SQLERRM);

                        COMMIT;
                END;
            END IF;
        ELSIF pv_operation = 'STYLE STATUS UPDATE'
        THEN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxd_item_plan_cost_stg';

            fnd_file.put_line (fnd_file.LOG, 'Cursor csr_style_upd');

            FOR rec_style_upd IN csr_style_upd
            LOOP
                fnd_file.put_line (fnd_file.LOG,
                                   '  For Item  ' || rec_style_upd.style);

                /*
                   lv_item_type :=
                      UPPER (NVL (rec_style_upd.inv_item_type, 'GENERIC'));
                   lv_item_number :=
                         TRIM (rec_style_upd.style)
                      || '-'
                      || (NVL (TRIM (rec_style_upd.colorway), 'ALL'))
                      || '-'
                      || NVL (rec_style_upd.size_num, 'ALL');

                   IF     UPPER (lv_item_type) = 'SAMPLE'
                      AND UPPER (rec_style_upd.product_group) = 'FOOTWEAR'
                   THEN
                      lv_item_number := 'SS' || lv_item_number;
                   END IF;

                         FOR rec_pland_items IN csr_pland_items (rec_style_upd.style)
                      LOOP
                         fnd_file.put_line (
                            fnd_file.LOG,
                            '  For Item  ' || rec_pland_items.segment1);
                      END LOOP;
                      */
                FOR rec_pland_items
                    IN csr_pland_items (
                           rec_style_upd.style || '-' || rec_style_upd.colorway)
                LOOP
                    fnd_file.put_line (
                        fnd_file.LOG,
                        '  For Item  ' || rec_pland_items.segment1);

                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_count_item_cost
                          FROM (SELECT resource_id
                                  FROM bom_resources brs, cst_cost_elements cce
                                 WHERE     organization_id =
                                           rec_pland_items.organization_id
                                       AND brs.cost_element_id =
                                           cce.cost_element_id
                                       AND cost_element = lv_mat_overhead
                                MINUS
                                SELECT resource_id
                                  FROM cst_item_cost_details cid, cst_cost_types cct
                                 WHERE     inventory_item_id =
                                           rec_pland_items.inventory_item_id
                                       AND cid.organization_id =
                                           rec_pland_items.organization_id
                                       AND cid.cost_type_id =
                                           cct.cost_type_id
                                       AND cost_type = 'AvgRates');
                    END;

                    IF ln_count_item_cost > 0
                    THEN
                        ln_cost_status   := 'N';

                        INSERT INTO xxd_item_plan_cost_stg (
                                        style,
                                        colorway,
                                        item_number,
                                        organization_id,
                                        organization_code,
                                        cost_flag,
                                        item_status,
                                        item_type,
                                        creation_date)
                                 VALUES (
                                            rec_style_upd.style,
                                            rec_style_upd.colorway,
                                            rec_pland_items.segment1,
                                            rec_pland_items.organization_id,
                                            rec_pland_items.organization_code,
                                            ln_cost_status,
                                            rec_pland_items.inventory_item_status_code,
                                            rec_pland_items.item_type,
                                            SYSDATE);
                    ELSE
                        ln_cost_status   := 'Y';

                        INSERT INTO xxd_item_plan_cost_stg (
                                        style,
                                        colorway,
                                        item_number,
                                        organization_id,
                                        organization_code,
                                        cost_flag,
                                        item_status,
                                        item_type,
                                        creation_date)
                                 VALUES (
                                            rec_style_upd.style,
                                            rec_style_upd.colorway,
                                            rec_pland_items.segment1,
                                            rec_pland_items.organization_id,
                                            rec_pland_items.organization_code,
                                            ln_cost_status,
                                            rec_pland_items.inventory_item_status_code,
                                            rec_pland_items.item_type,
                                            SYSDATE);
                    END IF;
                END LOOP;

                COMMIT;

                BEGIN
                    SELECT COUNT (1)
                      INTO ln_count
                      FROM mtl_system_items_b
                     WHERE     segment1 LIKE
                                      rec_style_upd.style
                                   || '-'
                                   || rec_style_upd.colorway
                                   || '-'
                                   || '%'
                           AND inventory_item_status_code = 'Planned';
                END;

                IF UPPER (pv_commit) = 'YES'
                THEN
                    IF ln_count = 0
                    THEN
                        UPDATE xxdo.xxdo_plm_staging
                           SET oracle_status = 'SK', date_updated = SYSDATE
                         WHERE     style = rec_style_upd.style
                               AND NVL (colorway, 'ALL') =
                                   NVL (rec_style_upd.colorway, 'ALL')
                               AND oracle_status = 'E';

                        COMMIT;
                    END IF;
                END IF;
            END LOOP;
        END IF;
    END update_stg_tab_active_items;
END XXD_PLM_ITEM_STG_UPD;
/
