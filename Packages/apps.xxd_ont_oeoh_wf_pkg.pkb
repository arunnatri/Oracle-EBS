--
-- XXD_ONT_OEOH_WF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_OEOH_WF_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_OEOH_WF_PKG
    * Design       : This package will be called from OEOH Workflow
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 10-Apr-2018  1.0        Viswanathan Pandian     Initial Version
    -- 17-Aug-2020  1.1        Gaurav Joshi            Add "Brand" parameter to Order Book Hold Criteria
    -- 22-Apr-2022  1.2        Viswanathan Pandian     Updated for CCR0009975
    -- 09-May-2022  1.3        Chirag Parekh           Updated for CCR0009995
    -- 05-JAN-2023  1.4        Elaine Yang             Updated for CCR0010065
    ******************************************************************************************/
    -- Start changes for CCR0009975
    gv_debug       VARCHAR2 (1);
    gv_pkg         VARCHAR2 (20) := 'XXD_ONT_OEOH_WF_PKG';
    gv_delimiter   VARCHAR2 (1) := ';';
    gv_debug_msg   VARCHAR2 (4000);

    PROCEDURE msg (p_msg IN VARCHAR2)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF gv_debug IS NULL
        THEN
            SELECT DECODE (COUNT (1), 0, 'N', 'Y')
              INTO gv_debug
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_OM_DEBUG_LOOKUP'
                   AND language = USERENV ('LANG')
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (start_date_active)
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND tag = gv_pkg;
        END IF;

        IF gv_debug = 'Y'
        THEN
            INSERT INTO custom.do_debug (created_by, application_id, debug_text
                                         , session_id, call_stack)
                     VALUES (
                                NVL (fnd_global.user_id, -1),
                                660,
                                gv_pkg || ':' || p_msg,
                                USERENV ('SESSIONID'),
                                SUBSTR (DBMS_UTILITY.format_call_stack,
                                        1,
                                        2000));

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END msg;

    -- End changes for CCR0009975

    PROCEDURE apply_hold (itemtype IN VARCHAR2, itemkey IN VARCHAR2, actid IN NUMBER
                          , funcmode IN VARCHAR2, resultout IN OUT VARCHAR2)
    IS
        CURSOR get_hold_c IS
            SELECT TO_NUMBER (flv.attribute5) hold_id
              FROM fnd_lookup_values flv, oe_order_headers_all ooha
             WHERE     lookup_type = 'XXD_ORDER_BOOK_HOLD_CRITERIA'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   -- Ordered Date
                   -- Changed Started for CCR0010065
                   /* AND TRUNC (ooha.ordered_date) BETWEEN TRUNC (
                                                              NVL (
                                                                  flv.start_date_active,
                                                                  SYSDATE))
                                                      AND TRUNC (
                                                              NVL (
                                                                  flv.end_date_active,
                                                                  SYSDATE))*/
                   AND TRUNC (ooha.ordered_date) >=
                       NVL (
                           TRUNC (flv.start_date_active),
                           LEAST (TRUNC (SYSDATE), TRUNC (ooha.ordered_date)))
                   AND TRUNC (ooha.ordered_date) <=
                       NVL (
                           TRUNC (flv.end_date_active),
                           GREATEST (TRUNC (SYSDATE),
                                     TRUNC (ooha.ordered_date)))
                   --- Changed Ended for CCR0010065
                   -- Operating Unit
                   AND ooha.org_id = TO_NUMBER (flv.attribute1)
                   -- Customer
                   AND ((flv.attribute2 IS NULL AND 1 = 1) OR (flv.attribute2 IS NOT NULL AND ooha.sold_to_org_id = TO_NUMBER (flv.attribute2)))
                   -- Order Type
                   AND ((flv.attribute3 IS NULL AND 1 = 1) OR (flv.attribute3 IS NOT NULL AND ooha.order_type_id = TO_NUMBER (flv.attribute3)))
                   -- Order Source
                   AND ((flv.attribute4 IS NULL AND 1 = 1) OR (flv.attribute4 IS NOT NULL AND ooha.order_source_id = TO_NUMBER (flv.attribute4)))
                   -- ver 1.1 Added Brand condition
                   AND ((flv.attribute6 IS NULL AND 1 = 1) OR (flv.attribute6 = 'ALL BRAND' AND 1 = 1) OR (flv.attribute6 IS NOT NULL AND ooha.attribute5 = flv.attribute6))
                   AND ooha.header_id = TO_NUMBER (itemkey);

        ln_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_hold_source_rec         oe_holds_pvt.hold_source_rec_type;
        ln_header_id              NUMBER;
        ln_msg_count              NUMBER := 0;
        ln_msg_index_out          NUMBER;
        lc_msg_data               VARCHAR2 (2000);
        lc_error_message          VARCHAR2 (2000);
        lc_return_status          VARCHAR2 (20);
        -- begin Added ver 1.3
        ln_record_count           NUMBER := 0;
        ld_ordered_date           DATE;
        ln_order_org_id           NUMBER;
        ln_sold_to_org_id         NUMBER;
        ln_order_type_id          NUMBER;
        ln_order_source_id        NUMBER;
        lc_order_attribute5       VARCHAR2 (150);
    -- End Added ver 1.3
    BEGIN
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', fnd_global.org_id);
        ln_header_id   := TO_NUMBER (itemkey);

        -- Start changes for CCR0009975
        gv_debug_msg   :=
               'WF FuncMode: '
            || funcmode
            || gv_delimiter
            || 'WF actid: '
            || actid
            || gv_delimiter
            || 'Init Org ID: '
            || fnd_global.org_id
            || gv_delimiter
            || 'Header ID before API: '
            || ln_header_id
            || gv_delimiter;
        msg (gv_debug_msg);

        -- End changes for CCR0009975

        --Start ver 1.3 changes for CCR0009995
        BEGIN
            gv_debug_msg      := NULL;
            ln_record_count   := 0;

            SELECT COUNT (*)
              INTO ln_record_count
              FROM oe_order_headers_all ooha
             WHERE ooha.header_id = ln_header_id;

            gv_debug_msg      :=
                   'Header ID: '
                || ln_header_id
                || gv_delimiter
                || 'Order count: '
                || ln_record_count;

            IF ln_record_count > 0 AND gv_debug = 'Y' --to only execute below if debug is true
            THEN
                SELECT TRUNC (ooha.ordered_date), ooha.org_id, ooha.sold_to_org_id,
                       ooha.order_type_id, ooha.order_source_id, ooha.attribute5
                  INTO ld_ordered_date, ln_order_org_id, ln_sold_to_org_id, ln_order_type_id,
                                      ln_order_source_id, lc_order_attribute5
                  FROM oe_order_headers_all ooha
                 WHERE ooha.header_id = ln_header_id;

                gv_debug_msg      :=
                       gv_debug_msg
                    || gv_delimiter
                    || 'Ordered Date: '
                    || ld_ordered_date
                    || gv_delimiter
                    || 'Org ID: '
                    || ln_order_org_id
                    || gv_delimiter
                    || 'Sold to Org ID:  '
                    || ln_sold_to_org_id
                    || gv_delimiter
                    || 'Order Type ID: '
                    || ln_order_type_id
                    || gv_delimiter
                    || 'Order Source ID: '
                    || ln_order_source_id
                    || gv_delimiter
                    || 'Order Attribute5: '
                    || lc_order_attribute5;

                -------------------------
                -- Lookup check for all attributes
                -------------------------
                ln_record_count   := 0;

                SELECT COUNT (*)
                  INTO ln_record_count
                  FROM fnd_lookup_values flv
                 WHERE     lookup_type = 'XXD_ORDER_BOOK_HOLD_CRITERIA'
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       -- Ordered Date
                       AND ld_ordered_date BETWEEN TRUNC (
                                                       NVL (
                                                           flv.start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (
                                                           flv.end_date_active,
                                                           SYSDATE))
                       -- Operating Unit
                       AND ln_order_org_id = TO_NUMBER (flv.attribute1)
                       -- Customer
                       AND ((flv.attribute2 IS NULL AND 1 = 1) OR (flv.attribute2 IS NOT NULL AND ln_sold_to_org_id = TO_NUMBER (flv.attribute2)))
                       -- Order Type
                       AND ((flv.attribute3 IS NULL AND 1 = 1) OR (flv.attribute3 IS NOT NULL AND ln_order_type_id = TO_NUMBER (flv.attribute3)))
                       -- Order Source
                       AND ((flv.attribute4 IS NULL AND 1 = 1) OR (flv.attribute4 IS NOT NULL AND ln_order_source_id = TO_NUMBER (flv.attribute4)))
                       -- ver 1.1 Added Brand condition
                       AND ((flv.attribute6 IS NULL AND 1 = 1) OR (flv.attribute6 = 'ALL BRAND' AND 1 = 1) OR (flv.attribute6 IS NOT NULL AND lc_order_attribute5 = flv.attribute6));

                gv_debug_msg      :=
                       gv_debug_msg
                    || gv_delimiter
                    || 'Lookup row count all attr: '
                    || ln_record_count;

                IF ln_record_count = 0
                THEN
                    -------------------------
                    -- Lookup check for attr1, attr2, attr3, attr4
                    -------------------------
                    ln_record_count   := 0;

                    SELECT COUNT (*)
                      INTO ln_record_count
                      FROM fnd_lookup_values flv
                     WHERE     lookup_type = 'XXD_ORDER_BOOK_HOLD_CRITERIA'
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           -- Ordered Date
                           AND ld_ordered_date BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))
                           -- Operating Unit
                           AND ln_order_org_id = TO_NUMBER (flv.attribute1)
                           -- Customer
                           AND ((flv.attribute2 IS NULL AND 1 = 1) OR (flv.attribute2 IS NOT NULL AND ln_sold_to_org_id = TO_NUMBER (flv.attribute2)))
                           -- Order Type
                           AND ((flv.attribute3 IS NULL AND 1 = 1) OR (flv.attribute3 IS NOT NULL AND ln_order_type_id = TO_NUMBER (flv.attribute3)))
                           -- Order Source
                           AND ((flv.attribute4 IS NULL AND 1 = 1) OR (flv.attribute4 IS NOT NULL AND ln_order_source_id = TO_NUMBER (flv.attribute4)));

                    gv_debug_msg      :=
                           gv_debug_msg
                        || gv_delimiter
                        || 'Lookup row count attr1, attr2, attr3, attr4: '
                        || ln_record_count;

                    -------------------------
                    -- Lookup check for attr1, attr2, attr3
                    -------------------------
                    ln_record_count   := 0;

                    SELECT COUNT (*)
                      INTO ln_record_count
                      FROM fnd_lookup_values flv
                     WHERE     lookup_type = 'XXD_ORDER_BOOK_HOLD_CRITERIA'
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           -- Ordered Date
                           AND ld_ordered_date BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))
                           -- Operating Unit
                           AND ln_order_org_id = TO_NUMBER (flv.attribute1)
                           -- Customer
                           AND ((flv.attribute2 IS NULL AND 1 = 1) OR (flv.attribute2 IS NOT NULL AND ln_sold_to_org_id = TO_NUMBER (flv.attribute2)))
                           -- Order Type
                           AND ((flv.attribute3 IS NULL AND 1 = 1) OR (flv.attribute3 IS NOT NULL AND ln_order_type_id = TO_NUMBER (flv.attribute3)));

                    gv_debug_msg      :=
                           gv_debug_msg
                        || gv_delimiter
                        || 'Lookup row count attr1, attr2, attr3: '
                        || ln_record_count;

                    -------------------------
                    -- Lookup check for attr1, attr2
                    -------------------------
                    ln_record_count   := 0;

                    SELECT COUNT (*)
                      INTO ln_record_count
                      FROM fnd_lookup_values flv
                     WHERE     lookup_type = 'XXD_ORDER_BOOK_HOLD_CRITERIA'
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           -- Ordered Date
                           AND ld_ordered_date BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))
                           -- Operating Unit
                           AND ln_order_org_id = TO_NUMBER (flv.attribute1)
                           -- Customer
                           AND ((flv.attribute2 IS NULL AND 1 = 1) OR (flv.attribute2 IS NOT NULL AND ln_sold_to_org_id = TO_NUMBER (flv.attribute2)));

                    gv_debug_msg      :=
                           gv_debug_msg
                        || gv_delimiter
                        || 'Lookup row count attr1, attr2: '
                        || ln_record_count;
                END IF;
            END IF;

            gv_debug_msg      := SUBSTR (gv_debug_msg, 1, 2000);
            msg (gv_debug_msg);
        EXCEPTION
            WHEN OTHERS
            THEN
                gv_debug_msg   :=
                    SUBSTR (
                           gv_debug_msg
                        || gv_delimiter
                        || 'Error location: '
                        || DBMS_UTILITY.format_error_backtrace,
                        1,
                        2000);
                msg (gv_debug_msg);
                gv_debug_msg   :=
                    SUBSTR (
                           'Header ID: '
                        || ln_header_id
                        || gv_delimiter
                        || 'Error description: '
                        || SQLCODE
                        || ' '
                        || SQLERRM,
                        1,
                        2000);
                msg (gv_debug_msg);
        END;

        --End ver 1.3 changes for CCR0009995

        IF (funcmode = 'RUN')
        THEN
            IF ln_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key: ' || itemkey);
            END IF;

            oe_standard_wf.set_msg_context (actid);

            FOR hold_rec IN get_hold_c
            LOOP
                oe_msg_pub.initialize;
                ln_msg_count                         := 0;
                lc_msg_data                          := NULL;
                lc_return_status                     := NULL;
                lc_error_message                     := NULL;

                IF ln_debug_level > 0
                THEN
                    oe_debug_pub.ADD ('Hold ID: ' || hold_rec.hold_id);
                END IF;

                l_hold_source_rec.hold_id            := hold_rec.hold_id;
                l_hold_source_rec.hold_entity_code   := 'O';
                l_hold_source_rec.hold_entity_id     := ln_header_id;
                l_hold_source_rec.header_id          := ln_header_id;
                l_hold_source_rec.hold_comment       :=
                    'Hold Applied as per Lookup XXD_ORDER_BOOK_HOLD_CRITERIA';
                oe_holds_pub.apply_holds (
                    p_api_version        => 1.0,
                    p_validation_level   => fnd_api.g_valid_level_full,
                    p_hold_source_rec    => l_hold_source_rec,
                    x_msg_count          => ln_msg_count,
                    x_msg_data           => lc_msg_data,
                    x_return_status      => lc_return_status);

                IF ln_debug_level > 0
                THEN
                    oe_debug_pub.ADD ('Hold Status: ' || lc_return_status);
                END IF;

                IF lc_return_status = 'S'
                THEN
                    IF ln_debug_level > 0
                    THEN
                        oe_debug_pub.ADD ('Hold Applied');
                    END IF;
                ELSE
                    -- If any error, skip and no action is needed per requirement
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                        , p_msg_index_out => ln_msg_index_out);
                        lc_error_message   := lc_error_message || lc_msg_data;
                    END LOOP;

                    IF ln_debug_level > 0
                    THEN
                        oe_debug_pub.ADD ('Apply Hold Failed');
                        oe_debug_pub.ADD (lc_error_message);
                    END IF;
                END IF;

                -- Start changes for CCR0009975
                gv_debug_msg                         :=
                       'Header ID after API: '
                    || ln_header_id
                    || gv_delimiter
                    || 'Hold ID: '
                    || hold_rec.hold_id
                    || gv_delimiter
                    || 'API Status: '
                    || lc_return_status
                    || gv_delimiter
                    || 'API Err Msg: '
                    || SUBSTR (lc_error_message, 1, 200)
                    || gv_delimiter;
                msg (gv_debug_msg);
            -- End changes for CCR0009975
            END LOOP;
        END IF;

        resultout      := '';

        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --Start ver 1.3
            gv_debug_msg   :=
                SUBSTR (
                       'Header ID: '
                    || ln_header_id
                    || gv_delimiter
                    || 'Prc apply_hold error location: '
                    || DBMS_UTILITY.format_error_backtrace,
                    1,
                    2000);
            msg (gv_debug_msg);
            gv_debug_msg   :=
                SUBSTR (
                       'Header ID: '
                    || ln_header_id
                    || gv_delimiter
                    || 'Prc apply_hold error description: '
                    || SQLCODE
                    || ' '
                    || SQLERRM,
                    1,
                    2000);
            msg (gv_debug_msg);
            --End ver 1.3

            wf_core.CONTEXT ('XXD_ONT_OEOH_WF_PKG.APPLY_HOLD', 'XXD_ONT_OEOH_WF_PKG.APPLY_HOLD', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END apply_hold;
END xxd_ont_oeoh_wf_pkg;
/
