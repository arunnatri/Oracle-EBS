--
-- XXD_INV_UPC_UPLOAD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_UPC_UPLOAD_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_INV_UPC_UPLOAD_PKG
    * Design       : This package is used for uploading UPC Codes for Items
    * Notes        :
    * Modification :
    -- =======================================================================================
    -- Date         Version#   Name                    Comments
    -- =======================================================================================
    -- 10-Dec-2019  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE upload_prc (p_trans_type IN VARCHAR2, p_item_number IN VARCHAR2, p_upc_code IN VARCHAR2)
    AS
        CURSOR get_items_c (p_inventory_item_id IN NUMBER)
        IS
            SELECT msib.inventory_item_id, msib.organization_id, LPAD (TRIM (p_upc_code), 14, 0) upc_code,
                   NULL cross_reference_id
              FROM mtl_system_items_b msib
             WHERE     msib.inventory_item_id = p_inventory_item_id
                   AND TRIM (p_trans_type) = 'CREATE'
            UNION
            SELECT msib.inventory_item_id, msib.organization_id, LPAD (TRIM (p_upc_code), 14, 0) upc_code,
                   mcrb.cross_reference_id
              FROM mtl_system_items_b msib, mtl_cross_references_b mcrb
             WHERE     msib.inventory_item_id = mcrb.inventory_item_id
                   AND msib.organization_id = mcrb.organization_id
                   AND mcrb.cross_reference_type = 'UPC Cross Reference'
                   AND TRIM (p_trans_type) = 'UPDATE'
                   AND msib.inventory_item_id = p_inventory_item_id;

        lc_message_list         error_handler.error_tbl_type;
        l_xref_tbl              mtl_cross_references_pub.xref_tbl_type;
        ln_master_org_id        mtl_cross_references_b.organization_id%TYPE;
        ln_inventory_item_id    mtl_system_items_b.inventory_item_id%TYPE;
        ln_user_id              mtl_cross_references_b.created_by%TYPE
                                    := fnd_global.user_id;
        ln_cross_reference_id   mtl_cross_references_b.cross_reference_id%TYPE;
        ln_msg_count            NUMBER := 0;
        ln_upc_length           NUMBER := 0;
        ln_index                NUMBER := 0;
        ln_exists               NUMBER := 0;
        lc_return_status        VARCHAR2 (4000);
        lc_err_message          VARCHAR2 (4000);
        lc_ret_message          VARCHAR2 (4000);
        le_webadi_exception     EXCEPTION;
    BEGIN
        --Derive Master Org ID
        BEGIN
            SELECT organization_id
              INTO ln_master_org_id
              FROM mtl_parameters
             WHERE organization_code = 'MST';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_err_message   :=
                    lc_err_message || 'Unable to derive Master Org ID. ';
            WHEN OTHERS
            THEN
                lc_err_message   := 'Derive Master Org ID Error' || SQLERRM;
        END;

        -- Validate Inventory Item
        IF ln_master_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT inventory_item_id
                  INTO ln_inventory_item_id
                  FROM mtl_system_items_b
                 WHERE     segment1 = TRIM (p_item_number)
                       AND organization_id = ln_master_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Invalid Inventory Item. ';
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Validate Inventory Item Error: '
                        || SQLERRM;
            END;
        END IF;

        -- Validate if SKU is Licensed
        IF ln_inventory_item_id IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_exists
              FROM xxdo.xxdo_plm_staging
             WHERE     attribute3 = 'Y'
                   AND record_id =
                       (SELECT MAX (record_id)
                          FROM xxdo.xxdo_plm_staging
                         WHERE style || '-' || colorway =
                                  REGEXP_SUBSTR (TRIM (p_item_number), '[^-]+', 1
                                                 , 1)
                               || '-'
                               || REGEXP_SUBSTR (TRIM (p_item_number), '[^-]+', 1
                                                 , 2));

            IF ln_exists = 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'This is not a licensee product. Please contact IT for this request. ';
            END IF;
        END IF;

        -- Verify UPC Code to be numeric
        BEGIN
            SELECT TO_NUMBER (TRIM (p_upc_code)) INTO ln_upc_length FROM DUAL;

            -- Validate UPC Code Length
            BEGIN
                SELECT LENGTH (TRIM (p_upc_code))
                  INTO ln_upc_length
                  FROM DUAL;

                IF ln_upc_length <> 12
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'UPC Code should be 12 characters. ';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        lc_err_message || 'UPC Length Error: ' || SQLERRM;
            END;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'UPC Code should be numeric. ';
        END;

        -- Validate UPC Code for Item
        IF ln_inventory_item_id IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_exists
              FROM mtl_cross_references_b
             WHERE     cross_reference_type = 'UPC Cross Reference'
                   AND inventory_item_id = ln_inventory_item_id;

            IF ln_exists > 0 AND TRIM (p_trans_type) = 'CREATE'
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'UPC already exists for this item. Please use UPDATE transaction type to update them.';
            ELSIF ln_exists = 0 AND TRIM (p_trans_type) = 'UPDATE'
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Cross reference does not exists for this item. Please use CREATE transcation type to create them.';
            END IF;
        END IF;

        -- Validate UPC Code
        SELECT COUNT (1)
          INTO ln_exists
          FROM mtl_cross_references_b
         WHERE     cross_reference_type = 'UPC Cross Reference'
               AND cross_reference = LPAD (TRIM (p_upc_code), 14, 0);

        IF ln_exists > 0
        THEN
            lc_err_message   := lc_err_message || 'This UPC already exists. ';
        END IF;

        -- Process UPC if no error
        IF lc_err_message IS NULL
        THEN
            lc_message_list.delete;
            l_xref_tbl.delete;
            lc_return_status   := NULL;
            ln_index           := 0;
            ln_msg_count       := 0;

            fnd_global.apps_initialize (ln_user_id,
                                        fnd_global.resp_id,
                                        fnd_global.resp_appl_id);

            FOR items_rec IN get_items_c (ln_inventory_item_id)
            LOOP
                ln_index                                     := ln_index + 1;
                l_xref_tbl (ln_index).transaction_type       :=
                    TRIM (p_trans_type);

                IF items_rec.cross_reference_id IS NULL
                THEN
                    l_xref_tbl (ln_index).inventory_item_id   :=
                        items_rec.inventory_item_id;
                    l_xref_tbl (ln_index).organization_id   :=
                        items_rec.organization_id;
                    l_xref_tbl (ln_index).cross_reference_type   :=
                        'UPC Cross Reference';
                ELSE
                    l_xref_tbl (ln_index).cross_reference_id   :=
                        items_rec.cross_reference_id;
                    l_xref_tbl (ln_index).last_update_date   := SYSDATE;
                    l_xref_tbl (ln_index).last_updated_by    := ln_user_id;
                END IF;

                l_xref_tbl (ln_index).cross_reference        :=
                    items_rec.upc_code;
                l_xref_tbl (ln_index).org_independent_flag   := 'N';
            END LOOP;

            mtl_cross_references_pub.process_xref (
                p_api_version     => 1.0,
                p_init_msg_list   => fnd_api.g_true,
                p_commit          => fnd_api.g_false,
                p_xref_tbl        => l_xref_tbl,
                x_return_status   => lc_return_status,
                x_msg_count       => ln_msg_count,
                x_message_list    => lc_message_list);

            IF lc_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR i IN 1 .. lc_message_list.COUNT
                LOOP
                    lc_err_message   :=
                        SUBSTR (
                               lc_err_message
                            || lc_message_list (i).MESSAGE_TEXT,
                            1,
                            2000);
                END LOOP;

                RAISE le_webadi_exception;
            ELSE
                BEGIN
                    UPDATE mtl_system_items_b
                       SET attribute11 = TRIM (p_upc_code), last_update_date = SYSDATE, last_updated_by = ln_user_id
                     WHERE inventory_item_id = ln_inventory_item_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_err_message   := SQLERRM;
                        RAISE le_webadi_exception;
                END;
            END IF;
        ELSE
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_ret_message   := fnd_message.get ();
            raise_application_error (-20000, lc_ret_message);
        WHEN OTHERS
        THEN
            lc_ret_message   := SQLERRM;
            raise_application_error (-20001, lc_ret_message);
    END upload_prc;
END xxd_inv_upc_upload_pkg;
/
