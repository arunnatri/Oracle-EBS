--
-- XXD_OM_INTERCO_PRICE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OM_INTERCO_PRICE_PKG"
AS
    /*****************************************************************
    * Package:            XXDO_INTERCOM_PRICING_PKG
    * Author:            GJensen
    *
    * Created:            30-MAR-2021
    *
    * Description:        Calculate the PO Interco price.
    *
    * Modifications:
    * Date modified        Developer name          Version
    * 03/30/2021           GJensen                 Original(1.0)
    *****************************************************************/
    FUNCTION check_price_list_fnc (p_line_id IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR get_price_list_c IS
            SELECT COUNT (1)
              FROM qp_list_lines qll, oe_order_lines_all oola
             WHERE     oola.price_list_id = qll.list_header_id
                   AND qll.price_by_formula_id IS NOT NULL
                   AND oola.line_id = p_line_id
                   AND ROWNUM = 1;

        ln_number   NUMBER;
    BEGIN
        OPEN get_price_list_c;

        FETCH get_price_list_c INTO ln_number;

        CLOSE get_price_list_c;

        RETURN ln_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END check_price_list_fnc;


    PROCEDURE LOG (p_line_id          IN NUMBER,
                   p_from_org_id      IN NUMBER,
                   p_to_org_id        IN NUMBER,
                   p_from_inv_org     IN NUMBER,
                   p_to_inv_org       IN NUMBER,
                   p_brand            IN VARCHAR2,
                   p_reclass          IN VARCHAR2,
                   p_order_currency   IN VARCHAR2,
                   p_source_factory   IN VARCHAR2,
                   p_function_name    IN VARCHAR2,
                   p_error_message    IN VARCHAR2)
    IS
        CURSOR get_ou_name (p_org_id IN NUMBER)
        IS
            SELECT name
              FROM hr_operating_units
             WHERE organization_id = p_org_id;

        CURSOR get_org_name (p_org_id IN NUMBER)
        IS
            SELECT organization_name
              FROM org_organization_definitions
             WHERE organization_id = p_org_id;



        l_from_org_name      VARCHAR2 (300);
        l_to_org_name        VARCHAR2 (300);
        l_from_invorg_name   VARCHAR2 (300);
        l_to_invorg_name     VARCHAR2 (300);
        l_message            VARCHAR2 (3000);

        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        OPEN get_ou_name (p_from_org_id);

        FETCH get_ou_name INTO l_from_org_name;

        CLOSE get_ou_name;

        OPEN get_ou_name (p_to_org_id);

        FETCH get_ou_name INTO l_to_org_name;

        CLOSE get_ou_name;

        OPEN get_org_name (p_from_inv_org);

        FETCH get_org_name INTO l_from_invorg_name;

        CLOSE get_org_name;

        OPEN get_org_name (p_to_inv_org);

        FETCH get_org_name INTO l_to_invorg_name;

        CLOSE get_org_name;

        INSERT INTO XXD_INTERCOM_ERROR_TBL
             VALUES (p_line_id, p_function_name, l_from_org_name,
                     l_to_org_name, l_from_invorg_name, l_to_invorg_name,
                     p_brand, p_reclass, p_order_currency,
                     p_source_factory, p_error_message, SYSDATE,
                     FND_GLOBAL.USER_ID);

        COMMIT;
        l_message   :=
               'Hi,'
            || CHR (10)
            || CHR (10)
            || '  '
            || p_error_message
            || CHR (10)
            || CHR (10)
            || 'From Operating Unit :'
            || '  '
            || l_from_org_name
            || CHR (10)
            || 'To Operating Unit     :'
            || '  '
            || l_to_org_name
            || CHR (10)
            || 'From Organization   :'
            || '  '
            || l_from_invorg_name
            || CHR (10)
            || 'To Organization       :'
            || '  '
            || l_to_invorg_name
            || CHR (10)
            || 'Brand                       :'
            || '  '
            || p_brand
            || CHR (10)
            || 'Reclass                    :'
            || '  '
            || p_reclass
            || CHR (10)
            || 'Order Currency        :'
            || '  '
            || p_order_currency
            || CHR (10)
            || 'Source Factory        :'
            || '  '
            || p_source_factory;
    END LOG;

    FUNCTION get_count (p_where_clause IN VARCHAR2)
        RETURN NUMBER
    IS
        lc_query          VARCHAR2 (3000);
        lc_where_clause   VARCHAR2 (3000);
        ln_count          NUMBER;
    BEGIN
        ln_count          := 0;
        lc_where_clause   := p_where_clause;

        lc_query          :=
            ' SELECT COUNT(*) 
                       FROM fnd_flex_value_sets ffvs,
                            fnd_flex_values      ffv
                      WHERE ffv.flex_value_set_id                               = ffvs.flex_value_set_id
                        AND flex_value_set_name                                 = ''DO_INTERCOMPANY''
                        AND ffv.enabled_flag                                    = ''Y''
                        AND TRUNC(SYSDATE) BETWEEN NVL(START_DATE_ACTIVE,TRUNC(SYSDATE)) 
                                               AND NVL(END_DATE_ACTIVE,TRUNC(SYSDATE)) ';
        lc_query          := lc_query || lc_where_clause;

        EXECUTE IMMEDIATE lc_query
            INTO ln_count;

        RETURN NVL (ln_count, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_count;

    FUNCTION BUILD_WHERE_CLAUSE (p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_brand IN VARCHAR2, p_reclass IN VARCHAR2
                                 , p_order_currency IN VARCHAR2, p_source_factory IN VARCHAR2, p_line_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lc_where_clause         VARCHAR2 (3000);
        ln_record_count         NUMBER;
        lc_final_where_clause   VARCHAR2 (3000);
        lc_where_clause_int     VARCHAR2 (3000);
        ex_no_record_found      EXCEPTION;
    BEGIN
        lc_where_clause   := ' and ffv.attribute14 = ' || p_from_org_id;
        ln_record_count   := 0;
        ln_record_count   := get_count (lc_where_clause);

        IF ln_record_count = 0
        THEN
            RAISE ex_no_record_found;
        ELSIF ln_record_count = 1
        THEN
            lc_final_where_clause   := lc_where_clause;
        ELSIF ln_record_count > 1
        THEN
            lc_where_clause_int   :=
                lc_where_clause || ' and ffv.attribute15 =  ' || p_to_org_id;
            ln_record_count   := 0;
            ln_record_count   := get_count (lc_where_clause_int);

            IF ln_record_count = 0
            THEN
                lc_where_clause_int   :=
                    lc_where_clause || ' and ffv.attribute15 IS NULL ';
                ln_record_count   := 0;
                ln_record_count   := get_count (lc_where_clause_int);

                IF ln_record_count = 0
                THEN
                    RAISE ex_no_record_found;
                ELSIF ln_record_count = 1
                THEN
                    lc_final_where_clause   := lc_where_clause_int;
                ELSIF ln_record_count > 1
                THEN
                    lc_where_clause   := lc_where_clause_int;
                END IF;
            ELSIF ln_record_count = 1
            THEN
                lc_final_where_clause   := lc_where_clause_int;
            ELSIF ln_record_count > 1
            THEN
                lc_where_clause   := lc_where_clause_int;
            END IF;
        END IF;

        IF lc_final_where_clause IS NULL AND ln_record_count > 1
        THEN
            lc_where_clause_int   :=
                lc_where_clause || ' and ffv.attribute1 = ' || p_from_inv_org;
            ln_record_count   := 0;
            ln_record_count   := get_count (lc_where_clause_int);

            IF ln_record_count = 0
            THEN
                lc_where_clause_int   :=
                    lc_where_clause || ' and ffv.attribute1 IS NULL ';
                ln_record_count   := 0;
                ln_record_count   := get_count (lc_where_clause_int);

                IF ln_record_count = 0
                THEN
                    RAISE ex_no_record_found;
                ELSIF ln_record_count = 1
                THEN
                    lc_final_where_clause   := lc_where_clause_int;
                ELSIF ln_record_count > 1
                THEN
                    lc_where_clause   := lc_where_clause_int;
                END IF;
            ELSIF ln_record_count = 1
            THEN
                lc_final_where_clause   := lc_where_clause_int;
            ELSIF ln_record_count > 1
            THEN
                lc_where_clause   := lc_where_clause_int;
            END IF;
        END IF;

        IF lc_final_where_clause IS NULL AND ln_record_count > 1
        THEN
            lc_where_clause_int   :=
                lc_where_clause || ' and ffv.attribute2 = ' || p_to_inv_org;
            ln_record_count   := 0;
            ln_record_count   := get_count (lc_where_clause_int);

            IF ln_record_count = 0
            THEN
                lc_where_clause_int   :=
                    lc_where_clause || ' and ffv.attribute2 IS NULL ';
                ln_record_count   := 0;
                ln_record_count   := get_count (lc_where_clause_int);

                IF ln_record_count = 0
                THEN
                    RAISE ex_no_record_found;
                ELSIF ln_record_count = 1
                THEN
                    lc_final_where_clause   := lc_where_clause_int;
                ELSIF ln_record_count > 1
                THEN
                    lc_where_clause   := lc_where_clause_int;
                END IF;
            ELSIF ln_record_count = 1
            THEN
                lc_final_where_clause   := lc_where_clause_int;
            ELSIF ln_record_count > 1
            THEN
                lc_where_clause   := lc_where_clause_int;
            END IF;
        END IF;

        IF lc_final_where_clause IS NULL AND ln_record_count > 1
        THEN
            lc_where_clause_int   :=
                   lc_where_clause
                || ' and ffv.attribute3 = '
                || ''''
                || p_brand
                || '''';
            ln_record_count   := 0;
            ln_record_count   := get_count (lc_where_clause_int);

            IF ln_record_count = 0
            THEN
                lc_where_clause_int   :=
                    lc_where_clause || ' and ffv.attribute3 IS NULL ';
                ln_record_count   := 0;
                ln_record_count   := get_count (lc_where_clause_int);

                IF ln_record_count = 0
                THEN
                    RAISE ex_no_record_found;
                ELSIF ln_record_count = 1
                THEN
                    lc_final_where_clause   := lc_where_clause_int;
                ELSIF ln_record_count > 1
                THEN
                    lc_where_clause   := lc_where_clause_int;
                END IF;
            ELSIF ln_record_count = 1
            THEN
                lc_final_where_clause   := lc_where_clause_int;
            ELSIF ln_record_count > 1
            THEN
                lc_where_clause   := lc_where_clause_int;
            END IF;
        END IF;

        IF lc_final_where_clause IS NULL AND ln_record_count > 1
        THEN
            lc_where_clause_int   :=
                   lc_where_clause
                || ' and ffv.attribute17 = '
                || ''''
                || p_reclass
                || '''';
            ln_record_count   := 0;
            ln_record_count   := get_count (lc_where_clause_int);

            IF ln_record_count = 0
            THEN
                lc_where_clause_int   :=
                    lc_where_clause || ' and ffv.attribute17 IS NULL ';
                ln_record_count   := 0;
                ln_record_count   := get_count (lc_where_clause_int);

                IF ln_record_count = 0
                THEN
                    RAISE ex_no_record_found;
                ELSIF ln_record_count = 1
                THEN
                    lc_final_where_clause   := lc_where_clause_int;
                ELSIF ln_record_count > 1
                THEN
                    lc_where_clause   := lc_where_clause_int;
                END IF;
            ELSIF ln_record_count = 1
            THEN
                lc_final_where_clause   := lc_where_clause_int;
            ELSIF ln_record_count > 1
            THEN
                lc_where_clause   := lc_where_clause_int;
            END IF;
        END IF;

        IF lc_final_where_clause IS NULL AND ln_record_count > 1
        THEN
            lc_where_clause_int   :=
                   lc_where_clause
                || ' and ffv.attribute19 = '
                || ''''
                || p_order_currency
                || '''';
            ln_record_count   := 0;
            ln_record_count   := get_count (lc_where_clause_int);

            IF ln_record_count = 0
            THEN
                lc_where_clause_int   :=
                    lc_where_clause || ' and ffv.attribute19 IS NULL ';
                ln_record_count   := 0;
                ln_record_count   := get_count (lc_where_clause_int);

                IF ln_record_count = 0
                THEN
                    RAISE ex_no_record_found;
                ELSIF ln_record_count = 1
                THEN
                    lc_final_where_clause   := lc_where_clause_int;
                ELSIF ln_record_count > 1
                THEN
                    lc_where_clause   := lc_where_clause_int;
                END IF;
            ELSIF ln_record_count = 1
            THEN
                lc_final_where_clause   := lc_where_clause_int;
            ELSIF ln_record_count > 1
            THEN
                lc_where_clause   := lc_where_clause_int;
            END IF;
        END IF;

        IF lc_final_where_clause IS NULL AND ln_record_count > 1
        THEN
            lc_where_clause_int   :=
                   lc_where_clause
                || ' and ffv.attribute20 = '
                || ''''
                || p_source_factory
                || '''';
            ln_record_count   := 0;
            ln_record_count   := get_count (lc_where_clause_int);

            IF ln_record_count = 0
            THEN
                lc_where_clause_int   :=
                    lc_where_clause || ' and ffv.attribute20 IS NULL ';
                ln_record_count   := 0;
                ln_record_count   := get_count (lc_where_clause_int);

                IF ln_record_count = 0
                THEN
                    RAISE ex_no_record_found;
                ELSIF ln_record_count = 1
                THEN
                    lc_final_where_clause   := lc_where_clause_int;
                ELSIF ln_record_count > 1
                THEN
                    lc_where_clause   := lc_where_clause_int;
                END IF;
            ELSIF ln_record_count = 1
            THEN
                lc_final_where_clause   := lc_where_clause_int;
            ELSIF ln_record_count > 1
            THEN
                lc_where_clause   := lc_where_clause_int;
            END IF;
        END IF;

        IF ln_record_count > 1
        THEN
            LOG (
                p_line_id          => p_line_id,
                p_from_org_id      => p_from_org_id,
                p_to_org_id        => p_to_org_id,
                p_from_inv_org     => p_from_inv_org,
                p_to_inv_org       => p_to_inv_org,
                p_brand            => p_brand,
                p_reclass          => p_reclass,
                p_order_currency   => p_order_currency,
                p_source_factory   => p_source_factory,
                p_function_name    => 'BUILD_WHERE_CLAUSE',
                p_error_message    =>
                    'More than one Record found in DO_INTERCOMPANY valuset for the below parameters combinations ');
        END IF;

        RETURN lc_final_where_clause;
    EXCEPTION
        WHEN ex_no_record_found
        THEN
            LOG (
                p_line_id          => p_line_id,
                p_from_org_id      => p_from_org_id,
                p_to_org_id        => p_to_org_id,
                p_from_inv_org     => p_from_inv_org,
                p_to_inv_org       => p_to_inv_org,
                p_brand            => p_brand,
                p_reclass          => p_reclass,
                p_order_currency   => p_order_currency,
                p_source_factory   => p_source_factory,
                p_function_name    => 'BUILD_WHERE_CLAUSE',
                p_error_message    =>
                    'No Record found in DO_INTERCOMPANY valuset for the below parameters combinations ');
            RETURN ' AND 1=2';
        WHEN OTHERS
        THEN
            LOG (
                p_line_id          => p_line_id,
                p_from_org_id      => p_from_org_id,
                p_to_org_id        => p_to_org_id,
                p_from_inv_org     => p_from_inv_org,
                p_to_inv_org       => p_to_inv_org,
                p_brand            => p_brand,
                p_reclass          => p_reclass,
                p_order_currency   => p_order_currency,
                p_source_factory   => p_source_factory,
                p_function_name    => 'BUILD_WHERE_CLAUSE',
                p_error_message    =>
                    ' Exception is  :  ' || CHR (10) || SQLERRM);
            RETURN ' AND 1=2';
    END BUILD_WHERE_CLAUSE;


    -- Main function which will be called internally by all the pricing attribute functions

    FUNCTION MAIN (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER, p_order_type_id IN NUMBER, p_cost_element IN VARCHAR2, p_line_id IN NUMBER DEFAULT NULL
                   , p_source IN VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2
    IS
        ln_pricelist           NUMBER;

        CURSOR get_listprice_cu (p_costing_org IN NUMBER)
        IS
            SELECT NVL (list_price_per_unit, 0)
              FROM mtl_system_items_b
             WHERE     inventory_item_id = p_inventory_item_id
                   AND organization_id = p_costing_org;

        CURSOR get_line_det_cu IS
            SELECT oos.name
              FROM oe_order_lines_all oola, oe_order_sources oos
             WHERE     oola.order_source_id = oos.order_source_id
                   AND oola.line_id = p_line_id;

        CURSOR get_order_curr_cu IS
            SELECT transactional_curr_code
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     oola.header_id = ooha.header_id
                   AND oola.line_id = p_line_id;

        CURSOR get_to_org_cu IS
            SELECT inv_org.operating_unit, inv_org.organization_id
              FROM apps.org_organization_definitions inv_org, apps.po_location_associations_all pla, apps.hr_locations hrl,
                   apps.hz_cust_site_uses_all su
             WHERE     su.site_use_id = pla.site_use_id(+)
                   AND pla.location_id = hrl.location_id(+)
                   AND pla.organization_id = inv_org.organization_id(+)
                   AND su.site_use_id = p_to_inv_org;

        CURSOR get_from_org_cu IS
            SELECT inv_org.operating_unit, inv_org.organization_id
              FROM apps.org_organization_definitions inv_org
             WHERE inv_org.organization_id = p_from_inv_org;

        CURSOR get_reclass_cu IS
            SELECT attribute11
              FROM oe_transaction_types_all
             WHERE transaction_type_id = p_order_type_id;

        -- Added below by BT Technology team for CR#95 version 2.0
        CURSOR get_po_country_cu IS
            SELECT assa.country
              FROM po_line_locations_all plla, oe_order_lines_all oola, po_headers_all pha,
                   ap_supplier_sites_all assa
             WHERE     oola.attribute16 = plla.line_location_id
                   AND pha.po_header_id = plla.po_header_id
                   AND pha.vendor_site_id = assa.vendor_site_id
                   AND oola.line_id = p_line_id;

        -- Added above by BT Technology team for CR#95 version 2.0

        CURSOR get_cost_element_cu (p_costing_org     IN NUMBER,
                                    p_material_cost   IN NUMBER)
        IS
            SELECT DECODE (basis_type, 1, item_cost, ((p_material_cost * usage_rate_or_amount))) -- Modified by BT Technology team for defect#713
                                                                                                 item_cost
              FROM cst_item_cost_details_v
             WHERE     organization_id = p_costing_org
                   AND inventory_item_id = p_inventory_item_id
                   AND UPPER (resource_code) = UPPER (p_cost_element)
                   AND cost_type_id = 1000;

        CURSOR get_sum_cost_element_cu (p_costing_org     IN NUMBER,
                                        p_material_cost   IN NUMBER)
        IS
            SELECT SUM (DECODE (basis_type, 1, item_cost, (p_material_cost * usage_rate_or_amount))) -- Modified by BT Technology team for defect#713
              FROM cst_item_cost_details_v
             WHERE     organization_id = p_costing_org
                   AND inventory_item_id = p_inventory_item_id
                   AND cost_type_id = 1000
                   -- Start modification by BT Technology team for defect#713
                   AND resource_code <> 'DUTY';

        -- End modification by BT Technology team for defect#713
        -- Commented below by BT Tech Team for defect# 431 on 03-Nov-2015
        /*  CURSOR get_material_cost_cu ( p_costing_org       IN NUMBER)
          IS
          SELECT NVL(item_cost,0)
            FROM cst_item_cost_details_v
           WHERE organization_id     = p_costing_org
             AND inventory_item_id   = p_inventory_item_id
             AND cost_element        = 'Material'
             AND cost_type_id        = 2
             AND resource_code IS NULL;

          CURSOR get_material_ohd_cost_cu ( p_costing_org       IN NUMBER)
          IS
          SELECT item_cost
            FROM cst_item_cost_details_v
           WHERE organization_id     = p_costing_org
             AND inventory_item_id   = p_inventory_item_id
             AND cost_element        = 'Material Overhead'
             AND cost_type_id        = 2
             AND resource_code IS NULL; */
        -- Commented above by BT Tech Team for defect# 431 on 03-Nov-2015

        -- Added below by BT Tech Team for defect# 431 on 03-Nov-2015
        CURSOR get_material_cost_cu (p_costing_org IN NUMBER)
        IS
            SELECT cicd1.item_cost
              FROM cst_item_cost_type_v cict, cst_item_cost_details_v cicd1, cst_cost_types cct1
             WHERE     1 = 1
                   AND cicd1.cost_type_id = cct1.cost_type_id
                   AND cct1.cost_type = 'Average'
                   AND cict.cost_type_id = cct1.cost_type_id
                   AND cicd1.cost_element = 'Material'
                   AND cicd1.inventory_item_id = cict.inventory_item_id
                   AND cicd1.organization_id = cict.organization_id
                   AND cict.inventory_item_id = p_inventory_item_id
                   AND cict.organization_id = p_costing_org;

        CURSOR get_material_ohd_cost_cu (p_costing_org IN NUMBER)
        IS
            SELECT cicd1.item_cost
              FROM cst_item_cost_type_v cict, cst_item_cost_details_v cicd1, cst_cost_types cct1
             WHERE     1 = 1
                   AND cicd1.cost_type_id = cct1.cost_type_id
                   AND cct1.cost_type = 'Average'
                   AND cict.cost_type_id = cct1.cost_type_id
                   AND cicd1.cost_element = 'Material Overhead'
                   AND cicd1.inventory_item_id = cict.inventory_item_id
                   AND cicd1.organization_id = cict.organization_id
                   AND cict.inventory_item_id = p_inventory_item_id
                   AND cict.organization_id = p_costing_org;

        -- Added above by BT Tech Team for defect# 431 on 03-Nov-2015

        CURSOR get_price_list_id (p_price_list_name IN VARCHAR2)
        IS
            SELECT list_header_id
              FROM qp_list_headers_all
             WHERE name = p_price_list_name;

        -- Added below by BT Technology team for CR#95 version 2.0
        CURSOR get_daily_rate_c (p_from_currency IN VARCHAR2, p_to_currency IN VARCHAR2, p_rate_type IN VARCHAR2
                                 , p_conv_date IN DATE)
        IS
            SELECT NVL (conversion_rate, 1)
              FROM gl_daily_rates
             WHERE     from_currency = p_from_currency
                   AND to_currency = p_to_currency
                   AND conversion_type = p_rate_type
                   AND conversion_date = p_conv_date;

        -- Added above by BT Technology team for CR#95 version 2.0

        -- lc_line_det_cu       get_line_det_cu%ROWTYPE;
        lc_attribute_val_cu    fnd_flex_values%ROWTYPE;
        lc_cost_element_cu     get_cost_element_cu%ROWTYPE;
        lc_order_type          VARCHAR2 (100);
        lc_reclass             VARCHAR2 (100);
        ln_list_header_id      NUMBER;
        ln_material_cost       NUMBER;
        ln_material_ohd_cost   NUMBER;
        ln_sum_cost            NUMBER;
        ln_duty                NUMBER;
        ln_to_org_id           NUMBER;
        ln_to_invorg_id        NUMBER;
        -- Added below by BT Technology team for CR#95 version 2.0
        ln_conversion_rate     NUMBER;
        lc_po_country          VARCHAR2 (100);
        -- Added above by BT Technology team for CR#95 version 2.0
        lc_order_source        VARCHAR2 (100);
        lc_query               VARCHAR2 (3000);
        lc_where_clause        VARCHAR2 (3000);
        ln_from_org_id         NUMBER;
        ln_from_invorg_id      NUMBER;
        lc_order_currency      VARCHAR2 (10);
        lc_source              VARCHAR2 (100);          --added for defect 685
    BEGIN
        -- start changes for defect 685
        lc_source             := NVL (p_source, 'NONE');

        -- IF check_price_list_fnc (p_line_id) = 0 AND p_line_id IS NOT NULL
        IF     check_price_list_fnc (p_line_id) = 0
           AND p_line_id IS NOT NULL
           AND lc_source <> 'VT'                  --end changes for defect 685
        THEN
            RETURN 0;
        END IF;

        lc_attribute_val_cu   := NULL;
        lc_cost_element_cu    := NULL;

        OPEN get_reclass_cu;

        FETCH get_reclass_cu INTO lc_reclass;

        CLOSE get_reclass_cu;

        OPEN get_order_curr_cu;

        FETCH get_order_curr_cu INTO lc_order_currency;

        CLOSE get_order_curr_cu;

        -- Added below by BT Technology team for CR#95 version 2.0
        lc_po_country         := NULL;

        IF p_line_id IS NOT NULL
        THEN
            OPEN get_line_det_cu;

            FETCH get_line_det_cu INTO lc_order_source;

            CLOSE get_line_det_cu;

            IF lc_order_source = 'Internal'
            THEN
                OPEN get_po_country_cu;

                FETCH get_po_country_cu INTO lc_po_country;

                CLOSE get_po_country_cu;

                /*OPEN get_to_ou_cu;
                FETCH get_to_ou_cu INTO ln_to_org_id;
                CLOSE get_to_ou_cu; */

                OPEN get_to_org_cu;

                FETCH get_to_org_cu INTO ln_to_org_id, ln_to_invorg_id;

                CLOSE get_to_org_cu;
            ELSE
                ln_to_org_id      := p_from_org_id;
                ln_to_invorg_id   := NULL;                     --p_to_inv_org;
            END IF;

            OPEN get_from_org_cu;

            FETCH get_from_org_cu INTO ln_from_org_id, ln_from_invorg_id;

            CLOSE get_from_org_cu;
        ELSE
            ln_from_org_id      := p_from_org_id;
            ln_from_invorg_id   := p_from_inv_org;
            ln_to_org_id        := p_to_org_id;
            ln_to_invorg_id     := p_to_inv_org;
        END IF;

        lc_where_clause       :=
            BUILD_WHERE_CLAUSE (p_from_org_id      => ln_from_org_id,
                                p_to_org_id        => ln_to_org_id,
                                p_from_inv_org     => ln_from_invorg_id,
                                p_to_inv_org       => ln_to_invorg_id,
                                p_brand            => p_brand,
                                p_reclass          => lc_reclass,
                                p_order_currency   => lc_order_currency,
                                p_source_factory   => lc_po_country,
                                p_line_id          => p_line_id);

        lc_query              :=
            ' SELECT ffv.* 
                       FROM fnd_flex_value_sets ffvs,
                            fnd_flex_values      ffv
                      WHERE ffv.flex_value_set_id                               = ffvs.flex_value_set_id
                        AND flex_value_set_name                                 = ''DO_INTERCOMPANY''
                        AND ffv.enabled_flag                                    = ''Y''
                        AND TRUNC(SYSDATE) BETWEEN NVL(START_DATE_ACTIVE,TRUNC(SYSDATE)) 
                                               AND NVL(END_DATE_ACTIVE,TRUNC(SYSDATE)) ';


        lc_query              := lc_query || lc_where_clause;

        -- Added above by BT Technology team for CR#95 version 2.0

        EXECUTE IMMEDIATE lc_query
            INTO lc_attribute_val_cu;


        IF p_cost_element = 'MATERIAL_COST_FACT'
        THEN
            RETURN NVL (lc_attribute_val_cu.attribute6, 0);
        ELSIF p_cost_element = 'DUTY_FCT'
        THEN
            RETURN NVL (lc_attribute_val_cu.attribute7, 0);
        ELSIF p_cost_element = 'FREIGHT_WITH_DUTY_FCT'
        THEN
            RETURN NVL (lc_attribute_val_cu.attribute8, 0);
        ELSIF p_cost_element = 'FREIGHT_WITHOUT_DUTY_FCT'
        THEN
            RETURN NVL (lc_attribute_val_cu.attribute9, 0);
        ELSIF p_cost_element = 'OVERHEAD_WITH_DUTY_FCT'
        THEN
            RETURN NVL (lc_attribute_val_cu.attribute10, 0);
        ELSIF p_cost_element = 'OVERHEAD_WITHOUT_DUTY_FCT'
        THEN
            RETURN NVL (lc_attribute_val_cu.attribute11, 0);
        ELSIF p_cost_element = 'MARKUP'
        THEN
            RETURN NVL (lc_attribute_val_cu.attribute12 / 100, 0);
        ELSIF p_cost_element = 'PRICELIST_FLAG'
        THEN
            IF lc_attribute_val_cu.attribute13 IS NULL
            THEN
                RETURN 0;
            ELSE
                RETURN 1;
            END IF;
        ELSIF p_cost_element = 'PRICELIST_ID'
        THEN
            IF lc_attribute_val_cu.attribute13 IS NULL
            THEN
                RETURN 0;
            ELSE
                OPEN get_price_list_id (lc_attribute_val_cu.attribute13);

                FETCH get_price_list_id INTO ln_list_header_id;

                CLOSE get_price_list_id;

                RETURN (NVL (ln_list_header_id, 0));
            END IF;
        ELSIF p_cost_element = 'EXCHANGE_RATE'
        THEN
            --  RETURN NVL(lc_attribute_val_cu.attribute18,1);   -- Commented by BT Technology team for CR#95 version 2.0
            -- Added below by BT Technology team for CR#95 version 2.0
            ln_conversion_rate   := 1;

            OPEN get_daily_rate_c (lc_attribute_val_cu.attribute16, lc_attribute_val_cu.attribute19, lc_attribute_val_cu.attribute18
                                   , TRUNC (SYSDATE));

            FETCH get_daily_rate_c INTO ln_conversion_rate;

            CLOSE get_daily_rate_c;

            RETURN NVL (ln_conversion_rate, 1);
        -- Added above by BT Technology team for CR#95 version 2.0
        ELSIF p_cost_element = 'ORDER_TYPE'
        THEN
            RETURN lc_attribute_val_cu.attribute17;
        ELSIF p_cost_element = 'PRICE_LIST'
        THEN
            ln_pricelist   := 0;

            OPEN get_listprice_cu (
                NVL (lc_attribute_val_cu.attribute5, ln_from_invorg_id));

            FETCH get_listprice_cu INTO ln_pricelist;

            CLOSE get_listprice_cu;

            RETURN ln_pricelist;
        ELSIF p_cost_element = 'Material'
        THEN
            OPEN get_material_cost_cu (
                NVL (lc_attribute_val_cu.attribute5, ln_from_invorg_id));

            FETCH get_material_cost_cu INTO ln_material_cost;

            CLOSE get_material_cost_cu;

            IF NVL (ln_material_cost, 0) = 0
            THEN
                OPEN get_listprice_cu (
                    NVL (lc_attribute_val_cu.attribute5, ln_from_invorg_id));

                FETCH get_listprice_cu INTO ln_material_cost;

                CLOSE get_listprice_cu;
            END IF;

            RETURN NVL (ln_material_cost, 0);
        ELSIF p_cost_element = 'DUTY'
        THEN
            OPEN get_material_cost_cu (
                NVL (lc_attribute_val_cu.attribute5, ln_from_invorg_id));

            FETCH get_material_cost_cu INTO ln_material_cost;

            CLOSE get_material_cost_cu;

            OPEN get_material_ohd_cost_cu (
                NVL (lc_attribute_val_cu.attribute5, ln_from_invorg_id));

            FETCH get_material_ohd_cost_cu INTO ln_material_ohd_cost;

            CLOSE get_material_ohd_cost_cu;

            OPEN get_sum_cost_element_cu (
                NVL (lc_attribute_val_cu.attribute5, ln_from_invorg_id),
                ln_material_cost);

            FETCH get_sum_cost_element_cu INTO ln_sum_cost;

            CLOSE get_sum_cost_element_cu;

            -- Start modification by BT Technology team for defect#713
            --RETURN (NVL(ln_material_ohd_cost,0)-NVL(ln_sum_cost,0));
            RETURN (CASE
                        WHEN (NVL (ln_material_ohd_cost, 0) - NVL (ln_sum_cost, 0)) >
                             0
                        THEN
                            (NVL (ln_material_ohd_cost, 0) - NVL (ln_sum_cost, 0))
                        ELSE
                            0
                    END);
        -- End modification by BT Technology team for defect#713

        ELSE
            OPEN get_material_cost_cu (
                NVL (lc_attribute_val_cu.attribute5, ln_from_invorg_id));

            FETCH get_material_cost_cu INTO ln_material_cost;

            CLOSE get_material_cost_cu;

            OPEN get_cost_element_cu (
                NVL (lc_attribute_val_cu.attribute5, ln_from_invorg_id),
                ln_material_cost);

            FETCH get_cost_element_cu INTO lc_cost_element_cu;

            CLOSE get_cost_element_cu;

            RETURN NVL (lc_cost_element_cu.item_cost, 0);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*  DBMS_OUTPUT.PUT_LINE('Excpetion'||SQLERRM);

                  LOG ( p_line_id         => p_line_id,
                        p_from_org_id     => ln_from_org_id,
                        p_to_org_id       => ln_to_org_id,
                        p_from_inv_org    => ln_from_invorg_id,
                        p_to_inv_org      => ln_to_invorg_id,
                        p_brand           => p_brand,
                        p_reclass         => lc_reclass,
                        p_order_currency  => lc_order_currency,
                        p_source_factory  => lc_po_country,
                        p_function_name   => 'MAIN',
                        p_error_message   => 'Exception in Main Function is '||SQLERRM); */
            RETURN 0;
    END MAIN;

    -- Start of functions to get cost
    -- Function to get material cost
    FUNCTION GET_MATERIAL_COST (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_material_cost   NUMBER;
    BEGIN
        ln_material_cost   := 0;
        ln_material_cost   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'Material', p_line_id,
                  p_source);
        RETURN ln_material_cost;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_MATERIAL_COST;

    -- Function to get Over head cost with duty
    FUNCTION GET_OVERHEAD_WITH_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                     , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_overhead_with_duty   NUMBER;
    BEGIN
        ln_overhead_with_duty   := 0;
        ln_overhead_with_duty   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'OH DUTY', p_line_id,
                  p_source);
        RETURN ln_overhead_with_duty;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_OVERHEAD_WITH_DUTY;

    -- Function to get Over head cost without duty
    FUNCTION GET_OVERHEAD_WITHOUT_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                        , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_overhead_without_duty   NUMBER;
    BEGIN
        ln_overhead_without_duty   := 0;
        ln_overhead_without_duty   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'OH NONDUTY', p_line_id,
                  p_source);
        RETURN ln_overhead_without_duty;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_OVERHEAD_WITHOUT_DUTY;

    -- Function to get freight without duty
    FUNCTION GET_FREIGHT_WITHOUT_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                       , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_FREIGHT_without_duty   NUMBER;
    BEGIN
        ln_FREIGHT_without_duty   := 0;
        ln_FREIGHT_without_duty   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'FREIGHT', p_line_id,
                  p_source);
        RETURN ln_FREIGHT_without_duty;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_FREIGHT_WITHOUT_DUTY;

    -- Function to get freight with duty
    FUNCTION GET_FREIGHT_WITH_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                    , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_FREIGHT_with_duty   NUMBER;
    BEGIN
        ln_FREIGHT_with_duty   := 0;
        ln_FREIGHT_with_duty   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'FREIGHT DU', p_line_id,
                  p_source);
        RETURN ln_FREIGHT_with_duty;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_FREIGHT_WITH_DUTY;

    -- Function to get Duty
    FUNCTION GET_DUTY (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                       , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_duty   NUMBER;
    BEGIN
        ln_duty   := 0;
        ln_duty   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'DUTY', p_line_id,
                  p_source);
        RETURN NVL (ln_duty, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_DUTY;

    -- Function to get price list
    FUNCTION GET_PRICELIST (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                            , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_pricelist   NUMBER;
    BEGIN
        ln_pricelist   := 0;
        ln_pricelist   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'PRICE_LIST', p_line_id,
                  p_source);
        RETURN ln_pricelist;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_PRICELIST;

    -- End of functions to get the cost
    -- Start of functions to get cost factors from DO_INTERCOMPANY value set DFF
    -- Function to get material cost factor
    FUNCTION GET_MATERIAL_COST_FACT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                     , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_material_cost_fact   NUMBER;
    BEGIN
        ln_material_cost_fact   := 0;
        ln_material_cost_fact   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'MATERIAL_COST_FACT', p_line_id,
                  p_source);
        RETURN ln_material_cost_fact;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_MATERIAL_COST_FACT;

    -- Function to get over head with duty factor
    FUNCTION GET_OVERHEAD_WITH_DUTY_FACT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                          , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_overhead_with_duty_fct   NUMBER;
    BEGIN
        ln_overhead_with_duty_fct   := 0;
        ln_overhead_with_duty_fct   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'OVERHEAD_WITH_DUTY_FCT', p_line_id,
                  p_source);
        RETURN ln_overhead_with_duty_fct;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_OVERHEAD_WITH_DUTY_FACT;

    -- Function to get over head without duty factor
    FUNCTION GET_OVERHEAD_WITHOUT_DUTY_FCT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                            , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_overhead_without_duty_fct   NUMBER;
    BEGIN
        ln_overhead_without_duty_fct   := 0;
        ln_overhead_without_duty_fct   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'OVERHEAD_WITHOUT_DUTY_FCT', p_line_id,
                  p_source);
        RETURN ln_overhead_without_duty_fct;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_OVERHEAD_WITHOUT_DUTY_FCT;

    -- Function to get freight without duty factor
    FUNCTION GET_FREIGHT_WITHOUT_DUTY_FCT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                           , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_FREIGHT_without_duty_fct   NUMBER;
    BEGIN
        ln_FREIGHT_without_duty_fct   := 0;
        ln_FREIGHT_without_duty_fct   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'FREIGHT_WITHOUT_DUTY_FCT', p_line_id,
                  p_source);
        RETURN ln_FREIGHT_without_duty_fct;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_FREIGHT_WITHOUT_DUTY_FCT;

    -- Function to get freight with duty factor
    FUNCTION GET_FREIGHT_WITH_DUTY_FCT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                        , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_FREIGHT_with_duty_fct   NUMBER;
    BEGIN
        ln_FREIGHT_with_duty_fct   := 0;
        ln_FREIGHT_with_duty_fct   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'FREIGHT_WITH_DUTY_FCT', p_line_id,
                  p_source);
        RETURN ln_FREIGHT_with_duty_fct;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_FREIGHT_WITH_DUTY_FCT;

    -- Function to get duty factor
    FUNCTION GET_DUTY_FCT (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                           , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_duty_fct   NUMBER;
    BEGIN
        ln_duty_fct   := 0;
        ln_duty_fct   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'DUTY_FCT', p_line_id,
                  p_source);
        RETURN ln_duty_fct;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_DUTY_FCT;

    -- Function to get markup
    FUNCTION GET_MARKUP (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                         , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_markup   NUMBER;
    BEGIN
        ln_markup   := 0;
        ln_markup   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'MARKUP', p_line_id,
                  p_source);
        RETURN ln_markup;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_MARKUP;

    -- Function to get Order Type
    FUNCTION GET_ORDER_TYPE (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                             , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2
    IS
        lc_order_type   VARCHAR2 (150);
    BEGIN
        lc_order_type   := NULL;
        lc_order_type   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'ORDER_TYPE', p_line_id,
                  p_source);
        RETURN lc_order_type;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END GET_ORDER_TYPE;

    -- Function to get exchange rate
    FUNCTION GET_EXCHANGE_RATE (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_exchange_rate   NUMBER;
    BEGIN
        ln_exchange_rate   := 1;
        ln_exchange_rate   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'EXCHANGE_RATE', p_line_id,
                  p_source);
        RETURN ln_exchange_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 1;
    END GET_EXCHANGE_RATE;

    -- End of functions to get cost factors from DO_INTERCOMPANY value set DFF

    -- Commented below by BT tech Team on 08-Mar-2016 to not to use pricing engine API
    -- as it is creating issue while pricing multiple lines at a time v1.1

    /*  PROCEDURE PRICE_LIST_PRICE (
         p_price_list_id       IN     NUMBER,
         p_inventory_item_id   IN     NUMBER,
         p_category_id         IN     NUMBER,
         p_currency_code       IN     VARCHAR2,
         p_uom                 IN     VARCHAR2,
         p_price_list             OUT NUMBER,
         p_line_id             IN     NUMBER DEFAULT NULL)
      IS
         PRAGMA AUTONOMOUS_TRANSACTION;

         -- Variables for Pricing Engine
         p_line_tbl               QP_PREQ_GRP.LINE_TBL_TYPE;
         p_qual_tbl               QP_PREQ_GRP.QUAL_TBL_TYPE;
         p_line_attr_tbl          QP_PREQ_GRP.LINE_ATTR_TBL_TYPE;
         p_LINE_DETAIL_tbl        QP_PREQ_GRP.LINE_DETAIL_TBL_TYPE;
         p_LINE_DETAIL_qual_tbl   QP_PREQ_GRP.LINE_DETAIL_QUAL_TBL_TYPE;
         p_LINE_DETAIL_attr_tbl   QP_PREQ_GRP.LINE_DETAIL_ATTR_TBL_TYPE;
         p_related_lines_tbl      QP_PREQ_GRP.RELATED_LINES_TBL_TYPE;
         p_control_rec            QP_PREQ_GRP.CONTROL_RECORD_TYPE;
         x_line_tbl               QP_PREQ_GRP.LINE_TBL_TYPE;
         x_line_qual              QP_PREQ_GRP.QUAL_TBL_TYPE;
         x_line_attr_tbl          QP_PREQ_GRP.LINE_ATTR_TBL_TYPE;
         x_line_detail_tbl        QP_PREQ_GRP.LINE_DETAIL_TBL_TYPE;
         x_line_detail_qual_tbl   QP_PREQ_GRP.LINE_DETAIL_QUAL_TBL_TYPE;
         x_line_detail_attr_tbl   QP_PREQ_GRP.LINE_DETAIL_ATTR_TBL_TYPE;
         x_related_lines_tbl      QP_PREQ_GRP.RELATED_LINES_TBL_TYPE;
         x_return_status          VARCHAR2 (240);
         x_return_status_text     VARCHAR2 (240);
         qual_rec                 QP_PREQ_GRP.QUAL_REC_TYPE;
         line_attr_rec            QP_PREQ_GRP.LINE_ATTR_REC_TYPE;
         line_rec                 QP_PREQ_GRP.LINE_REC_TYPE;
         rltd_rec                 QP_PREQ_GRP.RELATED_LINES_REC_TYPE;
         I                        BINARY_INTEGER;
         l_version                VARCHAR2 (240);
      BEGIN
         -- Passing Information to the Pricing Engine

         -- Setting up the control record variables
         -- Please refer documentation for explanation of each of these settings

         p_control_rec.pricing_event := 'LINE';
         p_control_rec.calculate_flag := 'Y';
         p_control_rec.simulation_flag := 'N';

         -- Request Line (Order Line) Information
         line_rec.request_type_code := 'ONT';
         line_rec.line_id := NULL; -- Order Line Id. This can be any thing for this script
         line_rec.line_Index := '1';                        -- Request Line Index
         line_rec.line_type_code := 'LINE';        -- LINE or ORDER(Summary Line)
         line_rec.pricing_effective_date := SYSDATE; -- Pricing as of what date ?
         line_rec.active_date_first := SYSDATE; -- Can be Ordered Date or Ship Date
         line_rec.active_date_second := SYSDATE; -- Can be Ordered Date or Ship Date
         line_rec.active_date_first_type := 'NO TYPE';                -- ORD/SHIP
         line_rec.active_date_second_type := 'NO TYPE';               -- ORD/SHIP
         line_rec.line_quantity := 1;                         -- Ordered Quantity
         line_rec.line_uom_code := p_uom;                     -- Ordered UOM Code
         line_rec.currency_code := p_currency_code;              -- Currency Code
         line_rec.price_flag := 'Y'; --lc_item_details_cu.calculate_price_flag;                   -- Price Flag can have 'Y' , 'N'(No pricing) , 'P'(Phase)
         p_line_tbl (1) := line_rec;

         -- If u need to get the price for multiple order lines , please fill the above information for each line
         -- and add to the p_line_tbl

         -- Pricing Attributes Passed In
         -- Please refer documentation for explanation of each of these settings
         line_attr_rec.LINE_INDEX := 1; -- Attributes for the above line. Attributes are attached with the line index
         line_attr_rec.PRICING_CONTEXT := 'ITEM';                              --
         line_attr_rec.PRICING_ATTRIBUTE := 'PRICING_ATTRIBUTE1';
         line_attr_rec.PRICING_ATTR_VALUE_FROM := p_inventory_item_id; -- Inventory Item Id
         line_attr_rec.VALIDATED_FLAG := 'N';
         p_line_attr_tbl (1) := line_attr_rec;

         line_attr_rec.LINE_INDEX := 1; -- Attributes for the above line. Attributes are attached with the line index
         line_attr_rec.PRICING_CONTEXT := 'ITEM';                              --
         line_attr_rec.PRICING_ATTRIBUTE := 'PRICING_ATTRIBUTE2';
         line_attr_rec.PRICING_ATTR_VALUE_FROM := p_category_id; -- Inventory Item Id
         line_attr_rec.VALIDATED_FLAG := 'N';
         p_line_attr_tbl (2) := line_attr_rec;

         -- If u need to add multiple attributes , please fill the above information for each attribute
         -- and add to the p_line_attr_tbl
         -- Make sure that u are adding the attribute to the right line index

         -- Qualifiers Passed In
         -- Please refer documentation for explanation of each of these settings
         qual_rec.LINE_INDEX := 1; -- Attributes for the above line. Attributes are attached with the line index
         qual_rec.QUALIFIER_CONTEXT := 'MODLIST';
         qual_rec.QUALIFIER_ATTRIBUTE := 'QUALIFIER_ATTRIBUTE4';
         qual_rec.QUALIFIER_ATTR_VALUE_FROM := p_price_list_id;  -- Price List Id
         qual_rec.COMPARISON_OPERATOR_CODE := '=';
         qual_rec.VALIDATED_FLAG := 'Y';
         p_qual_tbl (1) := qual_rec;

         -- This statement prints out the version of the QP_PREQ_PUB API(QPXPPREB.pls).Information only
         l_version := QP_PREQ_GRP.GET_VERSION;
         DBMS_OUTPUT.PUT_LINE ('Before API');
         -- Actual Call to the Pricing Engine
         QP_PREQ_PUB.PRICE_REQUEST (p_line_tbl,
                                    p_qual_tbl,
                                    p_line_attr_tbl,
                                    p_line_detail_tbl,
                                    p_line_detail_qual_tbl,
                                    p_line_detail_attr_tbl,
                                    p_related_lines_tbl,
                                    p_control_rec,
                                    x_line_tbl,
                                    x_line_qual,
                                    x_line_attr_tbl,
                                    x_line_detail_tbl,
                                    x_line_detail_qual_tbl,
                                    x_line_detail_attr_tbl,
                                    x_related_lines_tbl,
                                    x_return_status,
                                    x_return_status_text);
         I := x_line_tbl.FIRST;

         IF I IS NOT NULL
         THEN
            IF x_return_status = 'S'
            THEN
               p_price_list := NVL (x_line_tbl (I).adjusted_unit_price, 0);
               COMMIT;
            ELSE
               p_price_list := 0;
            END IF;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            p_price_list := 0;
      END price_list_price;
      */
    -- Commented above by BT tech Team on 08-Mar-2016 to not to use pricing engine API
    -- as it is creating issue while pricing multiple lines at a time  v1.1

    -- Added below by BT tech Team on 08-Mar-2016 to not to use pricing engine API
    -- as it is creating issue while pricing multiple lines at a time  v1.1

    -- Derivation of price at SKU level and if not found derive the price at Category level

    PROCEDURE PRICE_LIST_PRICE (p_price_list_id IN NUMBER, p_inventory_item_id IN NUMBER, p_category_id IN NUMBER, p_currency_code IN VARCHAR2, p_uom IN VARCHAR2, p_price_list OUT NUMBER
                                , p_line_id IN NUMBER DEFAULT NULL)
    IS
        ln_listprice   NUMBER;
    BEGIN
        DBMS_OUTPUT.put_line ('p_inventory_item_id' || p_inventory_item_id);
        DBMS_OUTPUT.put_line ('p_price_list_id' || p_price_list_id);
        DBMS_OUTPUT.put_line ('p_uom' || p_uom);

        BEGIN
            SELECT unit_price
              INTO ln_listprice
              FROM (  SELECT NVL (qpl.operand, 0) AS unit_price
                        FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qpl
                       WHERE     qpa.product_attribute_context = 'ITEM'
                             AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                             AND qpa.product_attr_value =
                                 TO_CHAR (p_inventory_item_id)
                             AND qpa.list_header_id = p_price_list_id
                             AND qpa.product_uom_code = NVL (p_uom, ' ')
                             AND qpl.list_line_id = qpa.list_line_id
                             AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                             NVL (
                                                                 qpl.start_date_active,
                                                                 SYSDATE))
                                                     AND TRUNC (
                                                             NVL (
                                                                 qpl.end_date_active,
                                                                 SYSDATE))
                    ORDER BY qpl.product_precedence)
             WHERE ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    SELECT unit_price
                      INTO ln_listprice
                      FROM (  SELECT NVL (operand, 0) AS unit_price
                                FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qpl, apps.mtl_item_categories mic,
                                     inv.mtl_category_sets_tl mcs
                               WHERE     mic.organization_id =
                                         (SELECT organization_id
                                            FROM apps.org_organization_definitions
                                           WHERE organization_name =
                                                 'MST_Deckers_Item_Master')
                                     AND mcs.category_set_id =
                                         mic.category_set_id
                                     AND mcs.category_set_name =
                                         'OM Sales Category'
                                     AND source_lang = USERENV ('LANG')
                                     AND mic.inventory_item_id =
                                         p_inventory_item_id
                                     AND qpa.product_attribute_context = 'ITEM'
                                     AND qpa.product_attribute =
                                         'PRICING_ATTRIBUTE2'
                                     AND qpa.product_attr_value =
                                         TO_CHAR (mic.category_id)
                                     AND qpa.product_uom_code =
                                         NVL (p_uom, ' ')
                                     AND qpa.list_header_id = p_price_list_id
                                     AND qpl.list_header_id =
                                         qpa.list_header_id
                                     AND qpl.list_line_id = qpa.list_line_id
                                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                     NVL (
                                                                         qpl.start_date_active,
                                                                         SYSDATE))
                                                             AND TRUNC (
                                                                     NVL (
                                                                         qpl.end_date_active,
                                                                         SYSDATE))
                            ORDER BY qpl.product_precedence)
                     WHERE ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_listprice   := 0;
                END;
            WHEN OTHERS
            THEN
                ln_listprice   := 0;
        END;

        p_price_list   := ln_listprice;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_price_list   := 0;
    END PRICE_LIST_PRICE;

    -- Added above by BT tech Team on 08-Mar-2016 to not to use pricing engine API
    -- as it is creating issue while pricing multiple lines at a time v1.1
    FUNCTION GET_PRICE_LIST_PRICE (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                   , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_price_list      NUMBER;
        ln_price_list_id   NUMBER;
        ln_category_id     NUMBER;
        lc_uom             VARCHAR2 (100);
        lc_currency        VARCHAR2 (100);

        CURSOR get_category_c IS
            SELECT category_id
              FROM xxd_common_items_v
             WHERE     inventory_item_id = p_inventory_item_id
                   AND organization_id =
                       (SELECT organization_id
                          FROM org_organization_definitions
                         WHERE organization_name = 'MST_Deckers_Item_Master');

        CURSOR get_pricing_det (p_category_id     IN NUMBER,
                                p_price_list_id   IN NUMBER)
        IS
            SELECT DISTINCT currency_code, product_uom_code
              FROM qp_list_headers qlh, qp_list_lines_v qll
             WHERE     qll.list_header_id = qlh.list_header_id
                   AND qlh.list_header_id = p_price_list_id
                   AND product_attr_value =
                       DECODE (product_attribute,
                               'PRICING_ATTRIBUTE1', p_inventory_item_id,
                               'PRICING_ATTRIBUTE2', p_category_id)
                   AND TRUNC (SYSDATE) BETWEEN NVL (qll.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (qll.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND ROWNUM = 1;
    BEGIN
        ln_price_list_id   := 0;

        ln_price_list_id   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'PRICELIST_ID', p_line_id,
                  p_source);

        OPEN get_category_c;

        FETCH get_category_c INTO ln_category_id;

        CLOSE get_category_c;

        IF ln_category_id IS NULL
        THEN
            RETURN 0;
        ELSE
            OPEN get_pricing_det (ln_category_id, ln_price_list_id);

            FETCH get_pricing_det INTO lc_currency, lc_uom;

            CLOSE get_pricing_det;

            IF lc_currency IS NULL OR lc_uom IS NULL
            THEN
                RETURN 0;
            ELSE
                xxdo_intercom_pricing_pkg.price_list_price (
                    ln_price_list_id,
                    p_inventory_item_id,
                    ln_category_id,
                    lc_currency,
                    lc_uom,
                    ln_price_list);
            END IF;
        END IF;

        RETURN NVL (ln_price_list, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    FUNCTION CHECK_PRICELIST_FLAG (p_from_inv_org IN NUMBER, p_to_inv_org IN NUMBER, p_from_org_id IN NUMBER, p_to_org_id IN NUMBER, p_brand IN VARCHAR2, p_inventory_item_id IN NUMBER
                                   , p_order_type_id IN NUMBER, p_line_id IN NUMBER DEFAULT NULL, p_source IN VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2
    IS
        lc_price_list_flag   VARCHAR2 (10);
    BEGIN
        lc_price_list_flag   := 'N';
        lc_price_list_flag   :=
            MAIN (p_from_inv_org, p_to_inv_org, p_from_org_id,
                  p_to_org_id, p_brand, p_inventory_item_id,
                  p_order_type_id, 'PRICELIST_FLAG', p_line_id,
                  p_source);

        IF lc_price_list_flag = 0
        THEN
            RETURN 'N';
        ELSE
            RETURN 'Y';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END CHECK_PRICELIST_FLAG;

    FUNCTION item_duty_value (pn_line_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_from_inv_org_id     NUMBER;
        ln_from_org_id         NUMBER;
        lv_brand               VARCHAR2 (50);
        ln_inventory_item_id   NUMBER;
        ln_order_type_id       NUMBER;
        ln_material_cost       NUMBER;
        ln_price_list_price    NUMBER;
        ln_sub_calc_price      NUMBER;
        ln_to_inv_org_id       NUMBER;
        ln_calc_price          NUMBER;
        ln_to_org_id           NUMBER;
        ln_source              VARCHAR2 (50) := 'VT';

        ln_duty_val            NUMBER;
    BEGIN
        BEGIN
            --Get values for function calls
            SELECT oola.ship_from_org_id from_inv_org_id, oola.org_id from_org_id, ooha.attribute5 brand,
                   oola.inventory_item_id, ooha.order_type_id, oola.ship_to_org_id
              INTO ln_from_inv_org_id, ln_from_org_id, lv_brand, ln_inventory_item_id,
                                     ln_order_type_id, ln_to_inv_org_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     ooha.header_id = oola.header_id
                   AND oola.line_id = pn_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN 0;
        END;

        ln_duty_val   :=
              get_duty (p_from_inv_org        => ln_from_inv_org_id,
                        p_to_inv_org          => ln_to_inv_org_id,
                        p_from_org_id         => ln_from_org_id,
                        p_to_org_id           => ln_to_org_id,
                        p_brand               => lv_brand,
                        p_inventory_item_id   => ln_inventory_item_id,
                        p_order_type_id       => ln_order_type_id,
                        p_line_id             => pn_line_id,
                        p_source              => ln_source)
            * NVL (
                  get_duty_fct (p_from_inv_org        => ln_from_inv_org_id,
                                p_to_inv_org          => ln_to_inv_org_id,
                                p_from_org_id         => ln_from_org_id,
                                p_to_org_id           => ln_to_org_id,
                                p_brand               => lv_brand,
                                p_inventory_item_id   => ln_inventory_item_id,
                                p_order_type_id       => ln_order_type_id,
                                p_line_id             => pn_line_id,
                                p_source              => ln_source),
                  1);

        RETURN ROUND (ln_duty_val, 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    FUNCTION item_unit_cost (pn_line_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_from_inv_org_id     NUMBER;
        ln_from_org_id         NUMBER;
        lv_brand               VARCHAR2 (50);
        ln_inventory_item_id   NUMBER;
        ln_order_type_id       NUMBER;
        ln_material_cost       NUMBER;
        ln_price_list_price    NUMBER;
        ln_sub_calc_price      NUMBER;
        ln_to_inv_org_id       NUMBER;
        ln_calc_price          NUMBER;
        ln_to_org_id           NUMBER;
        ln_source              VARCHAR2 (50) := 'VT';
        ln_conversion_rate     NUMBER;
    BEGIN
        BEGIN
            --Get values for function calls
            SELECT oola.ship_from_org_id from_inv_org_id, oola.org_id from_org_id, ooha.attribute5 brand,
                   oola.inventory_item_id, ooha.order_type_id, oola.ship_to_org_id
              INTO ln_from_inv_org_id, ln_from_org_id, lv_brand, ln_inventory_item_id,
                                     ln_order_type_id, ln_to_inv_org_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     ooha.header_id = oola.header_id
                   AND oola.line_id = pn_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN 0;
        END;


        BEGIN
            SELECT conversion_rate
              INTO ln_conversion_rate
              FROM gl_daily_rates
             WHERE     from_currency = 'USD'
                   AND to_currency = 'EUR'
                   AND conversion_type = 'Corporate'
                   AND conversion_date = TRUNC (SYSDATE);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_conversion_rate   := 1;
        END;

        ln_material_cost   :=
            XXDO_INTERCOM_PRICING_PKG.GET_MATERIAL_COST (
                ln_from_inv_org_id,
                ln_to_inv_org_id,
                ln_from_org_id,
                ln_to_org_id,
                lv_brand,
                ln_inventory_item_id,
                ln_order_type_id,
                pn_line_id,
                ln_source);

        ln_price_list_price   :=
            XXDO_INTERCOM_PRICING_PKG.GET_PRICE_LIST_PRICE (
                ln_from_inv_org_id,
                ln_to_inv_org_id,
                ln_from_org_id,
                ln_to_org_id,
                lv_brand,
                ln_inventory_item_id,
                ln_order_type_id,
                pn_line_id,
                ln_source);

        --Get the calculated price from the formula
        ln_sub_calc_price   :=
              -- ln_price_list_price+
              (  ln_material_cost
               * NVL (
                     get_material_cost_fact (
                         p_from_inv_org        => ln_from_inv_org_id,
                         p_to_inv_org          => ln_to_inv_org_id,
                         p_from_org_id         => ln_from_org_id,
                         p_to_org_id           => ln_to_org_id,
                         p_brand               => lv_brand,
                         p_inventory_item_id   => ln_inventory_item_id,
                         p_order_type_id       => ln_order_type_id,
                         p_line_id             => pn_line_id,
                         p_source              => ln_source),
                     1))
            + (  get_duty (p_from_inv_org        => ln_from_inv_org_id,
                           p_to_inv_org          => ln_to_inv_org_id,
                           p_from_org_id         => ln_from_org_id,
                           p_to_org_id           => ln_to_org_id,
                           p_brand               => lv_brand,
                           p_inventory_item_id   => ln_inventory_item_id,
                           p_order_type_id       => ln_order_type_id,
                           p_line_id             => pn_line_id,
                           p_source              => ln_source)
               * NVL (
                     get_duty_fct (
                         p_from_inv_org        => ln_from_inv_org_id,
                         p_to_inv_org          => ln_to_inv_org_id,
                         p_from_org_id         => ln_from_org_id,
                         p_to_org_id           => ln_to_org_id,
                         p_brand               => lv_brand,
                         p_inventory_item_id   => ln_inventory_item_id,
                         p_order_type_id       => ln_order_type_id,
                         p_line_id             => pn_line_id,
                         p_source              => ln_source),
                     1))
            + (  get_overhead_with_duty (
                     p_from_inv_org        => ln_from_inv_org_id,
                     p_to_inv_org          => ln_to_inv_org_id,
                     p_from_org_id         => ln_from_org_id,
                     p_to_org_id           => ln_to_org_id,
                     p_brand               => lv_brand,
                     p_inventory_item_id   => ln_inventory_item_id,
                     p_order_type_id       => ln_order_type_id,
                     p_line_id             => pn_line_id,
                     p_source              => ln_source)
               * NVL (
                     get_overhead_with_duty_fact (
                         p_from_inv_org        => ln_from_inv_org_id,
                         p_to_inv_org          => ln_to_inv_org_id,
                         p_from_org_id         => ln_from_org_id,
                         p_to_org_id           => ln_to_org_id,
                         p_brand               => lv_brand,
                         p_inventory_item_id   => ln_inventory_item_id,
                         p_order_type_id       => ln_order_type_id,
                         p_line_id             => pn_line_id,
                         p_source              => ln_source),
                     1))
            + (  get_freight_without_duty (
                     p_from_inv_org        => ln_from_inv_org_id,
                     p_to_inv_org          => ln_to_inv_org_id,
                     p_from_org_id         => ln_from_org_id,
                     p_to_org_id           => ln_to_org_id,
                     p_brand               => lv_brand,
                     p_inventory_item_id   => ln_inventory_item_id,
                     p_order_type_id       => ln_order_type_id,
                     p_line_id             => pn_line_id,
                     p_source              => ln_source)
               * NVL (
                     get_freight_without_duty_fct (
                         p_from_inv_org        => ln_from_inv_org_id,
                         p_to_inv_org          => ln_to_inv_org_id,
                         p_from_org_id         => ln_from_org_id,
                         p_to_org_id           => ln_to_org_id,
                         p_brand               => lv_brand,
                         p_inventory_item_id   => ln_inventory_item_id,
                         p_order_type_id       => ln_order_type_id,
                         p_line_id             => pn_line_id,
                         p_source              => ln_source),
                     1))
            + (  get_freight_with_duty (
                     p_from_inv_org        => ln_from_inv_org_id,
                     p_to_inv_org          => ln_to_inv_org_id,
                     p_from_org_id         => ln_from_org_id,
                     p_to_org_id           => ln_to_org_id,
                     p_brand               => lv_brand,
                     p_inventory_item_id   => ln_inventory_item_id,
                     p_order_type_id       => ln_order_type_id,
                     p_line_id             => pn_line_id,
                     p_source              => ln_source)
               * NVL (
                     get_freight_with_duty_fct (
                         p_from_inv_org        => ln_from_inv_org_id,
                         p_to_inv_org          => ln_to_inv_org_id,
                         p_from_org_id         => ln_from_org_id,
                         p_to_org_id           => ln_to_org_id,
                         p_brand               => lv_brand,
                         p_inventory_item_id   => ln_inventory_item_id,
                         p_order_type_id       => ln_order_type_id,
                         p_line_id             => pn_line_id,
                         p_source              => ln_source),
                     1))
            + (  get_overhead_without_duty (
                     p_from_inv_org        => ln_from_inv_org_id,
                     p_to_inv_org          => ln_to_inv_org_id,
                     p_from_org_id         => ln_from_org_id,
                     p_to_org_id           => ln_to_org_id,
                     p_brand               => lv_brand,
                     p_inventory_item_id   => ln_inventory_item_id,
                     p_order_type_id       => ln_order_type_id,
                     p_line_id             => pn_line_id,
                     p_source              => ln_source)
               * NVL (
                     get_overhead_without_duty_fct (
                         p_from_inv_org        => ln_from_inv_org_id,
                         p_to_inv_org          => ln_to_inv_org_id,
                         p_from_org_id         => ln_from_org_id,
                         p_to_org_id           => ln_to_org_id,
                         p_brand               => lv_brand,
                         p_inventory_item_id   => ln_inventory_item_id,
                         p_order_type_id       => ln_order_type_id,
                         p_line_id             => pn_line_id,
                         p_source              => ln_source),
                     1));

        ln_calc_price   :=
              (  ln_sub_calc_price
               + (  ln_sub_calc_price
                  * NVL (
                        get_markup (
                            p_from_inv_org        => ln_from_inv_org_id,
                            p_to_inv_org          => ln_to_inv_org_id,
                            p_from_org_id         => ln_from_org_id,
                            p_to_org_id           => ln_to_org_id,
                            p_brand               => lv_brand,
                            p_inventory_item_id   => ln_inventory_item_id,
                            p_order_type_id       => ln_order_type_id,
                            p_line_id             => pn_line_id,
                            p_source              => ln_source),
                        1)))
            * ln_conversion_rate;

        RETURN ROUND (ln_calc_price, 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;



    FUNCTION get_bonded_value (pn_line_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_ret_val   NUMBER;
    BEGIN
        ln_ret_val   :=
            item_unit_cost (pn_line_id) - item_duty_value (pn_line_id);


        RETURN ROUND (ln_ret_val, 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_free_circulation_value (pn_line_id IN NUMBER)
        RETURN NUMBER
    IS
    BEGIN
        RETURN item_unit_cost (pn_line_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;
END XXD_OM_INTERCO_PRICE_PKG;
/
