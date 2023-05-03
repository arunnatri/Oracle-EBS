--
-- XXD_SBX_O2C_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_SBX_O2C_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_SBX_O2C_INT_PKG
    * Design       : This package will be used as hook in the Sabix Tax determination package
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 27-JUL-2020  1.0        Deckers                 Initial Version
    -- 30-NOV-2020  2.0        Srinath Siricilla       CCR0009071
    -- 01-MAY-2021  3.0        Srinath Siricilla       CCR0009103
    -- 28-OCT-2021  3.1        Srinath Siricilla       CCR0009607
    -- 01-AUG-2022  3.2        Srinath Siricilla       CCR0009857
    ******************************************************************************************/

    g_debug_level   VARCHAR2 (50)
        := NVL (fnd_profile.VALUE ('SABRIX_DEBUG_LEVEL'), 'ABC');

    PROCEDURE debug_prc (p_batch_id NUMBER, p_procedure VARCHAR2, p_location VARCHAR2
                         , p_message VARCHAR2, p_severity VARCHAR2 DEFAULT 0)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF g_debug_level IS NOT NULL AND g_debug_level IN ('ALL', 'USER')
        THEN
            INSERT INTO sabrix_log (log_date, instance_name, batch_id,
                                    log_id, document_num, procedure_name,
                                    location, severity, MESSAGE,
                                    extended_message)
                 VALUES (SYSDATE, sabrix_log_pkg.g_instance_name, p_batch_id,
                         sabrix_log_id_seq.NEXTVAL, sabrix_log_pkg.g_invoice_number, p_procedure, p_location, p_severity, SUBSTR (p_message, 1, 4000)
                         , NULL);

            COMMIT;
        END IF;
    END debug_prc;

    -- Start of Change for CCR0009857

    FUNCTION get_tax_rate (pn_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_rate   NUMBER;
    BEGIN
        SELECT MAX (tax_rate)
          INTO ln_rate
          FROM apps.zx_lines_v
         WHERE 1 = 1 AND application_id = 222 AND trx_id = pn_trx_id;

        RETURN ln_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_rate   := 0;

            RETURN ln_rate;
    END get_tax_rate;

    -- End of Change for CCR0009857

    PROCEDURE update_header_prc (p_batch_id IN NUMBER, p_header_id IN NUMBER, p_user_element_attribute1 IN VARCHAR2:= NULL, p_user_element_attribute2 IN VARCHAR2:= NULL, p_user_element_attribute3 IN VARCHAR2:= NULL, p_user_element_attribute4 IN VARCHAR2:= NULL, p_user_element_attribute5 IN VARCHAR2:= NULL, p_user_element_attribute6 IN VARCHAR2:= NULL, p_user_element_attribute7 IN VARCHAR2:= NULL
                                 , p_user_element_attribute8 IN VARCHAR2:= NULL, p_user_element_attribute9 IN VARCHAR2:= NULL, p_user_element_attribute10 IN VARCHAR2:= NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        NULL;
        lv_location    := 'update_header_prc';
        lv_procedure   := 'update_header_prc';

        debug_prc (
            p_batch_id,
            'update_header_prc',
            'update_header_prc',
               'The values passed for Header Update are - attribute1 is - '
            || p_user_element_attribute1
            || ' - Attribute2 is - '
            || p_user_element_attribute2
            || ' - Attribute3 is - '
            || p_user_element_attribute3
            || ' - Attribute4 is - '
            || p_user_element_attribute4
            || ' - Attribute5 is - '
            || p_user_element_attribute5
            || ' - Attribute6 is - '
            || p_user_element_attribute6
            || ' - Attribute7 is - '
            || p_user_element_attribute7
            || ' - Attribute8 is - '
            || p_user_element_attribute8
            || ' - Attribute9 is - '
            || p_user_element_attribute9
            || ' - Attribute10 is - '
            || p_user_element_attribute10
            || ' - For Batch ID - '
            || p_batch_id
            || ' - Header ID is - '
            || p_header_id);


        UPDATE sabrix_invoice
           SET user_element_attribute1 = NVL (p_user_element_attribute1, user_element_attribute1), --lv_tax_class,
                                                                                                   user_element_attribute2 = NVL (p_user_element_attribute2, user_element_attribute2), user_element_attribute3 = NVL (p_user_element_attribute3, user_element_attribute3),
               user_element_attribute4 = NVL (p_user_element_attribute4, user_element_attribute4), user_element_attribute5 = NVL (p_user_element_attribute5, user_element_attribute5), user_element_attribute6 = NVL (p_user_element_attribute6, user_element_attribute6),
               user_element_attribute7 = NVL (p_user_element_attribute7, user_element_attribute7), user_element_attribute8 = NVL (p_user_element_attribute8, user_element_attribute8), user_element_attribute9 = NVL (p_user_element_attribute9, user_element_attribute9),
               user_element_attribute10 = NVL (p_user_element_attribute10, user_element_attribute10)
         WHERE     1 = 1
               AND batch_id = p_batch_id
               AND user_element_attribute41 = p_header_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_prc (p_batch_id, 'update_header_prc', 'update_header_prc',
                       'Error updating inv header' || SQLERRM);
    END update_header_prc;

    PROCEDURE update_line_prc (
        p_batch_id                   IN NUMBER,
        p_inv_id                     IN NUMBER,
        p_line_id                    IN NUMBER,
        p_user_element_attribute1    IN VARCHAR2 := NULL,
        p_user_element_attribute2    IN VARCHAR2 := NULL,
        p_user_element_attribute3    IN VARCHAR2 := NULL,
        p_user_element_attribute4    IN VARCHAR2 := NULL,
        p_user_element_attribute5    IN VARCHAR2 := NULL,
        p_user_element_attribute6    IN VARCHAR2 := NULL,
        p_user_element_attribute7    IN VARCHAR2 := NULL,
        p_user_element_attribute8    IN VARCHAR2 := NULL,
        p_user_element_attribute9    IN VARCHAR2 := NULL,
        p_user_element_attribute10   IN VARCHAR2 := NULL,
        p_transaction_type           IN VARCHAR2 := NULL,
        p_tax_determination_date     IN DATE := NULL,
        p_sf_country                 IN VARCHAR2 := NULL,
        p_product_code               IN VARCHAR2 := NULL,
        p_st_country                 IN VARCHAR2 := NULL,
        p_st_province                IN VARCHAR2 := NULL,
        p_sf_state                   IN VARCHAR2 := NULL,
        p_sf_district                IN VARCHAR2 := NULL,
        p_sf_province                IN VARCHAR2 := NULL,
        p_sf_postcode                IN VARCHAR2 := NULL,
        p_sf_city                    IN VARCHAR2 := NULL,
        p_sf_geocode                 IN VARCHAR2 := NULL,
        p_sf_county                  IN VARCHAR2 := NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        NULL;
        --lv_location := 'update_line_prc';
        --lv_procedure := 'update_line_prc';

        debug_prc (
            p_batch_id,
            'update_line_prc',
            'update_line_prc',
               'The values passed for Update are - attribute1 is - '
            || p_user_element_attribute1
            || ' - Attribute2 is - '
            || p_user_element_attribute2
            || ' - Attribute3 is - '
            || p_user_element_attribute3
            || ' - Attribute4 is - '
            || p_user_element_attribute4
            || ' - Attribute5 is - '
            || p_user_element_attribute5
            || ' - Attribute6 is - '
            || p_user_element_attribute6
            || ' - Attribute7 is - '
            || p_user_element_attribute7
            || ' - Attribute8 is - '
            || p_user_element_attribute8
            || ' - Attribute9 is - '
            || p_user_element_attribute9
            || ' - Attribute10 is - '
            || p_user_element_attribute10
            || ' - Trx Type is - '
            || p_transaction_type
            || ' - Tax Deter Date is - '
            || p_tax_determination_date
            || ' - sf country is - '
            || p_sf_country
            || ' - product code is - '
            || p_product_code
            || ' - st country is - '
            || p_st_country
            || ' - st province - '
            || p_st_province
            || ' - sf state is - '
            || p_sf_state
            || ' - sf district is - '
            || p_sf_district
            || ' - sf province is - '
            || p_sf_province
            || ' - sf postcode is - '
            || p_sf_postcode
            || ' - sf city is - '
            || p_sf_city
            || ' - sf geocode is - '
            || p_sf_geocode
            || ' - sf county is - '
            || p_sf_county
            || ' - For Invoice ID - '
            || p_inv_id
            || ' - Line ID is - '
            || p_line_id);


        UPDATE sabrix_line
           SET user_element_attribute1 = NVL (p_user_element_attribute1, user_element_attribute1), --lv_tax_class,
                                                                                                   user_element_attribute2 = NVL (p_user_element_attribute2, user_element_attribute2), user_element_attribute3 = NVL (p_user_element_attribute3, user_element_attribute3),
               user_element_attribute4 = NVL (p_user_element_attribute4, user_element_attribute4), user_element_attribute5 = NVL (p_user_element_attribute5, user_element_attribute5), user_element_attribute6 = NVL (p_user_element_attribute6, user_element_attribute6),
               user_element_attribute7 = NVL (p_user_element_attribute7, user_element_attribute7), user_element_attribute8 = NVL (p_user_element_attribute8, user_element_attribute8), user_element_attribute9 = NVL (p_user_element_attribute9, user_element_attribute9),
               user_element_attribute10 = NVL (p_user_element_attribute10, user_element_attribute10), transaction_type = NVL (p_transaction_type, transaction_type), tax_determination_date = NVL (p_tax_determination_date, tax_determination_date),
               sf_country = NVL (p_sf_country, sf_country), product_code = NVL (p_product_code, product_code), st_country = NVL (p_st_country, st_country),
               st_province = NVL (p_st_province, st_province), sf_state = NVL (p_sf_state, sf_state), sf_district = NVL (p_sf_district, sf_district),
               sf_province = NVL (p_sf_province, sf_province), sf_postcode = NVL (p_sf_postcode, sf_postcode), sf_city = NVL (p_sf_city, sf_city),
               sf_geocode = NVL (p_sf_geocode, sf_geocode), sf_county = NVL (p_sf_county, sf_county)
         WHERE     1 = 1
               AND batch_id = p_batch_id
               AND invoice_id = p_inv_id
               AND user_element_attribute41 = p_line_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_prc (p_batch_id, 'update_line_prc', 'update_line_prc',
                       'Error updating inv' || SQLERRM);
    END update_line_prc;

    PROCEDURE update_inv_prc (p_batch_id IN NUMBER, p_inv_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lv_db_name   VARCHAR2 (10);
    BEGIN
        lv_db_name   := NULL;

        -- lv_location := 'update_inv';
        --lv_procedure := 'update_inv_prc';

        BEGIN
            SELECT name INTO lv_db_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_db_name   := 'NONPROD';
        END;


        debug_prc (p_batch_id, 'update_inv', 'update_inv_prc',
                   'upd start with db as - ' || lv_db_name);

        UPDATE sabrix_invoice
           SET (username, password)     =
                   (SELECT flvv.description username, flvv.tag pwd
                      FROM fnd_lookup_values_vl flvv
                     WHERE     flvv.lookup_type = 'XXD_AR_SBX_CONN_DTLS_LKP'
                           AND flvv.lookup_code =
                               DECODE (lv_db_name,
                                       'EBSPROD', 'EBSPROD',
                                       'NONPROD')
                           AND flvv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flvv.start_date_active,
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           flvv.end_date_active,
                                                           TRUNC (SYSDATE))), --      UPDATE sabrix_invoice
               user_element_attribute1   = p_inv_id
         WHERE batch_id = p_batch_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_prc (p_batch_id, 'update_inv', 'update_inv_prc',
                       'Error updating inv' || SQLERRM);
    END update_inv_prc;

    -- Start of Change for CCR0009857

    PROCEDURE get_trxn_due_amt (p_header_id IN VARCHAR2, p_org_id IN NUMBER, x_trx_due OUT NUMBER
                                , x_ret_msg OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        SELECT SUM (amount)
          INTO x_trx_due
          FROM apps.ra_interface_lines_all
         WHERE     1 = 1
               AND interface_line_attribute1 = p_header_id
               AND org_id = p_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_trx_due   := NULL;
            x_ret_msg   := SUBSTR (SQLERRM, 1, 200);
    END get_trxn_due_amt;

    -- End of Change for CCR0009857

    FUNCTION check_ge_order (pv_ship_method_code IN VARCHAR2, pn_header_id IN NUMBER, pn_org_id IN NUMBER
                             , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_ship_code   VARCHAR2 (100);
    BEGIN
        lv_ship_code   := NULL;
        x_ret_msg      := NULL;

        IF pn_header_id IS NULL AND pv_ship_method_code IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.flex_value
                  INTO lv_ship_code
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     ffvs.flex_value_set_name =
                           'XXD_AR_CONS_GE_SHIP_MET_VS'
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.value_category =
                           'XXD_GLOBALE_TAX_CODE_MAPPING'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND NVL (ffvl.end_date_active,
                                                SYSDATE)
                       AND ffvl.flex_value = pv_ship_method_code
                       AND ffvl.attribute1 = pn_org_id;

                RETURN TRUE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_code   := NULL;
                    x_ret_msg      := SUBSTR (SQLERRM, 1, 200);
                    RETURN FALSE;
            END;
        ELSIF pn_header_id IS NOT NULL AND pv_ship_method_code IS NULL
        THEN
            BEGIN
                SELECT ffvl.flex_value
                  INTO lv_ship_code
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl, apps.oe_order_headers_all ooha
                 WHERE     ffvs.flex_value_set_name =
                           'XXD_AR_CONS_GE_SHIP_MET_VS'
                       AND ffvl.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND NVL (ffvl.end_date_active,
                                                SYSDATE)
                       AND ffvl.flex_value = ooha.shipping_method_code
                       AND ffvl.value_category =
                           'XXD_GLOBALE_TAX_CODE_MAPPING'
                       AND ooha.header_id = pn_header_id
                       AND ffvl.attribute1 = TO_CHAR (pn_org_id);

                RETURN TRUE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_code   := NULL;
                    x_ret_msg      := SUBSTR (SQLERRM, 1, 200);
                    RETURN FALSE;
            END;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END;

    PROCEDURE xxd_ont_sbx_pre_calc_prc (p_batch_id IN NUMBER)
    IS
        --PRAGMA AUTONOMOUS_TRANSACTION;
        CURSOR cur_om_hdr_data IS
            SELECT sbx_inv.batch_id, sbx_inv.invoice_id, sbx_inv.user_element_attribute41
              FROM sabrix_invoice sbx_inv
             WHERE     1 = 1
                   AND sbx_inv.calling_system_number = '660'
                   AND sbx_inv.batch_id = p_batch_id;

        CURSOR cur_om_line_data (pn_batch_id     IN NUMBER,
                                 pn_invoice_id   IN NUMBER)
        IS
            SELECT sbx_line.*
              FROM sabrix_line sbx_line
             WHERE     1 = 1
                   AND sbx_line.invoice_id = pn_invoice_id
                   AND sbx_line.batch_id = p_batch_id;

        lv_ex_msg                VARCHAR2 (4000);
        ln_inv_item_id           mtl_system_items_b.inventory_item_id%TYPE;
        ln_ship_org_id           mtl_system_items_b.organization_id%TYPE;
        ln_drop_site_id          NUMBER;
        lv_drop_country          VARCHAR2 (100);
        lv_tax_class             VARCHAR2 (100);
        l_ecom_boolean           BOOLEAN;
        ln_org_id                NUMBER;
        ln_line_id               NUMBER;
        ln_line_cat_code         VARCHAR2 (100);
        --ln_ref_line_id           NUMBER;
        ln_sold_to_org_id        NUMBER;
        lv_ordered_item          VARCHAR2 (100);
        lv_src_ordered_item      VARCHAR2 (100);
        ln_warehouse_id          NUMBER;
        lv_trx_number            VARCHAR2 (100);
        ld_trx_date              DATE;
        lv_org_loc               VARCHAR2 (100);
        lv_drop_ship_flag        VARCHAR2 (1) := 'N';
        ln_drop_ship_cnt         NUMBER;
        l_ship_add_boolean       BOOLEAN;
        lv_st_country            VARCHAR2 (100);
        lv_st_province           VARCHAR2 (100);
        lv_return_flag           VARCHAR2 (1);
        ln_ship_to_site_use_id   NUMBER;
        ln_cust_account_id       NUMBER;
        lv_ont_trx_number        VARCHAR2 (100);
        ln_hdr_sold_to_org_id    NUMBER;
        ln_invoice_to_org_id     NUMBER;
        ln_ship_to_org_id        NUMBER;           --- Added as per CCR0009607
        lv_tax_ref               VARCHAR2 (100);
        lv_hdr_cat_code          VARCHAR2 (100);
        lv_trx_type_code         VARCHAR2 (100);
        lb_ship_boolean          BOOLEAN;
        lv_ship_method_code      VARCHAR2 (100);
        lv_final_ship_code       VARCHAR2 (100);
        ln_order_source_id       NUMBER;
        lv_hdr_adj_flag          VARCHAR2 (1);
        lv_line_adj_flag         VARCHAR2 (1);
        lv_ret_msg               VARCHAR2 (4000);
        ln_orig_header_id        NUMBER;
    BEGIN
        lv_procedure   := 'XXD_ONT_SBX_PRE_CALC_PRC';
        lv_location    := 'First Entry Point into OM';
        lv_ret_msg     := NULL;

        debug_prc (
            p_batch_id,
            lv_procedure,
            lv_location,
            'Start of Data flow for OM with batch id - ' || p_batch_id);

        FOR om_hdr IN cur_om_hdr_data
        LOOP
            lv_location             := 'OM Header Loop';
            ln_org_id               := NULL;
            l_ecom_boolean          := NULL;
            ln_inv_item_id          := NULL;
            lv_ordered_item         := NULL;
            ln_ship_org_id          := NULL;
            ln_hdr_sold_to_org_id   := NULL;
            ln_invoice_to_org_id    := NULL;
            ln_ship_to_org_id       := NULL;        -- Added as per CCR0009607
            lv_tax_ref              := NULL;
            lv_hdr_cat_code         := NULL;
            lv_trx_type_code        := NULL;
            lv_ex_msg               := NULL;
            lb_ship_boolean         := NULL;
            lv_ship_method_code     := NULL;
            lv_final_ship_code      := NULL;
            lv_hdr_adj_flag         := NULL;
            lv_line_adj_flag        := NULL;
            ln_orig_header_id       := NULL;

            update_inv_prc (p_batch_id, om_hdr.user_element_attribute41);

            BEGIN
                SELECT ooha.sold_to_org_id, ooha.invoice_to_org_id, ooha.ship_to_org_id, --- Added as per CCR0009607
                       ooha.order_category_code, otta.name, org_id,
                       shipping_method_code
                  INTO ln_hdr_sold_to_org_id, ln_invoice_to_org_id, ln_ship_to_org_id, -- Added as per CCR0009607
                                                                                       lv_hdr_cat_code,
                                            lv_trx_type_code, ln_org_id, lv_ship_method_code
                  FROM oe_order_headers_all ooha, apps.oe_transaction_types_tl otta
                 WHERE     ooha.header_id = om_hdr.user_element_attribute41
                       AND otta.transaction_type_id = ooha.order_type_id
                       AND otta.language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_hdr_sold_to_org_id   := NULL;
                    ln_invoice_to_org_id    := NULL;
                    ln_ship_to_org_id       := NULL; -- Added as per CCR0009607
                    lv_hdr_cat_code         := NULL;
                    lv_trx_type_code        := NULL;
                    ln_org_id               := NULL;
                    lv_ship_method_code     := NULL;
                    lv_ex_msg               := SUBSTR (SQLERRM, 1, 200);
            -- debug_prc with Error Code 10.
            END;

            debug_prc (
                p_batch_id,
                lv_procedure,
                lv_location,
                   ' Sold to Org Id is - '
                || ln_hdr_sold_to_org_id
                || ' ln_invoice_to_org_id is - '
                || ln_invoice_to_org_id
                || ' ln_ship_to_org_id is - '
                || ln_ship_to_org_id
                || ' Sold to Org Id is - '
                || ln_hdr_sold_to_org_id
                || ' lv_hdr_cat_code is - '
                || lv_hdr_cat_code
                || ' lv_trx_type_code is - '
                || lv_trx_type_code
                || ' Org ID is - '
                || ln_org_id
                || ' Shipping Method Code is - '
                || lv_ship_method_code
                || ' For Order Header ID  - '
                || om_hdr.user_element_attribute41
                || ' Exception Msg if exists is - '
                || lv_ex_msg);

            -- Get the Tax Registration Number

            lv_location             := 'OM Header Loop - Tax Reg.';

            -- Added as per CCR0009607

            BEGIN
                SELECT custaccountsiteeo.tax_reference
                  INTO lv_tax_ref
                  FROM hz_cust_site_uses_all custaccountsiteeo
                 WHERE     1 = 1
                       AND custaccountsiteeo.site_use_id = ln_ship_to_org_id;

                debug_prc (
                    p_batch_id,
                    lv_procedure,
                    lv_location,
                       'Sabrix Reg. Number found is  - '
                    || lv_tax_ref
                    || ' - for cust account id - '
                    || ln_hdr_sold_to_org_id
                    || ' - With Ship to Site use id is  - '
                    || ln_ship_to_org_id);
            -- End of Change for CCR0009607

            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_tax_ref   := NULL;
                    lv_ex_msg    := SUBSTR (SQLERRM, 1, 200);

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Exception found for cust account id - '
                        || ln_hdr_sold_to_org_id
                        || ' - With ship to Site use id is  - '
                        || ln_ship_to_org_id
                        || ' - Exception Msg is - '
                        || lv_ex_msg);
            END;

            IF lv_tax_ref IS NULL
            THEN
                BEGIN
                    SELECT custaccountsiteeo.tax_reference
                      INTO lv_tax_ref
                      FROM hz_cust_site_uses_all custaccountsiteeo
                     WHERE     1 = 1
                           AND custaccountsiteeo.site_use_id =
                               ln_invoice_to_org_id;

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Sabrix Reg. Number found is  - '
                        || lv_tax_ref
                        || ' - for cust account id - '
                        || ln_hdr_sold_to_org_id
                        || ' - With Bill to Site use id is  - '
                        || ln_invoice_to_org_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_tax_ref   := NULL;
                        lv_ex_msg    := SUBSTR (SQLERRM, 1, 200);

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'Exception found for cust account id - '
                            || ln_hdr_sold_to_org_id
                            || ' - With Bill to Site use id is  - '
                            || ln_invoice_to_org_id
                            || ' - Exception Msg is - '
                            || lv_ex_msg);
                END;
            END IF;


            IF lv_tax_ref IS NOT NULL
            THEN
                lv_ex_msg   := NULL;
                lv_location   :=
                    'Inside OM Header Loop when Tax Ref is Found';

                BEGIN
                    INSERT INTO Sabrix_Registration (batch_id,
                                                     creation_date,
                                                     invoice_id,
                                                     line_id,
                                                     merchant_role,
                                                     registration_number)
                         VALUES (om_hdr.batch_id, SYSDATE, om_hdr.invoice_id,
                                 -1, 'B', lv_tax_ref);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                        lv_ex_msg   := SUBSTR (SQLERRM, 1, 200);
                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' Insert Stmt for Sabrix Reg is failed with msg  - '
                            || lv_ex_msg);
                END;

                debug_prc (p_batch_id, lv_procedure, lv_location,
                           ' Sabrix Reg is complete - ');
            END IF;

            -- For GE Return orders, Shippin Method code is NULL, Check if Original Order is GE

            lv_ret_msg              := NULL;
            lv_procedure            := 'check_orig_order_return';
            lv_location             := 'check_orig_order_return';
            lb_ship_boolean         := NULL;

            IF lv_hdr_cat_code = 'RETURN'
            THEN
                BEGIN
                    SELECT DISTINCT reference_header_id
                      INTO ln_orig_header_id
                      FROM oe_order_lines_all
                     WHERE header_id = om_hdr.user_element_attribute41;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_orig_header_id   := NULL;
                        lv_ret_msg          := SUBSTR (SQLERRM, 1, 2000);
                END;
            END IF;

            debug_prc (
                p_batch_id,
                lv_procedure,
                lv_location,
                   'Orginal Order header is  - '
                || ln_orig_header_id
                || ' - for header_id  - '
                || om_hdr.user_element_attribute41
                || ' - Exception Msg if exists is  - '
                || lv_ret_msg);


            lv_ret_msg              := NULL;
            lv_procedure            := 'check_ge_order';
            lv_location             := 'check_ge_order';
            lb_ship_boolean         := NULL;

            IF lv_hdr_cat_code = 'RETURN'
            THEN
                --lv_ship_method_code := NULL;
                lb_ship_boolean   :=
                    check_ge_order (pv_ship_method_code => NULL, pn_header_id => ln_orig_header_id, pn_org_id => ln_org_id
                                    , x_ret_msg => lv_ret_msg);

                IF lb_ship_boolean = TRUE
                THEN
                    lv_ret_msg            := NULL;
                    lv_ship_method_code   := NULL;

                    BEGIN
                        SELECT DISTINCT shipping_method_code
                          INTO lv_ship_method_code
                          FROM oe_order_headers_all
                         WHERE     header_id = ln_orig_header_id
                               AND org_id = ln_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_ship_method_code   := NULL;
                            lv_ret_msg            := SUBSTR (SQLERRM, 1, 200);
                    END;

                    IF lb_ship_boolean = TRUE
                    THEN
                        lv_final_ship_code   := lv_ship_method_code;
                    ELSE
                        lv_final_ship_code   := NULL;
                    END IF;
                END IF;
            ELSE
                lb_ship_boolean   :=
                    check_ge_order (pv_ship_method_code => lv_ship_method_code, pn_header_id => NULL, pn_org_id => ln_org_id
                                    , x_ret_msg => lv_ret_msg);

                IF lb_ship_boolean = TRUE
                THEN
                    lv_final_ship_code   := lv_ship_method_code;
                ELSE
                    lv_final_ship_code   := NULL;
                END IF;
            END IF;



            debug_prc (
                p_batch_id,
                lv_procedure,
                lv_location,
                   'Ship Method Code is  - '
                || lv_ship_method_code
                || ' - for ln_org_id  - '
                || ln_org_id
                || ' - Exception Msg if exists is  - '
                || lv_ret_msg);


            /*debug_prc (
               p_batch_id,
               'Calling Update Header Prc',
               'Update_header_prc',
                  'Values Passed are p_user_element_attribute1- '
               || lv_trx_type_code
               || ' - for p_user_element_attribute2  - '
               || lv_hdr_cat_code
               || ' - for p_user_element_attribute4  - '
               || lv_final_ship_code
               || ' - for Header ID  - '
               || om_hdr.user_element_attribute41
               || ' - for batch_id  - '
               || om_hdr.batch_id);*/



            update_header_prc (
                p_batch_id                  => om_hdr.batch_id,
                p_header_id                 => om_hdr.user_element_attribute41,
                p_user_element_attribute1   => lv_trx_type_code,
                p_user_element_attribute2   => lv_hdr_cat_code,
                p_user_element_attribute4   => lv_final_ship_code);

            lv_ret_msg              := NULL;
            l_ecom_boolean          :=
                check_ecom_org_fnc (ln_org_id, lv_ret_msg);

            debug_prc (
                p_batch_id,
                'Checking eCom Boolean',
                'check_ecom_org_fnc',
                   'For Org id  - '
                || ln_org_id
                || ' - Exception Msg if exists is  - '
                || lv_ret_msg);

            FOR om_line
                IN cur_om_line_data (om_hdr.batch_id, om_hdr.invoice_id)
            LOOP
                ln_inv_item_id           := NULL;
                lv_ordered_item          := NULL;
                ln_ship_org_id           := NULL;
                lv_ex_msg                := NULL;
                lv_tax_class             := NULL;
                ln_drop_site_id          := NULL;
                lv_drop_country          := NULL;
                lv_drop_ship_flag        := 'N';
                ln_drop_ship_cnt         := 0;
                l_ship_add_boolean       := NULL;
                ln_line_cat_code         := NULL;
                --ln_ref_line_id := NULL;
                ln_sold_to_org_id        := NULL;
                lv_src_ordered_item      := NULL;
                lv_st_country            := NULL;
                lv_st_province           := NULL;
                lv_return_flag           := 'N';
                ln_ship_to_site_use_id   := NULL;
                ln_cust_account_id       := NULL;
                ln_warehouse_id          := NULL;
                lv_trx_number            := NULL;
                ld_trx_date              := NULL;
                lv_ont_trx_number        := NULL;
                ln_order_source_id       := NULL;
                lv_hdr_adj_flag          := NULL;
                lv_line_adj_flag         := NULL;
                lv_ret_msg               := NULL;
                ln_line_id               := NULL;


                lv_location              := 'Get Order Line Details ';

                -- Get the details and check if the order is RETURN OF NOT

                -- Find whether the line is return or not and should not be a eComm

                BEGIN
                    lv_ex_msg   := NULL;

                    SELECT inventory_item_id,
                           ship_from_org_id,
                           SUBSTR (ordered_item,
                                   1,
                                     INSTR (ordered_item, '-', 1,
                                            2)
                                   - 1),
                           line_category_code,
                           --reference_line_id,
                           sold_to_org_id,
                           ordered_item,
                           order_source_id
                      INTO ln_inv_item_id, ln_ship_org_id, lv_src_ordered_item, ln_line_cat_code,
                                         --ln_ref_line_id,
                                         ln_sold_to_org_id, lv_ordered_item, ln_order_source_id
                      FROM oe_order_lines_all
                     WHERE     header_id = om_hdr.user_element_attribute41
                           AND line_id = om_line.user_element_attribute41;

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Derived Inventory item ID - '
                        || ln_inv_item_id
                        || ' - With Ship from Org ID - '
                        || ln_ship_org_id
                        || ' - With Src Order Item is - '
                        || lv_src_ordered_item
                        || ' - With Order Source ID - '
                        || ln_order_source_id
                        || ' - line_category_code is - '
                        || ln_line_cat_code
                        --|| ' - for ln_ref_line_id - '
                        --|| ln_ref_line_id
                        || ' - for ln_sold_to_org_id - '
                        || ln_sold_to_org_id
                        || ' - for lv_ordered_item - '
                        || lv_ordered_item);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_inv_item_id        := NULL;
                        ln_ship_org_id        := NULL;
                        lv_src_ordered_item   := NULL;
                        ln_line_cat_code      := NULL;
                        --ln_ref_line_id := NULL;
                        ln_sold_to_org_id     := NULL;
                        lv_ordered_item       := NULL;
                        ln_order_source_id    := NULL;
                        lv_ex_msg             := SUBSTR (SQLERRM, 1, 200);

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' Seems like this is not a order line, so going to Price Adj. to get details for Sabrix line - '
                            || om_line.user_element_attribute41
                            || ' - and Exception Message is - '
                            || lv_ex_msg);

                        -- Check if Sabrix line has Header Level Freight Charges

                        lv_location           := 'Price Adjustments Header';

                        BEGIN
                            ln_order_source_id   := NULL;
                            ln_sold_to_org_id    := NULL;
                            lv_ex_msg            := NULL;

                            SELECT ooha.order_source_id, ooha.sold_to_org_id
                              INTO ln_order_source_id, ln_sold_to_org_id
                              FROM apps.oe_price_adjustments_v opa, apps.oe_order_headers_all ooha
                             WHERE     opa.header_id = ooha.header_id
                                   AND opa.line_id IS NULL
                                   AND opa.price_adjustment_id =
                                       om_line.user_element_attribute41
                                   AND opa.list_line_type_code =
                                       'FREIGHT_CHARGE';

                            lv_hdr_adj_flag      := 'Y';
                            lv_line_adj_flag     := NULL;
                            lv_tax_class         := 9002;

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Adjustment at the Header level - '
                                || om_line.user_element_attribute41
                                || ' - and order Source id - '
                                || ln_order_source_id
                                || ' Tax Class is Hard Coded as it is Header level Freight Adj'
                                || ' and lv_hdr_adj_flag is - '
                                || lv_hdr_adj_flag
                                || ' and lv_line_adj_flag is - '
                                || lv_line_adj_flag);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                -- Check the Sabrix line price ajsutment id at the line level

                                BEGIN
                                    SELECT inventory_item_id,
                                           ship_from_org_id,
                                           SUBSTR (ordered_item,
                                                   1,
                                                     INSTR (ordered_item, '-', 1
                                                            , 2)
                                                   - 1),
                                           line_category_code,
                                           --reference_line_id,
                                           sold_to_org_id,
                                           ordered_item,
                                           order_source_id
                                      INTO ln_inv_item_id, ln_ship_org_id, lv_src_ordered_item, ln_line_cat_code,
                                                         --ln_ref_line_id,
                                                         ln_sold_to_org_id, lv_ordered_item, ln_order_source_id
                                      FROM oe_order_lines_all oola, oe_price_adjustments_v opa
                                     WHERE     oola.header_id =
                                               om_hdr.user_element_attribute41
                                           AND opa.price_adjustment_id =
                                               om_line.user_element_attribute41
                                           AND opa.list_line_type_code =
                                               'FREIGHT_CHARGE'
                                           AND opa.header_id = oola.header_id
                                           AND opa.line_id = oola.line_id;

                                    lv_hdr_adj_flag    := NULL;
                                    lv_line_adj_flag   := 'Y';

                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           'Derived Freight Adj Line Inventory item ID - '
                                        || ln_inv_item_id
                                        || ' - With Ship from Org ID - '
                                        || ln_ship_org_id
                                        || ' - With Src Order Item is - '
                                        || lv_src_ordered_item
                                        || ' - With Order Source ID - '
                                        || ln_order_source_id
                                        || ' - line_category_code is - '
                                        || ln_line_cat_code
                                        --|| ' - for ln_ref_line_id - '
                                        --|| ln_ref_line_id
                                        || ' - for ln_sold_to_org_id - '
                                        || ln_sold_to_org_id
                                        || ' - for lv_ordered_item - '
                                        || lv_ordered_item
                                        || ' and lv_hdr_adj_flag is - '
                                        || lv_hdr_adj_flag
                                        || ' and lv_line_adj_flag is - '
                                        || lv_line_adj_flag);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_inv_item_id        := NULL;
                                        ln_ship_org_id        := NULL;
                                        lv_src_ordered_item   := NULL;
                                        ln_line_cat_code      := NULL;
                                        --ln_ref_line_id := NULL;
                                        ln_sold_to_org_id     := NULL;
                                        lv_ordered_item       := NULL;
                                        ln_order_source_id    := NULL;
                                        lv_ex_msg             :=
                                            SUBSTR (SQLERRM, 1, 200);

                                        debug_prc (
                                            p_batch_id,
                                            lv_procedure,
                                            lv_location,
                                               ' Seems like this is not a order or Adj line, for Sabrix line - '
                                            || om_line.user_element_attribute41
                                            || ' - and Exception Message is - '
                                            || lv_ex_msg);
                                END;
                        END;
                END;

                lv_location              := ' Validate Order Line Details ';

                IF ln_order_source_id IS NULL --ln_inv_item_id IS NULL OR ln_ship_org_id IS NULL
                THEN
                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Please check the details for the line - '
                        || om_line.user_element_attribute41
                        || ' Check if this other than Header and Price Adjustment '
                        || ' - With Exceptin Msg - '
                        || lv_ex_msg);
                ELSIF     ln_inv_item_id IS NOT NULL
                      AND ln_ship_org_id IS NOT NULL
                THEN
                    lv_location   := 'Tax Class';
                    lv_ret_msg    := NULL;
                    lv_tax_class   :=
                        get_item_tax_class_fnc (
                            pn_inv_item_id    => ln_inv_item_id,
                            pn_warehouse_id   => ln_ship_org_id,
                            x_ret_msg         => lv_ret_msg);
                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Tax class derived is - '
                        || lv_tax_class
                        || ' - for Inventory item ID  - '
                        || ln_inv_item_id
                        || ' - and Ship from Org ID - '
                        || ln_ship_org_id
                        || ' and Exception if exists is - '
                        || lv_ret_msg);
                END IF;


                IF NVL (ln_line_cat_code, 'ABC') <> 'RETURN'
                THEN
                    lv_location   := 'Drop Ship Check';

                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_drop_ship_cnt
                          FROM oe_order_lines_all oola
                         WHERE     header_id =
                                   om_hdr.user_element_attribute41
                               AND line_id = om_line.user_element_attribute41
                               AND source_type_code = 'EXTERNAL'; -- Check if we can add more conditions to identify the drop ship order
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_drop_ship_cnt   := 0;
                    END;

                    IF ln_drop_ship_cnt > 0
                    THEN
                        lv_drop_ship_flag   := 'Y';
                    END IF;

                    -- If drop ship flag is Yes, then fetch the vendor site id details

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Drop Ship Flag derived is  - '
                        || lv_drop_ship_flag
                        || ' - having drop ship count - '
                        || ln_drop_ship_cnt
                        || ' - for SO header id - '
                        || om_hdr.user_element_attribute41
                        || ' - for line id - '
                        || om_line.user_element_attribute41);


                    IF lv_drop_ship_flag = 'Y'
                    THEN
                        lv_ex_msg     := NULL;

                        BEGIN
                            SELECT source_org.vendor_site_id
                              INTO ln_drop_site_id
                              FROM apps.mrp_sr_source_org source_org, apps.mrp_sr_receipt_org receipt_org, apps.mrp_sr_assignments_v msa,
                                   apps.mrp_sourcing_rules mrs
                             WHERE     1 = 1
                                   AND receipt_org.sourcing_rule_id(+) =
                                       msa.sourcing_rule_id
                                   AND SYSDATE BETWEEN NVL (
                                                           receipt_org.effective_date,
                                                           SYSDATE - 1)
                                                   AND NVL (
                                                           receipt_org.disable_date,
                                                           SYSDATE + 1)
                                   AND source_org.sr_receipt_id(+) =
                                       receipt_org.sr_receipt_id
                                   AND source_org.source_organization_id
                                           IS NULL
                                   AND mrs.sourcing_rule_id =
                                       msa.sourcing_rule_id
                                   --AND mrs.sourcing_rule_name like '1017419-BDOLV%'
                                   AND SUBSTR (mrs.sourcing_rule_name,
                                               1,
                                                 INSTR (mrs.sourcing_rule_name, '-', 1
                                                        , 2)
                                               - 1) = lv_src_ordered_item
                                   AND msa.organization_id = ln_ship_org_id --
                                   AND msa.assignment_set_id --= 3002; -- Check assignment set id
                                                             IN
                                           (SELECT fopl.profile_option_value
                                              FROM fnd_profile_options fop, fnd_profile_option_values fopl
                                             WHERE     1 = 1
                                                   AND fop.profile_option_name LIKE
                                                           'MRP_DEFAULT_ASSIGNMENT_SET%'
                                                   AND fop.profile_option_id =
                                                       fopl.profile_option_id);

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Drop Site ID   - '
                                || ln_drop_site_id
                                || ' - for Style Color - '
                                || lv_src_ordered_item
                                || ' - for Organization ID - '
                                || ln_ship_org_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_drop_site_id   := NULL;
                                lv_ex_msg         := SUBSTR (SQLERRM, 1, 200);

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Exception Msg for Drop Site ID   - '
                                    || ln_drop_site_id
                                    || ' - for Style Color - '
                                    || lv_ordered_item
                                    || ' - for Organization ID - '
                                    || ln_ship_org_id
                                    || ' - msg is - '
                                    || lv_ex_msg);
                        END;

                        lv_location   := 'Drop Ship Function';
                        lv_ex_msg     := NULL;

                        IF ln_drop_site_id IS NOT NULL
                        THEN
                            BEGIN
                                BEGIN
                                    SELECT hl.country
                                      INTO lv_drop_country
                                      --fvl.territory_short_name
                                      FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.ap_supplier_sites_all apsa
                                     WHERE     apsa.party_site_id =
                                               hps.party_site_id
                                           AND hl.location_id =
                                               hps.location_id
                                           AND apsa.vendor_site_id =
                                               ln_drop_site_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_drop_country   := NULL;
                                        lv_ex_msg         :=
                                            SUBSTR (SQLERRM, 1, 200);
                                        debug_prc (
                                            p_batch_id,
                                            lv_procedure,
                                            lv_location,
                                               'Please check the country assocaited with the Site ID - '
                                            || ln_drop_site_id
                                            || ' - With Exceptin Msg - '
                                            || lv_ex_msg,
                                            10);
                                END;
                            END;
                        END IF;
                    END IF;
                END IF;

                -- This is applicable to all eComm and WholeSales Orders

                IF lv_drop_ship_flag = 'N' --AND l_ecom_boolean = FALSE  -- Change as part of CCR0009071
                THEN
                    IF     NVL (NVL (lv_hdr_cat_code, ln_line_cat_code),
                                'ABC') =
                           'RETURN'
                       --AND ln_ref_line_id IS NULL -- Change as part of CCR0009071
                       AND NVL (lv_hdr_adj_flag, 'N') = 'N'
                       AND NVL (lv_line_adj_flag, 'N') = 'N'
                    THEN
                        lv_return_flag   := 'Y';
                        ln_line_id       := NULL;
                        lv_location      :=
                            'RETURN Order without Header and Line Adj';
                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'RETURN Order with NO price adj for order line id - '
                            || om_line.user_element_attribute41);

                        -- Get the similar order, like same customer, Same Order Item ID, same OU, Same Ship from Org ID OU

                        BEGIN
                            lv_ex_msg   := NULL;

                            --lv_return_flag := 'Y'; Not placing here, making sure we have some value in it

                            SELECT line_id
                              INTO ln_line_id
                              FROM (  SELECT line_id
                                        FROM oe_order_lines_all oola
                                       WHERE     1 = 1
                                             AND oola.sold_to_org_id =
                                                 ln_sold_to_org_id
                                             AND oola.inventory_item_id =
                                                 ln_inv_item_id
                                             AND oola.ship_from_org_id =
                                                 ln_ship_org_id -- Added as per CCR0009071
                                             AND oola.org_id = ln_org_id
                                             AND oola.cancelled_flag <> 'Y'
                                             AND oola.flow_status_code =
                                                 'CLOSED'
                                             AND oola.line_category_code <>
                                                 'RETURN'
                                             AND EXISTS
                                                     (SELECT 1
                                                        FROM ra_customer_trx_lines_all rctla
                                                       WHERE     rctla.interface_line_attribute6 =
                                                                 TO_CHAR (
                                                                     oola.line_id) -- used again
                                                             --AND  rctla.bill_to_customer_id = oola.sold_to_org_id
                                                             AND NVL (
                                                                     rctla.interface_line_attribute11,
                                                                     0) =
                                                                 0 -- Condition to exclude discount lines
                                                             AND rctla.inventory_item_id =
                                                                 oola.inventory_item_id)
                                    ORDER BY oola.actual_shipment_date DESC)
                             WHERE ROWNUM = 1;

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Derived the latest order line id for Same OU, Customer, Item and Inv Org as ln_line_id is - '
                                || ln_line_id);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_line_id   := NULL;
                                lv_ex_msg    := SUBSTR (SQLERRM, 1, 200);
                                lv_location   :=
                                    'Same OU, Same Customer, Same Item, Same Inv Org not Found without ADJ';

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Exception occurred as Same OU, Customer, Item and Inv Org not available WO ADJ - '
                                    || lv_ex_msg
                                    || ' So Derive value Excluding the Ship to Org Info');

                                -- Start of Change for CCR0009071
                                BEGIN
                                    SELECT line_id
                                      INTO ln_line_id
                                      FROM (  SELECT line_id
                                                FROM oe_order_lines_all oola
                                               WHERE     1 = 1
                                                     AND oola.sold_to_org_id =
                                                         ln_sold_to_org_id
                                                     AND oola.inventory_item_id =
                                                         ln_inv_item_id
                                                     AND oola.org_id =
                                                         ln_org_id
                                                     AND oola.cancelled_flag <>
                                                         'Y'
                                                     AND oola.flow_status_code =
                                                         'CLOSED'
                                                     AND oola.line_category_code <>
                                                         'RETURN'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM ra_customer_trx_lines_all rctla
                                                               WHERE     rctla.interface_line_attribute6 =
                                                                         TO_CHAR (
                                                                             oola.line_id) -- used again
                                                                     --AND  rctla.bill_to_customer_id = oola.sold_to_org_id
                                                                     AND NVL (
                                                                             rctla.interface_line_attribute11,
                                                                             0) =
                                                                         0 -- Condition to exclude discount lines
                                                                     AND rctla.inventory_item_id =
                                                                         oola.inventory_item_id)
                                            ORDER BY oola.actual_shipment_date DESC)
                                     WHERE ROWNUM = 1;

                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           ' Derived the latest order line id for Same OU, Customer, Item WO ADJ as ln_line_id is - '
                                        || ln_line_id);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_line_id   := NULL;
                                        lv_ex_msg    :=
                                            SUBSTR (SQLERRM, 1, 200);
                                        lv_location   :=
                                            'Same OU, Same Customer, Same Item WO ADJ OTHERS Exception ';

                                        debug_prc (
                                            p_batch_id,
                                            lv_procedure,
                                            lv_location,
                                               ' Others Exception occurred as Same OU, Customer, Item WO ADJ not available - '
                                            || lv_ex_msg);
                                END;
                            -- End of Change for CCR0009071
                            WHEN OTHERS
                            THEN
                                ln_line_id   := NULL;
                                lv_ex_msg    := SUBSTR (SQLERRM, 1, 200);
                                lv_location   :=
                                    'Same OU, Same Customer, Same Item, Same Inv Org WO ADJ OTHERS Exception ';

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Others Exception occurred as Same OU, Customer, Item and Inv Org WO ADJ not available - '
                                    || lv_ex_msg);
                        END;

                        -- Retrieved ln_line_id as per the Same OU,Same Customer, Same Item with/wo Same Ship Org

                        IF ln_line_id IS NOT NULL
                        THEN
                            lv_location      := 'ln_line_id NOT NULL WO ADJ ';
                            lv_ex_msg        := NULL;
                            lv_return_flag   := 'Y';            -- Placed here

                            BEGIN
                                SELECT rctla.warehouse_id, rcta.trx_number, rcta.trx_date,
                                       NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id) ship_to_site_use_id, rcta.bill_to_customer_id
                                  INTO ln_warehouse_id, lv_trx_number, ld_trx_date, ln_ship_to_site_use_id,
                                                      ln_cust_account_id
                                  FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta
                                 WHERE     1 = 1
                                       AND rctla.interface_line_attribute6 =
                                           TO_CHAR (ln_line_id) -- Check the To_CHAR or To_NUMBER function
                                       AND NVL (
                                               rctla.interface_line_attribute11,
                                               0) =
                                           0         -- Exclude Discount lines
                                       AND rctla.customer_trx_id =
                                           rcta.customer_trx_id;

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Fetched ln_warehouse_id is - '
                                    || ln_warehouse_id
                                    || ' - Fetched lv_trx_number is - '
                                    || lv_trx_number
                                    || ' - Fetched ld_trx_date is - '
                                    || ld_trx_date
                                    || ' - Fetched ln_cust_account_id is - '
                                    || ln_cust_account_id
                                    || ' - Fetched ln_cust_account_id is - '
                                    || ln_cust_account_id
                                    || ' - for ln_line_id - '
                                    || ln_line_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_warehouse_id          := NULL;
                                    lv_trx_number            := NULL;
                                    ld_trx_date              := NULL;
                                    ln_ship_to_site_use_id   := NULL;
                                    ln_cust_account_id       := NULL;
                                    lv_ex_msg                :=
                                        SUBSTR (SQLERRM, 1, 200);
                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           ' Exception occurred when fetching Ship to Site details for ln_line_id - '
                                        || ln_line_id
                                        || ' - and msg is - '
                                        || lv_ex_msg);
                            END;

                            IF ln_ship_to_site_use_id IS NOT NULL
                            THEN
                                lv_ret_msg           := NULL;
                                l_ship_add_boolean   := NULL;
                                l_ship_add_boolean   :=
                                    get_ship_add_fnc (
                                        pn_site_id        => ln_ship_to_site_use_id,
                                        x_ship_country    => lv_st_country,
                                        x_ship_province   => lv_st_province,
                                        x_ret_msg         => lv_ret_msg);
                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Derived Ship to Country is  - '
                                    || lv_st_country
                                    || ' Derived Ship to Province is  - '
                                    || lv_st_country
                                    || ' for combination of ln_line_id and Ship to Site use id   - '
                                    || ln_ship_to_site_use_id
                                    || ' and exception if exists is - '
                                    || lv_ret_msg);
                            ELSE
                                NULL;
                            -- use debug prc to send error as 10
                            END IF;
                        END IF;
                    ELSIF     NVL (NVL (lv_hdr_cat_code, ln_line_cat_code),
                                   'ABC') =
                              'RETURN'
                          -- AND ln_ref_line_id IS NULL
                          AND NVL (lv_hdr_adj_flag, 'N') = 'Y'
                          AND NVL (lv_line_adj_flag, 'N') = 'N'
                    THEN
                        lv_return_flag   := 'Y';
                        ln_line_id       := NULL;
                        lv_location      :=
                            'RETURN Order with Freight Adjustment is at Header ';
                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'RETURN Order with Header Price Adjsutment id - '
                            || om_line.user_element_attribute41);

                        BEGIN
                            lv_ex_msg   := NULL;

                            --lv_return_flag := 'Y'; Not placing here, making sure we have some value in it

                            SELECT price_adjustment_id
                              INTO ln_line_id
                              FROM (  SELECT opa.price_adjustment_id
                                        FROM oe_price_adjustments opa, oe_order_headers_all ooha
                                       WHERE     1 = 1
                                             AND ooha.sold_to_org_id =
                                                 ln_sold_to_org_id
                                             AND ooha.org_id = ln_org_id
                                             AND ooha.ship_from_org_id =
                                                 ln_ship_org_id -- Added as per CCR0009071
                                             AND ooha.cancelled_flag <> 'Y'
                                             --AND ooha.flow_status_code = 'CLOSED' -- Commented this as Header will be closed late even after all lines are closed (Probable End of Month)
                                             AND ooha.order_category_code <>
                                                 'RETURN'
                                             AND ooha.header_id = opa.header_id
                                             AND opa.line_id IS NULL
                                             AND opa.list_line_type_code =
                                                 'FREIGHT_CHARGE'
                                             AND EXISTS
                                                     (SELECT 1
                                                        FROM ra_customer_trx_lines_all rctla
                                                       WHERE     rctla.interface_line_attribute6 =
                                                                 TO_CHAR (
                                                                     opa.price_adjustment_id) -- used again
                                                             --AND  rctla.bill_to_customer_id = oola.sold_to_org_id
                                                             AND NVL (
                                                                     rctla.interface_line_attribute11,
                                                                     0) =
                                                                 0 -- Condition to exclude discount lines
                                                                  )
                                    ORDER BY ooha.last_update_date DESC)
                             WHERE ROWNUM = 1;

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Derived the latest order Price Adj id for Same OU, Customer, Item, Same Inv Org with HDR ADJ as ln_line_id is - '
                                || ln_line_id
                                || ' With lv_hdr_adj_flag - '
                                || lv_hdr_adj_flag);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_line_id   := NULL;
                                lv_ex_msg    := SUBSTR (SQLERRM, 1, 200);
                                lv_location   :=
                                    'Same OU, Same Customer, Same Item, Same Inv Org not Found with HDR ADJ';

                                BEGIN
                                    SELECT price_adjustment_id
                                      INTO ln_line_id
                                      FROM (  SELECT opa.price_adjustment_id
                                                FROM oe_price_adjustments opa, oe_order_headers_all ooha
                                               WHERE     1 = 1
                                                     AND ooha.sold_to_org_id =
                                                         ln_sold_to_org_id
                                                     AND ooha.org_id =
                                                         ln_org_id
                                                     AND ooha.cancelled_flag <>
                                                         'Y'
                                                     --AND ooha.flow_status_code = 'CLOSED' -- Commented this as Header will be closed late even after all lines are closed (Probable End of Month)
                                                     AND ooha.order_category_code <>
                                                         'RETURN'
                                                     AND ooha.header_id =
                                                         opa.header_id
                                                     AND opa.line_id IS NULL
                                                     AND opa.list_line_type_code =
                                                         'FREIGHT_CHARGE'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM ra_customer_trx_lines_all rctla
                                                               WHERE     rctla.interface_line_attribute6 =
                                                                         TO_CHAR (
                                                                             opa.price_adjustment_id) -- used again
                                                                     --AND  rctla.bill_to_customer_id = oola.sold_to_org_id
                                                                     AND NVL (
                                                                             rctla.interface_line_attribute11,
                                                                             0) =
                                                                         0 -- Condition to exclude discount lines
                                                                          )
                                            ORDER BY ooha.last_update_date DESC)
                                     WHERE ROWNUM = 1;

                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           ' Derived the latest order Price Adj id for Same OU, Customer, Item with HDR ADJ  as ln_line_id is - '
                                        || ln_line_id
                                        || ' With lv_hdr_adj_flag - '
                                        || lv_hdr_adj_flag);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_line_id   := NULL;
                                        lv_ex_msg    :=
                                            SUBSTR (SQLERRM, 1, 200);

                                        debug_prc (
                                            p_batch_id,
                                            lv_procedure,
                                            lv_location,
                                               ' Others Exception with HDR ADJ for Same OU, Customer, Item - '
                                            || lv_ex_msg
                                            || ' With Sold to Org Id as - '
                                            || ln_sold_to_org_id);
                                END;
                            WHEN OTHERS
                            THEN
                                ln_line_id   := NULL;
                                lv_ex_msg    := SUBSTR (SQLERRM, 1, 200);

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Others Exception with HDR ADJ for Same OU, Same Customer, Same Item, Same Inv Org not Found - '
                                    || lv_ex_msg
                                    || ' With Sold to Org Id as - '
                                    || ln_sold_to_org_id);
                        END;

                        -- Once line_id is found then Continue to fetch the Trx Details

                        IF ln_line_id IS NOT NULL
                        THEN
                            lv_location      :=
                                'ln_line_id NOT NULL with header Price Adjustment';
                            lv_ex_msg        := NULL;
                            lv_return_flag   := 'Y';            -- Placed here

                            BEGIN
                                SELECT rctla.warehouse_id, rcta.trx_number, rcta.trx_date,
                                       NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id) ship_to_site_use_id, rcta.bill_to_customer_id
                                  INTO ln_warehouse_id, lv_trx_number, ld_trx_date, ln_ship_to_site_use_id,
                                                      ln_cust_account_id
                                  FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta
                                 WHERE     1 = 1
                                       AND rctla.interface_line_attribute6 =
                                           TO_CHAR (ln_line_id) -- Check the To_CHAR or To_NUMBER function
                                       AND NVL (
                                               rctla.interface_line_attribute11,
                                               0) =
                                           0         -- Exclude Discount lines
                                       AND rctla.customer_trx_id =
                                           rcta.customer_trx_id;

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Fetched ln_warehouse_id is - '
                                    || ln_warehouse_id
                                    || ' - Fetched lv_trx_number is - '
                                    || lv_trx_number
                                    || ' - Fetched ld_trx_date is - '
                                    || ld_trx_date
                                    || ' - Fetched ln_cust_account_id is - '
                                    || ln_cust_account_id
                                    || ' - Fetched ln_cust_account_id is - '
                                    || ln_cust_account_id
                                    || ' - for ln_line_id - '
                                    || ln_line_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_warehouse_id          := NULL;
                                    lv_trx_number            := NULL;
                                    ld_trx_date              := NULL;
                                    ln_ship_to_site_use_id   := NULL;
                                    ln_cust_account_id       := NULL;
                                    lv_ex_msg                :=
                                        SUBSTR (SQLERRM, 1, 200);
                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           ' Exception occurred when fetching Ship to Site details with HDR ADJ for ln_line_id - '
                                        || ln_line_id
                                        || ' - and msg is - '
                                        || lv_ex_msg);
                            END;

                            IF ln_ship_to_site_use_id IS NOT NULL
                            THEN
                                l_ship_add_boolean   := NULL;
                                lv_ret_msg           := NULL;
                                l_ship_add_boolean   :=
                                    get_ship_add_fnc (
                                        pn_site_id        => ln_ship_to_site_use_id,
                                        x_ship_country    => lv_st_country,
                                        x_ship_province   => lv_st_province,
                                        x_ret_msg         => lv_ret_msg);
                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Derived Ship to Country is  - '
                                    || lv_st_country
                                    || ' Derived Ship to Province is  - '
                                    || lv_st_country
                                    || ' for combination of ln_line_id and Ship to Site use id   - '
                                    || ln_ship_to_site_use_id
                                    || ' Exception Msg is exists is - '
                                    || lv_ret_msg);
                            ELSE
                                NULL;
                                -- use debug prc to send error as 10
                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' latest line id fecthed is NULL as ref not available for Order - '
                                    || lv_ex_msg
                                    || ' With Sold to Org Id as - '
                                    || ln_sold_to_org_id);
                            END IF;
                        END IF;
                    ELSIF     NVL (NVL (lv_hdr_cat_code, ln_line_cat_code),
                                   'ABC') =
                              'RETURN'
                          --AND ln_ref_line_id IS NULL
                          AND NVL (lv_hdr_adj_flag, 'N') = 'N'
                          AND NVL (lv_line_adj_flag, 'N') = 'Y'
                    THEN
                        lv_return_flag   := 'Y';
                        ln_line_id       := NULL;
                        lv_location      :=
                            'RETURN Order with Freight Adjustment is at Line ';
                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'RETURN Order with Line Price Adjsutment id - '
                            || om_line.user_element_attribute41);

                        BEGIN
                            lv_ex_msg   := NULL;

                            --lv_return_flag := 'Y'; Not placing here, making sure we have some value in it

                            SELECT price_adjustment_id
                              INTO ln_line_id
                              FROM (  SELECT opa.price_adjustment_id
                                        FROM oe_price_adjustments opa, oe_order_lines_all oola
                                       WHERE     1 = 1
                                             --                                      AND oola.org_id = ln_org_id
                                             AND oola.sold_to_org_id =
                                                 ln_sold_to_org_id
                                             AND oola.org_id = ln_org_id
                                             AND oola.ship_from_org_id =
                                                 ln_ship_org_id -- Added as per CCR0009071
                                             AND oola.cancelled_flag <> 'Y'
                                             AND oola.flow_status_code =
                                                 'CLOSED'
                                             AND oola.line_category_code <>
                                                 'RETURN'
                                             AND oola.header_id = opa.header_id
                                             AND oola.line_id = opa.line_id
                                             AND opa.list_line_type_code =
                                                 'FREIGHT_CHARGE'
                                             AND EXISTS
                                                     (SELECT 1
                                                        FROM ra_customer_trx_lines_all rctla
                                                       WHERE     rctla.interface_line_attribute6 =
                                                                 TO_CHAR (
                                                                     opa.price_adjustment_id) -- used again
                                                             --AND  rctla.bill_to_customer_id = oola.sold_to_org_id
                                                             AND NVL (
                                                                     rctla.interface_line_attribute11,
                                                                     0) =
                                                                 0 -- Condition to exclude discount lines
                                                                  )
                                    ORDER BY oola.actual_shipment_date DESC --                             ORDER BY oola.last_update_date DESC
                                                                           )
                             WHERE ROWNUM = 1;

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Derived the latest order Price Adj id for Same OU, Customer, Item, Same Inv Org with LINE ADJ as ln_line_id is - '
                                || ln_line_id
                                || ' With lv_line_adj_flag - '
                                || lv_line_adj_flag);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                BEGIN
                                    ln_line_id   := NULL;
                                    lv_location   :=
                                        'Same OU, Same Customer, Same Item, Same Inv Org not Found for Line ADJ';

                                    SELECT price_adjustment_id
                                      INTO ln_line_id
                                      FROM (  SELECT opa.price_adjustment_id
                                                FROM oe_price_adjustments opa, oe_order_lines_all oola
                                               WHERE     1 = 1
                                                     AND oola.sold_to_org_id =
                                                         ln_sold_to_org_id
                                                     AND oola.org_id =
                                                         ln_org_id
                                                     AND oola.cancelled_flag <>
                                                         'Y'
                                                     AND oola.flow_status_code =
                                                         'CLOSED'
                                                     AND oola.line_category_code <>
                                                         'RETURN'
                                                     AND oola.header_id =
                                                         opa.header_id
                                                     AND oola.line_id =
                                                         opa.line_id
                                                     AND opa.list_line_type_code =
                                                         'FREIGHT_CHARGE'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM ra_customer_trx_lines_all rctla
                                                               WHERE     rctla.interface_line_attribute6 =
                                                                         TO_CHAR (
                                                                             opa.price_adjustment_id) -- used again
                                                                     --AND  rctla.bill_to_customer_id = oola.sold_to_org_id
                                                                     AND NVL (
                                                                             rctla.interface_line_attribute11,
                                                                             0) =
                                                                         0 -- Condition to exclude discount lines
                                                                          )
                                            ORDER BY oola.actual_shipment_date DESC --                             ORDER BY oola.last_update_date DESC
                                                                                   )
                                     WHERE ROWNUM = 1;

                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           ' Derived the latest order line Price Adj id for Same OU, Customer, Item as ln_line_id is - '
                                        || ln_line_id
                                        || ' With lv_lin_adj_flag - '
                                        || lv_line_adj_flag);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_line_id   := NULL;
                                        lv_ex_msg    :=
                                            SUBSTR (SQLERRM, 1, 200);

                                        debug_prc (
                                            p_batch_id,
                                            lv_procedure,
                                            lv_location,
                                               ' Others Exception with LINE ADJ for Same OU, Customer, Item - '
                                            || lv_ex_msg
                                            || ' With Sold to Org Id as - '
                                            || ln_sold_to_org_id);
                                END;
                            WHEN OTHERS
                            THEN
                                ln_line_id   := NULL;
                                lv_ex_msg    := SUBSTR (SQLERRM, 1, 200);
                                lv_location   :=
                                    'Same OU, Same Customer, Same Item, Same Inv Org not found for Line Adj';

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Others Exception with LINE ADJ for Same OU, Same Customer, Same Item, Same Inv Org not Found - '
                                    || lv_ex_msg
                                    || ' With Sold to Org Id as - '
                                    || ln_sold_to_org_id);
                        END;

                        IF ln_line_id IS NOT NULL
                        THEN
                            lv_location      :=
                                'ln_line_id NOT NULL with Line Price Adjustment';
                            lv_ex_msg        := NULL;
                            lv_return_flag   := 'Y';            -- Placed here

                            BEGIN
                                SELECT rctla.warehouse_id, rcta.trx_number, rcta.trx_date,
                                       NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id) ship_to_site_use_id, rcta.bill_to_customer_id
                                  INTO ln_warehouse_id, lv_trx_number, ld_trx_date, ln_ship_to_site_use_id,
                                                      ln_cust_account_id
                                  FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta
                                 WHERE     1 = 1
                                       AND rctla.interface_line_attribute6 =
                                           TO_CHAR (ln_line_id) -- Check the To_CHAR or To_NUMBER function
                                       AND NVL (
                                               rctla.interface_line_attribute11,
                                               0) =
                                           0         -- Exclude Discount lines
                                       AND rctla.customer_trx_id =
                                           rcta.customer_trx_id;

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Fetched ln_warehouse_id is - '
                                    || ln_warehouse_id
                                    || ' - Fetched lv_trx_number is - '
                                    || lv_trx_number
                                    || ' - Fetched ld_trx_date is - '
                                    || ld_trx_date
                                    || ' - Fetched ln_cust_account_id is - '
                                    || ln_cust_account_id
                                    || ' - Fetched ln_cust_account_id is - '
                                    || ln_cust_account_id
                                    || ' - for ln_line_id - '
                                    || ln_line_id
                                    || ' With lv_line_adj_flag - '
                                    || lv_line_adj_flag);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_warehouse_id          := NULL;
                                    lv_trx_number            := NULL;
                                    ld_trx_date              := NULL;
                                    ln_ship_to_site_use_id   := NULL;
                                    ln_cust_account_id       := NULL;
                                    lv_ex_msg                :=
                                        SUBSTR (SQLERRM, 1, 200);
                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           ' Exception occurred when fetching Ship to Site details for ln_line_id - '
                                        || ln_line_id
                                        || ' - and msg is - '
                                        || lv_ex_msg
                                        || ' With lv_line_adj_flag - '
                                        || lv_line_adj_flag);
                            END;

                            IF ln_ship_to_site_use_id IS NOT NULL
                            THEN
                                l_ship_add_boolean   := NULL;
                                lv_ret_msg           := NULL;
                                l_ship_add_boolean   :=
                                    get_ship_add_fnc (
                                        pn_site_id        => ln_ship_to_site_use_id,
                                        x_ship_country    => lv_st_country,
                                        x_ship_province   => lv_st_province,
                                        x_ret_msg         => lv_ret_msg);
                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Derived Ship to Country is  - '
                                    || lv_st_country
                                    || ' Derived Ship to Province is  - '
                                    || lv_st_country
                                    || ' for combination of ln_line_id and Ship to Site use id   - '
                                    || ln_ship_to_site_use_id
                                    || ' and exception if exists is - '
                                    || lv_ret_msg);
                            ELSE
                                NULL;
                            -- use debug prc to send error as 10
                            END IF;
                        END IF;
                    END IF;
                -- Changes as per CCR0009071
                -- eComm RETURN orders also treated as Wholesale RETURNS

                /*ELSIF     l_ecom_boolean = TRUE
                      AND NVL (NVL (lv_hdr_cat_code, ln_line_cat_code), 'ABC') =
                             'RETURN'
                      AND ln_ref_line_id IS NULL
                THEN
                   lv_ex_msg := NULL;
                   lv_return_flag := 'Y';
                   lv_location := 'eComm with RETURN and Ref line ID';
                   debug_prc (
                      p_batch_id,
                      lv_procedure,
                      lv_location,
                         'Reference line id cannot be NULL for eComm order line id - '
                      || line.user_element_attribute41);
                ELSIF     l_ecom_boolean = TRUE
                      AND ln_line_cat_code = 'RETURN'
                      AND ln_ref_line_id IS NOT NULL
                THEN
                   lv_return_flag := 'Y';

                   -- using the ref line line, that be the original odrer number and map it to customer transactions to get details
                   BEGIN
                      SELECT rctla.warehouse_id,
                             rcta.trx_number,
                             rcta.trx_date,
                             NVL (rctla.ship_to_site_use_id,
                                  rcta.ship_to_site_use_id)
                                ship_to_site_use_id,
                             rcta.bill_to_customer_id
                        INTO ln_warehouse_id,
                             lv_trx_number,
                             ld_trx_date,
                             ln_ship_to_site_use_id,
                             ln_cust_account_id
                        FROM ra_customer_trx_lines_all rctla,
                             ra_customer_trx_all rcta
                       WHERE     1 = 1
                             AND rctla.interface_line_attribute6 =
                                    TO_CHAR (ln_ref_line_id) -- Check the To_CHAR or To_NUMBER function
                             AND NVL (rctla.interface_line_attribute11, 0) = 0 -- Exclude discount line
                             AND rctla.customer_trx_id = rcta.customer_trx_id;
                   EXCEPTION
                      WHEN OTHERS
                      THEN
                         ln_warehouse_id := NULL;
                         lv_trx_number := NULL;
                         ld_trx_date := NULL;
                         ln_ship_to_site_use_id := NULL;
                         ln_cust_account_id := NULL;
                         lv_ex_msg := SUBSTR (SQLERRM, 1, 200);
                         debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' Exception occurred when fetching Ship to Site details for ref. line id ln_ref_line_id - '
                            || ln_ref_line_id
                            || ' - and msg is - '
                            || lv_ex_msg);
                   END;

                   IF ln_ship_to_site_use_id IS NOT NULL
                   THEN
                      l_ship_add_boolean := NULL;
                      lv_ret_msg := NULL;
                      l_ship_add_boolean :=
                         get_ship_add_fnc (pn_site_id        => ln_ship_to_site_use_id,
                                           x_ship_country    => lv_st_country,
                                           x_ship_province   => lv_st_province,
                                           x_ret_msg         => lv_ret_msg);
                      debug_prc (
                         p_batch_id,
                         lv_procedure,
                         lv_location,
                            'eCom Derived Ship to Country is  - '
                         || lv_st_country
                         || ' Derived Ship to Province is  - '
                         || lv_st_country
                         || ' for combination of ln_ref_line_id and Ship to Site use id   - '
                         || ln_ship_to_site_use_id
                         || ' and exception if exists is - '
                         || lv_ret_msg);
                   ELSE
                      NULL;
                   -- use debug prc to send error as 10
                   END IF;*/
                END IF;

                update_line_prc (
                    p_batch_id                  => om_hdr.batch_id,
                    p_inv_id                    => om_hdr.invoice_id,
                    p_line_id                   => om_line.user_element_attribute41,
                    p_user_element_attribute1   => lv_tax_class,
                    p_user_element_attribute5   =>
                        CASE
                            WHEN lv_return_flag = 'Y' THEN lv_trx_number
                        END,
                    p_user_element_attribute10   =>
                        CASE
                            WHEN ln_order_source_id = 10
                            THEN
                                ln_order_source_id
                        END,
                    p_transaction_type          => 'GS',
                    p_tax_determination_date    => ld_trx_date,
                    p_sf_country                =>
                        CASE
                            WHEN lv_drop_ship_flag = 'Y' THEN lv_drop_country
                        END,
                    p_product_code              =>
                        CASE
                            WHEN lv_return_flag = 'Y' THEN lv_ordered_item
                        END,
                    p_st_country                =>
                        CASE
                            WHEN lv_return_flag = 'Y' THEN lv_st_country
                        END,
                    p_st_province               =>
                        CASE
                            WHEN lv_return_flag = 'Y' THEN lv_st_province
                        END);
            END LOOP;
        END LOOP;
    END xxd_ont_sbx_pre_calc_prc;

    FUNCTION get_batch_source_fnc (pn_batch_source_id IN NUMBER, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR
    IS
        lv_batch_source   apps.ra_batch_sources_all.name%TYPE;
    BEGIN
        SELECT NAME
          INTO lv_batch_source
          FROM apps.ra_batch_sources_all
         WHERE batch_source_id = pn_batch_source_id AND org_id = pn_org_id;

        RETURN lv_batch_source;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_batch_source   := NULL;
            x_ret_msg         := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_batch_source;
    END get_batch_source_fnc;

    FUNCTION get_sales_order_id_fnc (pn_so_num IN NUMBER, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN NUMBER
    IS
        ln_so_header_id   NUMBER;
    BEGIN
        SELECT header_id
          INTO ln_so_header_id
          FROM apps.oe_order_headers_all
         WHERE order_number = pn_so_num AND org_id = pn_org_id;

        RETURN ln_so_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_so_header_id   := NULL;
            x_ret_msg         := SUBSTR (SQLERRM, 1, 200);
            RETURN ln_so_header_id;
    END get_sales_order_id_fnc;

    FUNCTION check_drop_ship_order_fnc (pn_header_id IN NUMBER, pn_line_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN NUMBER
    IS
        ln_vendor_site_id   NUMBER;
    BEGIN
        SELECT apsa.vendor_site_id
          INTO ln_vendor_site_id
          FROM apps.oe_drop_ship_sources ods, apps.po_line_locations_all plla, apps.po_lines_all pla,
               apps.po_headers_all pha, apps.ap_supplier_sites_all apsa
         WHERE     ods.line_location_id = plla.line_location_id
               AND ods.header_id = pn_header_id
               AND ods.line_id = pn_line_id
               AND plla.po_line_id = pla.po_line_id
               AND plla.po_header_id = pha.po_header_id
               AND pha.po_header_id = pla.po_header_id
               AND pha.vendor_site_id = apsa.vendor_site_id;

        RETURN ln_vendor_site_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_vendor_site_id   := NULL;
            x_ret_msg           := SUBSTR (SQLERRM, 1, 200);
            RETURN ln_vendor_site_id;
    END check_drop_ship_order_fnc;

    FUNCTION get_vendor_addr_fnc (pn_site_id IN NUMBER, x_city OUT VARCHAR2, x_postal_code OUT VARCHAR2, x_state OUT VARCHAR2, x_province OUT VARCHAR2, x_county OUT VARCHAR2
                                  , x_country_code OUT VARCHAR2, x_cntry_name OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT hl.city, hl.postal_code, hl.state,
               hl.province, hl.county, hl.country,
               fvl.territory_code
          --fvl.territory_short_name
          INTO x_city, x_postal_code, x_state, x_province,
                     x_county, x_country_code, x_cntry_name
          FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.ap_supplier_sites_all apsa,
               apps.fnd_territories_vl fvl
         WHERE     apsa.party_site_id = hps.party_site_id
               AND hl.location_id = hps.location_id
               AND fvl.territory_code = hl.country
               AND apsa.vendor_site_id = pn_site_id;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_city           := NULL;
            x_postal_code    := NULL;
            x_state          := NULL;
            x_province       := NULL;
            x_county         := NULL;
            x_country_code   := NULL;
            x_cntry_name     := NULL;
            x_ret_msg        := SUBSTR (SQLERRM, 1, 200);
            RETURN TRUE;
    END get_vendor_addr_fnc;

    FUNCTION get_revenue_account_fnc (pn_customer_trx_id IN NUMBER, pn_cust_trx_line_id IN NUMBER, pn_set_of_books_id IN NUMBER
                                      , pn_org_id IN NUMBER, pn_batch_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_code_account    VARCHAR2 (100);
        lv_exception_msg   VARCHAR2 (4000);
    BEGIN
        NULL;
        lv_location   := 'get_revenue_account_fnc with Fnc';

        SELECT DISTINCT glc.segment6
          INTO lv_code_account
          FROM                                         --xla.xla_ae_lines xal,
               --xla.xla_ae_headers xah,
               --apps.xla_distribution_links xdl,
               apps.gl_code_combinations_kfv glc, apps.ra_cust_trx_line_gl_dist_all gl_dist
         WHERE     1 = 1
               --             AND xal.application_id = xah.application_id
               --             AND xdl.ae_line_num = xal.ae_line_num
               --             AND xah.event_id = gl_dist.event_id
               --             AND xal.code_combination_id = glc.code_combination_id
               --             AND xal.ae_header_id = xdl.ae_header_id
               --             AND xah.ae_header_id = xdl.ae_header_id
               --             AND xdl.source_distribution_id_num_1 =
               --                    gl_dist.cust_trx_line_gl_dist_id
               --             AND xal.ledger_id = pn_set_of_books_id
               AND gl_dist.code_combination_id = glc.code_combination_id
               AND gl_dist.customer_trx_id = pn_customer_trx_id
               AND gl_dist.customer_trx_line_id = pn_cust_trx_line_id
               AND gl_dist.account_class = 'REV'
               --             AND gl_dist.account_set_flag = 'N'
               AND gl_dist.org_id = pn_org_id;

        RETURN lv_code_account;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_code_account    := NULL;
            lv_exception_msg   := SUBSTR (SQLERRM, 1, 200);
            x_ret_msg          := SUBSTR (SQLERRM, 1, 200);

            debug_prc (
                pn_batch_id,
                lv_procedure,
                lv_location,
                   'Revenue Code Account for all Transactions  - '
                || lv_code_account
                || ' - with Customer Trx ID - '
                || pn_customer_trx_id
                || ' - with Customer Trx line ID - '
                || pn_cust_trx_line_id
                || ' - with set_of_books_id - '
                || pn_set_of_books_id
                || ' - with org_id - '
                || pn_org_id
                || ' - and Exception msg is - '
                || lv_exception_msg);

            RETURN lv_code_account;
    END get_revenue_account_fnc;

    FUNCTION get_item_tax_class_fnc (pn_inv_item_id IN NUMBER, pn_warehouse_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_tax_class   mtl_categories.segment1%TYPE;
    BEGIN
        SELECT mc.segment1
          INTO lv_tax_class
          FROM mtl_categories mc, mtl_category_sets mcs, mtl_item_categories mic
         WHERE     mc.category_id = mic.category_id
               AND mic.inventory_item_id = pn_inv_item_id
               AND mic.organization_id = pn_warehouse_id
               AND mic.category_set_id = mcs.category_set_id
               AND mcs.category_set_name = 'Tax Class';

        RETURN lv_tax_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_tax_class   := NULL;
            x_ret_msg      := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_tax_class;
    END get_item_tax_class_fnc;

    FUNCTION get_memo_line_desc_fnc (pv_desc IN VARCHAR2, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN NUMBER
    IS
        ln_count   NUMBER;
    BEGIN
        ln_count   := 0;

        SELECT COUNT (pv_desc)
          INTO ln_count
          FROM apps.ar_memo_lines_all_tl a, apps.ar_memo_lines_all_b b
         WHERE     1 = 1
               AND a.org_id = b.org_id
               AND a.language = 'US'
               AND a.memo_line_id = b.memo_line_id
               AND a.description = pv_desc
               AND a.org_id = pn_org_id;

        RETURN ln_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_count    := 0;
            x_ret_msg   := SUBSTR (SQLERRM, 1, 200);
            RETURN ln_count;
    END get_memo_line_desc_fnc;

    FUNCTION is_manual_invoice_fnc (pn_cust_trx_type_id IN NUMBER, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_cust_trx_id   NUMBER;
    BEGIN
        SELECT cust_trx_type_id
          INTO ln_cust_trx_id
          FROM ra_cust_trx_types_all
         WHERE     cust_trx_type_id = pn_cust_trx_type_id
               AND org_id = pn_org_id
               AND name LIKE 'Manual%';

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_cust_trx_id   := NULL;
            x_ret_msg        := SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END is_manual_invoice_fnc;

    FUNCTION get_ship_from_fnc (pn_inv_org_id   IN     NUMBER,
                                x_ret_msg          OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_ship_country   VARCHAR2 (100);
    BEGIN
        lv_ship_country   := NULL;

        SELECT fvl.territory_code                   --fvl.territory_short_name
          INTO lv_ship_country
          FROM fnd_territories_vl fvl, hr_locations hrl, hr_all_organization_units hou
         WHERE     hrl.country = fvl.territory_code
               AND hrl.inventory_organization_id = hou.organization_id
               AND hrl.location_id = hou.location_id
               AND hrl.inventory_organization_id = pn_inv_org_id;

        RETURN lv_ship_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_ship_country   := NULL;
            x_ret_msg         := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_ship_country;
    END get_ship_from_fnc;

    FUNCTION get_ship_add_fnc (pn_site_id IN NUMBER, x_ship_country OUT VARCHAR2, x_ship_province OUT VARCHAR2
                               , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT hl_ship.country, hl_ship.province
          INTO x_ship_country, x_ship_province
          FROM hz_cust_site_uses_all hcs_ship, hz_cust_acct_sites_all hca_ship, hz_party_sites hps_ship,
               hz_parties hp_ship, hz_locations hl_ship
         WHERE     1 = 1
               AND hcs_ship.cust_acct_site_id = hca_ship.cust_acct_site_id
               AND hca_ship.party_site_id = hps_ship.party_site_id
               AND hps_ship.party_id = hp_ship.party_id
               AND hps_ship.location_id = hl_ship.location_id
               AND hcs_ship.site_use_id = pn_site_id;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ship_country    := NULL;
            x_ship_province   := NULL;
            x_ret_msg         := SUBSTR (SQLERRM, 1, 200);
            RETURN TRUE;
    END get_ship_add_fnc;

    FUNCTION check_ecom_org_fnc (pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_org_name   VARCHAR2 (100);
    BEGIN
        l_org_name   := NULL;

        SELECT name
          INTO l_org_name
          FROM hr_all_organization_units
         WHERE     organization_id = pn_org_id
               AND TYPE = 'ECOMM'
               AND SYSDATE BETWEEN NVL (date_from, SYSDATE)
                               AND NVL (date_to, SYSDATE + 1);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_org_name   := NULL;
            x_ret_msg    := SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END check_ecom_org_fnc;

    FUNCTION get_original_id_fnc (pn_header_id   IN     NUMBER,
                                  pn_line_id     IN     NUMBER,
                                  x_header_id       OUT NUMBER,
                                  x_line_id         OUT NUMBER,
                                  x_ret_msg         OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT reference_header_id, reference_line_id
          INTO x_header_id, x_line_id
          FROM oe_order_lines_all
         WHERE header_id = pn_header_id AND line_id = pn_line_id;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_header_id   := NULL;
            x_line_id     := NULL;
            x_ret_msg     := SUBSTR (SQLERRM, 1, 200);
            RETURN TRUE;
    END;

    FUNCTION get_original_trx_date_fnc (pn_line_id IN NUMBER, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN DATE
    IS
        ld_trx_date   DATE;
    BEGIN
        SELECT trx_date
          INTO ld_trx_date
          FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta
         WHERE     1 = 1
               AND rcta.customer_trx_id = rctla.customer_trx_id
               AND rctla.interface_line_attribute6 = pn_line_id
               AND NVL (rctla.interface_line_attribute11, 0) = 0 -- Exclude discount line
               AND rctla.org_id = pn_org_id;

        RETURN ld_trx_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            ld_trx_date   := NULL;
            x_ret_msg     := SUBSTR (SQLERRM, 1, 200);
            RETURN ld_trx_date;
    END get_original_trx_date_fnc;

    FUNCTION get_ship_from_brand_fnc (pv_brand IN VARCHAR2, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_territory   VARCHAR2 (100);
    BEGIN
        SELECT ffvl.attribute3
          INTO lv_territory
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvs.flex_value_set_name = 'XXD_MTD_OU_TERR_BRANDS_VS'
               AND ffvl.attribute1 = pn_org_id
               AND ffvl.attribute2 = pv_brand;

        RETURN lv_territory;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_territory   := NULL;
            x_ret_msg      := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_territory;
    END get_ship_from_brand_fnc;

    PROCEDURE xxd_ar_sbx_pre_calc_prc (p_batch_id IN NUMBER)
    IS
        --PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_trx_hdr_data IS
            SELECT rcta.customer_trx_id, sbx_inv.batch_id, sbx_inv.invoice_id,
                   rcta.batch_source_id, rcta.org_id, NVL (rcta.attribute5, hca.attribute1) brand, -- -- Added NVL for CCR0009103
                   rctta.TYPE trx_type, rcta.interface_header_attribute1 so_number, rcta.interface_header_context,
                   rcta.set_of_books_id, --rcta.reason_code,
                                         rcta.cust_trx_type_id, sbx_inv.user_element_attribute41,
                   rcta.bill_to_customer_id, rcta.bill_to_site_use_id, rcta.attribute6 orig_trx_number -- CCR0009857
              FROM sabrix_invoice sbx_inv, apps.ra_customer_trx_all rcta, apps.ra_cust_trx_types_all rctta,
                   apps.hz_cust_accounts hca        -- Added as per CCR0009103
             WHERE     1 = 1
                   AND sbx_inv.calling_system_number = '222'
                   AND rcta.customer_trx_id =
                       sbx_inv.user_element_attribute41
                   AND rcta.cust_trx_type_id = rctta.cust_trx_type_id
                   AND rcta.org_id = rctta.org_id
                   AND rcta.org_id = sbx_inv.user_element_attribute45
                   AND hca.cust_account_id = rcta.bill_to_customer_id -- -- Added as per CCR0009103
                   AND sbx_inv.batch_id = p_batch_id;

        CURSOR cur_trx_line_data (pn_batch_id IN NUMBER, pn_invoice_id IN NUMBER, pn_cust_trx_id IN NUMBER)
        IS
            SELECT DISTINCT user_element_attribute41, rctla.customer_trx_line_id, rctla.interface_line_attribute6 line_id,
                            rctla.inventory_item_id, rctla.warehouse_id, rctla.reason_code,
                            rctla.description, rctla.org_id, sbx_line.invoice_id,
                            sbx_line.batch_id, sbx_line.line_id sbx_line_id, rctla.interface_line_attribute1
              FROM sabrix_line sbx_line, apps.ra_customer_trx_lines_all rctla
             WHERE     1 = 1
                   AND rctla.customer_trx_line_id =
                       sbx_line.user_element_attribute41
                   AND rctla.customer_trx_id = pn_cust_trx_id
                   AND sbx_line.invoice_id = pn_invoice_id
                   AND sbx_line.batch_id = pn_batch_id;

        lv_batch_source_name         apps.ra_batch_sources_all.name%TYPE;
        ln_vendor_site_id            apps.ap_supplier_sites_all.vendor_site_id%TYPE;
        lv_city                      VARCHAR2 (100);
        lv_postal_code               VARCHAR2 (100);
        lv_state                     VARCHAR2 (100);
        lv_province                  VARCHAR2 (100);
        lv_county                    VARCHAR2 (100);
        lv_country_code              VARCHAR2 (100);
        lv_cntry_name                VARCHAR2 (100);
        ln_header_id                 NUMBER;
        l_addr_boolean               BOOLEAN;
        lv_item_tax_class            VARCHAR2 (100);
        lv_revenue_account           VARCHAR2 (100);
        ln_memo_count                NUMBER;
        lv_memo_desc                 VARCHAR2 (240);
        lv_tm_ship_from              VARCHAR2 (100);
        l_man_boolean                BOOLEAN;
        lv_man_ship_from             VARCHAR2 (100);
        l_ecom_org_boolean           BOOLEAN;
        l_nonecom_ship_from          VARCHAR2 (100);
        l_drop_ship_flag             VARCHAR2 (10);
        l_orig_ord_boolean           BOOLEAN;
        ln_orig_header_id            NUMBER;
        ln_orig_line_id              NUMBER;
        ld_invoice_date              DATE;
        lv_exception_msg             VARCHAR2 (4000);
        ln_warehouse_id              NUMBER;
        lv_reference_line            VARCHAR2 (100);
        lv_org_loc                   VARCHAR2 (100);
        ln_cust_account_id           NUMBER;
        ln_bill_site_id              NUMBER;
        lv_nonref_trx_number         VARCHAR2 (100);
        ln_hdr_cust_account_id       NUMBER;
        ln_hdr_bill_site_id          NUMBER;
        ln_hdr_ship_site_id          NUMBER;
        ln_ship_cust_id              NUMBER;        -- Added as per CCR0009607
        lv_tax_ref                   VARCHAR2 (100);
        ln_ship_to_site_use_id       NUMBER;
        lv_ar_ship_country           VARCHAR2 (100);
        lv_ar_ship_province          VARCHAR2 (100);
        lb_ar_ship_add_boolean       BOOLEAN;
        lv_cm_flag                   VARCHAR2 (1) := 'N';
        lv_ar_trx_number             VARCHAR2 (100);
        lv_trx_number                VARCHAR2 (100);
        lv_ship_from                 VARCHAR2 (100);
        lv_final_ship_from           VARCHAR2 (100);
        ln_hdr_ship_to_site_use_id   NUMBER;
        lb_ship_code                 BOOLEAN;
        lv_payment_type              VARCHAR2 (100);
        ln_line_adj_cnt              NUMBER;
        lin_line_id                  NUMBER;
        lin_header_id                NUMBER;
        lin_inv_item_id              NUMBER;
        ln_hdr_adj_cnt               NUMBER;
        lv_ret_msg                   VARCHAR2 (4000);
        ln_ref_trx_line_id           NUMBER;
        ln_ref_orig_hdr_id           NUMBER;
        -- Start of Change for CCR0009071
        lv_tm_whname                 VARCHAR2 (100);
        lv_tm_trx_type               VARCHAR2 (100);
        lv_tm_int_context            VARCHAR2 (100);
        lv_tm_brand                  VARCHAR2 (100);
        ln_tm_org_id                 NUMBER;
        ln_tm_warehouse_id           NUMBER;
        lv_tm_ship_from_obj          VARCHAR2 (100);
        ln_tm_counter                NUMBER;
        ln_tm_counter1               NUMBER;
        lv_tm_whname_obj             VARCHAR2 (100);
        lv_ref_ship_from             VARCHAR2 (100);
        lv_ref_ship_from_name        VARCHAR2 (100);
        ln_ref_ship_from_id          NUMBER;
        ln_trx_amt_due               NUMBER;     -- -- Added as per CCR0009857
        ln_amount_due                NUMBER;     -- -- Added as per CCR0009857
    -- End of Change
    BEGIN
        lv_procedure   := 'XXD_AR_SBX_PRE_CALC_PRC';
        lv_location    := 'First Entry Point';
        lv_ret_msg     := NULL;

        --      xxv_debug_prc('Debug level is - '||g_debug_level);

        debug_prc (
            p_batch_id,
            lv_procedure,
            lv_location,
            'Start of Data flow for AR with batch id - ' || p_batch_id);

        FOR trx_hdr IN cur_trx_hdr_data
        LOOP
            lv_location                  := 'TRX Header Loop';
            lv_exception_msg             := NULL;
            ln_cust_account_id           := NULL;
            ln_bill_site_id              := NULL;
            ln_hdr_cust_account_id       := NULL;
            ln_hdr_bill_site_id          := NULL;
            lv_tax_ref                   := NULL;
            lv_batch_source_name         := NULL;
            l_drop_ship_flag             := 'N';
            lv_tm_ship_from              := NULL;
            ln_header_id                 := NULL;
            l_man_boolean                := NULL;
            l_ecom_org_boolean           := NULL;
            ln_ship_to_site_use_id       := NULL;
            lv_ar_ship_country           := NULL;
            lv_ar_ship_province          := NULL;
            lb_ar_ship_add_boolean       := NULL;
            lv_nonref_trx_number         := NULL;
            lv_man_ship_from             := NULL;
            ln_hdr_ship_to_site_use_id   := NULL;
            lb_ship_code                 := NULL;
            lv_payment_type              := NULL;
            lv_ret_msg                   := NULL;
            ln_ref_orig_hdr_id           := NULL;
            lv_tm_whname_obj             := NULL;
            ln_ref_ship_from_id          := NULL;
            ln_hdr_ship_site_id          := NULL;   -- Added as per CCR0009071
            ln_ship_cust_id              := NULL;   -- Added as per CCR0009071
            ln_trx_amt_due               := NULL;   -- Added as per CCR0009857


            update_inv_prc (p_batch_id, trx_hdr.user_element_attribute41);

            -- Start of Change for CCR0009857

            ln_trx_amt_due               := NULL;

            get_trxn_due_amt (p_header_id => trx_hdr.so_number, p_org_id => trx_hdr.org_id, x_trx_due => ln_trx_amt_due
                              , x_ret_msg => lv_ret_msg);

            debug_prc (
                p_batch_id,
                lv_procedure,
                lv_location,
                   'Exception with - '
                || p_batch_id
                || ' Customer Trx ID - '
                || trx_hdr.user_element_attribute41
                || ' and Amount Due Remaining is '
                || ln_trx_amt_due
                || ' and exception is '
                || SQLERRM);

            -- End of Change for CCR0009857

            BEGIN
                SELECT bill_to_customer_id, bill_to_site_use_id, ship_to_site_use_id,
                       ship_to_customer_id          -- Added as per CCR0009607
                  INTO ln_hdr_cust_account_id, ln_hdr_bill_site_id, ln_hdr_ship_site_id, ln_ship_cust_id -- Added as per CCR0009607
                  FROM ra_customer_trx_all rcta
                 WHERE rcta.customer_trx_id =
                       trx_hdr.user_element_attribute41;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_hdr_cust_account_id   := NULL;
                    ln_hdr_bill_site_id      := NULL;
                    ln_hdr_ship_site_id      := NULL;
                    ln_ship_cust_id          := NULL; -- Added as per CCR0009071
                    lv_ret_msg               := SUBSTR (SQLERRM, 1, 200);
            -- debug_prc with Error Code 10.
            END;

            debug_prc (
                p_batch_id,
                lv_procedure,
                lv_location,
                   ' - Derived Customer Account '
                || ln_hdr_cust_account_id
                || ' - and Billing Site  - '
                || ln_hdr_bill_site_id
                || ' - Shipping Customer Account '
                || ln_ship_cust_id
                || ' - and Shipping Site  - '
                || ln_hdr_ship_site_id
                || ' - for Customer Trx ID - '
                || trx_hdr.user_element_attribute41
                || ' and exception msg if exists is - '
                || lv_ret_msg);

            -- Get the Tax Registration Number

            lv_location                  := 'TRX Header Loop - Tax Reg.';

            -- Added as per CCR0009607

            BEGIN
                SELECT custaccountsiteeo.tax_reference
                  INTO lv_tax_ref
                  FROM hz_cust_site_uses_all custaccountsiteeo, hz_cust_accounts custaccounteo, hz_cust_acct_sites_all hzcustacctsitesall,
                       hz_parties hzparties, hz_party_sites hzpartysites
                 WHERE     hzpartysites.party_id = custaccounteo.party_id
                       AND hzcustacctsitesall.cust_account_id =
                           custaccounteo.cust_account_id
                       AND hzcustacctsitesall.party_site_id =
                           hzpartysites.party_site_id
                       AND custaccountsiteeo.cust_acct_site_id =
                           hzcustacctsitesall.cust_acct_site_id
                       AND custaccountsiteeo.status = 'A'
                       AND hzparties.party_id = hzpartysites.party_id
                       AND custaccountsiteeo.org_id =
                           hzcustacctsitesall.org_id
                       AND custaccountsiteeo.site_use_code = 'SHIP_TO'
                       AND custaccounteo.cust_account_id = ln_ship_cust_id
                       AND custaccountsiteeo.site_use_id =
                           ln_hdr_ship_site_id;

                -- End of Change for CCR0009607

                debug_prc (
                    p_batch_id,
                    lv_procedure,
                    lv_location,
                       'Sabrix Reg. Number found is  - '
                    || lv_tax_ref
                    || ' - for cust account id - '
                    || ln_hdr_cust_account_id
                    || ' - With Ship to Site use id is  - '
                    || ln_hdr_ship_site_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_tax_ref         := NULL;
                    lv_exception_msg   := SUBSTR (SQLERRM, 1, 200);
            END;

            IF lv_tax_ref IS NULL
            THEN
                BEGIN
                    SELECT custaccountsiteeo.tax_reference
                      INTO lv_tax_ref
                      FROM hz_cust_site_uses_all custaccountsiteeo, hz_cust_accounts custaccounteo, hz_cust_acct_sites_all hzcustacctsitesall,
                           hz_parties hzparties, hz_party_sites hzpartysites
                     WHERE     hzpartysites.party_id = custaccounteo.party_id
                           AND hzcustacctsitesall.cust_account_id =
                               custaccounteo.cust_account_id
                           AND hzcustacctsitesall.party_site_id =
                               hzpartysites.party_site_id
                           AND custaccountsiteeo.cust_acct_site_id =
                               hzcustacctsitesall.cust_acct_site_id
                           AND custaccountsiteeo.status = 'A'
                           AND hzparties.party_id = hzpartysites.party_id
                           AND custaccountsiteeo.org_id =
                               hzcustacctsitesall.org_id
                           AND custaccountsiteeo.site_use_code = 'BILL_TO'
                           AND custaccounteo.cust_account_id =
                               ln_hdr_cust_account_id
                           AND custaccountsiteeo.site_use_id =
                               ln_hdr_bill_site_id;

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Sabrix Reg. Number found is  - '
                        || lv_tax_ref
                        || ' - for cust account id - '
                        || ln_hdr_cust_account_id
                        || ' - With Bill to Site use id is  - '
                        || ln_hdr_bill_site_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_tax_ref   := NULL;

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'Exception found for cust account id - '
                            || ln_hdr_cust_account_id
                            || ' - With Bill to Site use id is  - '
                            || ln_hdr_bill_site_id
                            || ' - Exception Msg is - '
                            || lv_exception_msg);
                END;
            END IF;


            -- Insert record into Sabrix Registration only when Tax_ref is NOT NULL

            --lv_location := 'TRX Hdr Loop with Reg Insert';

            IF lv_tax_ref IS NOT NULL
            THEN
                lv_exception_msg   := NULL;
                lv_location        := 'Inside when Tax Ref is Found';

                BEGIN
                    INSERT INTO Sabrix_Registration (batch_id,
                                                     creation_date,
                                                     invoice_id,
                                                     line_id,
                                                     merchant_role,
                                                     registration_number)
                         VALUES (trx_hdr.batch_id, SYSDATE, trx_hdr.invoice_id
                                 , -1, 'B', lv_tax_ref);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                        lv_exception_msg   := SUBSTR (SQLERRM, 1, 200);
                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' Insert Stmt for Sabrix Reg is failed with msg  - '
                            || lv_exception_msg);
                END;
            END IF;

            debug_prc (
                p_batch_id,
                lv_procedure,
                lv_location,
                   ' Sabrix Reg Insert is complete and if any error then it is - '
                || lv_exception_msg);


            --         update_inv_prc (p_batch_id, trx_hdr.user_element_attribute41);

            lv_location                  := 'Batch Source';

            IF trx_hdr.batch_source_id IS NOT NULL
            THEN
                lv_ret_msg   := NULL;
                lv_batch_source_name   :=
                    get_batch_source_fnc (trx_hdr.batch_source_id,
                                          trx_hdr.org_id,
                                          lv_ret_msg);
            END IF;


            debug_prc (
                p_batch_id,
                lv_procedure,
                lv_location,
                   'Batch Source Name - '
                || lv_batch_source_name
                || ' and exception if exists is - '
                || lv_ret_msg);

            lv_location                  := 'Header Context';

            IF trx_hdr.interface_header_context = 'ORDER ENTRY'
            THEN
                ln_header_id   := NULL;
                lv_ret_msg     := NULL;
                -- Get SO header id
                ln_header_id   :=
                    get_sales_order_id_fnc (trx_hdr.so_number,
                                            trx_hdr.org_id,
                                            lv_ret_msg);
            END IF;

            debug_prc (
                p_batch_id,
                lv_procedure,
                lv_location,
                   ' Interface header context - '
                || trx_hdr.interface_header_context
                || ' ln_header_id - '
                || ln_header_id
                || ' and exception if exists is - '
                || lv_ret_msg);

            -- When Batch Source is TM, implement the conditions and update accordingly

            -- Check Whether the transaction is Manual

            lv_ret_msg                   := NULL;
            l_man_boolean                :=
                is_manual_invoice_fnc (trx_hdr.cust_trx_type_id,
                                       trx_hdr.org_id,
                                       lv_ret_msg);

            debug_prc (p_batch_id, 'is_manual_invoice_fnc', 'is_manual_invoice_fnc'
                       , ' and exception if exists is - ' || lv_ret_msg);

            -- get the AR Transaction Type

            -- Check the org type, whether it is Ecom or Not


            lv_ret_msg                   := NULL;
            l_ecom_org_boolean           :=
                check_ecom_org_fnc (trx_hdr.org_id, lv_ret_msg);

            debug_prc (p_batch_id, 'check_ecom_orig_fnc', 'check_ecom_org_fnc'
                       , ' and exception if exists is - ' || lv_ret_msg);

            -- Added as per CCR0009071



            lv_ref_ship_from             := NULL;
            lv_ref_ship_from             :=
                get_ship_from_brand_fnc (pv_brand    => trx_hdr.brand,
                                         pn_org_id   => trx_hdr.org_id,
                                         x_ret_msg   => lv_ret_msg);
            lv_ref_ship_from_name        := NULL;

            IF lv_ref_ship_from IS NOT NULL
            THEN
                BEGIN
                    SELECT attribute2
                      INTO lv_ref_ship_from_name
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvs.flex_value_set_name =
                               'XXD_AR_MTD_CNTRY_WH_VS'
                           AND ffvl.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (ffvl.end_date_active,
                                                    SYSDATE + 1)
                           AND ffvl.attribute1 = lv_ref_ship_from;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_ref_ship_from_name   := 'ME3';
                    WHEN OTHERS
                    THEN
                        lv_ref_ship_from_name   := NULL;
                END;
            END IF;

            ln_ref_ship_from_id          := NULL;


            IF lv_ref_ship_from_name IS NOT NULL
            THEN
                BEGIN
                    SELECT organization_id
                      INTO ln_ref_ship_from_id
                      FROM org_organization_definitions
                     WHERE organization_code = lv_ref_ship_from_name;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_ref_ship_from_id   := NULL;
                END;
            END IF;

            debug_prc (
                p_batch_id,
                'get_ship_from_brand_fnc',
                'get_ship_from_brand_fnc',
                   ' lv_ref_ship_from is - '
                || lv_ref_ship_from
                || ' lv_ref_ship_from_name is - '
                || lv_ref_ship_from_name
                || ' Final ln_ref_ship_from_id - '
                || ln_ref_ship_from_id
                || ' for trx_hdr.brand - '
                || trx_hdr.brand
                || ' trx_hdr.org_id - '
                || trx_hdr.org_id
                || ' and exception if exists is - '
                || lv_ret_msg);

            -- End of Change

            lv_payment_type              := NULL;

            IF l_ecom_org_boolean = TRUE AND ln_header_id IS NOT NULL
            THEN
                lb_ship_code         := NULL;
                lv_ret_msg           := NULL;
                ln_ref_orig_hdr_id   := NULL;
                lv_procedure         := 'check_orig_order_return';
                lv_location          := 'check_orig_order_return';

                IF trx_hdr.trx_type = 'CM'
                THEN
                    BEGIN
                        SELECT DISTINCT reference_header_id
                          INTO ln_ref_orig_hdr_id
                          FROM oe_order_lines_all
                         WHERE header_id = ln_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_ref_orig_hdr_id   := NULL;
                            lv_ret_msg           := SUBSTR (SQLERRM, 1, 200);
                    END;
                END IF;

                debug_prc (
                    p_batch_id,
                    'check_orig_order_return',
                    'check_orig_order_return',
                       ' Original Header ID is - '
                    || ln_ref_orig_hdr_id
                    || ' and exception if exists is - '
                    || lv_ret_msg);


                lv_ret_msg           := NULL;

                IF trx_hdr.trx_type = 'CM' AND ln_ref_orig_hdr_id IS NOT NULL
                THEN
                    lb_ship_code   := NULL;
                    lv_ret_msg     := NULL;
                    lb_ship_code   :=
                        check_ge_order (pv_ship_method_code => NULL, pn_header_id => ln_ref_orig_hdr_id, pn_org_id => trx_hdr.org_id
                                        , x_ret_msg => lv_ret_msg);
                    debug_prc (
                        p_batch_id,
                        'check_ge_order',
                        'check_ge_order',
                           ' with trx_type as - '
                        || trx_hdr.trx_type
                        || ' Original Header ID is - '
                        || ln_ref_orig_hdr_id
                        || ' and exception if exists is - '
                        || lv_ret_msg);

                    IF lb_ship_code = TRUE
                    THEN
                        lv_ret_msg        := NULL;
                        lv_payment_type   := NULL;

                        BEGIN
                            SELECT DISTINCT shipping_method_code
                              INTO lv_payment_type
                              FROM oe_order_headers_all
                             WHERE     header_id = ln_ref_orig_hdr_id
                                   AND org_id = trx_hdr.org_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_payment_type   := NULL;
                                lv_ret_msg        := SUBSTR (SQLERRM, 1, 200);
                        END;
                    ELSE
                        lv_payment_type   := NULL;
                    END IF;

                    debug_prc (
                        p_batch_id,
                        'Payment Type for eCom',
                        'Payment Type for eCom',
                           ' lv_payment_type is - '
                        || lv_payment_type
                        || ' and exception if exists is - '
                        || lv_ret_msg);
                ELSE
                    lb_ship_code   := NULL;
                    lv_ret_msg     := NULL;
                    lb_ship_code   :=
                        check_ge_order (pv_ship_method_code => NULL, pn_header_id => ln_header_id, pn_org_id => trx_hdr.org_id
                                        , x_ret_msg => lv_ret_msg);
                    debug_prc (
                        p_batch_id,
                        'check_ge_order',
                        'check_ge_order',
                           ' with trx_type as - '
                        || trx_hdr.trx_type
                        || ' Header ID is - '
                        || ln_header_id
                        || ' and exception if exists is - '
                        || lv_ret_msg);

                    IF lb_ship_code = TRUE
                    THEN
                        lv_ret_msg        := NULL;
                        lv_payment_type   := NULL;

                        BEGIN
                            SELECT DISTINCT shipping_method_code
                              INTO lv_payment_type
                              FROM oe_order_headers_all
                             WHERE     header_id = ln_header_id
                                   AND org_id = trx_hdr.org_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_payment_type   := NULL;
                                lv_ret_msg        := SUBSTR (SQLERRM, 1, 200);
                        END;
                    ELSE
                        lv_payment_type   := NULL;
                    END IF;

                    debug_prc (
                        p_batch_id,
                        'Payment Type for eCom',
                        'Payment Type for eCom',
                           ' lv_payment_type is - '
                        || lv_payment_type
                        || ' and exception if exists is - '
                        || lv_ret_msg);
                END IF;
            END IF;


            -- For all the Transactions, irrespective of source, update as below

            update_header_prc (
                p_batch_id                  => trx_hdr.batch_id,
                p_header_id                 => trx_hdr.customer_trx_id,
                p_user_element_attribute1   => trx_hdr.trx_type,
                p_user_element_attribute2   => lv_batch_source_name,
                p_user_element_attribute4   => lv_payment_type);

            --COMMIT;

            FOR trx_line
                IN cur_trx_line_data (trx_hdr.batch_id,
                                      trx_hdr.invoice_id,
                                      trx_hdr.customer_trx_id)
            LOOP
                lv_location           := 'TRX Line Loop';

                ln_vendor_site_id     := NULL;
                lv_revenue_account    := NULL;
                ln_memo_count         := NULL;
                lv_memo_desc          := NULL;
                ld_invoice_date       := NULL;
                l_addr_boolean        := NULL;
                lv_city               := NULL;
                lv_postal_code        := NULL;
                lv_state              := NULL;
                lv_province           := NULL;
                lv_county             := NULL;
                lv_country_code       := NULL;
                lv_cntry_name         := NULL;
                l_drop_ship_flag      := 'N';
                lv_item_tax_class     := NULL;
                l_nonecom_ship_from   := NULL;
                l_orig_ord_boolean    := NULL;
                ln_orig_header_id     := NULL;
                ln_orig_line_id       := NULL;
                ld_invoice_date       := NULL;
                ln_warehouse_id       := NULL;
                lv_reference_line     := NULL;
                lv_org_loc            := NULL;
                lv_exception_msg      := NULL;
                lv_cm_flag            := 'N';
                lv_ar_trx_number      := NULL;
                lv_trx_number         := NULL;
                lv_ship_from          := NULL;
                lv_final_ship_from    := NULL;
                ln_line_adj_cnt       := 0;
                lin_line_id           := 0;
                lin_header_id         := 0;
                lin_inv_item_id       := 0;
                ln_hdr_adj_cnt        := 0;
                lv_ret_msg            := NULL;
                ln_ref_trx_line_id    := NULL;
                lv_tm_whname          := NULL;
                lv_tm_trx_type        := NULL;
                lv_tm_int_context     := NULL;
                lv_tm_brand           := NULL;
                ln_tm_org_id          := NULL;
                ln_tm_warehouse_id    := NULL;
                lv_tm_ship_from_obj   := NULL;
                ln_tm_counter         := 0;
                ln_tm_counter1        := 0;
                lv_tm_whname_obj      := NULL;

                --lv_ref_ship_from := NULL;


                -- Now check for the Drop Ship Orders, If it is a drop ship order then vendor site id is NOT NULL
                -- for this to continue, AR Trx should be based out of SO and it should be only INVOICE

                IF ln_header_id IS NOT NULL AND trx_hdr.trx_type = 'INV'
                THEN
                    lv_location         := 'Auto Invoice with INV type';
                    l_addr_boolean      := NULL;
                    lv_city             := NULL;
                    lv_postal_code      := NULL;
                    lv_state            := NULL;
                    lv_province         := NULL;
                    lv_county           := NULL;
                    lv_country_code     := NULL;
                    lv_cntry_name       := NULL;
                    ln_vendor_site_id   := NULL;
                    lv_ret_msg          := NULL;

                    -- Get order Header_id
                    -- Indicates that the Transaction has associated Sales order

                    ln_vendor_site_id   :=
                        check_drop_ship_order_fnc (ln_header_id,
                                                   trx_line.line_id,
                                                   lv_ret_msg);
                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           ' Vendor Site id is - '
                        || ln_vendor_site_id
                        || ' for SO Header id is - '
                        || ln_header_id
                        || ' - with Trx Type as - '
                        || trx_hdr.trx_type
                        || ' and exception if exists is - '
                        || lv_ret_msg);

                    -- if it is Drop Ship Order then vendor_site_id will be NOT NULL, then get the address details.

                    IF ln_vendor_site_id IS NOT NULL
                    THEN
                        lv_location          := 'Drop Ship Order';
                        l_drop_ship_flag     := 'Y'; -- Updated this flag to 'Y' on 0922
                        lv_ret_msg           := NULL;
                        l_addr_boolean       :=
                            get_vendor_addr_fnc (
                                pn_site_id       => ln_vendor_site_id,
                                x_city           => lv_city,
                                x_postal_code    => lv_postal_code,
                                x_state          => lv_state,
                                x_province       => lv_province,
                                x_county         => lv_county,
                                x_country_code   => lv_country_code,
                                x_cntry_name     => lv_cntry_name,
                                x_ret_msg        => lv_ret_msg);

                        lv_final_ship_from   := lv_cntry_name;

                        IF l_addr_boolean = TRUE
                        THEN
                            l_drop_ship_flag   := 'Y';
                        END IF;

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'Vendor Site ID is - '
                            || ln_vendor_site_id
                            || ' with Drop Ship Order flag is - '
                            || l_drop_ship_flag
                            || ' And Country is - '
                            || lv_final_ship_from
                            || ' and exception if exists is - '
                            || lv_ret_msg);
                    END IF;
                END IF;

                -- For all the Auto Invoice Transactions, fetching the Tax Class (How about CM's??)
                IF ln_header_id IS NOT NULL
                THEN
                    lv_location         := 'Tax Class of Auto Invoice';
                    lv_item_tax_class   := NULL;
                    ln_hdr_adj_cnt      := 0;
                    ln_line_adj_cnt     := 0;

                    -- Check whether the Inventory_item_id is the Freight Item

                    IF     trx_line.inventory_item_id IS NOT NULL
                       AND trx_line.inventory_item_id <> 1569786
                    THEN
                        lv_item_tax_class   := NULL;
                        lv_ret_msg          := NULL;
                        lv_location         :=
                            'Tax Class of Auto Invoice Non Freight Item';

                        lv_item_tax_class   :=
                            get_item_tax_class_fnc (
                                trx_line.inventory_item_id,
                                trx_line.warehouse_id,
                                lv_ret_msg);

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'Non Freight Item Tax Class as  - '
                            || lv_item_tax_class
                            || ' and exception if exists is - '
                            || lv_ret_msg);
                    ELSIF     trx_line.inventory_item_id IS NOT NULL
                          AND trx_line.inventory_item_id = 1569786
                    THEN
                        lv_item_tax_class   := NULL;
                        ln_line_adj_cnt     := 0;
                        lin_line_id         := NULL;
                        lin_header_id       := NULL;
                        lin_inv_item_id     := NULL;
                        ln_hdr_adj_cnt      := 0;
                        lv_location         :=
                            'Tax Class of Auto Invoice Freight Item';

                        -- For Freight, get the tx class associated with the line item

                        -- Using the customer_trx_line_id as price adjustment id and get the details

                        BEGIN
                            SELECT COUNT (1)
                              INTO ln_hdr_adj_cnt
                              FROM apps.oe_price_adjustments opa
                             WHERE     opa.list_line_type_code =
                                       'FREIGHT_CHARGE'
                                   AND TO_CHAR (price_adjustment_id) =
                                       trx_line.line_id
                                   AND line_id IS NULL
                                   AND header_id IS NOT NULL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_hdr_adj_cnt   := 0;
                                lv_ret_msg       := SUBSTR (SQLERRM, 1, 200);
                        END;

                        -- Now check, whether it is line level adjustment

                        IF ln_hdr_adj_cnt > 0
                        THEN
                            lv_item_tax_class   := 9002;
                        ELSIF ln_hdr_adj_cnt = 0
                        THEN
                            BEGIN
                                  SELECT COUNT (1), opa.line_id, opa.header_id
                                    INTO ln_line_adj_cnt, lin_line_id, lin_header_id
                                    FROM apps.oe_price_adjustments opa
                                   WHERE     opa.list_line_type_code =
                                             'FREIGHT_CHARGE'
                                         AND TO_CHAR (opa.price_adjustment_id) =
                                             trx_line.line_id
                                         AND opa.line_id IS NOT NULL
                                         AND opa.header_id IS NOT NULL
                                GROUP BY opa.line_id, opa.header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                                    ln_line_adj_cnt   := 0;
                                    lin_line_id       := NULL;
                                    lin_header_id     := NULL;
                                    lv_ret_msg        :=
                                        SUBSTR (SQLERRM, 1, 200);
                            END;
                        END IF;

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' Freight Item Tax Class as  - '
                            || lv_item_tax_class
                            || ' with ln_hdr_adj_cnt - '
                            || ln_hdr_adj_cnt
                            || ' with ln_line_adj_cnt - '
                            || ln_line_adj_cnt
                            || ' lin_line_id through price adj is '
                            || lin_line_id
                            || ' lin_header_id through price adj is '
                            || lin_line_id
                            || ' Exception if exists is - '
                            || lv_ret_msg);

                        -- When it is line level price adjustment, get the associated item


                        IF ln_line_adj_cnt > 0
                        THEN
                            lin_inv_item_id   := NULL;
                            lv_ret_msg        := NULL;

                            BEGIN
                                SELECT oola.inventory_item_id
                                  INTO lin_inv_item_id
                                  FROM apps.oe_order_lines_all oola
                                 WHERE     header_id = lin_header_id
                                       AND line_id = lin_line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lin_inv_item_id   := NULL;
                                    lv_ret_msg        :=
                                        SUBSTR (SQLERRM, 1, 200);
                            END;
                        END IF;

                        debug_prc (
                            p_batch_id,
                            'Inv Item Derivation for Freight assigned line',
                            'Inv Item Derivation for Freight assigned line',
                               ' lin_inv_item_id is   - '
                            || lin_inv_item_id
                            || ' with lin_header_id - '
                            || lin_header_id
                            || ' with lin_line_id - '
                            || lin_line_id
                            || ' and Exception if exists is - '
                            || lv_ret_msg);

                        -- Once Freight item associated line is identified, then fetch the tax class

                        IF lin_inv_item_id IS NOT NULL
                        THEN
                            lv_item_tax_class   := NULL;
                            lv_ret_msg          := NULL;
                            lv_item_tax_class   :=
                                get_item_tax_class_fnc (
                                    lin_inv_item_id,
                                    trx_line.warehouse_id,
                                    lv_ret_msg);
                            debug_prc (
                                p_batch_id,
                                'Tax Class Derivation for Freight assigned line',
                                'Tax Class Derivation for Freight assigned line',
                                   ' Tax class derived is - '
                                || lv_item_tax_class
                                || ' for lin_inv_item_id is   - '
                                || lin_inv_item_id
                                || ' with line.warehouse_id - '
                                || trx_line.warehouse_id
                                || ' and Exception if exists is - '
                                || lv_ret_msg);
                        END IF;
                    END IF;
                END IF;

                -- get the ship country fro AUTO Invoice Transactions

                -- This is applicable for OE Invoices and CM's (how to exclude drop ship orders), tag a flag

                -- Check whether the OU is eComm OU

                IF     trx_hdr.interface_header_context = 'ORDER ENTRY'
                   AND l_ecom_org_boolean = FALSE
                   AND l_drop_ship_flag = 'N'
                THEN
                    lv_location           :=
                        'Non Ecom and Non Drop Ship with Auto Inv. Trx';
                    l_nonecom_ship_from   := NULL;
                    lv_ret_msg            := NULL;

                    l_nonecom_ship_from   :=
                        get_ship_from_fnc (trx_line.warehouse_id, lv_ret_msg);

                    lv_final_ship_from    := l_nonecom_ship_from;

                    debug_prc (
                        p_batch_id,
                        'get_ship_from_fnc',
                        'get_ship_from_fnc',
                           'Value of Ship From for Non eComm and Non DS with Auto Trx  - '
                        || lv_final_ship_from
                        || ' Exception if exists is - '
                        || lv_ret_msg);
                END IF;

                -- Irrespective of Invoice Type, Few of Common details that has to be updated.

                lv_location           := 'Revenue Account';
                lv_ret_msg            := NULL;

                lv_revenue_account    :=
                    get_revenue_account_fnc (
                        pn_customer_trx_id    => trx_hdr.customer_trx_id,
                        pn_cust_trx_line_id   => trx_line.customer_trx_line_id,
                        pn_set_of_books_id    => trx_hdr.set_of_books_id,
                        pn_org_id             => trx_hdr.org_id,
                        pn_batch_id           => trx_hdr.batch_id,
                        x_ret_msg             => lv_ret_msg);



                debug_prc (
                    p_batch_id,
                    lv_procedure,
                    lv_location,
                       'Revenue Account for all Transactions  - '
                    || lv_revenue_account
                    || ' - with Customer Trx ID - '
                    || trx_hdr.customer_trx_id
                    || ' - with Customer Trx line ID - '
                    || trx_line.customer_trx_line_id
                    || ' - with set_of_books_id - '
                    || trx_hdr.set_of_books_id
                    || ' - with org_id - '
                    || trx_hdr.org_id
                    || ' Exception if exists is - '
                    || lv_ret_msg);

                lv_ret_msg            := NULL;
                ln_memo_count         :=
                    get_memo_line_desc_fnc (pv_desc     => trx_line.description,
                                            pn_org_id   => trx_hdr.org_id,
                                            x_ret_msg   => lv_ret_msg);

                lv_location           := 'Memo Line';

                IF ln_memo_count > 0
                THEN
                    lv_memo_desc   := trx_line.description;
                ELSE
                    lv_memo_desc   := NULL;
                END IF;

                debug_prc (
                    p_batch_id,
                    lv_procedure,
                    lv_location,
                       ' Getting Memo line irrespective of type if exists  - '
                    || lv_memo_desc
                    || ' - with line description - '
                    || trx_line.description
                    || ' - with org_id - '
                    || trx_hdr.org_id
                    || ' Exception if exists is - '
                    || lv_ret_msg);

                lv_cm_flag            := 'N';

                IF l_drop_ship_flag = 'N'
                THEN
                    -- Only for Ecom Orders that are Invoices/CM's ship from functionality has a impact

                    IF     trx_hdr.interface_header_context = 'ORDER ENTRY'
                       AND l_ecom_org_boolean = TRUE
                       AND trx_hdr.trx_type = 'CM'
                    THEN
                        lv_location          := 'OE eComm CM';
                        lv_cm_flag           := 'Y';
                        l_orig_ord_boolean   := NULL;
                        ln_orig_header_id    := NULL;
                        ln_orig_line_id      := NULL;
                        lv_trx_number        := NULL;
                        lv_ret_msg           := NULL;
                        l_orig_ord_boolean   :=
                            get_original_id_fnc (
                                pn_header_id   => ln_header_id,
                                pn_line_id     => trx_line.line_id,
                                x_header_id    => ln_orig_header_id,
                                x_line_id      => ln_orig_line_id,
                                x_ret_msg      => lv_ret_msg);

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' For OM eComm CM Fetched Orginal Order Header ID - '
                            || ln_orig_header_id
                            || ' - and order line ID is - '
                            || ln_orig_line_id
                            || ' Exception if exists is - '
                            || lv_ret_msg);

                        IF l_orig_ord_boolean = TRUE -- Meanimg a reference invoice exists
                        THEN
                            ld_invoice_date          := NULL;
                            ln_ship_to_site_use_id   := NULL;
                            lb_ar_ship_add_boolean   := NULL;
                            lv_location              :=
                                'OE eComm CM and GET ORIG INV DATE';
                            lv_ar_ship_country       := NULL;
                            lv_ar_ship_province      := NULL;
                            lv_exception_msg         := NULL;


                            BEGIN
                                SELECT rcta.trx_date, NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id) ship_to_site_use_id, rcta.trx_number,
                                       rctla.warehouse_id
                                  INTO ld_invoice_date, ln_ship_to_site_use_id, lv_trx_number, ln_warehouse_id
                                  FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta
                                 WHERE     1 = 1
                                       AND rcta.customer_trx_id =
                                           rctla.customer_trx_id
                                       AND rctla.interface_line_attribute6 =
                                           TO_CHAR (ln_orig_line_id)
                                       AND NVL (
                                               rctla.interface_line_attribute11,
                                               0) =
                                           0          -- Exclude discount line
                                       AND rctla.org_id = trx_hdr.org_id;


                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' ln_ship_to_site_use_id is  - '
                                    || ln_ship_to_site_use_id
                                    || ' - for Customer Trx line ID (ln_orig_line_id) is - '
                                    || ln_orig_line_id
                                    || ' - With Original Trx Number is '
                                    || lv_trx_number);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ld_invoice_date          := NULL;
                                    ln_ship_to_site_use_id   := NULL;
                                    lv_trx_number            := NULL;
                                    ln_warehouse_id          := NULL;
                                    lv_exception_msg         :=
                                        SUBSTR (SQLERRM, 1, 200);

                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           ' ln_ship_to_site_use_id is not found  - '
                                        || ln_ship_to_site_use_id
                                        || ' - for Customer Trx line ID (ln_orig_line_id) is - '
                                        || ln_orig_line_id
                                        || ' - With Error Msg as - '
                                        || lv_exception_msg);
                            END;

                            IF ln_ship_to_site_use_id IS NOT NULL
                            THEN
                                lv_ret_msg   := NULL;
                                lv_location   :=
                                    'Ship to Site use is found for Non eComm CM based on Original Trx Number';
                                lb_ar_ship_add_boolean   :=
                                    get_ship_add_fnc (
                                        pn_site_id        => ln_ship_to_site_use_id,
                                        x_ship_country    => lv_ar_ship_country,
                                        x_ship_province   =>
                                            lv_ar_ship_province,
                                        x_ret_msg         => lv_ret_msg);
                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       'Ship From Country is - '
                                    || lv_ar_ship_country
                                    || ' - Ship From Province is - '
                                    || lv_ar_ship_province
                                    || ' - For Ship Site Use ID  - '
                                    || ln_ship_to_site_use_id
                                    || ' Exception if exists is - '
                                    || lv_ret_msg);
                            ELSE
                                NULL;
                            -- use debug prc to send error as 10
                            END IF;

                            -- Start of Change as per CCR0009857

                            IF trx_hdr.orig_trx_number IS NOT NULL
                            THEN
                                lv_ar_trx_number   := trx_hdr.orig_trx_number;
                            ELSE
                                lv_ar_trx_number   := lv_trx_number;
                            END IF;
                        -- End of Change as per CCR0009857

                        END IF;
                    END IF;

                    -- For Manual Transaction (CM/DM) for Non Ecom Orgs check the reference Information, if that is NULL then
                    -- get the latest Inv. transation for that customer and place the values
                    -- Reference infomation goes into Interface_line_attribute1 column

                    lv_location   := 'Starting Non eComm Manual CM or DM';

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'l_ecom_org_boolean - '
                        -- || l_ecom_org_boolean
                        || ' - lv_batch_source_name - '
                        || lv_batch_source_name
                        || ' - trx_type  - '
                        || trx_hdr.trx_type
                        || 'interface_header_context - '
                        || trx_hdr.interface_header_context);


                    IF ((l_ecom_org_boolean = FALSE AND (l_man_boolean = TRUE OR lv_batch_source_name = 'Trade Management')) -- Added as per CCR0009857
                                                                                                                             OR (l_ecom_org_boolean = FALSE AND trx_hdr.trx_type IN ('CM', 'DM') AND trx_hdr.interface_header_context = 'ORDER ENTRY')-- End of Change as per CCR0009857
                                                                                                                                                                                                                                                      )
                    --AND trx_hdr.trx_type IN ('CM', 'DM')
                    THEN
                        lv_location                  := 'Non eComm Manual CM or DM';
                        lv_cm_flag                   := 'Y';
                        lv_ship_from                 := NULL;
                        ln_warehouse_id              := NULL;
                        ld_invoice_date              := NULL;
                        ln_ship_to_site_use_id       := NULL;
                        ln_hdr_ship_to_site_use_id   := NULL;
                        lb_ar_ship_add_boolean       := NULL;
                        lv_ar_ship_country           := NULL;
                        lv_ar_ship_province          := NULL;
                        lv_reference_line            := NULL;
                        ln_ref_trx_line_id           := NULL;
                        lv_ret_msg                   := NULL;
                        lv_ret_msg                   := NULL;

                        -- First check whether the Ship to Site use id is available on trx number

                        BEGIN
                            SELECT rctla.warehouse_id, rcta.trx_date, NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id),
                                   DECODE (lv_batch_source_name, 'Trade Management', rctla.interface_line_attribute1, trx_hdr.orig_trx_number) -- Added as per CCR0009857
                              INTO ln_warehouse_id, ld_invoice_date, ln_hdr_ship_to_site_use_id, lv_reference_line
                              FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta
                             WHERE     1 = 1
                                   AND rctla.customer_trx_id =
                                       rcta.customer_trx_id
                                   AND rctla.customer_trx_line_id =
                                       trx_line.customer_trx_line_id;

                            lv_location   :=
                                'Found Site use ID at for given invoice : Non eComm Manual CM or DM';

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Ship to Site use ID is found  - '
                                || ln_hdr_ship_to_site_use_id
                                || ' - For customer trx line Id -  '
                                || trx_line.customer_trx_line_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_hdr_ship_to_site_use_id   := NULL;
                                ln_warehouse_id              := NULL;
                                ld_invoice_date              := NULL;
                                lv_reference_line            := NULL;
                                lv_exception_msg             :=
                                       ' Ship to Site use ID is not found for Customer Trxn with Line ID: - '
                                    || trx_line.customer_trx_line_id
                                    || ' and msg is : '
                                    || SUBSTR (SQLERRM, 1, 200);
                                debug_prc (p_batch_id, lv_procedure, lv_location
                                           , lv_exception_msg);
                        END;

                        -- Added New only for Trade Management

                        IF lv_batch_source_name = 'Trade Management'
                        THEN
                            -- When batch source is TM, either populate the Ref line with Invoice Source object class value or make it as NULL
                            lv_location           :=
                                ' With TM Making Ref line as NULL';
                            lv_reference_line     := NULL;
                            ln_ref_trx_line_id    := NULL;
                            lv_tm_ship_from       := NULL;
                            lv_ret_msg            := NULL;
                            lv_tm_whname          := NULL;
                            lv_tm_trx_type        := NULL;
                            lv_tm_int_context     := NULL;
                            lv_tm_brand           := NULL;
                            ln_tm_org_id          := NULL;
                            ln_tm_warehouse_id    := NULL;
                            lv_tm_ship_from_obj   := NULL;
                            lv_tm_whname_obj      := NULL;
                            ln_tm_counter         := 0;
                            ln_tm_counter1        := 0;

                            lv_tm_ship_from       :=
                                get_ship_from_brand_fnc (trx_hdr.brand,
                                                         trx_hdr.org_id,
                                                         lv_ret_msg);

                            IF lv_tm_ship_from IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT attribute2
                                      INTO lv_tm_whname
                                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                     WHERE     ffvs.flex_value_set_id =
                                               ffvl.flex_value_set_id
                                           AND ffvs.flex_value_set_name =
                                               'XXD_AR_MTD_CNTRY_WH_VS'
                                           AND ffvl.enabled_flag = 'Y'
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                     SYSDATE
                                                                   - 1)
                                                           AND NVL (
                                                                   ffvl.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND ffvl.attribute1 =
                                               lv_tm_ship_from;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lv_tm_whname   := 'ME3';
                                    WHEN OTHERS
                                    THEN
                                        lv_tm_whname   := NULL;
                                END;
                            END IF;


                            debug_prc (
                                p_batch_id,
                                'get_ship_from_brand_fnc for TM',
                                lv_location,
                                   ' lv_tm_ship_from Outside Loop is - '
                                || lv_tm_ship_from
                                || ' lv_tm_whname is - '
                                || lv_tm_whname
                                || --' Final ln_ref_ship_from_id - '||ln_ref_ship_from_id||
                                   ' and exception if exists is - '
                                || lv_ret_msg);

                            -- Find whether it is CM or DM
                            -- If AUto Invoice, go to warehouse
                            -- If warehouse is not available then go to brand
                            -- If it is not Auto Invoice, Directly go and get the Brand

                            -- Start of Change as per CCR0009857

                            IF trx_hdr.orig_trx_number IS NOT NULL
                            THEN
                                lv_reference_line   :=
                                    trx_hdr.orig_trx_number;

                                debug_prc (
                                    p_batch_id,
                                    'Orig Trx Number is NOT NULL ',
                                    lv_location,
                                       ' trx_hdr.orig_trx_number - '
                                    || lv_reference_line
                                    || ' and exception if exists is - '
                                    || lv_ret_msg);
                            ELSE
                                BEGIN
                                    SELECT DISTINCT rcta.trx_number
                                      INTO lv_reference_line
                                      FROM apps.ozf_claim_lines_all ocla, apps.ozf_claims_all oca, apps.ra_customer_trx_all rcta
                                     WHERE     1 = 1
                                           AND oca.claim_number =
                                               trx_line.interface_line_attribute1
                                           AND ocla.claim_id = oca.claim_id
                                           AND ocla.org_id = oca.org_id
                                           AND ocla.org_id = trx_line.org_id
                                           AND rcta.trx_number =
                                               oca.attribute1
                                           AND rcta.org_id = oca.org_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_reference_line   := NULL;
                                END;
                            END IF;

                            IF lv_reference_line IS NOT NULL
                            THEN
                                ln_tm_counter1   := 1;
                                ln_tm_counter    := 1;
                            ELSE
                                -- End of Change as per CCR0009857

                                FOR tm_value
                                    IN (  SELECT -- Commented and Added as per CCR0009607
               --                                   NVL (oca.source_object_id,
            --                                          ocla.source_object_id)
                    --                                        source_object_id
                                                 DISTINCT rcta.customer_trx_id, NVL (oca.source_object_id, ocla.source_object_id) source_object_id, rcta.trx_date
                                            -- End of Change for CCR0009607
                                            FROM apps.ozf_claim_lines_all ocla, apps.ozf_claims_all oca, apps.ra_customer_trx_all rcta
                                           WHERE     1 = 1
                                                 --AND ocla.source_object_class = 'INVOICE'
                                                 AND oca.claim_number =
                                                     trx_line.interface_line_attribute1
                                                 AND ocla.claim_id =
                                                     oca.claim_id
                                                 AND ocla.org_id = oca.org_id
                                                 AND ocla.org_id =
                                                     trx_line.org_id
                                                 -- Commented and Added as per CCR0009607
                                                 AND rcta.customer_trx_id =
                                                     NVL (oca.source_object_id,
                                                          ocla.source_object_id) -- Check this Condition
                                                 --                                               --- End of Change for CCR0009607
                                                 AND rcta.org_id = oca.org_id
                                        ORDER BY rcta.trx_date DESC, -- Commented and Added as per CCR0009607
                                                                     -- NVL (oca.source_object_id,
                                                                     --      ocla.source_object_id)
                                                                     --                                                 source_object_id -- End of Change for CCR0009607
                                                                     NVL (oca.source_object_id, ocla.source_object_id) DESC)
                                LOOP
                                    --- Check the Source Obj Ref Type

                                    ln_tm_counter       := 1;
                                    ln_tm_counter1      := 0;
                                    lv_tm_trx_type      := NULL;
                                    lv_tm_int_context   := NULL;
                                    lv_tm_brand         := NULL;
                                    ln_tm_org_id        := NULL;

                                    BEGIN
                                        SELECT rctta.TYPE, rcta.interface_header_context, NVL (rcta.attribute5, hca.attribute1) brand, -- Added NVL for CCR0009103
                                               rcta.org_id
                                          INTO lv_tm_trx_type, lv_tm_int_context, lv_tm_brand, ln_tm_org_id
                                          FROM ra_cust_trx_types_all rctta, ra_customer_trx_all rcta, hz_cust_accounts hca -- Added as per CCR0009103
                                         WHERE     rctta.cust_trx_type_id =
                                                   rcta.cust_trx_type_id
                                               AND hca.cust_account_id =
                                                   rcta.bill_to_customer_id -- Added as per CCR0009103
                                               AND rcta.customer_trx_id =
                                                   tm_value.source_object_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lv_tm_trx_type      := NULL;
                                            lv_tm_int_context   := NULL;
                                            lv_tm_brand         := NULL;
                                            ln_tm_org_id        := NULL;
                                    END;

                                    -- Check if it Auto Invoice or Manual

                                    IF lv_tm_int_context = 'ORDER ENTRY'
                                    THEN
                                        ln_tm_warehouse_id   := NULL;

                                        -- Get warehouse ID and then fetch Country
                                        BEGIN
                                            SELECT DISTINCT warehouse_id
                                              INTO ln_tm_warehouse_id
                                              FROM ra_customer_trx_lines_all
                                             WHERE Customer_trx_id =
                                                   tm_value.source_object_id;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                ln_tm_warehouse_id   := NULL;
                                        END;

                                        -- Warehouse_id NOT NULL then get the  Ship from Country

                                        IF ln_tm_warehouse_id IS NOT NULL
                                        THEN
                                            lv_tm_ship_from_obj   := NULL;
                                            lv_ret_msg            := NULL;
                                            lv_tm_ship_from_obj   :=
                                                get_ship_from_fnc (
                                                    ln_tm_warehouse_id,
                                                    lv_ret_msg);
                                        ELSIF ln_tm_warehouse_id IS NULL
                                        THEN
                                            lv_tm_ship_from_obj   := NULL;
                                            lv_ret_msg            := NULL;
                                            lv_tm_ship_from_obj   :=
                                                get_ship_from_brand_fnc (
                                                    lv_tm_brand,
                                                    ln_tm_org_id,
                                                    lv_ret_msg);
                                        END IF;
                                    END IF;

                                    -- If this is not Auto Invoice or derived warehouse id is NULL, then go with the Brand Logic
                                    IF    lv_tm_int_context <> 'ORDER ENTRY'
                                       OR ln_tm_warehouse_id IS NULL
                                    THEN
                                        lv_tm_ship_from_obj   := NULL;
                                        lv_ret_msg            := NULL;
                                        lv_tm_ship_from_obj   :=
                                            get_ship_from_brand_fnc (
                                                lv_tm_brand,
                                                ln_tm_org_id,
                                                lv_ret_msg);
                                    END IF;

                                    IF lv_tm_ship_from_obj IS NOT NULL
                                    THEN
                                        lv_tm_whname_obj   := NULL;

                                        BEGIN
                                            SELECT attribute2
                                              INTO lv_tm_whname_obj
                                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                             WHERE     ffvs.flex_value_set_id =
                                                       ffvl.flex_value_set_id
                                                   AND ffvs.flex_value_set_name =
                                                       'XXD_AR_MTD_CNTRY_WH_VS'
                                                   AND ffvl.enabled_flag =
                                                       'Y'
                                                   AND SYSDATE BETWEEN NVL (
                                                                           ffvl.start_date_active,
                                                                             SYSDATE
                                                                           - 1)
                                                                   AND NVL (
                                                                           ffvl.end_date_active,
                                                                             SYSDATE
                                                                           + 1)
                                                   AND ffvl.attribute1 =
                                                       lv_tm_ship_from_obj;
                                        EXCEPTION
                                            WHEN NO_DATA_FOUND
                                            THEN
                                                lv_tm_whname_obj   := 'ME3'; --lv_tm_ship_from_obj := 'ME3';
                                            WHEN OTHERS
                                            THEN
                                                lv_tm_whname_obj   := NULL; --lv_tm_ship_from_obj := NULL;
                                        END;
                                    END IF;

                                    IF lv_tm_whname = lv_tm_whname_obj
                                    THEN
                                        ln_ref_trx_line_id   :=
                                            tm_value.source_object_id;

                                        -- Start of Change for CCR0009857

                                        ln_amount_due   := NULL;

                                        BEGIN
                                            SELECT SUM (amount_line_items_remaining) amount_due_remaining
                                              INTO ln_amount_due
                                              FROM ar_payment_schedules_all
                                             WHERE     customer_trx_id =
                                                       ln_ref_trx_line_id
                                                   AND org_id =
                                                       trx_hdr.org_id
                                                   AND status = 'OP';

                                            IF ln_amount_due >=
                                               ABS (ln_trx_amt_due)
                                            THEN
                                                ln_tm_counter1   := 1;
                                                EXIT;
                                            END IF;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                ln_amount_due   := NULL;
                                        END;
                                    -- End of Change for CCR0009857

                                    END IF;
                                END LOOP;
                            END IF;


                            IF ln_tm_counter = 1 AND ln_tm_counter1 = 0
                            THEN
                                ln_ref_trx_line_id   := NULL;

                                BEGIN
                                    SELECT source_object_id
                                      INTO ln_ref_trx_line_id
                                      FROM (  SELECT -- Commented and Added as per CCR0009607
            --                                      NVL (oca.source_object_id,
            --                                          ocla.source_object_id)
                    --                                        source_object_id
                                                     DISTINCT rcta.customer_trx_id, NVL (oca.source_object_id, ocla.source_object_id) source_object_id, rcta.trx_date
                                                -- End of Change for CCR0009607
                                                FROM apps.ozf_claim_lines_all ocla, apps.ozf_claims_all oca, apps.ra_customer_trx_all rcta
                                               WHERE     1 = 1
                                                     --AND ocla.source_object_class = 'INVOICE'
                                                     AND oca.claim_number =
                                                         trx_line.interface_line_attribute1
                                                     AND ocla.claim_id =
                                                         oca.claim_id
                                                     AND ocla.org_id =
                                                         oca.org_id
                                                     AND ocla.org_id =
                                                         trx_line.org_id
                                                     -- Commented and Added as per CCR00009607
                                                     -- CCR0009857 Change (uncommented)
                                                     AND rcta.customer_trx_id =
                                                         NVL (
                                                             oca.source_object_id,
                                                             ocla.source_object_id)
                                                     -- End of Change for CCR0009607 -- CCR0009857 Change
                                                     AND rcta.org_id =
                                                         oca.org_id
                                            ORDER BY rcta.trx_date DESC, -- Commented and Added as per CCR00009607
                                                                         NVL (oca.source_object_id, ocla.source_object_id) -- End of Change for CCR0009607
                                                                                                                           DESC)
                                     WHERE ROWNUM = 1;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_ref_trx_line_id   := NULL;
                                        lv_ret_msg           :=
                                            SUBSTR (SQLERRM, 1, 200);
                                END;
                            END IF;



                            debug_prc (
                                p_batch_id,
                                'TM Making Ref line as NULL',
                                lv_location,
                                   ' Reference line id is - '
                                || ln_ref_trx_line_id
                                || ' Reference value is - '
                                || lv_reference_line
                                || ' With batch Source as - '
                                || lv_batch_source_name
                                || ' for Claim Number - '
                                || trx_line.interface_line_attribute1
                                || ' Exception if exists is - '
                                || lv_ret_msg);
                        END IF;

                        --- When Ship to Site Use ID is NOT NULL, then get the ship to country and ship to province


                        IF     ln_hdr_ship_to_site_use_id IS NOT NULL
                           AND lv_reference_line IS NULL
                        THEN
                            lb_ar_ship_add_boolean   := NULL;
                            lv_ar_ship_country       := NULL;
                            lv_ar_ship_province      := NULL;
                            lv_ret_msg               := NULL;
                            lv_location              :=
                                ' Ship to Site use is found for Non eComm Invoice directly for Ref NULL';
                            lb_ar_ship_add_boolean   :=
                                get_ship_add_fnc (pn_site_id => ln_hdr_ship_to_site_use_id, x_ship_country => lv_ar_ship_country, x_ship_province => lv_ar_ship_province
                                                  , x_ret_msg => lv_ret_msg);
                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   'Ship From Country lv_ar_ship_country is - '
                                || lv_ar_ship_country
                                || ' - Ship From Province is - '
                                || lv_ar_ship_province
                                || ' - For Ship Site Use ID  - '
                                || ln_hdr_ship_to_site_use_id
                                || ' Exception if exists is - '
                                || lv_ret_msg);

                            --- Now get the ship from country based on Brand
                            lv_ret_msg               := NULL;
                            lv_ship_from             := NULL;
                            lv_ship_from             :=
                                get_ship_from_brand_fnc (trx_hdr.brand,
                                                         trx_hdr.org_id,
                                                         lv_ret_msg);

                            lv_final_ship_from       := lv_ship_from;

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Fetched Ship from through Brand and value is  - '
                                || lv_final_ship_from
                                || ' Exception if exists is - '
                                || lv_ret_msg);

                            IF     trx_hdr.bill_to_customer_id IS NOT NULL
                               AND trx_hdr.bill_to_site_use_id IS NOT NULL
                            THEN
                                ld_invoice_date    := NULL;
                                lv_trx_number      := NULL;
                                lv_exception_msg   := NULL;
                                lv_location        :=
                                    ' Get Inv Date and Trx Number based on Latest INV transaction ';

                                -- Now get the Tax det. date as latest transaction date

                                BEGIN
                                    SELECT trx_date, trx_number
                                      INTO ld_invoice_date, lv_trx_number
                                      FROM (  SELECT rcta.trx_date, rcta.trx_number, SUM (aps.amount_line_items_remaining) amount -- Added as per CCR0009857
                                                FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta, ra_cust_trx_types_all rctta,
                                                     ar_payment_schedules_all aps -- Added as per CCR0009857
                                               WHERE     rcta.customer_trx_id =
                                                         rctla.customer_trx_id
                                                     AND rcta.cust_trx_type_id =
                                                         rctta.cust_trx_type_id
                                                     AND rcta.org_id =
                                                         rctta.org_id
                                                     AND rctta.TYPE = 'INV'
                                                     AND rcta.interface_header_context =
                                                         'ORDER ENTRY' -- Note this condition
                                                     AND rctla.line_type =
                                                         'LINE'
                                                     AND rctta.name NOT LIKE
                                                             '%Manual%'
                                                     AND rctla.warehouse_id =
                                                         NVL (
                                                             trx_line.warehouse_id,
                                                             ln_ref_ship_from_id) -- Added as per CCR0009071
                                                     AND rcta.bill_to_customer_id =
                                                         trx_hdr.bill_to_customer_id
                                                     AND rcta.bill_to_site_use_id =
                                                         trx_hdr.bill_to_site_use_id
                                                     -- Start of Change as per CCR0009857
                                                     AND rcta.customer_trx_id =
                                                         aps.customer_trx_id
                                                     AND rcta.org_id =
                                                         aps.org_id
                                                     AND aps.status = 'OP'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM ra_customer_trx_lines_all rctla1
                                                               WHERE     rctla1.customer_trx_id =
                                                                         rctla.customer_trx_id
                                                                     AND rctla1.inventory_item_id =
                                                                         trx_line.inventory_item_id)
                                            GROUP BY rcta.trx_date, rcta.trx_number
                                              HAVING SUM (
                                                         aps.amount_line_items_remaining) >=
                                                     ABS (ln_trx_amt_due)
                                            -- End of Change as per CCR0009857
                                            ORDER BY rcta.trx_date DESC)
                                     WHERE ROWNUM = 1;

                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           ' trx date (ld_invoice_date) - '
                                        || ld_invoice_date
                                        || ' - for trxn is - '
                                        || lv_trx_number
                                        || ' - for warehouse id - '
                                        || ln_ref_ship_from_id);
                                --- Added as per CCR0009071
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        BEGIN
                                            SELECT trx_date, trx_number
                                              INTO ld_invoice_date, lv_trx_number
                                              FROM (  SELECT rcta.trx_date, rcta.trx_number, SUM (aps.amount_line_items_remaining) amount -- Added as per CCR0009857
                                                        FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta, ra_cust_trx_types_all rctta,
                                                             ar_payment_schedules_all aps
                                                       WHERE     rcta.customer_trx_id =
                                                                 rctla.customer_trx_id
                                                             AND rcta.cust_trx_type_id =
                                                                 rctta.cust_trx_type_id
                                                             AND rcta.org_id =
                                                                 rctta.org_id
                                                             AND rctta.TYPE =
                                                                 'INV'
                                                             AND rcta.interface_header_context =
                                                                 'ORDER ENTRY' -- Note this condition
                                                             AND rctla.line_type =
                                                                 'LINE'
                                                             AND rctla.warehouse_id =
                                                                 NVL (
                                                                     trx_line.warehouse_id,
                                                                     ln_ref_ship_from_id) -- Added as per CCR0009071
                                                             AND rctta.name NOT LIKE
                                                                     '%Manual%'
                                                             AND rcta.bill_to_customer_id =
                                                                 trx_hdr.bill_to_customer_id
                                                             AND rcta.bill_to_site_use_id =
                                                                 trx_hdr.bill_to_site_use_id
                                                             -- Start of Change as per CCR0009857
                                                             AND rcta.customer_trx_id =
                                                                 aps.customer_trx_id
                                                             AND rcta.org_id =
                                                                 aps.org_id
                                                             AND aps.status =
                                                                 'OP'
                                                    GROUP BY rcta.trx_date, rcta.trx_number
                                                      HAVING SUM (
                                                                 aps.amount_line_items_remaining) >=
                                                             ABS (
                                                                 ln_trx_amt_due)
                                                    -- End of Change as per CCR0009857
                                                    ORDER BY rcta.trx_date DESC)
                                             WHERE ROWNUM = 1;

                                            debug_prc (
                                                p_batch_id,
                                                lv_procedure,
                                                lv_location,
                                                   ' trx date (ld_invoice_date) - '
                                                || ld_invoice_date
                                                || ' - for trxn is - '
                                                || lv_trx_number);
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                ld_invoice_date   := NULL;
                                                lv_trx_number     := NULL;
                                                debug_prc (
                                                    p_batch_id,
                                                    lv_procedure,
                                                    lv_location,
                                                       'Transaction number is also not found, seems like there are no invoices for this with ln_ref_ship_from_id - '
                                                    || lv_exception_msg);
                                        END;
                                    -- End of Change

                                    WHEN OTHERS
                                    THEN
                                        lv_exception_msg   :=
                                            SUBSTR (SQLERRM, 1, 200);
                                        ld_invoice_date   := NULL;
                                        lv_trx_number     := NULL;
                                        debug_prc (
                                            p_batch_id,
                                            lv_procedure,
                                            lv_location,
                                               'Transaction number is also not found, seems like there are no invoices for this without ln_ref_ship_from_id - '
                                            || SUBSTR (SQLERRM, 1, 200));
                                END;

                                lv_ar_trx_number   := lv_trx_number;
                            END IF;
                        ELSIF     ln_hdr_ship_to_site_use_id IS NOT NULL
                              AND lv_reference_line IS NOT NULL
                        THEN
                            lv_location              :=
                                ' Ship to Site use is found for Non eComm Invoice directly for Ref NOT NULL ';
                            lv_ar_ship_country       := NULL;
                            lv_ar_ship_province      := NULL;
                            lb_ar_ship_add_boolean   := NULL;
                            ln_warehouse_id          := NULL;
                            lv_exception_msg         := NULL;
                            lv_ship_from             := NULL;
                            ln_ship_to_site_use_id   := NULL;
                            ld_invoice_date          := NULL;
                            lv_ret_msg               := NULL;

                            lb_ar_ship_add_boolean   :=
                                get_ship_add_fnc (pn_site_id => ln_hdr_ship_to_site_use_id, x_ship_country => lv_ar_ship_country, x_ship_province => lv_ar_ship_province
                                                  , x_ret_msg => lv_ret_msg);
                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   'Ship From Country is - '
                                || lv_ar_ship_country
                                || ' - Ship From Province is - '
                                || lv_ar_ship_province
                                || ' - For Ship Site Use ID  - '
                                || ln_hdr_ship_to_site_use_id
                                || ' Exception if exists is - '
                                || lv_ret_msg);

                            BEGIN
                                SELECT rctla.warehouse_id, rcta.trx_date, NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id)
                                  INTO ln_warehouse_id, ld_invoice_date, ln_ship_to_site_use_id
                                  FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta
                                 WHERE     rcta.trx_number =
                                           lv_reference_line
                                       AND rcta.customer_trx_id =
                                           rctla.customer_trx_id
                                       AND rctla.line_type = 'LINE'
                                       --       AND rctla.warehouse_id IS NOT NULL
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_exception_msg   :=
                                           ' Ship to Site use ID is not found : - '
                                        || SUBSTR (SQLERRM, 1, 200);
                                    debug_prc (p_batch_id, lv_procedure, lv_location
                                               , lv_exception_msg);
                            END;

                            lv_ar_trx_number         := lv_reference_line;

                            IF ln_warehouse_id IS NOT NULL
                            THEN
                                lv_ret_msg           := NULL;
                                lv_location          :=
                                    'Reference Line is Not NULL, so pull the ship from through Warehouse';
                                lv_ship_from         :=
                                    get_ship_from_fnc (ln_warehouse_id,
                                                       lv_ret_msg);

                                lv_final_ship_from   := lv_ship_from;

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Fetched Ship from through Warehouse with ref line as NOT NULL and value is  - '
                                    || lv_final_ship_from
                                    || ' Exception if exists is - '
                                    || lv_ret_msg);
                            END IF;
                        ELSIF     ln_hdr_ship_to_site_use_id IS NULL
                              AND lv_reference_line IS NOT NULL
                        THEN
                            lv_location              :=
                                'Ref is found for Non eComm CM or DM where as ship to is NULL on provided Trx.';
                            ln_warehouse_id          := NULL;
                            lv_exception_msg         := NULL;
                            lv_ship_from             := NULL;
                            ln_ship_to_site_use_id   := NULL;
                            ld_invoice_date          := NULL;

                            BEGIN
                                SELECT rctla.warehouse_id, rcta.trx_date, NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id)
                                  INTO ln_warehouse_id, ld_invoice_date, ln_ship_to_site_use_id
                                  FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta
                                 WHERE     rcta.trx_number =
                                           lv_reference_line
                                       AND rcta.customer_trx_id =
                                           rctla.customer_trx_id
                                       AND rctla.line_type = 'LINE'
                                       --       AND rctla.warehouse_id IS NOT NULL
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_exception_msg   :=
                                           ' Ship to Site use ID is not found : - '
                                        || SUBSTR (SQLERRM, 1, 200);
                                    debug_prc (p_batch_id, lv_procedure, lv_location
                                               , lv_exception_msg);
                            END;

                            IF ln_warehouse_id IS NOT NULL
                            THEN
                                lv_ret_msg           := NULL;
                                lv_ship_from         :=
                                    get_ship_from_fnc (ln_warehouse_id,
                                                       lv_ret_msg);

                                lv_final_ship_from   := lv_ship_from;

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Fetched Ship from through Warehouse with ref line as NOT NULL and value is  - '
                                    || lv_final_ship_from
                                    || ' Exception if exists is - '
                                    || lv_ret_msg);
                            END IF;

                            IF ln_ship_to_site_use_id IS NOT NULL
                            THEN
                                lv_location              :=
                                    'Ship to Site use is found for Non eComm CM or DM based on Ref line';
                                lb_ar_ship_add_boolean   := NULL;
                                lv_ar_ship_country       := NULL;
                                lv_ar_ship_province      := NULL;
                                lv_ret_msg               := NULL;

                                lb_ar_ship_add_boolean   :=
                                    get_ship_add_fnc (
                                        pn_site_id       => ln_ship_to_site_use_id,
                                        x_ship_country   => lv_ar_ship_country,
                                        x_ship_province   =>
                                            lv_ar_ship_province,
                                        x_ret_msg        => lv_ret_msg);
                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       'Ship From Country is - '
                                    || lv_ar_ship_country
                                    || ' - Ship From Province is - '
                                    || lv_ar_ship_province
                                    || ' - For Ship Site Use ID  - '
                                    || ln_ship_to_site_use_id
                                    || ' Exception if exists is - '
                                    || lv_ret_msg);
                            ELSE
                                NULL;
                            -- use debug prc to send error as 10
                            END IF;

                            lv_ar_trx_number         := lv_reference_line;
                        ELSIF     ln_hdr_ship_to_site_use_id IS NULL
                              AND lv_reference_line IS NULL
                        THEN
                            IF     trx_hdr.bill_to_customer_id IS NOT NULL
                               AND trx_hdr.bill_to_site_use_id IS NOT NULL
                            THEN
                                ln_warehouse_id          := NULL;
                                ld_invoice_date          := NULL;
                                lv_nonref_trx_number     := NULL;
                                ln_ship_to_site_use_id   := NULL;
                                lv_location              :=
                                    'Ship to Add is NULL and Ref line is not provided ';

                                BEGIN
                                    SELECT warehouse_id, trx_date, trx_number,
                                           ship_to_site_use_id
                                      INTO ln_warehouse_id, ld_invoice_date, lv_nonref_trx_number, ln_ship_to_site_use_id
                                      FROM (  SELECT rctla.warehouse_id, rcta.trx_date, rcta.trx_number,
                                                     NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id) ship_to_site_use_id, SUM (aps.amount_line_items_remaining) amount -- Added as per CCR0009857
                                                FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta, ra_cust_trx_types_all rctta,
                                                     ar_payment_schedules_all aps -- Added as per CCR0009857
                                               WHERE     rcta.customer_trx_id =
                                                         rctla.customer_trx_id
                                                     AND rcta.cust_trx_type_id =
                                                         rctta.cust_trx_type_id
                                                     AND rcta.org_id =
                                                         rctta.org_id
                                                     AND rctta.TYPE = 'INV'
                                                     AND rcta.interface_header_context =
                                                         'ORDER ENTRY' -- Note this condition
                                                     AND rctla.line_type =
                                                         'LINE'
                                                     AND rctta.name NOT LIKE
                                                             '%Manual%'
                                                     AND rctla.warehouse_id =
                                                         NVL (
                                                             trx_line.warehouse_id,
                                                             ln_ref_ship_from_id) -- Added as per CCR0009071
                                                     AND rcta.bill_to_customer_id =
                                                         trx_hdr.bill_to_customer_id
                                                     AND rcta.bill_to_site_use_id =
                                                         trx_hdr.bill_to_site_use_id
                                                     -- Start of Change as per CCR0009857
                                                     AND rcta.customer_trx_id =
                                                         aps.customer_trx_id
                                                     AND rcta.org_id =
                                                         aps.org_id
                                                     AND aps.status = 'OP'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM ra_customer_trx_lines_all rctla1
                                                               WHERE     rctla1.customer_trx_id =
                                                                         rctla.customer_trx_id
                                                                     AND rctla1.inventory_item_id =
                                                                         trx_line.inventory_item_id)
                                            GROUP BY rctla.warehouse_id, rcta.trx_date, rcta.trx_number,
                                                     NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id)
                                              HAVING SUM (
                                                         aps.amount_line_items_remaining) >=
                                                     ABS (ln_trx_amt_due)
                                            -- End of Change as per CCR0009857
                                            ORDER BY rcta.trx_date DESC)
                                     WHERE ROWNUM = 1;

                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           'Ship to Site Use ID - '
                                        || ln_ship_to_site_use_id
                                        || ' - trx date (ld_invoice_date) - '
                                        || ld_invoice_date
                                        || ' - for Non eComm CM or DM Non ref. trxn is - '
                                        || lv_nonref_trx_number);
                                --- Added as per CCR0009071

                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        BEGIN
                                            SELECT warehouse_id, trx_date, trx_number,
                                                   ship_to_site_use_id
                                              INTO ln_warehouse_id, ld_invoice_date, lv_nonref_trx_number, ln_ship_to_site_use_id
                                              FROM (  SELECT rctla.warehouse_id, rcta.trx_date, rcta.trx_number,
                                                             NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id) ship_to_site_use_id, SUM (aps.amount_line_items_remaining) amount -- -- Added as per CCR0009857
                                                        FROM ra_customer_trx_lines_all rctla, ra_customer_trx_all rcta, ra_cust_trx_types_all rctta,
                                                             ar_payment_schedules_all aps -- Added as per CCR0009857
                                                       WHERE     rcta.customer_trx_id =
                                                                 rctla.customer_trx_id
                                                             AND rcta.cust_trx_type_id =
                                                                 rctta.cust_trx_type_id
                                                             AND rcta.org_id =
                                                                 rctta.org_id
                                                             AND rctta.TYPE =
                                                                 'INV'
                                                             AND rcta.interface_header_context =
                                                                 'ORDER ENTRY' -- Note this condition
                                                             AND rctla.line_type =
                                                                 'LINE'
                                                             AND rctta.name NOT LIKE
                                                                     '%Manual%'
                                                             AND rcta.bill_to_customer_id =
                                                                 trx_hdr.bill_to_customer_id
                                                             AND rcta.bill_to_site_use_id =
                                                                 trx_hdr.bill_to_site_use_id
                                                             AND rctla.warehouse_id =
                                                                 NVL (
                                                                     trx_line.warehouse_id,
                                                                     ln_ref_ship_from_id)
                                                             -- -- Added as per CCR0009857
                                                             AND rcta.customer_trx_id =
                                                                 aps.customer_trx_id
                                                             AND rcta.org_id =
                                                                 aps.org_id
                                                             AND aps.status =
                                                                 'OP'
                                                    -- End of Change as per CCR0009857
                                                    GROUP BY rctla.warehouse_id, rcta.trx_date, rcta.trx_number,
                                                             NVL (rctla.ship_to_site_use_id, rcta.ship_to_site_use_id)
                                                      HAVING SUM (
                                                                 aps.amount_line_items_remaining) >=
                                                             ABS (
                                                                 ln_trx_amt_due) -- Added as per CCR0009857
                                                    ORDER BY rcta.trx_date DESC)
                                             WHERE ROWNUM = 1;

                                            debug_prc (
                                                p_batch_id,
                                                lv_procedure,
                                                lv_location,
                                                   ' trx date (ld_invoice_date) - '
                                                || ld_invoice_date
                                                || ' - for trxn is - '
                                                || lv_trx_number);
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                lv_exception_msg   :=
                                                    SUBSTR (SQLERRM, 1, 200);
                                                ln_ship_to_site_use_id   :=
                                                    NULL;
                                                ld_invoice_date   := NULL;
                                                lv_nonref_trx_number   :=
                                                    NULL;
                                                ln_warehouse_id   :=
                                                    NULL;
                                                debug_prc (
                                                    p_batch_id,
                                                    lv_procedure,
                                                    lv_location,
                                                       'Non Ref Transaction number is also not found, seems like there are no invoices for this - '
                                                    || lv_exception_msg);
                                        END;
                                    -- End of Change

                                    ----

                                    WHEN OTHERS
                                    THEN
                                        lv_exception_msg         :=
                                            SUBSTR (SQLERRM, 1, 200);
                                        ln_ship_to_site_use_id   := NULL;
                                        ld_invoice_date          := NULL;
                                        lv_nonref_trx_number     := NULL;
                                        ln_warehouse_id          := NULL;
                                        debug_prc (
                                            p_batch_id,
                                            lv_procedure,
                                            lv_location,
                                               'Non Ref Transaction number is also not found, seems like there are no invoices for this - '
                                            || lv_exception_msg);
                                END;

                                lv_ret_msg               := NULL;
                                lv_ship_from             :=
                                    get_ship_from_brand_fnc (
                                        pv_brand    => trx_hdr.brand,
                                        pn_org_id   => trx_hdr.org_id,
                                        x_ret_msg   => lv_ret_msg);

                                lv_final_ship_from       := lv_ship_from;

                                debug_prc (
                                    p_batch_id,
                                    lv_procedure,
                                    lv_location,
                                       ' Fetched Ship from through Brand and value is  - '
                                    || lv_final_ship_from
                                    || ' Exception if exists is - '
                                    || lv_ret_msg);


                                IF ln_ship_to_site_use_id IS NOT NULL
                                THEN
                                    lv_ar_ship_country       := NULL;
                                    lv_ar_ship_province      := NULL;
                                    lb_ar_ship_add_boolean   := NULL;
                                    lv_ret_msg               := NULL;
                                    lv_location              :=
                                        'Ship to Site use is found for Non eComm CM or DM based on Non Ref line';
                                    lb_ar_ship_add_boolean   :=
                                        get_ship_add_fnc (
                                            pn_site_id   =>
                                                ln_ship_to_site_use_id,
                                            x_ship_country   =>
                                                lv_ar_ship_country,
                                            x_ship_province   =>
                                                lv_ar_ship_province,
                                            x_ret_msg   => lv_ret_msg);
                                    debug_prc (
                                        p_batch_id,
                                        lv_procedure,
                                        lv_location,
                                           'Ship From Country is - '
                                        || lv_ar_ship_country
                                        || ' - Ship From Province is - '
                                        || lv_ar_ship_province
                                        || ' - For Ship Site Use ID  - '
                                        || ln_ship_to_site_use_id
                                        || ' Exception if exists is - '
                                        || lv_ret_msg);
                                ELSE
                                    NULL;
                                -- use debug prc to send error as 10
                                END IF;

                                lv_ar_trx_number         :=
                                    lv_nonref_trx_number;
                            END IF;
                        END IF;
                    END IF;
                END IF;

                debug_prc (p_batch_id, lv_procedure, lv_location,
                           'Final Trx Number - ' || lv_ar_trx_number);

                update_line_prc (
                    p_batch_id                  => trx_hdr.batch_id,
                    p_inv_id                    => trx_hdr.invoice_id,
                    p_line_id                   => trx_line.customer_trx_line_id,
                    p_user_element_attribute1   => lv_item_tax_class,
                    p_user_element_attribute2   => trx_line.reason_code,
                    p_user_element_attribute3   => lv_revenue_account,
                    p_user_element_attribute4   => lv_memo_desc,
                    p_user_element_attribute5   =>
                        CASE
                            WHEN lv_cm_flag = 'Y' THEN lv_ar_trx_number
                        END,
                    p_transaction_type          => 'GS',
                    p_tax_determination_date    => ld_invoice_date,
                    p_sf_country                => lv_final_ship_from,
                    p_sf_state                  =>
                        CASE
                            WHEN l_drop_ship_flag = 'Y' THEN lv_state
                        END,
                    p_sf_province               =>
                        CASE
                            WHEN l_drop_ship_flag = 'Y' THEN lv_province
                        END,
                    p_sf_postcode               =>
                        CASE
                            WHEN l_drop_ship_flag = 'Y' THEN lv_postal_code
                        END,
                    p_sf_city                   =>
                        CASE
                            WHEN l_drop_ship_flag = 'Y' THEN lv_city
                        END,
                    p_sf_geocode                =>
                        CASE
                            WHEN l_drop_ship_flag = 'Y' THEN lv_country_code
                        END,
                    p_sf_county                 =>
                        CASE
                            WHEN l_drop_ship_flag = 'Y' THEN lv_county
                        END,
                    p_st_country                =>
                        CASE
                            WHEN lv_cm_flag = 'Y' THEN lv_ar_ship_country
                        END,
                    p_st_province               =>
                        CASE
                            WHEN lv_cm_flag = 'Y' THEN lv_ar_ship_province
                        END);
            END LOOP;
        END LOOP;
    -- COMMIT;

    END xxd_ar_sbx_pre_calc_prc;

    PROCEDURE xxd_o2c_sbx_post_calc_prc (p_batch_id IN NUMBER)
    IS
    -- PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE Sabrix_Line_Tax
           SET batch_id   = batch_id * -1
         WHERE erp_tax_code = 'SUPPRESS' AND batch_id = p_batch_id;

        -- Start of Change for CCR0009103

        UPDATE Sabrix_Line_Tax slt
           SET slt.jurisdiction_text = SUBSTR (slt.jurisdiction_text, 1, 150)
         WHERE     1 = 1
               AND slt.batch_id = p_batch_id
               AND EXISTS
                       (SELECT 1
                          FROM apps.sabrix_invoice si
                         WHERE     si.invoice_id = slt.invoice_id
                               AND si.batch_id = slt.batch_id
                               AND si.calling_system_number = '222');
    -- End of Change for CCR0009103

    --COMMIT;
    END xxd_o2c_sbx_post_calc_prc;

    PROCEDURE xxd_ar_sbx_post_calc_prc (p_batch_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE Sabrix_Line_Tax
           SET batch_id   = batch_id * -1
         WHERE erp_tax_code = 'SUPPRESS' AND batch_id = p_batch_id;

        COMMIT;
    END xxd_ar_sbx_post_calc_prc;
END XXD_SBX_O2C_INT_PKG;
/
