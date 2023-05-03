--
-- XXD_PA_ACCTGEN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PA_ACCTGEN_PKG"
AS
    -- =======================================================================================
    -- NAME: XXD_PA_ACCTGEN_PKG.pkb
    --
    -- Design Reference:
    --
    -- PROGRAM TYPE :  Package Body
    -- PURPOSE:
    -- For the account generator work flows
    -- NOTES
    --
    --
    -- HISTORY
    -- =======================================================================================
    --  Date        Author              Version Activity
    -- =======================================================================================
    --
    -- 02-Sep-2014  BTDev team          1.0     Initial Version
    -- 10-Sep-2015 BTDev team   1.1     Modified for Accrual account Canada issue
    -- 15-Sep-2015 BTDev team   1.2     Modified for Requisition Org Id error (HPQC 2859)
    -- 30-Nov-2016  Infosys             1.3     Modified for capturing invalid account combination as part of ENHC0012850
    -- 12-Jun-2019  Kranthi Bollam      1.4     Modified for CCR0008025. Modified to generate account for Expense Invoice(PAAPWEBX workflow)
    -- 12-Jun-2019  Kranthi Bollam      1.5     Modified for CCR0008074. Modified logic to derive natural account if task is capitalizable
    -- =======================================================================================

    -- =========================================================================
    -- NAME: XXD_PA_ACCTGEN_PKG
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
    --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
    -- get the chart of accounts id
    /* CURSOR get_chart_of_acc_c
     IS
        SELECT chart_of_accounts_id
          FROM gl_sets_of_books
         WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');*/
    --End modification by BTDEV Team for HPQC 2859,on 15-Sep-15

    /*+======================================================================+
    | procedure name                                                         |
    |     get_prj_seg_values                                                 |
    |                                                                        |
    | DESCRIPTION                                                            |
    |   Procedure to get segments for project related invoice,po and         |
    | requisitions account generation                                        |
    +========================================================================*/
    PROCEDURE get_prj_seg_values (p_item_type    IN            VARCHAR2,
                                  p_item_key     IN            VARCHAR2,
                                  p_actid        IN            NUMBER,
                                  p_funcmode     IN            VARCHAR2,
                                  px_resultout      OUT NOCOPY VARCHAR2)
    IS
        --Local Variables
        ln_user_id                  NUMBER := fnd_global.user_id;
        ln_projectid                pa_projects_all.project_id%TYPE;
        ln_taskid                   pa_tasks.task_id%TYPE;
        ln_exp_organization_id      hr_all_organization_units.organization_id%TYPE;
        lc_expenditure_type         pa_expenditure_items_all.expenditure_type%TYPE;
        ln_cost                     NUMBER;
        lc_segment1                 gl_code_combinations.segment1%TYPE;
        lc_segment2                 gl_code_combinations.segment2%TYPE;
        lc_segment3                 gl_code_combinations.segment3%TYPE;
        lc_segment4                 gl_code_combinations.segment4%TYPE;
        lc_segment5                 gl_code_combinations.segment5%TYPE;
        lc_segment6                 gl_code_combinations.segment5%TYPE;
        lc_segment7                 gl_code_combinations.segment5%TYPE;
        lc_segment8                 gl_code_combinations.segment5%TYPE;
        ln_code_combinationid       gl_code_combinations.code_combination_id%TYPE;
        lc_chr_return               VARCHAR2 (150) := NULL;
        ln_org_id                   NUMBER;
        lc_valid_ccid               VARCHAR2 (15) := NULL;
        lc_char_of_acc_id           NUMBER;
        lc_error_msg                VARCHAR2 (2000) := NULL;
        lc_task_capitalflag         VARCHAR2 (1) := NULL;
        lc_task_trans_cntrl         VARCHAR2 (15) := NULL;
        lc_task_trans_capitalflag   VARCHAR2 (15) := NULL;
        lc_prj_trans_cntrl          VARCHAR2 (15) := NULL;
        lc_prj_trans_capitalflag    VARCHAR2 (15) := NULL;
        ln_dest_org_id              NUMBER;
        l_error_msg                 VARCHAR2 (200); -- Added as part of Ver 1.3
    BEGIN
        IF (p_funcmode = 'RUN')
        THEN
            -- Get the Project id
            ln_projectid   :=
                wf_engine.getitemattrnumber (itemtype   => p_item_type,
                                             itemkey    => p_item_key,
                                             aname      => 'PROJECT_ID');
            -- Get the task id
            ln_taskid     :=
                wf_engine.getitemattrnumber (itemtype   => p_item_type,
                                             itemkey    => p_item_key,
                                             aname      => 'TASK_ID');
            -- Get the expenditure type
            lc_expenditure_type   :=
                wf_engine.getitemattrtext (itemtype   => p_item_type,
                                           itemkey    => p_item_key,
                                           aname      => 'EXPENDITURE_TYPE');
            -- Get the expenditure organization
            ln_exp_organization_id   :=
                wf_engine.getitemattrnumber (
                    itemtype   => p_item_type,
                    itemkey    => p_item_key,
                    aname      => 'EXPENDITURE_ORGANIZATION_ID');

            --Get Org Id
            IF p_item_type = 'POWFPOAG'
            THEN
                ln_org_id   :=
                    wf_engine.getitemattrnumber (
                        itemtype   => p_item_type,
                        itemkey    => p_item_key,
                        aname      => 'PURCHASING_OU_ID');
            ELSIF p_item_type = 'POWFRQAG'
            THEN
                --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
                ln_org_id   := fnd_profile.VALUE ('ORG_ID');
            --End modification by BTDEV Team for HPQC 2859,on 15-Sep-15

            ELSIF p_item_type = 'PAAPINVW'
            THEN
                ln_org_id   :=
                    NVL (
                        wf_engine.getitemattrnumber (
                            itemtype   => p_item_type,
                            itemkey    => p_item_key,
                            aname      => 'ORG_ID'),
                        fnd_profile.VALUE ('ORG_ID'));
            --Start of Code changes for change 1.4
            ELSIF p_item_type = 'PAAPWEBX'
            THEN
                ln_org_id   :=
                    NVL (
                        wf_engine.getitemattrnumber (
                            itemtype   => p_item_type,
                            itemkey    => p_item_key,
                            aname      => 'ORG_ID'),
                        fnd_profile.VALUE ('ORG_ID'));
            --End of Code changes for change 1.4
            END IF;

            --Fetch company segment value
            lc_segment1   :=
                xxd_seg_derivation_pkg.get_company_segment (ln_org_id);
            --Fetch brand segment value
            lc_segment2   :=
                xxd_seg_derivation_pkg.get_brand_segment (ln_projectid);
            --Fetch geo segment value
            lc_segment3   :=
                xxd_seg_derivation_pkg.get_geo_segment (ln_projectid);
            --Fetch channel segment value
            lc_segment4   :=
                xxd_seg_derivation_pkg.get_channel_segment (ln_projectid);
            --Fetch cost segment value
            lc_segment5   :=
                xxd_seg_derivation_pkg.get_cost_center_segment (
                    ln_exp_organization_id);
            --Intercompany is same as company
            lc_segment7   := lc_segment1;
            lc_segment8   := '1000';
            --Start logic for deriving the natural account segment
            lc_task_capitalflag   :=
                xxd_seg_derivation_pkg.get_is_task_capitalized (NULL,
                                                                ln_projectid,
                                                                ln_taskid);

            --selected task is capitalizable
            IF lc_task_capitalflag = 'Y'
            THEN
                --Check if task level transaction control exists and 'Capitalizable' option is set at task level
                xxd_seg_derivation_pkg.get_is_task_tran_control (
                    p_projectid                 => ln_projectid,
                    p_taskid                    => ln_taskid,
                    p_expendituretype           => lc_expenditure_type,
                    px_task_trans_cntrl         => lc_task_trans_cntrl,
                    px_task_trans_capitalflag   => lc_task_trans_capitalflag);

                --task level transaction control exists
                IF lc_task_trans_cntrl IS NOT NULL
                THEN
                    --'Capitalizable' option is set as ?No?
                    IF lc_task_trans_capitalflag = 'N'
                    THEN
                        --Fetch natural account segment value
                        lc_segment6   :=
                            xxd_seg_derivation_pkg.get_exp_type_natural_acct (
                                lc_expenditure_type);
                    --'Capitalizable' option is set at task Level
                    ELSIF lc_task_trans_capitalflag = 'T'
                    THEN
                        --Fetch natural account segment value
                        --lc_segment6 := xxd_seg_derivation_pkg.get_fixed_cip_natural_acct; --Commented for change 1.5
                        --Added for change 1.5 - START
                        lc_segment6   :=
                            NVL (
                                xxd_pa_util_pkg.get_cip_cca_account (
                                    pn_project_id            => ln_projectid --122002
                                                                            ,
                                    pn_task_id               => ln_taskid --143062
                                                                         ,
                                    pn_expenditure_item_id   => NULL --1018021
                                                                    ),
                                xxd_seg_derivation_pkg.get_fixed_cip_natural_acct);
                    --Added for change 1.5 - END
                    END IF;
                --task level transaction control exists does not exists
                ELSE
                    --Check if prj level transaction control exists and 'Capitalizable' option is set at Project level
                    xxd_seg_derivation_pkg.get_is_project_trans_cntrl (
                        p_projectid                => ln_projectid,
                        p_expendituretype          => lc_expenditure_type,
                        px_prj_trans_cntrl         => lc_prj_trans_cntrl,
                        px_prj_trans_capitalflag   => lc_prj_trans_capitalflag);

                    --prj level transaction control exists
                    IF lc_prj_trans_cntrl IS NOT NULL
                    THEN
                        --'Capitalizable' option is set as ?No?
                        IF lc_prj_trans_capitalflag = 'N'
                        THEN
                            --Fetch natural account segment value
                            lc_segment6   :=
                                xxd_seg_derivation_pkg.get_exp_type_natural_acct (
                                    lc_expenditure_type);
                        --'Capitalizable' option is set at prj Level
                        ELSIF lc_prj_trans_capitalflag = 'T'
                        THEN
                            --Fetch natural account segment value
                            --lc_segment6 := xxd_seg_derivation_pkg.get_fixed_cip_natural_acct; --Commented for change 1.5
                            --Added for change 1.5 - START
                            lc_segment6   :=
                                NVL (
                                    xxd_pa_util_pkg.get_cip_cca_account (
                                        pn_project_id            => ln_projectid --122002
                                                                                ,
                                        pn_task_id               => ln_taskid --143062
                                                                             ,
                                        pn_expenditure_item_id   => NULL --1018021
                                                                        ),
                                    xxd_seg_derivation_pkg.get_fixed_cip_natural_acct);
                        --Added for change 1.5 - END
                        END IF;
                    --prj level transaction control exists does not exists
                    ELSE
                        --Fetch natural account segment value
                        --lc_segment6 := xxd_seg_derivation_pkg.get_fixed_cip_natural_acct; --Commented for change 1.5
                        --Added for change 1.5 - START
                        lc_segment6   :=
                            NVL (
                                xxd_pa_util_pkg.get_cip_cca_account (
                                    pn_project_id            => ln_projectid --122002
                                                                            ,
                                    pn_task_id               => ln_taskid --143062
                                                                         ,
                                    pn_expenditure_item_id   => NULL --1018021
                                                                    ),
                                xxd_seg_derivation_pkg.get_fixed_cip_natural_acct);
                    --Added for change 1.5 - END
                    END IF;         --end if for prj level transaction control
                END IF;
            --selected task is non-capitalizable
            ELSE
                --Fetch natural account segment value
                lc_segment6   :=
                    xxd_seg_derivation_pkg.get_exp_type_natural_acct (
                        lc_expenditure_type);
            END IF;

            -- fetch the chart of accounts id
            --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
            /*  OPEN get_chart_of_acc_c;

              FETCH get_chart_of_acc_c
               INTO lc_char_of_acc_id;

              CLOSE get_chart_of_acc_c;*/

            SELECT gsb.chart_of_accounts_id
              INTO lc_char_of_acc_id
              FROM hr_operating_units hou, gl_sets_of_books gsb
             WHERE     hou.set_of_books_id = gsb.set_of_books_id
                   AND hou.organization_id = ln_org_id;

            --End modification by BTDEV Team for HPQC 2859,on 15-Sep-15
            BEGIN
                --Create the ccid
                ln_code_combinationid   :=
                    fnd_flex_ext.get_ccid (
                        'SQLGL',
                        'GL#',
                        lc_char_of_acc_id,
                        NULL,
                           lc_segment1
                        || '.'
                        || lc_segment2
                        || '.'
                        || lc_segment3
                        || '.'
                        || lc_segment4
                        || '.'
                        || lc_segment5
                        || '.'
                        || lc_segment6
                        || '.'
                        || lc_segment7
                        || '.'
                        || lc_segment8);
                /*Start of change as part of Ver 1.3 */
                l_error_msg   := NULL;

                IF     ln_code_combinationid = 0
                   AND --p_item_type = 'PAAPINVW' Commented for change 1.4
                       p_item_type IN ('PAAPINVW', 'PAAPWEBX') --Added for change 1.4
                THEN
                    ln_code_combinationid   := -999;
                    l_error_msg             :=
                           'Account Combination '
                        || lc_segment1
                        || '.'
                        || lc_segment2
                        || '.'
                        || lc_segment3
                        || '.'
                        || lc_segment4
                        || '.'
                        || lc_segment5
                        || '.'
                        || lc_segment6
                        || '.'
                        || lc_segment7
                        || '.'
                        || lc_segment8
                        || ' is invalid';
                    FND_MESSAGE.set_name ('FND', 'ERROR_MESSAGE');
                    FND_MESSAGE.set_token ('MESSAGE', l_error_msg);

                    wf_engine.SetItemAttrText (
                        itemtype   => p_item_type,
                        itemkey    => p_item_key,
                        aname      => 'ERROR_MESSAGE',
                        avalue     => fnd_message.get_encoded);
                END IF;
            /*End of change as part of Ver 1.3 */
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_code_combinationid   := -999;
            END;

            IF ln_code_combinationid <> -999
            THEN
                IF       --p_item_type = 'PAAPINVW' --Commented for change 1.4
                   p_item_type IN ('PAAPINVW', 'PAAPWEBX') --Added for change 1.4
                THEN
                    wf_engine.setitemattrnumber (
                        itemtype   => p_item_type,
                        itemkey    => p_item_key,
                        aname      => 'DIST_CODE_COMBINATION_ID',
                        avalue     => ln_code_combinationid);
                ELSIF p_item_type IN ('POWFPOAG', 'POWFRQAG')
                THEN
                    wf_engine.setitemattrnumber (
                        itemtype   => p_item_type,
                        itemkey    => p_item_key,
                        aname      => 'TEMP_ACCOUNT_ID',
                        avalue     => ln_code_combinationid);
                END IF;
            END IF;

            IF ln_code_combinationid <> -999
            THEN
                px_resultout   := 'COMPLETE:SUCCESS';
            ELSE
                px_resultout   := 'COMPLETE:FAILURE';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --  Call WF_CORE API.
            apps.wf_core.CONTEXT (
                pkg_name    => 'XXD_PA_ACCTGEN_PKG',
                proc_name   => 'get_prj_seg_values',
                arg1        =>
                    ln_code_combinationid || SUBSTR (SQLERRM, 1, 2000),
                arg2        => p_item_type,
                arg3        => p_item_key,
                arg4        => p_funcmode);
            RAISE;
    END get_prj_seg_values;                               --get_prj_seg_values

    /*+======================================================================+
    | procedure name                                                         |
    |     is_po_prj_related                                                  |
    |                                                                        |
    | DESCRIPTION                                                            |
    |   Procedure to get segments for ap supplier invoice account generation |
    +========================================================================*/
    PROCEDURE is_po_prj_related (p_itemtype   IN            VARCHAR2,
                                 p_itemkey    IN            VARCHAR2,
                                 p_actid      IN            NUMBER,
                                 p_funcmode   IN            VARCHAR2,
                                 p_result        OUT NOCOPY VARCHAR2)
    IS
        ln_projectid   pa_projects_all.project_id%TYPE;
    BEGIN
        ln_projectid   :=
            NVL (
                wf_engine.getitemattrnumber (itemtype   => p_itemtype,
                                             itemkey    => p_itemkey,
                                             aname      => 'PROJECT_ID'),
                -99);

        IF ln_projectid <> -99
        THEN
            p_result   := 'COMPLETE:T';
        ELSE
            p_result   := 'COMPLETE:F';
        END IF;
    END is_po_prj_related;

    /*+======================================================================+
    | procedure name                                                         |
    |     get_nonprj_seg_values                                              |
    |                                                                        |
    | DESCRIPTION                                                            |
    |   Procedure to get segments for non-project related invoice,po and     |
    | requisitions account generation                                        |
    +========================================================================*/
    PROCEDURE get_nonprj_seg_values (p_item_type    IN     VARCHAR2,
                                     p_item_key     IN     VARCHAR2,
                                     p_actid        IN     NUMBER,
                                     p_funcmode     IN     VARCHAR2,
                                     px_resultout   IN OUT VARCHAR2)
    IS
        --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
        -- get the chart of accounts id
        /*    CURSOR get_chart_of_acc_c
            IS
               SELECT chart_of_accounts_id
                 FROM gl_sets_of_books
                WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');*/
        --End modification by BTDEV Team for HPQC 2859,on 15-Sep-15

        CURSOR get_org_code (p_org_id IN NUMBER)
        IS
            SELECT short_code
              FROM hr_operating_units
             WHERE organization_id = p_org_id;

        --Local Variables
        ln_user_id              NUMBER := fnd_global.user_id;
        lc_segment1             gl_code_combinations.segment1%TYPE;
        lc_segment2             gl_code_combinations.segment2%TYPE;
        lc_segment3             gl_code_combinations.segment3%TYPE;
        lc_segment4             gl_code_combinations.segment4%TYPE;
        lc_segment5             gl_code_combinations.segment5%TYPE;
        lc_segment6             gl_code_combinations.segment5%TYPE;
        lc_segment7             gl_code_combinations.segment5%TYPE;
        lc_segment8             gl_code_combinations.segment5%TYPE;
        ln_code_combinationid   gl_code_combinations.code_combination_id%TYPE;
        lc_chr_return           VARCHAR2 (150) := NULL;
        ln_org_id               NUMBER;
        lc_valid_ccid           VARCHAR2 (15) := NULL;
        lc_char_of_acc_id       NUMBER;
        lc_error_msg            VARCHAR2 (2000) := NULL;
        ln_category_id          NUMBER;
        ln_orgid                NUMBER;
        ln_requestor_id         NUMBER;
        ln_unit_price           NUMBER;
        ln_qty                  NUMBER;
        ln_cost                 NUMBER;
        lc_expense_asset        VARCHAR2 (150) := NULL;
        ln_flex_defaults_ccid   NUMBER;
        lc_currency_code        VARCHAR2 (15) := NULL;
        ln_cost_center_digit    NUMBER;
        lc_org_code             VARCHAR2 (100);
        ln_dest_org_id          NUMBER;
    BEGIN
        IF (p_funcmode = 'RUN')
        THEN
            --Get unit price
            ln_unit_price   :=
                wf_engine.getitemattrnumber (itemtype   => p_item_type,
                                             itemkey    => p_item_key,
                                             aname      => 'UNIT_PRICE');

            IF p_item_type = 'POWFPOAG'
            THEN
                ln_org_id   :=
                    wf_engine.getitemattrnumber (
                        itemtype   => p_item_type,
                        itemkey    => p_item_key,
                        aname      => 'PURCHASING_OU_ID');
            ELSIF p_item_type = 'POWFRQAG'
            THEN
                --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
                ln_org_id   := fnd_profile.VALUE ('ORG_ID');
            --End modification by BTDEV Team for HPQC 2859,on 15-Sep-15

            END IF;

            --Get category id
            ln_category_id   :=
                wf_engine.getitemattrnumber (itemtype   => p_item_type,
                                             itemkey    => p_item_key,
                                             aname      => 'CATEGORY_ID');
            ln_requestor_id   :=
                wf_engine.getitemattrnumber (itemtype   => p_item_type,
                                             itemkey    => p_item_key,
                                             aname      => 'TO_PERSON_ID');
            lc_currency_code   :=
                wf_engine.getitemattrtext (itemtype   => p_item_type,
                                           itemkey    => p_item_key,
                                           aname      => 'LINE_ATT15');

            OPEN get_org_code (p_org_id => ln_org_id);

            FETCH get_org_code INTO lc_org_code;

            CLOSE get_org_code;


            --Start to be removed post CRP3
            /* IF lc_org_code IN ('DO_US', 'DO_SALES', 'DO_USRET')
             THEN
                lc_currency_code := 'USD';
             ELSIF ln_org_id IN ('DO_BEIJING', 'DO_SHANG', 'DO_GUANG')
             THEN
                lc_currency_code := 'CNY';
             ELSIF ln_org_id IN ('DO_DEL', 'DO_BENE', 'DO_BEL', 'DO_FRSAS', 'DO_GER', 'DO_UK')
             THEN
                lc_currency_code := 'EUR';
             ELSIF ln_org_id IN ('DO_CA', 'DO_CA_ECOM')
             THEN
                lc_currency_code := 'CAD';
             ELSIF ln_org_id = 'DO_JP'
             THEN
                lc_currency_code := 'JPY';
             ELSIF ln_org_id = 'DO_MACAU'
             THEN
                lc_currency_code := 'MOP';
             ELSIF ln_org_id IN ('DO_HK', 'DO_HKB')
             THEN
                lc_currency_code := 'HKD';
             ELSE
                lc_currency_code := 'USD';
             END IF;*/

            --end to be removed post CRP3

            --Call function to check if expense account or Asset Account needs to be fetched.
            lc_expense_asset   :=
                xxd_seg_derivation_pkg.check_expense_or_asset (
                    ln_unit_price,
                    ln_category_id,
                    lc_currency_code);


            -- lc_expense_asset := xxd_seg_derivation_pkg.check_expense_or_asset(ln_unit_price,ln_category_id);

            --Expense account  segments derivation
            IF lc_expense_asset = 'Expense'
            THEN
                --Fetch Default Expense Account  for Segment1 to segment 5 and segment 7 from Employee Assignment for Requestor
                BEGIN
                    SELECT gcc.segment1, gcc.segment2, gcc.segment3,
                           gcc.segment4, gcc.segment5, gcc.segment7
                      INTO lc_segment1, lc_segment2, lc_segment3, lc_segment4,
                                      lc_segment5, lc_segment7
                      FROM per_all_people_f papf, per_all_assignments_f paaf, gl_code_combinations gcc
                     WHERE     papf.person_id = paaf.person_id
                           AND paaf.default_code_comb_id =
                               gcc.code_combination_id
                           AND TRUNC (paaf.effective_end_date) >
                               TRUNC (SYSDATE)
                           AND TRUNC (papf.effective_end_date) >
                               TRUNC (SYSDATE)
                           AND papf.person_id = ln_requestor_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lc_segment1   := NULL;
                        lc_segment2   := NULL;
                        lc_segment3   := NULL;
                        lc_segment4   := NULL;
                        lc_segment5   := NULL;
                        lc_segment7   := NULL;
                END;

                --Start Added to get COAGS account if cost center begins with 2
                BEGIN
                    SELECT SUBSTR (lc_segment5, 0, 1)
                      INTO ln_cost_center_digit
                      FROM DUAL;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost_center_digit   := 0;
                END;


                IF ln_cost_center_digit = 2
                THEN
                    SELECT attribute6 cogs_account
                      INTO lc_segment6
                      FROM mtl_categories
                     WHERE     attribute_category =
                               'PO Mapping Data Elements'
                           AND category_id = ln_category_id;
                --EndAdded to get COAGS account if cost center begins with 2
                ELSE
                    --Fetch Expense account for segment6 from Item Category DFF
                    BEGIN
                        SELECT attribute5 expense_account
                          INTO lc_segment6
                          FROM mtl_categories
                         WHERE     attribute_category =
                                   'PO Mapping Data Elements'
                               AND category_id = ln_category_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_segment6   := NULL;
                    END;
                END IF;
            --Asset account  segments derivation
            ELSIF lc_expense_asset = 'Asset'
            THEN
                --Fetch Default Expense Account  for Segment1  and segment 7 from Employee Assignment for Requestor
                BEGIN
                    SELECT gcc.segment1, gcc.segment7
                      INTO lc_segment1, lc_segment7
                      FROM per_all_people_f papf, per_all_assignments_f paaf, gl_code_combinations gcc
                     WHERE     papf.person_id = paaf.person_id
                           AND paaf.default_code_comb_id =
                               gcc.code_combination_id
                           AND TRUNC (paaf.effective_end_date) >
                               TRUNC (SYSDATE)
                           AND TRUNC (papf.effective_end_date) >
                               TRUNC (SYSDATE)
                           AND papf.person_id = ln_requestor_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lc_segment1   := NULL;
                        lc_segment7   := NULL;
                END;

                --Fetch "Account? segment where company segment matches company from
                --Employee Assignment in Asset Book definition
                BEGIN
                    SELECT flexbuilder_defaults_ccid
                      INTO ln_flex_defaults_ccid
                      FROM fa_book_controls
                     WHERE flexbuilder_defaults_ccid IN
                               (SELECT code_combination_id
                                  FROM gl_code_combinations
                                 WHERE segment1 = lc_segment1);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_flex_defaults_ccid   := 0;
                END;

                BEGIN
                    SELECT gcc.segment2, gcc.segment3, gcc.segment4,
                           gcc.segment5, gcc.segment6
                      INTO lc_segment2, lc_segment3, lc_segment4, lc_segment5,
                                      lc_segment6
                      FROM gl_code_combinations gcc
                     WHERE gcc.code_combination_id = ln_flex_defaults_ccid;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lc_segment2   := NULL;
                        lc_segment3   := NULL;
                        lc_segment4   := NULL;
                        lc_segment5   := NULL;
                        lc_segment6   := NULL;
                END;
            END IF;

            --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
            -- fetch the chart of accounts id
            /* OPEN get_chart_of_acc_c;

             FETCH get_chart_of_acc_c
              INTO lc_char_of_acc_id;

             CLOSE get_chart_of_acc_c;*/

            SELECT gsb.chart_of_accounts_id
              INTO lc_char_of_acc_id
              FROM hr_operating_units hou, gl_sets_of_books gsb
             WHERE     hou.set_of_books_id = gsb.set_of_books_id
                   AND hou.organization_id = ln_org_id;

            --End modification by BTDEV Team for HPQC 2859,on 15-Sep-15

            lc_segment8   := '1000';

            BEGIN
                --Create the ccid
                ln_code_combinationid   :=
                    fnd_flex_ext.get_ccid (
                        'SQLGL',
                        'GL#',
                        lc_char_of_acc_id,
                        NULL,
                           lc_segment1
                        || '.'
                        || lc_segment2
                        || '.'
                        || lc_segment3
                        || '.'
                        || lc_segment4
                        || '.'
                        || lc_segment5
                        || '.'
                        || lc_segment6
                        || '.'
                        || lc_segment7
                        || '.'
                        || lc_segment8);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_code_combinationid   := -999;
            END;

            IF ln_code_combinationid <> -999
            THEN
                IF p_item_type IN ('POWFPOAG', 'POWFRQAG')
                THEN
                    wf_engine.setitemattrnumber (
                        itemtype   => p_item_type,
                        itemkey    => p_item_key,
                        aname      => 'TEMP_ACCOUNT_ID',
                        avalue     => ln_code_combinationid);
                END IF;
            END IF;

            IF ln_code_combinationid <> -999
            THEN
                px_resultout   := 'COMPLETE:SUCCESS';
            ELSE
                px_resultout   := 'COMPLETE:FAILURE';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --  Call WF_CORE API.
            apps.wf_core.CONTEXT (
                pkg_name    => 'XXD_PA_ACCTGEN_PKG',
                proc_name   => 'get_nonprj_seg_values',
                arg1        =>
                    ln_code_combinationid || SUBSTR (SQLERRM, 1, 2000),
                arg2        => p_item_type,
                arg3        => p_item_key,
                arg4        => p_funcmode);
            RAISE;
    END get_nonprj_seg_values;                         --get_nonprj_seg_values

    /*+======================================================================+
    | procedure name                                                         |
    |     get_accural_seg_values                                             |
    |                                                                        |
    | DESCRIPTION                                                            |
    |   Procedure to get accrual segments for project and non project related|
    |  po and requisitions account generation                                |
    +========================================================================*/
    PROCEDURE get_accural_seg_values (p_item_type    IN     VARCHAR2,
                                      p_item_key     IN     VARCHAR2,
                                      p_actid        IN     NUMBER,
                                      p_funcmode     IN     VARCHAR2,
                                      px_resultout   IN OUT VARCHAR2)
    IS
        --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
        -- get the chart of accounts id
        /*   CURSOR get_chart_of_acc_c
           IS
              SELECT chart_of_accounts_id
                FROM gl_sets_of_books
               WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');*/
        --End modification by BTDEV Team for HPQC 2859,on 15-Sep-15

        --Local Variables
        ln_user_id              NUMBER := fnd_global.user_id;
        lc_segment1             gl_code_combinations.segment1%TYPE;
        lc_segment2             gl_code_combinations.segment2%TYPE;
        lc_segment3             gl_code_combinations.segment3%TYPE;
        lc_segment4             gl_code_combinations.segment4%TYPE;
        lc_segment5             gl_code_combinations.segment5%TYPE;
        lc_segment6             gl_code_combinations.segment5%TYPE;
        lc_segment7             gl_code_combinations.segment5%TYPE;
        lc_segment8             gl_code_combinations.segment5%TYPE;
        ln_code_combinationid   gl_code_combinations.code_combination_id%TYPE;
        lc_chr_return           VARCHAR2 (150) := NULL;
        ln_org_id               NUMBER;
        lc_valid_ccid           VARCHAR2 (15) := NULL;
        lc_char_of_acc_id       NUMBER;
        lc_error_msg            VARCHAR2 (2000) := NULL;
        ln_category_id          NUMBER;
        ln_orgid                NUMBER;
        ln_requestor_id         NUMBER;
        ln_unit_price           NUMBER;
        ln_qty                  NUMBER;
        ln_cost                 NUMBER;
        lc_expense_asset        VARCHAR2 (150) := NULL;
        ln_flex_defaults_ccid   NUMBER;
        ln_dest_org_id          NUMBER;
    BEGIN
        IF (p_funcmode = 'RUN')
        THEN
            IF p_item_type = 'POWFPOAG'
            THEN
                ln_org_id   :=
                    wf_engine.getitemattrnumber (
                        itemtype   => p_item_type,
                        itemkey    => p_item_key,
                        aname      => 'PURCHASING_OU_ID');
            ELSIF p_item_type = 'POWFRQAG'
            THEN
                --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
                ln_org_id   := fnd_profile.VALUE ('ORG_ID');
            --End Modification on 10-Sep-15 for Accrual account Canada issue
            END IF;


            --Start Modification on 10-Sep-15 for Accrual account Canada issue
            /* ln_requestor_id :=
                wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                             itemkey       => p_item_key,
                                             aname         => 'TO_PERSON_ID'
                                            );

             --Fetch Segment1 Employee Assignment for Requestor
             BEGIN
                SELECT gcc.segment1
                  INTO lc_segment1
                  FROM per_all_people_f papf,
                       per_all_assignments_f paaf,
                       gl_code_combinations gcc
                 WHERE papf.person_id = paaf.person_id
                   AND paaf.default_code_comb_id = gcc.code_combination_id
                   AND TRUNC (paaf.effective_end_date) > TRUNC (SYSDATE)
                   AND TRUNC (papf.effective_end_date) > TRUNC (SYSDATE)
                   AND papf.person_id = ln_requestor_id;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                   lc_segment1 := NULL;
             END;*/
            --End Modification on 10-Sep-15 for Accrual account Canada issue

            --Fetch Default Expense Account  for Segment2 to segment 7  from Expense AP Accrual Account setup
            BEGIN
                SELECT --Start Modification on 10-Sep-15 for Accrual account Canada issue
                       gcc.segment1--End Modification on 10-Sep-15 for Accrual account Canada issue
                                   , gcc.segment2, gcc.segment3,
                       gcc.segment4, gcc.segment5, gcc.segment6,
                       gcc.segment7
                  INTO lc_segment1, lc_segment2, lc_segment3, lc_segment4,
                                  lc_segment5, lc_segment6, lc_segment7
                  FROM po_system_parameters_all pspa, gl_code_combinations gcc
                 WHERE     pspa.accrued_code_combination_id =
                           gcc.code_combination_id
                       AND pspa.org_id = ln_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_segment1   := NULL;
                    lc_segment2   := NULL;
                    lc_segment3   := NULL;
                    lc_segment4   := NULL;
                    lc_segment5   := NULL;
                    lc_segment6   := NULL;
                    lc_segment7   := NULL;
            END;

            --Start modification by BTDEV Team for HPQC 2859,on 15-Sep-15
            -- fetch the chart of accounts id
            /*  OPEN get_chart_of_acc_c;

              FETCH get_chart_of_acc_c
               INTO lc_char_of_acc_id;

              CLOSE get_chart_of_acc_c;*/

            SELECT gsb.chart_of_accounts_id
              INTO lc_char_of_acc_id
              FROM hr_operating_units hou, gl_sets_of_books gsb
             WHERE     hou.set_of_books_id = gsb.set_of_books_id
                   AND hou.organization_id = ln_org_id;

            --End modification by BTDEV Team for HPQC 2859,on 15-Sep-15

            lc_segment8   := '1000';

            BEGIN
                --Create the ccid
                ln_code_combinationid   :=
                    fnd_flex_ext.get_ccid (
                        'SQLGL',
                        'GL#',
                        lc_char_of_acc_id,
                        NULL,
                           lc_segment1
                        || '.'
                        || lc_segment2
                        || '.'
                        || lc_segment3
                        || '.'
                        || lc_segment4
                        || '.'
                        || lc_segment5
                        || '.'
                        || lc_segment6
                        || '.'
                        || lc_segment7
                        || '.'
                        || lc_segment8);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_code_combinationid   := -999;
            END;

            IF ln_code_combinationid <> -999
            THEN
                IF p_item_type IN ('POWFPOAG', 'POWFRQAG')
                THEN
                    wf_engine.setitemattrnumber (
                        itemtype   => p_item_type,
                        itemkey    => p_item_key,
                        aname      => 'TEMP_ACCOUNT_ID',
                        avalue     => ln_code_combinationid);
                END IF;
            END IF;

            IF ln_code_combinationid <> -999
            THEN
                px_resultout   := 'COMPLETE:SUCCESS';
            ELSE
                px_resultout   := 'COMPLETE:FAILURE';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --  Call WF_CORE API.
            apps.wf_core.CONTEXT (
                pkg_name    => 'XXD_PA_ACCTGEN_PKG',
                proc_name   => 'get_accural_seg_values',
                arg1        =>
                    ln_code_combinationid || SUBSTR (SQLERRM, 1, 2000),
                arg2        => p_item_type,
                arg3        => p_item_key,
                arg4        => p_funcmode);
            RAISE;
    END get_accural_seg_values;                       --get_accural_seg_values
END xxd_pa_acctgen_pkg;
/
