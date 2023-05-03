--
-- XXD_PO_PRICE_RULE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_PRICE_RULE_PKG"
AS
    /****************************************************************************************
    * Package      : XXDO_PO_PRICE_RULE_PKG
    * Design       : This package is used to update and insert Japan TQ price rules from OA Page
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 09-Dec-2020  1.0        Balavenu Rao      Initial version
    ******************************************************************************************/

    PROCEDURE xxd_po_price_rule_prc (p_po_price_rule_tbl xxdo.xxd_po_price_rule_tbl_type, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        ln_error_num           NUMBER;
        lv_error_msg           VARCHAR2 (4000) := NULL;
        lv_error_stat          VARCHAR2 (4) := 'S';
        lv_error_code          VARCHAR2 (4000) := NULL;
        lv_price_rule_name     VARCHAR2 (200) := NULL;
        ln_user_id             NUMBER := fnd_global.user_id;
        ld_cur_date            DATE := SYSDATE;
        ln_last_update_login   NUMBER := fnd_global.login_id;
        ln_count               NUMBER;
        lv_list_name           qp_list_headers.name%TYPE;
        lv_price_list          xxdo_po_price_rule.price_source%TYPE;
        ln_list_header_id      qp_list_headers.list_header_id%TYPE;
        v_po_price_rule_tbl    xxdo.xxd_po_price_rule_tbl_type
                                   := xxdo.xxd_po_price_rule_tbl_type ();

        TYPE xxdo_po_price_rule_ins_type
            IS TABLE OF xxdo_po_price_rule%ROWTYPE;

        v_xxdo_inst_type       xxdo_po_price_rule_ins_type
                                   := xxdo_po_price_rule_ins_type ();

        TYPE xxdo_po_price_rule_upd_type
            IS TABLE OF xxdo_po_price_rule%ROWTYPE;

        v_xxdo_upd_type        xxdo_po_price_rule_upd_type
                                   := xxdo_po_price_rule_upd_type ();

        TYPE xxdo_po_price_rule_bkp_type
            IS TABLE OF xxdo_po_price_rule%ROWTYPE;

        v_xxdo_bkp_type        xxdo_po_price_rule_bkp_type
                                   := xxdo_po_price_rule_bkp_type ();

        TYPE xxd_po_price_rule_arch_type
            IS TABLE OF xxd_po_price_rule_archive_t%ROWTYPE;

        v_xxdo_arch_type       xxd_po_price_rule_arch_type
                                   := xxd_po_price_rule_arch_type ();

        TYPE xxd_po_price_rule_vld_type
            IS TABLE OF xxdo_po_price_rule%ROWTYPE;

        v_xxdo_vld_type        xxd_po_price_rule_vld_type
                                   := xxd_po_price_rule_vld_type ();
    BEGIN
        v_xxdo_inst_type.DELETE;
        v_xxdo_upd_type.DELETE;
        v_xxdo_arch_type.DELETE;
        v_po_price_rule_tbl.DELETE;
        v_po_price_rule_tbl   := p_po_price_rule_tbl;

        BEGIN
            SELECT meaning, description
              INTO lv_list_name, lv_price_list
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_PO_TQ_PRICE_RULE_UTILS'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y'
                   AND language = USERENV ('LANG');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || ' Error While collecting The Constant Values '
                        || SQLERRM,
                        1,
                        4000);
        END;

        BEGIN
            SELECT list_header_id
              INTO ln_list_header_id
              FROM qp_list_headers
             WHERE name = lv_list_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || ' Error While Deriving The Constant Values '
                        || SQLERRM,
                        1,
                        4000);
        END;

        BEGIN
            SELECT *
              BULK COLLECT INTO v_xxdo_vld_type
              FROM xxdo_po_price_rule
             WHERE po_price_rule IN
                       (SELECT po_price_rule
                          FROM TABLE (p_po_price_rule_tbl)
                         WHERE NVL (attribute1, 'XXX') <> 'INSERT');

            IF (v_xxdo_vld_type.COUNT > 0)
            THEN
                FOR i IN v_xxdo_vld_type.FIRST .. v_xxdo_vld_type.LAST
                LOOP
                    FOR j IN v_po_price_rule_tbl.FIRST ..
                             v_po_price_rule_tbl.LAST
                    LOOP
                        IF (v_xxdo_vld_type (i).po_price_rule = v_po_price_rule_tbl (j).po_price_rule AND v_xxdo_vld_type (i).rate_multiplier = v_po_price_rule_tbl (j).rate_multiplier AND v_xxdo_vld_type (i).rate_amount = v_po_price_rule_tbl (j).rate_amount)
                        THEN
                            lv_error_msg                         :=
                                SUBSTR (
                                       lv_error_msg
                                    || ' No changes to process for the selected record : '
                                    || v_po_price_rule_tbl (j).po_price_rule
                                    || ' #',
                                    1,
                                    4000);

                            v_po_price_rule_tbl (j).attribute1   := 'ERROR';
                        END IF;
                    END LOOP;
                END LOOP;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || ' Validating Records: '
                        || SQLERRM
                        || ' #',
                        1,
                        4000);
        END;

        BEGIN
            FOR i IN v_po_price_rule_tbl.FIRST .. v_po_price_rule_tbl.LAST
            LOOP
                IF (NVL (v_po_price_rule_tbl (i).attribute1, 'XXX') != 'ERROR')
                THEN
                    IF (v_po_price_rule_tbl (i).po_price_rule IS NULL AND v_po_price_rule_tbl (i).attribute1 = 'INSERT')
                    THEN
                        lv_price_rule_name   :=
                            get_price_rule_name (
                                v_po_price_rule_tbl (i).vendor_id,
                                v_po_price_rule_tbl (i).brand,
                                v_po_price_rule_tbl (i).tq_category);

                        IF (lv_price_rule_name = 'E')
                        THEN
                            lv_error_stat   := 'E';
                            lv_error_msg    :=
                                SUBSTR (
                                       lv_error_msg
                                    || ' Price Rule Name is not defined for Vendor: '
                                    || v_po_price_rule_tbl (i).vendor_name
                                    || ' #',
                                    1,
                                    4000);
                        ELSE
                            v_po_price_rule_tbl (i).po_price_rule   :=
                                lv_price_rule_name;
                        END IF;
                    END IF;

                    IF (v_po_price_rule_tbl (i).po_price_rule IS NOT NULL AND v_po_price_rule_tbl (i).attribute1 = 'INSERT')
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO ln_count
                              FROM xxdo_po_price_rule
                             WHERE po_price_rule =
                                   v_po_price_rule_tbl (i).po_price_rule;

                            IF (ln_count > 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price Rule is Already Existing '
                                        || v_po_price_rule_tbl (i).po_price_rule
                                        || ' #',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    END IF;

                    IF (v_po_price_rule_tbl (i).rate_multiplier IS NULL AND v_po_price_rule_tbl (i).rate_amount IS NULL)
                    THEN
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                   lv_error_msg
                                || ' Price Rule '
                                || v_po_price_rule_tbl (i).po_price_rule
                                || ' Either Rate Multiplier or Rate Amount value Must Be Entered #',
                                1,
                                4000);
                    END IF;

                    IF (NVL (v_po_price_rule_tbl (i).rate_multiplier, 0) < 0)
                    THEN
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                   lv_error_msg
                                || ' Price Rule '
                                || v_po_price_rule_tbl (i).po_price_rule
                                || ' Rate Multiplier value should not be Negative #',
                                1,
                                4000);
                    END IF;

                    IF (NVL (v_po_price_rule_tbl (i).rate_amount, 0) < 0)
                    THEN
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                   lv_error_msg
                                || ' Price Rule '
                                || v_po_price_rule_tbl (i).po_price_rule
                                || ' Rate Amount value should not be Negative #',
                                1,
                                4000);
                    END IF;

                    IF (LENGTH (SUBSTR (TO_CHAR (v_po_price_rule_tbl (i).rate_multiplier), INSTR (TO_CHAR (v_po_price_rule_tbl (i).rate_multiplier), '.') + 1, 6)) > 5)
                    THEN
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                   lv_error_msg
                                || ' Price Rule '
                                || v_po_price_rule_tbl (i).po_price_rule
                                || ' Rate Multiplier Exceeded 5 decimals, Rate Multiplier accepts  maximum of 5 decimals  #',
                                1,
                                4000);
                    END IF;

                    IF (LENGTH (SUBSTR (TO_CHAR (v_po_price_rule_tbl (i).rate_amount), INSTR (TO_CHAR (v_po_price_rule_tbl (i).rate_amount), '.') + 1, 6)) > 5)
                    THEN
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                   lv_error_msg
                                || ' Price Rule '
                                || v_po_price_rule_tbl (i).po_price_rule
                                || ' Rate Amount Exceeded 5 decimals,Rate Amount accepts  maximum of 5 decimals #',
                                1,
                                4000);
                    END IF;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || 'Error While Validating'
                        || SQLERRM
                        || ' #',
                        1,
                        4000);
        END;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_error_msg;
        ELSE
            BEGIN
                FOR i IN v_po_price_rule_tbl.FIRST ..
                         v_po_price_rule_tbl.LAST
                LOOP
                    IF (NVL (v_po_price_rule_tbl (i).attribute1, 'XXX') != 'ERROR')
                    THEN
                        IF (v_po_price_rule_tbl (i).attribute1 = 'INSERT')
                        THEN
                            v_xxdo_inst_type.EXTEND;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).po_price_rule   :=
                                v_po_price_rule_tbl (i).po_price_rule;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).description   :=
                                v_po_price_rule_tbl (i).description;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).price_source   :=
                                lv_price_list; --v_po_price_rule_tbl(i).price_source;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).price_source_id   :=
                                ln_list_header_id; --v_po_price_rule_tbl(i).price_source_id;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).rate_multiplier   :=
                                v_po_price_rule_tbl (i).rate_multiplier;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).rate_amount   :=
                                v_po_price_rule_tbl (i).rate_amount;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).enabled_flag   :=
                                v_po_price_rule_tbl (i).enabled_flag;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).vendor_id   :=
                                v_po_price_rule_tbl (i).vendor_id;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).vendor_name   :=
                                v_po_price_rule_tbl (i).vendor_name;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).created_by   :=
                                ln_user_id;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).creation_date   :=
                                ld_cur_date;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).last_updated_by   :=
                                ln_user_id;
                            v_xxdo_inst_type (v_xxdo_inst_type.LAST).last_update_date   :=
                                ld_cur_date;
                            v_xxdo_arch_type.EXTEND;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule_arc_id   :=
                                xxd_po_price_rule_archive_s.NEXTVAL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule   :=
                                v_po_price_rule_tbl (i).po_price_rule;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).description   :=
                                v_po_price_rule_tbl (i).description;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).price_source   :=
                                lv_price_list; --v_po_price_rule_tbl(i).price_source;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).price_source_id   :=
                                ln_list_header_id; --v_po_price_rule_tbl(i).price_source_id;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).rate_multiplier   :=
                                v_po_price_rule_tbl (i).rate_multiplier;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).rate_amount   :=
                                v_po_price_rule_tbl (i).rate_amount;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).old_rate_multiplier   :=
                                v_po_price_rule_tbl (i).attribute11;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).old_rate_amount   :=
                                v_po_price_rule_tbl (i).attribute12;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).enabled_flag   :=
                                v_po_price_rule_tbl (i).enabled_flag;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).vendor_id   :=
                                v_po_price_rule_tbl (i).vendor_id;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).vendor_name   :=
                                v_po_price_rule_tbl (i).vendor_name;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).created_by   :=
                                ln_user_id;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).creation_date   :=
                                ld_cur_date;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_updated_by   :=
                                ln_user_id;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_date   :=
                                ld_cur_date;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_login   :=
                                ln_last_update_login;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute1   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute2   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute3   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute4   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute5   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute6   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute7   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute8   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute9   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute10   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute11   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute12   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute13   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute14   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute15   :=
                                NULL;
                        ELSE
                            v_xxdo_upd_type.EXTEND;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).po_price_rule   :=
                                v_po_price_rule_tbl (i).po_price_rule;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).description   :=
                                v_po_price_rule_tbl (i).description;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).price_source   :=
                                lv_price_list;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).price_source_id   :=
                                ln_list_header_id;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).rate_multiplier   :=
                                v_po_price_rule_tbl (i).rate_multiplier;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).rate_amount   :=
                                v_po_price_rule_tbl (i).rate_amount;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).enabled_flag   :=
                                v_po_price_rule_tbl (i).enabled_flag;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).vendor_id   :=
                                v_po_price_rule_tbl (i).vendor_id;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).vendor_name   :=
                                v_po_price_rule_tbl (i).vendor_name;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).last_updated_by   :=
                                ln_user_id;
                            v_xxdo_upd_type (v_xxdo_upd_type.LAST).last_update_date   :=
                                ld_cur_date;
                            v_xxdo_arch_type.EXTEND;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule_arc_id   :=
                                xxd_po_price_rule_archive_s.NEXTVAL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule   :=
                                v_po_price_rule_tbl (i).po_price_rule;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).description   :=
                                v_po_price_rule_tbl (i).description;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).price_source   :=
                                lv_price_list;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).price_source_id   :=
                                ln_list_header_id;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).rate_multiplier   :=
                                v_po_price_rule_tbl (i).rate_multiplier;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).rate_amount   :=
                                v_po_price_rule_tbl (i).rate_amount;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).old_rate_multiplier   :=
                                v_po_price_rule_tbl (i).attribute11;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).old_rate_amount   :=
                                v_po_price_rule_tbl (i).attribute12;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).enabled_flag   :=
                                v_po_price_rule_tbl (i).enabled_flag;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).vendor_id   :=
                                v_po_price_rule_tbl (i).vendor_id;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).vendor_name   :=
                                v_po_price_rule_tbl (i).vendor_name;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).created_by   :=
                                ln_user_id;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).creation_date   :=
                                ld_cur_date;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_updated_by   :=
                                ln_user_id;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_date   :=
                                ld_cur_date;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_login   :=
                                ln_last_update_login;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute1   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute2   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute3   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute4   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute5   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute6   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute7   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute8   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute9   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute10   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute11   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute12   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute13   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute14   :=
                                NULL;
                            v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute15   :=
                                NULL;
                        END IF;
                    END IF;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';
                    lv_error_msg    :=
                        SUBSTR (
                               lv_error_msg
                            || 'Error While Setting RectType Values'
                            || SQLERRM
                            || ' #',
                            1,
                            4000);
            END;

            --User Insert New Record

            IF (v_xxdo_inst_type.COUNT > 0)
            THEN
                BEGIN
                    FORALL i
                        IN v_xxdo_inst_type.FIRST .. v_xxdo_inst_type.LAST
                      SAVE EXCEPTIONS
                        INSERT INTO xxdo_po_price_rule
                             VALUES v_xxdo_inst_type (i);
                -- lv_error_stat := 'S';

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_stat   := 'E';

                        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            ln_error_num   :=
                                SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                            lv_error_code   :=
                                SQLERRM (
                                    -1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                            lv_error_msg   :=
                                SUBSTR (
                                    (lv_error_msg || ' Error Insert in price rule ' || v_xxdo_inst_type (ln_error_num).po_price_rule || lv_error_code),
                                    1,
                                    4000);
                        END LOOP;
                END;
            END IF;

            --User Updates Existing Records

            IF (v_xxdo_upd_type.COUNT > 0)
            THEN
                BEGIN
                    FORALL i IN v_xxdo_upd_type.FIRST .. v_xxdo_upd_type.LAST
                      SAVE EXCEPTIONS
                        UPDATE xxdo_po_price_rule
                           SET rate_multiplier = v_xxdo_upd_type (i).rate_multiplier, rate_amount = v_xxdo_upd_type (i).rate_amount, last_update_date = v_xxdo_upd_type (i).last_update_date,
                               last_updated_by = v_xxdo_upd_type (i).last_updated_by
                         WHERE po_price_rule =
                               v_xxdo_upd_type (i).po_price_rule;
                --lv_error_stat := 'S';

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_stat   := 'E';

                        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            ln_error_num   :=
                                SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                            lv_error_code   :=
                                SQLERRM (
                                    -1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                            lv_error_msg   :=
                                SUBSTR (
                                    (lv_error_msg || ' Error Update in price rule ' || v_xxdo_upd_type (ln_error_num).po_price_rule || lv_error_code),
                                    1,
                                    4000);
                        END LOOP;
                END;
            END IF;

            --Archive the updated Data

            IF (v_xxdo_arch_type.COUNT > 0)
            THEN
                BEGIN
                    FORALL i
                        IN v_xxdo_arch_type.FIRST .. v_xxdo_arch_type.LAST
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_po_price_rule_archive_t
                             VALUES v_xxdo_arch_type (i);
                --lv_error_stat := 'S';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_stat   := 'E';

                        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            ln_error_num   :=
                                SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                            lv_error_code   :=
                                SQLERRM (
                                    -1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                            lv_error_msg   :=
                                SUBSTR (
                                    (lv_error_msg || ' Error in Archive price rule ' || v_xxdo_arch_type (ln_error_num).po_price_rule || lv_error_code),
                                    1,
                                    4000);
                        END LOOP;
                END;
            END IF;

            IF (lv_error_stat = 'E')
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    :=
                    SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
                ROLLBACK;
            ELSE
                pv_error_stat   := 'S';
                pv_error_msg    := lv_error_msg || ' Successfully Updated';
                COMMIT;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Error while updating :' || SQLERRM;
            ROLLBACK;
    END xxd_po_price_rule_prc;

    PROCEDURE xxd_po_price_rule_asigmnts_prc (p_po_price_rule_asmnt_tbl xxdo.xxd_po_pric_rul_asmnt_tbl_type, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    AS
        ln_error_num           NUMBER;
        lv_error_msg           VARCHAR2 (4000) := NULL;
        lv_error_stat          VARCHAR2 (4) := 'S';
        lv_error_code          VARCHAR2 (4000) := NULL;
        ln_count               NUMBER;
        ln_count_org           NUMBER;
        l_count_brnd           NUMBER;
        l_count_sts            NUMBER;
        l_count_cust           NUMBER;
        l_count_enb            NUMBER;
        ln_user_id             NUMBER := fnd_global.user_id;
        ld_cur_date            DATE := SYSDATE;
        ln_last_update_login   NUMBER := fnd_global.login_id;
        lv_po_price_rule_cnt   NUMBER;
        lv_org_code            org_organization_definitions.organization_code%TYPE;
        ln_org_id              org_organization_definitions.organization_id%TYPE;
        lv_org_name            org_organization_definitions.organization_name%TYPE;
        lv_price_rule_name     xxdo_po_price_rule_assignment.po_price_rule%TYPE;

        TYPE po_price_rule_asigmnt_ins_type
            IS TABLE OF xxdo_po_price_rule_assignment%ROWTYPE;

        v_xxdo_inst_type       po_price_rule_asigmnt_ins_type
                                   := po_price_rule_asigmnt_ins_type ();

        TYPE xxd_po_pric_rul_asmnt_rec_typ IS RECORD
        (
            target_item_org_id          NUMBER,
            target_item_organization    VARCHAR2 (50 BYTE),
            po_price_rule               VARCHAR2 (30 BYTE),
            item_segment1               VARCHAR2 (40 BYTE),
            item_segment2               VARCHAR2 (40 BYTE),
            new_po_price_rule           VARCHAR2 (30 BYTE),
            new_item_segment1           VARCHAR2 (40 BYTE),
            new_item_segment2           VARCHAR2 (40 BYTE),
            item_segment3               VARCHAR2 (40 BYTE),
            active_start_date           DATE,
            active_end_date             DATE,
            comments                    VARCHAR2 (180 BYTE),
            created_by                  NUMBER,
            creation_date               DATE,
            last_updated_by             NUMBER,
            last_update_date            DATE,
            attribute1                  VARCHAR2 (240 BYTE),
            attribute2                  VARCHAR2 (240 BYTE),
            attribute3                  VARCHAR2 (240 BYTE),
            attribute4                  VARCHAR2 (240 BYTE),
            attribute5                  VARCHAR2 (240 BYTE),
            attribute6                  VARCHAR2 (240 BYTE),
            attribute7                  VARCHAR2 (240 BYTE),
            attribute8                  VARCHAR2 (240 BYTE),
            attribute9                  VARCHAR2 (240 BYTE),
            attribute10                 NUMBER,
            attribute11                 NUMBER,
            attribute12                 NUMBER,
            attribute13                 NUMBER,
            attribute14                 NUMBER,
            attribute15                 NUMBER
        );

        TYPE po_price_rule_asigmnt_upd_type
            IS TABLE OF xxd_po_pric_rul_asmnt_rec_typ;

        v_xxdo_upd_type        po_price_rule_asigmnt_upd_type
                                   := po_price_rule_asigmnt_upd_type ();

        TYPE xxd_po_price_rul_asgn_bkp_type
            IS TABLE OF xxdo_po_price_rule_assignment%ROWTYPE;

        v_xxdo_bkp_type        xxd_po_price_rul_asgn_bkp_type
                                   := xxd_po_price_rul_asgn_bkp_type ();

        TYPE xxd_po_price_rul_asgn_arc_type
            IS TABLE OF xxd_po_price_rule_asgn_arch_t%ROWTYPE;

        v_xxdo_arch_type       xxd_po_price_rul_asgn_arc_type
                                   := xxd_po_price_rul_asgn_arc_type ();
    BEGIN
        v_xxdo_inst_type.DELETE;
        v_xxdo_upd_type.DELETE;
        v_xxdo_arch_type.DELETE;

        BEGIN
            SELECT lookup_code
              INTO lv_org_code
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_PO_TQ_PRICE_RULE_UTILS'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y'
                   AND language = USERENV ('LANG');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || ' Error While collecting The Constant Values '
                        || SQLERRM,
                        1,
                        4000);
        END;

        BEGIN
            SELECT organization_id, organization_name
              INTO ln_org_id, lv_org_name
              FROM org_organization_definitions
             WHERE organization_code = lv_org_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || ' Error While Deriving The Constant Values '
                        || SQLERRM,
                        1,
                        4000);
        END;

        BEGIN
            IF (lv_error_stat <> 'E')
            THEN
                FOR i IN p_po_price_rule_asmnt_tbl.FIRST ..
                         p_po_price_rule_asmnt_tbl.LAST
                LOOP
                    IF (p_po_price_rule_asmnt_tbl (i).new_po_price_rule IS NULL AND NVL (p_po_price_rule_asmnt_tbl (i).attribute1, 'XXX') <> 'INSERT')
                    THEN
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                   lv_error_msg
                                || ' Price Rule: '
                                || p_po_price_rule_asmnt_tbl (i).po_price_rule
                                || ' Style: '
                                || p_po_price_rule_asmnt_tbl (i).item_segment1
                                || ' Color: '
                                || p_po_price_rule_asmnt_tbl (i).item_segment2
                                || ' Enter New Price Rule Value #',
                                1,
                                4000);
                    END IF;

                    IF (p_po_price_rule_asmnt_tbl (i).new_po_price_rule IS NOT NULL OR p_po_price_rule_asmnt_tbl (i).po_price_rule IS NOT NULL)
                    THEN
                        --      lv_error_stat := 'S';
                        SELECT DECODE (NVL (p_po_price_rule_asmnt_tbl (i).attribute1, 'XXX'), 'INSERT', p_po_price_rule_asmnt_tbl (i).po_price_rule, p_po_price_rule_asmnt_tbl (i).new_po_price_rule)
                          INTO lv_price_rule_name
                          FROM DUAL;

                        BEGIN
                            SELECT COUNT (1)
                              INTO ln_count
                              FROM xxdo_po_price_rule_assignment
                             WHERE     po_price_rule =
                                       DECODE (
                                           NVL (
                                               p_po_price_rule_asmnt_tbl (i).attribute1,
                                               'XXX'),
                                           'INSERT', p_po_price_rule_asmnt_tbl (
                                                         i).po_price_rule,
                                           p_po_price_rule_asmnt_tbl (i).new_po_price_rule)
                                   AND item_segment1 =
                                       p_po_price_rule_asmnt_tbl (i).item_segment1
                                   AND item_segment2 =
                                       p_po_price_rule_asmnt_tbl (i).item_segment2;

                            IF (ln_count > 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price Rule: '
                                        || lv_price_rule_name
                                        || ' Style: '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' Color: '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' Record Already Existing #',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_stat   := 'E';
                        END;
                    END IF;

                    IF (UPPER (p_po_price_rule_asmnt_tbl (i).attribute1) = 'INSERT')
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO lv_po_price_rule_cnt
                              FROM xxdo_po_price_rule_assignment
                             WHERE     REGEXP_SUBSTR (po_price_rule, '[^-]+', 1
                                                      , 1) =
                                       REGEXP_SUBSTR (p_po_price_rule_asmnt_tbl (i).po_price_rule, '[^-]+', 1
                                                      , 1)
                                   AND item_segment1 =
                                       p_po_price_rule_asmnt_tbl (i).item_segment1
                                   AND item_segment2 =
                                       p_po_price_rule_asmnt_tbl (i).item_segment2;

                            IF (lv_po_price_rule_cnt > 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Vendor '
                                        || p_po_price_rule_asmnt_tbl (i).attribute2
                                        || ' Style  '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' and Color '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' combination already exists for : '
                                        || 'Price Rule '
                                        || lv_price_rule_name
                                        || ' #',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Vendor '
                                        || p_po_price_rule_asmnt_tbl (i).attribute2
                                        || ' Style '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' and Color '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' combination already exists for : '
                                        || 'Price Rule '
                                        || lv_price_rule_name
                                        || ' #',
                                        1,
                                        4000);
                        END;
                    END IF;

                    IF (p_po_price_rule_asmnt_tbl (i).item_segment1 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).item_segment2 IS NOT NULL)
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO ln_count_org
                              FROM xxd_common_items_v xciv, org_organization_definitions ood
                             WHERE     1 = 1
                                   AND xciv.organization_id =
                                       ood.organization_id
                                   AND xciv.style_number =
                                       p_po_price_rule_asmnt_tbl (i).item_segment1
                                   AND xciv.color_code =
                                       p_po_price_rule_asmnt_tbl (i).item_segment2
                                   AND ood.organization_code = lv_org_code;

                            IF (ln_count_org = 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price Rule,Style Color: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' : Style Color does not exist or not assigned to JP5 #',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price Rule,Style Color: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' : Style Color does not exist or not assigned to JP5 #',
                                        1,
                                        4000);
                        END;
                    END IF;

                    IF (p_po_price_rule_asmnt_tbl (i).item_segment1 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).item_segment2 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).comments IS NOT NULL)
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO l_count_brnd
                              FROM xxd_common_items_v xciv
                             WHERE     1 = 1
                                   AND xciv.style_number =
                                       p_po_price_rule_asmnt_tbl (i).item_segment1
                                   AND xciv.color_code =
                                       p_po_price_rule_asmnt_tbl (i).item_segment2
                                   AND xciv.organization_id = ln_org_id
                                   AND xciv.brand =
                                       p_po_price_rule_asmnt_tbl (i).comments;

                            IF (l_count_brnd = 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price RuleStyle Color,Brand: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).comments
                                        || '	Style Color should be of the brand in the price rule #',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price RuleStyle Color,Brand: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).comments
                                        || '	Style Color should be of the brand in the price rule #',
                                        1,
                                        4000);
                        END;
                    END IF;

                    IF (p_po_price_rule_asmnt_tbl (i).item_segment1 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).item_segment2 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).comments IS NOT NULL)
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO l_count_sts
                              FROM xxd_common_items_v xciv
                             WHERE     1 = 1
                                   AND xciv.style_number =
                                       p_po_price_rule_asmnt_tbl (i).item_segment1
                                   AND xciv.color_code =
                                       p_po_price_rule_asmnt_tbl (i).item_segment2
                                   AND xciv.brand =
                                       p_po_price_rule_asmnt_tbl (i).comments
                                   AND xciv.organization_id = ln_org_id
                                   AND (xciv.inventory_item_status_code IN ('Inactive') OR xciv.item_type = 'GENERIC');

                            IF (l_count_sts > 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price RuleStyle Color,Brand: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).comments
                                        || '	Style Color is not Active #',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price RuleStyle Color,Brand: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).comments
                                        || '	Style Color is not Active #',
                                        1,
                                        4000);
                        END;
                    END IF;

                    IF (p_po_price_rule_asmnt_tbl (i).item_segment1 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).item_segment2 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).comments IS NOT NULL)
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO l_count_cust
                              FROM xxd_common_items_v xciv
                             WHERE     xciv.style_number =
                                       p_po_price_rule_asmnt_tbl (i).item_segment1
                                   AND xciv.color_code =
                                       p_po_price_rule_asmnt_tbl (i).item_segment2
                                   AND xciv.brand =
                                       p_po_price_rule_asmnt_tbl (i).comments
                                   AND xciv.organization_id = ln_org_id
                                   AND NVL (xciv.customer_order_enabled_flag,
                                            'N') =
                                       'Y';

                            IF (l_count_cust = 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price RuleStyle Color,Brand: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).comments
                                        || '	Style Color is not Customer Order Enabled #',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price RuleStyle Color,Brand: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).comments
                                        || '	Style Color is not Customer Order Enabled #',
                                        1,
                                        4000);
                        END;
                    END IF;

                    IF (p_po_price_rule_asmnt_tbl (i).item_segment1 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).item_segment2 IS NOT NULL AND p_po_price_rule_asmnt_tbl (i).comments IS NOT NULL)
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO l_count_enb
                              FROM xxd_common_items_v xciv
                             WHERE     1 = 1
                                   AND xciv.style_number =
                                       p_po_price_rule_asmnt_tbl (i).item_segment1
                                   AND xciv.color_code =
                                       p_po_price_rule_asmnt_tbl (i).item_segment2
                                   AND xciv.brand =
                                       p_po_price_rule_asmnt_tbl (i).comments
                                   AND xciv.organization_id = ln_org_id
                                   AND NVL (xciv.enabled_flag, 'N') <> 'Y';

                            IF (l_count_enb > 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price RuleStyle Color,Brand: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).comments
                                        || '	Style Color is not Enabled #',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Price RuleStyle Color,Brand: '
                                        || lv_price_rule_name
                                        || ','
                                        || p_po_price_rule_asmnt_tbl (i).item_segment1
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).item_segment2
                                        || ' '
                                        || p_po_price_rule_asmnt_tbl (i).comments
                                        || '	Style Color is not Enabled #',
                                        1,
                                        4000);
                        END;
                    END IF;
                END LOOP;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || 'Error While VALIDATION'
                        || SQLERRM
                        || ' #',
                        1,
                        4000);
        END;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := lv_error_msg;
        ELSE
            BEGIN
                FOR i IN p_po_price_rule_asmnt_tbl.FIRST ..
                         p_po_price_rule_asmnt_tbl.LAST
                LOOP
                    IF (p_po_price_rule_asmnt_tbl (i).attribute1 = 'INSERT')
                    THEN
                        v_xxdo_inst_type.EXTEND;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).po_price_rule   :=
                            p_po_price_rule_asmnt_tbl (i).po_price_rule;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).item_segment1   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment1;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).item_segment2   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment2;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).item_segment3   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment3;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).active_start_date   :=
                            p_po_price_rule_asmnt_tbl (i).active_start_date;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).active_end_date   :=
                            p_po_price_rule_asmnt_tbl (i).active_end_date;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).comments   :=
                            p_po_price_rule_asmnt_tbl (i).comments;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).created_by   :=
                            fnd_profile.VALUE ('USER_ID');
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).creation_date   :=
                            SYSDATE;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).last_updated_by   :=
                            fnd_profile.VALUE ('USER_ID');
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).last_update_date   :=
                            SYSDATE;
                        v_xxdo_arch_type.EXTEND;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_prc_rul_asgn_arc_id   :=
                            xxd_po_price_rule_asgn_arch_s.NEXTVAL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule   :=
                            p_po_price_rule_asmnt_tbl (i).po_price_rule;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment1   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment1;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment2   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment2;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment3   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment3;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).new_po_price_rule   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_start_date   :=
                            p_po_price_rule_asmnt_tbl (i).active_start_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_end_date   :=
                            p_po_price_rule_asmnt_tbl (i).active_end_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).comments   :=
                            p_po_price_rule_asmnt_tbl (i).comments;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).created_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).creation_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_updated_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_login   :=
                            ln_last_update_login;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute1   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute2   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute4   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute5   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute6   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute7   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute8   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute9   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute10   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute11   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute12   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute13   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute14   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute15   :=
                            NULL;
                    ELSE
                        v_xxdo_upd_type.EXTEND;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).po_price_rule   :=
                            p_po_price_rule_asmnt_tbl (i).po_price_rule;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).item_segment1   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment1;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).item_segment2   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment2;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).new_po_price_rule   :=
                            p_po_price_rule_asmnt_tbl (i).new_po_price_rule;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).new_item_segment1   :=
                            p_po_price_rule_asmnt_tbl (i).new_item_segment1;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).new_item_segment2   :=
                            p_po_price_rule_asmnt_tbl (i).new_item_segment2;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).item_segment3   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment3;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).active_start_date   :=
                            p_po_price_rule_asmnt_tbl (i).active_start_date;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).active_end_date   :=
                            p_po_price_rule_asmnt_tbl (i).active_end_date;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).comments   :=
                            p_po_price_rule_asmnt_tbl (i).comments;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).last_updated_by   :=
                            fnd_profile.VALUE ('USER_ID');
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).last_update_date   :=
                            SYSDATE;
                        v_xxdo_arch_type.EXTEND;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_prc_rul_asgn_arc_id   :=
                            xxd_po_price_rule_asgn_arch_s.NEXTVAL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule   :=
                            p_po_price_rule_asmnt_tbl (i).po_price_rule;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment1   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment1;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment2   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment2;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment3   :=
                            p_po_price_rule_asmnt_tbl (i).item_segment3;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).new_po_price_rule   :=
                            p_po_price_rule_asmnt_tbl (i).new_po_price_rule;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_start_date   :=
                            p_po_price_rule_asmnt_tbl (i).active_start_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_end_date   :=
                            p_po_price_rule_asmnt_tbl (i).active_end_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).comments   :=
                            p_po_price_rule_asmnt_tbl (i).comments;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).created_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).creation_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_updated_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_login   :=
                            ln_last_update_login;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute1   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute2   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute4   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute5   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute6   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute7   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute8   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute9   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute10   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute11   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute12   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute13   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute14   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute15   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_id   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_name   :=
                            NULL;
                    END IF;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';
                    lv_error_msg    :=
                           lv_error_msg
                        || ' Assigment rectype values #'
                        || SQLERRM;
            END;

            IF (lv_error_stat = 'S')
            THEN
                IF (v_xxdo_inst_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i
                            IN v_xxdo_inst_type.FIRST ..
                               v_xxdo_inst_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxdo_po_price_rule_assignment
                                 VALUES v_xxdo_inst_type (i);
                    --  lv_error_stat := 'S';

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_stat   := 'E';

                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error Insert in price rule Assignment' || v_xxdo_inst_type (ln_error_num).po_price_rule || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                IF (v_xxdo_upd_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i
                            IN v_xxdo_upd_type.FIRST .. v_xxdo_upd_type.LAST
                          SAVE EXCEPTIONS
                            UPDATE xxdo_po_price_rule_assignment
                               SET po_price_rule = v_xxdo_upd_type (i).new_po_price_rule, comments = v_xxdo_upd_type (i).comments, last_update_date = v_xxdo_upd_type (i).last_update_date,
                                   last_updated_by = v_xxdo_upd_type (i).last_updated_by
                             WHERE     po_price_rule =
                                       v_xxdo_upd_type (i).po_price_rule
                                   AND item_segment1 =
                                       v_xxdo_upd_type (i).item_segment1
                                   AND item_segment2 =
                                       v_xxdo_upd_type (i).item_segment2;
                    -- lv_error_stat := 'S';
                    --                    lv_error_msg   :=v_xxdo_upd_type.count;

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_stat   := 'E';

                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error Update in price rule Assignment' || v_xxdo_upd_type (ln_error_num).new_po_price_rule || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                IF (v_xxdo_arch_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i
                            IN v_xxdo_arch_type.FIRST ..
                               v_xxdo_arch_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxd_po_price_rule_asgn_arch_t
                                 VALUES v_xxdo_arch_type (i);
                    -- lv_error_stat := 'S';

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_stat   := 'E';

                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error in Archive price rule Assignment ' || v_xxdo_arch_type (ln_error_num).po_price_rule || ' ' || v_xxdo_arch_type.COUNT || ' ' || v_xxdo_arch_type (ln_error_num).po_prc_rul_asgn_arc_id || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;
            END IF;

            IF (lv_error_stat = 'E')
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    :=
                    SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
                ROLLBACK;
            ELSE
                pv_error_stat   := 'S';
                pv_error_msg    := lv_error_msg || 'Successfully Updated';
                COMMIT;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := ' Error while updating :' || SQLERRM;
            ROLLBACK;
    END xxd_po_price_rule_asigmnts_prc;

    FUNCTION get_price_rule_name (p_vendor_id     NUMBER,
                                  p_brand         VARCHAR2,
                                  p_tq_category   VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_price_rule   xxdo_po_price_rule.po_price_rule%TYPE;
    BEGIN
        SELECT tag
          INTO lv_price_rule
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_PO_TQ_PRICE_RULE_VENDORS'
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG')
               AND meaning = p_vendor_id;

        lv_price_rule   :=
            lv_price_rule || '-' || p_brand || '-' || p_tq_category;
        RETURN (lv_price_rule);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'E';
    END get_price_rule_name;

    PROCEDURE user_role (p_user_id IN NUMBER, x_role OUT NOCOPY VARCHAR2)
    IS
        l_count_user   NUMBER;
    BEGIN
        SELECT COUNT (user_id)
          INTO l_count_user
          FROM apps.fnd_lookup_values flv, fnd_user fu
         WHERE     flv.lookup_type = 'XXD_PO_TQ_PRICE_RULE_USERS'
               AND flv.language = 'US'
               AND flv.enabled_flag = 'Y'
               AND flv.meaning = fu.user_name
               AND fu.user_id = p_user_id
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1)
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        -- CHECK IF USER IN THE LIST

        IF l_count_user = 0
        THEN
            x_role   := 'UNATHORIZED';
        ELSE
            x_role   := 'SUBMITTER';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_role   := 'UNATHORIZED';
    END user_role;

    PROCEDURE process_file (p_file_id IN NUMBER, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2
                            , x_file_id OUT NOCOPY VARCHAR2)
    IS
        CURSOR cur_val IS
            (SELECT REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   1, NULL, 1) po_price_rule,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   2, NULL, 1) item_segment1,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   3, NULL, 1) item_segment2,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   4, NULL, 1) vendor_name,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   5, NULL, 1) comments,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   6, NULL, 1) org_name,
                    TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              7, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') action,
                    NULL attribute1,
                    src.file_id,
                    src.file_name
               FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
              WHERE     1 = 1
                    AND file_source = 'FOB'
                    AND file_id = p_file_id
                    AND REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                       4, NULL, 1)
                            IS NOT NULL
                    AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                       1)
                            IS NOT NULL
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'PRICE%')
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             '%RULE'));

        TYPE v_validate_rec_type IS TABLE OF cur_val%ROWTYPE;

        v_val_typ              v_validate_rec_type := v_validate_rec_type ();
        ln_error_num           NUMBER;
        lv_error_msg           VARCHAR2 (4000) := NULL;
        lv_error_stat          VARCHAR2 (4) := 'S';
        lv_error_code          VARCHAR2 (4000) := NULL;
        lv_tl_error_msg        VARCHAR2 (4000) := NULL;
        ln_count               NUMBER;
        ln_count_org           NUMBER;
        l_count_brnd           NUMBER;
        l_count_sts            NUMBER;
        l_count_cust           NUMBER;
        l_count_enb            NUMBER;
        ln_user_id             NUMBER := fnd_global.user_id;
        ld_cur_date            DATE := SYSDATE;
        ln_last_update_login   NUMBER := fnd_global.login_id;
        ln_val_count           NUMBER;
        ln_po_price_rule_cnt   NUMBER;
        lv_stat                VARCHAR2 (10);
        ln_line                NUMBER := 1;
        lv_po_price_rule       xxdo_po_price_rule_assignment.po_price_rule%TYPE;
        lv_org_code            org_organization_definitions.organization_code%TYPE;
        ln_org_id              org_organization_definitions.organization_id%TYPE;
        lv_org_name            org_organization_definitions.organization_name%TYPE;

        TYPE po_price_rule_asigmnt_ins_type
            IS TABLE OF xxdo_po_price_rule_assignment%ROWTYPE;

        v_xxdo_inst_type       po_price_rule_asigmnt_ins_type
                                   := po_price_rule_asigmnt_ins_type ();
        v_xxdo_rmv_type        po_price_rule_asigmnt_ins_type
                                   := po_price_rule_asigmnt_ins_type ();

        TYPE xxd_po_pric_rul_asmnt_rec_typ IS RECORD
        (
            target_item_org_id          NUMBER,
            target_item_organization    VARCHAR2 (50 BYTE),
            po_price_rule               VARCHAR2 (30 BYTE),
            item_segment1               VARCHAR2 (40 BYTE),
            item_segment2               VARCHAR2 (40 BYTE),
            new_po_price_rule           VARCHAR2 (30 BYTE),
            new_item_segment1           VARCHAR2 (40 BYTE),
            new_item_segment2           VARCHAR2 (40 BYTE),
            item_segment3               VARCHAR2 (40 BYTE),
            active_start_date           DATE,
            active_end_date             DATE,
            comments                    VARCHAR2 (180 BYTE),
            created_by                  NUMBER,
            creation_date               DATE,
            last_updated_by             NUMBER,
            last_update_date            DATE,
            attribute1                  VARCHAR2 (240 BYTE),
            attribute2                  VARCHAR2 (240 BYTE),
            attribute3                  VARCHAR2 (240 BYTE),
            attribute4                  VARCHAR2 (240 BYTE),
            attribute5                  VARCHAR2 (240 BYTE),
            attribute6                  VARCHAR2 (240 BYTE),
            attribute7                  VARCHAR2 (240 BYTE),
            attribute8                  VARCHAR2 (240 BYTE),
            attribute9                  VARCHAR2 (240 BYTE),
            attribute10                 NUMBER,
            attribute11                 NUMBER,
            attribute12                 NUMBER,
            attribute13                 NUMBER,
            attribute14                 NUMBER,
            attribute15                 NUMBER
        );

        TYPE po_price_rule_asigmnt_upd_type
            IS TABLE OF xxd_po_pric_rul_asmnt_rec_typ;

        v_xxdo_upd_type        po_price_rule_asigmnt_upd_type
                                   := po_price_rule_asigmnt_upd_type ();

        TYPE xxd_po_price_rul_asgn_bkp_type
            IS TABLE OF xxdo_po_price_rule_assignment%ROWTYPE;

        v_xxdo_bkp_type        xxd_po_price_rul_asgn_bkp_type
                                   := xxd_po_price_rul_asgn_bkp_type ();

        TYPE xxd_po_price_rul_asgn_arc_type
            IS TABLE OF xxd_po_price_rule_asgn_arch_t%ROWTYPE;

        v_xxdo_arch_type       xxd_po_price_rul_asgn_arc_type
                                   := xxd_po_price_rul_asgn_arc_type ();
        v_xxdo_price_type      xxdo.xxd_po_pric_rul_asmnt_tbl_type
                                   := xxdo.xxd_po_pric_rul_asmnt_tbl_type ();
    BEGIN
        v_xxdo_inst_type.DELETE;
        v_xxdo_upd_type.DELETE;
        v_xxdo_arch_type.DELETE;

        BEGIN
            SELECT lookup_code
              INTO lv_org_code
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_PO_TQ_PRICE_RULE_UTILS'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y'
                   AND language = USERENV ('LANG');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || ' Error While collecting The Constant Values '
                        || SQLERRM,
                        1,
                        4000);
        END;

        BEGIN
            SELECT organization_id, organization_name
              INTO ln_org_id, lv_org_name
              FROM org_organization_definitions
             WHERE organization_code = lv_org_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                    SUBSTR (
                           lv_error_msg
                        || ' Error While Deriving The Constant Values '
                        || SQLERRM,
                        1,
                        4000);
        END;

        OPEN cur_val;

        FETCH cur_val BULK COLLECT INTO v_val_typ;

        BEGIN
            IF (lv_error_stat <> 'E')
            THEN
                FOR i IN v_val_typ.FIRST .. v_val_typ.LAST
                LOOP
                    lv_error_msg   := NULL;

                    IF (v_val_typ (i).action IS NULL)
                    THEN
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                   lv_error_msg
                                || ' Please Provide the Action Value (INSERT,UPDATE,REMOVE) ',
                                1,
                                4000);
                    ELSIF (v_val_typ (i).action IS NOT NULL AND UPPER (v_val_typ (i).action) NOT IN ('INSERT', 'UPDATE', 'REMOVE'))
                    THEN
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                   lv_error_msg
                                || ' Please Correct The '
                                || v_val_typ (i).action
                                || '  Action Value (INSERT,UPDATE,REMOVE) ',
                                1,
                                4000);
                    ELSE
                        lv_stat   := 'S';
                    END IF;

                    IF ((UPPER (v_val_typ (i).action) = 'INSERT' OR UPPER (v_val_typ (i).action) = 'UPDATE') AND lv_stat = 'S')
                    THEN
                        IF (v_val_typ (i).po_price_rule IS NOT NULL)
                        THEN
                            BEGIN
                                SELECT COUNT (1)
                                  INTO ln_val_count
                                  FROM xxdo_po_price_rule
                                 WHERE po_price_rule =
                                       v_val_typ (i).po_price_rule;

                                IF (ln_val_count = 0)
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Price Rule  is not defined ',
                                            1,
                                            4000);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Price Rule is not defined ',
                                            1,
                                            4000);
                            END;

                            BEGIN
                                SELECT COUNT (1)
                                  INTO ln_count
                                  FROM xxdo_po_price_rule_assignment
                                 WHERE     po_price_rule =
                                           v_val_typ (i).po_price_rule
                                       AND item_segment1 =
                                           v_val_typ (i).item_segment1
                                       AND item_segment2 =
                                           v_val_typ (i).item_segment2;

                                IF (ln_count > 0)
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' Record Already Existing ',
                                            1,
                                            4000);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    --          lv_error_stat := 'S';
                                    NULL;
                            END;
                        END IF;

                        IF (v_val_typ (i).po_price_rule IS NOT NULL AND v_val_typ (i).item_segment1 IS NOT NULL AND v_val_typ (i).item_segment2 IS NOT NULL)
                        THEN
                            BEGIN
                                SELECT COUNT (1)
                                  INTO ln_count_org
                                  FROM xxd_common_items_v xciv, org_organization_definitions ood
                                 WHERE     1 = 1
                                       AND xciv.organization_id =
                                           ood.organization_id
                                       AND xciv.style_number =
                                           v_val_typ (i).item_segment1
                                       AND xciv.color_code =
                                           v_val_typ (i).item_segment2
                                       AND ood.organization_code = 'JP5';

                                IF (ln_count_org = 0)
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color does not exist or not assigned to JP5 ',
                                            1,
                                            4000);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color does not exist or not assigned to JP5 ',
                                            1,
                                            4000);
                            END;
                        ELSE
                            lv_error_stat   := 'E';
                            lv_error_msg    :=
                                SUBSTR (
                                       lv_error_msg
                                    || ' ; Enter The Price Rule OR Style OR Color Values ',
                                    1,
                                    4000);
                        END IF;

                        IF (v_val_typ (i).item_segment1 IS NOT NULL AND v_val_typ (i).item_segment2 IS NOT NULL AND v_val_typ (i).comments IS NOT NULL)
                        THEN
                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_count_brnd
                                  FROM xxd_common_items_v xciv
                                 WHERE     1 = 1
                                       AND xciv.style_number =
                                           v_val_typ (i).item_segment1
                                       AND xciv.color_code =
                                           v_val_typ (i).item_segment2
                                       AND xciv.organization_id = ln_org_id
                                       AND xciv.brand =
                                           v_val_typ (i).comments;

                                IF (l_count_brnd = 0)
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color should be of the brand in the price rule ',
                                            1,
                                            4000);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color should be of the brand in the price rule ',
                                            1,
                                            4000);
                            END;
                        END IF;

                        IF (v_val_typ (i).item_segment1 IS NOT NULL AND v_val_typ (i).item_segment2 IS NOT NULL AND v_val_typ (i).comments IS NOT NULL)
                        THEN
                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_count_sts
                                  FROM xxd_common_items_v xciv
                                 WHERE     1 = 1
                                       AND xciv.style_number =
                                           v_val_typ (i).item_segment1
                                       AND xciv.color_code =
                                           v_val_typ (i).item_segment2
                                       AND xciv.brand =
                                           v_val_typ (i).comments
                                       AND xciv.organization_id = ln_org_id
                                       AND (xciv.inventory_item_status_code IN ('Inactive') OR xciv.item_type = 'GENERIC');

                                IF (l_count_sts > 0)
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color is not Active ',
                                            1,
                                            4000);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color is not Active ',
                                            1,
                                            4000);
                            END;
                        END IF;

                        IF (v_val_typ (i).item_segment1 IS NOT NULL AND v_val_typ (i).item_segment2 IS NOT NULL AND v_val_typ (i).comments IS NOT NULL)
                        THEN
                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_count_cust
                                  FROM xxd_common_items_v xciv
                                 WHERE     xciv.style_number =
                                           v_val_typ (i).item_segment1
                                       AND xciv.color_code =
                                           v_val_typ (i).item_segment2
                                       AND xciv.brand =
                                           v_val_typ (i).comments
                                       AND xciv.organization_id = ln_org_id
                                       AND NVL (
                                               xciv.customer_order_enabled_flag,
                                               'N') =
                                           'Y';

                                IF (l_count_cust = 0)
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color is not Customer Order Enabled ',
                                            1,
                                            4000);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color is not Customer Order Enabled ',
                                            1,
                                            4000);
                            END;
                        END IF;

                        IF (v_val_typ (i).item_segment1 IS NOT NULL AND v_val_typ (i).item_segment2 IS NOT NULL AND v_val_typ (i).comments IS NOT NULL)
                        THEN
                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_count_enb
                                  FROM xxd_common_items_v xciv
                                 WHERE     1 = 1
                                       AND xciv.style_number =
                                           v_val_typ (i).item_segment1
                                       AND xciv.color_code =
                                           v_val_typ (i).item_segment2
                                       AND xciv.brand =
                                           v_val_typ (i).comments
                                       AND xciv.organization_id = ln_org_id
                                       AND NVL (xciv.enabled_flag, 'N') <>
                                           'Y';

                                IF (l_count_enb > 0)
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color is not Enabled ',
                                            1,
                                            4000);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Style Color is not Enabled ',
                                            1,
                                            4000);
                            END;
                        END IF;

                        IF (UPPER (v_val_typ (i).action) = 'INSERT')
                        THEN
                            BEGIN
                                SELECT COUNT (1)
                                  INTO ln_po_price_rule_cnt
                                  FROM xxdo_po_price_rule_assignment
                                 WHERE     REGEXP_SUBSTR (po_price_rule, '[^-]+', 1
                                                          , 1) =
                                           REGEXP_SUBSTR (v_val_typ (i).po_price_rule, '[^-]+', 1
                                                          , 1)
                                       AND item_segment1 =
                                           v_val_typ (i).item_segment1
                                       AND item_segment2 =
                                           v_val_typ (i).item_segment2;

                                v_val_typ (i).attribute1   :=
                                    lv_po_price_rule;

                                IF (ln_po_price_rule_cnt > 0)
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Vendor '
                                            || v_val_typ (i).vendor_name
                                            || ' Style '
                                            || v_val_typ (i).item_segment1
                                            || ' and Color '
                                            || v_val_typ (i).item_segment2
                                            || ' combination already exists for  '
                                            || 'Price Rule '
                                            || v_val_typ (i).po_price_rule
                                            || ' ',
                                            1,
                                            4000);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;

                        IF (UPPER (v_val_typ (i).action) = 'UPDATE')
                        THEN
                            BEGIN
                                SELECT po_price_rule
                                  INTO lv_po_price_rule
                                  FROM xxdo_po_price_rule_assignment
                                 WHERE     REGEXP_SUBSTR (po_price_rule, '[^-]+', 1
                                                          , 1) =
                                           REGEXP_SUBSTR (v_val_typ (i).po_price_rule, '[^-]+', 1
                                                          , 1)
                                       AND item_segment1 =
                                           v_val_typ (i).item_segment1
                                       AND item_segment2 =
                                           v_val_typ (i).item_segment2;

                                v_val_typ (i).attribute1   :=
                                    lv_po_price_rule;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_error_stat   := 'E';
                                    lv_error_msg    :=
                                        SUBSTR (
                                               lv_error_msg
                                            || ' ; Price Rule not existed For The Vendor Combination To Update ',
                                            1,
                                            4000);
                            END;
                        END IF;
                    END IF;

                    IF (UPPER (v_val_typ (i).action) = 'REMOVE' AND lv_stat = 'S')
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO ln_count
                              FROM xxdo_po_price_rule_assignment
                             WHERE     po_price_rule =
                                       v_val_typ (i).po_price_rule
                                   AND item_segment1 =
                                       v_val_typ (i).item_segment1
                                   AND item_segment2 =
                                       v_val_typ (i).item_segment2;

                            IF (ln_count = 0)
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Record Is not Existing To Remove ',
                                        1,
                                        4000);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_stat   := 'E';
                                lv_error_msg    :=
                                    SUBSTR (
                                           lv_error_msg
                                        || ' Record Is not Existing To Remove ',
                                        1,
                                        4000);
                        END;
                    END IF;

                    ln_line        := ln_line + 1;

                    IF (lv_error_msg IS NOT NULL)
                    THEN
                        lv_error_msg   :=
                               ' Row '
                            || ln_line
                            || ' Price Rule,Style Color '
                            || v_val_typ (i).po_price_rule
                            || ','
                            || v_val_typ (i).item_segment1
                            || ', '
                            || v_val_typ (i).item_segment2
                            || ' '
                            || lv_error_msg;

                        lv_tl_error_msg   :=
                            lv_tl_error_msg || lv_error_msg || ' #';
                    END IF;
                END LOOP;

                lv_error_msg   := lv_tl_error_msg;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_status   := 'E';
                x_err_msg      :=
                    ' Error while Validating Records :' || SQLERRM;
                ROLLBACK;
        END;

        IF (lv_error_stat = 'E')
        THEN
            x_ret_status   := 'E';
            x_err_msg      := lv_error_msg;
        ELSE
            BEGIN
                FOR i IN v_val_typ.FIRST .. v_val_typ.LAST
                LOOP
                    IF (UPPER (v_val_typ (i).action) = 'INSERT')
                    THEN
                        v_xxdo_inst_type.EXTEND;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).po_price_rule   :=
                            v_val_typ (i).po_price_rule;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).item_segment1   :=
                            v_val_typ (i).item_segment1;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).item_segment2   :=
                            v_val_typ (i).item_segment2;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).item_segment3   :=
                            NULL;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).active_start_date   :=
                            NULL;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).active_end_date   :=
                            NULL;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).comments   :=
                            v_val_typ (i).comments;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).created_by   :=
                            fnd_profile.VALUE ('USER_ID');
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).creation_date   :=
                            SYSDATE;
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).last_updated_by   :=
                            fnd_profile.VALUE ('USER_ID');
                        v_xxdo_inst_type (v_xxdo_inst_type.LAST).last_update_date   :=
                            SYSDATE;
                        v_xxdo_arch_type.EXTEND;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_prc_rul_asgn_arc_id   :=
                            xxd_po_price_rule_asgn_arch_s.NEXTVAL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule   :=
                            v_val_typ (i).po_price_rule;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment1   :=
                            v_val_typ (i).item_segment1;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment2   :=
                            v_val_typ (i).item_segment2;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).new_po_price_rule   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_start_date   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_end_date   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).comments   :=
                            v_val_typ (i).comments;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).created_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).creation_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_updated_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_login   :=
                            ln_last_update_login;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute1   :=
                            'INSERT';
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute2   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute4   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute5   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute6   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute7   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute8   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute9   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute10   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute11   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute12   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute13   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute14   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute15   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_id   :=
                            v_val_typ (i).file_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_name   :=
                            v_val_typ (i).file_name;
                    ELSIF (UPPER (v_val_typ (i).action) = 'UPDATE')
                    THEN
                        v_xxdo_upd_type.EXTEND;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).po_price_rule   :=
                            v_val_typ (i).po_price_rule;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).item_segment1   :=
                            v_val_typ (i).item_segment1;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).item_segment2   :=
                            v_val_typ (i).item_segment2;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).item_segment3   :=
                            NULL;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).active_start_date   :=
                            NULL;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).active_end_date   :=
                            NULL;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).attribute1   :=
                            v_val_typ (i).attribute1;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).comments   :=
                            v_val_typ (i).comments;
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).last_updated_by   :=
                            fnd_profile.VALUE ('USER_ID');
                        v_xxdo_upd_type (v_xxdo_upd_type.LAST).last_update_date   :=
                            SYSDATE;
                        v_xxdo_arch_type.EXTEND;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_prc_rul_asgn_arc_id   :=
                            xxd_po_price_rule_asgn_arch_s.NEXTVAL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule   :=
                            v_val_typ (i).attribute1;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment1   :=
                            v_val_typ (i).item_segment1;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment2   :=
                            v_val_typ (i).item_segment2;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).new_po_price_rule   :=
                            v_val_typ (i).po_price_rule;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_start_date   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_end_date   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).comments   :=
                            v_val_typ (i).comments;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).created_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).creation_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_updated_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_login   :=
                            ln_last_update_login;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute1   :=
                            'UPDATE';
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute2   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute4   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute5   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute6   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute7   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute8   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute9   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute10   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute11   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute12   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute13   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute14   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute15   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_id   :=
                            v_val_typ (i).file_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_name   :=
                            v_val_typ (i).file_name;
                    ELSIF (UPPER (v_val_typ (i).action) = 'REMOVE')
                    THEN
                        v_xxdo_rmv_type.EXTEND;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).po_price_rule   :=
                            v_val_typ (i).po_price_rule;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).item_segment1   :=
                            v_val_typ (i).item_segment1;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).item_segment2   :=
                            v_val_typ (i).item_segment2;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).item_segment3   :=
                            NULL;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).active_start_date   :=
                            NULL;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).active_end_date   :=
                            NULL;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).comments   :=
                            v_val_typ (i).comments;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).created_by   :=
                            fnd_profile.VALUE ('USER_ID');
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).creation_date   :=
                            SYSDATE;
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).last_updated_by   :=
                            fnd_profile.VALUE ('USER_ID');
                        v_xxdo_rmv_type (v_xxdo_rmv_type.LAST).last_update_date   :=
                            SYSDATE;
                        v_xxdo_arch_type.EXTEND;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_prc_rul_asgn_arc_id   :=
                            xxd_po_price_rule_asgn_arch_s.NEXTVAL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_org_id   :=
                            ln_org_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_organization   :=
                            lv_org_name;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule   :=
                            v_val_typ (i).po_price_rule;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment1   :=
                            v_val_typ (i).item_segment1;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment2   :=
                            v_val_typ (i).item_segment2;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).new_po_price_rule   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_start_date   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_end_date   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).comments   :=
                            v_val_typ (i).comments;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).created_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).creation_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_updated_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_login   :=
                            ln_last_update_login;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute1   :=
                            'REMOVE';
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute2   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute4   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute5   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute6   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute7   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute8   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute9   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute10   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute11   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute12   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute13   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute14   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute15   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_id   :=
                            v_val_typ (i).file_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_name   :=
                            v_val_typ (i).file_name;
                    END IF;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';
                    lv_error_msg    :=
                           lv_error_msg
                        || ' Assigment rectype values #'
                        || SQLERRM;
            END;

            IF (lv_error_stat = 'S')
            THEN
                IF (v_xxdo_inst_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i
                            IN v_xxdo_inst_type.FIRST ..
                               v_xxdo_inst_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxdo_po_price_rule_assignment
                                 VALUES v_xxdo_inst_type (i);
                    --lv_error_stat := 'S';

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_stat   := 'E';

                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error Insert in price rule Assignment' || v_xxdo_inst_type (ln_error_num).po_price_rule || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                IF (v_xxdo_upd_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i
                            IN v_xxdo_upd_type.FIRST .. v_xxdo_upd_type.LAST
                          SAVE EXCEPTIONS
                            UPDATE xxdo_po_price_rule_assignment
                               SET po_price_rule = v_xxdo_upd_type (i).po_price_rule, last_update_date = v_xxdo_upd_type (i).last_update_date, last_updated_by = v_xxdo_upd_type (i).last_updated_by
                             WHERE     po_price_rule =
                                       v_xxdo_upd_type (i).attribute1
                                   AND item_segment1 =
                                       v_xxdo_upd_type (i).item_segment1
                                   AND item_segment2 =
                                       v_xxdo_upd_type (i).item_segment2;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_stat   := 'E';

                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error Update in price rule Assignment' || v_xxdo_upd_type (ln_error_num).new_po_price_rule || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                IF (v_xxdo_arch_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i
                            IN v_xxdo_arch_type.FIRST ..
                               v_xxdo_arch_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxd_po_price_rule_asgn_arch_t
                                 VALUES v_xxdo_arch_type (i);
                    --lv_error_stat := 'S';

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_stat   := 'E';

                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error in Archive price rule Assignment ' || v_xxdo_arch_type (ln_error_num).po_price_rule || ' ' || v_xxdo_arch_type.COUNT || ' ' || v_xxdo_arch_type (ln_error_num).po_prc_rul_asgn_arc_id || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                IF (v_xxdo_rmv_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i
                            IN v_xxdo_rmv_type.FIRST .. v_xxdo_rmv_type.LAST
                          SAVE EXCEPTIONS
                            DELETE FROM
                                xxdo_po_price_rule_assignment
                                  WHERE     po_price_rule =
                                            v_xxdo_rmv_type (i).po_price_rule
                                        AND item_segment1 =
                                            v_xxdo_rmv_type (i).item_segment1
                                        AND item_segment2 =
                                            v_xxdo_rmv_type (i).item_segment2;
                    -- lv_error_stat := 'S';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_stat   := 'E';

                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error removing in price rule Assignment' || v_xxdo_rmv_type (ln_error_num).po_price_rule || ' ' || v_xxdo_rmv_type (ln_error_num).item_segment1 || ' ' || v_xxdo_rmv_type (ln_error_num).item_segment2 || ' ' || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;
            END IF;
        END IF;

        IF (lv_error_stat = 'E')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            x_ret_status   := 'S';
            x_err_msg      := lv_error_msg || 'File Successfully Uploaded';
            COMMIT;
        END IF;

        CLOSE cur_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := ' Error while updating :' || SQLERRM;
            ROLLBACK;
    END process_file;

    PROCEDURE xxd_po_price_rule_asignt_delet (p_po_price_rule_asmnt_tbl xxdo.xxd_po_pric_rul_asmnt_tbl_type, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    AS
        ln_error_num           NUMBER;
        lv_error_msg           VARCHAR2 (4000) := NULL;
        lv_error_stat          VARCHAR2 (4) := 'S';
        lv_error_code          VARCHAR2 (4000) := NULL;
        ln_user_id             NUMBER := fnd_global.user_id;
        ld_cur_date            DATE := SYSDATE;
        ln_last_update_login   NUMBER := fnd_global.login_id;

        TYPE xxd_po_price_rul_asgn_bkp_type
            IS TABLE OF xxdo_po_price_rule_assignment%ROWTYPE;

        v_xxdo_bkp_type        xxd_po_price_rul_asgn_bkp_type
                                   := xxd_po_price_rul_asgn_bkp_type ();

        TYPE xxd_po_price_rul_asgn_arc_type
            IS TABLE OF xxd_po_price_rule_asgn_arch_t%ROWTYPE;

        v_xxdo_arch_type       xxd_po_price_rul_asgn_arc_type
                                   := xxd_po_price_rul_asgn_arc_type ();
    BEGIN
        BEGIN
            IF (p_po_price_rule_asmnt_tbl.COUNT > 0)
            THEN
                SELECT *
                  BULK COLLECT INTO v_xxdo_bkp_type
                  FROM xxdo_po_price_rule_assignment
                 WHERE (po_price_rule, item_segment1, item_segment2) IN
                           (SELECT po_price_rule, item_segment1, item_segment2 FROM TABLE (p_po_price_rule_asmnt_tbl));

                IF (v_xxdo_bkp_type.COUNT > 0)
                THEN
                    FOR x IN v_xxdo_bkp_type.FIRST .. v_xxdo_bkp_type.LAST
                    LOOP
                        v_xxdo_arch_type.EXTEND;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_prc_rul_asgn_arc_id   :=
                            xxd_po_price_rule_asgn_arch_s.NEXTVAL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_org_id   :=
                            v_xxdo_bkp_type (x).target_item_org_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).target_item_organization   :=
                            v_xxdo_bkp_type (x).target_item_organization;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).po_price_rule   :=
                            v_xxdo_bkp_type (x).po_price_rule;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment1   :=
                            v_xxdo_bkp_type (x).item_segment1;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment2   :=
                            v_xxdo_bkp_type (x).item_segment2;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).item_segment3   :=
                            v_xxdo_bkp_type (x).item_segment3;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).new_po_price_rule   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_start_date   :=
                            v_xxdo_bkp_type (x).active_start_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).active_end_date   :=
                            v_xxdo_bkp_type (x).active_end_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).comments   :=
                            v_xxdo_bkp_type (x).comments;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).created_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).creation_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_updated_by   :=
                            ln_user_id;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_date   :=
                            ld_cur_date;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).last_update_login   :=
                            ln_last_update_login;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute1   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute2   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute3   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute4   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute5   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute6   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute7   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute8   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute9   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute10   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute11   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute12   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute13   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute14   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).attribute15   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_id   :=
                            NULL;
                        v_xxdo_arch_type (v_xxdo_arch_type.LAST).file_name   :=
                            NULL;
                    END LOOP;
                END IF;
            --lv_error_stat := 'S';

            END IF;

            IF (v_xxdo_arch_type.COUNT > 0)
            THEN
                BEGIN
                    FORALL i
                        IN v_xxdo_arch_type.FIRST .. v_xxdo_arch_type.LAST
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_po_price_rule_asgn_arch_t
                             VALUES v_xxdo_arch_type (i);
                --lv_error_stat := 'S';

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_stat   := 'E';

                        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            ln_error_num   :=
                                SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                            lv_error_code   :=
                                SQLERRM (
                                    -1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                            lv_error_msg   :=
                                SUBSTR (
                                    (lv_error_msg || ' Error in Archive price rule Assignment ' || v_xxdo_arch_type (ln_error_num).po_price_rule || ' ' || v_xxdo_arch_type.COUNT || ' ' || v_xxdo_arch_type (ln_error_num).po_prc_rul_asgn_arc_id || lv_error_code || ' #'),
                                    1,
                                    4000);
                        END LOOP;
                END;
            END IF;

            IF (p_po_price_rule_asmnt_tbl.COUNT > 0)
            THEN
                BEGIN
                    FORALL i
                        IN p_po_price_rule_asmnt_tbl.FIRST ..
                           p_po_price_rule_asmnt_tbl.LAST
                      SAVE EXCEPTIONS
                        DELETE FROM
                            xxdo_po_price_rule_assignment
                              WHERE     po_price_rule =
                                        p_po_price_rule_asmnt_tbl (i).po_price_rule
                                    AND item_segment1 =
                                        p_po_price_rule_asmnt_tbl (i).item_segment1
                                    AND item_segment2 =
                                        p_po_price_rule_asmnt_tbl (i).item_segment2;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_stat   := 'E';

                        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            ln_error_num   :=
                                SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                            lv_error_code   :=
                                SQLERRM (
                                    -1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                            lv_error_msg   :=
                                SUBSTR (
                                    (lv_error_msg || ' Error Update in price rule Assignment' || p_po_price_rule_asmnt_tbl (ln_error_num).po_price_rule || lv_error_code || ' #'),
                                    1,
                                    4000);
                        END LOOP;
                END;
            END IF;
        END;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            pv_error_stat   := 'S';
            pv_error_msg    := lv_error_msg || 'Successfully Deleted';
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_stat   := 'E';
            lv_error_msg    :=
                'Error While Deleting the Records : ' || SQLERRM;
    END xxd_po_price_rule_asignt_delet;
END xxd_po_price_rule_pkg;
/
