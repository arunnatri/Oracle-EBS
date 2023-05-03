--
-- XXD_ICX_POREQ_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ICX_POREQ_PKG"
IS
    /***********************************************************************************
     *$header     :                                                                   *
     *                                                                                *
     * AUTHORS    : Srinath Siricilla                                                 *
     *                                                                                *
     * PURPOSE    : Mass Creation/Updation of Requisitions through WEBADI             *
     *                                                                                *
     * PARAMETERS :                                                                   *
     *                                                                                *
     * DATE       :  03-FEB-2020                                                      *
     *                                                                                *
     * Assumptions:                                                                   *
     *                                                                                *
     *                                                                                *
     * History                                                                        *
     * Vsn     Change Date  Changed By            Change Description                  *
     * -----   -----------  ------------------    ------------------------------------*
     * 1.1     03-FEB-2020  Srinath Siricilla     CCR0008385                          *
     *********************************************************************************/
    --Global Variables
    gv_package_name   CONSTANT VARCHAR2 (30) := 'XXD_ICX_POREQ_PKG';
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id              NUMBER;
    --:= TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmddhh24miss')) ;
    v_def_mail_recips          do_mail_utils.tbl_recips;
    ex_no_recips               EXCEPTION;

    --Purge Procedure
    PROCEDURE purge_data (pv_ret_message OUT VARCHAR2)
    IS
        ln_purge_days   NUMBER := 90;
    BEGIN
        DELETE FROM xxdo.xxd_icx_poreq_stg_t stg
              WHERE 1 = 1 AND stg.creation_date < SYSDATE - ln_purge_days;

        pv_ret_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_ret_message   :=
                SUBSTR ('Error in Purging Data. Error is: ' || SQLERRM,
                        1,
                        2000);
    END purge_data;

    FUNCTION get_supervisor_id (pn_requester_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_sup_id   per_all_people_f.person_id%TYPE := NULL;
    BEGIN
        BEGIN
            SELECT papf.person_id Sup_id
              INTO ln_sup_id
              FROM per_all_people_f papf, per_all_assignments_f paaf, per_all_people_f papf1
             WHERE     papf.person_id = paaf.person_id
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND paaf.supervisor_id = papf1.person_id
                   AND NVL (papf1.current_employee_flag, 'Y') = 'Y'
                   AND SYSDATE BETWEEN NVL (papf.effective_start_date,
                                            SYSDATE - 1)
                                   AND NVL (papf.effective_end_date,
                                            SYSDATE + 1)
                   AND SYSDATE BETWEEN NVL (paaf.effective_start_date,
                                            SYSDATE - 1)
                                   AND NVL (paaf.effective_end_date,
                                            SYSDATE + 1)
                   AND SYSDATE BETWEEN NVL (papf1.effective_start_date,
                                            SYSDATE - 1)
                                   AND NVL (papf1.effective_end_date,
                                            SYSDATE + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_sup_id   := NULL;
        END;

        RETURN ln_sup_id;
    END get_supervisor_id;

    PROCEDURE check_req_valid_prc (pn_resp_id IN NUMBER, pn_requester_id IN NUMBER, x_cc OUT VARCHAR2
                                   , x_req OUT VARCHAR2)
    IS
    --lv_attr2   VARCHAR2(100);
    BEGIN
        BEGIN
            SELECT attribute2, attribute3
              INTO x_cc, x_req
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
             WHERE     1 = 1
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvs.flex_value_set_name =
                       'XXD_IPROC_RESP_COST_CNT_VS'
                   AND ffvl.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                            SYSDATE - 1)
                                   AND NVL (ffvl.end_date_active,
                                            SYSDATE + 1)
                   AND ffvl.attribute1 = pn_resp_id
                   AND ffvl.attribute2 IS NULL
                   AND ffvl.attribute3 = pn_requester_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_cc    := NULL;
                x_req   := NULL;
        END;
    END check_req_valid_prc;

    PROCEDURE get_cost_center (pn_resp_id        IN     NUMBER,
                               pn_requester_id   IN     NUMBER,
                               pn_cc             IN     NUMBER,
                               x_cost_center        OUT NUMBER,
                               x_person_id          OUT NUMBER)
    IS
        lv_cost_center   gl_code_combinations_kfv.segment5%TYPE;
    BEGIN
        x_cost_center   := NULL;
        x_person_id     := NULL;

        BEGIN
            SELECT attribute2, attribute3
              INTO x_cost_center, x_person_id
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
             WHERE     1 = 1
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvs.flex_value_set_name =
                       'XXD_IPROC_RESP_COST_CNT_VS'
                   AND ffvl.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                            SYSDATE - 1)
                                   AND NVL (ffvl.end_date_active,
                                            SYSDATE + 1)
                   AND ffvl.attribute1 = pn_resp_id
                   AND ffvl.attribute2 = pn_cc
                   AND ffvl.attribute3 = pn_requester_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_cost_center   := NULL;
                x_person_id     := NULL;
        END;

        IF x_cost_center IS NULL
        THEN
            BEGIN
                SELECT attribute2
                  INTO x_cost_center
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffvs.flex_value_set_name =
                           'XXD_IPROC_RESP_COST_CNT_VS'
                       AND ffvl.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE - 1)
                                       AND NVL (ffvl.end_date_active,
                                                SYSDATE + 1)
                       AND ffvl.attribute1 = pn_resp_id
                       AND ffvl.attribute2 = pn_cc
                       AND ffvl.attribute3 IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_cost_center   := NULL;
            END;
        END IF;

        IF x_cost_center IS NULL
        THEN
            BEGIN
                SELECT attribute2
                  INTO x_cost_center
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffvs.flex_value_set_name =
                           'XXD_IPROC_RESP_COST_CNT_VS'
                       AND ffvl.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE - 1)
                                       AND NVL (ffvl.end_date_active,
                                                SYSDATE + 1)
                       AND ffvl.attribute1 = pn_resp_id
                       AND ffvl.attribute2 IS NULL
                       AND ffvl.attribute3 IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_cost_center   := NULL;
            END;
        END IF;
    END get_cost_center;

    FUNCTION validate_cost_center (pn_requester_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lc_cost_center    gl_code_combinations_kfv.segment5%TYPE;
        lc_con_segments   gl_code_combinations_kfv.segment5%TYPE;
        ln_def_ccid       gl_code_combinations_kfv.code_combination_id%TYPE;
        ln_sup_def_ccid   gl_code_combinations_kfv.code_combination_id%TYPE;
        ln_sup_id         per_all_people_f.person_id%TYPE := NULL;
        ln_cc             VARCHAR2 (100);
        ln_requester_id   NUMBER;
    BEGIN
        ln_requester_id   := pn_requester_id;

        BEGIN
            SELECT paaf.DEFAULT_CODE_COMB_ID
              INTO ln_def_ccid
              FROM PER_all_ASSIGNMENTS_f paaf
             WHERE     1 = 1
                   AND SYSDATE BETWEEN paaf.effective_start_date
                                   AND paaf.effective_end_date
                   AND paaf.person_id = ln_requester_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_def_ccid   := NULL;
        END;

        IF ln_def_ccid IS NOT NULL
        THEN
            BEGIN
                SELECT gcc_kfv.segment5
                  INTO ln_cc
                  FROM gl_code_combinations_kfv gcc_kfv
                 WHERE     gcc_kfv.enabled_flag = 'Y'
                       AND gcc_kfv.code_combination_id = ln_def_ccid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --ln_cc := 'NULL';
                    ln_cc   := 'E';
            END;

            RETURN ln_cc;
        ELSE
            LOOP
                BEGIN
                    SELECT get_supervisor_id (ln_requester_id)
                      INTO ln_sup_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_sup_id   := NULL;
                END;

                IF ln_sup_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT paaf.DEFAULT_CODE_COMB_ID
                          INTO ln_sup_def_ccid
                          FROM PER_all_ASSIGNMENTS_f paaf
                         WHERE     SYSDATE BETWEEN paaf.effective_start_date
                                               AND paaf.effective_end_date
                               AND person_id = ln_sup_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_sup_def_ccid   := NULL;
                    END;

                    IF ln_sup_def_ccid IS NOT NULL
                    THEN
                        BEGIN
                            SELECT gcc_kfv.segment5
                              INTO ln_cc
                              FROM gl_code_combinations_kfv gcc_kfv
                             WHERE     enabled_flag = 'Y'
                                   AND gcc_kfv.code_combination_id =
                                       ln_sup_def_ccid;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                --ln_cc := NULL;
                                ln_cc   := 'E';
                        END;

                        EXIT WHEN ln_sup_def_ccid IS NOT NULL;
                    ELSE
                        ln_requester_id   := ln_sup_id;
                    END IF;
                ELSE
                    --ln_cc := 'NULL';
                    ln_cc   := 'E';

                    EXIT WHEN ln_sup_id IS NULL;
                END IF;
            END LOOP;

            RETURN ln_cc;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_cc   := 'E';
            RETURN ln_cc;
    END validate_cost_center;

    FUNCTION get_company_segment (p_org_id IN NUMBER)
        RETURN NUMBER
    IS
        -- get the value for company segment
        CURSOR lcu_company_ap_c (cp_org_id NUMBER)
        IS
            SELECT DISTINCT flex_segment_value
              FROM hr_operating_units hou, gl_legal_entities_bsvs gleb
             WHERE     hou.default_legal_context_id = gleb.legal_entity_id
                   AND hou.organization_id = cp_org_id;

        lc_segment1   VARCHAR2 (50);
    BEGIN
        --Fetch company segment value
        OPEN lcu_company_ap_c (cp_org_id => p_org_id);

        FETCH lcu_company_ap_c INTO lc_segment1;

        CLOSE lcu_company_ap_c;

        RETURN lc_segment1;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_company_segment: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_company_ap_c%ISOPEN
            THEN
                CLOSE lcu_company_ap_c;
            END IF;
    END get_company_segment;

    FUNCTION check_expense_or_asset (p_unit_price IN NUMBER, p_category_id IN NUMBER, p_currency_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lc_expense_or_asset   VARCHAR2 (50) := NULL;
        ln_threshold_amount   NUMBER := 0;
        lv_conv_rate          NUMBER;
        ln_unit_price         NUMBER := 0;

        CURSOR lcu_threshold_amount (cp_category_id NUMBER)
        IS
            SELECT attribute4 threshold_amount
              FROM mtl_categories
             WHERE     attribute_category = 'PO Mapping Data Elements'
                   AND category_id = cp_category_id;
    BEGIN
        ln_unit_price   := p_unit_price;

        --Convert currency other then USD using corporate conversion
        IF p_currency_code <> 'USD'
        THEN
            SELECT rate.conversion_rate
              INTO lv_conv_rate
              FROM apps.gl_daily_rates rate, apps.gl_daily_conversion_types ratetyp
             WHERE     ratetyp.conversion_type = rate.conversion_type
                   AND UPPER (ratetyp.user_conversion_type) = 'CORPORATE'
                   AND rate.from_currency = p_currency_code
                   AND rate.to_currency = 'USD'
                   AND rate.conversion_date = TRUNC (SYSDATE);

            ln_unit_price   := ln_unit_price * lv_conv_rate;
        END IF;

        OPEN lcu_threshold_amount (cp_category_id => p_category_id);

        FETCH lcu_threshold_amount INTO ln_threshold_amount;

        CLOSE lcu_threshold_amount;

        IF ln_unit_price < ln_threshold_amount
        THEN
            lc_expense_or_asset   := 'Expense';
        ELSE
            lc_expense_or_asset   := 'Asset';
        END IF;

        RETURN lc_expense_or_asset;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function check_expense_or_asset: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_threshold_amount%ISOPEN
            THEN
                CLOSE lcu_threshold_amount;
            END IF;
    END check_expense_or_asset;

    --Main Procedure called by WebADI
    PROCEDURE upload_proc (pn_cart_num NUMBER, pn_cart_line_num NUMBER, pv_operating_unit VARCHAR2, pv_po_item_cat VARCHAR2, pv_item_type VARCHAR2, pv_item_desc VARCHAR2 DEFAULT NULL, pv_requester VARCHAR2 DEFAULT NULL, pn_quantity NUMBER DEFAULT NULL, pv_uom VARCHAR2 DEFAULT NULL, pn_unit_price NUMBER DEFAULT NULL, pn_amount NUMBER DEFAULT NULL, pv_currency VARCHAR2 DEFAULT NULL, pv_vendor_name VARCHAR2 DEFAULT NULL, pv_vendor_site VARCHAR2 DEFAULT NULL, pd_need_by_date DATE DEFAULT NULL, pv_charge_account VARCHAR2 DEFAULT NULL, pv_deliver_to_loc VARCHAR2 DEFAULT NULL, pv_justification VARCHAR2, pv_requisition_num VARCHAR2, pv_attribute1 VARCHAR2, pv_attribute2 VARCHAR2, pv_attribute3 VARCHAR2, pv_attribute4 VARCHAR2, pv_attribute5 VARCHAR2, pv_attribute6 VARCHAR2, pv_attribute7 VARCHAR2, pv_attribute8 VARCHAR2, pv_attribute9 VARCHAR2, pv_attribute10 VARCHAR2, pv_attribute11 VARCHAR2, pv_attribute12 VARCHAR2, pv_attribute13 VARCHAR2, pv_attribute14 VARCHAR2
                           , pv_attribute15 VARCHAR2)
    IS
        ln_record_id               NUMBER;
        lv_error_message           VARCHAR2 (4000) := NULL;
        ln_cart_num                NUMBER;
        ln_cart_line_num           NUMBER;
        ln_org_id                  NUMBER := NULL;
        ln_category_id             NUMBER;
        lv_po_item_class           VARCHAR2 (100);
        lv_item_type               VARCHAR2 (100) := NULL;
        ln_person_id               NUMBER := NULL;
        ln_quantity                NUMBER;
        lv_uom_code                VARCHAR2 (10) := NULL;
        ln_unit_price              NUMBER;
        ln_amount                  NUMBER;
        lv_currency_code           VARCHAR2 (10) := NULL;
        ln_vendor_id               NUMBER := NULL;
        ln_vendor_site_id          NUMBER := NULL;
        ld_need_by_date            VARCHAR2 (20) := NULL;
        lv_company                 VARCHAR2 (100);
        lv_brand                   VARCHAR2 (100);
        lv_geo                     VARCHAR2 (100);
        lv_channel                 VARCHAR2 (100);
        lv_cost_center             VARCHAR2 (100);
        lv_account                 VARCHAR2 (100);
        lv_interco                 VARCHAR2 (100);
        lv_future                  VARCHAR2 (100);
        ln_ccid                    NUMBER;
        ln_deliver_loc_id          NUMBER;
        ln_dest_organization_id    NUMBER;
        lv_return_status           VARCHAR2 (1) := NULL;
        ln_requisition_header_id   po_requisition_headers_all.requisition_header_id%TYPE;
        ln_requisition_line_id     po_requisition_lines_all.requisition_line_id%TYPE;
        ln_req_preparer_id         NUMBER;
        le_webadi_exception        EXCEPTION;
        l_progress                 VARCHAR2 (4);
        l_msg_data                 VARCHAR2 (2000);
        l_msg_count                NUMBER;
        l_return_status            VARCHAR2 (1);
        l_update_person            VARCHAR2 (200);
        l_old_preparer_id          NUMBER;
        l_new_preparer_id          NUMBER;
        l_document_type            VARCHAR2 (200);
        l_document_no_from         VARCHAR2 (200);
        l_document_no_to           VARCHAR2 (200);
        l_date_from                VARCHAR2 (200);
        l_date_to                  VARCHAR2 (200);
        l_commit_interval          NUMBER;
        x_date_from                DATE;
        x_date_to                  DATE;
        l_req_line                 po_requisition_update_pub.req_line_rec_type;
        lv_error_msg               VARCHAR2 (4000);
        lv_asset_expense           VARCHAR2 (100);
        ln_valid_org_id            NUMBER;
        ln_nt_req_count            NUMBER;
    --         ln_req_preparer_id       NUMBER;
    BEGIN
        --        SELECT XXDO.XXD_ICX_POREQ_REQ_S.nextval
        --        INTO gn_request_id from dual ; --
        -- Mandatory Columns validation

        IF pv_requisition_num IS NOT NULL
        THEN
            lv_error_message   := NULL;

            IF pn_cart_line_num IS NULL OR pv_operating_unit IS NULL
            THEN
                lv_error_message   :=
                    'Cart line Num and Operaing Unit are Mandatory. One or more mandatory columns are missing. ';
                RAISE le_webadi_exception;
            END IF;

            -- Validating OU

            BEGIN
                SELECT organization_id
                  INTO ln_org_id
                  FROM apps.hr_operating_units
                 WHERE UPPER (name) = UPPER (pv_operating_unit);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'Invalid Operating Unit: '
                        || pv_operating_unit
                        || '. ';
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating Operaing Unit: '
                            || pv_operating_unit
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;


            IF ln_org_id IS NOT NULL
            THEN
                -- After getting OU, Check whether spread sheet has OU related to responsibility

                BEGIN
                    SELECT hou.organization_id
                      INTO ln_valid_org_id
                      FROM apps.hr_organization_units hou, apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov,
                           apps.fnd_responsibility_vl frv, apps.per_security_profiles psp
                     WHERE     1 = 1
                           AND frv.responsibility_id = fnd_global.resp_id
                           AND fpov.level_value = frv.responsibility_id
                           AND UPPER (frv.responsibility_name) LIKE
                                   'DECKERS IPROCUREMENT%'
                           AND fpo.profile_option_id = fpov.profile_option_id
                           AND fpo.user_profile_option_name =
                               'MO: Security Profile'
                           AND fpov.profile_option_id = fpo.profile_option_id
                           AND psp.security_profile_id =
                               fpov.profile_option_value
                           AND hou.name = psp.security_profile_name;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || ' Please select valid IProcurement responsibility ';
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || ' Exception while selecting responsibility - '
                            || SUBSTR (SQLERRM, 1, 200);
                END;

                IF ln_valid_org_id IS NOT NULL
                THEN
                    IF ln_org_id <> ln_valid_org_id
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || ' - '
                            || ' OU selected is different than that is available in Spread Sheet ';
                    END IF;
                END IF;

                -- Once OU is validated, get req id based on req number

                BEGIN
                    SELECT requisition_header_id
                      INTO ln_requisition_header_id
                      FROM apps.po_requisition_headers_all
                     WHERE     segment1 = pv_requisition_num
                           AND org_id = ln_org_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || 'Invalid Requisition : '
                            || pv_requisition_num
                            || 'With OU : '
                            || pv_operating_unit;
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating exisiting requisition number : '
                                || pv_requisition_num
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;

                -- Validating req line number is valid

                BEGIN
                    SELECT pn_cart_line_num / 1
                      INTO ln_cart_line_num
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating Cart Num: '
                                || pn_cart_num
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;

                -- once req header and line are valid then using them to get req line ID

                IF ln_requisition_header_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT requisition_line_id, quantity, unit_price,
                               Category_id, currency_code
                          INTO ln_requisition_line_id, ln_quantity, ln_unit_price, ln_category_id,
                                                     lv_currency_code
                          FROM apps.po_requisition_lines_all
                         WHERE     requisition_header_id =
                                   ln_requisition_header_id
                               AND line_num = pn_cart_line_num;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_error_message   :=
                                   lv_error_message
                                || '*****'
                                || 'Requisition line is not found for given Req : '
                                || pv_requisition_num
                                || 'Within OU : '
                                || pv_operating_unit
                                || 'With line num : '
                                || pn_cart_line_num;
                        WHEN OTHERS
                        THEN
                            lv_error_message   :=
                                SUBSTR (
                                       lv_error_message
                                    || '*****'
                                    || 'Error While fetching requisition line id for  : '
                                    || pv_requisition_num
                                    || ' with line num '
                                    || pn_cart_line_num
                                    || ' with in OU '
                                    || pv_operating_unit
                                    || '. '
                                    || SQLERRM
                                    || '. ',
                                    1,
                                    2000);
                    END;


                    -- Validate the requisition should be Non Trade only if category_id IS NOT NULL

                    IF ln_category_id IS NOT NULL
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO ln_nt_req_count
                              FROM apps.mtl_categories_kfv mc
                             WHERE     mc.category_id = ln_category_id
                                   AND mc.segment1 = 'Non-Trade'
                                   AND NVL (mc.enabled_flag, 'N') = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           mc.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           mc.end_date_active,
                                                           SYSDATE);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_message   :=
                                    SUBSTR (
                                           lv_error_message
                                        || '*****'
                                        || 'Error validating requisition classificatoin  : '
                                        || pv_requisition_num
                                        || ' with line num '
                                        || pn_cart_line_num
                                        || ' with in OU '
                                        || pv_operating_unit
                                        || '. '
                                        || SQLERRM
                                        || '. ',
                                        1,
                                        2000);
                        END;

                        IF ln_nt_req_count <> 1
                        THEN
                            lv_error_message   :=
                                SUBSTR (
                                       lv_error_message
                                    || '*****'
                                    || 'You can update only active Non Trade requisitions only  : Please check '
                                    || pv_requisition_num
                                    || ' with line num '
                                    || pn_cart_line_num
                                    || ' with in OU '
                                    || pv_operating_unit
                                    || '. ',
                                    1,
                                    2000);
                        END IF;
                    END IF;



                    IF NVL (pn_quantity, 0) < ln_quantity
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || ' Cannot decrease the existing quantity ';
                    ELSE
                        ln_quantity   := NVL (pn_quantity, ln_quantity);
                    END IF;

                    IF NVL (pn_unit_price, 0) < ln_unit_price
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || ' Cannot decrease the Unit Price of a item ';
                    ELSE
                        ln_unit_price   := NVL (pn_unit_price, ln_unit_price);
                    END IF;



                    lv_asset_expense   :=
                        check_expense_or_asset (ln_unit_price,
                                                ln_category_id,
                                                lv_currency_code);

                    IF lv_asset_expense = 'Asset'
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || ' Cannot convert the Expense item to Asset ';
                    END IF;
                END IF;                                        -- End Req line

                -- there is a chance that req. can be updated by a person other than preparer, so taking care by updating with new preparer.

                IF     ln_requisition_header_id IS NOT NULL
                   AND ln_requisition_line_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT preparer_id
                          INTO ln_req_preparer_id
                          FROM po_requisition_headers_all a, po_requisition_lines_all b
                         WHERE     a.requisition_header_id =
                                   b.requisition_header_id
                               AND b.requisition_line_id =
                                   ln_requisition_line_id
                               AND a.org_id = ln_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_message   :=
                                   lv_error_message
                                || '*****'
                                || 'Unable to derive Preparer id for requisition '
                                || pv_requisition_num;
                    END;
                END IF;

                IF     ln_requisition_header_id IS NOT NULL
                   AND ln_requisition_line_id IS NOT NULL
                THEN
                    NULL;
                END IF;
            END IF;

            -- Check Errors
            IF lv_error_message IS NOT NULL
            THEN
                RAISE le_webadi_exception;
            -- Call API
            ELSE
                mo_global.init ('PO');
                mo_global.set_policy_context ('S', ln_org_id);
                fnd_global.apps_initialize (user_id        => gn_user_id,
                                            resp_id        => gn_resp_id,
                                            resp_appl_id   => gn_resp_appl_id);

                l_req_line.requisition_header_id   :=
                    ln_requisition_header_id;
                l_req_line.requisition_line_id   := ln_requisition_line_id;
                l_req_line.org_id                := ln_org_id;
                l_req_line.unit_price            := pn_unit_price;
                l_req_line.quantity              := pn_quantity;
                l_req_line.ITEM_DESCRIPTION      := pv_item_desc;
                --l_req_line.vendor_id := ln_vendor_id;
                --l_req_line.vendor_site_id := ln_vendor_site_id;
                l_req_line.action_flag           := 'UPDATE';

                /**Begin Changes:  ver 1.1  update  preparer id with buyer id i.e. the current person using this webadi at this moment with an assumption that only buyer has acccess to this webadi **/

                IF fnd_global.employee_id <> ln_req_preparer_id
                THEN
                    -- if the preparer on this PR is not logged in user then only call this; and also this will avoid duplicate call of below code if the preparer has already been updated in the first call

                    l_update_person      := 'PREPARER';
                    l_old_preparer_id    := ln_req_preparer_id; -- person id of  current preparer
                    l_new_preparer_id    := fnd_global.EMPLOYEE_ID; -- Pass New Person Id
                    l_document_type      := 'PURCHASE';
                    l_document_no_from   := pv_requisition_num; -- keeping to and from PR number as same
                    l_document_no_to     := pv_requisition_num; -- keeping to and from PR number as same
                    l_commit_interval    := 100000000; -- keeping it higher so that below API wont commit by its own. API has logic to compre l_commit_interval with NO of eligble records and then commit.
                    x_date_from          := TO_DATE (NULL);
                    x_date_to            := TO_DATE (NULL);
                    -- we dont have any pub API to update preparer_id and the same is not updatable using po_requisition_update_pub.update_requisition_line, so using below API after taking consent from Srini.
                    PO_Mass_Update_Req_GRP.Update_Persons (
                        p_update_person      => l_update_person,
                        p_old_personid       => l_old_preparer_id,
                        p_new_personid       => l_new_preparer_id,
                        p_document_type      => l_document_type,
                        p_document_no_from   => l_document_no_from,
                        p_document_no_to     => l_document_no_to,
                        p_date_from          => x_date_from,
                        p_date_to            => x_date_to,
                        p_commit_interval    => l_commit_interval,
                        p_msg_data           => l_msg_data,
                        p_msg_count          => l_msg_count,
                        p_return_status      => l_return_status);

                    IF l_return_status <> g_ret_success
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || SUBSTR (lv_error_message, 1, 3900);
                        RAISE le_webadi_exception;
                    END IF;
                END IF;

                /**End Chnages:  ver 1.1  update  preparer id with buyer id**/

                po_requisition_update_pub.update_requisition_line (
                    p_req_line          => l_req_line,
                    p_init_msg          => fnd_api.g_false,
                    p_submit_approval   => 'Y', -- ver 1.1 submit for approval
                    x_return_status     => lv_return_status,
                    x_error_msg         => lv_error_msg,
                    p_commit            => 'N');

                IF lv_return_status <> g_ret_success
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || SUBSTR (lv_error_msg, 1, 3900);
                    RAISE le_webadi_exception;
                END IF;
            END IF;
        ELSE
            IF    pn_cart_num IS NULL
               OR pn_cart_line_num IS NULL
               OR pv_operating_unit IS NULL
               OR pv_po_item_cat IS NULL
               OR pv_item_type IS NULL
               OR pv_requester IS NULL
               OR pv_vendor_name IS NULL
               OR pv_vendor_site IS NULL
               OR pv_justification IS NULL
            THEN
                lv_error_message   :=
                    'Cart Num,Cart line Num,Operaing Unit,PO Item Category, Requestor, Vendor Name, Vendor Site and Justification are Mandatory. One or more mandatory columns are missing. ';
                RAISE le_webadi_exception;
            END IF;

            -- Operating Unit Validation

            BEGIN
                SELECT organization_id
                  INTO ln_org_id
                  FROM apps.hr_operating_units
                 WHERE UPPER (name) = UPPER (pv_operating_unit);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'Invalid Operating Unit: '
                        || pv_operating_unit
                        || '. ';
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating Operaing Unit: '
                            || pv_operating_unit
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            -- After getting OU, Check whether spread sheet has OU related to responsibility

            BEGIN
                SELECT hou.organization_id
                  INTO ln_valid_org_id
                  FROM apps.hr_organization_units hou, apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov,
                       apps.fnd_responsibility_vl frv, apps.per_security_profiles psp
                 WHERE     1 = 1
                       AND frv.responsibility_id = fnd_global.resp_id
                       AND fpov.level_value = frv.responsibility_id
                       AND UPPER (frv.responsibility_name) LIKE
                               'DECKERS IPROCUREMENT%'
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpo.user_profile_option_name =
                           'MO: Security Profile'
                       AND fpov.profile_option_id = fpo.profile_option_id
                       AND psp.security_profile_id =
                           fpov.profile_option_value
                       AND hou.name = psp.security_profile_name;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || ' Please select valid IProcurement responsibility ';
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || ' Exception while selecting responsibility - '
                        || SUBSTR (SQLERRM, 1, 200);
            END;

            IF ln_valid_org_id IS NOT NULL
            THEN
                IF ln_org_id <> ln_valid_org_id
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || ' - '
                        || ' OU selected is different than that is available in Spread Sheet ';
                END IF;
            END IF;

            -- Validate Cart Num and Cart Line Num

            BEGIN
                SELECT pn_cart_num / 1 INTO ln_cart_num FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating Cart Num: '
                            || pn_cart_num
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            BEGIN
                SELECT pn_cart_line_num / 1 INTO ln_cart_line_num FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating Cart Num: '
                            || pn_cart_num
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            -- Validate Category ID

            BEGIN
                SELECT category_id
                  INTO ln_category_id
                  FROM apps.mtl_categories_kfv mc, apps.fnd_id_flex_structures cat_str
                 WHERE     cat_str.id_flex_structure_code =
                           'PO_ITEM_CATEGORY'
                       AND cat_str.id_flex_num = mc.structure_id
                       AND mc.segment1 = 'Non-Trade'
                       AND mc.concatenated_segments = pv_po_item_cat
                       AND NVL (mc.enabled_flag, 'N') = 'Y'
                       AND SYSDATE BETWEEN NVL (mc.start_date_active,
                                                SYSDATE)
                                       AND NVL (mc.end_date_active, SYSDATE);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'Invalid Category : '
                        || pv_po_item_cat
                        || '. ';
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating Category: '
                            || pv_po_item_cat
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            IF ln_category_id IS NOT NULL
            THEN
                BEGIN
                    SELECT attribute9
                      INTO lv_po_item_class
                      FROM apps.mtl_categories_kfv
                     WHERE category_id = ln_category_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_po_item_class   := NULL;
                END;
            END IF;

            -- Validate PO Item Type

            BEGIN
                SELECT lookup_code
                  INTO lv_item_type
                  FROM apps.fnd_lookup_values flv
                 WHERE     1 = 1
                       AND flv.lookup_type = 'POR_ITEM_TYPE'
                       AND flv.language = 'US'
                       AND flv.enabled_flag = 'Y'
                       AND UPPER (flv.meaning) = UPPER (pv_item_type)
                       AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                SYSDATE)
                                       AND NVL (flv.end_date_active, SYSDATE);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'Invalid PO Item Type : '
                        || pv_item_type
                        || '. ';
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating PO Item Type: '
                            || pv_item_type
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            -- Validate Requestor

            BEGIN
                SELECT papf.person_id
                  INTO ln_person_id
                  FROM per_all_people_f papf
                 WHERE     UPPER (papf.full_name) LIKE UPPER (pv_requester)
                       AND SYSDATE BETWEEN NVL (papf.effective_start_date,
                                                SYSDATE - 1)
                                       AND NVL (papf.effective_end_date,
                                                SYSDATE + 1);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'Invalid Requestor : '
                        || pv_requester
                        || '. ';
                WHEN TOO_MANY_ROWS
                THEN
                    SELECT person_id
                      INTO ln_person_id
                      FROM (  SELECT papf.person_id
                                FROM per_all_people_f papf
                               WHERE     UPPER (papf.full_name) LIKE
                                             UPPER (pv_requester)
                                     AND SYSDATE BETWEEN NVL (
                                                             papf.effective_start_date,
                                                             SYSDATE - 1)
                                                     AND NVL (
                                                             papf.effective_end_date,
                                                             SYSDATE + 1)
                            ORDER BY effective_start_date DESC)
                     WHERE ROWNUM = 1;
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating Requestor : '
                            || pv_requester
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            -- Validate Quantity

            IF pn_quantity IS NOT NULL
            THEN
                BEGIN
                    SELECT pn_quantity / 1 INTO ln_quantity FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating Quantity: '
                                || pn_quantity
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;
            END IF;

            -- Validate Unit of Measure

            IF pv_uom IS NOT NULL
            THEN
                BEGIN
                    SELECT DISTINCT mum.uom_code
                      INTO lv_uom_code
                      FROM mtl_uom_conversions_val_v muc, mtl_units_of_measure mum
                     WHERE     1 = 1
                           AND muc.unit_of_measure = mum.unit_of_measure
                           AND UPPER (muc.unit_of_measure) = UPPER (pv_uom);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || 'Invalid UOM : '
                            || pv_uom
                            || '. ';
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating UOM : '
                                || pv_uom
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;
            END IF;

            -- Validate Unit Price

            IF pn_unit_price IS NOT NULL
            THEN
                BEGIN
                    SELECT pn_unit_price / 1 INTO ln_unit_price FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating Unit Price: '
                                || pn_unit_price
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;
            END IF;

            -- Validate Amount

            IF pn_amount IS NOT NULL
            THEN
                BEGIN
                    SELECT pn_amount / 1 INTO ln_amount FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating Unit Price: '
                                || pn_amount
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;
            END IF;

            -- Validate Currency Code

            BEGIN
                SELECT currency_code
                  INTO lv_currency_code
                  FROM apps.fnd_currencies
                 WHERE UPPER (currency_code) = UPPER (pv_currency);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'Invalid Currency Code : '
                        || pv_currency
                        || '. ';
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating Currency Code : '
                            || pv_currency
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            -- Validate Supplier Name

            BEGIN
                SELECT vendor_id
                  INTO ln_vendor_id
                  FROM apps.ap_suppliers
                 WHERE UPPER (vendor_name) = UPPER (pv_vendor_name);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'Invalid Vendor Name : '
                        || pv_vendor_name
                        || '. ';
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Error While Validating Vendor Name : '
                            || pv_vendor_name
                            || ' '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            -- Validate Supplier Site

            IF ln_vendor_id IS NOT NULL AND ln_org_id IS NOT NULL
            THEN
                BEGIN
                    SELECT vendor_site_id
                      INTO ln_vendor_site_id
                      FROM apps.ap_supplier_sites_all
                     WHERE     UPPER (vendor_site_code) =
                               UPPER (pv_vendor_site)
                           AND NVL (inactive_date, SYSDATE + 1) > SYSDATE
                           AND vendor_id = ln_vendor_id
                           AND org_id = ln_org_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || 'Invalid Vendor Site : '
                            || pv_vendor_site
                            || '. ';
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating Vendor Site : '
                                || pv_vendor_site
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;
            ELSE
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || '*****'
                        || ' Vendor Site can be derived only for valid Vendors, Please check OU and Vendor',
                        1,
                        2000);
            END IF;

            -- Need by Date validation

            BEGIN
                SELECT TO_CHAR (TO_DATE (pd_need_by_date, 'DD-MM-YYYY'), 'DD-MON-YYYY')
                  INTO ld_need_by_date
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Need By Date Not In DD-MON-YYYY Format '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            IF ld_need_by_date <> pd_need_by_date
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || '*****'
                        || 'Need By Date Not In DD-MON-YYYY Format',
                        1,
                        2000);
            END IF;

            --Need By Date Validation
            IF ld_need_by_date = pd_need_by_date
            THEN
                IF TO_DATE (pd_need_by_date, 'DD-MON-YYYY') < TRUNC (SYSDATE)
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || 'Need By Date must be greater than or equal to sysdate. ',
                            1,
                            2000);
                END IF;
            END IF;

            -- Validate Charge Account

            IF     pv_charge_account IS NOT NULL
               AND LENGTH (NVL (pv_charge_account, 0)) <> 36
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || '*****'
                        || 'Charge account is not in proper format. Please check',
                        1,
                        2000);
            ELSIF     pv_charge_account IS NOT NULL
                  AND LENGTH (NVL (pv_charge_account, 0)) = 36
            THEN
                BEGIN
                    NULL;

                    SELECT segment1, segment2, segment3,
                           segment4, segment5, segment6,
                           segment7, segment8, code_combination_id
                      INTO lv_company, lv_brand, lv_geo, lv_channel,
                                     lv_cost_center, lv_account, lv_interco,
                                     lv_future, ln_ccid
                      FROM apps.gl_code_combinations_kfv
                     WHERE     enabled_flag = 'Y'
                           AND concatenated_segments = pv_charge_account;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || 'Invalid Charge Account : '
                            || pv_charge_account
                            || '. ';
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating Charge account : '
                                || pv_charge_account
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;
            END IF;

            -- Validate Deliver to Location Code

            IF pv_deliver_to_loc IS NOT NULL
            THEN
                BEGIN
                    SELECT location_id
                      INTO ln_deliver_loc_id
                      FROM hr_locations
                     WHERE     1 = 1
                           AND NVL (inactive_date, SYSDATE + 1) > SYSDATE
                           AND UPPER (location_code) =
                               UPPER (pv_deliver_to_loc);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || '*****'
                            || 'Invalid Deliver to location code : '
                            || pv_deliver_to_loc
                            || '. ';
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error While Validating Deliver to location code : '
                                || pv_deliver_to_loc
                                || ' '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;

                IF ln_deliver_loc_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT hrl.inventory_organization_id
                          INTO ln_dest_organization_id
                          FROM hr_locations hrl
                         WHERE     hrl.location_id = ln_deliver_loc_id
                               AND EXISTS
                                       (SELECT 1
                                          FROM apps.mtl_parameters mp
                                         WHERE     mp.organization_id =
                                                   hrl.inventory_organization_id
                                               AND mp.attribute13 = 1);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_error_message   :=
                                   lv_error_message
                                || '*****'
                                || 'Destination Organization doesnot exist for Deliver to Loc : '
                                || pv_deliver_to_loc
                                || '. ';
                        WHEN OTHERS
                        THEN
                            lv_error_message   :=
                                SUBSTR (
                                       lv_error_message
                                    || '*****'
                                    || 'Exception while getting Destination Organization for Deliver to Loc : '
                                    || pv_deliver_to_loc
                                    || ' '
                                    || SQLERRM
                                    || '. ',
                                    1,
                                    2000);
                    END;
                END IF;
            END IF;

            IF lv_error_message IS NULL
            THEN
                BEGIN
                    SELECT xxdo.xxd_icx_poreq_stg_s.NEXTVAL record_id
                      INTO ln_record_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || 'Error in generating Record ID from Sequence. Error is: '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;
            END IF;

            IF lv_error_message IS NULL
            THEN
                BEGIN
                    INSERT INTO xxdo.xxd_icx_poreq_stg_t (
                                    record_id,
                                    cart_num,
                                    cart_line_num,
                                    operating_unit,
                                    po_item_cat,
                                    item_type,
                                    item_desc,
                                    requester,
                                    quantity,
                                    uom,
                                    unit_price,
                                    amount,
                                    currency,
                                    vendor_name,
                                    vendor_site,
                                    need_by_date,
                                    charge_account,
                                    deliver_to_loc,
                                    justification,
                                    record_status,
                                    error_message,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    last_update_login,
                                    request_id,
                                    org_id,
                                    po_item_cat_id,
                                    requester_id,
                                    vendor_id,
                                    vendor_site_id,
                                    charge_account_ccid,
                                    deliver_to_loc_id,
                                    dest_organization_id,
                                    gl_company,
                                    gl_brand,
                                    gl_geo,
                                    gl_channel,
                                    gl_cost_center,
                                    gl_account,
                                    gl_interco,
                                    gl_future,
                                    po_item_cat_class)
                         VALUES (ln_record_id, pn_cart_num, pn_cart_line_num,
                                 pv_operating_unit, pv_po_item_cat, pv_item_type, pv_item_desc, pv_requester, pn_quantity, lv_uom_code, pn_unit_price, pn_amount, pv_currency, pv_vendor_name, pv_vendor_site, pd_need_by_date, pv_charge_account, pv_deliver_to_loc, pv_justification, 'N', NULL, TRUNC (SYSDATE), gn_user_id, TRUNC (SYSDATE), gn_user_id, gn_login_id, -1, --gn_request_id,
                                                                                                                                                                                                                                                                                                                                                                              ln_org_id, ln_category_id, ln_person_id, ln_vendor_id, ln_vendor_site_id, ln_ccid, ln_deliver_loc_id, ln_dest_organization_id, lv_company, lv_brand, lv_geo, lv_channel, lv_cost_center, lv_account, lv_interco
                                 , lv_future, lv_po_item_class);
                --COMMIT;

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || ' Error while inserting into staging table: '
                                || SQLERRM,
                                1,
                                2000);
                        RAISE le_webadi_exception;
                END;
            ELSE
                RAISE le_webadi_exception;
            END IF;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            lv_error_message   := SUBSTR (lv_error_message, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_PR_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_PR_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
    END upload_proc;

    PROCEDURE validate_staging (pn_request_id    IN     NUMBER,
                                pv_ret_message      OUT VARCHAR2)
    IS
        CURSOR stg_cur IS
            SELECT *
              FROM xxdo.xxd_icx_poreq_stg_t
             WHERE request_id = pn_request_id AND record_status = 'N';

        CURSOR stg_dist_rec IS
              SELECT cart_num
                FROM xxdo.xxd_icx_poreq_stg_t
               WHERE request_id = pn_request_id
            GROUP BY cart_num;

        lv_valid_company        VARCHAR2 (100) := NULL;
        --      lv_valid_cost_center    VARCHAR2 (100) := NULL;
        lv_valid_account        VARCHAR2 (100) := NULL;
        lv_cc_val               VARCHAR2 (100) := NULL;
        lv_asset_expense        VARCHAR2 (100) := NULL;
        lv_cogs_account         VARCHAR2 (100) := NULL;
        lv_exp_account          VARCHAR2 (100) := NULL;
        lv_final_account        VARCHAR2 (100) := NULL;
        lv_error_message        VARCHAR2 (4000) := NULL;
        lv_error_message1       VARCHAR2 (4000) := NULL;
        lv_record_status        VARCHAR2 (10) := NULL;
        lv_record_status1       VARCHAR2 (10) := NULL;
        ln_count                NUMBER;
        ln_batch_id             NUMBER;
        ln_req_count            NUMBER := NULL;
        ln_vendor_count         NUMBER := NULL;
        ln_site_count           NUMBER := NULL;
        ln_need_by_date_count   NUMBER := NULL;
        ln_del_to_loc_count     NUMBER := NULL;
        ln_line_count           NUMBER := NULL;
        ln_po_class_count       NUMBER := NULL;
        ln_cost_center          NUMBER := NULL;
        ln_req_id               NUMBER := NULL;
        lv_resp_name            VARCHAR2 (240) := NULL;
        l_req_valid             VARCHAR2 (100);
        l_emp_id                NUMBER;
        l_emp_name              VARCHAR2 (240);
        l_cc                    VARCHAR2 (100);
        l_req                   VARCHAR2 (100);
    BEGIN
        -- Open the cursor to validate the Staging records.

        FOR rec IN stg_cur
        LOOP
            lv_valid_company    := NULL;
            --         lv_valid_cost_center := NULL;
            lv_valid_account    := NULL;
            lv_asset_expense    := NULL;
            lv_record_status    := NULL;
            lv_cc_val           := NULL;
            lv_cogs_account     := NULL;
            lv_exp_account      := NULL;
            lv_final_account    := NULL;
            lv_error_message    := NULL;
            lv_error_message1   := NULL;
            ln_cost_center      := NULL;
            ln_req_id           := NULL;
            lv_resp_name        := NULL;
            l_req_valid         := NULL;
            l_emp_id            := NULL;
            l_emp_name          := NULL;
            l_cc                := NULL;
            l_req               := NULL;

            --ln_batch_id := NULL;

            BEGIN
                SELECT responsibility_name
                  INTO lv_resp_name
                  FROM apps.fnd_responsibility_vl
                 WHERE responsibility_id = fnd_global.resp_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_resp_name   := NULL;
            END;

            BEGIN
                -- Validate the Company segment based on Operating Unit

                IF rec.org_id IS NOT NULL AND rec.gl_company IS NOT NULL
                THEN
                    lv_valid_company   := get_company_segment (rec.org_id);

                    IF lv_valid_company = rec.gl_company
                    THEN
                        lv_valid_company   := rec.gl_company;
                    ELSE
                        lv_record_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || ' Company provided : '
                                || rec.gl_company
                                || ' is not aligned with Operating Unit : '
                                || rec.operating_unit,
                                1,
                                2000);
                    END IF;
                ELSE
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || ' Company and Operating unit should be valid for Company segment validation : ',
                            1,
                            2000);
                END IF;


                -- Check the requisition line is Asset/Expense

                IF     rec.unit_price IS NOT NULL
                   AND rec.currency IS NOT NULL
                   AND rec.po_item_cat_id IS NOT NULL
                THEN
                    lv_asset_expense   :=
                        check_expense_or_asset (rec.unit_price,
                                                rec.po_item_cat_id,
                                                rec.currency);

                    IF lv_asset_expense = 'Asset'
                    THEN
                        lv_record_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || ' Assets are not allowed to upload, please check ',
                                1,
                                2000);
                    ELSIF lv_asset_expense = 'Expense'
                    THEN
                        NULL;
                    END IF;
                ELSE
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || ' Unit Price, Currency, Category ID should be valid for Asset/Expense validation : ',
                            1,
                            2000);
                END IF;

                -- Get the Preparer or requester if Preparer is not in per_all_people_f

                IF    fnd_global.user_id IS NOT NULL
                   OR rec.requester_id IS NOT NULL
                THEN
                    l_emp_id     := NULL;
                    l_emp_name   := NULL;

                    BEGIN
                        SELECT fu.employee_id, papf.full_name
                          INTO l_emp_id, l_emp_name
                          FROM apps.fnd_user fu, apps.per_all_people_f papf
                         WHERE     1 = 1
                               AND papf.person_id = fu.employee_id
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                 papf.effective_start_date
                                                               - 1)
                                                       AND TRUNC (
                                                                 papf.effective_end_date
                                                               + 1)
                               AND user_id = fnd_global.user_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            l_emp_id     := rec.requester_id;
                            l_emp_name   := rec.requester;
                        WHEN OTHERS
                        THEN
                            lv_record_status   := g_ret_error;
                            lv_error_message   :=
                                SUBSTR (
                                       lv_error_message
                                    || '*****'
                                    || ' When Others Exception in Finding user for the requester: - '
                                    || SQLERRM,
                                    1,
                                    2000);
                    END;

                    IF l_emp_id IS NOT NULL
                    THEN
                        l_cc    := NULL;
                        l_req   := NULL;
                        check_req_valid_prc (pn_resp_id => fnd_global.resp_id, pn_requester_id => l_emp_id, x_cc => l_cc
                                             , x_req => l_req);

                        IF l_cc IS NULL AND l_req IS NOT NULL
                        THEN
                            lv_record_status   := g_ret_error;
                            lv_error_message   :=
                                SUBSTR (
                                       lv_error_message
                                    || '*****'
                                    || ' Restriction in Valueset, WEBADI cannot be accessed by Preparer/Requester : - '
                                    || l_emp_name,
                                    1,
                                    2000);
                        END IF;
                    END IF;
                END IF;

                -- Validate Cost Center

                IF rec.requester_id IS NOT NULL
                THEN
                    get_cost_center (pn_resp_id        => fnd_global.resp_id,
                                     pn_requester_id   => rec.requester_id,
                                     pn_cc             => rec.gl_cost_center,
                                     x_cost_center     => ln_cost_center,
                                     x_person_id       => ln_req_id);

                    IF ln_cost_center IS NULL
                    THEN
                        NULL;
                    ELSIF     ln_cost_center IS NOT NULL
                          AND ln_cost_center = rec.gl_cost_center
                          AND ln_req_id IS NULL
                    THEN
                        lv_record_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || ' You cannot use this Cost Center for this responsibility : - '
                                || lv_resp_name,
                                1,
                                2000);
                    ELSIF     ln_cost_center IS NOT NULL
                          AND ln_cost_center = rec.gl_cost_center
                          AND ln_req_id IS NOT NULL
                          AND ln_req_id = rec.requester_id
                    THEN
                        lv_record_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || '*****'
                                || ' You cannot use this Cost Center with this requester : - '
                                || rec.requester,
                                1,
                                2000);
                    END IF;
                --               lv_valid_cost_center := validate_cost_center (rec.requester_id);
                --
                --               IF lv_valid_cost_center = rec.gl_cost_center
                --               THEN
                --                  lv_valid_cost_center := rec.gl_cost_center;
                --               ELSE
                --                  lv_record_status := g_ret_error;
                --                  lv_error_message :=
                --                     SUBSTR (
                --                           lv_error_message
                --                        || ' Cost Center is not as as per requester/supervisor : ',
                --                        1,
                --                        2000);
                --               END IF;
                ELSE
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || ' GL Cost Center has to ve valid for validation : ',
                            1,
                            2000);
                END IF;

                -- Validate Account

                IF lv_asset_expense = 'Expense'
                --AND ln_cost_center IS NULL--lv_valid_cost_center IS NOT NULL
                THEN
                    lv_cc_val   := SUBSTR (rec.gl_cost_center, 1, 1);

                    IF NVL (lv_cc_val, 'X') = '2'
                    THEN
                        BEGIN
                            SELECT attribute6
                              INTO lv_cogs_account
                              FROM apps.mtl_categories
                             WHERE     1 = 1
                                   AND attribute_category =
                                       'PO Mapping Data Elements'
                                   AND category_id = rec.po_item_cat_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_record_status   := g_ret_error;
                                lv_error_message   :=
                                    SUBSTR (
                                           lv_error_message
                                        || '*****'
                                        || ' There is no attribute6 assigned for Category : '
                                        || rec.po_item_cat,
                                        1,
                                        2000);
                        END;
                    ELSIF NVL (lv_cc_val, 'X') <> '2'
                    THEN
                        BEGIN
                            SELECT attribute5
                              INTO lv_exp_account
                              FROM apps.mtl_categories
                             WHERE     1 = 1
                                   AND attribute_category =
                                       'PO Mapping Data Elements'
                                   AND category_id = rec.po_item_cat_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_record_status   := g_ret_error;
                                lv_error_message   :=
                                    SUBSTR (
                                           lv_error_message
                                        || '*****'
                                        || ' There is no attribute5 assigned for Category : '
                                        || rec.po_item_cat,
                                        1,
                                        2000);
                        END;
                    END IF;

                    lv_final_account   :=
                        NVL (lv_cogs_account, lv_exp_account);

                    --- Now Check the value of account against the provided account segment
                    IF lv_final_account IS NOT NULL
                    THEN
                        IF rec.gl_account = lv_final_account
                        THEN
                            NULL;
                        ELSE
                            lv_record_status   := g_ret_error;
                            lv_error_message   :=
                                SUBSTR (
                                       lv_error_message
                                    || '*****'
                                    || ' The GL Account derived for Category : '
                                    || rec.po_item_cat
                                    || ' based on Cost Center: '
                                    || rec.gl_cost_center --lv_valid_cost_center
                                    || ' should be : '
                                    || lv_final_account,
                                    1,
                                    2000);
                        END IF;
                    END IF;
                END IF;
            END;


            IF lv_record_status IS NULL OR lv_error_message IS NULL
            THEN
                BEGIN
                    UPDATE xxdo.xxd_icx_poreq_stg_t
                       SET gl_valid_company = lv_valid_company, --gl_valid_cost_center = lv_valid_cost_center,
                                                                gl_valid_account = lv_final_account, asset_exp_type = lv_asset_expense,
                           record_status = g_ret_valid, error_message = lv_error_message
                     WHERE     request_id = gn_request_id
                           AND record_id = rec.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_ret_message   :=
                            SUBSTR (
                                   'Exception Error in Validate_Staging procedure while updating validated records'
                                || SQLERRM,
                                1,
                                2000);
                END;
            ELSE
                BEGIN
                    UPDATE xxdo.xxd_icx_poreq_stg_t
                       SET gl_valid_company = lv_valid_company, --                      gl_valid_cost_center = lv_valid_cost_center,
                                                                gl_valid_account = lv_final_account, asset_exp_type = lv_asset_expense,
                           record_status = g_ret_error, error_message = lv_error_message
                     WHERE     request_id = gn_request_id
                           AND record_id = rec.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_ret_message   :=
                            SUBSTR (
                                   'Exception Error in Validate_Staging procedure while updating error records'
                                || SQLERRM,
                                1,
                                2000);
                END;
            END IF;
        --      IF lv_error_message IS NOT NULL
        --      THEN
        --           RAISE le_webadi_exception;
        --      END IF;

        END LOOP;

        --- Validtong requester, batch_id based on grouping sequence

        FOR dist_rec IN stg_dist_rec
        LOOP
            lv_error_message        := NULL;
            lv_record_status        := NULL;
            ln_count                := NULL;
            ln_req_count            := NULL;
            ln_vendor_count         := NULL;
            ln_site_count           := NULL;
            ln_need_by_date_count   := NULL;
            ln_del_to_loc_count     := NULL;
            ln_line_count           := NULL;
            ln_po_class_count       := NULL;


            BEGIN
                SELECT COUNT (DISTINCT requester_id), COUNT (DISTINCT vendor_id), COUNT (DISTINCT vendor_site_id),
                       COUNT (DISTINCT need_by_date), COUNT (DISTINCT deliver_to_loc_id), COUNT (DISTINCT cart_line_num),
                       COUNT (DISTINCT po_item_cat_class)
                  INTO ln_req_count, ln_vendor_count, ln_site_count, ln_need_by_date_count,
                                   ln_del_to_loc_count, ln_count, ln_po_class_count
                  FROM xxdo.xxd_icx_poreq_stg_t
                 WHERE     request_id = pn_request_id
                       AND cart_num = dist_rec.cart_num;

                BEGIN
                    SELECT COUNT (cart_line_num)
                      INTO ln_line_count
                      FROM xxdo.xxd_icx_poreq_stg_t
                     WHERE     request_id = pn_request_id
                           AND cart_num = dist_rec.cart_num;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_line_count   := 0;
                END;



                IF NVL (ln_req_count, 0) > 1
                THEN
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'There cannot be more than one requester per cart '
                        || dist_rec.cart_num;
                END IF;

                IF NVL (ln_vendor_count, 0) > 1
                THEN
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'There cannot be more than one vendor per cart '
                        || dist_rec.cart_num;
                END IF;

                IF NVL (ln_site_count, 0) > 1
                THEN
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'There cannot be more than one vendor site per cart '
                        || dist_rec.cart_num;
                END IF;

                IF NVL (ln_need_by_date_count, 0) > 1
                THEN
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'There cannot be more than one Need by date per cart '
                        || dist_rec.cart_num;
                END IF;

                IF NVL (ln_del_to_loc_count, 0) > 1
                THEN
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'There cannot be more than one Deliver to location per cart '
                        || dist_rec.cart_num;
                END IF;

                IF NVL (ln_count, 999) = NVL (ln_line_count, 998)
                THEN
                    NULL;
                ELSE
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'There cannot be duplicate cart line numbers per cart '
                        || dist_rec.cart_num;
                END IF;

                IF NVL (ln_po_class_count, 0) > 1
                THEN
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || '*****'
                        || 'There cannot be more than po category type per cart '
                        || dist_rec.cart_num;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || '*****'
                            || ' Exception occurred when validating one group by restrictions per cart '
                            || dist_rec.cart_num
                            || SQLERRM,
                            1,
                            2000);
            END;

            BEGIN
                --getting interface batch_id
                SELECT xxdo.xxd_icx_poreq_stg_bcth_s.NEXTVAL
                  INTO ln_batch_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_record_status   := g_ret_error;
                    lv_error_message   :=
                        SUBSTR (
                               'Error while getting seq id from XXD_PO_PR_UPD_STG_SNO. Error is: '
                            || SQLERRM,
                            1,
                            2000);
            END;

            IF lv_record_status IS NULL OR lv_error_message IS NULL
            THEN
                BEGIN
                    UPDATE xxdo.xxd_icx_poreq_stg_t
                       SET error_message = SUBSTR (error_message || '*****' || lv_error_message, 1, 2000), interface_batch_id = ln_batch_id
                     WHERE     request_id = pn_request_id
                           AND cart_num = dist_rec.cart_num;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_ret_message   :=
                            SUBSTR (
                                   'Exception Error in Validate_Staging procedure while updating validated records'
                                || SQLERRM,
                                1,
                                2000);
                END;
            ELSE
                BEGIN
                    UPDATE xxdo.xxd_icx_poreq_stg_t
                       SET record_status = g_ret_error, error_message = SUBSTR (error_message || '*****' || lv_error_message, 1, 2000), interface_batch_id = ln_batch_id
                     WHERE     request_id = pn_request_id
                           AND cart_num = dist_rec.cart_num;

                    pv_ret_message   := lv_error_message;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_ret_message   :=
                            SUBSTR (
                                   'Exception Error in Validate_Staging procedure while updating error records'
                                || SQLERRM,
                                1,
                                2000);
                END;
            END IF;



            -- How about updating the staging table with error record for requester records

            BEGIN
                UPDATE xxdo.xxd_icx_poreq_stg_t stg1
                   SET stg1.record_status = g_ret_error, stg1.process_message = SUBSTR ('Record cannot be processed as one or more records failed requisition grouping validation', 1, 2000)
                 WHERE     stg1.cart_num = dist_rec.cart_num
                       AND stg1.request_id = pn_request_id
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_icx_poreq_stg_t stg2
                                 WHERE     1 = 1
                                       --                                  AND stg1.record_id = stg2.record_id
                                       AND stg2.request_id = stg1.request_id
                                       AND stg1.cart_num = stg2.cart_num
                                       AND stg2.record_status = g_ret_error);

                --                                  AND stg2.request_id = pn_request_id);

                fnd_file.put_line (
                    fnd_file.LOG,
                    'No of records updated are :' || SQL%ROWCOUNT);

                IF SQL%ROWCOUNT > 0
                THEN
                    pv_ret_message   :=
                        'Record cannot be processed as one or more records failed requisition grouping validation';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_ret_message   :=
                        SUBSTR (
                               lv_error_message1
                            || '*****'
                            || 'Error in group_sequence_validation procedure while updating requisition grouping validation records'
                            || SQLERRM,
                            1,
                            2000);
            END;
        END LOOP;
    END validate_staging;

    PROCEDURE insert_into_interface_table (pv_error_message OUT VARCHAR2)
    IS
        lv_return_status   VARCHAR2 (1) := NULL;
        ln_person_id       NUMBER;
    BEGIN
        --Getting person_id of user
        BEGIN
            SELECT employee_id
              INTO ln_person_id
              FROM fnd_user
             WHERE user_id = gn_user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_return_status   := g_ret_error;
                pv_error_message   :=
                    SUBSTR (
                        'Error getting employee id. Error is: ' || SQLERRM,
                        1,
                        2000);
        END;

        INSERT INTO po_requisitions_interface_all (
                        interface_source_code,
                        requisition_type,
                        org_id,
                        authorization_status,
                        charge_account_id,
                        quantity,
                        uom_code,                           --Unit_of_measure,
                        group_code,
                        need_by_date,
                        preparer_id,
                        deliver_to_requestor_id,
                        source_type_code,
                        destination_type_code,
                        deliver_to_location_id,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by,
                        batch_id,
                        line_num,
                        suggested_vendor_id,
                        suggested_vendor_site_id,
                        --LINE_TYPE_ID,
                        category_id,
                        unit_price,
                        destination_organization_id,
                        ITEM_DESCRIPTION,
                        note_to_approver --                                                 ,amount
                                        )
            (SELECT 'NTWEBADI',                       -- interface_source_code
                                'PURCHASE',                -- Requisition_type
                                            org_id,
                    'INCOMPLETE',                      -- Authorization_Status
                                  charge_account_ccid, -- Destination org ccid
                                                       quantity,   -- Quantity
                    uom,                                           -- UOm Code
                         1,                                        -- Group_id
                            need_by_date,                     -- neeed by date
                    ln_person_id,                 -- Person id of the preparer
                                  requester_id,  -- Person_id of the requestor
                                                'VENDOR',  -- source_type_code
                    'EXPENSE',                        -- destination_type_code
                               deliver_to_loc_id,     --deliver to location id
                                                  SYSDATE,
                    gn_user_id, SYSDATE, gn_user_id,
                    interface_batch_id, cart_line_num, vendor_id,
                    vendor_site_id, --                 1,
                                    po_Item_cat_id, unit_price,
                    dest_organization_id, item_desc, justification
               --                 ,amount
               FROM xxdo.xxd_icx_poreq_stg_t stg
              WHERE     1 = 1
                    AND stg.request_id = gn_request_id
                    AND stg.record_status = g_ret_valid);
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_return_status   := g_ret_error;
            pv_error_message   :=
                SUBSTR (
                       'Error while inserting data into staging table. Error is: '
                    || SQLERRM,
                    1,
                    2000);
    END insert_into_interface_table;


    --   PROCEDURE submit_import_proc (--pn_person_id       IN       NUMBER,
    --                                 pv_error_message OUT VARCHAR2)
    PROCEDURE submit_import_proc (pn_request_id IN NUMBER)
    IS
        CURSOR cursor_interface_records (cv_request_id NUMBER)
        IS
              SELECT DISTINCT interface_batch_id, org_id
                FROM xxdo.xxd_icx_poreq_stg_t
               WHERE record_status = g_ret_valid AND request_id = cv_request_id
            ORDER BY org_id, interface_batch_id ASC;

        lv_error_message     VARCHAR2 (2000);
        lv_return_status     VARCHAR2 (1) := NULL;
        ln_request_id        NUMBER;
        lb_concreqcallstat   BOOLEAN := FALSE;
        lv_phasecode         VARCHAR2 (100) := NULL;
        lv_statuscode        VARCHAR2 (100) := NULL;
        lv_devphase          VARCHAR2 (100) := NULL;
        lv_devstatus         VARCHAR2 (100) := NULL;
        lv_returnmsg         VARCHAR2 (200) := NULL;
        ln_int_error_count   NUMBER;
        lv_error_stat        NUMBER;
        lv_error_msg         VARCHAR2 (4000);
    BEGIN
        FOR cursor_interface_rec IN cursor_interface_records (pn_request_id)
        LOOP
            ln_request_id   := NULL;
            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => gn_resp_id,
                                        resp_appl_id   => gn_resp_appl_id);
            mo_global.init ('PO');
            mo_global.set_policy_context ('S', cursor_interface_rec.org_id);
            fnd_request.set_org_id (cursor_interface_rec.org_id);
            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'PO',           -- application short name
                    program       => 'REQIMPORT',        -- program short name
                    description   => 'Requisition Import',      -- description
                    start_time    => SYSDATE,                    -- start date
                    sub_request   => FALSE,                     -- sub-request
                    argument1     => 'NTWEBADI',      -- interface source code
                    argument2     => cursor_interface_rec.interface_batch_id, -- Batch Id
                    argument3     => 'ALL',                        -- Group By
                    argument4     => NULL,          -- Last Requisition Number
                    argument5     => NULL,              -- Multi Distributions
                    argument6     => 'Y' -- Initiate Requisition Approval after Requisition Import
                                        );
            COMMIT;

            IF ln_request_id = 0
            THEN
                lv_return_status   := g_ret_error;
                lv_error_msg       :=
                    SUBSTR (
                           'Error while submitting requisition import. Error is: '
                        || SQLERRM,
                        1,
                        2000);
            ELSE
                LOOP
                    lb_concreqcallstat   :=
                        apps.fnd_concurrent.wait_for_request (ln_request_id,
                                                              5, -- wait 5 seconds between db checks
                                                              0,
                                                              lv_phasecode,
                                                              lv_statuscode,
                                                              lv_devphase,
                                                              lv_devstatus,
                                                              lv_returnmsg);
                    EXIT WHEN lv_devphase = 'COMPLETE';
                END LOOP;
            END IF;


            BEGIN
                SELECT COUNT (*)
                  INTO ln_int_error_count
                  FROM po_requisitions_interface_all
                 WHERE request_id = ln_request_id AND process_flag = 'ERROR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;


            IF ln_int_error_count > 0
            THEN
                --Updating error_records
                BEGIN
                    UPDATE xxdo.xxd_icx_poreq_stg_t stg
                       SET record_status   = g_ret_error,
                           error_message   =
                               NVL (
                                   (SELECT SUBSTR (REPLACE (error_message, CHR (10), ''), 1, 2000)
                                      FROM po_interface_errors ie, po_requisitions_interface_all rie
                                     WHERE     rie.transaction_id =
                                               ie.interface_transaction_id
                                           AND rie.request_id = ln_request_id
                                           AND ROWNUM = 1),
                                   'Requistion import error. Please check interface error table')
                     WHERE     stg.record_status = g_ret_valid
                           AND stg.request_id = pn_request_id
                           AND stg.interface_batch_id =
                               cursor_interface_rec.interface_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_msg   :=
                            SUBSTR (
                                   'Error while updating staging table with error records'
                                || SQLERRM,
                                1,
                                2000);
                END;
            ELSE
                BEGIN
                    UPDATE xxdo.xxd_icx_poreq_stg_t stg
                       SET record_status   = g_ret_success,
                           requisition_number   =
                               (SELECT segment1
                                  FROM po_requisition_headers_all prh
                                 WHERE prh.request_id = ln_request_id)
                     WHERE     1 = 1
                           AND stg.record_status = g_ret_valid
                           AND stg.request_id = pn_request_id
                           AND stg.interface_batch_id =
                               cursor_interface_rec.interface_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_msg   :=
                            SUBSTR (
                                   'Error while updating staging table with requisition number'
                                || SQLERRM,
                                1,
                                2000);
                END;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR ('Error in submit_import_proc' || SQLERRM, 1, 2000);
    END submit_import_proc;

    PROCEDURE status_report (pn_request_id          IN     NUMBER,
                             x_proc_error_message      OUT VARCHAR2)
    IS
        lv_inst_name   VARCHAR2 (30) := NULL;
        lv_msg         VARCHAR2 (4000) := NULL;
        ln_ret_val     NUMBER := 0;
        lv_out_line    VARCHAR2 (4000);

        CURSOR submitted_by_cur IS
            SELECT NVL (fu.email_address, ppx.email_address) email_id
              FROM fnd_user fu, per_people_x ppx
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE))
                   AND fu.employee_id = ppx.person_id(+);

        CURSOR status_rep IS
              SELECT stg.*                                     --,fu.user_name
                          , DECODE (stg.record_status,  'E', 'Error',  'S', 'Success',  'N', 'New',  'Error') status_desc
                FROM XXDO.XXD_ICX_POREQ_STG_T stg
               WHERE stg.request_id = pn_request_id
            ORDER BY stg.record_id;
    BEGIN
        BEGIN
            SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
              INTO lv_inst_name
              FROM fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inst_name   := '';
                x_proc_error_message   :=
                       'Error getting the instance name in send_email_proc procedure. Error is '
                    || SQLERRM;
        --raise_application_error (-20010, x_proc_error_message);
        END;


        FOR submitted_by_rec IN submitted_by_cur
        LOOP
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                submitted_by_rec.email_id;
        END LOOP;



        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;


        apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Deckers Non Trade Requisition Creation Upload Result. ' || ' Email generated from ' || lv_inst_name || ' instance'
                                             , ln_ret_val);

        do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);                 --Added
        do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);                 --Added
        --            do_mail_utils.send_mail_line ('Content-Type: text/plain', ln_ret_val); --Not Required
        --            do_mail_utils.send_mail_line ('', ln_ret_val); --Not Required
        do_mail_utils.send_mail_line (
            'Please see attached the result of the Deckers Non Trade Requisition Creation WEBADI Upload.',
            ln_ret_val);
        do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
        do_mail_utils.send_mail_line ('Content-Type: text/xls', ln_ret_val);
        do_mail_utils.send_mail_line (
               'Content-Disposition: attachment; filename="Deckers_NonTrade_Requisition_Upload_'
            || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
            || '.xls"',
            ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);

        apps.do_mail_utils.send_mail_line (
               'Cart Number'
            || CHR (9)
            || 'Cart Line Number'
            || CHR (9)
            || 'Operating Unit'
            || CHR (9)
            || 'PO Item Category'
            || CHR (9)
            || 'Item Type'
            || CHR (9)
            || 'Item Description'
            || CHR (9)
            || 'Requester'
            || CHR (9)
            || 'Quantity'
            || CHR (9)
            || 'UOM'
            || CHR (9)
            || 'Unit Price'
            || CHR (9)
            || 'Currency'
            || CHR (9)
            || 'Supplier'
            || CHR (9)
            || 'Supplier Site'
            || CHR (9)
            || 'Need By Date'
            || CHR (9)
            || 'Charge Account'
            || CHR (9)
            || 'Deliver to Loc'
            || CHR (9)
            || 'Justification'
            || CHR (9)
            || 'Requisition Number'
            || CHR (9)
            || 'Record Status'
            || CHR (9)
            || 'Error Message'
            || CHR (9)
            || 'Process Message'
            || CHR (9)
            || 'Request ID'
            || CHR (9),
            ln_ret_val);

        FOR status_rep_rec IN status_rep
        LOOP
            lv_out_line   := NULL;
            lv_out_line   :=
                   status_rep_rec.cart_num
                || CHR (9)
                || status_rep_rec.cart_line_num
                || CHR (9)
                || status_rep_rec.operating_unit
                || CHR (9)
                || status_rep_rec.po_item_cat
                || CHR (9)
                || status_rep_rec.item_type
                || CHR (9)
                || status_rep_rec.item_desc
                || CHR (9)
                || status_rep_rec.requester
                || CHR (9)
                || status_rep_rec.quantity
                || CHR (9)
                || status_rep_rec.UOM
                || CHR (9)
                || status_rep_rec.unit_price
                || CHR (9)
                || status_rep_rec.currency
                || CHR (9)
                || status_rep_rec.vendor_name
                || CHR (9)
                || status_rep_rec.vendor_site
                || CHR (9)
                || status_rep_rec.need_by_date
                || CHR (9)
                || status_rep_rec.charge_account
                || CHR (9)
                || status_rep_rec.deliver_to_loc
                || CHR (9)
                || status_rep_rec.justification
                || CHR (9)
                || status_rep_rec.requisition_number
                || CHR (9)
                || status_rep_rec.status_desc
                || CHR (9)
                || status_rep_rec.error_message
                || CHR (9)
                || status_rep_rec.process_message
                || CHR (9)
                || status_rep_rec.request_id
                || CHR (9);
            apps.do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
        END LOOP;


        apps.do_mail_utils.send_mail_close (ln_ret_val);
    EXCEPTION
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            x_proc_error_message   :=
                   'In When others exception in status_report procedure. Error is: '
                || SUBSTR (SQLERRM, 1, 200);
    --raise_application_error (-20010, lv_msg);
    END status_report;

    PROCEDURE importer_proc
    IS
        lv_error_message          VARCHAR2 (2000);
        lv_return_status          VARCHAR2 (1) := NULL;
        lv_proc_error_message     VARCHAR2 (2000);
        le_proc_error_exception   EXCEPTION;
        ln_person_id              NUMBER;
        lv_error_code             VARCHAR2 (1);
        ln_request_id             NUMBER;
    BEGIN
        SELECT TO_NUMBER (TO_CHAR (SYSDATE, 'yyyymmddhh24miss'))
          INTO gn_request_id
          FROM DUAL;

        mo_global.init ('PO');



        --Updating staging table with request_id
        BEGIN
            UPDATE xxdo.xxd_icx_poreq_stg_t
               SET request_id   = gn_request_id
             WHERE     1 = 1
                   AND record_status = 'N'
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE)
                   AND request_id = -1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_return_status   := g_ret_error;
                lv_error_message   :=
                    SUBSTR (
                           'Error while updating staging table with request id. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_error_message);
                --pv_retcode := gn_error;                                       --2;
                RAISE;
        END;

        BEGIN
            validate_staging (gn_request_id, lv_proc_error_message);
        --         IF lv_proc_error_message IS NOT NULL
        --         THEN
        --            RAISE le_proc_error_exception;
        --         END IF;
        END;

        -- IF NVL (lv_proc_error_message, 'N') = 'N'
        -- THEN
        BEGIN
            insert_into_interface_table (lv_proc_error_message);
        --            IF lv_proc_error_message IS NOT NULL
        --            THEN
        --               RAISE le_proc_error_exception;
        --            END IF;
        END;

        BEGIN
            submit_import_proc (gn_request_id);    -- (lv_proc_error_message);
        --            IF lv_proc_error_message IS NOT NULL
        --            THEN
        --               RAISE le_proc_error_exception;
        --            END IF;
        END;

        -- END IF;

        BEGIN
            status_report (gn_request_id, lv_proc_error_message);
        --         IF lv_proc_error_message IS NOT NULL
        --         THEN
        --            RAISE le_proc_error_exception;
        --         END IF;
        END;
    EXCEPTION
        WHEN le_proc_error_exception
        THEN
            COMMIT;
            raise_application_error (-20000, lv_proc_error_message);
        WHEN OTHERS
        THEN
            COMMIT;
            lv_proc_error_message   :=
                SUBSTR (lv_proc_error_message || SQLERRM, 1, 2000);
            --fnd_file.put_line (fnd_file.LOG, lv_proc_error_message);
            --pv_retcode := gn_error;
            RAISE;
    END importer_proc;
END XXD_ICX_POREQ_PKG;
/
