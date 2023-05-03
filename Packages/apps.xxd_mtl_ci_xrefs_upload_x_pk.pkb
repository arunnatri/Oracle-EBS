--
-- XXD_MTL_CI_XREFS_UPLOAD_X_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_MTL_CI_XREFS_UPLOAD_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_MTL_CI_XREFS_UPLOAD_X_PK
    * Design       : This package is used for Customer Item and its cross reference upload
    * Notes        : Validate and insert
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 26-Jan-2017  1.0        Viswanathan Pandian     Web ADI for Customer Item Xref Upload
    --                                                 for CCR0005889
    ******************************************************************************************/
    --Public Subprograms
    /****************************************************************************************
    * Procedure    : CUST_ITEM_XREF_UPLOAD_PRC
    * Design       : This procedure inserts records into MTL CI interface tables
    * Notes        : Validate and insert
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 26-Jan-2017  1.0        Viswanathan Pandian     Initial Version
    ****************************************************************************************/
    PROCEDURE cust_item_xref_upload_prc (
        p_customer_number         IN hz_cust_accounts.account_number%TYPE,
        p_customer_item_number    IN mtl_customer_items.customer_item_number%TYPE,
        p_customer_item_desc      IN mtl_customer_items.customer_item_desc%TYPE,
        p_inventory_item_number   IN mtl_system_items_b.segment1%TYPE)
    IS
        ln_customer_id              oe_lines_iface_all.orig_sys_line_ref%TYPE;
        ln_inventory_item_id        xxd_common_items_v.inventory_item_id%TYPE;
        ln_master_organization_id   xxd_common_items_v.organization_id%TYPE;
        lc_cust_brand               hz_cust_accounts.attribute1%TYPE;
        lc_item_brand               xxd_common_items_v.brand%TYPE;
        lc_err_message              VARCHAR2 (4000);
        ln_exists                   NUMBER;
        le_webadi_exception         EXCEPTION;
    BEGIN
        -- Validate Customer Number
        IF p_customer_number IS NULL
        THEN
            lc_err_message   := lc_err_message || 'Customer Number is null. ';
        ELSE
            BEGIN
                SELECT cust_account_id, NVL (attribute1, -1)
                  INTO ln_customer_id, lc_cust_brand
                  FROM hz_cust_accounts
                 WHERE account_number = p_customer_number AND status = 'A';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Customer Number is invalid or inactive. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Inventory Item
        IF p_inventory_item_number IS NULL
        THEN
            lc_err_message   :=
                lc_err_message || 'Internal Item Number is null. ';
        ELSE
            BEGIN
                SELECT inventory_item_id, brand, organization_id
                  INTO ln_inventory_item_id, lc_item_brand, ln_master_organization_id
                  FROM xxd_common_items_v a
                 WHERE     customer_order_enabled_flag = 'Y'
                       AND master_org_flag = 'Y'
                       AND item_number = p_inventory_item_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Internal Item Number is invalid or inactive. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Customer and Item Brand
        IF lc_cust_brand <> lc_item_brand
        THEN
            lc_err_message   :=
                lc_err_message || 'Customer/Item Brand do not match. ';
        END IF;

        -- Validate Customer Item Number in Base Table
        IF p_customer_item_number IS NULL
        THEN
            lc_err_message   :=
                lc_err_message || 'Customer Item Number is null. ';
        ELSIF ln_customer_id IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_exists
              FROM mtl_customer_items mci
             WHERE     mci.customer_item_number = p_customer_item_number
                   AND mci.customer_id = ln_customer_id;

            IF ln_exists > 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Customer Item Number already exist for this Customer Number. ';
            ELSE
                -- Validate Customer Item Number in Interface Table
                IF p_customer_item_number IS NOT NULL
                THEN
                    SELECT COUNT (1)
                      INTO ln_exists
                      FROM mtl_ci_interface
                     WHERE     customer_item_number = p_customer_item_number
                           AND process_mode = 1;

                    IF ln_exists > 0
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'Customer Item Number already exist in Interface Table. ';
                    END IF;
                END IF;
            END IF;
        END IF;

        -- Validate Customer Item Number Size
        IF     p_customer_item_number IS NOT NULL
           AND LENGTH (p_customer_item_number) > 50
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Customer Item Number size is more than 50. ';
        END IF;


        IF lc_err_message IS NULL
        THEN
            -- Insert Records
            INSERT INTO apps.mtl_ci_interface (process_flag,
                                               process_mode,
                                               lock_flag,
                                               last_updated_by,
                                               last_update_date,
                                               last_update_login,
                                               created_by,
                                               creation_date,
                                               transaction_type,
                                               customer_number,
                                               customer_item_number,
                                               item_definition_level_desc,
                                               customer_item_desc,
                                               commodity_code,
                                               inactive_flag)
                 VALUES ('1', 1, '1',
                         gn_user_id, gd_sysdate, gn_login_id,
                         gn_user_id, gd_sysdate, 'CREATE',
                         p_customer_number, p_customer_item_number, 'Customer'
                         , p_customer_item_desc, lc_item_brand, '2');

            INSERT INTO apps.mtl_ci_xrefs_interface (transaction_type, customer_number, customer_item_number, item_definition_level_desc, inventory_item_segment1, master_organization_id, preference_number, process_flag, process_mode, lock_flag, inactive_flag, last_updated_by, last_update_login, created_by, creation_date
                                                     , last_update_date)
                 VALUES ('CREATE', p_customer_number, p_customer_item_number,
                         'Customer', p_inventory_item_number, ln_master_organization_id, 1, '1', 1, '1', '2', gn_user_id, gn_login_id, gn_user_id, gd_sysdate
                         , gd_sysdate);
        ELSE
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20000, lc_err_message);
        WHEN OTHERS
        THEN
            lc_err_message   := SQLERRM;
            raise_application_error (-20001, lc_err_message);
    END cust_item_xref_upload_prc;

    /****************************************************************************************
    * Procedure    : RUN_IMPORT_CUST_ITEM_PRC
    * Design       : This procedure submits "Import Customer Items - Deckers" Request Set
    * Notes        : This is called from WebADI
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 26-Jan-2017  1.0        Viswanathan Pandian     Initial Version
    ****************************************************************************************/
    PROCEDURE run_import_cust_item_prc
    IS
        lc_err_message         VARCHAR2 (4000);
        lb_set_mode            BOOLEAN := FALSE;
        lb_request_set         BOOLEAN := FALSE;
        lb_conc_stg_1          BOOLEAN := FALSE;
        lb_conc_stg_2          BOOLEAN := FALSE;
        lb_conc_stg_3          BOOLEAN := FALSE;
        lb_set_layout          BOOLEAN := FALSE;
        ln_request_id          NUMBER;
        ln_org_id              NUMBER := fnd_global.org_id;
        ln_responsibility_id   NUMBER;
        ln_application_id      NUMBER;
        le_webadi_exception    EXCEPTION;
    BEGIN
        mo_global.init ('INV');
        mo_global.set_policy_context ('S', ln_org_id);

        SELECT responsibility_id, application_id
          INTO ln_responsibility_id, ln_application_id
          FROM fnd_responsibility_vl
         WHERE responsibility_id = fnd_global.resp_id;

        fnd_global.apps_initialize (gn_user_id,
                                    ln_responsibility_id,
                                    ln_application_id);

        lb_set_mode   := fnd_submit.set_mode (FALSE);

        IF lb_set_mode
        THEN
            lb_request_set   :=
                fnd_submit.set_request_set (
                    application   => 'XXDO',
                    request_set   => 'XXD_IMP_CUST_ITEMS');

            IF lb_request_set
            THEN
                lb_conc_stg_1   :=
                    fnd_submit.submit_program (
                        application   => 'INV',
                        program       => 'INVCIINT',
                        stage         => 'IMP_CUST_ITEMS',
                        argument1     => 'N',                -- Abort On Error
                        argument2     => 'N');                -- Delete Record

                IF lb_conc_stg_1
                THEN
                    lb_conc_stg_2   :=
                        fnd_submit.submit_program (
                            application   => 'INV',
                            program       => 'INVCIINTX',
                            stage         => 'IMP_ITEM_XREF',
                            argument1     => 'N',            -- Abort On Error
                            argument2     => 'N');           -- Delete Records

                    IF lb_conc_stg_2
                    THEN
                        lb_set_layout   :=
                            fnd_submit.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        =>
                                    'XXD_CUST_ITEM_EXCP_RPT',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'EXCEL');

                        IF lb_set_layout
                        THEN
                            lb_conc_stg_3   :=
                                fnd_submit.submit_program (
                                    application   => 'XXDO',
                                    program       => 'XXD_CUST_ITEM_EXCP_RPT',
                                    stage         => 'CUST_ITEM_EXEP_RPT');

                            IF lb_conc_stg_3
                            THEN
                                ln_request_id   :=
                                    fnd_submit.submit_set (
                                        start_time    => NULL,
                                        sub_request   => FALSE);

                                IF NVL (ln_request_id, 0) = 0
                                THEN
                                    lc_err_message   :=
                                        'Reqest Set Failed: Import Customer Items - Deckers';
                                    RAISE le_webadi_exception;
                                END IF;
                            ELSE
                                lc_err_message   :=
                                    'Request Set Stage 3 Failed';
                                RAISE le_webadi_exception;
                            END IF;
                        ELSE
                            lc_err_message   :=
                                'Request Add Template Layout Failed';
                            RAISE le_webadi_exception;
                        END IF;
                    ELSE
                        lc_err_message   := 'Request Set Stage 2 Failed';
                        RAISE le_webadi_exception;
                    END IF;
                ELSE
                    lc_err_message   := 'Request Set Stage 1 Failed';
                    RAISE le_webadi_exception;
                END IF;
            ELSE
                lc_err_message   := 'Submit Request Set Failed';
                RAISE le_webadi_exception;
            END IF;
        ELSE
            lc_err_message   := 'Request Set Mode Failed';
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            raise_application_error (-20000, lc_err_message);
        WHEN OTHERS
        THEN
            lc_err_message   := SQLERRM;
            raise_application_error (-20000, lc_err_message);
    END run_import_cust_item_prc;

    /****************************************************************************************
    * Procedure    : DELETE_INTERFACE_RECORDS_FNC
    * Design       : This function will delete interface records of 10 or more days old
    * Notes        : This is called from "Customer Item Import Exception Report - Deckers"
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 26-Jan-2017  1.0        Viswanathan Pandian     Initial Version
    ****************************************************************************************/
    FUNCTION delete_interface_records_fnc
        RETURN BOOLEAN
    IS
    BEGIN
        DELETE mtl_ci_interface
         WHERE TRUNC (creation_date) <= TRUNC (SYSDATE) - 10;

        DELETE mtl_ci_xrefs_interface
         WHERE TRUNC (creation_date) <= TRUNC (SYSDATE) - 10;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END delete_interface_records_fnc;
END xxd_mtl_ci_xrefs_upload_x_pk;
/
