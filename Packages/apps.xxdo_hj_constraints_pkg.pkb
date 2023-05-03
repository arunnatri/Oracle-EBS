--
-- XXDO_HJ_CONSTRAINTS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_HJ_CONSTRAINTS_PKG"
IS
    g_pkg_name   CONSTANT VARCHAR2 (30) := 'XXDO_HJ_CONSTRAINTS_PKG';

    PROCEDURE validate_release_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                       , x_result_out OUT NOCOPY NUMBER)
    IS
        l_release_status         VARCHAR2 (1);
        --
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    --
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;

        SELECT pick_status
          INTO l_release_status
          FROM wsh_delivery_line_status_v
         WHERE     source_code = 'OE'
               AND source_line_id = oe_line_security.g_record.line_id
               AND pick_status = 'S';

        IF l_release_status = 'S'
        THEN
            x_result_out   := 1;
        ELSE
            x_result_out   := 0;
        END IF;

        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '2';
        END IF;

        IF x_result_out = 1
        THEN
            BEGIN
                SELECT 1
                  INTO x_result_out
                  FROM mtl_parameters mp, oe_order_lines_all ool
                 WHERE     ool.line_id = oe_line_security.g_record.line_id
                       AND ool.ship_from_org_id = mp.organization_id
                       AND mp.organization_code IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values fvl
                                 WHERE     fvl.lookup_type = 'XXONT_WMS_WHSE'
                                       AND NVL (LANGUAGE, USERENV ('LANG')) =
                                           USERENV ('LANG')
                                       AND fvl.enabled_flag = 'Y');
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_result_out   := 0;
            END;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('NO DATA FOUND IN VALIDATE RELEASE STATUS',
                                  1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('TOO MANY ROWS IN VALIDATE RELEASE STATUS',
                                  1);
            END IF;

            x_result_out   := 1;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name,
                                        'Validate_Release_Status');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN VALIDATE RELEASE STATUS : '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;
    END validate_release_status;
END xxdo_hj_constraints_pkg;
/
