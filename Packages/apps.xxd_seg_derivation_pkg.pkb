--
-- XXD_SEG_DERIVATION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_SEG_DERIVATION_PKG"
AS
    -- =======================================================================================
    -- NAME: XXD_SEG_DERIVATION_PKG.pkb
    --
    -- Design Reference:
    --
    -- PROGRAM TYPE :  Package Body
    -- PURPOSE:
    -- For the account generator work flows segment derivations
    -- NOTES
    --
    --
    -- HISTORY
    -- =======================================================================================
    --  Date          Author                                Version             Activity
    -- =======================================================================================
    --
    -- 2-Sep-2014    BTDev team                            1.0                  Initial Version
    -- 3-Nov-2015      BTDev team                                      1.1                  Defect 363
    -- =======================================================================================

    -- =========================================================================
    -- NAME: XXD_SEG_DERIVATION_PKG
    --
    -- Design Reference:
    --
    -- PROGRAM TYPE :  Package Procedure
    --
    -- PURPOSE:  used in workflow to intiate the segment values for account generation.
    --
    -- Parameters :
    --      p_item_type      IN  TYPE
    --      p_item_key       IN  TYPE
    --      p_actid             IN  TYPE
    --      p_funcmode     IN TYPE
    --      px_resultout     IN OUT  TYPE
    --
    -- HISTORY
    -- =========================================================================
    --  Date            Author          Version            Activity
    -- =========================================================================
    --
    -- 2-Sep-2014        BTDev team         1.0                  Initial Version
    -- =========================================================================
    /*+======================================================================+
     | Function name                                                          |
     |     get_company_segment                                                  |
     |                                                                        |
     | DESCRIPTION                                                            |
     |     Function to get segments for company                                        |
     +========================================================================*/
    FUNCTION get_company_segment (p_org_id IN NUMBER)
        RETURN NUMBER
    IS
        -- get the value for company segment for ap supplier invoice
        CURSOR lcu_company_ap_c (cp_org_id NUMBER)
        IS
            SELECT flex_segment_value
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

    /*+======================================================================+
    | Function name                                                          |
    |     get_cost_center_segment                                              |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get segments for cost center                                     |
    +========================================================================*/
    FUNCTION get_cost_center_segment (p_expenditure_org_id IN NUMBER)
        RETURN NUMBER
    IS
        -- get the value for Cost center segment
        CURSOR lcu_cost_center_c (cp_expenditure_org_id NUMBER)
        IS
            SELECT segment_value
              FROM pa_segment_value_lookups psvl, hr_all_organization_units haou
             WHERE     segment_value_lookup_set_id IN
                           (SELECT segment_value_lookup_set_id
                              FROM pa_segment_value_lookup_sets
                             WHERE segment_value_lookup_set_name =
                                   'DO_EXP_ORG_COST_CENTER')
                   AND psvl.segment_value_lookup = haou.NAME
                   AND haou.organization_id = cp_expenditure_org_id;

        lc_segment2   VARCHAR2 (50);
    BEGIN
        --Fetch cost segment value
        OPEN lcu_cost_center_c (cp_expenditure_org_id => p_expenditure_org_id);

        FETCH lcu_cost_center_c INTO lc_segment2;

        CLOSE lcu_cost_center_c;

        RETURN lc_segment2;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_company_segment: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_cost_center_c%ISOPEN
            THEN
                CLOSE lcu_cost_center_c;
            END IF;
    END get_cost_center_segment;

    /*+======================================================================+
    | Function name                                                          |
    |     get_channel_segment                                                 |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get segments for channel                                        |
    +========================================================================*/
    FUNCTION get_channel_segment (p_projectid IN NUMBER)
        RETURN NUMBER
    IS
        -- get the value for channel segment
        CURSOR lcu_channel_c (cp_project_id NUMBER)
        IS
            SELECT segment_value
              FROM pa_segment_value_lookups psvl, pa_project_classes CLASS, pa_class_codes code
             WHERE     segment_value_lookup_set_id IN
                           (SELECT segment_value_lookup_set_id
                              FROM pa_segment_value_lookup_sets
                             WHERE segment_value_lookup_set_name =
                                   'DO_CLASSIFICATION_CHANNEL')
                   AND CLASS.class_category = code.class_category
                   AND CLASS.class_code = code.class_code
                   AND psvl.segment_value_lookup = code.class_code
                   AND CLASS.project_id = cp_project_id;

        lc_segment4   VARCHAR2 (50);
    BEGIN
        --Fetch channel segment value
        OPEN lcu_channel_c (cp_project_id => p_projectid);

        FETCH lcu_channel_c INTO lc_segment4;

        CLOSE lcu_channel_c;

        RETURN lc_segment4;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_company_segment: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_channel_c%ISOPEN
            THEN
                CLOSE lcu_channel_c;
            END IF;
    END get_channel_segment;

    /*+======================================================================+
    | Function name                                                          |
    |     get_brand_segment                                                 |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get segments for brand                                        |
    +========================================================================*/
    FUNCTION get_brand_segment (p_projectid IN NUMBER)
        RETURN NUMBER
    IS
        -- get the value for brand segment
        CURSOR lcu_brand_c (cp_project_id NUMBER)
        IS
            SELECT segment_value
              FROM pa_segment_value_lookups psvl, pa_project_classes CLASS, pa_class_codes code
             WHERE     segment_value_lookup_set_id IN
                           (SELECT segment_value_lookup_set_id
                              FROM pa_segment_value_lookup_sets
                             WHERE segment_value_lookup_set_name =
                                   'DO_CLASSIFICATION_BRAND')
                   AND CLASS.class_category = code.class_category
                   AND CLASS.class_code = code.class_code
                   AND psvl.segment_value_lookup = code.class_code
                   AND CLASS.project_id = cp_project_id;

        lc_segment5   VARCHAR2 (50);
    BEGIN
        --Fetch brand segment value
        OPEN lcu_brand_c (cp_project_id => p_projectid);

        FETCH lcu_brand_c INTO lc_segment5;

        CLOSE lcu_brand_c;

        RETURN lc_segment5;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_company_segment: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_brand_c%ISOPEN
            THEN
                CLOSE lcu_brand_c;
            END IF;
    END get_brand_segment;

    /*+======================================================================+
    | Function name                                                          |
    |     get_geo_segment                                                 |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get segments for geo                                        |
    +========================================================================*/
    FUNCTION get_geo_segment (p_projectid IN NUMBER)
        RETURN NUMBER
    IS
        -- get the value for geo segment
        CURSOR lcu_geo_c (cp_project_id NUMBER)
        IS
            SELECT segment_value
              FROM pa_segment_value_lookups psvl, pa_project_classes CLASS, pa_class_codes code
             WHERE     segment_value_lookup_set_id IN
                           (SELECT segment_value_lookup_set_id
                              FROM pa_segment_value_lookup_sets
                             WHERE segment_value_lookup_set_name =
                                   'DO_CLASSIFICATION_GEOGRAPHY')
                   AND CLASS.class_category = code.class_category
                   AND CLASS.class_code = code.class_code
                   AND psvl.segment_value_lookup = code.class_code
                   AND CLASS.project_id = cp_project_id;

        lc_segment6   VARCHAR2 (50);
    BEGIN
        --Fetch brand segment value
        OPEN lcu_geo_c (cp_project_id => p_projectid);

        FETCH lcu_geo_c INTO lc_segment6;

        CLOSE lcu_geo_c;

        RETURN lc_segment6;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_company_segment: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_geo_c%ISOPEN
            THEN
                CLOSE lcu_geo_c;
            END IF;
    END get_geo_segment;

    /*+======================================================================+
    | Function name                                                          |
    |     get_is_task_capitalized                                                     |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get check whether billable flag in PA_EXPENDITURE_ITEMS|
    |========================================================================*/
    FUNCTION get_is_task_capitalized (p_expenditureitemid IN NUMBER DEFAULT NULL, p_projectid IN NUMBER DEFAULT NULL, p_taskid IN NUMBER DEFAULT NULL)
        RETURN VARCHAR2
    IS
        lc_task_capitalflag   VARCHAR2 (1) := 'N';

        CURSOR lcu_task_capitalized (cp_projectid NUMBER, cp_taskid NUMBER)
        IS
            SELECT pt.billable_flag capital_flag
              FROM pa_tasks pt, pa_tasks ptt
             WHERE     pt.task_id = cp_taskid
                   AND pt.project_id = cp_projectid
                   AND pt.top_task_id = ptt.task_id
                   AND pt.project_id = ptt.project_id;
    BEGIN
        --Fetch capitalizable flag
        OPEN lcu_task_capitalized (cp_projectid   => p_projectid,
                                   cp_taskid      => p_taskid);

        FETCH lcu_task_capitalized INTO lc_task_capitalflag;

        CLOSE lcu_task_capitalized;

        RETURN lc_task_capitalflag;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_is_task_capitalized: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_task_capitalized%ISOPEN
            THEN
                CLOSE lcu_task_capitalized;
            END IF;
    END get_is_task_capitalized;

    /*+======================================================================+
    | Function name                                                          |
    |     get_is_task_tran_control                                                     |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get check whether billable flag in PA_EXPENDITURE_ITEMS|
    |========================================================================*/
    PROCEDURE get_is_task_tran_control (
        p_projectid                 IN     NUMBER DEFAULT NULL,
        p_taskid                    IN     NUMBER DEFAULT NULL,
        p_expendituretype           IN     VARCHAR2 DEFAULT NULL,
        px_task_trans_cntrl            OUT VARCHAR2,
        px_task_trans_capitalflag      OUT VARCHAR2)
    IS
        lc_task_trans_cntrl         VARCHAR2 (1) := NULL;
        lc_task_trans_capitalflag   VARCHAR2 (5) := NULL;
        lc_expenditure_category     VARCHAR2 (250) := NULL;
    BEGIN
        --Check if task level transaction control exists for the selected expenditure type.
        BEGIN
            SELECT 'X'
              INTO lc_task_trans_cntrl
              FROM pa_transaction_controls
             WHERE     project_id = p_projectid
                   AND task_id = p_taskid
                   AND expenditure_type = p_expendituretype;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_task_trans_cntrl   := NULL;
        END;

        --If task level transaction control exists for the selected expenditure type
        IF lc_task_trans_cntrl IS NOT NULL
        THEN
            --check 'Capitalizable' option for the expenditure type in the transaction control
            BEGIN
                SELECT billable_indicator
                  INTO lc_task_trans_capitalflag
                  FROM pa_transaction_controls
                 WHERE     project_id = p_projectid
                       AND task_id = p_taskid
                       AND expenditure_type = p_expendituretype;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_task_trans_capitalflag   := NULL;
            END;
        ELSE
            --get expenditure category for the expenditure type .
            BEGIN
                SELECT expenditure_category
                  INTO lc_expenditure_category
                  FROM pa_expenditure_types
                 WHERE expenditure_type = p_expendituretype;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_expenditure_category   := NULL;
            END;

            --Check if task level transaction control exists for the selected expenditure category.
            BEGIN
                SELECT 'X'
                  INTO lc_task_trans_cntrl
                  FROM pa_transaction_controls
                 WHERE     project_id = p_projectid
                       AND task_id = p_taskid
                       AND expenditure_category = lc_expenditure_category;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_task_trans_cntrl   := NULL;
            END;

            --If task level transaction control exists for the selected expenditure category
            IF lc_task_trans_cntrl IS NOT NULL
            THEN
                --check 'Capitalizable' option for the expenditure category in the transaction control
                BEGIN
                    SELECT billable_indicator
                      INTO lc_task_trans_capitalflag
                      FROM pa_transaction_controls
                     WHERE     project_id = p_projectid
                           AND task_id = p_taskid
                           AND expenditure_category = lc_expenditure_category;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lc_task_trans_capitalflag   := NULL;
                END;
            END IF;
        END IF;

        --end if for If task level transaction control exists for the selected expenditure type

        --Assign out variables
        px_task_trans_cntrl         := lc_task_trans_cntrl;
        px_task_trans_capitalflag   := lc_task_trans_capitalflag;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_company_segment: '
                || SQLERRM);
    END get_is_task_tran_control;

    /*+======================================================================+
    | procedure name                                                          |
    |     get_is_project_trans_cntrl                                                     |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get check whether billable flag in PA_EXPENDITURE_ITEMS|
    |========================================================================*/
    PROCEDURE get_is_project_trans_cntrl (
        p_projectid                IN     NUMBER DEFAULT NULL,
        p_expendituretype          IN     VARCHAR2 DEFAULT NULL,
        px_prj_trans_cntrl            OUT VARCHAR2,
        px_prj_trans_capitalflag      OUT VARCHAR2)
    IS
        lc_prj_trans_cntrl         VARCHAR2 (1) := NULL;
        lc_prj_trans_capitalflag   VARCHAR2 (5) := NULL;
        lc_expenditure_category    VARCHAR2 (250) := NULL;
    BEGIN
        --Check if prj level transaction control exists for the selected expenditure type.
        BEGIN
            SELECT 'X'
              INTO lc_prj_trans_cntrl
              FROM pa_transaction_controls
             WHERE     project_id = p_projectid
                   AND expenditure_type = p_expendituretype;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_prj_trans_cntrl   := NULL;
        END;

        --If prj level transaction control exists for the selected expenditure type
        IF lc_prj_trans_cntrl IS NOT NULL
        THEN
            --check 'Capitalizable' option for the expenditure type in the transaction control
            BEGIN
                SELECT billable_indicator
                  INTO lc_prj_trans_capitalflag
                  FROM pa_transaction_controls
                 WHERE     project_id = p_projectid
                       AND expenditure_type = p_expendituretype;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_prj_trans_capitalflag   := NULL;
            END;
        ELSE
            BEGIN
                --get expenditure category for the expenditure type .
                SELECT expenditure_category
                  INTO lc_expenditure_category
                  FROM pa_expenditure_types
                 WHERE expenditure_type = p_expendituretype;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_expenditure_category   := NULL;
            END;

            --Check if prj level transaction control exists for the selected expenditure category.
            BEGIN
                SELECT 'X'
                  INTO lc_prj_trans_cntrl
                  FROM pa_transaction_controls
                 WHERE     project_id = p_projectid
                       AND expenditure_category = lc_expenditure_category;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_prj_trans_cntrl   := NULL;
            END;

            --If prj level transaction control exists for the selected expenditure category
            IF lc_prj_trans_cntrl IS NOT NULL
            THEN
                --check 'Capitalizable' option for the expenditure category in the transaction control
                BEGIN
                    SELECT billable_indicator
                      INTO lc_prj_trans_capitalflag
                      FROM pa_transaction_controls
                     WHERE     project_id = p_projectid
                           AND expenditure_category = lc_expenditure_category;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lc_prj_trans_capitalflag   := NULL;
                END;
            END IF;
        END IF;

        --end if for If prj level transaction control exists for the selected expenditure type

        --Assign out variables
        px_prj_trans_cntrl         := lc_prj_trans_cntrl;
        px_prj_trans_capitalflag   := lc_prj_trans_capitalflag;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in procedure get_is_project_trans_cntrl: '
                || SQLERRM);
    END get_is_project_trans_cntrl;

    /*+======================================================================+
    | Function name                                                          |
    |     get_exp_type_natural_acct                                              |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get segments for natural account                                     |
    +========================================================================*/
    FUNCTION get_exp_type_natural_acct (p_expenditure_type IN VARCHAR2)
        RETURN NUMBER
    IS
        -- get the value for Cost center segment
        CURSOR lcu_exp_type_natural_acct_c (cp_expenditure_type VARCHAR2)
        IS
            SELECT segment_value
              FROM pa_segment_value_lookups psvl
             WHERE     segment_value_lookup_set_id IN
                           (SELECT segment_value_lookup_set_id
                              FROM pa_segment_value_lookup_sets
                             WHERE segment_value_lookup_set_name =
                                   'DO_EXP_TYPE_NATURAL_ACCOUNT')
                   AND psvl.segment_value_lookup = cp_expenditure_type;

        lc_segment6   VARCHAR2 (50);
    BEGIN
        --Fetch cost segment value
        OPEN lcu_exp_type_natural_acct_c (
            cp_expenditure_type => p_expenditure_type);

        FETCH lcu_exp_type_natural_acct_c INTO lc_segment6;

        CLOSE lcu_exp_type_natural_acct_c;

        RETURN lc_segment6;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_company_segment: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_exp_type_natural_acct_c%ISOPEN
            THEN
                CLOSE lcu_exp_type_natural_acct_c;
            END IF;
    END get_exp_type_natural_acct;

    /*+======================================================================+
    | Function name                                                          |
    |     get_exp_type_natural_acct                                              |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get segments for natural account                                     |
    +========================================================================*/
    FUNCTION get_fixed_cip_natural_acct
        RETURN NUMBER
    IS
        -- get the value for Cost center segment
        CURSOR lcu_fixed_cip_natural_acct_c IS
            SELECT constant_value
              FROM pa_rules
             WHERE rule_name = 'DO_FIXED_CIP_ACCOUNT';

        lc_segment6   VARCHAR2 (50);
    BEGIN
        --Fetch cost segment value
        OPEN lcu_fixed_cip_natural_acct_c;

        FETCH lcu_fixed_cip_natural_acct_c INTO lc_segment6;

        CLOSE lcu_fixed_cip_natural_acct_c;

        RETURN lc_segment6;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected Error in function get_company_segment: '
                || SQLERRM);
            RETURN NULL;

            IF lcu_fixed_cip_natural_acct_c%ISOPEN
            THEN
                CLOSE lcu_fixed_cip_natural_acct_c;
            END IF;
    END get_fixed_cip_natural_acct;

    /*+======================================================================+
    | Function name                                                          |
    |     check_expense_or_asset                                             |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get segments for natural account                       |
    +========================================================================*/
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

        --Start modification for Defect 363,by BT Tech Team,Dt: 11/3/2015
        --IF ln_unit_price <= ln_threshold_amount THEN
        IF ln_unit_price < ln_threshold_amount
        THEN
            --End  modification for Defect 363,by BT Tech Team,Dt: 11/3/2015

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
END xxd_seg_derivation_pkg;
/
