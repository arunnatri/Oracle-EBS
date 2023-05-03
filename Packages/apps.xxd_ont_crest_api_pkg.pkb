--
-- XXD_ONT_CREST_API_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CREST_API_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CREST_API_PKG
    * Design       : This package will be used in REST API calls for CREST
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 20-May-2022  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE msg (p_appl VARCHAR2, p_msg VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO custom.do_debug (created_by, application_id, debug_text,
                                     session_id, call_stack)
                 VALUES (1875,                               -- BATCH.O2F User
                         'XXD_ONT_CREST_API_PKG:' || p_appl,
                         p_msg,
                         USERENV ('SESSIONID'),
                         SUBSTR (DBMS_UTILITY.format_call_stack, 1, 2000));

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END msg;

    PROCEDURE get_order_dtls (p_email_address IN VARCHAR2)
    AS
        l_cursor             SYS_REFCURSOR;
        ln_category_set_id   NUMBER;
        ln_order_source_id   NUMBER;
    BEGIN
        msg ('Email Address', p_email_address);

        BEGIN
            SELECT category_set_id
              INTO ln_category_set_id
              FROM mtl_category_sets
             WHERE category_set_name = 'Inventory';

            SELECT order_source_id
              INTO ln_order_source_id
              FROM oe_order_sources
             WHERE name = 'Flagstaff';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_category_set_id   := NULL;
                ln_order_source_id   := NULL;
        END;

        OPEN l_cursor FOR
              SELECT ooha.cust_po_number cust_po_number,
                     ooha.attribute5 brand,
                     TO_CHAR (ooha.ordered_date,
                              'YYYYMMDD HH24:MI:SS') order_date,
                     oola.flow_status_code line_status,
                     oola.inventory_item_id product_id,
                     oola.unit_list_price unit_list_price,
                     oola.unit_selling_price unit_selling_price,
                     oola.ordered_item product,
                     cat.product_desc,
                     cat.product_division,
                     cat.product_color_desc,
                     cat.product_style_number,
                     cat.product_color_code,
                     cat.product_size,
                     oola.ordered_quantity quantity,
                     CASE
                         WHEN (oola.line_category_code = 'RETURN')
                         THEN
                             ((oola.unit_selling_price * -1) * oola.ordered_quantity)
                         ELSE
                             (oola.unit_selling_price * oola.ordered_quantity)
                     END total_amount,
                     ROUND (
                         CASE
                             WHEN (oola.attribute2 NOT LIKE 'GCARD%' AND oola.attribute2 NOT LIKE 'ECARD%')
                             THEN
                                   (oola.unit_list_price * oola.ordered_quantity)
                                 - (oola.unit_selling_price * oola.ordered_quantity)
                             ELSE
                                 0
                         END,
                         2) discount_amount,
                     oola.tax_value tax_amount
                FROM hz_parties hp,
                     hz_cust_accounts hca,
                     oe_order_headers_all ooha,
                     oe_order_lines_all oola,
                     (SELECT msib.inventory_item_id, msib.organization_id, msib.description product_desc,
                             mcb.segment4 product_division, mcb.segment8 product_color_desc, mcb.attribute7 product_style_number,
                             mcb.attribute8 product_color_code, msib.attribute27 product_size
                        FROM mtl_system_items_b msib, mtl_item_categories mic, mtl_categories_b mcb
                       WHERE     1 = 1
                             AND msib.inventory_item_id = mic.inventory_item_id
                             AND msib.organization_id = mic.organization_id
                             AND mic.category_id = mcb.category_id
                             AND mic.category_set_id = ln_category_set_id) cat
               WHERE     1 = 1
                     AND hp.party_id = hca.party_id
                     AND hca.cust_account_id = ooha.sold_to_org_id
                     AND oola.header_id = ooha.header_id
                     AND oola.inventory_item_id = cat.inventory_item_id
                     AND oola.ship_from_org_id = cat.organization_id
                     AND ooha.order_source_id = ln_order_source_id
                     AND UPPER (hp.email_address) = p_email_address
            ORDER BY ooha.ordered_date DESC, oola.line_number ASC;

        apex_json.open_object;
        apex_json.write ('OrderDetails', l_cursor);
        apex_json.close_object;
        msg ('End of APEX', 'Successfully created JSON Object');
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('MAIN Exception', SUBSTR (SQLERRM, 1, 300));
    END get_order_dtls;
END xxd_ont_crest_api_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_CREST_API_PKG TO XXORDS
/
