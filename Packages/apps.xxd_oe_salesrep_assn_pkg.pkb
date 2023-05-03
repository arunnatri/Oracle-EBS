--
-- XXD_OE_SALESREP_ASSN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OE_SALESREP_ASSN_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : BT Tech Team
    -- Creation Date           : 27-NOV-2014
    -- Program Name            : XXD_OE_SALESREP_ASSN_PKG.pkb
    -- Description             : Called from Attributing Defaulting to assign sales rep for orders
    -- Language                : PL/SQL
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 27-NOV-2014        1.0         BT Tech Team    Initial development.
    -- 29-NOV-2016        1.1         Mithun Mathew   Addition of Style and Color to salesrep matrix (CCR0005785).
    -- 05-JUL-2017    1.2    Infosys    Modified for Salesrep defaulting logic change based on Line Level SHIP TO. (CCR0006477).

    gc_multi_salesrep     VARCHAR2 (100);
    gc_no_salesrep        VARCHAR2 (100);
    gc_hold_name          VARCHAR2 (100);
    gc_hold_profile       VARCHAR2 (100);
    gc_hold_profile_val   VARCHAR2 (100);

    PROCEDURE ASSIGN_DEFAULTS
    IS
        CURSOR get_salesrep_defaults_c IS
            SELECT DISTINCT attribute1, attribute2, attribute3,
                            attribute4
              FROM fnd_lookup_values
             WHERE lookup_type = 'XXDO_SALESREP_DEFAULTS';


        CURSOR get_proifle_val_c IS
            SELECT fpov.PROFILE_OPTION_VALUE
              FROM fnd_profile_options fpo, fnd_profile_option_values fpov
             WHERE     profile_option_name =
                       'XXDO_SALESREP_MATRIX_EXCLUDE_HOLD'
                   AND fpov.profile_option_id = fpo.profile_option_id
                   AND level_value = FND_PROFILE.VALUE ('ORG_ID');

        lc_profile_val   VARCHAR2 (1);
    BEGIN
        OPEN get_salesrep_defaults_c;

        FETCH get_salesrep_defaults_c INTO gc_hold_name, gc_hold_profile, gc_multi_salesrep, gc_no_salesrep;

        CLOSE get_salesrep_defaults_c;

        OPEN get_proifle_val_c;

        FETCH get_proifle_val_c INTO lc_profile_val;

        CLOSE get_proifle_val_c;

        gc_hold_profile_val   := NVL (lc_profile_val, 'N');
    END ASSIGN_DEFAULTS;

    PROCEDURE ASSIGN_SALESREP (p_retcode                OUT NUMBER,
                               p_errbuff                OUT VARCHAR2,
                               p_order_number        IN     NUMBER,
                               p_request_date_low    IN     VARCHAR2,
                               p_request_date_high   IN     VARCHAR2)
    IS
        CURSOR get_order_det_c IS
            SELECT oel.inventory_item_id, oel.org_id, oel.sold_to_org_id,
                   oel.ship_to_org_id, oel.invoice_to_org_id, oel.ship_from_org_id,
                   oel.header_id, oel.line_id, oel.reference_header_id,
                   oel.reference_line_id, oeh.order_category_code
              FROM oe_order_headers_all oeh, oe_order_lines_all oel
             WHERE     oel.header_id = oeh.header_id
                   AND oeh.header_id = NVL (p_order_number, oeh.header_id)
                   AND TRUNC (oeh.ordered_date) BETWEEN NVL (
                                                            FND_DATE.CANONICAL_TO_DATE (
                                                                p_request_date_low),
                                                            TRUNC (
                                                                oeh.ordered_date))
                                                    AND NVL (
                                                            FND_DATE.CANONICAL_TO_DATE (
                                                                p_request_date_high),
                                                            TRUNC (
                                                                oeh.ordered_date))
                   AND oeh.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM ra_customer_trx_all
                             WHERE interface_header_attribute1 =
                                   oeh.order_number);

        CURSOR get_order_header_det_c IS
            SELECT org_id,
                   header_id,
                   (SELECT DISTINCT reference_header_id
                      FROM oe_order_lines_all
                     WHERE header_id = oeh.header_id) ref_header_id,
                   oeh.order_category_code
              FROM oe_order_headers_all oeh
             WHERE     header_id = NVL (p_order_number, header_id)
                   AND TRUNC (oeh.ordered_date) BETWEEN NVL (
                                                            FND_DATE.CANONICAL_TO_DATE (
                                                                p_request_date_low),
                                                            TRUNC (
                                                                oeh.ordered_date))
                                                    AND NVL (
                                                            FND_DATE.CANONICAL_TO_DATE (
                                                                p_request_date_high),
                                                            TRUNC (
                                                                oeh.ordered_date))
                   AND oeh.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM ra_customer_trx_all
                             WHERE interface_header_attribute1 =
                                   oeh.order_number);

        CURSOR get_product_det_c (p_inv_item_id       IN NUMBER,
                                  p_organization_id   IN NUMBER)
        IS
            SELECT brand, division, department,
                   master_class, sub_class, style_number,         --CCR0005785
                   color_code                                     --CCR0005785
              FROM xxd_common_items_v
             WHERE     organization_id = p_organization_id
                   AND inventory_item_id = p_inv_item_id;

        CURSOR get_nosales_rep_det (p_org_id IN NUMBER)
        IS
            SELECT salesrep_id
              FROM jtf_rs_salesreps
             WHERE name = gc_no_salesrep AND org_id = p_org_id;

        CURSOR get_ret_salesrep (p_ref_header_id   IN NUMBER,
                                 p_ref_line_id     IN NUMBER)
        IS
            SELECT salesrep_id
              FROM oe_order_lines_all
             WHERE header_id = p_ref_header_id AND line_id = p_ref_line_id;

        CURSOR get_ret_hsalesrep (p_ref_header_id IN NUMBER)
        IS
            SELECT salesrep_id
              FROM oe_order_headers_all
             WHERE header_id = p_ref_header_id;

        CURSOR get_salesrep_name_c (p_salesrep_id IN NUMBER)
        IS
            SELECT name
              FROM jtf_rs_salesreps
             WHERE salesrep_id = p_salesrep_id;

        lcu_product_det      get_product_det_c%ROWTYPE;
        ln_salesrep_id       NUMBER := NULL;
        ln_user_id           NUMBER := FND_GLOBAL.USER_ID;
        lc_salesrep_name     VARCHAR2 (200);

        TYPE t_order_det_rec IS TABLE OF get_order_det_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        lcu_order_det_rec    t_order_det_rec;

        TYPE t_header_det_rec IS TABLE OF get_order_header_det_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        lcu_header_det_rec   t_header_det_rec;
    BEGIN
        lcu_header_det_rec.DELETE;
        lcu_header_det_rec.DELETE;

        ASSIGN_DEFAULTS;

        OPEN get_order_det_c;

        FETCH get_order_det_c BULK COLLECT INTO lcu_order_det_rec;

        CLOSE get_order_det_c;


        FOR i IN 1 .. lcu_order_det_rec.COUNT
        LOOP
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Inside Loop ' || lcu_order_det_rec.COUNT);

            ln_salesrep_id   := NULL;

            IF     lcu_order_det_rec (i).reference_header_id IS NOT NULL
               AND lcu_order_det_rec (i).reference_line_id IS NOT NULL
               AND lcu_order_det_rec (i).order_category_code = 'RETURN'
            THEN
                OPEN get_ret_salesrep (
                    lcu_order_det_rec (i).reference_header_id,
                    lcu_order_det_rec (i).reference_line_id);

                FETCH get_ret_salesrep INTO ln_salesrep_id;

                CLOSE get_ret_salesrep;
            ELSE
                IF lcu_order_det_rec (i).inventory_item_id IS NOT NULL
                THEN
                    OPEN get_product_det_c (
                        lcu_order_det_rec (i).inventory_item_id,
                        lcu_order_det_rec (i).ship_from_org_id);

                    FETCH get_product_det_c INTO lcu_product_det;

                    CLOSE get_product_det_c;

                    IF     lcu_order_det_rec (i).org_id IS NOT NULL
                       AND lcu_order_det_rec (i).invoice_to_org_id
                               IS NOT NULL
                       AND lcu_order_det_rec (i).sold_to_org_id IS NOT NULL
                       AND lcu_product_det.brand IS NOT NULL
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Inside Loop  invoice_to_org_id'
                            || lcu_order_det_rec.COUNT);
                        ln_salesrep_id   :=
                            XXD_OE_SALESREP_ASSN_PKG.GET_SALES_REP (
                                lcu_order_det_rec (i).org_id,
                                lcu_order_det_rec (i).sold_to_org_id,
                                lcu_order_det_rec (i).invoice_to_org_id,
                                lcu_product_det.brand,
                                lcu_product_det.division,
                                lcu_product_det.department,
                                lcu_product_det.master_class,
                                lcu_product_det.sub_class,
                                lcu_product_det.style_number      --CCR0005785
                                                            ,
                                lcu_product_det.color_code        --CCR0005785
                                                          );
                    END IF;

                    IF     lcu_order_det_rec (i).org_id IS NOT NULL
                       AND lcu_order_det_rec (i).ship_to_org_id IS NOT NULL
                       AND lcu_order_det_rec (i).sold_to_org_id IS NOT NULL
                       AND lcu_product_det.brand IS NOT NULL
                       AND ln_salesrep_id IS NOT NULL
                    THEN
                        ln_salesrep_id   :=
                            XXD_OE_SALESREP_ASSN_PKG.GET_SALES_REP (
                                lcu_order_det_rec (i).org_id,
                                lcu_order_det_rec (i).sold_to_org_id,
                                lcu_order_det_rec (i).ship_to_org_id,
                                lcu_product_det.brand,
                                lcu_product_det.division,
                                lcu_product_det.department,
                                lcu_product_det.master_class,
                                lcu_product_det.sub_class,
                                lcu_product_det.style_number      --CCR0005785
                                                            ,
                                lcu_product_det.color_code        --CCR0005785
                                                          );
                    END IF;

                    IF ln_salesrep_id IS NULL
                    THEN
                        OPEN get_nosales_rep_det (
                            lcu_order_det_rec (i).org_id);

                        FETCH get_nosales_rep_det INTO ln_salesrep_id;

                        CLOSE get_nosales_rep_det;

                        APPLY_HOLD (lcu_order_det_rec (i).header_id,
                                    lcu_order_det_rec (i).org_id);
                    END IF;
                ELSE
                    OPEN get_nosales_rep_det (lcu_order_det_rec (i).org_id);

                    FETCH get_nosales_rep_det INTO ln_salesrep_id;

                    CLOSE get_nosales_rep_det;

                    APPLY_HOLD (lcu_order_det_rec (i).header_id,
                                lcu_order_det_rec (i).org_id);
                END IF;
            END IF;

            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Sales Rep not Found ' || ln_salesrep_id);

            IF ln_salesrep_id IS NOT NULL
            THEN
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'Sales Rep Found ' || ln_salesrep_id);

                OPEN get_salesrep_name_c (ln_salesrep_id);

                FETCH get_salesrep_name_c INTO lc_salesrep_name;

                CLOSE get_salesrep_name_c;

                XXD_OE_SALESREP_ASSN_PKG.UPDATE_SALESREP (
                    p_level       => 'LINE',
                    p_header_id   => NULL,
                    p_line_id     => lcu_order_det_rec (i).line_id,
                    p_salesrep    => lc_salesrep_name);
            ELSE
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'No Sales Rep Found ' || SQLERRM);
            END IF;
        END LOOP;

        OPEN get_order_header_det_c;

        FETCH get_order_header_det_c BULK COLLECT INTO lcu_header_det_rec;

        CLOSE get_order_header_det_c;

        FOR j IN 1 .. lcu_header_det_rec.COUNT
        LOOP
            ln_salesrep_id   := NULL;

            IF     lcu_header_det_rec (j).ref_header_id IS NOT NULL
               AND lcu_header_det_rec (j).order_category_code = 'RETURN'
            THEN
                OPEN get_ret_hsalesrep (lcu_header_det_rec (j).ref_header_id);

                FETCH get_ret_hsalesrep INTO ln_salesrep_id;

                CLOSE get_ret_hsalesrep;

                OPEN get_salesrep_name_c (ln_salesrep_id);

                FETCH get_salesrep_name_c INTO lc_salesrep_name;

                CLOSE get_salesrep_name_c;

                IF ln_salesrep_id IS NOT NULL
                THEN
                    XXD_OE_SALESREP_ASSN_PKG.UPDATE_SALESREP (
                        p_level       => 'HEADER',
                        p_header_id   => lcu_header_det_rec (j).header_id,
                        p_line_id     => NULL,
                        p_salesrep    => lc_salesrep_name);
                END IF;
            ELSE
                ASSIGN_SALESREP_HEADER (
                    p_header_id     => lcu_header_det_rec (j).header_id,
                    p_org_id        => lcu_header_det_rec (j).org_id,
                    p_salesrep_id   => NULL);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Exception at procedure ASSIGN_SALESREP ' || SQLERRM);
    END ASSIGN_SALESREP;

    FUNCTION RET_HSALESREP (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN NUMBER
    IS
        /*   CURSOR get_brand_c (p_cust_account_id IN NUMBER) IS
           SELECT hca.attribute1
             FROM hz_cust_accounts_all hca,
                  fnd_lookup_values flv
            WHERE hca.cust_account_id     = p_cust_account_id
              AND flv.lookup_type         = 'CUSTOMER CLASS'
              AND flv.language            = USERENV('LANG')
              AND hca.customer_class_code = flv.lookup_code
              AND flv.meaning IN ('Wholesale','Distributor','Consumer Direct');*/


        ln_ret     NUMBER;
        ln_brand   VARCHAR2 (50);
    BEGIN
        IF ONT_HEADER_DEF_HDLR.g_record.sold_to_org_id IS NULL
        THEN
            RETURN NULL;
        END IF;

        ASSIGN_DEFAULTS;

        IF ONT_HEADER_DEF_HDLR.g_record.sold_to_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT hca.attribute1
                  INTO ln_brand
                  FROM hz_cust_accounts_all hca, fnd_lookup_values flv
                 WHERE     hca.cust_account_id =
                           ONT_HEADER_DEF_HDLR.g_record.sold_to_org_id
                       AND flv.lookup_type = 'CUSTOMER CLASS'
                       AND flv.language = USERENV ('LANG')
                       AND hca.customer_class_code = flv.lookup_code
                       AND flv.meaning IN ('Wholesale', 'Dealer Employee', 'Consumer Direct',
                                           'House'); --Added House in condition on 07-jun-2016 as per incident INC0297947
            --AND flv.meaning IN ('Wholesale','Distributor','Consumer Direct'); Commented as per Inputs from Functional 09-jun-2015

            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_brand   := NULL;
                    RETURN NULL;
            END;
        END IF;


        SELECT salesrep_id
          INTO ln_ret
          FROM apps.hz_cust_site_uses_all hcsua, do_custom.do_rep_cust_assignment drca
         WHERE     hcsua.site_use_id = drca.site_use_id
               AND drca.customer_id =
                   NVL (ONT_HEADER_DEF_HDLR.g_record.sold_to_org_id, -1)
               AND drca.site_use_id IN
                       (NVL (ONT_HEADER_DEF_HDLR.g_record.invoice_to_org_id, -1), NVL (ONT_HEADER_DEF_HDLR.g_record.ship_to_org_id, -1))
               AND drca.brand = NVL (ln_brand, '--none--')
               AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (drca.start_date),
                                                TRUNC (SYSDATE))
                                       AND NVL (TRUNC (drca.end_date),
                                                TRUNC (SYSDATE))
               AND drca.org_id = apps.fnd_global.org_id;

        RETURN ln_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            SELECT salesrep_id
              INTO ln_ret
              FROM jtf_rs_salesreps
             WHERE     name = gc_no_salesrep
                   AND org_id = ONT_HEADER_DEF_HDLR.G_RECORD.ORG_ID;

            RETURN ln_ret;
        WHEN TOO_MANY_ROWS
        THEN
            SELECT jrs.salesrep_id
              INTO ln_ret
              FROM jtf_rs_resource_extns_vl jrr, jtf_rs_salesreps jrs
             WHERE     jrr.resource_id = jrs.resource_id
                   AND resource_name = gc_multi_salesrep
                   AND org_id = ONT_HEADER_DEF_HDLR.G_RECORD.ORG_ID;

            RETURN ln_ret;
        WHEN OTHERS
        THEN
            SELECT salesrep_id
              INTO ln_ret
              FROM jtf_rs_salesreps
             WHERE     name = gc_no_salesrep
                   AND org_id = ONT_HEADER_DEF_HDLR.G_RECORD.ORG_ID;

            RETURN ln_ret;
    END RET_HSALESREP;

    FUNCTION RET_LSALESREP (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN NUMBER
    IS
        CURSOR get_product_det_c (p_inv_item_id IN NUMBER)
        IS
            SELECT DISTINCT brand, division, department,
                            master_class, sub_class, style_number, --CCR0005785
                            color_code                            --CCR0005785
              FROM xxd_common_items_v
             WHERE inventory_item_id = p_inv_item_id;

        CURSOR get_nosales_rep_det (p_org_id IN NUMBER)
        IS
            SELECT salesrep_id
              FROM jtf_rs_salesreps
             WHERE name = gc_no_salesrep AND org_id = p_org_id;

        CURSOR get_order_excl_flag_c (p_order_type_id IN NUMBER)
        IS
            SELECT NVL (attribute15, 'N')
              FROM oe_transaction_types_all
             WHERE transaction_type_id = p_order_type_id;

        lcu_product_det      get_product_det_c%ROWTYPE;
        ln_salesrep_id       NUMBER := NULL;
        l_header_rec         oe_ak_order_headers_v%ROWTYPE;
        l_line_rec           oe_ak_order_lines_v%ROWTYPE;
        lc_order_excl_flag   VARCHAR2 (10);
        ln_no_salesrep_id    NUMBER;
        ln_brand             VARCHAR2 (50);
    BEGIN
        l_line_rec          := NULL;
        l_header_rec        := NULL;
        ln_salesrep_id      := NULL;
        ln_no_salesrep_id   := NULL;
        lcu_product_det     := NULL;
        l_line_rec          := ont_line_def_hdlr.g_record;
        l_header_rec        := ont_header_def_hdlr.g_record;

        IF l_line_rec.sold_to_org_id IS NULL
        THEN
            RETURN NULL;
        END IF;

        ASSIGN_DEFAULTS;

        BEGIN
            -- Added to restrict at line level also depending on customer level
            SELECT hca.attribute1
              INTO ln_brand
              FROM hz_cust_accounts_all hca, fnd_lookup_values flv
             WHERE     hca.cust_account_id = l_line_rec.sold_to_org_id
                   AND flv.lookup_type = 'CUSTOMER CLASS'
                   AND flv.language = USERENV ('LANG')
                   AND hca.customer_class_code = flv.lookup_code
                   AND flv.meaning IN ('Wholesale', 'Dealer Employee', 'Consumer Direct',
                                       'House'); --Added House in condition on 07-jun-2016 as per incident INC0297947
        --AND flv.meaning IN ('Wholesale','Distributor','Consumer Direct'); Commented as per Inputs from Functional 09-jun-2015

        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
        END;


        IF l_header_rec.order_type_id IS NOT NULL
        THEN
            OPEN get_order_excl_flag_c (l_header_rec.order_type_id);

            FETCH get_order_excl_flag_c INTO lc_order_excl_flag;

            CLOSE get_order_excl_flag_c;
        END IF;

        OPEN get_nosales_rep_det (l_header_rec.org_id);

        FETCH get_nosales_rep_det INTO ln_no_salesrep_id;

        CLOSE get_nosales_rep_det;

        IF UPPER (lc_order_excl_flag) = 'Y'
        THEN
            ln_salesrep_id   := NULL;

            RETURN ln_salesrep_id;
        ELSE
            IF l_line_rec.inventory_item_id IS NOT NULL
            THEN
                OPEN get_product_det_c (l_line_rec.inventory_item_id);

                FETCH get_product_det_c INTO lcu_product_det;

                CLOSE get_product_det_c;

                IF     l_header_rec.org_id IS NOT NULL
                   AND l_header_rec.sold_to_org_id IS NOT NULL
                   AND lcu_product_det.brand IS NOT NULL
                   AND l_header_rec.invoice_to_org_id IS NOT NULL
                THEN
                    ln_salesrep_id   :=
                        XXD_OE_SALESREP_ASSN_PKG.GET_SALES_REP (
                            l_header_rec.org_id,
                            l_header_rec.sold_to_org_id,
                            l_header_rec.invoice_to_org_id,
                            lcu_product_det.brand,
                            lcu_product_det.division,
                            lcu_product_det.department,
                            lcu_product_det.master_class,
                            lcu_product_det.sub_class,
                            lcu_product_det.style_number          --CCR0005785
                                                        ,
                            lcu_product_det.color_code            --CCR0005785
                                                      );
                END IF;


                IF     l_header_rec.org_id IS NOT NULL
                   AND l_header_rec.sold_to_org_id IS NOT NULL
                   --  AND l_header_rec.ship_to_org_id    IS NOT NULL  -- Commented by Infosys for 1.2.
                   AND (l_header_rec.ship_to_org_id IS NOT NULL OR l_line_rec.ship_to_org_id IS NOT NULL) -- Modified by Infosys for 1.2.
                   AND lcu_product_det.brand IS NOT NULL
                   AND ln_salesrep_id IS NULL
                THEN
                    ln_salesrep_id   :=
                        XXD_OE_SALESREP_ASSN_PKG.GET_SALES_REP (
                            l_header_rec.org_id,
                            l_header_rec.sold_to_org_id--   , l_header_rec.ship_to_org_id   -- Commented by Infosys for 1.2.
                                                       ,
                            NVL (l_line_rec.ship_to_org_id,
                                 l_header_rec.ship_to_org_id) -- Modified by Infosys for 1.2.
                                                             ,
                            lcu_product_det.brand,
                            lcu_product_det.division,
                            lcu_product_det.department,
                            lcu_product_det.master_class,
                            lcu_product_det.sub_class,
                            lcu_product_det.style_number          --CCR0005785
                                                        ,
                            lcu_product_det.color_code            --CCR0005785
                                                      );
                END IF;

                IF ln_salesrep_id IS NULL
                THEN
                    /*    OPEN get_nosales_rep_det(l_header_rec.org_id);
                        FETCH get_nosales_rep_det INTO ln_salesrep_id;
                        CLOSE get_nosales_rep_det;*/

                    COMMIT;
                    APPLY_HOLD (l_line_rec.header_id, l_line_rec.org_id);
                    RETURN ln_no_salesrep_id;
                END IF;
            END IF;

            IF ln_salesrep_id IS NOT NULL
            THEN
                /*ASSIGN_SALESREP_HEADER(l_header_rec.header_id
                                     , l_header_rec.org_id
                                     , ln_salesrep_id);*/
                RETURN ln_salesrep_id;
            ELSE
                RETURN NULL;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END RET_LSALESREP;

    PROCEDURE APPLY_HOLD (pv_header_id IN NUMBER, pv_org_id IN NUMBER)
    IS
        lc_return_status      VARCHAR2 (30);
        lc_msg_data           VARCHAR2 (4000);
        ln_msg_count          NUMBER;
        lc_hold_source_rec    OE_HOLDS_PVT.HOLD_SOURCE_REC_TYPE;
        ln_hold_id            NUMBER := NULL;
        lc_hold_entity_code   VARCHAR2 (10) DEFAULT 'O';
        lc_context            VARCHAR2 (2);
        ln_hold_count         NUMBER;

        CURSOR get_hold_id_c IS
            SELECT hold_id
              FROM apps.oe_hold_definitions
             WHERE NAME = gc_hold_name;

        CURSOR hold_exist_c IS
            SELECT COUNT (*)
              FROM oe_order_holds_all
             WHERE     header_id = pv_header_id
                   AND org_id = pv_org_id
                   AND released_flag = 'N';

        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        APPS.FND_GLOBAL.APPS_INITIALIZE (APPS.FND_GLOBAL.USER_ID,
                                         APPS.FND_GLOBAL.RESP_ID,
                                         APPS.FND_GLOBAL.RESP_APPL_ID);

        mo_global.set_policy_context ('S', pv_org_id);

        OPEN get_hold_id_c;

        FETCH get_hold_id_c INTO ln_hold_id;

        CLOSE get_hold_id_c;

        OPEN hold_exist_c;

        FETCH hold_exist_c INTO ln_hold_count;

        CLOSE hold_exist_c;

        IF gc_hold_profile_val = 'N' AND NVL (ln_hold_count, 0) = 0
        THEN
            IF pv_header_id IS NOT NULL
            THEN
                lc_hold_source_rec                    := OE_HOLDS_PVT.G_MISS_HOLD_SOURCE_REC;
                lc_hold_source_rec.hold_id            := ln_hold_id;
                lc_hold_source_rec.hold_entity_code   := lc_hold_entity_code;
                lc_hold_source_rec.hold_entity_id     := pv_header_id;
                lc_hold_source_rec.header_id          := pv_header_id;
                lc_return_status                      := NULL;
                lc_msg_data                           := NULL;
                ln_msg_count                          := NULL;

                ----------------------------
                -- Calling the Hold API
                ----------------------------
                APPS.OE_HOLDS_PUB.APPLY_HOLDS (p_api_version => 1.0, p_init_msg_list => FND_API.G_TRUE, p_commit => FND_API.G_FALSE, p_hold_source_rec => lc_hold_source_rec, x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                               , x_msg_data => lc_msg_data);

                IF lc_return_status = FND_API.G_RET_STS_SUCCESS
                THEN
                    FND_FILE.PUT_LINE (FND_FILE.LOG, 'success:');
                    COMMIT;
                ELSIF lc_return_status IS NULL
                THEN
                    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Status is null');
                ELSE
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'failure:'
                        || lc_return_status
                        || lc_msg_data
                        || ln_msg_count);

                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lc_msg_data   :=
                            oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                        FND_FILE.PUT_LINE (FND_FILE.LOG,
                                           i || ') ' || lc_msg_data);
                    END LOOP;
                END IF;
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Error occured while getting header_id'
                    || '  '
                    || SQLCODE);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error : ' || SQLCODE || '---' || SQLERRM);
    END APPLY_HOLD;

    PROCEDURE ASSIGN_SALESREP_HEADER (p_header_id IN NUMBER, p_org_id IN NUMBER, p_salesrep_id IN NUMBER)
    IS
        CURSOR get_sales_rep_count IS
            SELECT COUNT (DISTINCT salesrep_id)
              FROM (SELECT salesrep_id
                      FROM oe_order_lines_all
                     WHERE header_id = p_header_id
                    UNION
                    SELECT p_salesrep_id salesrep_id
                      FROM DUAL
                     WHERE p_salesrep_id = NVL (p_salesrep_id, -99));

        CURSOR get_multi_rep_det IS
            SELECT jrs.salesrep_id
              FROM jtf_rs_resource_extns_vl jrr, jtf_rs_salesreps jrs
             WHERE     jrr.resource_id = jrs.resource_id
                   AND resource_name = gc_multi_salesrep
                   AND org_id = p_org_id;

        CURSOR get_salesrep IS
            SELECT DISTINCT salesrep_id
              FROM oe_order_lines_all
             WHERE header_id = p_header_id;

        CURSOR get_salesrep_name_c (p_salesrep_id IN NUMBER)
        IS
            SELECT resource_name
              FROM jtf_rs_resource_extns_vl jrr, jtf_rs_salesreps jrs
             WHERE     jrr.resource_id = jrs.resource_id
                   AND salesrep_id = p_salesrep_id;

        ln_sales_rep_id     NUMBER;
        ln_salesrep_count   NUMBER;
        ln_user_id          NUMBER := FND_GLOBAL.USER_ID;
        l_val               VARCHAR2 (1000);
        lc_salesrep_name    VARCHAR2 (200);
    BEGIN
        ln_sales_rep_id     := NULL;
        ln_salesrep_count   := NULL;

        OPEN get_sales_rep_count;

        FETCH get_sales_rep_count INTO ln_salesrep_count;

        CLOSE get_sales_rep_count;

        IF ln_salesrep_count = 1 AND p_salesrep_id IS NOT NULL
        THEN
            ln_sales_rep_id   := p_salesrep_id;
        ELSIF ln_salesrep_count = 1 AND p_salesrep_id IS NULL
        THEN
            OPEN get_salesrep;

            FETCH get_salesrep INTO ln_sales_rep_id;

            CLOSE get_salesrep;
        ELSE
            OPEN get_multi_rep_det;

            FETCH get_multi_rep_det INTO ln_sales_rep_id;

            CLOSE get_multi_rep_det;
        END IF;


        IF ln_sales_rep_id IS NOT NULL
        THEN
            OPEN get_salesrep_name_c (ln_sales_rep_id);

            FETCH get_salesrep_name_c INTO lc_salesrep_name;

            CLOSE get_salesrep_name_c;

            BEGIN
                XXD_OE_SALESREP_ASSN_PKG.UPDATE_SALESREP (
                    p_level       => 'HEADER',
                    p_header_id   => p_header_id,
                    p_line_id     => NULL,
                    p_salesrep    => lc_salesrep_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_val   := SUBSTR (SQLERRM, 1, 99);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'EXCEPTION AT ASSIGN_SALESREP_HEADER ' || SQLERRM);
    END ASSIGN_SALESREP_HEADER;

    PROCEDURE UPDATE_SALESREP (p_level IN VARCHAR2, p_header_id IN NUMBER, p_line_id IN NUMBER
                               , p_salesrep IN VARCHAR2)
    IS
        l_hdr_rec         oe_order_pub.header_val_rec_type;
        l_line_rec        oe_order_pub.line_val_rec_type;
        x_return_stat     VARCHAR2 (2000);
        x_msg_cnt         NUMBER;
        x_msg_dat         VARCHAR2 (2000);
        l_error_message   VARCHAR2 (30000);

        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        -- Setting the Environment
        MO_GLOBAL.INIT ('ONT');
        MO_GLOBAL.SET_POLICY_CONTEXT ('S', FND_GLOBAL.ORG_ID);
        fnd_global.apps_initialize (user_id        => FND_GLOBAL.USER_ID,
                                    resp_id        => FND_GLOBAL.RESP_ID,
                                    resp_appl_id   => FND_GLOBAL.RESP_APPL_ID);

        IF p_level = 'HEADER'
        THEN
            l_hdr_rec.salesrep   := p_salesrep;

            oe_order_pub.update_header (p_header_id        => p_header_id,
                                        p_header_val_rec   => l_hdr_rec,
                                        x_return_status    => x_return_stat,
                                        x_msg_count        => x_msg_cnt,
                                        x_msg_data         => x_msg_dat);

            IF x_return_stat = 'S'
            THEN
                COMMIT;
            ELSE
                FOR i IN 1 .. x_msg_cnt
                LOOP
                    Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_error_message
                                    , p_msg_index_out => x_msg_cnt);
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Unable to update Salesrep for header_id '
                        || p_header_id
                        || ' Because of'
                        || l_error_message);
                END LOOP;
            END IF;
        ELSIF p_level = 'LINE'
        THEN
            l_line_rec.salesrep   := p_salesrep;

            oe_order_pub.update_line (p_line_id         => p_line_id,
                                      p_line_val_rec    => l_line_rec,
                                      x_return_status   => x_return_stat,
                                      x_msg_count       => x_msg_cnt,
                                      x_msg_data        => x_msg_dat);

            IF x_return_stat = 'S'
            THEN
                COMMIT;
            ELSE
                FOR i IN 1 .. x_msg_cnt
                LOOP
                    Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_error_message
                                    , p_msg_index_out => x_msg_cnt);
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Unable to update Salesrep for line_id '
                        || p_line_id
                        || ' Because of'
                        || l_error_message);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Exception at UPDATE_SALESREP ' || SQLERRM);
    END UPDATE_SALESREP;

    FUNCTION get_sales_rep (p_org_id IN NUMBER, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER, p_brand IN VARCHAR2, p_division IN VARCHAR2, p_department IN VARCHAR2, p_class IN VARCHAR2, p_sub_class IN VARCHAR2, p_style_number IN VARCHAR2 --CCR0005785
                            , p_color_code IN VARCHAR2            --CCR0005785
                                                      )
        RETURN NUMBER
    IS
        CURSOR get_sales_rep_det (p_org_id1 IN NUMBER, p_cust_account_id1 IN NUMBER, p_site_use_id1 IN NUMBER, p_brand1 IN VARCHAR2, p_division1 IN VARCHAR2, p_department1 IN VARCHAR2, p_class1 IN VARCHAR2, p_sub_class1 IN VARCHAR2, p_style_number1 IN VARCHAR2 --CCR0005785
                                  , p_color_code1 IN VARCHAR2     --CCR0005785
                                                             )
        IS
            SELECT salesrep_id
              FROM do_custom.do_rep_cust_assignment
             WHERE     org_id = p_org_id1
                   AND customer_id = p_cust_account_id1
                   AND site_use_id = p_site_use_id1
                   AND NVL (brand, 'X') = NVL (p_brand1, 'X')
                   AND NVL (division, 'X') = NVL (p_division1, 'X')
                   AND NVL (department, 'X') = NVL (p_department1, 'X')
                   AND NVL (class, 'X') = NVL (p_class1, 'X')
                   AND NVL (sub_class, 'X') = NVL (p_sub_class1, 'X')
                   AND NVL (style_number, 'X') = NVL (p_style_number1, 'X') --CCR0005785
                   AND NVL (color_code, 'X') = NVL (p_color_code1, 'X') --CCR0005785
                   AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (start_date),
                                                    TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date),
                                                    TRUNC (SYSDATE));

        ln_salesrep_id   NUMBER;
    BEGIN
        IF     p_org_id IS NOT NULL
           AND p_cust_account_id IS NOT NULL
           AND p_site_use_id IS NOT NULL
           AND p_brand IS NOT NULL
        THEN
            OPEN get_sales_rep_det (p_org_id, p_cust_account_id, p_site_use_id, p_brand, p_division, p_department, p_class, p_sub_class, p_style_number --CCR0005785
                                    , p_color_code                --CCR0005785
                                                  );

            FETCH get_sales_rep_det INTO ln_salesrep_id;

            CLOSE get_sales_rep_det;


            /* Start of Addition for CCR0005785*/
            IF ln_salesrep_id IS NULL
            THEN
                OPEN get_sales_rep_det (p_org_id, p_cust_account_id, p_site_use_id, p_brand, p_division, p_department, p_class, p_sub_class, p_style_number
                                        , NULL);

                FETCH get_sales_rep_det INTO ln_salesrep_id;

                CLOSE get_sales_rep_det;
            END IF;

            IF ln_salesrep_id IS NULL
            THEN
                OPEN get_sales_rep_det (p_org_id, p_cust_account_id, p_site_use_id, p_brand, p_division, p_department, p_class, p_sub_class, NULL
                                        , NULL);

                FETCH get_sales_rep_det INTO ln_salesrep_id;

                CLOSE get_sales_rep_det;
            END IF;

            /* End of Addition for CCR0005785*/

            IF ln_salesrep_id IS NULL
            THEN
                OPEN get_sales_rep_det (p_org_id, p_cust_account_id, p_site_use_id, p_brand, p_division, p_department, p_class, NULL, NULL --CCR0005785
                                        , NULL                    --CCR0005785
                                              );

                FETCH get_sales_rep_det INTO ln_salesrep_id;

                CLOSE get_sales_rep_det;
            END IF;

            IF ln_salesrep_id IS NULL
            THEN
                OPEN get_sales_rep_det (p_org_id, p_cust_account_id, p_site_use_id, p_brand, p_division, p_department, NULL, NULL, NULL --CCR0005785
                                        , NULL                    --CCR0005785
                                              );

                FETCH get_sales_rep_det INTO ln_salesrep_id;

                CLOSE get_sales_rep_det;
            END IF;

            IF ln_salesrep_id IS NULL
            THEN
                OPEN get_sales_rep_det (p_org_id, p_cust_account_id, p_site_use_id, p_brand, p_division, NULL, NULL, NULL, NULL --CCR0005785
                                        , NULL                    --CCR0005785
                                              );

                FETCH get_sales_rep_det INTO ln_salesrep_id;

                CLOSE get_sales_rep_det;
            END IF;

            IF ln_salesrep_id IS NULL
            THEN
                OPEN get_sales_rep_det (p_org_id, p_cust_account_id, p_site_use_id, p_brand, NULL, NULL, NULL, NULL, NULL --CCR0005785
                                        , NULL                    --CCR0005785
                                              );

                FETCH get_sales_rep_det INTO ln_salesrep_id;

                CLOSE get_sales_rep_det;
            END IF;
        END IF;

        RETURN ln_salesrep_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_sales_rep;
END XXD_OE_SALESREP_ASSN_PKG;
/
