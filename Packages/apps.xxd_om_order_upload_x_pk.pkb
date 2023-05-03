--
-- XXD_OM_ORDER_UPLOAD_X_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_om_order_upload_x_pk
AS
    /******************************************************************************************
    -- Modification History:
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 25-Feb-2015  1.0        BT Technology Team      Created for Order Upload WebADI
    ******************************************************************************************/
    PROCEDURE printmessage (p_msgtoken IN VARCHAR2)
    IS
    BEGIN
        IF p_msgtoken IS NOT NULL
        THEN
            NULL;
        END IF;

        RETURN;
    END printmessage;

    --Global Variables
    --Private Subprograms
    /****************************************************************************************
    * Function     : GET_SITE_ORG_ID_FNC
    * Design       : This function return the SITE_USE_ID of the location
    * Notes        :
    * Return Values: site_use_id
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 25-Feb-2015  1.0        BT Technology Team      Initial Version
    ****************************************************************************************/
    FUNCTION get_site_org_id_fnc (p_cust_account IN oe_headers_iface_all.customer_number%TYPE, p_site_use_code IN hz_cust_site_uses_all.site_use_code%TYPE, p_location IN oe_headers_iface_all.ship_to_org%TYPE)
        RETURN NUMBER
    AS
        ln_site_org_id   hz_cust_site_uses_all.site_use_id%TYPE;

        CURSOR get_brand_location_c IS
            SELECT hcsu.site_use_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_code = p_site_use_code
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcsu.status = 'A'
                   AND hca.account_number = p_cust_account
                   AND hcsu.location = p_location;

        CURSOR get_legacy_ship_to_c IS
            SELECT hcsu.site_use_id
              FROM (SELECT NVL (hcar.related_cust_account_id, hca.cust_account_id) related_cust_account_id, hca.status, hca.cust_account_id
                      FROM hz_cust_accounts hca, hz_cust_acct_relate_all hcar
                     WHERE     hca.cust_account_id = hcar.cust_account_id(+)
                           AND hcar.status(+) = 'A'
                           AND hca.account_number = p_cust_account) hca,
                   hz_cust_acct_sites_all hcas,
                   hz_cust_site_uses_all hcsu,
                   hz_party_sites party_site,
                   hz_locations loc
             WHERE     hca.related_cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_code = p_site_use_code
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcsu.status = 'A'
                   AND hcsu.location = p_location;
    BEGIN
        OPEN get_brand_location_c;

        FETCH get_brand_location_c INTO ln_site_org_id;

        CLOSE get_brand_location_c;

        IF ln_site_org_id IS NULL AND p_site_use_code = 'SHIP_TO'
        THEN
            OPEN get_legacy_ship_to_c;

            FETCH get_legacy_ship_to_c INTO ln_site_org_id;

            CLOSE get_legacy_ship_to_c;
        END IF;

        RETURN ln_site_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_brand_location_c%ISOPEN
            THEN
                CLOSE get_brand_location_c;
            END IF;

            IF get_legacy_ship_to_c%ISOPEN
            THEN
                CLOSE get_legacy_ship_to_c;
            END IF;

            RETURN NULL;
    END get_site_org_id_fnc;

    --Public Subprograms
    /****************************************************************************************
    * Procedure    : ORDER_UPLOAD_PRC
    * Design       : This procedure inserts records into OE interface tables
    * Notes        : GT will hold the header sequence value for both interface tables
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 25-Feb-2015  1.0        BT Technology Team      Initial Version
    ****************************************************************************************/
    PROCEDURE order_upload_prc (
        p_order_source_id         IN oe_order_sources.order_source_id%TYPE,
        p_order_type              IN oe_order_types_v.name%TYPE,
        p_orig_sys_document_ref   IN oe_headers_iface_all.orig_sys_document_ref%TYPE,
        p_user_id                 IN fnd_user.user_id%TYPE,
        p_creation_date           IN oe_headers_iface_all.creation_date%TYPE,
        p_request_date            IN oe_headers_iface_all.request_date%TYPE,
        p_operation_code          IN oe_headers_iface_all.operation_code%TYPE,
        p_booked_flag             IN oe_headers_iface_all.booked_flag%TYPE,
        p_customer_number         IN oe_headers_iface_all.customer_number%TYPE,
        p_customer_po_number      IN oe_headers_iface_all.customer_po_number%TYPE,
        p_price_list              IN oe_headers_iface_all.price_list%TYPE,
        p_ship_from_org           IN oe_headers_iface_all.ship_from_org%TYPE,
        p_ship_to_org             IN oe_headers_iface_all.ship_to_org%TYPE,
        p_invoice_to_org          IN oe_headers_iface_all.invoice_to_org%TYPE,
        p_cancel_date             IN DATE,
        p_brand                   IN oe_headers_iface_all.attribute5%TYPE,
        p_orig_sys_line_ref       IN oe_lines_iface_all.orig_sys_line_ref%TYPE,
        p_inventory_item          IN oe_lines_iface_all.inventory_item%TYPE,
        p_ordered_quantity        IN oe_lines_iface_all.ordered_quantity%TYPE,
        p_line_request_date       IN oe_lines_iface_all.request_date%TYPE,
        p_unit_selling_price      IN oe_lines_iface_all.unit_selling_price%TYPE,
        p_subinventory            IN oe_lines_iface_all.subinventory%TYPE)
    IS
        ln_org_id              NUMBER := fnd_global.org_id;
        ln_item_id             NUMBER;
        ln_inv_org_id          NUMBER;

        CURSOR get_header_records_c IS
            SELECT DISTINCT order_source_id, order_type, orig_sys_document_ref,
                            created_by, creation_date, last_updated_by,
                            last_update_date, header_request_date, operation_code,
                            booked_flag, customer_number, customer_po_number,
                            price_list, ship_from_org, ship_to_org_id,
                            invoice_to_org_id, cancel_date, brand
              FROM xxdo.xxd_om_order_upload_gt xooug
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM oe_headers_iface_all ohia
                         WHERE ohia.orig_sys_document_ref =
                               xooug.orig_sys_document_ref);

        CURSOR get_line_records_c IS
            SELECT DISTINCT order_source_id, orig_sys_document_ref, orig_sys_line_ref,
                            inventory_item, ordered_quantity, line_request_date,
                            created_by, creation_date, last_updated_by,
                            last_update_date, ship_from_org, cancel_date,
                            unit_selling_price, subinventory
              FROM xxdo.xxd_om_order_upload_gt xooug
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM oe_lines_iface_all olia
                         WHERE olia.orig_sys_line_ref =
                               xooug.orig_sys_line_ref);

        lc_orig_sys_line_ref   oe_lines_iface_all.orig_sys_line_ref%TYPE;
        ln_ship_to_org_id      oe_headers_iface_all.ship_to_org_id%TYPE;
        ln_invoice_to_org_id   oe_headers_iface_all.invoice_to_org_id%TYPE;
        l_err_message          VARCHAR2 (4000) := NULL;
        l_ret_message          VARCHAR2 (4000) := NULL;
        ln_cust_account_id     NUMBER;
        ln_exists              NUMBER;
        le_webadi_exception    EXCEPTION;
    BEGIN
        printmessage ('p_order_source_id ' || p_order_source_id);
        printmessage ('p_order_type ' || p_order_type);
        printmessage ('p_orig_sys_document_ref ' || p_orig_sys_document_ref);
        printmessage ('p_user_id ' || p_user_id);
        printmessage ('p_creation_date ' || p_creation_date);
        printmessage ('p_request_date ' || p_request_date);
        printmessage ('p_operation_code ' || p_operation_code);
        printmessage ('p_booked_flag ' || p_booked_flag);
        printmessage ('p_customer_number ' || p_customer_number);
        printmessage ('p_customer_po_number ' || p_customer_po_number);
        printmessage ('p_price_list ' || p_price_list);
        printmessage ('p_ship_from_org ' || p_ship_from_org);
        printmessage ('p_ship_to_org ' || p_ship_to_org);
        printmessage ('p_invoice_to_org ' || p_invoice_to_org);
        printmessage ('p_cancel_date ' || p_cancel_date);
        printmessage ('p_brand ' || p_brand);
        printmessage ('p_orig_sys_line_ref ' || p_orig_sys_line_ref);
        printmessage ('p_inventory_item ' || p_inventory_item);
        printmessage ('p_ordered_quantity ' || p_ordered_quantity);
        printmessage ('p_line_request_date ' || p_line_request_date);
        printmessage ('p_unit_selling_price ' || p_unit_selling_price);
        printmessage ('p_subinventory ' || p_subinventory);
        printmessage (
            'MFG_ORGANIZATION_ID:' || fnd_profile.VALUE ('MFG_ORGANIZATION_ID'));

        IF p_brand IS NULL
        THEN
            l_err_message   := 'Brand cannot be null. ';
        END IF;

        ln_cust_account_id   := NULL;

        IF p_customer_number IS NULL
        THEN
            l_err_message   :=
                l_err_message || 'Customer number cannot be null. ';
        ELSE
            BEGIN
                SELECT cust_account_id
                  INTO ln_cust_account_id
                  FROM hz_cust_accounts
                 WHERE     NVL (attribute1, -1) = p_brand
                       AND account_number = p_customer_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'Customer number is not associated with the brand provided. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF p_order_type IS NULL
        THEN
            l_err_message   := l_err_message || 'Order Type cannot be null. ';
        END IF;

        IF p_ship_from_org IS NULL
        THEN
            l_err_message   := l_err_message || 'Warehouse cannot be null. ';
        ELSE
            BEGIN
                SELECT organization_id
                  INTO ln_inv_org_id
                  FROM mtl_parameters
                 WHERE organization_code = p_ship_from_org;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   := l_err_message || 'Invalid Warehouse. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF p_inventory_item IS NULL
        THEN
            l_err_message   := l_err_message || 'SKU cannot be null. ';
        ELSE
            BEGIN
                SELECT inventory_item_id
                  INTO ln_item_id
                  FROM mtl_system_items_b a
                 WHERE     organization_id = ln_inv_org_id
                       AND segment1 = p_inventory_item;

                IF ln_item_id IS NOT NULL AND p_brand IS NOT NULL
                THEN
                    BEGIN
                        SELECT 1
                          INTO ln_exists
                          FROM xxd_common_items_v
                         WHERE     organization_id = ln_inv_org_id
                               AND inventory_item_id = ln_item_id
                               AND brand = p_brand;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            l_err_message   :=
                                   l_err_message
                                || 'Customer/SKU Brand do not match. ';
                        WHEN OTHERS
                        THEN
                            l_err_message   := l_err_message || SQLERRM;
                    END;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                        l_err_message || 'SKU is not assigned to Warehouse. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF p_subinventory IS NOT NULL AND ln_inv_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT 1
                  INTO ln_exists
                  FROM mtl_secondary_inventories
                 WHERE     secondary_inventory_name = p_subinventory
                       AND organization_id = ln_inv_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'Subinventory is not valid for this Warehouse. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF p_ship_to_org IS NOT NULL
        THEN
            ln_ship_to_org_id   :=
                get_site_org_id_fnc (p_customer_number,
                                     'SHIP_TO',
                                     p_ship_to_org);

            IF ln_ship_to_org_id IS NULL
            THEN
                l_err_message   :=
                    l_err_message || 'Ship to location is invalid. ';
            END IF;
        END IF;

        IF p_invoice_to_org IS NOT NULL
        THEN
            ln_invoice_to_org_id   :=
                get_site_org_id_fnc (p_customer_number,
                                     'BILL_TO',
                                     p_invoice_to_org);

            IF ln_invoice_to_org_id IS NULL
            THEN
                l_err_message   :=
                    l_err_message || 'Bill to location is invalid. ';
            END IF;
        END IF;

        printmessage ('ln_ship_to_org_id ' || ln_ship_to_org_id);
        printmessage ('p_invoice_to_org ' || p_invoice_to_org);


        IF l_err_message IS NULL
        THEN
            SELECT 'DO_OE_LINE_UPLOAD_' || xxd_om_upload_oe_line_s.NEXTVAL
              INTO lc_orig_sys_line_ref
              FROM DUAL;

            printmessage ('lc_orig_sys_line_ref' || lc_orig_sys_line_ref);


            -- Insert into Staging Table

            INSERT INTO xxdo.xxd_om_order_upload_gt (order_source_id,
                                                     order_type,
                                                     orig_sys_document_ref,
                                                     orig_sys_line_ref,
                                                     inventory_item,
                                                     ordered_quantity,
                                                     created_by,
                                                     creation_date,
                                                     last_updated_by,
                                                     last_update_date,
                                                     header_request_date,
                                                     line_request_date,
                                                     operation_code,
                                                     booked_flag,
                                                     customer_number,
                                                     customer_po_number,
                                                     price_list,
                                                     ship_from_org,
                                                     ship_to_org_id,
                                                     invoice_to_org_id,
                                                     cancel_date,
                                                     brand,
                                                     unit_selling_price,
                                                     subinventory)
                 VALUES (p_order_source_id, p_order_type, p_orig_sys_document_ref, lc_orig_sys_line_ref, p_inventory_item, p_ordered_quantity, p_user_id, SYSDATE, --p_creation_date,
                                                                                                                                                                   p_user_id, SYSDATE, --p_creation_date,
                                                                                                                                                                                       p_request_date, NVL (p_line_request_date, p_request_date), p_operation_code, p_booked_flag, p_customer_number, p_customer_po_number, p_price_list, p_ship_from_org, ln_ship_to_org_id, ln_invoice_to_org_id, p_cancel_date
                         , p_brand, p_unit_selling_price, p_subinventory);

            printmessage ('count ' || SQL%ROWCOUNT);

            -- Insert Header Records
            FOR lcu_header_records_rec IN get_header_records_c
            LOOP
                INSERT INTO oe_headers_iface_all (order_source_id, order_type, orig_sys_document_ref, created_by, creation_date, last_updated_by, last_update_date, request_date, operation_code, booked_flag, customer_number, sold_to_org, customer_po_number, price_list, ship_from_org, ship_to_org_id, invoice_to_org_id, attribute1
                                                  , attribute5, org_id)
                     VALUES (lcu_header_records_rec.order_source_id, lcu_header_records_rec.order_type, lcu_header_records_rec.orig_sys_document_ref, lcu_header_records_rec.created_by, lcu_header_records_rec.creation_date, lcu_header_records_rec.last_updated_by, lcu_header_records_rec.last_update_date, lcu_header_records_rec.header_request_date, lcu_header_records_rec.operation_code, lcu_header_records_rec.booked_flag, lcu_header_records_rec.customer_number, NULL, --ln_cust_account_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     lcu_header_records_rec.customer_po_number, lcu_header_records_rec.price_list, lcu_header_records_rec.ship_from_org, lcu_header_records_rec.ship_to_org_id, lcu_header_records_rec.invoice_to_org_id, fnd_date.date_to_canonical (lcu_header_records_rec.cancel_date)
                             , lcu_header_records_rec.brand, ln_org_id);

                printmessage ('count 1' || SQL%ROWCOUNT);
            END LOOP;


            -- Insert Line Records
            FOR lcu_line_records_rec IN get_line_records_c
            LOOP
                INSERT INTO oe_lines_iface_all (order_source_id, orig_sys_document_ref, orig_sys_line_ref, inventory_item, INVENTORY_ITEM_ID, ordered_quantity, request_date, created_by, creation_date, last_updated_by, last_update_date, ship_from_org, attribute1, unit_selling_price, subinventory
                                                , org_id)
                     VALUES (lcu_line_records_rec.order_source_id, lcu_line_records_rec.orig_sys_document_ref, lcu_line_records_rec.orig_sys_line_ref, lcu_line_records_rec.inventory_item, ln_item_id, lcu_line_records_rec.ordered_quantity, lcu_line_records_rec.line_request_date, lcu_line_records_rec.created_by, lcu_line_records_rec.creation_date, lcu_line_records_rec.last_updated_by, lcu_line_records_rec.last_update_date, lcu_line_records_rec.ship_from_org, fnd_date.date_to_canonical (lcu_line_records_rec.cancel_date), lcu_line_records_rec.unit_selling_price, lcu_line_records_rec.subinventory
                             , ln_org_id);
            END LOOP;

            printmessage ('count 3 ' || SQL%ROWCOUNT);
        ELSE
            printmessage ('RAISE exception: ' || l_err_message);
            RAISE le_webadi_exception;
            printmessage ('Complete order_upload_prc');
        END IF;

        printmessage ('End order_upload_prc');
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_err_message);
            l_ret_message   := fnd_message.get ();
            printmessage ('l_ret_message: ' || l_ret_message);
            raise_application_error (-20000, l_ret_message);
        WHEN OTHERS
        THEN
            l_ret_message   := SQLERRM;
            printmessage ('l_ret_message err: ' || l_ret_message);
            raise_application_error (-20001, l_ret_message);
    END order_upload_prc;

    PROCEDURE run_order_import_prc
    IS
        ln_request_id              NUMBER;
        ln_req_id                  NUMBER;
        ln_count                   NUMBER;
        lv_dummy                   VARCHAR2 (100);
        lx_dummy                   VARCHAR2 (250);
        lv_dphase                  VARCHAR2 (100);
        lv_dstatus                 VARCHAR2 (100);
        lv_status                  VARCHAR2 (1);
        lv_message                 VARCHAR2 (240);
        ln_org_id                  NUMBER := fnd_global.org_id;

        ln_responsibility_id       NUMBER;
        ln_application_id          NUMBER;
        ln_user_id                 NUMBER;
        ln_order_source_id         NUMBER;
        lv_orig_sys_document_ref   oe_headers_iface_all.orig_sys_document_ref%TYPE;
        lx_message                 VARCHAR2 (4000);
    BEGIN
        printmessage ('Run import test: ' || ln_org_id);

        SELECT responsibility_id, application_id
          INTO ln_responsibility_id, ln_application_id
          FROM fnd_responsibility_vl
         WHERE responsibility_id = fnd_global.resp_id;

        printmessage ('ln_responsibility_id :' || ln_responsibility_id);
        printmessage ('ln_application_id :' || ln_application_id);

        SELECT user_id
          INTO ln_user_id
          FROM fnd_user
         WHERE user_id = fnd_global.user_id;

        printmessage ('ln_user_id :' || ln_user_id);
        printmessage ('ln_org_id :' || ln_org_id);

        SELECT order_source_id, orig_sys_document_ref
          INTO ln_order_source_id, lv_orig_sys_document_ref
          FROM (  SELECT order_source_id, orig_sys_document_ref
                    FROM xxdo.xxd_om_order_upload_gt
                   WHERE     TRUNC (creation_date) = TRUNC (SYSDATE)
                         AND created_by = fnd_global.user_id
                ORDER BY creation_date DESC)
         WHERE ROWNUM = 1;

        printmessage ('ln_order_source_id :' || ln_order_source_id);
        printmessage (
            'lv_orig_sys_document_ref :' || lv_orig_sys_document_ref);
        fnd_global.apps_initialize (ln_user_id,
                                    ln_responsibility_id,
                                    ln_application_id);
        printmessage ('Run program :');
        ln_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'ONT',
                program       => 'OEOIMP',
                argument1     => ln_org_id,
                argument2     => ln_order_source_id,
                argument3     => lv_orig_sys_document_ref,
                argument4     => NULL,
                argument5     => 'N',
                argument6     => NULL,
                argument7     => 4,
                argument8     => NULL,
                argument9     => NULL,
                argument10    => NULL,
                argument11    => NULL,
                argument12    => 'N',
                argument13    => NULL,
                argument14    => NULL,
                argument15    => 'Y');

        COMMIT;
        printmessage ('ln_request_id :' || ln_request_id);

        IF NVL (ln_request_id, 0) = 0
        THEN
            lx_message   := 'Error in Order Import Program';
        END IF;

        DBMS_OUTPUT.put (
            'concurrent request id is ' || ln_request_id || CHR (13));

        /*IF (apps.fnd_concurrent.wait_for_request (ln_request_id,
                                                  1,
                                                  600000,
                                                  lv_dummy,
                                                  lv_dummy,
                                                  lv_dphase,
                                                  lv_dstatus,
                                                  lx_dummy))
        THEN
           IF lv_dphase = 'COMPLETE' AND lv_dstatus = 'NORMAL'
           THEN
              lx_message := 'Succesfully';
           ELSE
              lx_message := 'Completed With Errors';
           END IF;
        END IF;*/
        printmessage ('lx_message :' || lx_message);
    EXCEPTION
        WHEN OTHERS
        THEN
            lx_message   := SQLERRM;
            raise_application_error (-20000, lx_message);
    END;
END xxd_om_order_upload_x_pk;
/
