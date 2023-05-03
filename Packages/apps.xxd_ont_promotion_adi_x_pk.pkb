--
-- XXD_ONT_PROMOTION_ADI_X_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_PROMOTION_ADI_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_PROMOTION_ADI_X_PK
    * Design       : This package is used for Promotions WebADI
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 21-Feb-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/

    -- ===============================================================================
    -- This procedure validates and inserts records into the Promotion table
    -- ===============================================================================
    PROCEDURE promotion_upload_prc (p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_promotion_name IN xxd_ont_promotions_t.promotion_name%TYPE, p_operating_unit IN xxd_ont_promotions_t.operating_unit%TYPE, p_brand IN xxd_ont_promotions_t.brand%TYPE, p_currency IN xxd_ont_promotions_t.currency%TYPE, p_customer_number IN xxd_ont_promotions_t.customer_number%TYPE, p_distribution_channel IN xxd_ont_promotions_t.distribution_channel%TYPE, p_ship_method IN xxd_ont_promotions_t.ship_method%TYPE, p_freight_term IN xxd_ont_promotions_t.freight_term%TYPE, p_payment_term IN xxd_ont_promotions_t.payment_term%TYPE, p_header_discount IN xxd_ont_promotions_t.header_discount%TYPE, p_line_discount IN xxd_ont_promotions_t.line_discount%TYPE, p_ordered_date_from IN xxd_ont_promotions_t.ordered_date_from%TYPE, p_ordered_date_to IN xxd_ont_promotions_t.ordered_date_to%TYPE, p_request_date_from IN xxd_ont_promotions_t.request_date_from%TYPE, p_request_date_to IN xxd_ont_promotions_t.request_date_to%TYPE, p_department IN xxd_ont_promotions_t.department%TYPE, p_division IN xxd_ont_promotions_t.division%TYPE, p_class IN xxd_ont_promotions_t.class%TYPE, p_sub_class IN xxd_ont_promotions_t.sub_class%TYPE, p_style_number IN xxd_ont_promotions_t.style_number%TYPE, p_color_code IN xxd_ont_promotions_t.color_code%TYPE, p_number_of_styles IN xxd_ont_promotions_t.number_of_styles%TYPE, p_number_of_colors IN xxd_ont_promotions_t.number_of_colors%TYPE
                                    , p_country_code IN xxd_ont_promotions_t.country_code%TYPE, p_state IN xxd_ont_promotions_t.state%TYPE)
    IS
        CURSOR get_duplicate_records IS
            SELECT COUNT (1)
              FROM xxd_ont_promotions_t
             WHERE     promotion_code = p_promotion_code
                   AND operating_unit = p_operating_unit
                   AND brand = p_brand
                   AND NVL (currency, 'XX') =
                       NVL (p_currency, NVL (currency, 'XX'))
                   AND NVL (customer_number, 'XX') =
                       NVL (p_customer_number, NVL (customer_number, 'XX'))
                   AND NVL (distribution_channel, 'XX') =
                       NVL (p_distribution_channel,
                            NVL (distribution_channel, 'XX'))
                   AND NVL (ship_method, 'XX') =
                       NVL (p_ship_method, NVL (ship_method, 'XX'))
                   AND NVL (freight_term, 'XX') =
                       NVL (p_freight_term, NVL (freight_term, 'XX'))
                   AND NVL (payment_term, 'XX') =
                       NVL (p_payment_term, NVL (payment_term, 'XX'))
                   AND NVL (header_discount, 999) =
                       NVL (p_header_discount, NVL (header_discount, 999))
                   AND NVL (line_discount, 999) =
                       NVL (p_line_discount, NVL (line_discount, 999))
                   AND TRUNC (
                           NVL (ordered_date_from, TO_DATE ('01-JAN-1950'))) =
                       TRUNC (
                           NVL (
                               p_ordered_date_from,
                               NVL (ordered_date_from,
                                    TO_DATE ('01-JAN-1950'))))
                   AND TRUNC (NVL (ordered_date_to, TO_DATE ('01-JAN-1950'))) =
                       TRUNC (
                           NVL (
                               p_ordered_date_to,
                               NVL (ordered_date_to, TO_DATE ('01-JAN-1950'))))
                   AND TRUNC (
                           NVL (request_date_from, TO_DATE ('01-JAN-1950'))) =
                       TRUNC (
                           NVL (
                               p_request_date_from,
                               NVL (request_date_from,
                                    TO_DATE ('01-JAN-1950'))))
                   AND TRUNC (NVL (request_date_to, TO_DATE ('01-JAN-1950'))) =
                       TRUNC (
                           NVL (
                               p_request_date_to,
                               NVL (request_date_to, TO_DATE ('01-JAN-1950'))))
                   AND NVL (department, 'XX') =
                       NVL (p_department, NVL (department, 'XX'))
                   AND NVL (division, 'XX') =
                       NVL (p_division, NVL (division, 'XX'))
                   AND NVL (class, 'XX') = NVL (p_class, NVL (class, 'XX'))
                   AND NVL (sub_class, 'XX') =
                       NVL (p_sub_class, NVL (sub_class, 'XX'))
                   AND NVL (style_number, 'XX') =
                       NVL (p_style_number, NVL (style_number, 'XX'))
                   AND NVL (color_code, 'XX') =
                       NVL (p_color_code, NVL (color_code, 'XX'))
                   AND NVL (number_of_styles, 999) =
                       NVL (p_number_of_styles, NVL (number_of_styles, 999))
                   AND NVL (number_of_colors, 999) =
                       NVL (p_number_of_colors, NVL (number_of_colors, 999))
                   AND NVL (country_code, 'XX') =
                       NVL (p_country_code, NVL (country_code, 'XX'))
                   AND NVL (state, 'XX') = NVL (p_state, NVL (state, 'XX'))
                   AND promotion_code_status = 'A';

        CURSOR get_duplicate_header_records IS
            SELECT COUNT (1)
              FROM xxd_ont_promotions_t
             WHERE     promotion_code = p_promotion_code
                   AND (operating_unit <> p_operating_unit OR brand <> p_brand OR NVL (currency, 'XX') <> NVL (p_currency, NVL (currency, 'XX')) OR NVL (customer_number, 'XX') <> NVL (p_customer_number, NVL (customer_number, 'XX')) OR NVL (distribution_channel, 'XX') <> NVL (p_distribution_channel, NVL (distribution_channel, 'XX')) OR NVL (ship_method, 'XX') <> NVL (p_ship_method, NVL (ship_method, 'XX')) OR NVL (freight_term, 'XX') <> NVL (p_freight_term, NVL (freight_term, 'XX')) OR NVL (payment_term, 'XX') <> NVL (p_payment_term, NVL (payment_term, 'XX')) OR NVL (header_discount, 999) <> NVL (p_header_discount, NVL (header_discount, 999)) OR TRUNC (NVL (ordered_date_from, TO_DATE ('01-JAN-1950'))) <> TRUNC (NVL (p_ordered_date_from, NVL (ordered_date_from, TO_DATE ('01-JAN-1950')))) OR TRUNC (NVL (ordered_date_to, TO_DATE ('01-JAN-1950'))) <> TRUNC (NVL (p_ordered_date_to, NVL (ordered_date_to, TO_DATE ('01-JAN-1950')))) OR TRUNC (NVL (request_date_from, TO_DATE ('01-JAN-1950'))) <> TRUNC (NVL (p_request_date_from, NVL (request_date_from, TO_DATE ('01-JAN-1950')))) OR TRUNC (NVL (request_date_to, TO_DATE ('01-JAN-1950'))) <> TRUNC (NVL (p_request_date_to, NVL (request_date_to, TO_DATE ('01-JAN-1950')))))
                   AND promotion_level = 'HEADER';


        lc_err_message          VARCHAR2 (4000) := NULL;
        lc_ret_message          VARCHAR2 (4000) := NULL;
        ln_exists               NUMBER;
        ln_dummy                NUMBER;
        ln_organization_id      hr_operating_units.organization_id%TYPE;
        ln_term_id              ra_terms.term_id%TYPE;
        lc_customer_name        hz_cust_accounts.account_name%TYPE;
        ln_cust_account_id      hz_cust_accounts.cust_account_id%TYPE;
        lc_ship_method_code     VARCHAR2 (30);
        lc_freight_terms_code   VARCHAR2 (30);
        le_webadi_exception     EXCEPTION;
    BEGIN
        -- Validate Dates
        IF    p_ordered_date_from > p_ordered_date_to
           OR p_request_date_from > p_request_date_to
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'To Date must be greater than the From Date. ';
        END IF;

        -- Validate Substitutions
        IF     p_ship_method IS NULL
           AND p_freight_term IS NULL
           AND p_payment_term IS NULL
           AND p_header_discount IS NULL
           AND p_line_discount IS NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Please specify atleast one application method. ';
        END IF;

        -- Validate Hierarchy with Header Discount
        IF     p_header_discount IS NOT NULL
           AND (p_department IS NOT NULL OR p_division IS NOT NULL OR p_class IS NOT NULL OR p_sub_class IS NOT NULL OR p_style_number IS NOT NULL OR p_color_code IS NOT NULL)
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Header discount cannot be used for Dept/Div/Class/SubClass/Style/Color. ';
        END IF;

        -- Validate Hierarchy with Line Discount
        IF     p_line_discount IS NULL
           AND (p_department IS NOT NULL OR p_division IS NOT NULL OR p_class IS NOT NULL OR p_sub_class IS NOT NULL OR p_style_number IS NOT NULL OR p_color_code IS NOT NULL)
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Dept/Div/Class/SubClass/Style/Color can only be used for Line Discounts. ';
        END IF;

        -- Validate Hierarchy with Line Discount
        IF     p_line_discount IS NOT NULL
           AND (p_department IS NULL AND p_division IS NULL AND p_class IS NULL AND p_sub_class IS NULL AND p_style_number IS NULL AND p_color_code IS NULL)
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Line discount should have atleast one item hierarchy populated Dept/Div/Class/SubClass/Style/Color. ';
        END IF;

        -- Validate Discount
        IF p_header_discount IS NOT NULL AND p_line_discount IS NOT NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Header discount and Line Discount cannot be used on the same record. ';
        END IF;

        -- Validate Operating Unit
        BEGIN
            SELECT organization_id
              INTO ln_organization_id
              FROM hr_operating_units
             WHERE name = p_operating_unit;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_err_message   :=
                    lc_err_message || 'Error Deriving Organization_id. ';
            WHEN OTHERS
            THEN
                lc_err_message   := lc_err_message || SQLERRM;
        END;

        -- Validate Customer Number
        IF p_customer_number IS NOT NULL
        THEN
            BEGIN
                SELECT account_name, cust_account_id
                  INTO lc_customer_name, ln_cust_account_id
                  FROM hz_cust_accounts
                 WHERE     account_number = p_customer_number
                       AND attribute1 = p_brand;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Error Deriving Customer Name. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Ship Method
        IF p_ship_method IS NOT NULL
        THEN
            BEGIN
                SELECT lookup_code
                  INTO lc_ship_method_code
                  FROM oe_ship_methods_v
                 WHERE meaning = p_ship_method;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Error Deriving Ship Method Code. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Freight Term
        IF p_freight_term IS NOT NULL
        THEN
            BEGIN
                SELECT lookup_code
                  INTO lc_freight_terms_code
                  FROM fnd_lookup_values
                 WHERE     meaning = p_freight_term
                       AND lookup_type = 'FREIGHT_TERMS'
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND language = USERENV ('LANG');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Error Deriving Freight Terms Code. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Payment Term
        IF p_payment_term IS NOT NULL
        THEN
            BEGIN
                SELECT term_id
                  INTO ln_term_id
                  FROM ra_terms
                 WHERE name = p_payment_term;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Error Deriving Payment Term id. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Header Discount
        IF p_header_discount IS NOT NULL
        THEN
            BEGIN
                SELECT TO_NUMBER (p_header_discount) INTO ln_dummy FROM DUAL;

                IF p_header_discount > 100
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Discount should be less than or equal to 100. ';
                ELSIF SIGN (p_header_discount) = -1
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Discount should be a positive number. ';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Discount should be a number. ';
            END;
        END IF;

        -- Validate Line Discount
        IF p_line_discount IS NOT NULL
        THEN
            BEGIN
                SELECT TO_NUMBER (p_line_discount) INTO ln_dummy FROM DUAL;

                IF p_line_discount > 100
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Discount should be less than or equal to 100. ';
                ELSIF SIGN (p_line_discount) = -1
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Discount should be a positive number. ';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Discount should be a number. ';
            END;
        END IF;

        -- Validate Style Number
        IF p_style_number IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_dummy
              FROM xxd_common_items_v
             WHERE     style_number = p_style_number
                   AND brand = p_brand
                   AND master_org_flag = 'Y';

            IF ln_dummy = 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Brand on Style does not match with the Brand on Promotion. ';
            END IF;
        END IF;

        -- Validate Duplicate combination
        OPEN get_duplicate_records;

        FETCH get_duplicate_records INTO ln_dummy;

        CLOSE get_duplicate_records;

        IF ln_dummy > 0
        THEN
            lc_err_message   :=
                lc_err_message || 'Duplicate combination exists. ';
        END IF;


        OPEN get_duplicate_header_records;

        FETCH get_duplicate_header_records INTO ln_dummy;

        CLOSE get_duplicate_header_records;

        IF ln_dummy > 0
        THEN
            lc_err_message   :=
                lc_err_message || 'Duplicate promotion combination exists. ';
        END IF;

        -- Insert Promotion
        IF lc_err_message IS NULL
        THEN
            INSERT INTO xxdo.xxd_ont_promotions_t (promotion_id, org_id, promotion_code_status, promotion_code, promotion_name, operating_unit, brand, currency, customer_number, customer_name, cust_account_id, distribution_channel, ship_method, shipping_method_code, freight_term, freight_terms_code, payment_term, payment_term_id, header_discount, line_discount, ordered_date_from, ordered_date_to, request_date_from, request_date_to, department, division, class, sub_class, style_number, color_code, number_of_styles, number_of_colors, country_code, state, last_updated_by, last_update_date, last_update_login, created_by, creation_date
                                                   , promotion_level)
                     VALUES (
                                xxdo.xxd_ont_promotions_s.NEXTVAL,
                                ln_organization_id,
                                'A',
                                p_promotion_code,
                                p_promotion_name,
                                p_operating_unit,
                                p_brand,
                                p_currency,
                                p_customer_number,
                                lc_customer_name,
                                ln_cust_account_id,
                                p_distribution_channel,
                                p_ship_method,
                                lc_ship_method_code,
                                p_freight_term,
                                lc_freight_terms_code,
                                p_payment_term,
                                ln_term_id,
                                p_header_discount,
                                p_line_discount,
                                p_ordered_date_from,
                                p_ordered_date_to,
                                p_request_date_from,
                                p_request_date_to,
                                p_department,
                                p_division,
                                p_class,
                                p_sub_class,
                                p_style_number,
                                p_color_code,
                                p_number_of_styles,
                                p_number_of_colors,
                                p_country_code,
                                p_state,
                                gn_user_id,
                                gd_sysdate,
                                gn_login_id,
                                gn_user_id,
                                gd_sysdate,
                                CASE
                                    WHEN     p_department IS NULL
                                         AND p_division IS NULL
                                         AND p_class IS NULL
                                         AND p_sub_class IS NULL
                                         AND p_style_number IS NULL
                                         AND p_color_code IS NULL
                                    THEN
                                        'HEADER'
                                    ELSE
                                        'LINE'
                                END);
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
    END promotion_upload_prc;

    -- ===============================================================================
    -- This procedure validates duplicate promotions and inserts header records
    -- ===============================================================================
    PROCEDURE promotion_validate_prc
    AS
        CURSOR get_term_subtitutions IS
              SELECT promotion_code, ship_method, freight_term,
                     payment_term
                FROM xxd_ont_promotions_t
               WHERE promotion_code_status = 'A'
            GROUP BY promotion_code, ship_method, freight_term,
                     payment_term, department, division,
                     class, sub_class, style_number,
                     color_code
              HAVING COUNT (1) > 1;

        CURSOR get_duplicates IS
              SELECT promotion_code, operating_unit, brand,
                     currency, customer_number, distribution_channel,
                     ship_method, freight_term, payment_term,
                     header_discount, line_discount, ordered_date_from,
                     ordered_date_to, request_date_from, request_date_to,
                     department, division, class,
                     sub_class, style_number, color_code,
                     number_of_styles, number_of_colors, country_code,
                     state
                FROM xxd_ont_promotions_t
               WHERE     promotion_code_status = 'A'
                     AND TRUNC (creation_date) = TRUNC (SYSDATE)
            GROUP BY promotion_code, operating_unit, brand,
                     currency, customer_number, distribution_channel,
                     ship_method, freight_term, payment_term,
                     header_discount, line_discount, ordered_date_from,
                     ordered_date_to, request_date_from, request_date_to,
                     department, division, class,
                     sub_class, style_number, color_code,
                     number_of_styles, number_of_colors, country_code,
                     state
              HAVING COUNT (1) > 1;

        CURSOR get_headerless_promo IS
            WITH
                promo_query
                AS
                    (SELECT xopt.*,
                            ROW_NUMBER ()
                                OVER (PARTITION BY promotion_code, ship_method, freight_term,
                                                   payment_term
                                      ORDER BY promotion_id) RANK
                       FROM xxd_ont_promotions_t xopt
                      WHERE     xopt.promotion_code_status = 'A'
                            AND NOT EXISTS
                                    (SELECT 1
                                       FROM xxd_ont_promotions_t xopt1
                                      WHERE     xopt.promotion_code =
                                                xopt1.promotion_code
                                            AND xopt1.promotion_code_status =
                                                'A'
                                            AND xopt1.promotion_level =
                                                'HEADER'))
            SELECT *
              FROM promo_query
             WHERE RANK = 1;
    BEGIN
        -- Validate Terms Combination within the same Promotion
        FOR term_subtitutions_rec IN get_term_subtitutions
        LOOP
            UPDATE xxd_ont_promotions_t
               SET promotion_code_status = 'I', inactivation_date = gd_sysdate, inactivated_by = gn_user_id,
                   inactivation_reason = 'Inactivated by System - Different Terms across Header/Lines.', last_updated_by = gn_user_id, last_update_date = gd_sysdate,
                   last_update_login = gn_login_id
             WHERE     promotion_code = term_subtitutions_rec.promotion_code
                   AND promotion_code_status = 'A'
                   AND TRUNC (creation_date) = TRUNC (SYSDATE);
        END LOOP;

        -- Validate Duplicate Combination
        FOR duplicates_rec IN get_duplicates
        LOOP
            UPDATE xxd_ont_promotions_t
               SET promotion_code_status = 'I', inactivation_date = gd_sysdate, inactivated_by = gn_user_id,
                   inactivation_reason = 'Inactivated by System - Duplicate combination exists.', last_updated_by = gn_user_id, last_update_date = gd_sysdate,
                   last_update_login = gn_login_id
             WHERE     promotion_code = duplicates_rec.promotion_code
                   AND operating_unit = duplicates_rec.operating_unit
                   AND brand = duplicates_rec.brand
                   AND NVL (currency, 'XX') =
                       NVL (duplicates_rec.currency, NVL (currency, 'XX'))
                   AND NVL (customer_number, 'XX') =
                       NVL (duplicates_rec.customer_number,
                            NVL (customer_number, 'XX'))
                   AND NVL (distribution_channel, 'XX') =
                       NVL (duplicates_rec.distribution_channel,
                            NVL (distribution_channel, 'XX'))
                   AND NVL (ship_method, 'XX') =
                       NVL (duplicates_rec.ship_method,
                            NVL (ship_method, 'XX'))
                   AND NVL (freight_term, 'XX') =
                       NVL (duplicates_rec.freight_term,
                            NVL (freight_term, 'XX'))
                   AND NVL (payment_term, 'XX') =
                       NVL (duplicates_rec.payment_term,
                            NVL (payment_term, 'XX'))
                   AND NVL (header_discount, 999) =
                       NVL (duplicates_rec.header_discount,
                            NVL (header_discount, 999))
                   AND NVL (line_discount, 999) =
                       NVL (duplicates_rec.line_discount,
                            NVL (line_discount, 999))
                   AND TRUNC (
                           NVL (ordered_date_from, TO_DATE ('01-JAN-1950'))) =
                       TRUNC (
                           NVL (
                               duplicates_rec.ordered_date_from,
                               NVL (ordered_date_from,
                                    TO_DATE ('01-JAN-1950'))))
                   AND TRUNC (NVL (ordered_date_to, TO_DATE ('01-JAN-1950'))) =
                       TRUNC (
                           NVL (
                               duplicates_rec.ordered_date_to,
                               NVL (ordered_date_to, TO_DATE ('01-JAN-1950'))))
                   AND TRUNC (
                           NVL (request_date_from, TO_DATE ('01-JAN-1950'))) =
                       TRUNC (
                           NVL (
                               duplicates_rec.request_date_from,
                               NVL (request_date_from,
                                    TO_DATE ('01-JAN-1950'))))
                   AND TRUNC (NVL (request_date_to, TO_DATE ('01-JAN-1950'))) =
                       TRUNC (
                           NVL (
                               duplicates_rec.request_date_to,
                               NVL (request_date_to, TO_DATE ('01-JAN-1950'))))
                   AND NVL (department, 'XX') =
                       NVL (duplicates_rec.department,
                            NVL (department, 'XX'))
                   AND NVL (division, 'XX') =
                       NVL (duplicates_rec.division, NVL (division, 'XX'))
                   AND NVL (class, 'XX') =
                       NVL (duplicates_rec.class, NVL (class, 'XX'))
                   AND NVL (sub_class, 'XX') =
                       NVL (duplicates_rec.sub_class, NVL (sub_class, 'XX'))
                   AND NVL (style_number, 'XX') =
                       NVL (duplicates_rec.style_number,
                            NVL (style_number, 'XX'))
                   AND NVL (color_code, 'XX') =
                       NVL (duplicates_rec.color_code,
                            NVL (color_code, 'XX'))
                   AND NVL (number_of_styles, 999) =
                       NVL (duplicates_rec.number_of_styles,
                            NVL (number_of_styles, 999))
                   AND NVL (number_of_colors, 999) =
                       NVL (duplicates_rec.number_of_colors,
                            NVL (number_of_colors, 999))
                   AND NVL (country_code, 'XX') =
                       NVL (duplicates_rec.country_code,
                            NVL (country_code, 'XX'))
                   AND NVL (state, 'XX') =
                       NVL (duplicates_rec.state, NVL (state, 'XX'))
                   AND promotion_code_status = 'A'
                   AND TRUNC (creation_date) = TRUNC (SYSDATE);
        END LOOP;

        --Insert HEADER record if not exists
        FOR headerless_promo_rec IN get_headerless_promo
        LOOP
            INSERT INTO xxd_ont_promotions_t (promotion_id, promotion_code, promotion_name, operating_unit, org_id, brand, currency, promotion_code_status, creation_date, created_by, last_update_date, last_updated_by, last_update_login, customer_number, customer_name, cust_account_id, distribution_channel, ship_method, shipping_method_code, freight_term, freight_terms_code, payment_term, payment_term_id, header_discount, line_discount, ordered_date_from, ordered_date_to, request_date_from, request_date_to, department, division, class, sub_class, style_number, color_code, number_of_styles, number_of_colors, country_code, state
                                              , promotion_level)
                 VALUES (xxdo.xxd_ont_promotions_s.NEXTVAL, headerless_promo_rec.promotion_code, 'Header Record Added by System', headerless_promo_rec.operating_unit, headerless_promo_rec.org_id, headerless_promo_rec.brand, headerless_promo_rec.currency, headerless_promo_rec.promotion_code_status, gd_sysdate, gn_user_id, gd_sysdate, gn_user_id, gn_login_id, headerless_promo_rec.customer_number, headerless_promo_rec.customer_name, headerless_promo_rec.cust_account_id, headerless_promo_rec.distribution_channel, headerless_promo_rec.ship_method, headerless_promo_rec.shipping_method_code, headerless_promo_rec.freight_term, headerless_promo_rec.freight_terms_code, headerless_promo_rec.payment_term, headerless_promo_rec.payment_term_id, headerless_promo_rec.header_discount, NULL, headerless_promo_rec.ordered_date_from, headerless_promo_rec.ordered_date_to, headerless_promo_rec.request_date_from, headerless_promo_rec.request_date_to, NULL, NULL, NULL, NULL, NULL, NULL, headerless_promo_rec.number_of_styles, headerless_promo_rec.number_of_colors, headerless_promo_rec.country_code, headerless_promo_rec.state
                         , 'HEADER');
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (-20001, SQLERRM);
    END promotion_validate_prc;
END xxd_ont_promotion_adi_x_pk;
/
