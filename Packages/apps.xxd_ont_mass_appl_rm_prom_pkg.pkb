--
-- XXD_ONT_MASS_APPL_RM_PROM_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_MASS_APPL_RM_PROM_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_MASS_APPL_RM_PROM_PKG
    * Design       : This package is used for mass applying/removing Promotions
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 24-Jul-2017  1.0       Arun Murthy     Initial Version
    -- 27-Jul-2017  1.0       Arun Murthy      Check order line status procedure is redundant
                                                    even in XXD_ONT_PROMOTIONS_X_PK.check_order_line_status.
                                                    Hence any changes in that package needs to be
                                                    changed accordingly to this pkg
    ******************************************************************************************/
    FUNCTION check_order_line_status (
        p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN NUMBER
    AS
        CURSOR get_order_lines IS
            SELECT COUNT (1)
              FROM oe_order_lines_all oola, fnd_lookup_values flv
             WHERE     oe_line_status_pub.get_line_status (
                           oola.line_id,
                           oola.flow_status_code) =
                       flv.meaning
                   AND flv.lookup_type = 'XXD_PROMO_MODIFIER'
                   AND flv.description = 'FLOW_STATUS_CODE'
                   AND flv.enabled_flag = 'Y'
                   AND flv.language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND oola.header_id = p_header_id;

        ln_dummy   NUMBER := 0;
    BEGIN
        OPEN get_order_lines;

        FETCH get_order_lines INTO ln_dummy;

        CLOSE get_order_lines;

        RETURN ln_dummy;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 1;
    END check_order_line_status;

    PROCEDURE prc_apply_remove_promotion (p_order_number IN oe_order_headers_all.order_number%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE DEFAULT NULL, p_is_apply IN VARCHAR2)
    IS
        ln_order_header_id    oe_order_headers_all.header_id%TYPE;
        ln_promotion_code     oe_order_headers_all.attribute11%TYPE;
        x_status_flag         VARCHAR2 (100);
        x_clear_flag          VARCHAR2 (100);
        le_webadi_exception   EXCEPTION;
        lc_err_message        VARCHAR2 (4000) := NULL;
        lc_ret_message        VARCHAR2 (4000) := NULL;
        x_err_message         VARCHAR2 (4000) := NULL;
        ln_user_id            NUMBER := fnd_global.user_id;
        ln_resp_id            NUMBER := fnd_global.resp_id;
        ln_resp_app_id        NUMBER := fnd_global.resp_appl_id;
        ln_org_id             NUMBER := fnd_global.org_id;
        ln_is_apply           NUMBER := 0;
        ln_line_status        NUMBER := 1;
        lv_promtion_code      VARCHAR2 (200);
        lv_promotion_status   VARCHAR2 (80);
        ln_invld_prom_cnt     NUMBER := 1;
        ln_vld_prom_cnt       NUMBER := 0;
        lv_brand              VARCHAR2 (50);
    BEGIN
        IF p_is_apply = 'APPLY'
        THEN
            ln_is_apply   := 1;
        ELSE
            ln_is_apply   := 2;
        END IF;

        fnd_global.apps_initialize (user_id        => ln_user_id,
                                    resp_id        => ln_resp_id,
                                    resp_appl_id   => ln_resp_app_id);
        mo_global.set_policy_context ('S', ln_org_id);
        mo_global.init ('ONT');

        BEGIN
            SELECT header_id, attribute11, attribute12,
                   attribute5
              INTO ln_order_header_id, lv_promtion_code, lv_promotion_status, lv_brand
              FROM oe_order_headers_all
             WHERE     1 = 1
                   AND order_number = p_order_number
                   AND org_id = ln_org_id
                   AND open_flag = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   := SQLERRM;
                RAISE le_webadi_exception;
        END;

        IF p_promotion_code IS NOT NULL AND p_is_apply = 'APPLY'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_vld_prom_cnt
                  FROM xxd_ont_promotions_t
                 WHERE     1 = 1
                       AND promotion_code = p_promotion_code
                       AND brand = lv_brand;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   := SQLERRM;
                    RAISE le_webadi_exception;
            END;

            IF ln_vld_prom_cnt = 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || '  ---  '
                    || 'The Brand of this Order is '
                    || lv_brand
                    || '. Please Enter a valid Promotion Code';
                RAISE le_webadi_exception;
            END IF;
        END IF;

        IF xxd_ont_promotions_x_pk.check_order_lock (ln_order_header_id) =
           'Y'
        THEN
            lc_err_message   :=
                   lc_err_message
                || '  -- This Order has been locked by other source';
            RAISE le_webadi_exception;
        END IF;

        IF ln_is_apply = 1
        THEN
            IF p_promotion_code IS NULL
            THEN
                lc_err_message   :=
                       lc_err_message
                    || ' --  Promotion Code cannot be null if the Action = "APPLY" ';
                RAISE le_webadi_exception;
            END IF;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_invld_prom_cnt
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND lookup_type = 'XXD_ONT_PROMO_STATUS_ADI'
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND tag = 'Remove'
                       AND meaning = lv_promotion_status;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || '  -- No records returned while deriving invlaid promotion count';
                    RAISE le_webadi_exception;
            END;

            IF ln_invld_prom_cnt > 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || ' -- Promotion status is "Applied", Please remove existing promotion during the upload';
                RAISE le_webadi_exception;
            END IF;
        ELSIF     ln_is_apply = 2
              AND NVL (lv_promotion_status, 'INVALID') = 'INVALID'
        THEN
            lc_err_message   :=
                lc_err_message || ' -- No promotion has been applied';
            RAISE le_webadi_exception;
        END IF;

        ln_line_status   := check_order_line_status (ln_order_header_id);

        IF ln_line_status = 0
        THEN
            IF p_promotion_code IS NULL
            THEN
                BEGIN
                    SELECT attribute11
                      INTO ln_promotion_code
                      FROM oe_order_headers_all
                     WHERE     1 = 1
                           AND order_number = p_order_number
                           AND attribute12 IN
                                   ('Scheduled to Apply', 'Applied', 'Scheduled to Remove');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_err_message   := SQLERRM;
                END;

                xxd_ont_promotions_x_pk.apply_remove_promotion (
                    ln_order_header_id,
                    ln_promotion_code,
                    ln_user_id,
                    ln_resp_id,
                    ln_resp_app_id,
                    ln_org_id,
                    ln_is_apply,
                    x_status_flag,
                    x_err_message,
                    x_clear_flag);

                IF x_status_flag = 'E' AND x_err_message <> 'schedule'
                THEN
                    lc_err_message   :=
                        lc_err_message || '--' || x_err_message;
                    RAISE le_webadi_exception;
                ELSIF x_status_flag = 'E' AND x_err_message = 'schedule'
                THEN
                    IF ln_is_apply = 1
                    THEN
                        lv_promotion_status   := 'Scheduled to Apply';
                    ELSE
                        lv_promotion_status   := 'Scheduled to Remove';
                    END IF;

                    xxd_ont_promotions_x_pk.schedule_promotion (
                        ln_order_header_id,
                        ln_promotion_code,
                        lv_promotion_status,
                        ln_user_id,
                        ln_resp_id,
                        ln_resp_app_id,
                        ln_org_id,
                        x_status_flag,
                        x_err_message);

                    IF x_status_flag = 'E'
                    THEN
                        lc_err_message   :=
                            lc_err_message || '--' || x_err_message;
                        RAISE le_webadi_exception;
                    END IF;
                END IF;
            ELSE
                xxd_ont_promotions_x_pk.apply_remove_promotion (
                    ln_order_header_id,
                    p_promotion_code,
                    ln_user_id,
                    ln_resp_id,
                    ln_resp_app_id,
                    ln_org_id,
                    ln_is_apply,
                    x_status_flag,
                    x_err_message,
                    x_clear_flag);

                IF x_status_flag = 'E' AND x_err_message <> 'schedule'
                THEN
                    lc_err_message   :=
                        lc_err_message || '--' || x_err_message;
                    RAISE le_webadi_exception;
                ELSIF x_status_flag = 'E' AND x_err_message = 'schedule'
                THEN
                    IF ln_is_apply = 1
                    THEN
                        lv_promotion_status   := 'Scheduled to Apply';
                    ELSE
                        lv_promotion_status   := 'Scheduled to Remove';
                    END IF;

                    xxd_ont_promotions_x_pk.schedule_promotion (
                        ln_order_header_id,
                        p_promotion_code,
                        lv_promotion_status,
                        ln_user_id,
                        ln_resp_id,
                        ln_resp_app_id,
                        ln_org_id,
                        x_status_flag,
                        x_err_message);

                    IF x_status_flag = 'E'
                    THEN
                        lc_err_message   :=
                            lc_err_message || '--' || x_err_message;
                        RAISE le_webadi_exception;
                    END IF;
                END IF;

                IF x_status_flag = 'E'
                THEN
                    lc_err_message   :=
                        lc_err_message || '--' || x_err_message;
                    RAISE le_webadi_exception;
                END IF;
            END IF;
        ELSE
            lc_err_message   :=
                   lc_err_message
                || ' -- One or more lines are either Closed/Invoiced/Shipped/Picked ';
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
            ROLLBACK;
            lc_ret_message   := SQLERRM;
            raise_application_error (-20001, lc_ret_message);
    END;
END xxd_ont_mass_appl_rm_prom_pkg;
/
