--
-- XXDO_PO_ACCT_SEGMENT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_ACCT_SEGMENT_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Restricting Natual Accounts in IProcurement                      *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  01-MAY-2017                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     01-MAY-2017  Srinath Siricilla     Initial Creation                    *
      * 1.1     21-MAY-2018  Srinath Siricilla     CCR0007253                          *
      * 1.2     09-SEP-2019  Kranthi Bollam        CCR0008074 - Modified logic to      *
      *                                            derive natural account if task is   *
      *                                            capitalizable                       *                                                       *
      *********************************************************************************/
    FUNCTION get_natural_segment (p_project_id IN NUMBER, p_task_id IN NUMBER, p_expenditure_type IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lc_segment6                 gl_code_combinations.segment6%TYPE;
        lc_task_capitalflag         VARCHAR2 (1) := NULL;
        lc_task_trans_cntrl         VARCHAR2 (15) := NULL;
        lc_task_trans_capitalflag   VARCHAR2 (15) := NULL;
        lc_prj_trans_cntrl          VARCHAR2 (15) := NULL;
        lc_prj_trans_capitalflag    VARCHAR2 (15) := NULL;
    BEGIN
        lc_segment6   := NULL;
        --Start logic for deriving the natural account segment

        lc_task_capitalflag   :=
            xxd_seg_derivation_pkg.get_is_task_capitalized (NULL,
                                                            p_project_id,
                                                            p_task_id);

        --selected task is capitalizable

        IF lc_task_capitalflag = 'Y'
        THEN
            --Check if task level transaction control exists and 'Capitalizable' option is set at task level

            xxd_seg_derivation_pkg.get_is_task_tran_control (
                p_projectid                 => p_project_id,
                p_taskid                    => p_task_id,
                p_expendituretype           => p_expenditure_type,
                px_task_trans_cntrl         => lc_task_trans_cntrl,
                px_task_trans_capitalflag   => lc_task_trans_capitalflag);

            --task level transaction control exists
            IF lc_task_trans_cntrl IS NOT NULL
            THEN
                --'Capitalizable' option is set as No
                IF lc_task_trans_capitalflag = 'N'
                THEN
                    --Fetch natural account segment value
                    lc_segment6   :=
                        xxd_seg_derivation_pkg.get_exp_type_natural_acct (
                            p_expenditure_type);
                --'Capitalizable' option is set at task Level

                ELSIF lc_task_trans_capitalflag = 'T'
                THEN
                    --Fetch natural account segment value
                    --lc_segment6 := xxd_seg_derivation_pkg.get_fixed_cip_natural_acct; --Commented for change 1.2
                    --Added for change 1.2 - START
                    lc_segment6   :=
                        NVL (
                            xxd_pa_util_pkg.get_cip_cca_account (
                                pn_project_id            => p_project_id,
                                pn_task_id               => p_task_id,
                                pn_expenditure_item_id   => NULL),
                            xxd_seg_derivation_pkg.get_fixed_cip_natural_acct);
                --Added for change 1.2 - END
                END IF;
            --task level transaction control exists does not exists
            ELSE
                --Check if prj level transaction control exists and 'Capitalizable' option is set at Project level
                xxd_seg_derivation_pkg.get_is_project_trans_cntrl (
                    p_projectid                => p_project_id,
                    p_expendituretype          => p_expenditure_type,
                    px_prj_trans_cntrl         => lc_prj_trans_cntrl,
                    px_prj_trans_capitalflag   => lc_prj_trans_capitalflag);

                --prj level transaction control exists
                IF lc_prj_trans_cntrl IS NOT NULL
                THEN
                    --'Capitalizable' option is set as No
                    IF lc_prj_trans_capitalflag = 'N'
                    THEN
                        --Fetch natural account segment value

                        lc_segment6   :=
                            xxd_seg_derivation_pkg.get_exp_type_natural_acct (
                                p_expenditure_type);
                    --'Capitalizable' option is set at prj Level

                    ELSIF lc_prj_trans_capitalflag = 'T'
                    THEN
                        --Fetch natural account segment value
                        --lc_segment6 := xxd_seg_derivation_pkg.get_fixed_cip_natural_acct; --Commented for change 1.2
                        --Added for change 1.2 - START
                        lc_segment6   :=
                            NVL (
                                xxd_pa_util_pkg.get_cip_cca_account (
                                    pn_project_id            => p_project_id,
                                    pn_task_id               => p_task_id,
                                    pn_expenditure_item_id   => NULL),
                                xxd_seg_derivation_pkg.get_fixed_cip_natural_acct);
                    --Added for change 1.2 - END
                    END IF;
                --prj level transaction control exists does not exists
                ELSE
                    --Fetch natural account segment value
                    --lc_segment6 := xxd_seg_derivation_pkg.get_fixed_cip_natural_acct; --Commented for change 1.2
                    --Added for change 1.2 - START
                    lc_segment6   :=
                        NVL (
                            xxd_pa_util_pkg.get_cip_cca_account (
                                pn_project_id            => p_project_id,
                                pn_task_id               => p_task_id,
                                pn_expenditure_item_id   => NULL),
                            xxd_seg_derivation_pkg.get_fixed_cip_natural_acct);
                --Added for change 1.2 - END
                END IF;             --end if for prj level transaction control
            END IF;
        --selected task is non-capitalizable
        ELSE
            --Fetch natural account segment value
            lc_segment6   :=
                xxd_seg_derivation_pkg.get_exp_type_natural_acct (
                    p_expenditure_type);
        END IF;

        RETURN lc_segment6;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_natural_segment;

    FUNCTION get_non_proj_acct_segment (p_unit_price      IN NUMBER,
                                        p_category_id     IN NUMBER,
                                        p_requestor_id    IN NUMBER,
                                        p_currency_code   IN VARCHAR2,
                                        p_org_id          IN NUMBER)
        RETURN VARCHAR2
    IS
        lc_expense_asset        VARCHAR2 (150) := NULL;
        lc_segment1             gl_code_combinations.segment1%TYPE;
        lc_segment5             gl_code_combinations.segment5%TYPE;
        lc_segment6             gl_code_combinations.segment6%TYPE;
        lc_ret_seg6             gl_code_combinations.segment6%TYPE;
        ln_flex_defaults_ccid   NUMBER;
        ln_cost_center_digit    VARCHAR2 (100);                      --NUMBER;
    BEGIN
        lc_expense_asset   :=
            xxd_seg_derivation_pkg.check_expense_or_asset (P_unit_price,
                                                           P_category_id,
                                                           P_currency_code);

        IF lc_expense_asset = 'Expense'
        THEN
            --Fetch Default Expense Account  for Segment1 to segment 5 and segment 7 from Employee Assignment for Requestor
            -- Commented as a part of CCR0007253
            BEGIN
                SELECT validate_cost_center_seg (p_requestor_id)
                  INTO lc_segment5
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_segment5   := NULL;
            END;

            /*BEGIN
              SELECT  gcc.segment1,
                      gcc.segment5
                INTO  lc_segment1,
                      lc_segment5
                FROM  apps.per_all_people_f papf,
                      apps.per_all_assignments_f paaf,
                      apps.gl_code_combinations gcc
              WHERE   1=1
                AND   papf.person_id                    = paaf.person_id
                AND   paaf.default_code_comb_id       = gcc.code_combination_id
                AND   TRUNC (paaf.effective_end_date) > TRUNC (SYSDATE)
                AND   TRUNC (papf.effective_end_date) > TRUNC (SYSDATE)
                AND   papf.person_id                  = p_requestor_id;--ln_requestor_id;
            EXCEPTION
                 WHEN OTHERS
                 THEN
                   lc_segment1 := NULL;
                   lc_segment5 := NULL;
            END;*/

            --- End of Changes as a part of CCR0007253

            --Start Added to get COAGS account if cost center begins with 2

            BEGIN
                SELECT SUBSTR (lc_segment5, 0, 1)
                  INTO ln_cost_center_digit
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_cost_center_digit   := '0';
            END;

            -- Added AND condition as a part of CCR0007253

            IF     ln_cost_center_digit IS NOT NULL
               AND ln_cost_center_digit = '2'
            THEN
                SELECT attribute6 cogs_account
                  INTO lc_segment6
                  FROM apps.mtl_categories
                 WHERE     1 = 1
                       AND attribute_category = 'PO Mapping Data Elements'
                       AND category_id = p_category_id;
            --End Added to get COAGS account if cost center begins with 2
            ELSIF     ln_cost_center_digit IS NOT NULL
                  AND ln_cost_center_digit NOT IN ('E', '0')
            THEN
                --Fetch Expense account for segment6 from Item Category DFF
                BEGIN
                    SELECT attribute5 expense_account
                      INTO lc_segment6
                      FROM mtl_categories
                     WHERE     1 = 1
                           AND attribute_category =
                               'PO Mapping Data Elements'
                           AND category_id = p_category_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_segment6   := NULL;
                END;
            -- Added as a part of CCR0007253
            ELSIF     ln_cost_center_digit IS NOT NULL
                  AND ln_cost_center_digit = 'E'
            THEN
                lc_segment6   := 'E';
            -- End of change for CCR0007253
            END IF;

            lc_ret_seg6   := lc_segment6;
        --Asset account  segments derivation
        ELSIF lc_expense_asset = 'Asset'
        THEN
            /*BEGIN
              SELECT
                gcc.segment1
              INTO
                lc_segment1
              FROM
                per_all_people_f papf,
                per_all_assignments_f paaf,
                gl_code_combinations gcc
              WHERE
                papf.person_id                    = paaf.person_id
              AND paaf.default_code_comb_id       = gcc.code_combination_id
              AND TRUNC (paaf.effective_end_date) > TRUNC (SYSDATE)
              AND TRUNC (papf.effective_end_date) > TRUNC (SYSDATE)
              AND papf.person_id                  = p_requestor_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
              lc_segment1 := NULL;
            END; */

            -- Fetching the Balancing segment of the associated OU based on Operating unit.

            BEGIN
                SELECT glev.flex_segment_value
                  INTO lc_segment1
                  FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_locations_all hrl,
                       apps.hz_parties hzp, apps.hr_operating_units hro, apps.gl_legal_entities_bsvs glev
                 WHERE     1 = 1
                       AND lep.transacting_entity_flag = 'Y'
                       AND lep.party_id = hzp.party_id
                       AND lep.legal_entity_id = reg.source_id
                       AND reg.source_table IN
                               ('XLE_ENTITY_PROFILES', 'XLE_ETB_PROFILES')
                       AND hrl.location_id = reg.location_id
                       AND reg.identifying_flag = 'Y'
                       AND lep.legal_entity_id = hro.default_legal_context_id
                       AND glev.legal_entity_id = lep.legal_entity_id
                       AND hro.organization_id = p_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_segment1   := NULL;
            END;

            --Fetch "Account? segment where company segment matches company from
            --Employee Assignment in Asset Book definition
            BEGIN
                SELECT flexbuilder_defaults_ccid
                  INTO ln_flex_defaults_ccid
                  FROM apps.fa_book_controls
                 WHERE flexbuilder_defaults_ccid IN
                           (SELECT code_combination_id
                              FROM apps.gl_code_combinations
                             WHERE segment1 = lc_segment1);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_flex_defaults_ccid   := 0;
            END;

            BEGIN
                SELECT gcc.segment6
                  INTO lc_segment6
                  FROM apps.gl_code_combinations gcc
                 WHERE     1 = 1
                       AND gcc.code_combination_id = ln_flex_defaults_ccid
                       AND gcc.enabled_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    --lc_segment6 := NULL;
                    lc_segment6   := 'E';
            END;

            lc_ret_seg6   := lc_segment6;
        END IF;

        RETURN lc_ret_seg6;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_ret_seg6   := NULL;
            RETURN lc_ret_seg6;
    END get_non_proj_acct_segment;

    -- Added as a part of CCR0007253

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
                   AND SYSDATE BETWEEN papf.effective_start_date
                                   AND papf.effective_end_date
                   AND SYSDATE BETWEEN paaf.effective_start_date
                                   AND paaf.effective_end_date
                   AND SYSDATE BETWEEN papf1.effective_start_date
                                   AND papf1.effective_end_date
                   AND papf.person_id = pn_requester_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_sup_id   := NULL;
        END;

        RETURN ln_sup_id;
    END get_supervisor_id;


    FUNCTION validate_cost_center_seg (pn_requester_id IN NUMBER)
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
                SELECT SUBSTR (gcc_kfv.segment5, 1, 1)
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
                            SELECT SUBSTR (gcc_kfv.segment5, 1, 1)
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
            RETURN NULL;
    END validate_cost_center_seg;
-- End of change as a part of CCR0007253

END XXDO_PO_ACCT_SEGMENT_PKG;
/
