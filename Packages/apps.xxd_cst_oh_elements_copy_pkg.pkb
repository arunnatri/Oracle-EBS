--
-- XXD_CST_OH_ELEMENTS_COPY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_CST_OH_ELEMENTS_COPY_PKG"
IS
      /******************************************************************************************
 NAME           : XXD_CST_OH_ELEMENTS_COPY_PKG
 PACKAGE NAME   : Deckers OH Elements Copy Program

 REVISIONS:
 Date        Author             Version  Description
 ----------  ----------         -------  ---------------------------------------------------
 04-JAN-2022 Damodara Gupta     1.0      Created this package using XXD_CST_OH_ELEMENTS_COPY_PKG
                                         to override the Duty/Cost Elements to ORACLE
 28-FEB-2022 Damodara Gupta     1.1      CCR0009885
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

      /******************************************************************************
-- PROCEDURE load_data_into_tbl_prc
-- PURPOSE: This Procedure extract the data and load it into the custom table.
*******************************************************************************/
    PROCEDURE oh_ele_data_into_tbl_prc (pv_from_org   IN VARCHAR2,
                                        pv_duty_vs    IN VARCHAR2) -- Added  CCR0009885
    IS
        CURSOR c_items_ccid_duty_cur IS
            SELECT xci.style_number
                       style_number,
                   xci.style_number || '-' || xci.color_code
                       style_color,
                   xci.item_size
                       item_size,
                   xci.department
                       department,
                   xci.item_number
                       item_number,
                   xci.inventory_item_id
                       inventory_item_id,
                   xci.organization_id
                       organization_id,
                   (SELECT organization_code
                      FROM apps.org_organization_definitions ood
                     WHERE ood.organization_id = pv_from_org)
                       organization_code,
                   xci.brand
                       brand,
                   cicd.creation_date
                       duty_start_date,
                   NULL
                       duty_end_date,
                   cicd.cost_type_id
                       cost_type_id,
                   cicd.resource_code
                       resource_code,
                   cicd.usage_rate_or_amount
                       duty,
                   'Y'
                       primary_duty_flag,
                   xci.inventory_item_status_code
                       inventory_item_status_code
              FROM apps.xxd_common_items_v xci, apps.cst_item_cost_details_v cicd
             WHERE     xci.organization_id = cicd.organization_id
                   AND xci.inventory_item_id = cicd.inventory_item_id
                   AND cicd.cost_type_id = 1000
                   AND cicd.resource_code = 'DUTY'
                   AND xci.inventory_item_status_code = 'Active'
                   AND xci.organization_id = pv_from_org;

        lv_country           VARCHAR2 (100);
        lv_region            VARCHAR2 (100);
        lv_duty              VARCHAR2 (1000);
        lv_oh_region         VARCHAR2 (1000);
        lv_oh_brand          VARCHAR2 (1000);
        lv_oh_duty           VARCHAR2 (1000);
        lv_oh_freight        VARCHAR2 (1000);
        lv_oh_oh_duty        VARCHAR2 (1000);
        lv_oh_nonduty        VARCHAR2 (1000);
        lv_oh_freight_duty   VARCHAR2 (1000);
        lv_oh_inv_org_id     VARCHAR2 (1000);
        lv_oh_country        VARCHAR2 (1000);
        lv_oh_addl_duty      VARCHAR2 (1000);
        lv_tariff_code       VARCHAR2 (1000);
        l_group_id           NUMBER
                                 := xxdo.xxd_cst_oh_elements_stg_t_s.NEXTVAL;
        ln_stg_insert        NUMBER;
    BEGIN
        write_log_prc (
               'oh_ele_data_into_tbl_prc Process Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        write_log_prc ('Deriving Region, Country based on Inventory Org');

        BEGIN
            SELECT ffvl.attribute1, ffvl.parent_flex_value_low
              INTO lv_country, lv_region
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
             WHERE     1 = 1
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvs.flex_value_set_name =
                       'XXD_CM_COUNTRY_INV_ORGS_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND enabled_flag = 'Y'
                   AND ffvl.attribute2 = pv_from_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Unable to derive country for the Inv Org' || pv_from_org);
                lv_country   := NULL;
        END;

        FOR i IN c_items_ccid_duty_cur
        LOOP
            write_log_prc (
                   'Style Number '
                || i.style_number
                || 'Style Color '
                || i.style_color
                || 'Item Size '
                || i.item_size
                || 'Department '
                || i.department
                || 'Item Number '
                || i.item_number
                || 'Inventory Item Id '
                || i.inventory_item_id
                || 'Organization Id '
                || i.organization_id
                || 'Organization Code '
                || i.organization_code
                || 'Brand '
                || i.brand
                || 'Duty Start Date '
                || i.duty_start_date
                || 'Duty End Date '
                || i.duty_end_date
                || 'Cost Type Id '
                || i.cost_type_id
                || 'Resource Code '
                || i.resource_code
                || 'Duty '
                || i.duty
                || 'Primary Duty Flag '
                || i.primary_duty_flag
                || 'Inventory Item Status Code '
                || i.inventory_item_status_code);

            BEGIN
                lv_oh_region         := NULL;
                lv_oh_brand          := NULL;
                lv_oh_duty           := NULL;
                lv_oh_freight        := NULL;
                lv_oh_oh_duty        := NULL;
                lv_oh_nonduty        := NULL;
                lv_oh_freight_duty   := NULL;
                lv_oh_inv_org_id     := NULL;
                lv_oh_country        := NULL;
                lv_oh_addl_duty      := NULL;

                SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                       oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                       oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                       oh_val.attribute10 addl_duty
                  INTO lv_oh_region, lv_oh_brand, lv_oh_duty, lv_oh_freight,
                                   lv_oh_oh_duty, lv_oh_nonduty, lv_oh_freight_duty,
                                   lv_oh_inv_org_id, lv_oh_country, lv_oh_addl_duty
                  FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                 WHERE     1 = 1
                       AND oh_set.flex_value_set_id =
                           oh_val.flex_value_set_id
                       AND oh_set.flex_value_set_name =
                           'XXD_CST_OH_ELEMENTS_VS'
                       AND NVL (TRUNC (oh_val.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (oh_val.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND oh_val.enabled_flag = 'Y'
                       AND oh_val.attribute1 = lv_region
                       AND oh_val.attribute2 = i.brand
                       AND oh_val.attribute8 = i.organization_id
                       AND oh_val.attribute9 = lv_country
                       AND UPPER (oh_val.attribute11) = UPPER (i.department)
                       AND oh_val.attribute12 = i.style_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    --write_log_prc ('No OHE For Country, Org, Department, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                    lv_oh_region         := NULL;
                    lv_oh_brand          := NULL;
                    lv_oh_duty           := NULL;
                    lv_oh_freight        := NULL;
                    lv_oh_oh_duty        := NULL;
                    lv_oh_nonduty        := NULL;
                    lv_oh_freight_duty   := NULL;
                    lv_oh_inv_org_id     := NULL;
                    lv_oh_country        := NULL;
                    lv_oh_addl_duty      := NULL;

                    BEGIN
                        SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                               oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                               oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                               oh_val.attribute10 addl_duty
                          INTO lv_oh_region, lv_oh_brand, lv_oh_duty, lv_oh_freight,
                                           lv_oh_oh_duty, lv_oh_nonduty, lv_oh_freight_duty,
                                           lv_oh_inv_org_id, lv_oh_country, lv_oh_addl_duty
                          FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                         WHERE     1 = 1
                               AND oh_set.flex_value_set_id =
                                   oh_val.flex_value_set_id
                               AND oh_set.flex_value_set_name =
                                   'XXD_CST_OH_ELEMENTS_VS'
                               AND NVL (TRUNC (oh_val.start_date_active),
                                        TRUNC (SYSDATE)) <=
                                   TRUNC (SYSDATE)
                               AND NVL (TRUNC (oh_val.end_date_active),
                                        TRUNC (SYSDATE)) >=
                                   TRUNC (SYSDATE)
                               AND oh_val.enabled_flag = 'Y'
                               AND oh_val.attribute1 = lv_region
                               AND oh_val.attribute2 = i.brand
                               AND oh_val.attribute8 = i.organization_id
                               AND oh_val.attribute9 IS NULL
                               AND UPPER (oh_val.attribute11) =
                                   UPPER (i.department)
                               AND oh_val.attribute12 = i.style_number;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            --write_log_prc ('No OHE For Country Null, Org, Department, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                            lv_oh_region         := NULL;
                            lv_oh_brand          := NULL;
                            lv_oh_duty           := NULL;
                            lv_oh_freight        := NULL;
                            lv_oh_oh_duty        := NULL;
                            lv_oh_nonduty        := NULL;
                            lv_oh_freight_duty   := NULL;
                            lv_oh_inv_org_id     := NULL;
                            lv_oh_country        := NULL;
                            lv_oh_addl_duty      := NULL;

                            BEGIN
                                SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                       oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                       oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                       oh_val.attribute10 addl_duty
                                  INTO lv_oh_region, lv_oh_brand, lv_oh_duty, lv_oh_freight,
                                                   lv_oh_oh_duty, lv_oh_nonduty, lv_oh_freight_duty,
                                                   lv_oh_inv_org_id, lv_oh_country, lv_oh_addl_duty
                                  FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                 WHERE     1 = 1
                                       AND oh_set.flex_value_set_id =
                                           oh_val.flex_value_set_id
                                       AND oh_set.flex_value_set_name =
                                           'XXD_CST_OH_ELEMENTS_VS'
                                       AND NVL (
                                               TRUNC (
                                                   oh_val.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (
                                               TRUNC (oh_val.end_date_active),
                                               TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND oh_val.enabled_flag = 'Y'
                                       AND oh_val.attribute1 = lv_region
                                       AND oh_val.attribute2 = i.brand
                                       AND oh_val.attribute8 IS NULL
                                       AND oh_val.attribute9 = lv_country
                                       AND UPPER (oh_val.attribute11) =
                                           UPPER (i.department)
                                       AND oh_val.attribute12 =
                                           i.style_number;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    --write_log_prc ('No OHE For Country, Department, Style Not Null, Org Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                    lv_oh_region         := NULL;
                                    lv_oh_brand          := NULL;
                                    lv_oh_duty           := NULL;
                                    lv_oh_freight        := NULL;
                                    lv_oh_oh_duty        := NULL;
                                    lv_oh_nonduty        := NULL;
                                    lv_oh_freight_duty   := NULL;
                                    lv_oh_inv_org_id     := NULL;
                                    lv_oh_country        := NULL;
                                    lv_oh_addl_duty      := NULL;

                                    BEGIN
                                        SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                               oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                               oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                               oh_val.attribute10 addl_duty
                                          INTO lv_oh_region, lv_oh_brand, lv_oh_duty, lv_oh_freight,
                                                           lv_oh_oh_duty, lv_oh_nonduty, lv_oh_freight_duty,
                                                           lv_oh_inv_org_id, lv_oh_country, lv_oh_addl_duty
                                          FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                         WHERE     1 = 1
                                               AND oh_set.flex_value_set_id =
                                                   oh_val.flex_value_set_id
                                               AND oh_set.flex_value_set_name =
                                                   'XXD_CST_OH_ELEMENTS_VS'
                                               AND NVL (
                                                       TRUNC (
                                                           oh_val.start_date_active),
                                                       TRUNC (SYSDATE)) <=
                                                   TRUNC (SYSDATE)
                                               AND NVL (
                                                       TRUNC (
                                                           oh_val.end_date_active),
                                                       TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND oh_val.enabled_flag = 'Y'
                                               AND oh_val.attribute1 =
                                                   lv_region
                                               AND oh_val.attribute2 =
                                                   i.brand
                                               AND oh_val.attribute8 IS NULL
                                               AND oh_val.attribute9 IS NULL
                                               AND UPPER (oh_val.attribute11) =
                                                   UPPER (i.department)
                                               AND oh_val.attribute12 =
                                                   i.style_number;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            --write_log_prc ('No OHE For Country, Org Null, Department, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                            lv_oh_region         := NULL;
                                            lv_oh_brand          := NULL;
                                            lv_oh_duty           := NULL;
                                            lv_oh_freight        := NULL;
                                            lv_oh_oh_duty        := NULL;
                                            lv_oh_nonduty        := NULL;
                                            lv_oh_freight_duty   := NULL;
                                            lv_oh_inv_org_id     := NULL;
                                            lv_oh_country        := NULL;
                                            lv_oh_addl_duty      := NULL;

                                            BEGIN
                                                SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                       oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                       oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                       oh_val.attribute10 addl_duty
                                                  INTO lv_oh_region, lv_oh_brand, lv_oh_duty, lv_oh_freight,
                                                                   lv_oh_oh_duty, lv_oh_nonduty, lv_oh_freight_duty,
                                                                   lv_oh_inv_org_id, lv_oh_country, lv_oh_addl_duty
                                                  FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                 WHERE     1 = 1
                                                       AND oh_set.flex_value_set_id =
                                                           oh_val.flex_value_set_id
                                                       AND oh_set.flex_value_set_name =
                                                           'XXD_CST_OH_ELEMENTS_VS'
                                                       AND NVL (
                                                               TRUNC (
                                                                   oh_val.start_date_active),
                                                               TRUNC (
                                                                   SYSDATE)) <=
                                                           TRUNC (SYSDATE)
                                                       AND NVL (
                                                               TRUNC (
                                                                   oh_val.end_date_active),
                                                               TRUNC (
                                                                   SYSDATE)) >=
                                                           TRUNC (SYSDATE)
                                                       AND oh_val.enabled_flag =
                                                           'Y'
                                                       AND oh_val.attribute1 =
                                                           lv_region
                                                       AND oh_val.attribute2 =
                                                           i.brand
                                                       AND oh_val.attribute8 =
                                                           i.organization_id
                                                       AND oh_val.attribute9 =
                                                           lv_country
                                                       AND oh_val.attribute11
                                                               IS NULL
                                                       AND oh_val.attribute12 =
                                                           i.style_number;
                                            EXCEPTION
                                                WHEN NO_DATA_FOUND
                                                THEN
                                                    --write_log_prc ('No OHE For Country, Org, Style Is Not Null, Department Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                    lv_oh_region    := NULL;
                                                    lv_oh_brand     := NULL;
                                                    lv_oh_duty      := NULL;
                                                    lv_oh_freight   := NULL;
                                                    lv_oh_oh_duty   := NULL;
                                                    lv_oh_nonduty   := NULL;
                                                    lv_oh_freight_duty   :=
                                                        NULL;
                                                    lv_oh_inv_org_id   :=
                                                        NULL;
                                                    lv_oh_country   :=
                                                        NULL;
                                                    lv_oh_addl_duty   :=
                                                        NULL;

                                                    BEGIN
                                                        SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                               oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                               oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                               oh_val.attribute10 addl_duty
                                                          INTO lv_oh_region, lv_oh_brand, lv_oh_duty, lv_oh_freight,
                                                                           lv_oh_oh_duty, lv_oh_nonduty, lv_oh_freight_duty,
                                                                           lv_oh_inv_org_id, lv_oh_country, lv_oh_addl_duty
                                                          FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                         WHERE     1 = 1
                                                               AND oh_set.flex_value_set_id =
                                                                   oh_val.flex_value_set_id
                                                               AND oh_set.flex_value_set_name =
                                                                   'XXD_CST_OH_ELEMENTS_VS'
                                                               AND NVL (
                                                                       TRUNC (
                                                                           oh_val.start_date_active),
                                                                       TRUNC (
                                                                           SYSDATE)) <=
                                                                   TRUNC (
                                                                       SYSDATE)
                                                               AND NVL (
                                                                       TRUNC (
                                                                           oh_val.end_date_active),
                                                                       TRUNC (
                                                                           SYSDATE)) >=
                                                                   TRUNC (
                                                                       SYSDATE)
                                                               AND oh_val.enabled_flag =
                                                                   'Y'
                                                               AND oh_val.attribute1 =
                                                                   lv_region
                                                               AND oh_val.attribute2 =
                                                                   i.brand
                                                               AND oh_val.attribute8 =
                                                                   i.organization_id
                                                               AND oh_val.attribute9
                                                                       IS NULL
                                                               AND oh_val.attribute11
                                                                       IS NULL
                                                               AND oh_val.attribute12 =
                                                                   i.style_number;
                                                    EXCEPTION
                                                        WHEN NO_DATA_FOUND
                                                        THEN
                                                            --write_log_prc ('No OHE For Country, Department Null, Org, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                            lv_oh_region   :=
                                                                NULL;
                                                            lv_oh_brand   :=
                                                                NULL;
                                                            lv_oh_duty   :=
                                                                NULL;
                                                            lv_oh_freight   :=
                                                                NULL;
                                                            lv_oh_oh_duty   :=
                                                                NULL;
                                                            lv_oh_nonduty   :=
                                                                NULL;
                                                            lv_oh_freight_duty   :=
                                                                NULL;
                                                            lv_oh_inv_org_id   :=
                                                                NULL;
                                                            lv_oh_country   :=
                                                                NULL;
                                                            lv_oh_addl_duty   :=
                                                                NULL;

                                                            BEGIN
                                                                SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                       oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                       oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                       oh_val.attribute10 addl_duty
                                                                  INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                       lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                       lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                       lv_oh_addl_duty
                                                                  FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                 WHERE     1 =
                                                                           1
                                                                       AND oh_set.flex_value_set_id =
                                                                           oh_val.flex_value_set_id
                                                                       AND oh_set.flex_value_set_name =
                                                                           'XXD_CST_OH_ELEMENTS_VS'
                                                                       AND NVL (
                                                                               TRUNC (
                                                                                   oh_val.start_date_active),
                                                                               TRUNC (
                                                                                   SYSDATE)) <=
                                                                           TRUNC (
                                                                               SYSDATE)
                                                                       AND NVL (
                                                                               TRUNC (
                                                                                   oh_val.end_date_active),
                                                                               TRUNC (
                                                                                   SYSDATE)) >=
                                                                           TRUNC (
                                                                               SYSDATE)
                                                                       AND oh_val.enabled_flag =
                                                                           'Y'
                                                                       AND oh_val.attribute1 =
                                                                           lv_region
                                                                       AND oh_val.attribute2 =
                                                                           i.brand
                                                                       AND oh_val.attribute8
                                                                               IS NULL
                                                                       AND oh_val.attribute9 =
                                                                           lv_country
                                                                       AND oh_val.attribute11
                                                                               IS NULL
                                                                       AND oh_val.attribute12 =
                                                                           i.style_number;
                                                            EXCEPTION
                                                                WHEN NO_DATA_FOUND
                                                                THEN
                                                                    --write_log_prc ('No OHE For Country, Style Not Null, Org, Department Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                    lv_oh_region   :=
                                                                        NULL;
                                                                    lv_oh_brand   :=
                                                                        NULL;
                                                                    lv_oh_duty   :=
                                                                        NULL;
                                                                    lv_oh_freight   :=
                                                                        NULL;
                                                                    lv_oh_oh_duty   :=
                                                                        NULL;
                                                                    lv_oh_nonduty   :=
                                                                        NULL;
                                                                    lv_oh_freight_duty   :=
                                                                        NULL;
                                                                    lv_oh_inv_org_id   :=
                                                                        NULL;
                                                                    lv_oh_country   :=
                                                                        NULL;
                                                                    lv_oh_addl_duty   :=
                                                                        NULL;

                                                                    BEGIN
                                                                        SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                               oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                               oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                               oh_val.attribute10 addl_duty
                                                                          INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                               lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                               lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                               lv_oh_addl_duty
                                                                          FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                         WHERE     1 =
                                                                                   1
                                                                               AND oh_set.flex_value_set_id =
                                                                                   oh_val.flex_value_set_id
                                                                               AND oh_set.flex_value_set_name =
                                                                                   'XXD_CST_OH_ELEMENTS_VS'
                                                                               AND NVL (
                                                                                       TRUNC (
                                                                                           oh_val.start_date_active),
                                                                                       TRUNC (
                                                                                           SYSDATE)) <=
                                                                                   TRUNC (
                                                                                       SYSDATE)
                                                                               AND NVL (
                                                                                       TRUNC (
                                                                                           oh_val.end_date_active),
                                                                                       TRUNC (
                                                                                           SYSDATE)) >=
                                                                                   TRUNC (
                                                                                       SYSDATE)
                                                                               AND oh_val.enabled_flag =
                                                                                   'Y'
                                                                               AND oh_val.attribute1 =
                                                                                   lv_region
                                                                               AND oh_val.attribute2 =
                                                                                   i.brand
                                                                               AND oh_val.attribute8
                                                                                       IS NULL
                                                                               AND oh_val.attribute9
                                                                                       IS NULL
                                                                               AND oh_val.attribute11
                                                                                       IS NULL
                                                                               AND oh_val.attribute12 =
                                                                                   i.style_number;
                                                                    EXCEPTION
                                                                        WHEN NO_DATA_FOUND
                                                                        THEN
                                                                            --write_log_prc ('No OHE For Country, Org, Department Null, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                            lv_oh_region   :=
                                                                                NULL;
                                                                            lv_oh_brand   :=
                                                                                NULL;
                                                                            lv_oh_duty   :=
                                                                                NULL;
                                                                            lv_oh_freight   :=
                                                                                NULL;
                                                                            lv_oh_oh_duty   :=
                                                                                NULL;
                                                                            lv_oh_nonduty   :=
                                                                                NULL;
                                                                            lv_oh_freight_duty   :=
                                                                                NULL;
                                                                            lv_oh_inv_org_id   :=
                                                                                NULL;
                                                                            lv_oh_country   :=
                                                                                NULL;
                                                                            lv_oh_addl_duty   :=
                                                                                NULL;

                                                                            BEGIN
                                                                                SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                                       oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                                       oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                                       oh_val.attribute10 addl_duty
                                                                                  INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                                       lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                                       lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                                       lv_oh_addl_duty
                                                                                  FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                                 WHERE     1 =
                                                                                           1
                                                                                       AND oh_set.flex_value_set_id =
                                                                                           oh_val.flex_value_set_id
                                                                                       AND oh_set.flex_value_set_name =
                                                                                           'XXD_CST_OH_ELEMENTS_VS'
                                                                                       AND NVL (
                                                                                               TRUNC (
                                                                                                   oh_val.start_date_active),
                                                                                               TRUNC (
                                                                                                   SYSDATE)) <=
                                                                                           TRUNC (
                                                                                               SYSDATE)
                                                                                       AND NVL (
                                                                                               TRUNC (
                                                                                                   oh_val.end_date_active),
                                                                                               TRUNC (
                                                                                                   SYSDATE)) >=
                                                                                           TRUNC (
                                                                                               SYSDATE)
                                                                                       AND oh_val.enabled_flag =
                                                                                           'Y'
                                                                                       AND oh_val.attribute1 =
                                                                                           lv_region
                                                                                       AND oh_val.attribute2 =
                                                                                           i.brand
                                                                                       AND oh_val.attribute8 =
                                                                                           i.organization_id
                                                                                       AND oh_val.attribute9 =
                                                                                           lv_country
                                                                                       AND UPPER (
                                                                                               oh_val.attribute11) =
                                                                                           UPPER (
                                                                                               i.department)
                                                                                       AND oh_val.attribute12
                                                                                               IS NULL;
                                                                            EXCEPTION
                                                                                WHEN NO_DATA_FOUND
                                                                                THEN
                                                                                    --write_log_prc ('No OHE For Country, Org, Department Not Null, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                    lv_oh_region   :=
                                                                                        NULL;
                                                                                    lv_oh_brand   :=
                                                                                        NULL;
                                                                                    lv_oh_duty   :=
                                                                                        NULL;
                                                                                    lv_oh_freight   :=
                                                                                        NULL;
                                                                                    lv_oh_oh_duty   :=
                                                                                        NULL;
                                                                                    lv_oh_nonduty   :=
                                                                                        NULL;
                                                                                    lv_oh_freight_duty   :=
                                                                                        NULL;
                                                                                    lv_oh_inv_org_id   :=
                                                                                        NULL;
                                                                                    lv_oh_country   :=
                                                                                        NULL;
                                                                                    lv_oh_addl_duty   :=
                                                                                        NULL;

                                                                                    BEGIN
                                                                                        SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                                               oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                                               oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                                               oh_val.attribute10 addl_duty
                                                                                          INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                                               lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                                               lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                                               lv_oh_addl_duty
                                                                                          FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                                         WHERE     1 =
                                                                                                   1
                                                                                               AND oh_set.flex_value_set_id =
                                                                                                   oh_val.flex_value_set_id
                                                                                               AND oh_set.flex_value_set_name =
                                                                                                   'XXD_CST_OH_ELEMENTS_VS'
                                                                                               AND NVL (
                                                                                                       TRUNC (
                                                                                                           oh_val.start_date_active),
                                                                                                       TRUNC (
                                                                                                           SYSDATE)) <=
                                                                                                   TRUNC (
                                                                                                       SYSDATE)
                                                                                               AND NVL (
                                                                                                       TRUNC (
                                                                                                           oh_val.end_date_active),
                                                                                                       TRUNC (
                                                                                                           SYSDATE)) >=
                                                                                                   TRUNC (
                                                                                                       SYSDATE)
                                                                                               AND oh_val.enabled_flag =
                                                                                                   'Y'
                                                                                               AND oh_val.attribute1 =
                                                                                                   lv_region
                                                                                               AND oh_val.attribute2 =
                                                                                                   i.brand
                                                                                               AND oh_val.attribute8 =
                                                                                                   i.organization_id
                                                                                               AND oh_val.attribute9
                                                                                                       IS NULL
                                                                                               AND UPPER (
                                                                                                       oh_val.attribute11) =
                                                                                                   UPPER (
                                                                                                       i.department)
                                                                                               AND oh_val.attribute12
                                                                                                       IS NULL;
                                                                                    EXCEPTION
                                                                                        WHEN NO_DATA_FOUND
                                                                                        THEN
                                                                                            --write_log_prc ('No OHE For Country, Style Null, Org, Department Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                            lv_oh_region   :=
                                                                                                NULL;
                                                                                            lv_oh_brand   :=
                                                                                                NULL;
                                                                                            lv_oh_duty   :=
                                                                                                NULL;
                                                                                            lv_oh_freight   :=
                                                                                                NULL;
                                                                                            lv_oh_oh_duty   :=
                                                                                                NULL;
                                                                                            lv_oh_nonduty   :=
                                                                                                NULL;
                                                                                            lv_oh_freight_duty   :=
                                                                                                NULL;
                                                                                            lv_oh_inv_org_id   :=
                                                                                                NULL;
                                                                                            lv_oh_country   :=
                                                                                                NULL;
                                                                                            lv_oh_addl_duty   :=
                                                                                                NULL;

                                                                                            BEGIN
                                                                                                SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                                                       oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                                                       oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                                                       oh_val.attribute10 addl_duty
                                                                                                  INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                                                       lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                                                       lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                                                       lv_oh_addl_duty
                                                                                                  FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                                                 WHERE     1 =
                                                                                                           1
                                                                                                       AND oh_set.flex_value_set_id =
                                                                                                           oh_val.flex_value_set_id
                                                                                                       AND oh_set.flex_value_set_name =
                                                                                                           'XXD_CST_OH_ELEMENTS_VS'
                                                                                                       AND NVL (
                                                                                                               TRUNC (
                                                                                                                   oh_val.start_date_active),
                                                                                                               TRUNC (
                                                                                                                   SYSDATE)) <=
                                                                                                           TRUNC (
                                                                                                               SYSDATE)
                                                                                                       AND NVL (
                                                                                                               TRUNC (
                                                                                                                   oh_val.end_date_active),
                                                                                                               TRUNC (
                                                                                                                   SYSDATE)) >=
                                                                                                           TRUNC (
                                                                                                               SYSDATE)
                                                                                                       AND oh_val.enabled_flag =
                                                                                                           'Y'
                                                                                                       AND oh_val.attribute1 =
                                                                                                           lv_region
                                                                                                       AND oh_val.attribute2 =
                                                                                                           i.brand
                                                                                                       AND oh_val.attribute8
                                                                                                               IS NULL
                                                                                                       AND oh_val.attribute9 =
                                                                                                           lv_country
                                                                                                       AND UPPER (
                                                                                                               oh_val.attribute11) =
                                                                                                           UPPER (
                                                                                                               i.department)
                                                                                                       AND oh_val.attribute12
                                                                                                               IS NULL;
                                                                                            EXCEPTION
                                                                                                WHEN NO_DATA_FOUND
                                                                                                THEN
                                                                                                    --write_log_prc ('No OHE For Country, Department Not Null, Org, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                                    lv_oh_region   :=
                                                                                                        NULL;
                                                                                                    lv_oh_brand   :=
                                                                                                        NULL;
                                                                                                    lv_oh_duty   :=
                                                                                                        NULL;
                                                                                                    lv_oh_freight   :=
                                                                                                        NULL;
                                                                                                    lv_oh_oh_duty   :=
                                                                                                        NULL;
                                                                                                    lv_oh_nonduty   :=
                                                                                                        NULL;
                                                                                                    lv_oh_freight_duty   :=
                                                                                                        NULL;
                                                                                                    lv_oh_inv_org_id   :=
                                                                                                        NULL;
                                                                                                    lv_oh_country   :=
                                                                                                        NULL;
                                                                                                    lv_oh_addl_duty   :=
                                                                                                        NULL;

                                                                                                    BEGIN
                                                                                                        SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                                                               oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                                                               oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                                                               oh_val.attribute10 addl_duty
                                                                                                          INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                                                               lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                                                               lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                                                               lv_oh_addl_duty
                                                                                                          FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                                                         WHERE     1 =
                                                                                                                   1
                                                                                                               AND oh_set.flex_value_set_id =
                                                                                                                   oh_val.flex_value_set_id
                                                                                                               AND oh_set.flex_value_set_name =
                                                                                                                   'XXD_CST_OH_ELEMENTS_VS'
                                                                                                               AND NVL (
                                                                                                                       TRUNC (
                                                                                                                           oh_val.start_date_active),
                                                                                                                       TRUNC (
                                                                                                                           SYSDATE)) <=
                                                                                                                   TRUNC (
                                                                                                                       SYSDATE)
                                                                                                               AND NVL (
                                                                                                                       TRUNC (
                                                                                                                           oh_val.end_date_active),
                                                                                                                       TRUNC (
                                                                                                                           SYSDATE)) >=
                                                                                                                   TRUNC (
                                                                                                                       SYSDATE)
                                                                                                               AND oh_val.enabled_flag =
                                                                                                                   'Y'
                                                                                                               AND oh_val.attribute1 =
                                                                                                                   lv_region
                                                                                                               AND oh_val.attribute2 =
                                                                                                                   i.brand
                                                                                                               AND oh_val.attribute8
                                                                                                                       IS NULL
                                                                                                               AND oh_val.attribute9
                                                                                                                       IS NULL
                                                                                                               AND UPPER (
                                                                                                                       oh_val.attribute11) =
                                                                                                                   UPPER (
                                                                                                                       i.department)
                                                                                                               AND oh_val.attribute12
                                                                                                                       IS NULL;
                                                                                                    EXCEPTION
                                                                                                        WHEN NO_DATA_FOUND
                                                                                                        THEN
                                                                                                            --write_log_prc ('No OHE For Country, Org, Style Null, Department Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                                            lv_oh_region   :=
                                                                                                                NULL;
                                                                                                            lv_oh_brand   :=
                                                                                                                NULL;
                                                                                                            lv_oh_duty   :=
                                                                                                                NULL;
                                                                                                            lv_oh_freight   :=
                                                                                                                NULL;
                                                                                                            lv_oh_oh_duty   :=
                                                                                                                NULL;
                                                                                                            lv_oh_nonduty   :=
                                                                                                                NULL;
                                                                                                            lv_oh_freight_duty   :=
                                                                                                                NULL;
                                                                                                            lv_oh_inv_org_id   :=
                                                                                                                NULL;
                                                                                                            lv_oh_country   :=
                                                                                                                NULL;
                                                                                                            lv_oh_addl_duty   :=
                                                                                                                NULL;

                                                                                                            BEGIN
                                                                                                                SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                                                                       oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                                                                       oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                                                                       oh_val.attribute10 addl_duty
                                                                                                                  INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                                                                       lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                                                                       lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                                                                       lv_oh_addl_duty
                                                                                                                  FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                                                                 WHERE     1 =
                                                                                                                           1
                                                                                                                       AND oh_set.flex_value_set_id =
                                                                                                                           oh_val.flex_value_set_id
                                                                                                                       AND oh_set.flex_value_set_name =
                                                                                                                           'XXD_CST_OH_ELEMENTS_VS'
                                                                                                                       AND NVL (
                                                                                                                               TRUNC (
                                                                                                                                   oh_val.start_date_active),
                                                                                                                               TRUNC (
                                                                                                                                   SYSDATE)) <=
                                                                                                                           TRUNC (
                                                                                                                               SYSDATE)
                                                                                                                       AND NVL (
                                                                                                                               TRUNC (
                                                                                                                                   oh_val.end_date_active),
                                                                                                                               TRUNC (
                                                                                                                                   SYSDATE)) >=
                                                                                                                           TRUNC (
                                                                                                                               SYSDATE)
                                                                                                                       AND oh_val.enabled_flag =
                                                                                                                           'Y'
                                                                                                                       AND oh_val.attribute1 =
                                                                                                                           lv_region
                                                                                                                       AND oh_val.attribute2 =
                                                                                                                           i.brand
                                                                                                                       AND oh_val.attribute8 =
                                                                                                                           i.organization_id
                                                                                                                       AND oh_val.attribute9 =
                                                                                                                           lv_country
                                                                                                                       AND oh_val.attribute11
                                                                                                                               IS NULL
                                                                                                                       AND oh_val.attribute12
                                                                                                                               IS NULL;
                                                                                                            EXCEPTION
                                                                                                                WHEN NO_DATA_FOUND
                                                                                                                THEN
                                                                                                                    --write_log_prc ('No OHE For Country, Org Not Null, Department, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                                                    lv_oh_region   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_brand   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_duty   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_freight   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_oh_duty   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_nonduty   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_freight_duty   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_inv_org_id   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_country   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_addl_duty   :=
                                                                                                                        NULL;

                                                                                                                    BEGIN
                                                                                                                        SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                                                                               oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                                                                               oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                                                                               oh_val.attribute10 addl_duty
                                                                                                                          INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                                                                               lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                                                                               lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                                                                               lv_oh_addl_duty
                                                                                                                          FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                                                                         WHERE     1 =
                                                                                                                                   1
                                                                                                                               AND oh_set.flex_value_set_id =
                                                                                                                                   oh_val.flex_value_set_id
                                                                                                                               AND oh_set.flex_value_set_name =
                                                                                                                                   'XXD_CST_OH_ELEMENTS_VS'
                                                                                                                               AND NVL (
                                                                                                                                       TRUNC (
                                                                                                                                           oh_val.start_date_active),
                                                                                                                                       TRUNC (
                                                                                                                                           SYSDATE)) <=
                                                                                                                                   TRUNC (
                                                                                                                                       SYSDATE)
                                                                                                                               AND NVL (
                                                                                                                                       TRUNC (
                                                                                                                                           oh_val.end_date_active),
                                                                                                                                       TRUNC (
                                                                                                                                           SYSDATE)) >=
                                                                                                                                   TRUNC (
                                                                                                                                       SYSDATE)
                                                                                                                               AND oh_val.enabled_flag =
                                                                                                                                   'Y'
                                                                                                                               AND oh_val.attribute1 =
                                                                                                                                   lv_region
                                                                                                                               AND oh_val.attribute2 =
                                                                                                                                   i.brand
                                                                                                                               AND oh_val.attribute8 =
                                                                                                                                   i.organization_id
                                                                                                                               AND oh_val.attribute9
                                                                                                                                       IS NULL
                                                                                                                               AND oh_val.attribute11
                                                                                                                                       IS NULL
                                                                                                                               AND oh_val.attribute12
                                                                                                                                       IS NULL;
                                                                                                                    EXCEPTION
                                                                                                                        WHEN NO_DATA_FOUND
                                                                                                                        THEN
                                                                                                                            --write_log_prc ('No OHE For Country, Department, Style Is Null Org Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                                                            lv_oh_region   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_brand   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_duty   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_freight   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_oh_duty   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_nonduty   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_freight_duty   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_inv_org_id   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_country   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_addl_duty   :=
                                                                                                                                NULL;

                                                                                                                            BEGIN
                                                                                                                                SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                                                                                       oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                                                                                       oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                                                                                       oh_val.attribute10 addl_duty
                                                                                                                                  INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                                                                                       lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                                                                                       lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                                                                                       lv_oh_addl_duty
                                                                                                                                  FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                                                                                 WHERE     1 =
                                                                                                                                           1
                                                                                                                                       AND oh_set.flex_value_set_id =
                                                                                                                                           oh_val.flex_value_set_id
                                                                                                                                       AND oh_set.flex_value_set_name =
                                                                                                                                           'XXD_CST_OH_ELEMENTS_VS'
                                                                                                                                       AND NVL (
                                                                                                                                               TRUNC (
                                                                                                                                                   oh_val.start_date_active),
                                                                                                                                               TRUNC (
                                                                                                                                                   SYSDATE)) <=
                                                                                                                                           TRUNC (
                                                                                                                                               SYSDATE)
                                                                                                                                       AND NVL (
                                                                                                                                               TRUNC (
                                                                                                                                                   oh_val.end_date_active),
                                                                                                                                               TRUNC (
                                                                                                                                                   SYSDATE)) >=
                                                                                                                                           TRUNC (
                                                                                                                                               SYSDATE)
                                                                                                                                       AND oh_val.enabled_flag =
                                                                                                                                           'Y'
                                                                                                                                       AND oh_val.attribute1 =
                                                                                                                                           lv_region
                                                                                                                                       AND oh_val.attribute2 =
                                                                                                                                           i.brand
                                                                                                                                       AND oh_val.attribute8
                                                                                                                                               IS NULL
                                                                                                                                       AND oh_val.attribute9 =
                                                                                                                                           lv_country
                                                                                                                                       AND oh_val.attribute11
                                                                                                                                               IS NULL
                                                                                                                                       AND oh_val.attribute12
                                                                                                                                               IS NULL;
                                                                                                                            EXCEPTION
                                                                                                                                WHEN NO_DATA_FOUND
                                                                                                                                THEN
                                                                                                                                    --write_log_prc ('No OHE For Country Not Null, Org, Department, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                                                                    lv_oh_region   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_brand   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_duty   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_freight   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_oh_duty   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_nonduty   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_freight_duty   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_inv_org_id   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_country   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_addl_duty   :=
                                                                                                                                        NULL;

                                                                                                                                    BEGIN
                                                                                                                                        SELECT oh_val.attribute1 region, oh_val.attribute2 brand, oh_val.attribute3 duty,
                                                                                                                                               oh_val.attribute4 freight, oh_val.attribute5 oh_duty, oh_val.attribute6 oh_nonduty,
                                                                                                                                               oh_val.attribute7 freight_duty, oh_val.attribute8 inv_org_id, oh_val.attribute9 country,
                                                                                                                                               oh_val.attribute10 addl_duty
                                                                                                                                          INTO lv_oh_region, lv_oh_brand, lv_oh_duty,
                                                                                                                                               lv_oh_freight, lv_oh_oh_duty, lv_oh_nonduty,
                                                                                                                                               lv_oh_freight_duty, lv_oh_inv_org_id, lv_oh_country,
                                                                                                                                               lv_oh_addl_duty
                                                                                                                                          FROM apps.fnd_flex_value_sets oh_set, apps.fnd_flex_values_vl oh_val
                                                                                                                                         WHERE     1 =
                                                                                                                                                   1
                                                                                                                                               AND oh_set.flex_value_set_id =
                                                                                                                                                   oh_val.flex_value_set_id
                                                                                                                                               AND oh_set.flex_value_set_name =
                                                                                                                                                   'XXD_CST_OH_ELEMENTS_VS'
                                                                                                                                               AND NVL (
                                                                                                                                                       TRUNC (
                                                                                                                                                           oh_val.start_date_active),
                                                                                                                                                       TRUNC (
                                                                                                                                                           SYSDATE)) <=
                                                                                                                                                   TRUNC (
                                                                                                                                                       SYSDATE)
                                                                                                                                               AND NVL (
                                                                                                                                                       TRUNC (
                                                                                                                                                           oh_val.end_date_active),
                                                                                                                                                       TRUNC (
                                                                                                                                                           SYSDATE)) >=
                                                                                                                                                   TRUNC (
                                                                                                                                                       SYSDATE)
                                                                                                                                               AND oh_val.enabled_flag =
                                                                                                                                                   'Y'
                                                                                                                                               AND oh_val.attribute1 =
                                                                                                                                                   lv_region
                                                                                                                                               AND oh_val.attribute2 =
                                                                                                                                                   i.brand
                                                                                                                                               AND oh_val.attribute8
                                                                                                                                                       IS NULL
                                                                                                                                               AND oh_val.attribute9
                                                                                                                                                       IS NULL
                                                                                                                                               AND oh_val.attribute11
                                                                                                                                                       IS NULL
                                                                                                                                               AND oh_val.attribute12
                                                                                                                                                       IS NULL;
                                                                                                                                    EXCEPTION
                                                                                                                                        WHEN NO_DATA_FOUND
                                                                                                                                        THEN
                                                                                                                                            --write_log_prc ('No OHE For Country, Org, Department, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                                                                            lv_oh_region   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_brand   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_duty   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_freight   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_oh_duty   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_nonduty   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_freight_duty   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_inv_org_id   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_country   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_addl_duty   :=
                                                                                                                                                NULL;
                                                                                                                                        WHEN OTHERS
                                                                                                                                        THEN
                                                                                                                                            lv_oh_region   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_brand   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_duty   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_freight   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_oh_duty   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_nonduty   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_freight_duty   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_inv_org_id   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_country   :=
                                                                                                                                                NULL;
                                                                                                                                            lv_oh_addl_duty   :=
                                                                                                                                                NULL;
                                                                                                                                            write_log_prc (
                                                                                                                                                   'OTHERS: No OHE For Country, Org, Department, Style Null'
                                                                                                                                                || lv_country
                                                                                                                                                || '-'
                                                                                                                                                || i.organization_id
                                                                                                                                                || '-'
                                                                                                                                                || i.department
                                                                                                                                                || '-'
                                                                                                                                                || i.style_number);
                                                                                                                                    END;
                                                                                                                                WHEN OTHERS
                                                                                                                                THEN
                                                                                                                                    lv_oh_region   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_brand   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_duty   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_freight   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_oh_duty   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_nonduty   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_freight_duty   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_inv_org_id   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_country   :=
                                                                                                                                        NULL;
                                                                                                                                    lv_oh_addl_duty   :=
                                                                                                                                        NULL;
                                                                                                                            -- write_log_prc ('OTHERS: No OHE For Country Not Null, Org, Department, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                                                                                                                            END;
                                                                                                                        WHEN OTHERS
                                                                                                                        THEN
                                                                                                                            lv_oh_region   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_brand   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_duty   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_freight   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_oh_duty   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_nonduty   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_freight_duty   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_inv_org_id   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_country   :=
                                                                                                                                NULL;
                                                                                                                            lv_oh_addl_duty   :=
                                                                                                                                NULL;
                                                                                                                    -- write_log_prc ('OTHERS: No OHE For Country, Department, Style Is Null Org Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                                                                                                                    END;
                                                                                                                WHEN OTHERS
                                                                                                                THEN
                                                                                                                    lv_oh_region   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_brand   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_duty   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_freight   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_oh_duty   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_nonduty   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_freight_duty   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_inv_org_id   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_country   :=
                                                                                                                        NULL;
                                                                                                                    lv_oh_addl_duty   :=
                                                                                                                        NULL;
                                                                                                            -- write_log_prc ('OTHERS: No OHE For Country, Org Not Null, Department, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                                                                                                            END;
                                                                                                        WHEN OTHERS
                                                                                                        THEN
                                                                                                            lv_oh_region   :=
                                                                                                                NULL;
                                                                                                            lv_oh_brand   :=
                                                                                                                NULL;
                                                                                                            lv_oh_duty   :=
                                                                                                                NULL;
                                                                                                            lv_oh_freight   :=
                                                                                                                NULL;
                                                                                                            lv_oh_oh_duty   :=
                                                                                                                NULL;
                                                                                                            lv_oh_nonduty   :=
                                                                                                                NULL;
                                                                                                            lv_oh_freight_duty   :=
                                                                                                                NULL;
                                                                                                            lv_oh_inv_org_id   :=
                                                                                                                NULL;
                                                                                                            lv_oh_country   :=
                                                                                                                NULL;
                                                                                                            lv_oh_addl_duty   :=
                                                                                                                NULL;
                                                                                                    -- write_log_prc ('OTHERS: No OHE For Country, Style, Org Is Null Department Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                                                                                                    END;
                                                                                                WHEN OTHERS
                                                                                                THEN
                                                                                                    lv_oh_region   :=
                                                                                                        NULL;
                                                                                                    lv_oh_brand   :=
                                                                                                        NULL;
                                                                                                    lv_oh_duty   :=
                                                                                                        NULL;
                                                                                                    lv_oh_freight   :=
                                                                                                        NULL;
                                                                                                    lv_oh_oh_duty   :=
                                                                                                        NULL;
                                                                                                    lv_oh_nonduty   :=
                                                                                                        NULL;
                                                                                                    lv_oh_freight_duty   :=
                                                                                                        NULL;
                                                                                                    lv_oh_inv_org_id   :=
                                                                                                        NULL;
                                                                                                    lv_oh_country   :=
                                                                                                        NULL;
                                                                                                    lv_oh_addl_duty   :=
                                                                                                        NULL;
                                                                                            -- write_log_prc ('OTHERS: No OHE For Country, Department Not Null, Org, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                                                                                            END;
                                                                                        WHEN OTHERS
                                                                                        THEN
                                                                                            lv_oh_region   :=
                                                                                                NULL;
                                                                                            lv_oh_brand   :=
                                                                                                NULL;
                                                                                            lv_oh_duty   :=
                                                                                                NULL;
                                                                                            lv_oh_freight   :=
                                                                                                NULL;
                                                                                            lv_oh_oh_duty   :=
                                                                                                NULL;
                                                                                            lv_oh_nonduty   :=
                                                                                                NULL;
                                                                                            lv_oh_freight_duty   :=
                                                                                                NULL;
                                                                                            lv_oh_inv_org_id   :=
                                                                                                NULL;
                                                                                            lv_oh_country   :=
                                                                                                NULL;
                                                                                            lv_oh_addl_duty   :=
                                                                                                NULL;
                                                                                    -- write_log_prc ('OTHERS: No OHE For Country, Style Null, Org, Department Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                                                    END;
                                                                                WHEN OTHERS
                                                                                THEN
                                                                                    lv_oh_region   :=
                                                                                        NULL;
                                                                                    lv_oh_brand   :=
                                                                                        NULL;
                                                                                    lv_oh_duty   :=
                                                                                        NULL;
                                                                                    lv_oh_freight   :=
                                                                                        NULL;
                                                                                    lv_oh_oh_duty   :=
                                                                                        NULL;
                                                                                    lv_oh_nonduty   :=
                                                                                        NULL;
                                                                                    lv_oh_freight_duty   :=
                                                                                        NULL;
                                                                                    lv_oh_inv_org_id   :=
                                                                                        NULL;
                                                                                    lv_oh_country   :=
                                                                                        NULL;
                                                                                    lv_oh_addl_duty   :=
                                                                                        NULL;
                                                                            -- write_log_prc ('OTHERS: No OHE For Country, Org, Department, Not Null, Style Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                                                                            END;
                                                                        WHEN OTHERS
                                                                        THEN
                                                                            lv_oh_region   :=
                                                                                NULL;
                                                                            lv_oh_brand   :=
                                                                                NULL;
                                                                            lv_oh_duty   :=
                                                                                NULL;
                                                                            lv_oh_freight   :=
                                                                                NULL;
                                                                            lv_oh_oh_duty   :=
                                                                                NULL;
                                                                            lv_oh_nonduty   :=
                                                                                NULL;
                                                                            lv_oh_freight_duty   :=
                                                                                NULL;
                                                                            lv_oh_inv_org_id   :=
                                                                                NULL;
                                                                            lv_oh_country   :=
                                                                                NULL;
                                                                            lv_oh_addl_duty   :=
                                                                                NULL;
                                                                    -- write_log_prc ('OTHERS: No OHE For Country, Org, Department Null, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                                                                    END;
                                                                WHEN OTHERS
                                                                THEN
                                                                    lv_oh_region   :=
                                                                        NULL;
                                                                    lv_oh_brand   :=
                                                                        NULL;
                                                                    lv_oh_duty   :=
                                                                        NULL;
                                                                    lv_oh_freight   :=
                                                                        NULL;
                                                                    lv_oh_oh_duty   :=
                                                                        NULL;
                                                                    lv_oh_nonduty   :=
                                                                        NULL;
                                                                    lv_oh_freight_duty   :=
                                                                        NULL;
                                                                    lv_oh_inv_org_id   :=
                                                                        NULL;
                                                                    lv_oh_country   :=
                                                                        NULL;
                                                                    lv_oh_addl_duty   :=
                                                                        NULL;
                                                            -- write_log_prc ('OTHERS: No OHE For Country, Style Not Null, Org, Department Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                                                            END;
                                                        WHEN OTHERS
                                                        THEN
                                                            lv_oh_region   :=
                                                                NULL;
                                                            lv_oh_brand   :=
                                                                NULL;
                                                            lv_oh_duty   :=
                                                                NULL;
                                                            lv_oh_freight   :=
                                                                NULL;
                                                            lv_oh_oh_duty   :=
                                                                NULL;
                                                            lv_oh_nonduty   :=
                                                                NULL;
                                                            lv_oh_freight_duty   :=
                                                                NULL;
                                                            lv_oh_inv_org_id   :=
                                                                NULL;
                                                            lv_oh_country   :=
                                                                NULL;
                                                            lv_oh_addl_duty   :=
                                                                NULL;
                                                    -- write_log_prc ('OTHERS: No OHE For Country, Department Null, Org, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                                    END;
                                                WHEN OTHERS
                                                THEN
                                                    lv_oh_region    := NULL;
                                                    lv_oh_brand     := NULL;
                                                    lv_oh_duty      := NULL;
                                                    lv_oh_freight   := NULL;
                                                    lv_oh_oh_duty   := NULL;
                                                    lv_oh_nonduty   := NULL;
                                                    lv_oh_freight_duty   :=
                                                        NULL;
                                                    lv_oh_inv_org_id   :=
                                                        NULL;
                                                    lv_oh_country   :=
                                                        NULL;
                                                    lv_oh_addl_duty   :=
                                                        NULL;
                                            -- write_log_prc ('OTHERS: No OHE For Country, Org, Style Not Null, Department Is Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                            END;
                                        WHEN OTHERS
                                        THEN
                                            lv_oh_region         := NULL;
                                            lv_oh_brand          := NULL;
                                            lv_oh_duty           := NULL;
                                            lv_oh_freight        := NULL;
                                            lv_oh_oh_duty        := NULL;
                                            lv_oh_nonduty        := NULL;
                                            lv_oh_freight_duty   := NULL;
                                            lv_oh_inv_org_id     := NULL;
                                            lv_oh_country        := NULL;
                                            lv_oh_addl_duty      := NULL;
                                    -- write_log_prc ('OTHERS: No OHE For Country, Org Null, Department, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                                    END;
                                WHEN OTHERS
                                THEN
                                    lv_oh_region         := NULL;
                                    lv_oh_brand          := NULL;
                                    lv_oh_duty           := NULL;
                                    lv_oh_freight        := NULL;
                                    lv_oh_oh_duty        := NULL;
                                    lv_oh_nonduty        := NULL;
                                    lv_oh_freight_duty   := NULL;
                                    lv_oh_inv_org_id     := NULL;
                                    lv_oh_country        := NULL;
                                    lv_oh_addl_duty      := NULL;
                            -- write_log_prc ('OTHERS: No OHE For Country, Department, Style Not Null, Org Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);

                            END;
                        WHEN OTHERS
                        THEN
                            lv_oh_region         := NULL;
                            lv_oh_brand          := NULL;
                            lv_oh_duty           := NULL;
                            lv_oh_freight        := NULL;
                            lv_oh_oh_duty        := NULL;
                            lv_oh_nonduty        := NULL;
                            lv_oh_freight_duty   := NULL;
                            lv_oh_inv_org_id     := NULL;
                            lv_oh_country        := NULL;
                            lv_oh_addl_duty      := NULL;
                    -- write_log_prc ('OTHERS: No OHE For Country Null, Org, Department, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
                    END;
                WHEN OTHERS
                THEN
                    lv_oh_region         := NULL;
                    lv_oh_brand          := NULL;
                    lv_oh_duty           := NULL;
                    lv_oh_freight        := NULL;
                    lv_oh_oh_duty        := NULL;
                    lv_oh_nonduty        := NULL;
                    lv_oh_freight_duty   := NULL;
                    lv_oh_inv_org_id     := NULL;
                    lv_oh_country        := NULL;
                    lv_oh_addl_duty      := NULL;
            -- write_log_prc ('OTHERS: No OHE For Country Org, Department, Style Not Null'||lv_country||'-'||i.organization_id||'-'||i.department||'-'||i.style_number);
            END;

            -- BEGIN CCR0009885
            IF NVL (pv_duty_vs, 'N') = 'Y' AND lv_oh_duty IS NOT NULL
            THEN
                lv_duty   := lv_oh_duty;
            ELSIF NVL (pv_duty_vs, 'N') = 'N' OR lv_oh_duty IS NULL
            THEN
                lv_duty   := i.duty;
            END IF;

            -- END CCR0009885

            BEGIN
                SELECT harmonized_tariff_code
                  INTO lv_tariff_code
                  FROM do_custom.do_harmonized_tariff_codes
                 WHERE style_number = i.style_number AND country = lv_country;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           'Unable to derive tariff code for the style number and country'
                        || i.style_number
                        || '-'
                        || lv_country);
                    lv_tariff_code   := NULL;
            END;

            BEGIN
                INSERT INTO xxdo.xxd_cst_oh_elements_stg_t (
                                style_number,
                                style_color,
                                item_size,
                                item_number,
                                inventory_item_id,
                                department,
                                organization_id,
                                organization_code,
                                country,
                                brand,
                                region,
                                duty,
                                primary_duty_flag,
                                duty_start_date,
                                duty_end_date,
                                freight,
                                freight_duty,
                                oh_duty,
                                oh_nonduty,
                                factory_cost,
                                addl_duty,
                                tarrif_code,
                                rec_status,
                                error_msg,
                                created_by,
                                creation_date,
                                last_update_date,
                                last_updated_by,
                                request_id,
                                GROUP_ID)
                         VALUES (TRIM (i.style_number),
                                 TRIM (i.style_color),
                                 TRIM (i.item_size),
                                 TRIM (i.item_number),
                                 TRIM (i.inventory_item_id),
                                 TRIM (i.department),
                                 TRIM (i.organization_id),
                                 TRIM (i.organization_code),
                                 TRIM (lv_country),
                                 TRIM (lv_oh_brand),
                                 TRIM (lv_oh_region)--,TRIM (i.duty)                                       -- Commeented  CCR0009885
                                                    ,
                                 TRIM (lv_duty)           -- Added  CCR0009885
                                               ,
                                 TRIM (i.primary_duty_flag),
                                 TRIM (i.duty_start_date),
                                 TRIM (i.duty_end_date),
                                 TRIM (lv_oh_freight),
                                 TRIM (lv_oh_freight_duty),
                                 TRIM (lv_oh_oh_duty),
                                 TRIM (lv_oh_nonduty),
                                 NULL,
                                 TRIM (lv_oh_addl_duty),
                                 TRIM (lv_tariff_code),
                                 'N',
                                 NULL,
                                 TRIM (gn_user_id),
                                 SYSDATE,
                                 SYSDATE,
                                 TRIM (gn_user_id),
                                 TRIM (gn_request_id),
                                 TRIM (l_group_id));

                ln_stg_insert   := ln_stg_insert + 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           SQLERRM
                        || ' Insertion Failed for Staging table: xxdo.xxd_cst_oh_elements_stg_t');
            END;

            IF ln_stg_insert >= 2000
            THEN
                COMMIT;
                ln_stg_insert   := 0;
            END IF;

            EXIT WHEN c_items_ccid_duty_cur%NOTFOUND;
        END LOOP;

        COMMIT;

        BEGIN
            UPDATE xxdo.xxd_cst_oh_elements_stg_t
               SET rec_status = 'E', error_msg = 'Unable To Derive OH Values From Value Set'
             WHERE     rec_status = 'N'
                   AND region IS NULL
                   AND brand IS NULL
                   AND request_id = gn_request_id;

            write_log_prc (
                   SQL%ROWCOUNT
                || 'Records Updated With Error Unable To Derive OH Values');
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                       'Error: Updation Failed for Staging table: xxdo.xxd_cst_oh_elements_stg_t'
                    || SQLERRM);
        END;

        write_log_prc (
               'Procedure oh_ele_data_into_tbl_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Error in Procedure oh_ele_data_into_tbl_prc:' || SQLERRM);
    END oh_ele_data_into_tbl_prc;

       /***************************************************************************
-- PROCEDURE create_final_zip_prc
-- PURPOSE: This Procedure Converts the file to zip file
***************************************************************************/

    FUNCTION file_to_blob_fnc (pv_directory_name   IN VARCHAR2,
                               pv_file_name        IN VARCHAR2)
        RETURN BLOB
    IS
        dest_loc   BLOB := EMPTY_BLOB ();
        src_loc    BFILE := BFILENAME (pv_directory_name, pv_file_name);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           ' Start of Convering the file to BLOB');

        DBMS_LOB.OPEN (src_loc, DBMS_LOB.LOB_READONLY);

        DBMS_LOB.CREATETEMPORARY (lob_loc   => dest_loc,
                                  cache     => TRUE,
                                  dur       => DBMS_LOB.session);

        DBMS_LOB.OPEN (dest_loc, DBMS_LOB.LOB_READWRITE);

        DBMS_LOB.LOADFROMFILE (dest_lob   => dest_loc,
                               src_lob    => src_loc,
                               amount     => DBMS_LOB.getLength (src_loc));

        DBMS_LOB.CLOSE (dest_loc);

        DBMS_LOB.CLOSE (src_loc);

        RETURN dest_loc;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in Converting the file to BLOB - ' || SQLERRM);

            RETURN NULL;
    END file_to_blob_fnc;

    PROCEDURE save_zip_prc (pb_zipped_blob     BLOB,
                            pv_dir             VARCHAR2,
                            pv_zip_file_name   VARCHAR2)
    IS
        t_fh    UTL_FILE.file_type;
        t_len   PLS_INTEGER := 32767;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of save_zip_prc Procedure');

        DBMS_OUTPUT.put_line (' Start of save_zip_prc Procedure');

        t_fh   := UTL_FILE.fopen (pv_dir, pv_zip_file_name, 'wb');

        DBMS_OUTPUT.put_line (' Start of save_zip_prc Procedure - TEST1');

        FOR i IN 0 ..
                 TRUNC ((DBMS_LOB.getlength (pb_zipped_blob) - 1) / t_len)
        LOOP
            UTL_FILE.put_raw (
                t_fh,
                DBMS_LOB.SUBSTR (pb_zipped_blob, t_len, i * t_len + 1));
        END LOOP;

        UTL_FILE.fclose (t_fh);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in save_zip_prc Procedure - ' || SQLERRM);

            DBMS_OUTPUT.put_line (
                ' Exception in save_zip_prc Procedure - ' || SQLERRM);
    END save_zip_prc;


    PROCEDURE create_final_zip_prc (pv_directory_name IN VARCHAR2, pv_file_name IN VARCHAR2, pv_zip_file_name IN VARCHAR2)
    IS
        lb_file   BLOB;
        lb_zip    BLOB;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of file_to_blob_fnc ');

        lb_file   := file_to_blob_fnc (pv_directory_name, pv_file_name);

        fnd_file.put_line (fnd_file.LOG, pv_directory_name || pv_file_name);

        fnd_file.put_line (fnd_file.LOG, ' Start of add_file PROC ');

        APEX_200200.WWV_FLOW_ZIP.add_file (lb_zip, pv_file_name, lb_file);

        fnd_file.put_line (fnd_file.LOG, ' Start of finish PROC ');

        APEX_200200.wwv_flow_zip.finish (lb_zip);

        fnd_file.put_line (fnd_file.LOG, ' Start of Saving ZIP File PROC ');

        save_zip_prc (lb_zip, pv_directory_name, pv_zip_file_name);
    END create_final_zip_prc;


      /***************************************************************************
-- PROCEDURE write_duty_ele_report_prc
-- PURPOSE: This Procedure generates the duty elements report
***************************************************************************/

    PROCEDURE write_duty_ele_report_prc (pv_display_sku IN VARCHAR2)
    IS
        CURSOR duty_ele_rep_sku IS
              SELECT style_number style_number, style_color style_color, item_size item_size,
                     organization_code organization_code, item_number item_number, duty,
                     primary_duty_flag, duty_start_date, duty_end_date,
                     freight, freight_duty, oh_duty,
                     oh_nonduty, factory_cost, addl_duty,
                     tarrif_code, country
                FROM xxdo.xxd_cst_oh_elements_stg_t
               WHERE 1 = 1 AND request_id = gn_request_id
            ORDER BY style_number, style_color, item_size;

        CURSOR duty_ele_rep IS
              SELECT style_number style_number, NULL style_color, organization_code organization_code,
                     NULL item_number, MAX (duty) duty, NULL primary_duty_flag,
                     NULL duty_start_date, NULL duty_end_date, MAX (freight) freight,
                     MAX (freight_duty) freight_duty, MAX (oh_duty) oh_duty, MAX (oh_nonduty) oh_nonduty,
                     MAX (factory_cost) factory_cost, MAX (addl_duty) addl_duty, NULL tarrif_code,
                     country
                FROM xxdo.xxd_cst_oh_elements_stg_t
               WHERE 1 = 1 AND request_id = gn_request_id
            GROUP BY style_number, organization_code, country
            ORDER BY style_number;

        lv_oh_ele_rep_file       VARCHAR2 (1000);
        lv_oh_ele_rep_file_zip   VARCHAR2 (1000);
        lv_file_path             VARCHAR2 (100);
        lv_hdr_line              VARCHAR2 (1000);
        lv_sku_hdr_line          VARCHAR2 (1000);
        lv_line                  VARCHAR2 (32000);
        lv_output_file           UTL_FILE.file_type;
        lv_outbound_file         VARCHAR2 (1000);
        x_ret_code               VARCHAR2 (100);
        lv_err_msg               VARCHAR2 (100);
        x_ret_message            VARCHAR2 (100);
        lv_header                VARCHAR2 (1) := 'Y';
        buffer_size     CONSTANT INTEGER := 32767;
    BEGIN
        write_log_prc (
               'Procedure write_duty_ele_report_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        lv_oh_ele_rep_file   :=
            gn_request_id || '_Costing_Material_Overhead_Elements_Upload.csv';

        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_file_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_CST_DUTY_ELE_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_file_path   := NULL;
        END;

        IF pv_display_sku = 'Y'
        THEN
            lv_sku_hdr_line   :=
                   'Style'
                || gv_delim_comma
                || 'Style Color'
                || gv_delim_comma
                || 'Organization Code'
                || gv_delim_comma
                || 'Item'
                || gv_delim_comma
                || 'Duty'
                || gv_delim_comma
                || 'Primary Duty Flag'
                || gv_delim_comma
                || 'Duty Start Date'
                || gv_delim_comma
                || 'Duty End Date'
                || gv_delim_comma
                || 'Freight'
                || gv_delim_comma
                || 'Freight Duty'
                || gv_delim_comma
                || 'OH Duty'
                || gv_delim_comma
                || 'OH Nonduty'
                || gv_delim_comma
                || 'Factory Cost'
                || gv_delim_comma
                || 'Add''l Duty'
                || gv_delim_comma
                || 'Tariff Code'
                || gv_delim_comma
                || 'Country';

            -- WRITE INTO FOLDER
            write_log_prc (
                'Duty Elements File Name is - ' || lv_oh_ele_rep_file);

            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_oh_ele_rep_file, 'W' --opening the file in write mode
                                                                     ,
                                buffer_size);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                IF lv_header = 'Y'
                THEN
                    lv_line   := lv_sku_hdr_line;
                    UTL_FILE.put_line (lv_output_file, lv_line);
                END IF;

                FOR i IN duty_ele_rep_sku
                LOOP
                    lv_line   :=
                           i.style_number
                        || gv_delim_comma
                        || i.style_color
                        || gv_delim_comma
                        || i.organization_code
                        || gv_delim_comma
                        || i.item_number
                        || gv_delim_comma
                        || i.duty
                        || gv_delim_comma
                        || i.primary_duty_flag
                        || gv_delim_comma
                        || i.duty_start_date
                        || gv_delim_comma
                        || i.duty_end_date
                        || gv_delim_comma
                        || i.freight
                        || gv_delim_comma
                        || i.freight_duty
                        || gv_delim_comma
                        || i.oh_duty
                        || gv_delim_comma
                        || i.oh_nonduty
                        || gv_delim_comma
                        || i.factory_cost
                        || gv_delim_comma
                        || i.addl_duty
                        || gv_delim_comma
                        || i.tarrif_code
                        || gv_delim_comma
                        || i.country;

                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;
            ELSE
                lv_err_msg      :=
                    SUBSTR (
                           'Error in Opening the Duty Elements data file for writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                write_log_prc (lv_err_msg);
                x_ret_code      := gn_error;
                x_ret_message   := lv_err_msg;
                RETURN;
            END IF;

            UTL_FILE.fclose (lv_output_file);
        ELSIF pv_display_sku = 'N'
        THEN
            lv_hdr_line   :=
                   'Style'
                || gv_delim_comma
                || 'Style Color'
                || gv_delim_comma
                || 'Organization Code'
                || gv_delim_comma
                || 'Item'
                || gv_delim_comma
                || 'Duty'
                || gv_delim_comma
                || 'Primary Duty Flag'
                || gv_delim_comma
                || 'Duty Start Date'
                || gv_delim_comma
                || 'Duty End Date'
                || gv_delim_comma
                || 'Freight'
                || gv_delim_comma
                || 'Freight Duty'
                || gv_delim_comma
                || 'OH Duty'
                || gv_delim_comma
                || 'OH Nonduty'
                || gv_delim_comma
                || 'Factory Cost'
                || gv_delim_comma
                || 'Add''l Duty'
                || gv_delim_comma
                || 'Tariff Code'
                || gv_delim_comma
                || 'Country';

            -- WRITE INTO FOLDER
            write_log_prc (
                'Duty Elements File Name is - ' || lv_oh_ele_rep_file);

            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_oh_ele_rep_file, 'W' --opening the file in write mode
                                                                     ,
                                buffer_size);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                IF lv_header = 'Y'
                THEN
                    lv_line   := lv_hdr_line;
                    UTL_FILE.put_line (lv_output_file, lv_line);
                END IF;

                FOR i IN duty_ele_rep
                LOOP
                    lv_line   :=
                           i.style_number
                        || gv_delim_comma
                        || i.style_color
                        || gv_delim_comma
                        || i.organization_code
                        || gv_delim_comma
                        || i.item_number
                        || gv_delim_comma
                        || i.duty
                        || gv_delim_comma
                        || i.primary_duty_flag
                        || gv_delim_comma
                        || i.duty_start_date
                        || gv_delim_comma
                        || i.duty_end_date
                        || gv_delim_comma
                        || i.freight
                        || gv_delim_comma
                        || i.freight_duty
                        || gv_delim_comma
                        || i.oh_duty
                        || gv_delim_comma
                        || i.oh_nonduty
                        || gv_delim_comma
                        || i.factory_cost
                        || gv_delim_comma
                        || i.addl_duty
                        || gv_delim_comma
                        || i.tarrif_code
                        || gv_delim_comma
                        || i.country;

                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;
            ELSE
                lv_err_msg      :=
                    SUBSTR (
                           'Error in Opening the Duty Elements data file for writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                write_log_prc (lv_err_msg);
                x_ret_code      := gn_error;
                x_ret_message   := lv_err_msg;
                RETURN;
            END IF;

            UTL_FILE.fclose (lv_output_file);
        END IF;

        UTL_FILE.fclose (lv_output_file);

        lv_oh_ele_rep_file_zip   :=
               SUBSTR (lv_oh_ele_rep_file,
                       1,
                       (INSTR (lv_oh_ele_rep_file, '.', -1) - 1))
            || '.zip';
        write_log_prc (
            'OH Elements Report File Name is - ' || lv_oh_ele_rep_file);
        write_log_prc (
               'OH Elements Report ZIP File Name is - '
            || lv_oh_ele_rep_file_zip);

        create_final_zip_prc (
            pv_directory_name   => 'XXD_CST_DUTY_ELE_REP_DIR',
            pv_file_name        => lv_oh_ele_rep_file,
            pv_zip_file_name    => lv_oh_ele_rep_file_zip);

        duty_ele_rep_send_mail_prc (lv_oh_ele_rep_file_zip);

        write_log_prc (
               'Procedure write_duty_ele_report_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_duty_ele_report_prc;

    /***************************************************************************
     -- PROCEDURE update_item_price_prc
     -- PURPOSE: This Procedure update the price for an item
     ***************************************************************************/
    PROCEDURE update_item_price_prc (
        p_item_tbl_type IN ego_item_pub.item_tbl_type)
    IS
        -- l_item_tbl_typ    ego_item_pub.item_tbl_type;
        x_item_table      ego_item_pub.item_tbl_type;
        x_message_list    error_handler.error_tbl_type;
        x_return_status   VARCHAR2 (1);
        x_msg_count       NUMBER (10);
        l_count           NUMBER;
    BEGIN
        write_log_prc ('Procedure update_item_price_prc Begin....');

                 /* l_item_tbl_typ (1).transaction_type := 'UPDATE';
l_item_tbl_typ (1).inventory_item_id := p_inv_item_id;
l_item_tbl_typ (1).organization_id := p_inv_org_id;
l_item_tbl_typ (1).list_price_per_unit := p_factory_cost;*/

        ego_item_pub.process_items (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_true, p_item_tbl => p_item_tbl_type, x_item_tbl => x_item_table, x_return_status => x_return_status
                                    , x_msg_count => x_msg_count);

        IF (x_return_status <> fnd_api.g_ret_sts_success)
        THEN
            write_log_prc ('Error Messages :');
            error_handler.get_message_list (x_message_list => x_message_list);

            FOR i IN 1 .. x_message_list.COUNT
            LOOP
                write_log_prc (x_message_list (i).MESSAGE_TEXT);
            END LOOP;
        END IF;

        COMMIT;
        write_log_prc (
               'Procedure update_item_price_prc Ends....'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Error in update_item_price_prc Procedure -' || SQLERRM);
    END update_item_price_prc;

    /***************************************************************************
 -- PROCEDURE submit_cost_import_prc
 -- PURPOSE: This Procedure submits cost import standard program
 ***************************************************************************/
    PROCEDURE submit_cost_import_prc (p_return_mesg OUT VARCHAR2, p_return_code OUT VARCHAR2, p_request_id OUT NUMBER
                                      , p_group_id IN NUMBER)
    IS
        l_req_id       NUMBER;
        l_phase        VARCHAR2 (100);
        l_status       VARCHAR2 (30);
        l_dev_phase    VARCHAR2 (100);
        l_dev_status   VARCHAR2 (100);
        l_wait_req     BOOLEAN;
        l_message      VARCHAR2 (2000);
    BEGIN
        write_log_prc (
               'Procedure submit_cost_import_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        l_req_id       :=
            fnd_request.submit_request (application   => 'BOM',
                                        program       => 'CSTPCIMP',
                                        argument1     => 4,
                                        -- Import Cost Option (Import item costs,resource rates, and overhead rates)
                                        argument2     => 2,
                                        -- (Mode to Run )Remove and replace cost information
                                        argument3     => 1, -- Group Id option (specific_request_id)
                                        argument4     => NULL, -- Dummy Group ID
                                        argument5     => p_group_id, -- Group Id
                                        argument6     => 'AvgRates', -- Cost Type
                                        argument7     => 2, -- Delete Successful rows
                                        start_time    => SYSDATE,
                                        sub_request   => FALSE);
        COMMIT;

        IF l_req_id = 0
        THEN
            p_return_code   := 2;
            write_log_prc (
                ' Unable to submit Cost Import concurrent program ');
        ELSE
            write_log_prc (
                'Cost Import concurrent request submitted successfully.');
            l_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => l_req_id, interval => 5, phase => l_phase, status => l_status, dev_phase => l_dev_phase, dev_status => l_dev_status
                                                 , MESSAGE => l_message);

            IF l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL'
            THEN
                write_log_prc (
                       'Cost Import concurrent request with the request id '
                    || l_req_id
                    || ' completed with NORMAL status.');
            ELSE
                p_return_code   := 2;
                write_log_prc (
                       'Cost Import concurrent request with the request id '
                    || l_req_id
                    || ' did not complete with NORMAL status.');
            END IF; -- End of if to check if the status is normal and phase is complete
        END IF;                      -- End of if to check if request ID is 0.

        COMMIT;
        p_request_id   := l_req_id;
        write_log_prc (
               'Procedure submit_cost_import_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_code   := 2;
            p_return_mesg   :=
                   'Error in Cost Import '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ();

            write_log_prc (p_return_mesg);
            write_log_prc (
                'Error in submit_cost_import_prc Procedure -' || SQLERRM);
    END submit_cost_import_prc;

    /***************************************************************************
 -- PROCEDURE update_interface_status_prc
 -- PURPOSE: This Procedure update staging table rec_status based on
 --          Interface record status
 ***************************************************************************/
    PROCEDURE update_interface_status_prc (pv_to_org IN VARCHAR2, p_request_id IN NUMBER, p_group_id IN NUMBER)
    IS
        l_status         VARCHAR2 (1);
        l_err_msg        VARCHAR2 (4000);
        v_interfaced     VARCHAR2 (1);
        l_update_count   NUMBER := 0;
    BEGIN
        write_log_prc (
               'Procedure update_interface_status_prc Begins....'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        BEGIN
            UPDATE xxdo.xxd_cst_oh_elements_stg_t xcoest
               SET xcoest.rec_status   = 'E',
                   error_msg          =
                       (SELECT            --error_code||'-'||error_explanation
                               LISTAGG (DISTINCT int.error_explanation, '-') WITHIN GROUP (ORDER BY int.inventory_item_id)
                          FROM cst_item_cst_dtls_interface int
                         WHERE     1 = 1
                               AND xcoest.inventory_item_id =
                                   int.inventory_item_id
                               AND NVL (pv_to_org, xcoest.organization_id) =
                                   int.organization_id
                               AND int.request_id = p_request_id
                               AND GROUP_ID = p_group_id
                               AND error_flag IS NOT NULL)
             WHERE     EXISTS
                           (SELECT 1
                              FROM cst_item_cst_dtls_interface int
                             WHERE     1 = 1
                                   AND xcoest.inventory_item_id =
                                       int.inventory_item_id
                                   AND NVL (pv_to_org,
                                            xcoest.organization_id) =
                                       int.organization_id
                                   AND int.request_id = p_request_id
                                   AND GROUP_ID = p_group_id
                                   AND error_flag IS NOT NULL)
                   AND xcoest.GROUP_ID = p_group_id
                   AND xcoest.request_id = gn_request_id
                   AND xcoest.rec_status = 'I'
                   AND xcoest.error_msg IS NULL;

            write_log_prc (
                SQL%ROWCOUNT || ' Records updated with the Rec Status as E');
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Exception Occured while updating the processed status in staging table:');
        END;

        BEGIN
            UPDATE xxdo.xxd_cst_oh_elements_stg_t xcoest
               SET xcoest.rec_status   = 'P'
             WHERE     EXISTS
                           (SELECT 1
                              FROM cst_item_cst_dtls_interface int
                             WHERE     1 = 1
                                   AND xcoest.inventory_item_id =
                                       int.inventory_item_id
                                   AND NVL (pv_to_org,
                                            xcoest.organization_id) =
                                       int.organization_id
                                   AND int.request_id = p_request_id
                                   AND GROUP_ID = p_group_id
                                   AND error_flag IS NULL
                                   AND process_flag = 5)
                   AND xcoest.GROUP_ID = p_group_id
                   AND xcoest.request_id = gn_request_id
                   AND xcoest.rec_status = 'I'
                   AND xcoest.error_msg IS NULL;

            -- UPDATE xxdo.xxd_cst_oh_elements_stg_t
            -- SET rec_status = 'P'
            -- WHERE rec_status IN ('I')
            -- AND error_msg IS NULL
            -- AND group_id = p_group_id
            -- AND request_id = gn_request_id
            -- AND active_flag = 'Y';

            write_log_prc (
                SQL%ROWCOUNT || ' Records updated with the Rec Status as P');
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Exception Occured while updating the processed status in staging table:');
        END;

        write_log_prc (
               'Procedure update_interface_status_prc Ends....'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Error in update_interface_status_prc Procedure -' || SQLERRM);
    END update_interface_status_prc;

    /***************************************************************************
 -- PROCEDURE insert_into_interface_prc
 -- PURPOSE: This Procedure inserts the duty element records to CST Interface tables
 ***************************************************************************/

    PROCEDURE insert_into_interface_prc (pv_from_org   IN VARCHAR2,
                                         pv_to_org     IN VARCHAR2)
    IS
        CURSOR oh_elements_cur IS
            SELECT *
              FROM xxdo.xxd_cst_oh_elements_stg_t
             WHERE     1 = 1
                   AND rec_status = 'N'
                   AND request_id = gn_request_id
                   AND organization_id = pv_from_org;

        l_item_tbl_typ       ego_item_pub.item_tbl_type;
        user_exception       EXCEPTION;
        l_group_id           NUMBER;
        l_insert_count       NUMBER;
        l_price              NUMBER;
        l_duty_basis         NUMBER;
        l_freight_basis      NUMBER;
        l_oh_duty_basis      NUMBER;
        l_oh_nonduty_basis   NUMBER;
        l_freight_du_basis   NUMBER;
        api_index            NUMBER := 0;
        v_interfaced         VARCHAR2 (1);
        l_int_req_id         NUMBER;
        p_errbuff            VARCHAR2 (4000);
        p_retcode            VARCHAR2 (4000);
        lv_freight           VARCHAR2 (1000);
        lv_oh_duty           VARCHAR2 (1000);
        lv_oh_nonduty        VARCHAR2 (1000);
        lv_freight_duty      VARCHAR2 (1000);
    BEGIN
        write_log_prc ('Truncating table CST_ITEM_CST_DTLS_INTERFACE.. ');

        EXECUTE IMMEDIATE 'truncate table BOM.CST_ITEM_CST_DTLS_INTERFACE';

        BEGIN
            SELECT cc.cost_element_id
              INTO gn_cost_element_id
              FROM cst_cost_elements cc
             WHERE 1 = 1 AND UPPER (cc.cost_element) = 'MATERIAL OVERHEAD';

            write_log_prc (
                   'cost element id for material_overhead is -'
                || gn_cost_element_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc ('Error while fetching cost element id ');
                RAISE user_exception;
        END;

        FOR i IN oh_elements_cur
        LOOP
            l_group_id       := i.GROUP_ID;
            l_insert_count   := l_insert_count + 1;
            l_price          := 0;

            write_log_prc (
                   'Procedure insert_into_interface_prc Begins...'
                || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

            BEGIN
                SELECT default_basis_type
                  INTO l_duty_basis
                  FROM bom_resources_v
                 WHERE     1 = 1
                       AND cost_element_id = gn_cost_element_id
                       AND resource_code = gc_duty
                       AND organization_id = i.organization_id;
            -- write_log_prc ('Deriving default_basis_type for Duty - '||l_duty_basis);

            EXCEPTION
                WHEN OTHERS
                THEN
                    l_duty_basis   := 1;
            END;

            BEGIN
                SELECT default_basis_type
                  INTO l_oh_duty_basis
                  FROM bom_resources_v
                 WHERE     1 = 1
                       AND cost_element_id = gn_cost_element_id
                       AND resource_code = gc_oh_duty
                       AND organization_id = i.organization_id;
            -- write_log_prc ('Deriving default_basis_type for OH Duty - '||l_oh_duty_basis);

            EXCEPTION
                WHEN OTHERS
                THEN
                    l_oh_duty_basis   := 1;
            END;

            BEGIN
                SELECT default_basis_type
                  INTO l_oh_nonduty_basis
                  FROM bom_resources_v
                 WHERE     1 = 1
                       AND cost_element_id = gn_cost_element_id
                       AND resource_code = gc_oh_nonduty
                       AND organization_id = i.organization_id;
            -- write_log_prc ('Deriving default_basis_type for OH Non Duty - '||l_oh_nonduty_basis);

            EXCEPTION
                WHEN OTHERS
                THEN
                    l_oh_nonduty_basis   := 1;
            END;

            BEGIN
                SELECT default_basis_type
                  INTO l_freight_basis
                  FROM bom_resources_v
                 WHERE     1 = 1
                       AND cost_element_id = gn_cost_element_id
                       AND resource_code = gc_freight
                       AND organization_id = i.organization_id;
            -- write_log_prc ('Deriving default_basis_type for Freight - '||l_freight_basis);

            EXCEPTION
                WHEN OTHERS
                THEN
                    l_freight_basis   := 1;
            END;

            BEGIN
                SELECT default_basis_type
                  INTO l_freight_du_basis
                  FROM bom_resources_v
                 WHERE     1 = 1
                       AND cost_element_id = gn_cost_element_id
                       AND resource_code = gc_freight_du
                       AND organization_id = i.organization_id;
            -- write_log_prc ('Deriving default_basis_type for Freight Duty - '||l_freight_du_basis);

            EXCEPTION
                WHEN OTHERS
                THEN
                    l_freight_du_basis   := 1;
            END;

            IF i.duty IS NOT NULL
            THEN
                write_log_prc ('Inserting Duty Element Data into Interface');
                write_log_prc (
                       i.inventory_item_id
                    || '-'
                    || i.organization_id
                    || '-'
                    || gc_duty
                    || '-'
                    || i.duty
                    || '-'
                    || gn_cost_element_id
                    || '-'
                    || gc_cost_type
                    || '-'
                    || l_duty_basis
                    || '-'
                    || gn_process_flag
                    || '-'
                    || SYSDATE
                    || '-'
                    || gn_user_id
                    || '-'
                    || SYSDATE
                    || '-'
                    || gn_user_id
                    || '-'
                    || l_group_id);

                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.inventory_item_id, NVL (pv_to_org, pv_from_org), gc_duty, i.duty, gn_cost_element_id, gc_cost_type, l_duty_basis, gn_process_flag, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , l_group_id);
            END IF;

            /*            IF i.freight IS NULL OR i.oh_duty IS NULL OR i.oh_nonduty IS NULL OR i.freight_duty IS NULL
                        THEN
                             IF i.freight IS NULL
                             THEN
                                 BEGIN

                                      lv_freight := NULL;

                                      SELECT usage_rate_or_amount
                                        INTO lv_freight
                                        FROM apps.cst_item_cost_details_v
                                       WHERE resource_code = gc_freight
                                         AND cost_type_id = 1000
                                         AND inventory_item_id = i.inventory_item_id
                                         AND organization_id = i.organization_id;

                                 EXCEPTION
                                      WHEN OTHERS
                                      THEN
                                          write_log_prc ('Unable to Derive Freight Element from CICD');
                                          lv_freight := NULL;
                                 END;

                             ELSIF i.freight IS NOT NULL
                             THEN
                                 lv_freight := NULL;
                                 lv_freight := i.freight;
                             END IF;

                             IF i.oh_duty IS NULL
                             THEN
                                 BEGIN

                                      lv_oh_duty := NULL;

                                      SELECT usage_rate_or_amount
                                        INTO lv_oh_duty
                                        FROM apps.cst_item_cost_details_v
                                       WHERE resource_code = gc_oh_duty
                                         AND cost_type_id = 1000
                                         AND inventory_item_id = i.inventory_item_id
                                         AND organization_id = i.organization_id;

                                 EXCEPTION
                                      WHEN OTHERS
                                      THEN
                                          write_log_prc ('Unable to Derive OH Duty Element from CICD');
                                          lv_oh_duty := NULL;
                                 END;

                             ELSIF i.oh_duty IS NOT NULL
                             THEN
                                 lv_oh_duty := NULL;
                                 lv_oh_duty := i.oh_duty;
                             END IF;

                             IF i.oh_nonduty IS NULL
                             THEN
                                 BEGIN

                                      lv_oh_nonduty := NULL;

                                      SELECT usage_rate_or_amount
                                        INTO lv_oh_nonduty
                                        FROM apps.cst_item_cost_details_v
                                       WHERE resource_code = gc_oh_nonduty
                                         AND cost_type_id = 1000
                                         AND inventory_item_id = i.inventory_item_id
                                         AND organization_id = i.organization_id;

                                 EXCEPTION
                                      WHEN OTHERS
                                      THEN
                                          write_log_prc ('Unable to Derive OH NONDuty Element from CICD');
                                          lv_oh_nonduty := NULL;
                                 END;

                             ELSIF i.oh_nonduty IS NOT NULL
                             THEN
                                 lv_oh_nonduty := NULL;
                                 lv_oh_nonduty := i.oh_nonduty;
                             END IF;

                             IF i.freight_duty IS NULL
                             THEN
                                 BEGIN

                                      lv_freight_duty := NULL;

                                      SELECT usage_rate_or_amount
                                        INTO lv_freight_duty
                                        FROM apps.cst_item_cost_details_v
                                       WHERE resource_code = gc_freight_du
                                         AND cost_type_id = 1000
                                         AND inventory_item_id = i.inventory_item_id
                                         AND organization_id = i.organization_id;

                                 EXCEPTION
                                      WHEN OTHERS
                                      THEN
                                          write_log_prc ('Unable to Derive OH NONDuty Element from CICD');
                                          lv_freight_duty := NULL;
                                 END;

                             ELSIF i.freight_duty IS NOT NULL
                             THEN
                                 lv_freight_duty := NULL;
                                 lv_freight_duty := i.freight_duty;
                             END IF;

                             IF lv_freight IS NULL OR lv_oh_duty IS NULL OR lv_oh_nonduty IS NULL OR lv_freight_duty IS NULL
                             THEN
                                 lv_freight := 0;
                                 lv_oh_duty := 0;
                                 lv_oh_nonduty := 0;
                                 lv_freight_duty := 0;
                             END IF;

                        ELSIF i.freight IS NOT NULL AND i.oh_duty IS NOT NULL AND i.oh_nonduty IS NOT NULL AND i.freight_duty IS NOT NULL
                        THEN
                            lv_freight := i.freight;
                            lv_oh_duty := i.oh_duty;
                            lv_oh_nonduty := i.oh_nonduty;
                            lv_freight_duty := i.freight_duty;
                        END IF; */

            IF i.freight IS NULL
            THEN
                BEGIN
                    lv_freight   := 0;

                    SELECT usage_rate_or_amount
                      INTO lv_freight
                      FROM apps.cst_item_cost_details_v
                     WHERE     resource_code = gc_freight
                           AND cost_type_id = 1000
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                            'Unable to Derive Freight Element from CICD');
                        lv_freight   := 0;
                END;
            ELSIF i.freight IS NOT NULL
            THEN
                lv_freight   := 0;
                lv_freight   := i.freight;
            END IF;

            IF lv_freight IS NOT NULL
            THEN
                --write_log_prc ('Inserting freight Element Data into Interface');
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.inventory_item_id, NVL (pv_to_org, pv_from_org), gc_freight, -- i.freight,
                                                                                            lv_freight, gn_cost_element_id, gc_cost_type, l_freight_basis, gn_process_flag, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , l_group_id);
            END IF;

            IF i.oh_duty IS NULL
            THEN
                BEGIN
                    lv_oh_duty   := 0;

                    SELECT usage_rate_or_amount
                      INTO lv_oh_duty
                      FROM apps.cst_item_cost_details_v
                     WHERE     resource_code = gc_oh_duty
                           AND cost_type_id = 1000
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                            'Unable to Derive OH Duty Element from CICD');
                        lv_oh_duty   := 0;
                END;
            ELSIF i.oh_duty IS NOT NULL
            THEN
                lv_oh_duty   := 0;
                lv_oh_duty   := i.oh_duty;
            END IF;

            IF lv_oh_duty IS NOT NULL
            THEN
                --write_log_prc ('Inserting OH Duty Element Data into Interface');
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.inventory_item_id, NVL (pv_to_org, pv_from_org), gc_oh_duty, --i.oh_duty,
                                                                                            lv_oh_duty, gn_cost_element_id, gc_cost_type, l_oh_duty_basis, gn_process_flag, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , l_group_id);
            END IF;

            IF i.oh_nonduty IS NULL
            THEN
                BEGIN
                    lv_oh_nonduty   := 0;

                    SELECT usage_rate_or_amount
                      INTO lv_oh_nonduty
                      FROM apps.cst_item_cost_details_v
                     WHERE     resource_code = gc_oh_nonduty
                           AND cost_type_id = 1000
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                            'Unable to Derive OH NONDuty Element from CICD');
                        lv_oh_nonduty   := 0;
                END;
            ELSIF i.oh_nonduty IS NOT NULL
            THEN
                lv_oh_nonduty   := 0;
                lv_oh_nonduty   := i.oh_nonduty;
            END IF;

            IF lv_oh_nonduty IS NOT NULL
            THEN
                --write_log_prc ('Inserting OH Non Duty Element Data into Interface');
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.inventory_item_id, NVL (pv_to_org, pv_from_org), gc_oh_nonduty, --i.oh_nonduty,
                                                                                               lv_oh_nonduty, gn_cost_element_id, gc_cost_type, l_oh_nonduty_basis, gn_process_flag, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , l_group_id);
            END IF;

            IF i.freight_duty IS NULL
            THEN
                BEGIN
                    lv_freight_duty   := 0;

                    SELECT usage_rate_or_amount
                      INTO lv_freight_duty
                      FROM apps.cst_item_cost_details_v
                     WHERE     resource_code = gc_freight_du
                           AND cost_type_id = 1000
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                            'Unable to Derive OH NONDuty Element from CICD');
                        lv_freight_duty   := 0;
                END;
            ELSIF i.freight_duty IS NOT NULL
            THEN
                lv_freight_duty   := 0;
                lv_freight_duty   := i.freight_duty;
            END IF;

            IF lv_freight_duty IS NOT NULL
            THEN
                --write_log_prc ('Inserting freight_duty Element Data into Interface');
                INSERT INTO cst_item_cst_dtls_interface (inventory_item_id, organization_id, resource_code, usage_rate_or_amount, cost_element_id, cost_type, basis_type, process_flag, last_update_date, last_updated_by, creation_date, created_by
                                                         , GROUP_ID)
                     VALUES (i.inventory_item_id, NVL (pv_to_org, pv_from_org), gc_freight_du, --i.freight_duty,
                                                                                               lv_freight_duty, gn_cost_element_id, gc_cost_type, l_freight_du_basis, gn_process_flag, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , l_group_id);
            END IF;

            BEGIN
                SELECT list_price_per_unit
                  INTO l_price
                  FROM mtl_system_items_b msi
                 WHERE     1 = 1
                       AND msi.inventory_item_id = i.inventory_item_id
                       AND organization_id = i.organization_id;

                write_log_prc ('List Price Per Unit :' || l_price);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_price   := 1;
                    write_log_prc (
                        'Error while fetching list price of the item ');
            END;

            IF     (l_price = 0 OR l_price IS NULL)
               AND i.factory_cost IS NOT NULL
            THEN
                write_log_prc (
                       'updating list_price_per_unit for item - '
                    || i.inventory_item_id
                    || ' in org - '
                    || i.organization_id);
                api_index                                     := api_index + 1;

                l_item_tbl_typ (api_index).transaction_type   := 'UPDATE';
                l_item_tbl_typ (api_index).inventory_item_id   :=
                    i.inventory_item_id;
                l_item_tbl_typ (api_index).organization_id    :=
                    i.organization_id;
                l_item_tbl_typ (api_index).list_price_per_unit   :=
                    i.factory_cost;
            END IF;

            IF l_insert_count >= 2000
            THEN
                COMMIT;
                l_insert_count   := 0;

                update_item_price_prc (l_item_tbl_typ);
                api_index        := 0;
                l_item_tbl_typ.delete;
            END IF;


            EXIT WHEN oh_elements_cur%NOTFOUND;
        END LOOP;

        update_item_price_prc (l_item_tbl_typ);
        l_item_tbl_typ.delete;

        BEGIN
            UPDATE xxdo.xxd_cst_oh_elements_stg_t xcoest
               SET xcoest.rec_status   = 'I'
             WHERE     EXISTS
                           (SELECT 1
                              FROM cst_item_cst_dtls_interface cicdi
                             WHERE     1 = 1
                                   AND xcoest.inventory_item_id =
                                       cicdi.inventory_item_id
                                   AND NVL (pv_to_org,
                                            xcoest.organization_id) =
                                       cicdi.organization_id
                                   AND error_flag IS NULL
                                   AND process_flag = 1)
                   AND xcoest.rec_status = 'N'
                   AND xcoest.error_msg IS NULL
                   AND xcoest.request_id = gn_request_id;

            write_log_prc (
                SQL%ROWCOUNT || ' Records successfully Updated with status I');

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Exception Occured while updating status I to staging table:');
        END;


        BEGIN
            SELECT DISTINCT 'Y'
              INTO v_interfaced
              FROM xxdo.xxd_cst_oh_elements_stg_t
             WHERE EXISTS
                       (SELECT DISTINCT rec_status
                          FROM xxdo.xxd_cst_oh_elements_stg_t
                         WHERE     1 = 1
                               AND rec_status = 'I'
                               AND request_id = gn_request_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                       'Exception Occured while fetching v_interfaced:'
                    || SQLERRM);
                v_interfaced   := 'N';
        END;

        write_log_prc ('v_interfaced = ' || v_interfaced);
        write_log_prc ('group_id = ' || l_group_id);

        IF v_interfaced = 'Y'
        THEN
            write_log_prc (
                   'submitting Cost Import program for the Group ID: '
                || l_group_id);

            submit_cost_import_prc (p_errbuff, p_retcode, l_int_req_id,
                                    l_group_id);

            write_log_prc (
                   'updating interfcae status into staging table for the Group ID: '
                || l_group_id);

            update_interface_status_prc (pv_to_org, l_int_req_id, l_group_id);

            gn_int_request_id   := l_int_req_id;
        END IF;                                                -- v_interfaced

        write_log_prc (
               'Procedure insert_into_interface_prc Process Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN user_exception
        THEN
            write_log_prc ('Cost element not found');
            write_log_prc (
                'Error in Procedure insert_into_interface_prc:' || SQLERRM);
        --- retcode := 2;
        WHEN OTHERS
        THEN
            -- retcode := 2;
            write_log_prc (
                'Error in Procedure insert_into_interface_prc:' || SQLERRM);
    END insert_into_interface_prc;

      /***************************************************************************
-- PROCEDURE duty_ele_rep_send_mail_prc
-- PURPOSE: This Procedure sends duty element report to the PD Team
***************************************************************************/
    PROCEDURE duty_ele_rep_send_mail_prc (pv_rep_file_name IN VARCHAR2)
    IS
        lv_rep_file_name    VARCHAR2 (4000);
        lv_message          VARCHAR2 (4000);
        lv_directory_path   VARCHAR2 (100);
        lv_mail_delimiter   VARCHAR2 (1) := '/';
        lv_recipients       VARCHAR2 (1000);
        lv_ccrecipients     VARCHAR2 (1000);
        lv_result           VARCHAR2 (4000);
        lv_result_msg       VARCHAR2 (4000);
        lv_message1         VARCHAR2 (32000);
        lv_message2         VARCHAR2 (32000);
        lv_message3         VARCHAR2 (32000);

        CURSOR c_write_errors IS
              SELECT error_msg, COUNT (1) err_cnt
                FROM xxdo.xxd_cst_oh_elements_stg_t
               WHERE     rec_status = 'E'
                     AND error_msg IS NOT NULL
                     AND request_id = gn_request_id
            GROUP BY error_msg;
    BEGIN
        write_log_prc (
               'Procedure duty_ele_rep_send_mail_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_CST_DUTY_ELE_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        lv_rep_file_name   :=
            lv_directory_path || lv_mail_delimiter || pv_rep_file_name;
        write_log_prc (
            'Duty Elements Report File Name is - ' || lv_rep_file_name);

        lv_message2   :=
               CHR (10)
            || 'Distinct Error Messages :'
            || CHR (10)
            || '========================='
            || CHR (10)
            || 'Count'
            || CHR (9)
            || 'Error Message'
            || CHR (10)
            || '-----------------------------------------------------------------';

        FOR i IN c_write_errors
        LOOP
            lv_message3   :=
                CASE
                    WHEN lv_message3 IS NOT NULL
                    THEN
                           lv_message3
                        || CHR (10)
                        || i.err_cnt
                        || CHR (9)
                        || i.error_msg
                    ELSE
                        i.err_cnt || CHR (9) || i.error_msg
                END;
        END LOOP;

        lv_message3   := SUBSTR (lv_message3, 1, 30000);

        lv_message1   :=
               'Hello Team,'
            || CHR (10)
            || CHR (10)
            || 'Please Find the Attached Deckers OH Elements Copy Program Output. '
            || CHR (10)
            || CHR (10)
            || lv_message2
            || CHR (10)
            || lv_message3
            || CHR (10)
            || CHR (10)
            || 'Regards,'
            || CHR (10)
            || 'SYSADMIN.'
            || CHR (10)
            || CHR (10)
            || 'Note: This is auto generated mail, please donot reply.';

        SELECT LISTAGG (ffvl.description, ';') WITHIN GROUP (ORDER BY ffvl.description)
          INTO lv_recipients
          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND fvs.flex_value_set_id = ffvl.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXD_TRO_EMAIL_TO_PD_VS'
               AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                   TRUNC (SYSDATE)
               AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE)
               AND ffvl.enabled_flag = 'Y';

        xxdo_mail_pkg.send_mail (
            pv_sender         => 'erp@deckers.com',
            pv_recipients     => lv_recipients,
            pv_ccrecipients   => lv_ccrecipients,
            pv_subject        => 'Deckers OH Elements Copy Program',
            pv_message        => lv_message1,
            pv_attachments    => lv_rep_file_name,
            xv_result         => lv_result,
            xv_result_msg     => lv_result_msg);

        write_log_prc (lv_result);
        write_log_prc (lv_result_msg);
        write_log_prc (
               'Procedure duty_ele_rep_send_mail_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Error in Procedure duty_ele_rep_send_mail_prc:' || SQLERRM);
    END duty_ele_rep_send_mail_prc;

    /***************************************************************************
 -- PROCEDURE main_prc
 -- PURPOSE: This Procedure is Concurrent Program.
 ****************************************************************************/
    PROCEDURE main_prc (errbuf              OUT NOCOPY VARCHAR2,
                        retcode             OUT NOCOPY VARCHAR2,
                        pv_mode          IN            VARCHAR2,
                        pv_dummy         IN            VARCHAR2,
                        pv_from_org      IN            NUMBER,
                        pv_to_org        IN            NUMBER,
                        pv_duty_vs       IN            VARCHAR2, -- Added CCR0009885
                        pv_dummy1        IN            VARCHAR2,
                        pv_display_sku   IN            VARCHAR2)
    IS
        CURSOR c_write_errors IS
              SELECT error_msg, COUNT (1) err_cnt
                FROM xxdo.xxd_cst_oh_elements_stg_t
               WHERE     rec_status = 'E'
                     AND error_msg IS NOT NULL
                     AND request_id = gn_request_id
            GROUP BY error_msg;

        ln_stg_tot_rec   NUMBER := 0;
        ln_stg_suc_rec   NUMBER := 0;
        ln_stg_err_rec   NUMBER := 0;
        ln_int_tot_rec   NUMBER := 0;
        ln_int_suc_rec   NUMBER := 0;
        ln_int_err_rec   NUMBER := 0;
        lv_display_sku   VARCHAR2 (1);
    BEGIN
        write_log_prc (
               'Main Process Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        fnd_global.apps_initialize (fnd_global.user_id,             -- User Id
                                    fnd_global.resp_id,   -- Responsibility Id
                                    fnd_global.resp_appl_id); -- Application Id

        oh_ele_data_into_tbl_prc (pv_from_org, pv_duty_vs); -- Added CCR0009885

        IF pv_mode = 'Preview'
        THEN
            lv_display_sku   := NVL (pv_display_sku, 'N');
            write_log_prc (lv_display_sku);
            write_duty_ele_report_prc (lv_display_sku);
        END IF;

        IF pv_mode = 'Process'
        THEN
            insert_into_interface_prc (pv_from_org, pv_to_org);
        END IF;

        BEGIN
            SELECT COUNT (1)
              INTO ln_stg_tot_rec
              FROM xxdo.xxd_cst_oh_elements_stg_t
             WHERE request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_stg_tot_rec   := 0;
                write_log_prc (
                    'Exception Occurred while retriving the Stg Total Count');
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_stg_err_rec
              FROM xxdo.xxd_cst_oh_elements_stg_t
             WHERE     1 = 1
                   AND rec_status = 'E'
                   AND error_msg IS NOT NULL
                   AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_stg_err_rec   := 0;
                write_log_prc (
                    'Exception Occurred while retriving the Stg Error Count');
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_stg_suc_rec
              FROM xxdo.xxd_cst_oh_elements_stg_t
             WHERE     1 = 1
                   AND rec_status = 'P'
                   AND error_msg IS NULL
                   AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_stg_suc_rec   := 0;
                write_log_prc (
                    'Exception Occurred while retriving the Stg Success Count');
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_int_tot_rec
              FROM BOM.cst_item_cst_dtls_interface
             WHERE 1 = 1 AND request_id = gn_int_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_int_tot_rec   := 0;
                write_log_prc (
                    'Exception Occurred while retriving the Interface Total Count');
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_int_suc_rec
              FROM BOM.cst_item_cst_dtls_interface
             WHERE     1 = 1
                   AND request_id = gn_int_request_id
                   AND process_flag = 5
                   AND error_flag IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_int_suc_rec   := 0;
                write_log_prc (
                    'Exception Occurred while retriving the Interface Success Count');
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_int_err_rec
              FROM BOM.cst_item_cst_dtls_interface
             WHERE     1 = 1
                   AND request_id = gn_int_request_id
                   AND process_flag <> 5
                   AND error_flag IS NOT NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_int_err_rec   := 0;
                write_log_prc (
                    'Exception Occurred while retriving the Interface Error Count');
        END;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '                                                                      Deckers OH Elements Copy Program');
        apps.fnd_file.put_line (apps.fnd_file.output, '');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Date:' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        apps.fnd_file.put_line (apps.fnd_file.output, '');
        apps.fnd_file.put_line (apps.fnd_file.output, '');
        apps.fnd_file.put_line (apps.fnd_file.output, 'Parameters: ');
        apps.fnd_file.put_line (apps.fnd_file.output, '------------');
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Mode          : ' || pv_mode);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Copy Org From : ' || pv_from_org);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Copy Org TO   : ' || pv_to_org);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Display SKU   : ' || pv_display_sku);
        apps.fnd_file.put_line (apps.fnd_file.output, '');
        apps.fnd_file.put_line (apps.fnd_file.output, '');
        apps.fnd_file.put_line (apps.fnd_file.output, '');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '************************************************************************');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               ' Number of Rows Extracted into Inbound Staging Table - '
            || ln_stg_tot_rec);
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               ' Number of Rows Errored                              - '
            || ln_stg_err_rec);
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               ' Number of Rows Successful                           - '
            || ln_stg_suc_rec);
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '************************************************************************');
        apps.fnd_file.put_line (apps.fnd_file.output, '');
        apps.fnd_file.put_line (apps.fnd_file.output, '');
        apps.fnd_file.put_line (apps.fnd_file.output, '');

        IF pv_mode = 'Process'
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Inserted into Interface              - '
                || ln_int_tot_rec);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Errored                              - '
                || ln_int_err_rec);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Successful                           - '
                || ln_int_suc_rec);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
        END IF;

        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Distinct Error Messages :');
        apps.fnd_file.put_line (apps.fnd_file.output,
                                '=========================');
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Count' || CHR (9) || 'Error Message');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            '-----------------------------------------------------------------');

        FOR i IN c_write_errors
        LOOP
            apps.fnd_file.put_line (apps.fnd_file.output,
                                    i.err_cnt || CHR (9) || i.error_msg);
        END LOOP;

        IF pv_mode = 'Preview'
        THEN
            EXECUTE IMMEDIATE 'DELETE xxdo.xxd_cst_oh_elements_stg_t
												                    WHERE request_id = ' || gn_request_id;

            write_log_prc (
                   SQL%ROWCOUNT
                || ' Records Deleted for the Request--'
                || gn_request_id);
            COMMIT;
        END IF;

        write_log_prc (
               'Main Process Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := gn_error;
            write_log_prc (
                'Error Occured in Procedure main_prc: ' || SQLERRM);
    END main_prc;
END xxd_cst_oh_elements_copy_pkg;
/
