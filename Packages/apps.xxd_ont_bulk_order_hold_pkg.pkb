--
-- XXD_ONT_BULK_ORDER_HOLD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BULK_ORDER_HOLD_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_ORDER_HOLD_PKG
    * Design       : This package will be used to apply/release hold to restrict or control
    *                Bulk order closure by Workflow Background Process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 23-Feb-2018  1.0        Viswanathan Pandian     Initial Version
    -- 23-Sep-2021  1.1        Shivanshu Talwar        Modified for CCR0009552
    ******************************************************************************************/
    gn_created_by        NUMBER := apps.fnd_global.user_id;
    gn_last_updated_by   NUMBER := apps.fnd_global.user_id;
    gn_conc_request_id   NUMBER := apps.fnd_global.conc_request_id;
    gn_user_id           NUMBER := apps.fnd_global.user_id;
    gn_resp_appl_id      NUMBER := apps.fnd_global.resp_appl_id;
    gn_resp_id           NUMBER := apps.fnd_global.resp_id;

    PROCEDURE apply_release_hold (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_apply_release IN VARCHAR2
                                  , p_hold_id IN oe_hold_sources_all.hold_id%TYPE, p_release_reason_code IN VARCHAR2, p_release_comment IN VARCHAR2)
    IS
        CURSOR get_hold_order_c IS
            /* --Start w.r.t 1.1
            SELECT header_id, order_number
               FROM oe_order_headers_all ooha, fnd_lookup_values flv
              WHERE     ooha.open_flag = 'Y'
                    AND ooha.booked_flag = 'Y'
                    AND ooha.org_id = p_org_id
                    AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                    AND ooha.org_id = TO_NUMBER (flv.tag)
                    AND flv.language = USERENV ('LANG')
                    AND flv.enabled_flag = 'Y'
                    AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (flv.start_date_active,
                                                        SYSDATE))
                                            AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                    AND flv.lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
                    AND (   (    p_order_number_from IS NOT NULL
                             AND p_order_number_to IS NOT NULL
                             AND ooha.order_number BETWEEN p_order_number_from
                                                       AND p_order_number_to)
                         OR (    p_order_number_from IS NULL
                             AND p_order_number_to IS NULL
                             AND 1 = 1))
                    AND TRUNC (SYSDATE) <=
                           (SELECT TRUNC (MAX (latest_acceptable_date))
                              FROM oe_order_lines_all oola
                             WHERE     oola.header_id = ooha.header_id
                                   AND oola.org_id = ooha.org_id)
                    AND NOT EXISTS
                               (SELECT 1
                                  FROM oe_order_holds_all holds,
                                       oe_hold_sources_all ohsa,
                                       oe_hold_definitions ohd
                                 WHERE     holds.hold_source_id =
                                              ohsa.hold_source_id
                                       AND ohsa.hold_id = ohd.hold_id
                                       AND holds.header_id = ooha.header_id
                                       AND holds.released_flag = 'N'
                                       AND ohsa.released_flag = 'N'
                                       AND ohsa.hold_id = p_hold_id);*/

            SELECT header_id, order_number, TO_NUMBER (flv.attribute2) hold_id
              FROM oe_order_headers_all ooha, fnd_lookup_values flv
             WHERE     ooha.open_flag = 'Y'
                   AND ooha.booked_flag = 'Y'
                   AND ooha.org_id = p_org_id
                   AND ooha.order_type_id = TO_NUMBER (flv.attribute1)
                   AND TO_NUMBER (flv.attribute2) =
                       NVL (p_hold_id, TO_NUMBER (flv.attribute2))
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.lookup_type = 'XXD_ONT_ORDER_HDR_HOLD_LKP'
                   AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number BETWEEN p_order_number_from AND p_order_number_to) OR (p_order_number_from IS NULL AND p_order_number_to IS NULL AND 1 = 1))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd
                             WHERE     holds.hold_source_id =
                                       ohsa.hold_source_id
                                   AND ohsa.hold_id = ohd.hold_id
                                   AND holds.header_id = ooha.header_id
                                   AND holds.released_flag = 'N'
                                   AND ohsa.released_flag = 'N'
                                   AND ohsa.hold_id =
                                       TO_NUMBER (flv.attribute2))
            UNION
            SELECT header_id, order_number, TO_NUMBER (flv.attribute3) hold_id
              FROM oe_order_headers_all ooha, fnd_lookup_values flv
             WHERE     ooha.open_flag = 'Y'
                   AND ooha.booked_flag = 'Y'
                   AND ooha.org_id = p_org_id
                   AND ooha.order_type_id = TO_NUMBER (flv.attribute1)
                   AND TO_NUMBER (NVL (flv.attribute3, '0000')) =
                       NVL (p_hold_id, TO_NUMBER (flv.attribute3))
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.lookup_type = 'XXD_ONT_ORDER_HDR_HOLD_LKP'
                   AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number BETWEEN p_order_number_from AND p_order_number_to) OR (p_order_number_from IS NULL AND p_order_number_to IS NULL AND 1 = 1))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd
                             WHERE     holds.hold_source_id =
                                       ohsa.hold_source_id
                                   AND ohsa.hold_id = ohd.hold_id
                                   AND holds.header_id = ooha.header_id
                                   AND holds.released_flag = 'N'
                                   AND ohsa.released_flag = 'N'
                                   AND ohsa.hold_id =
                                       TO_NUMBER (
                                           NVL (flv.attribute3, '0000')));

        CURSOR get_release_order_c IS
            /* SELECT header_id, order_number
               FROM oe_order_headers_all ooha, fnd_lookup_values flv
              WHERE     ooha.open_flag = 'Y'
                    AND ooha.booked_flag = 'Y'
                    AND ooha.org_id = p_org_id
                    AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                    AND ooha.org_id = TO_NUMBER (flv.tag)
                    AND flv.language = USERENV ('LANG')
                    AND flv.enabled_flag = 'Y'
                    AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (flv.start_date_active,
                                                        SYSDATE))
                                            AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                    AND flv.lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
                    AND (   (    p_order_number_from IS NOT NULL
                             AND p_order_number_to IS NOT NULL
                             AND ooha.order_number BETWEEN p_order_number_from
                                                       AND p_order_number_to)
                         OR (    p_order_number_from IS NULL
                             AND p_order_number_to IS NULL
                             AND 1 = 1))
                    AND TRUNC (SYSDATE) >=
                           (SELECT TRUNC (MAX (latest_acceptable_date))
                              FROM oe_order_lines_all oola
                             WHERE     oola.header_id = ooha.header_id
                                   AND oola.org_id = ooha.org_id)
                    AND EXISTS
                           (SELECT 1
                              FROM oe_order_holds_all holds,
                                   oe_hold_sources_all ohsa,
                                   oe_hold_definitions ohd
                             WHERE     holds.hold_source_id = ohsa.hold_source_id
                                   AND ohsa.hold_id = ohd.hold_id
                                   AND holds.header_id = ooha.header_id
                                   AND holds.released_flag = 'N'
                                   AND ohsa.released_flag = 'N'
                                   AND ohsa.hold_id = p_hold_id); */

            SELECT header_id, order_number, TO_NUMBER (flv.attribute2) hold_id
              FROM oe_order_headers_all ooha, fnd_lookup_values flv
             WHERE     ooha.open_flag = 'Y'
                   AND ooha.booked_flag = 'Y'
                   AND ooha.org_id = p_org_id
                   AND ooha.order_type_id = TO_NUMBER (flv.attribute1)
                   AND TO_NUMBER (flv.attribute2) =
                       NVL (p_hold_id, TO_NUMBER (flv.attribute2))
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.lookup_type = 'XXD_ONT_ORDER_HDR_HOLD_LKP'
                   AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number BETWEEN p_order_number_from AND p_order_number_to) OR (p_order_number_from IS NULL AND p_order_number_to IS NULL AND 1 = 1))
                   AND EXISTS
                           (SELECT 1
                              FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd
                             WHERE     holds.hold_source_id =
                                       ohsa.hold_source_id
                                   AND ohsa.hold_id = ohd.hold_id
                                   AND holds.header_id = ooha.header_id
                                   AND holds.released_flag = 'N'
                                   AND ohsa.released_flag = 'N'
                                   AND ohsa.hold_id =
                                       TO_NUMBER (flv.attribute2))
            UNION
            SELECT header_id, order_number, TO_NUMBER (flv.attribute3) hold_id
              FROM oe_order_headers_all ooha, fnd_lookup_values flv
             WHERE     ooha.open_flag = 'Y'
                   AND ooha.booked_flag = 'Y'
                   AND ooha.org_id = p_org_id
                   AND ooha.order_type_id = TO_NUMBER (flv.attribute1)
                   AND NVL (TO_NUMBER (flv.attribute3), '0000') =
                       NVL (p_hold_id, TO_NUMBER (flv.attribute3))
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.lookup_type = 'XXD_ONT_ORDER_HDR_HOLD_LKP'
                   AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number BETWEEN p_order_number_from AND p_order_number_to) OR (p_order_number_from IS NULL AND p_order_number_to IS NULL AND 1 = 1))
                   AND EXISTS
                           (SELECT 1
                              FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd
                             WHERE     holds.hold_source_id =
                                       ohsa.hold_source_id
                                   AND ohsa.hold_id = ohd.hold_id
                                   AND holds.header_id = ooha.header_id
                                   AND holds.released_flag = 'N'
                                   AND ohsa.released_flag = 'N'
                                   AND ohsa.hold_id =
                                       NVL (TO_NUMBER (flv.attribute3),
                                            '0000'));

        --End w.r.t 1.1


        l_line_rec             oe_order_pub.line_rec_type;
        l_header_rec           oe_order_pub.header_rec_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        l_request_rec          oe_order_pub.request_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        l_hold_source_rec      oe_holds_pvt.hold_source_rec_type;
        l_order_tbl_type       oe_holds_pvt.order_tbl_type;
        ln_msg_count           NUMBER := 0;
        ln_msg_index_out       NUMBER;
        ln_record_count        NUMBER := 0;
        lc_msg_data            VARCHAR2 (2000);
        lc_error_message       VARCHAR2 (2000);
        lc_return_status       VARCHAR2 (20);
        ln_hold_id             NUMBER;
        ex_validate            EXCEPTION;
    BEGIN
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', fnd_global.org_id);

        IF p_apply_release = 'APPLY'
        THEN
            FOR hold_order_rec IN get_hold_order_c
            LOOP
                ln_hold_id                           := hold_order_rec.hold_id; --added w.r.t 1.1
                ln_record_count                      := ln_record_count + 1;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Start Hold Application on Order ' || hold_order_rec.order_number);
                lc_error_message                     := NULL;
                ln_msg_count                         := 0;
                ln_msg_index_out                     := 0;
                lc_msg_data                          := NULL;
                ln_msg_count                         := NULL;
                ln_msg_count                         := NULL;
                ---   l_hold_source_rec.hold_id := p_hold_id; --commented w.r.t 1.1
                l_hold_source_rec.hold_id            := ln_hold_id; --added w.r.t 1.1
                l_hold_source_rec.hold_entity_code   := 'O';
                l_hold_source_rec.hold_entity_id     :=
                    hold_order_rec.header_id;
                l_hold_source_rec.hold_comment       :=
                       'Applied by Bulk Order Hold Apply Program Request_id:'
                    || gn_conc_request_id;
                oe_holds_pub.apply_holds (
                    p_api_version        => 1.0,
                    p_validation_level   => fnd_api.g_valid_level_full,
                    p_hold_source_rec    => l_hold_source_rec,
                    x_msg_count          => ln_msg_count,
                    x_msg_data           => lc_msg_data,
                    x_return_status      => lc_return_status);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Apply Hold Status = ' || lc_return_status);

                IF lc_return_status = 'S'
                THEN
                    fnd_file.put_line (fnd_file.LOG, 'Applied Hold');
                ELSE
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                        , p_msg_index_out => ln_msg_index_out);
                        lc_error_message   := lc_error_message || lc_msg_data;
                    END LOOP;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Apply Hold Failed: ' || lc_error_message);
                END IF;
            END LOOP;
        ELSIF p_apply_release = 'RELEASE'
        THEN
            IF p_release_reason_code IS NULL OR p_release_comment IS NULL
            THEN
                lc_error_message   :=
                    'Please Provide both Release Reason Code and Release Comment';
                RAISE ex_validate;
            END IF;

            FOR release_order_rec IN get_release_order_c
            LOOP
                ln_hold_id        := release_order_rec.hold_id; --added w.r.t 1.1
                ln_record_count   := ln_record_count + 1;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Start Hold Release on Order ' || release_order_rec.order_number);
                l_order_tbl_type (1).header_id   :=
                    release_order_rec.header_id;

                -- Call Process Order to release hold
                oe_holds_pub.release_holds (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, p_order_tbl => l_order_tbl_type, --  p_hold_id               => p_hold_id, --commented w.r.t 1.1
                                                                                                                                                                   p_hold_id => ln_hold_id, --added w.r.t 1.1
                                                                                                                                                                                            p_release_reason_code => p_release_reason_code, p_release_comment => p_release_comment, x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                            , x_msg_data => lc_msg_data);

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Hold Release Status = ' || lc_return_status);

                IF lc_return_status = 'S'
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Released Hold Id ' || ln_hold_id);
                ELSE
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                        , p_msg_index_out => ln_msg_index_out);
                        lc_error_message   := lc_error_message || lc_msg_data;
                    END LOOP;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Hold Release Failed: ' || lc_error_message);
                END IF;
            END LOOP;
        END IF;

        IF ln_record_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG, 'No Data Found');
        END IF;
    EXCEPTION
        WHEN ex_validate
        THEN
            x_errbuf    := lc_error_message;
            x_retcode   := 1;
            fnd_file.put_line (fnd_file.LOG,
                               'Validation Exception: ' || lc_error_message);
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            fnd_file.put_line (fnd_file.LOG, 'Others Exception: ' || SQLERRM);
    END apply_release_hold;
END xxd_ont_bulk_order_hold_pkg;
/
