--
-- XXD_OM_ORDER_UPLOAD_X_PK1  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OM_ORDER_UPLOAD_X_PK1"
AS
    /******************************************************************************************
    -- Modification History:
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 25-Feb-2015  1.0        BT Technology Team      Created for Order Upload WebADI
    -- 26-APR-2017  1.1        To Sync LAD and Cancel Date CCR : CCR0006079
    -- 03-Oct-2017  1.2        Viswanathan Pandian     Modified for Bulk Order CCR0006663
    -- 11-Dec-2017  1.3        Viswanathan Pandian     Modified for CCR0006653
    -- 14-DEC-2017  1.4        Infosys                 Modified for Performance issue : CCR0006870
    -- 16-Jan-2018  1.5        Infosys                 Modified for CCR0006999
    -- 02-Mar-2018  1.6        Infosys                 Modified for CCR0007082
    -- 29-Jan-2018  1.7        Viswanathan Pandian     Modified for CCR0006889 to revert code
    --                                                 changes done as part of CCR0006663
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
        --      p_creation_date           IN oe_headers_iface_all.creation_date%TYPE, --Commented parameter
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
        --      p_orig_sys_line_ref       IN oe_lines_iface_all.orig_sys_line_ref%TYPE, --Commented parameter
        p_inventory_item          IN oe_lines_iface_all.inventory_item%TYPE,
        p_ordered_quantity        IN oe_lines_iface_all.ordered_quantity%TYPE,
        p_line_request_date       IN oe_lines_iface_all.request_date%TYPE,
        p_unit_selling_price      IN oe_lines_iface_all.unit_selling_price%TYPE,
        p_subinventory            IN oe_lines_iface_all.subinventory%TYPE,
        --------------------------------------------------------------------
        -- Added By Sivakumar Boothathan For Adding Pricing Agreement,
        -- Shipping Instructions and Comments1 and 2
        --------------------------------------------------------------------
        p_ship_instructions       IN oe_headers_iface_all.shipping_instructions%TYPE,
        p_comments1               IN oe_headers_iface_all.attribute6%TYPE,
        p_comments2               IN oe_headers_iface_all.attribute7%TYPE,
        p_pricing_agreement       IN oe_headers_iface_all.agreement%TYPE,
        -------------------------------------------------------------
        -- End of chnage By Sivakuar Boothathan for adding more
        -- Input Parameters
        ---------------------------------------------------------------
        -------------------------------------------------------------------
        -- Added By Sivakumar Boothathan: 12/28 To add A. Sales Agreement Number
        -- to the Parameter when populated the sales agreement ID will be used
        --to release the order from that agreement.
        -------------------------------------------------------------------
        p_sa_number               IN oe_headers_iface_all.blanket_number%TYPE -----------------------------------------
                                                                             -- End of changes By Sivakumar Boothathan
                                                                             -----------------------------------------
                                                                             )
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
                            invoice_to_org_id, cancel_date, brand,
                            ---------------------------------------------------------
                            -- Addition of new parameters by Sivakumar Boothathan
                            ---------------------------------------------------------
                            shipping_instructions, comments1, comments2,
                            pricing_agreement, --------------------------------------------------------------
                                               -- end of addition of new parameters by Sivakumar Boothathan
                                               --------------------------------------------------------------
                                               ----------------------------------------------------------------
                                               -- Added By Sivakumar Boothathan on 01/02 to add sales agreement
                                               ----------------------------------------------------------------
                                               sa_number blanket_number
              ----------------------------------------------------------------
              -- End of addition By Sivakumar Boothathan to add Sales Agreement
              ----------------------------------------------------------------
              FROM xxdo.xxd_om_order_upload_gt xooug
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM oe_headers_iface_all ohia
                         WHERE     ohia.orig_sys_document_ref =
                                   xooug.orig_sys_document_ref
                               AND order_source_id = p_order_source_id); --Added as part of CCR0006870;

        CURSOR get_line_records_c IS
            SELECT DISTINCT order_source_id, orig_sys_document_ref, orig_sys_line_ref,
                            inventory_item, ordered_quantity, line_request_date,
                            created_by, creation_date, last_updated_by,
                            last_update_date, ship_from_org, cancel_date,
                            unit_selling_price, subinventory, ----------------------------------------------------------------
                                                              -- Added By Sivakumar Boothathan on 01/02 to add sales agreement
                                                              ----------------------------------------------------------------
                                                              sa_number blanket_number
              ----------------------------------------------------------------
              -- End of addition By Sivakumar Boothathan to add Sales Agreement
              ----------------------------------------------------------------
              FROM xxdo.xxd_om_order_upload_gt xooug
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM oe_lines_iface_all olia
                         WHERE     olia.orig_sys_line_ref =
                                   xooug.orig_sys_line_ref
                               AND order_source_id = p_order_source_id); --Added as part of CCR0006870;

        lc_orig_sys_line_ref   oe_lines_iface_all.orig_sys_line_ref%TYPE;
        ln_ship_to_org_id      oe_headers_iface_all.ship_to_org_id%TYPE;
        ln_invoice_to_org_id   oe_headers_iface_all.invoice_to_org_id%TYPE;
        l_err_message          VARCHAR2 (4000) := NULL;
        l_ret_message          VARCHAR2 (4000) := NULL;
        ln_cust_account_id     NUMBER;
        ln_exists              NUMBER;
        ln_cust_itm_exists     NUMBER;
        ln_pa_exists           NUMBER;
        ln_pa_item_exists      NUMBER;
        ln_sa_exists           NUMBER;
        ln_sa_item_exists      NUMBER;
        le_webadi_exception    EXCEPTION;
        v_order_check          NUMBER := 0;
        -- Start commenting for CCR0006889 on 08-Mar-2018
        -- Start changes for CCR0006663
        -- lc_bulk_order          VARCHAR2 (1);
        -- ld_line_request_date   DATE;
        -- End changes for CCR0006663
        -- End commenting for CCR0006889 on 08-Mar-2018
        ld_intro_date          DATE;    -- 1.6 Added by Infosys for CCR0007082
        ld_ats_date            DATE;    -- 1.6 Added by Infosys for CCR0007082
        gn_master_org_id       NUMBER;
        ln_org_exist_cnt       NUMBER;
    BEGIN
        printmessage ('p_order_source_id ' || p_order_source_id);
        printmessage ('p_order_type ' || p_order_type);
        printmessage ('p_orig_sys_document_ref ' || p_orig_sys_document_ref);
        printmessage ('p_user_id ' || p_user_id);
        --      printmessage ('p_creation_date ' || p_creation_date); -- Commented parameter
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
        --      printmessage ('p_orig_sys_line_ref ' || p_orig_sys_line_ref); -- Commented parameter
        printmessage ('p_inventory_item ' || p_inventory_item);
        printmessage ('p_ordered_quantity ' || p_ordered_quantity);
        printmessage ('p_line_request_date ' || p_line_request_date);
        printmessage ('p_unit_selling_price ' || p_unit_selling_price);
        printmessage ('p_subinventory ' || p_subinventory);
        printmessage (
            'MFG_ORGANIZATION_ID:' || fnd_profile.VALUE ('MFG_ORGANIZATION_ID'));
        ------------------------------------------------------------------------
        -- Added By Sivakumar Boothathan for New Parameters
        ------------------------------------------------------------------------
        printmessage ('Shipping Instructions ' || p_ship_instructions);
        printmessage ('Comments 1 ' || p_comments1);
        printmessage ('Comments 2 ' || p_comments2);
        printmessage ('Pricing Agreement ' || p_pricing_agreement);
        ------------------------------------------------------------------------
        -- Added By Sivakumar Boothathan for New Parameters
        ------------------------------------------------------------------------
        --------------------------------------------------------------
        -- Added By Sivakumar Boothathan to add Sales Agreement Number
        --------------------------------------------------------------
        printmessage ('Sales Agreement Number' || p_sa_number);


        SELECT organization_id
          INTO gn_master_org_id
          FROM mtl_parameters
         WHERE organization_code = 'MST';

        ------------------------------------------------------------------
        -- End of Addition By Sivakumar Boothathan for adding SA number
        ------------------------------------------------------------------
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
                BEGIN
                    -- Start changes for CCR0006653
                    /*SELECT inventory_item_id
                      INTO ln_item_id
                      FROM mtl_system_items_b a
                     WHERE     organization_id = ln_inv_org_id
                           AND segment1 = p_inventory_item;*/
                    SELECT msib.inventory_item_id
                      INTO ln_item_id
                      FROM mtl_system_items_b msib, mtl_parameters mp
                     WHERE     msib.organization_id = mp.organization_id
                           AND msib.segment1 = p_inventory_item
                           AND mp.organization_code = 'MST'
                           AND msib.enabled_flag = 'Y'
                           AND msib.inventory_item_status_code <> 'Inactive'
                           AND msib.customer_order_enabled_flag = 'Y'
                           AND EXISTS
                                   (SELECT 1
                                      FROM mtl_system_items_b msib1
                                     WHERE     msib1.inventory_item_id =
                                               msib.inventory_item_id
                                           AND msib1.organization_id =
                                               ln_inv_org_id
                                           AND msib1.enabled_flag = 'Y'
                                           AND msib1.inventory_item_status_code <>
                                               'Inactive'
                                           AND msib1.customer_order_enabled_flag =
                                               'Y');
                -- End changes for CCR0006653
                -------------------------------------------------
                -- Added By Sivakumar Boothathan
                -- Date : 01/02 to add customer item number
                -------------------------------------------------
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        SELECT 1
                          INTO ln_cust_itm_exists
                          FROM mtl_customer_items mci, mtl_system_items msi, mtl_customer_item_xrefs mix
                         WHERE     mci.customer_item_id =
                                   mix.customer_item_id
                               AND msi.inventory_item_id =
                                   mix.inventory_item_id
                               AND msi.organization_id =
                                   mix.master_organization_id
                               AND mci.inactive_flag = 'N'
                               AND mix.preference_number = 1
                               AND mci.customer_id = ln_cust_account_id
                               AND mci.customer_item_number =
                                   p_inventory_item;
                END;

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
                           l_err_message
                        || 'SKU/Customer Item is invalid or not assigned to Warehouse. ';
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

        -- 1.5: Start : Added by Infosys for CCR0006999

        -- Validate Ordered Quantity
        IF p_ordered_quantity = 0
        THEN
            l_err_message   := l_err_message || 'Quantity cannot be zero. ';
        /* ELSIF SIGN (p_ordered_quantity) = -1   --w.r.t Version 1.6
         THEN
            l_err_message := l_err_message || 'Quantity cannot be negative. '; */
        ELSE
            BEGIN
                SELECT TO_NUMBER (p_ordered_quantity, '999999999')
                  INTO ln_exists
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'Quantity Should be a whole number. ';
            END;
        END IF;

        --1.5: End : Added by Infosys for CCR0006999
        -----------------------------------------------------------------------------
        -- Added By Sivakumar Boothathan
        -- Date : 01/02 to Validate pricing agreement, sales agreement and booked flag
        -----------------------------------------------------------------------------

        IF p_pricing_agreement IS NOT NULL AND p_sa_number IS NOT NULL
        THEN
            l_err_message   :=
                   l_err_message
                || 'Agreement cannot be specified on an order with a sales agreement reference';
        END IF;

        IF p_pricing_agreement IS NOT NULL
        THEN
            BEGIN
                SELECT 1
                  INTO ln_pa_exists
                  FROM oe_agreements_vl
                 WHERE     name = p_pricing_agreement
                       AND sold_to_org_id = ln_cust_account_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'Pricing Agreement is not valid for this Customer. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF     p_pricing_agreement IS NOT NULL
           AND ln_pa_exists IS NOT NULL
           AND ln_cust_itm_exists IS NULL
        THEN
            BEGIN
                SELECT 1
                  INTO ln_pa_item_exists
                  FROM qp_list_lines_v
                 WHERE     list_header_id IN
                               (SELECT price_list_id
                                  FROM oe_agreements_vl
                                 WHERE name = p_pricing_agreement)
                       AND product_attr_val_disp = p_inventory_item
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           end_date_active),
                                                       TRUNC (SYSDATE));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'SKU is not valid for this Pricing Agreement. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF     p_pricing_agreement IS NOT NULL
           AND ln_pa_exists IS NOT NULL
           AND ln_cust_itm_exists IS NOT NULL
        THEN
            BEGIN
                SELECT 1
                  INTO ln_pa_item_exists
                  FROM qp_list_lines_v
                 WHERE     list_header_id IN
                               (SELECT price_list_id
                                  FROM oe_agreements_vl
                                 WHERE name = p_pricing_agreement)
                       AND product_attr_val_disp IN
                               (SELECT msi.segment1
                                  FROM mtl_customer_items mci, mtl_system_items msi, mtl_customer_item_xrefs mix
                                 WHERE     mci.customer_item_id =
                                           mix.customer_item_id
                                       AND msi.inventory_item_id =
                                           mix.inventory_item_id
                                       AND msi.organization_id =
                                           mix.master_organization_id
                                       AND mci.inactive_flag = 'N'
                                       AND mix.preference_number = 1
                                       AND mci.customer_id =
                                           ln_cust_account_id
                                       AND mci.customer_item_number =
                                           p_inventory_item)
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           end_date_active),
                                                       TRUNC (SYSDATE));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'Customer Item is not valid for this Pricing Agreement. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF p_sa_number IS NOT NULL
        THEN
            BEGIN
                SELECT 1
                  INTO ln_sa_exists
                  FROM oe_blanket_headers_all obha
                 WHERE     order_number = p_sa_number
                       AND sold_to_org_id = ln_cust_account_id
                       AND EXISTS
                               (SELECT 1
                                  FROM oe_blanket_headers_ext obhe
                                 WHERE     obhe.order_number =
                                           obha.order_number
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       TRUNC (
                                                                           obhe.start_date_active),
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       TRUNC (
                                                                           obhe.end_date_active),
                                                                       TRUNC (
                                                                           SYSDATE)));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'Sales Agreement is not valid for this Customer or Inactive. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF p_sa_number IS NOT NULL AND ln_sa_exists IS NOT NULL
        THEN
            BEGIN
                SELECT 1
                  INTO ln_sa_item_exists
                  FROM oe_blanket_lines_all obla
                 WHERE     obla.header_id IN
                               (SELECT header_id
                                  FROM oe_blanket_headers_all
                                 WHERE order_number = p_sa_number)
                       AND obla.ordered_item = p_inventory_item
                       AND EXISTS
                               (SELECT 1
                                  FROM oe_blanket_lines_ext oble
                                 WHERE     oble.line_id = obla.line_id
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       TRUNC (
                                                                           oble.start_date_active),
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       TRUNC (
                                                                           oble.end_date_active),
                                                                       TRUNC (
                                                                           SYSDATE)));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'SKU/Customer Item is not valid for this Sales Agreement. ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        IF p_booked_flag IS NOT NULL
        THEN
            BEGIN
                SELECT 1
                  INTO ln_exists
                  FROM DUAL
                 WHERE p_booked_flag IN ('Y', 'N');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'Book Order flag has to be either N or Y ';
                WHEN OTHERS
                THEN
                    l_err_message   := l_err_message || SQLERRM;
            END;
        END IF;

        -----------------------------------------------------------------------------
        -- End of Change By Sivakumar Boothathan
        -- Date : 01/02 to Validate pricing agreement, sales agreement and booked flag
        -----------------------------------------------------------------------------

        -------------------------------------------------------------------
        -- Check adde By Sivakumar boothathan to make sure that
        -- No Web-ADI orders dupicate is inserted into the
        -- table
        -----------------------------------------------------------------

        BEGIN
            SELECT COUNT (1)
              INTO v_order_check
              FROM apps.oe_order_headers_all ooh, apps.oe_order_sources oos
             WHERE     ooh.orig_sys_document_ref = p_orig_sys_document_ref
                   AND ooh.order_source_id = oos.order_source_id
                   AND oos.name = 'Order Upload';

            IF (v_order_check >= 1)
            THEN
                l_err_message   :=
                       l_err_message
                    || 'The Reference is already in Oracle. Please Download  a New Template';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                v_order_check   := 0;
        END;

        -- Start commenting for CCR0006889 on 08-Mar-2018
        -- Start changes for CCR0006663
        -- Validate if Bulk Order
        -- SELECT DECODE (COUNT (1), 0, 'N', 'Y')
        --   INTO lc_bulk_order
        --   FROM fnd_lookup_values
        --  WHERE     lookup_type = 'XXD_ONT_PICK_REL_ORD_TYP_EXCL'
        --        AND tag = 'Bulk Order'
        --        AND enabled_flag = 'Y'
        --        AND TRUNC (SYSDATE) BETWEEN TRUNC (
        --                                       NVL (start_date_active, SYSDATE))
        --                                AND TRUNC (
        --                                       NVL (end_date_active, SYSDATE))
        --        AND meaning = p_order_type;

        -- If Bulk Order then
        -- Request Date should be First of that month
        -- Cancel Date should be Last Day of Request Date's Month
        -- ld_line_request_date := NVL (p_line_request_date, p_request_date);

        -- IF     lc_bulk_order = 'Y'
        --    AND (   TO_DATE (TRUNC (p_request_date, 'MM')) <> p_request_date
        --         OR TO_DATE (TRUNC (ld_line_request_date, 'MM')) <>
        --               ld_line_request_date
        --         OR TO_DATE (LAST_DAY (p_request_date)) <> p_cancel_date
        --         OR TO_DATE (LAST_DAY (ld_line_request_date)) <> p_cancel_date)
        -- THEN
        --    l_err_message :=
        --          l_err_message
        --       || 'Bulk orders must be placed for a specific calendar month; with the request date set as the first of the month and cancel date as the last day of the month. ';
        -- END IF;

        -- End changes for CCR0006663
        -- End commenting for CCR0006889 on 08-Mar-2018

        -- 1.6: Start: Added by Infosys for CCR0007082
        SELECT COUNT (1)
          INTO ln_org_exist_cnt
          FROM fnd_lookup_values_vl
         WHERE     lookup_type = 'XXD_ONT_SO_WEBADI_ATS_INTRO_OU'
               AND enabled_flag = 'Y'
               AND MEANING = ln_org_id;

        IF ln_org_exist_cnt <> 0
        THEN
            BEGIN
                SELECT TRUNC (TO_DATE (msi.attribute24, 'YYYY/MM/DD'), 'MM'), TO_DATE (msi.attribute25, 'YYYY/MM/DD')
                  INTO ld_intro_date, ld_ats_date
                  FROM apps.mtl_system_items_b msi
                 WHERE     segment1 = p_inventory_item
                       AND organization_id = gn_master_org_id;

                IF TRUNC (P_request_date) <
                   NVL (NVL (ld_ats_date, ld_intro_date),
                        TRUNC (P_request_date))
                THEN
                    l_err_message   :=
                           l_err_message
                        || 'ATS or Intro validation error, please check the Request Date';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_err_message   :=
                           'Exception raised in Intro date'
                        || ld_intro_date
                        || ' validation'
                        || SQLERRM;
            END;
        END IF;

        -- 1.6: End: Added by Infosys for CCR0007082

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
                                                     subinventory,
                                                     ---------------------------------------------------------
                                                     -- Addition of new parameters by Sivakumar Boothathan
                                                     ---------------------------------------------------------
                                                     shipping_instructions,
                                                     comments1,
                                                     comments2,
                                                     pricing_agreement,
                                                     --------------------------------------------------------------
                                                     -- end of addition of new parameters by Sivakumar Boothathan
                                                     --------------------------------------------------------------
                                                     -------------------------------------------------------------
                                                     -- Addition of Sales Agreement By Sivakumar Boothathan
                                                     -------------------------------------------------------------
                                                     sa_number)
                 VALUES (p_order_source_id, p_order_type, p_orig_sys_document_ref, lc_orig_sys_line_ref, p_inventory_item, p_ordered_quantity, p_user_id, SYSDATE, --p_creation_date,
                                                                                                                                                                   p_user_id, SYSDATE, --p_creation_date,
                                                                                                                                                                                       p_request_date, NVL (p_line_request_date, p_request_date), p_operation_code, p_booked_flag, p_customer_number, p_customer_po_number, p_price_list, p_ship_from_org, ln_ship_to_org_id, ln_invoice_to_org_id, p_cancel_date, p_brand, p_unit_selling_price, p_subinventory, ---------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                  -- Addition of new parameters by Sivakumar Boothathan
                                                                                                                                                                                                                                                                                                                                                                                                                                                                  --------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                  p_ship_instructions, p_comments1, p_comments2
                         , p_pricing_agreement, --------------------------------------------------------
                                                -- Addition Of Sivakumar Boothathan for Sales Agreement
                                                -- Number
                                                -------------------------------------------------------
                                                p_sa_number);

            --------------------------------------------------------------
            -- end of addition of new parameters by Sivakumar Boothathan
            --------------------------------------------------------------
            printmessage ('count ' || SQL%ROWCOUNT);

            -- Insert Header Records
            FOR lcu_header_records_rec IN get_header_records_c
            LOOP
                INSERT INTO oe_headers_iface_all (order_source_id, order_type, orig_sys_document_ref, created_by, creation_date, last_updated_by, last_update_date, request_date, operation_code, booked_flag, customer_number, sold_to_org, customer_po_number, price_list, ship_from_org, ship_to_org_id, invoice_to_org_id, attribute1, attribute5, org_id, --------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                               -- Addition of new parameters By Sivakumar Boothathan
                                                                                                                                                                                                                                                                                                                                                               -------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                               shipping_instructions, attribute6, attribute7, agreement
                                                  , -----------------------------------------------
                                                    -- Addition Of Sivakumar Boothathan to add
                                                    -- Sales Agreeent number so that release can
                                                    -- be created
                                                    -------------------------------------------------
                                                    blanket_number --------------------------------------------------
                                                                  -- End of changes By Sivakumar Boothathan on 12/30
                                                                  --------------------------------------------------
                                                                  )
                     -------------------------------------------------------------
                     -- End of addition of new parameters By Sivakumar Boothathan
                     ------------------------------------------------------------
                     VALUES (lcu_header_records_rec.order_source_id, lcu_header_records_rec.order_type, lcu_header_records_rec.orig_sys_document_ref, lcu_header_records_rec.created_by, lcu_header_records_rec.creation_date, lcu_header_records_rec.last_updated_by, lcu_header_records_rec.last_update_date, lcu_header_records_rec.header_request_date, lcu_header_records_rec.operation_code, lcu_header_records_rec.booked_flag, lcu_header_records_rec.customer_number, NULL, --ln_cust_account_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     lcu_header_records_rec.customer_po_number, lcu_header_records_rec.price_list, lcu_header_records_rec.ship_from_org, lcu_header_records_rec.ship_to_org_id, lcu_header_records_rec.invoice_to_org_id, fnd_date.date_to_canonical (lcu_header_records_rec.cancel_date), lcu_header_records_rec.brand, ln_org_id, --------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    -- Addition of new parameters By Sivakumar Boothathan
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    -------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    lcu_header_records_rec.shipping_instructions, lcu_header_records_rec.comments1, lcu_header_records_rec.comments2, lcu_header_records_rec.pricing_agreement
                             , ------------------------------------------------------------
                               -- End of addition of new parameters By Sivakumar Boothathan
                               -------------------------------------------------------------
                               ------------------------------------------------------------
                               -- Addition Of Sivakumar Boothathan to add SA Number
                               -------------------------------------------------------------
                               lcu_header_records_rec.blanket_number);

                -------------------------------------------------------------
                -- End of changes By Sivakumar Boothathan on 12/30
                -------------------------------------------------------------

                printmessage ('count 1' || SQL%ROWCOUNT);
            END LOOP;


            -- Insert Line Records
            FOR lcu_line_records_rec IN get_line_records_c
            LOOP
                INSERT INTO oe_lines_iface_all (order_source_id, orig_sys_document_ref, orig_sys_line_ref, inventory_item, inventory_item_id, ordered_quantity, request_date, created_by, creation_date, last_updated_by, last_update_date, ship_from_org, attribute1, unit_selling_price, -----------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                           -- Addition of new parameters to enforce unit selling price passed from webadi 12/13/2016
                                                                                                                                                                                                                                                                                           ------------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                           unit_list_price, calculate_price_flag, ------------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                  -- End of addition of new parameters to enforce unit selling price passed from webadi 12/13/2016
                                                                                                                                                                                                                                                                                                                                  ------------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                  subinventory, org_id, --------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                        -- Addition of new parameters By Sivakumar Boothathan
                                                                                                                                                                                                                                                                                                                                                        -------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                        blanket_number, customer_item_id_type, customer_item_name
                                                , --------------------------------------------------
                                                  -- End of changes By Sivakumar Boothathan on 12/30
                                                  --------------------------------------------------
                                                  --------------------------------------------------
                                                  -- Start of change By Siva B for : CCR0006079
                                                  --------------------------------------------------
                                                  latest_acceptable_date --------------------------------------------------
                                                                        -- End of change By Siva B for : CCR0006079
                                                                        --------------------------------------------------
                                                                        )
                     VALUES (lcu_line_records_rec.order_source_id, lcu_line_records_rec.orig_sys_document_ref, lcu_line_records_rec.orig_sys_line_ref, DECODE (ln_cust_itm_exists, 1, NULL, lcu_line_records_rec.inventory_item), DECODE (ln_cust_itm_exists, 1, NULL, ln_item_id), lcu_line_records_rec.ordered_quantity, lcu_line_records_rec.line_request_date, lcu_line_records_rec.created_by, lcu_line_records_rec.creation_date, lcu_line_records_rec.last_updated_by, lcu_line_records_rec.last_update_date, lcu_line_records_rec.ship_from_org, fnd_date.date_to_canonical (lcu_line_records_rec.cancel_date), lcu_line_records_rec.unit_selling_price, -----------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 -- Addition of new parameters to enforce unit selling price passed from webadi 12/13/2016
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 ------------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 lcu_line_records_rec.unit_selling_price, DECODE (NVL (lcu_line_records_rec.unit_selling_price, '1'), 1, 'Y', 'P'), ------------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    -- End of addition of new parameters to enforce unit selling price passed from webadi 12/13/2016
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ------------------------------------------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    lcu_line_records_rec.subinventory, ln_org_id, -------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  -- Addition Of Sivakumar Boothathan to add SA Number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  -------------------------------------------------------------
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  lcu_line_records_rec.blanket_number, DECODE (ln_cust_itm_exists, 1, 'CUST', NULL), DECODE (ln_cust_itm_exists, 1, lcu_line_records_rec.inventory_item, NULL)
                             , -------------------------------------------------------------
                               -- End of changes By Sivakumar Boothathan on 12/30
                               --------------------------------------------------------------
                               --------------------------------------------------
                               --Start of change By Siva B for : CCR0006079
                               --------------------------------------------------
                               lcu_line_records_rec.cancel_date ------------------------------------------
                                                               -- End of change By Siva B for CCR : CCR0006079
                                                               -----------------------------------------------
                                                               );
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
        -- Start changes for CCR0006653
        /*ln_request_id :=
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

        -----------------------------------------------------------------
        -- Deleting from the custom table to avoid any duplicate insert
        -- changes done by Sivakumar Boothathan
        -----------------------------------------------------------------
        BEGIN
           DELETE FROM xxdo.xxd_om_order_upload_gt
                 WHERE orig_sys_document_ref = lv_orig_sys_document_ref;

           COMMIT;
        EXCEPTION
           WHEN OTHERS
           THEN
              printmessage ('Error while deleting from custom table');
        END;

        ---------------------------------------------------------------------
        -- End of additon By Sivakumar Boothathan to avoid deuplicate insert
        ---------------------------------------------------------------------
        printmessage ('ln_request_id :' || ln_request_id);

        IF NVL (ln_request_id, 0) = 0
        THEN
           lx_message := 'Error in Order Import Program';
        END IF;

        DBMS_OUTPUT.put (
           'concurrent request id is ' || ln_request_id || CHR (13));
        */
        -- End changes for CCR0006653

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
        -- Start changes for CCR0006653
        ln_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'XXDO',
                program       => 'XXDOEOIMPWEBADI',
                argument1     => lv_orig_sys_document_ref);

        IF NVL (ln_request_id, 0) = 0
        THEN
            lx_message   :=
                'Error in Deckers Order Import - Pre Validation for WebADI Program';
        END IF;

        -- End changes for CCR0006653
        printmessage ('lx_message :' || lx_message);
    EXCEPTION
        WHEN OTHERS
        THEN
            lx_message   := SQLERRM;
            raise_application_error (-20000, lx_message);
    END;
END xxd_om_order_upload_x_pk1;
/
