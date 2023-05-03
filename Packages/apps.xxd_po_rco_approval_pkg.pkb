--
-- XXD_PO_RCO_APPROVAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_RCO_APPROVAL_PKG"
AS
    /******************************************************************************
      NAME: xxd_po_rco_approval_pkg

       Ver          Date            Author                       Description
       ---------  ----------    ---------------           ------------------------------------
      1.0         14/10/2014    BT Technology Team        Function to return approval list ( AME  )
      1.1         01/03.2018    Tejswi Gangumalla         Added function get_post_apprvrlist to get buyer approval list based on changed quantity
      1.1         01/03.2018    Tejswi Gangumalla         Added function get_req_eligible to check buyer approval eligibility based on changed quantity
      1.1         01/03.2018    Tejswi Gangumalla         Added function get_apac_finance_apprlist to get APAC finance approval listbased on changed quantity
      1.1         01/03.2018    Tejswi Gangumalla         Added function get_apac_finance_apprlimit to check APAC finance approval eligibility based on changed quantity
      1.1         01/03.2018    Tejswi Gangumalla         Added function change_po_buyer to modify buyer name on PO when buyer approver is changed
      1.2         21/05/2018    Infosys                   Modified for CCR0007258 ; IDENTIFIED BY CCR0007258
                                                          Approval List is not Getting Generated when there were multiple lines in Requisition.
      1.3        11/13/2019     Srinath Siricilla         Added for Change CCR0008214
      1.4        01/09/2020     Srinath Siricilla         CCR0008534
    *************************************************************************************************************************************************/
    FUNCTION get_supervisor (p_per_id NUMBER)
        RETURN NUMBER
    IS
        sup_id   NUMBER;
    BEGIN
        SELECT papf1.person_id
          INTO sup_id
          FROM per_all_people_f papf, per_all_assignments_f paaf, per_all_people_f papf1
         WHERE     papf.person_id = paaf.person_id
               AND paaf.primary_flag = 'Y'
               AND paaf.assignment_type = 'E'
               AND paaf.supervisor_id = papf1.person_id
               AND papf1.current_employee_flag = 'Y'
               AND SYSDATE BETWEEN papf.effective_start_date
                               AND papf.effective_end_date
               AND SYSDATE BETWEEN paaf.effective_start_date
                               AND paaf.effective_end_date
               AND SYSDATE BETWEEN papf1.effective_start_date
                               AND papf1.effective_end_date
               AND papf.person_id = p_per_id;

        RETURN sup_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_supervisor;

    FUNCTION get_apprlist (p_trx_id IN NUMBER)
        RETURN XXD_PO_RCO_APPROVAL_PKG.out_rec
        PIPELINED
    IS
        ln_amount            NUMBER;
        ln_per_id            NUMBER;
        ln_sup_id            NUMBER;
        ln_app_amount        NUMBER;
        ln_list              VARCHAR2 (1000) := ' ';
        ln_num               NUMBER;
        ln_org_id            NUMBER;
        lc_currency_code     VARCHAR2 (15);
        ld_rate_date         DATE;
        ln_conversion_rate   NUMBER := 1;
    BEGIN
        out_approver_rec_final   := out_rec (NULL);

        lc_currency_code         := NULL;              -- Added for CCR0008534

          /*SELECT   to_person_id, amount, MIN (line_num), org_id,trunc(rate_date)
                      INTO ln_per_id, ln_amount, ln_num, ln_org_id,ld_rate_date
              FROM (SELECT prla1.to_person_id, sub.amount, prla1.line_num, prla1.org_id,NVL(prla1.rate_date,prla1.creation_date) rate_date
                      FROM apps.po_requisition_lines_all prla1,
                           (SELECT   prla.requisition_header_id,
                                     SUM (prla.quantity * prla.unit_price) amount
                                FROM po_requisition_lines_all prla
                               WHERE prla.requisition_header_id = p_trx_id
                            GROUP BY prla.requisition_header_id) sub
                     WHERE sub.requisition_header_id = prla1.requisition_header_id)
          GROUP BY to_person_id, amount,org_id,trunc(rate_date); */

          SELECT to_person_id, amount, MIN (line_num),
                 org_id, TRUNC (rate_date)
            INTO ln_per_id, ln_amount, ln_num, ln_org_id,
                          ld_rate_date
            FROM (SELECT prla.to_person_id, po_ame_setup_pvt.get_changed_req_total (p_trx_id) amount, prla.line_num,
                         prla.org_id, NVL (prla.rate_date, prla.creation_date) rate_date
                    FROM apps.po_requisition_lines_all prla
                   WHERE prla.requisition_header_id = p_trx_id)
        GROUP BY to_person_id, amount, org_id,
                 TRUNC (rate_date);


        -- Start of Change for CCR0008534

        -- Getting everything in Functional Currency

        IF lc_currency_code IS NULL
        THEN
            lc_currency_code   :=
                po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;

        -- Get the requisition line currency
        /* BEGIN
            SELECT DISTINCT currency_code
              INTO lc_currency_code
              FROM apps.po_requisition_lines_all
             WHERE requisition_header_id = p_trx_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               lc_currency_code := NULL;
         END;

         IF lc_currency_code IS NULL
         THEN
            lc_currency_code := po_ame_setup_pvt.get_function_currency (p_trx_id);
         END IF;*/


        -- End of Change

        --      -- fetching ledger for getting functional currency
        --
        --      SELECT currency_code
        --        INTO lc_currency_code
        --        FROM hr_operating_units op, gl_ledgers ledgers
        --       WHERE     organization_id = ln_org_id
        --             AND op.set_of_books_id = ledgers.ledger_id;


        /*     IF lc_currency_code != 'USD'
             THEN
             SELECT NVL(conversion_rate,100)
             INTO ln_conversion_rate
             FROM gl_daily_rates
             WHERE from_currency = 'USD'
             AND to_currency =  lc_currency_code
             AND conversion_date = ld_rate_date
             AND CONVERSION_TYPE ='Corporate';
             END IF;
           */

        IF lc_currency_code != 'USD'
        THEN
            SELECT conversion_rate
              INTO ln_conversion_rate
              FROM gl_daily_rates
             WHERE     1 = 1
                   --                AND from_currency = 'USD'
                   --                AND to_currency = lc_currency_code
                   AND from_currency = lc_currency_code
                   AND to_currency = 'USD'
                   AND conversion_date = ld_rate_date
                   AND conversion_type = 'Corporate';
        ELSIF lc_currency_code = 'USD'
        THEN
            ln_conversion_rate   := 1;
        END IF;

        IF ln_conversion_rate = 0
        THEN
            ln_conversion_rate   := 100;
        END IF;

        ln_amount                := ln_amount * ln_conversion_rate;

        IF ln_per_id IS NOT NULL
        THEN
            LOOP
                ln_sup_id       := get_supervisor (ln_per_id);
                ln_app_amount   := 0;

                SELECT NVL (attribute1, 0)
                  INTO ln_app_amount
                  FROM per_jobs jobs, per_all_assignments_f paaf
                 WHERE     paaf.person_id = ln_sup_id
                       AND paaf.job_id = jobs.job_id
                       AND SYSDATE BETWEEN paaf.effective_start_date
                                       AND paaf.effective_end_date;

                ln_per_id       := ln_sup_id;


                IF ln_app_amount > 0
                THEN
                    out_approver_rec_final (out_approver_rec_final.LAST).approver   :=
                        ln_sup_id;
                    out_approver_rec_final.EXTEND;
                --ln_list := ln_list || ',' || ln_sup_id;
                END IF;

                EXIT WHEN ln_app_amount > ln_amount;
            END LOOP;

            FOR x IN 1 .. out_approver_rec_final.COUNT - 1
            LOOP
                IF out_approver_rec_final (x).approver IS NULL
                THEN
                    NULL;
                ELSE
                    PIPE ROW (out_approver_rec_final (x));
                END IF;
            END LOOP;

            --ln_list := LTRIM (ln_list, ' ,');
            --return ln_sup_id;
            RETURN;
        END IF;

        --return ln_sup_id;
        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN;
    END get_apprlist;

    --function get buyer approval list based on changed amount
    FUNCTION get_post_apprvrlist (p_trx_id IN NUMBER)
        RETURN xxd_po_rco_approval_pkg.out_rec_list
        PIPELINED
    IS
        -- Commented as per change 1.3
        /*
        CURSOR lcu_post_approval_list (
           cp_trx_id             NUMBER,
           cp_approval_limit     NUMBER,
           cp_conversion_rate    NUMBER)
        IS
           --Added new query for CCR CCR0006810
           SELECT attribute1
             FROM (  SELECT pf.person_id attribute1
                       FROM fnd_lookup_values flv,
                            per_people_f pf,
                            (SELECT DISTINCT pf.full_name appr_name
                               FROM mtl_categories mc, per_people_f pf
                              WHERE     mc.attribute_category =
                                           'PO Mapping Data Elements'
                                    AND mc.category_id IN
                                           (SELECT prla.category_id
                                              FROM po_requisition_lines_all prla
                                             WHERE prla.requisition_header_id =
                                                      cp_trx_id)
                                    AND EXISTS
                                           (  SELECT 1
                                                FROM po_requisition_lines_all prla1
                                               WHERE prla1.requisition_header_id =
                                                        cp_trx_id
                                            GROUP BY prla1.requisition_header_id
                                              HAVING po_ame_setup_pvt.get_changed_req_total (
                                                        cp_trx_id) >=
                                                        cp_approval_limit)
                                    AND pf.person_id = mc.attribute1) pf_name
                      WHERE     flv.LANGUAGE = 'US'
                            AND flv.lookup_type = 'XXDO_REQ_BUYER_APPR_LIST'
                            AND enabled_flag = 'Y'
                            AND SYSDATE BETWEEN start_date_active
                                            AND NVL (end_date_active,
                                                     SYSDATE + 1)
                            AND flv.description = pf_name.appr_name
                            AND (flv.tag * cp_conversion_rate) <=
                                   (SELECT po_ame_setup_pvt.get_changed_req_total (
                                              cp_trx_id)
                                              amount
                                      FROM DUAL)
                            AND pf.full_name = flv.meaning
                   ORDER BY TO_NUMBER (flv.tag) DESC)
            WHERE ROWNUM = 1;*/

        CURSOR lcu_post_approval_list (cp_org_id IN NUMBER, cp_req_amount IN NUMBER, cp_cat_type IN VARCHAR2)
        IS
            SELECT papf.person_id
              FROM apps.per_all_people_f papf, apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
             WHERE     ffvs.flex_value_set_name = 'XXD_PO_NT_EMP_MGR_VS'
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvl.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                                   AND NVL (ffvl.end_date_active, SYSDATE)
                   AND SYSDATE BETWEEN NVL (papf.effective_start_date,
                                            SYSDATE)
                                   AND NVL (papf.effective_end_date, SYSDATE)
                   AND ffvl.attribute1 = cp_org_id
                   AND NVL (ffvl.attribute6, cp_cat_type) = cp_cat_type
                   AND papf.full_name = ffvl.attribute4
                   AND cp_req_amount >=
                       NVL (ffvl.attribute3, cp_req_amount + 1)
                   AND cp_req_amount <=
                       NVL (ffvl.attribute5, cp_req_amount + 1);

        -- End of Change 1.3

        TYPE c1_type IS TABLE OF lcu_post_approval_list%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_c1_tab                     c1_type;

        ln_non_trade_appr_limit_amt   NUMBER := 0;
        lc_currency_code              VARCHAR2 (50) := NULL;
        ln_conv_rate                  NUMBER DEFAULT 1;
        -- Added as per change 1.3
        ln_org_id                     NUMBER;
        ln_req_amount                 NUMBER;
        lv_cat_owner                  VARCHAR2 (100);
        lv_cat_type                   VARCHAR2 (100);
    -- End of change
    BEGIN
        ln_org_id                     := NULL;
        lv_cat_type                   := NULL;
        lv_cat_owner                  := NULL;
        lc_currency_code              := NULL;
        ln_conv_rate                  := 1;
        ln_non_trade_appr_limit_amt   := NULL;
        ln_req_amount                 := NULL;
        out_approver_rec_final_list   := out_rec_list (NULL);

        -- Getting everything in Functional Currency

        IF lc_currency_code IS NULL
        THEN
            lc_currency_code   :=
                po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;

        -- Get the requisition line currency
        /*BEGIN
           SELECT DISTINCT currency_code
             INTO lc_currency_code
             FROM apps.po_requisition_lines_all
            WHERE requisition_header_id = p_trx_id;
        EXCEPTION
           WHEN OTHERS
           THEN
              lc_currency_code := NULL;
        END;

        IF lc_currency_code IS NULL
        THEN
           lc_currency_code := po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;*/



        IF lc_currency_code <> 'USD'
        THEN
            --Get the corprate conversion rate for SYSDATE to USD
            SELECT rate.conversion_rate
              INTO ln_conv_rate
              FROM apps.gl_daily_rates rate, apps.gl_daily_conversion_types ratetyp
             WHERE     ratetyp.conversion_type = rate.conversion_type
                   AND UPPER (ratetyp.user_conversion_type) = 'CORPORATE'
                   AND rate.from_currency = lc_currency_code
                   AND rate.to_currency = 'USD'
                   AND rate.conversion_date = TRUNC (SYSDATE);
        END IF;

        -- Calculate the Requisition amount

        BEGIN
            SELECT po_ame_setup_pvt.get_changed_req_total (p_trx_id)
              INTO ln_req_amount
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_req_amount   := 0;
        END;

        ln_req_amount                 := ln_req_amount * ln_conv_rate;

        BEGIN
            SELECT TO_NUMBER (fpov.profile_option_value) --Converting approval limit to respective currency for Defect 3181
              INTO ln_non_trade_appr_limit_amt -- All the profile option value amounts set are in USD
              FROM fnd_profile_options fpo, fnd_profile_option_values fpov
             WHERE     fpo.profile_option_id = fpov.profile_option_id
                   AND fpo.profile_option_name = 'DO_REQ_BUYER_LIMIT';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_non_trade_appr_limit_amt   := 0;
        END;


        BEGIN
              SELECT DISTINCT prla.org_id, mc.attribute9
                INTO ln_org_id, lv_cat_type
                FROM apps.mtl_categories mc, apps.po_requisition_lines_all prla
               WHERE     1 = 1
                     AND mc.attribute_category = 'PO Mapping Data Elements'
                     AND mc.category_id = prla.category_id
                     AND prla.requisition_header_id = p_trx_id
            GROUP BY prla.org_id, mc.attribute9
              HAVING   po_ame_setup_pvt.get_changed_req_total (p_trx_id)
                     * ln_conv_rate >
                     ln_non_trade_appr_limit_amt;
        --                  * ln_conv_rate >= ln_non_trade_appr_limit_amt;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_org_id     := NULL;
                lv_cat_type   := NULL;
        END;

        IF ln_org_id IS NOT NULL AND lv_cat_type IS NOT NULL
        THEN
            out_approver_rec_final_list   := out_rec_list (NULL);

            --              OPEN lcu_post_approval_list (cp_trx_id            => p_trx_id,
            --                                   cp_approval_limit    => ln_non_trade_appr_limit_amt,
            --                                   cp_conversion_rate   => ln_conv_rate);


            OPEN lcu_post_approval_list (cp_org_id       => ln_org_id,
                                         cp_req_amount   => ln_req_amount,
                                         cp_cat_type     => lv_cat_type);

            FETCH lcu_post_approval_list BULK COLLECT INTO lt_c1_tab;

            CLOSE lcu_post_approval_list;


            IF lt_c1_tab.COUNT > 0
            THEN
                FOR x IN lt_c1_tab.FIRST .. lt_c1_tab.LAST
                LOOP
                    out_approver_rec_final_list (
                        out_approver_rec_final_list.LAST).approver_id   :=
                        lt_c1_tab (x).person_id;
                    out_approver_rec_final_list.EXTEND;
                END LOOP;
            END IF;

            FOR x IN 1 .. out_approver_rec_final_list.COUNT - 1
            LOOP
                IF out_approver_rec_final_list (x).approver_id IS NULL
                THEN
                    NULL;
                ELSE
                    PIPE ROW (out_approver_rec_final_list (x));
                END IF;
            END LOOP;

            RETURN;
        ELSE
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN;
    END get_post_apprvrlist;

    --function to get APAC finance approver list based on changed amount
    FUNCTION get_apac_finance_apprlist (p_trx_id IN NUMBER)
        RETURN xxd_po_rco_approval_pkg.out_apac_rec_list
        PIPELINED
    IS
        ln_org_id            NUMBER;
        ln_amount            NUMBER;
        lc_currency_code     VARCHAR2 (15);
        ln_conversion_rate   NUMBER := 0;
        ln_app_amount        NUMBER;
        ld_rate_date         DATE;

        CURSOR apac_aprover_list_cur (cp_org_id NUMBER, cp_amount NUMBER)
        IS
            SELECT appr_id
              FROM (  SELECT papf.person_id appr_id
                        FROM fnd_lookup_values flv, apps.hr_organization_units hou, per_all_people_f papf
                       WHERE     flv.LANGUAGE = 'US'
                             AND flv.lookup_type =
                                 'XXDO_REQ_APAC_LIMIT_APPR_LIST'
                             AND flv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN flv.start_date_active
                                             AND NVL (flv.end_date_active,
                                                      SYSDATE + 1)
                             AND hou.NAME = flv.description
                             AND hou.organization_id = cp_org_id
                             AND papf.full_name = flv.attribute1
                             AND papf.employee_number = flv.attribute2
                             AND SYSDATE BETWEEN papf.effective_start_date
                                             AND papf.effective_end_date
                             AND TO_NUMBER (flv.tag) < cp_amount
                    ORDER BY TO_NUMBER (flv.tag) ASC);

        TYPE c1_type IS TABLE OF apac_aprover_list_cur%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_c1_tab            c1_type;
    BEGIN
          SELECT amount, org_id, TRUNC (rate_date)
            INTO ln_amount, ln_org_id, ld_rate_date
            FROM (SELECT sub.amount, prla1.line_num, prla1.org_id,
                         NVL (prla1.rate_date, prla1.creation_date) rate_date
                    FROM apps.po_requisition_lines_all prla1,
                         (  SELECT prla.requisition_header_id, po_ame_setup_pvt.get_changed_req_total (p_trx_id) amount
                              FROM po_requisition_lines_all prla
                             WHERE prla.requisition_header_id = p_trx_id
                          GROUP BY prla.requisition_header_id) sub
                   WHERE sub.requisition_header_id =
                         prla1.requisition_header_id)
        GROUP BY amount, org_id, TRUNC (rate_date);


        -- fetching ledger for getting functional currency
        SELECT currency_code
          INTO lc_currency_code
          FROM hr_operating_units op, gl_ledgers ledgers
         WHERE     organization_id = ln_org_id
               AND op.set_of_books_id = ledgers.ledger_id;

        IF lc_currency_code != 'USD'
        THEN
            /*SELECT conversion_rate
              INTO ln_conversion_rate
              FROM gl_daily_rates
             WHERE from_currency = 'USD'
               AND to_currency = lc_currency_code
               AND conversion_date = ld_rate_date
               AND conversion_type = 'Corporate';*/
            SELECT conversion_rate
              INTO ln_conversion_rate
              FROM gl_daily_rates
             WHERE     from_currency = lc_currency_code
                   AND to_currency = 'USD'
                   AND conversion_date = ld_rate_date
                   AND conversion_type = 'Corporate';
        ELSIF lc_currency_code = 'USD'
        THEN
            ln_conversion_rate   := 1;
        END IF;

        IF ln_conversion_rate = 0
        THEN
            ln_conversion_rate   := 100;
        END IF;

        ln_app_amount                  := ln_amount * ln_conversion_rate;
        out_apac_appr_rec_final_list   := out_apac_rec_list (NULL);

        OPEN apac_aprover_list_cur (cp_org_id   => ln_org_id,
                                    cp_amount   => ln_app_amount);

        FETCH apac_aprover_list_cur BULK COLLECT INTO lt_c1_tab;

        CLOSE apac_aprover_list_cur;

        IF lt_c1_tab.COUNT > 0
        THEN
            FOR x IN lt_c1_tab.FIRST .. lt_c1_tab.LAST
            LOOP
                out_apac_appr_rec_final_list (
                    out_apac_appr_rec_final_list.LAST).approver_id   :=
                    lt_c1_tab (x).appr_id;
                out_apac_appr_rec_final_list.EXTEND;
            END LOOP;
        END IF;

        FOR x IN 1 .. out_apac_appr_rec_final_list.COUNT - 1
        LOOP
            IF out_apac_appr_rec_final_list (x).approver_id IS NULL
            THEN
                NULL;
            ELSE
                PIPE ROW (out_apac_appr_rec_final_list (x));
            END IF;
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN;
    END get_apac_finance_apprlist;

    --Funtion to get APAC finace eilgibility based on changed amount
    FUNCTION get_apac_finance_apprlimit (p_trx_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_org_id            NUMBER;
        ln_amount            NUMBER;
        lc_currency_code     VARCHAR2 (15);
        ln_conversion_rate   NUMBER := 0;
        ln_app_amount        NUMBER;
        ld_rate_date         DATE;
        ln_limit             NUMBER;
        lv_true              VARCHAR2 (1) := 'Y';
        lv_false             VARCHAR2 (1) := 'N';
    BEGIN
          SELECT amount, org_id, TRUNC (rate_date)
            INTO ln_amount, ln_org_id, ld_rate_date
            FROM (SELECT sub.amount, prla1.line_num, prla1.org_id,
                         NVL (prla1.rate_date, prla1.creation_date) rate_date
                    FROM apps.po_requisition_lines_all prla1,
                         (  SELECT prla.requisition_header_id, po_ame_setup_pvt.get_changed_req_total (p_trx_id) amount
                              FROM po_requisition_lines_all prla
                             WHERE prla.requisition_header_id = p_trx_id
                          GROUP BY prla.requisition_header_id) sub
                   WHERE sub.requisition_header_id =
                         prla1.requisition_header_id)
        GROUP BY amount, org_id, TRUNC (rate_date);

        -- fetching ledger for getting functional currency
        SELECT currency_code
          INTO lc_currency_code
          FROM hr_operating_units op, gl_ledgers ledgers
         WHERE     organization_id = ln_org_id
               AND op.set_of_books_id = ledgers.ledger_id;

        IF lc_currency_code != 'USD'
        THEN
            SELECT conversion_rate
              INTO ln_conversion_rate
              FROM gl_daily_rates
             WHERE     from_currency = lc_currency_code
                   AND to_currency = 'USD'
                   AND conversion_date = ld_rate_date
                   AND conversion_type = 'Corporate';
        END IF;

        IF ln_conversion_rate = 0
        THEN
            ln_conversion_rate   := 100;
        END IF;

        -- ln_app_amount := ln_amount * ln_conversion_rate; -- commented

        -- SELECT MIN (tag)
        IF lc_currency_code != 'USD'
        THEN
            SELECT MIN (tag) / ln_conversion_rate                 -- Added New
              INTO ln_limit
              FROM fnd_lookup_values flv, apps.hr_organization_units hou
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_REQ_APAC_LIMIT_APPR_LIST'
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN flv.start_date_active
                                   AND NVL (flv.end_date_active, SYSDATE + 1)
                   AND hou.NAME = flv.description
                   AND hou.organization_id = ln_org_id;
        ELSIF lc_currency_code = 'USD'
        THEN
            SELECT MIN (tag)                                      -- Added New
              INTO ln_limit
              FROM fnd_lookup_values flv, apps.hr_organization_units hou
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_REQ_APAC_LIMIT_APPR_LIST'
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN flv.start_date_active
                                   AND NVL (flv.end_date_active, SYSDATE + 1)
                   AND hou.NAME = flv.description
                   AND hou.organization_id = ln_org_id;
        END IF;

        IF ln_amount > ln_limit
        THEN
            RETURN lv_true;
        ELSE
            RETURN lv_false;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN lv_false;
    END get_apac_finance_apprlimit;

    --function to chnage buyer on purchase order when buyer approver is chnaged

    FUNCTION change_po_buyer (p_trx_id IN NUMBER)
        RETURN xxd_po_rco_approval_pkg.out_rec_list
        PIPELINED
    IS
        -- PRAGMA AUTONOMOUS_TRANSACTION;

        -- Commented as per change 1.3

        /*CURSOR lcu_post_approval_list (
           cp_trx_id             NUMBER,
           cp_approval_limit     NUMBER,
           cp_conversion_rate    NUMBER)
        IS
           SELECT attribute1
             FROM (  SELECT pf.person_id attribute1
                       FROM fnd_lookup_values flv,
                            per_people_f pf,
                            (SELECT DISTINCT pf.full_name appr_name
                               FROM mtl_categories mc, per_people_f pf
                              WHERE     mc.attribute_category =
                                           'PO Mapping Data Elements'
                                    AND mc.category_id IN
                                           (SELECT prla.category_id
                                              FROM po_requisition_lines_all prla
                                             WHERE prla.requisition_header_id =
                                                      cp_trx_id)
                                    AND EXISTS
                                           (  SELECT 1
                                                FROM po_requisition_lines_all prla1
                                               WHERE prla1.requisition_header_id =
                                                        cp_trx_id
                                            GROUP BY prla1.requisition_header_id
                                              HAVING po_ame_setup_pvt.get_changed_req_total (
                                                        cp_trx_id) >=
                                                        cp_approval_limit)
                                    AND pf.person_id = mc.attribute1) pf_name
                      WHERE     flv.LANGUAGE = 'US'
                            AND flv.lookup_type = 'XXDO_REQ_BUYER_APPR_LIST'
                            AND enabled_flag = 'Y'
                            AND SYSDATE BETWEEN start_date_active
                                            AND NVL (end_date_active,
                                                     SYSDATE + 1)
                            AND flv.description = pf_name.appr_name
                            AND (flv.tag * cp_conversion_rate) <=
                                   (SELECT po_ame_setup_pvt.get_changed_req_total (
                                              cp_trx_id)
                                              amount
                                      FROM DUAL)
                            AND pf.full_name = flv.meaning
                   ORDER BY TO_NUMBER (flv.tag) DESC)
            WHERE ROWNUM = 1; */

        CURSOR lcu_post_approval_list (cp_org_id IN NUMBER, cp_req_amount IN NUMBER, cp_cat_type IN VARCHAR2)
        IS
            SELECT DISTINCT papf.person_id
              FROM apps.per_all_people_f papf, apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
             WHERE     ffvs.flex_value_set_name = 'XXD_PO_NT_EMP_MGR_VS'
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvl.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                                   AND NVL (ffvl.end_date_active, SYSDATE)
                   AND SYSDATE BETWEEN NVL (papf.effective_start_date,
                                            SYSDATE)
                                   AND NVL (papf.effective_end_date, SYSDATE)
                   AND ffvl.attribute1 = cp_org_id
                   AND NVL (ffvl.attribute6, cp_cat_type) = cp_cat_type
                   AND papf.full_name = ffvl.attribute4
                   AND cp_req_amount >=
                       NVL (ffvl.attribute3, cp_req_amount + 1)
                   AND cp_req_amount <=
                       NVL (ffvl.attribute5, cp_req_amount + 1);

        --Added on 30-Apr-2017 to fix multiple PO issue CCR0007258
        CURSOR req_po_cur IS
            SELECT DISTINCT ph.po_header_id, ph.agent_id, ph.authorization_status
              FROM po_headers_all ph, po_lines_all pl, po_distributions_all pd,
                   po_requisition_headers_all prh, po_requisition_lines_all prl, po_req_distributions_all prd
             WHERE     ph.po_header_id = pl.po_header_id
                   AND ph.po_header_id = pd.po_header_id
                   AND pl.po_line_id = pd.po_line_id             -- CCR0007258
                   AND pd.req_distribution_id = prd.distribution_id
                   AND prl.requisition_line_id = prd.requisition_line_id
                   AND prh.requisition_header_id = prl.requisition_header_id
                   AND prh.requisition_header_id = p_trx_id
                   AND ph.authorization_status IN
                           ('APPROVED', 'IN PROCESS', 'REQUIRES REAPPROVAL');

        -- END CCR0007258

        --AND prl.requisition_line_id = req_change_line_rec.requisition_line_id;
        TYPE c1_type IS TABLE OF lcu_post_approval_list%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_c1_tab                     c1_type;
        ln_non_trade_appr_limit_amt   NUMBER := 0;
        ln_new_buyer_id               NUMBER;
        ln_po_header_id               NUMBER;
        ln_current_buyer_id           NUMBER;
        lv_error                      VARCHAR2 (2000);
        lc_currency_code              VARCHAR2 (50) := NULL;
        ln_conv_rate                  NUMBER DEFAULT 1;
        ln_action_history             NUMBER := 0;
        ln_change_request             NUMBER := 0;
        ln_approval_count             NUMBER := 0;
        lv_po_status                  VARCHAR2 (30);
        ld_change_date                TIMESTAMP;
        ln_po_count                   NUMBER;
        ln_org_id                     NUMBER;
        ln_req_amount                 NUMBER;
        lv_cat_owner                  VARCHAR2 (100);
        lv_cat_type                   VARCHAR2 (100);
    BEGIN
        lc_currency_code   := NULL;                   --- Added for CCR0008534

        -- Start of Change for CCR0008534

        -- Getting everything in Functional Currency

        IF lc_currency_code IS NULL
        THEN
            lc_currency_code   :=
                po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;

        -- Get the requisition line currency
        /*BEGIN
           SELECT DISTINCT currency_code
             INTO lc_currency_code
             FROM apps.po_requisition_lines_all
            WHERE requisition_header_id = p_trx_id;
        EXCEPTION
           WHEN OTHERS
           THEN
              lc_currency_code := NULL;
        END;

        IF lc_currency_code IS NULL
        THEN
           lc_currency_code := po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;*/

        -- End of Change

        IF lc_currency_code <> 'USD'
        THEN
            --Get the corprate conversion rate for SYSDATE to USD
            SELECT rate.conversion_rate
              INTO ln_conv_rate
              FROM apps.gl_daily_rates rate, apps.gl_daily_conversion_types ratetyp
             WHERE     ratetyp.conversion_type = rate.conversion_type
                   AND UPPER (ratetyp.user_conversion_type) = 'CORPORATE'
                   --                AND rate.from_currency = 'USD'
                   --                AND rate.to_currency = lc_currency_code
                   AND rate.from_currency = lc_currency_code
                   AND rate.to_currency = 'USD'
                   AND rate.conversion_date = TRUNC (SYSDATE);
        END IF;

        -- All the profile option values set are in USD only

        -- Get the Buyer Limit from the profile Option

        BEGIN
            SELECT TO_NUMBER (fpov.profile_option_value)
              INTO ln_non_trade_appr_limit_amt
              FROM fnd_profile_options fpo, fnd_profile_option_values fpov
             WHERE     fpo.profile_option_id = fpov.profile_option_id
                   AND fpo.profile_option_name = 'DO_REQ_BUYER_LIMIT';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_non_trade_appr_limit_amt   := 0;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_po_count
              FROM po_headers_all ph, po_lines_all pl, po_distributions_all pd,
                   po_requisition_headers_all prh, po_requisition_lines_all prl, po_req_distributions_all prd
             WHERE     ph.po_header_id = pl.po_header_id
                   AND ph.po_header_id = pd.po_header_id
                   AND pl.po_line_id = pd.po_line_id             -- CCR0007258
                   AND pd.req_distribution_id = prd.distribution_id
                   AND prl.requisition_line_id = prd.requisition_line_id
                   AND prh.requisition_header_id = prl.requisition_header_id
                   AND prh.requisition_header_id = p_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_po_count   := 0;
        END;

        IF ln_po_count > 0
        THEN
            SELECT COUNT (*)
              INTO ln_change_request
              FROM po_change_requests
             WHERE document_header_id = p_trx_id AND request_status = 'NEW';

            IF ln_change_request > 0
            THEN
                -- Initialised variables to NULL as per change 1.3
                ld_change_date      := NULL;
                ln_action_history   := 0;
                ln_approval_count   := 0;
                ln_new_buyer_id     := 0;

                SELECT MAX (creation_date)
                  INTO ld_change_date
                  FROM po_change_requests
                 WHERE     document_header_id = p_trx_id
                       AND request_status = 'NEW';

                SELECT COUNT (*)
                  INTO ln_action_history
                  FROM ame_trans_approval_history
                 WHERE     transaction_id = p_trx_id
                       AND status = 'APPROVE'
                       AND group_or_chain_id = 16010
                       AND row_timestamp > ld_change_date;

                SELECT COUNT (*)
                  INTO ln_approval_count
                  FROM TABLE (xxd_po_rco_approval_pkg.get_apprlist (p_trx_id))
                 WHERE     approver NOT IN
                               (SELECT approver_id FROM TABLE (xxd_po_rco_approval_pkg.get_post_apprvrlist (p_trx_id)))
                       AND approver NOT IN
                               (SELECT approver_id FROM TABLE (xxd_po_rco_approval_pkg.get_apac_finance_apprlist (p_trx_id)));

                BEGIN
                    SELECT approver_id
                      INTO ln_new_buyer_id
                      FROM TABLE (xxd_po_rco_approval_pkg.get_post_apprvrlist (p_trx_id));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_new_buyer_id   := NULL;
                END;

                -- START CURSOR CCR0007258
                FOR req_po_rec IN req_po_cur
                LOOP
                    IF     ln_approval_count = ln_action_history
                       AND ln_new_buyer_id <> (req_po_rec.agent_id)
                    THEN
                        BEGIN
                            change_buyer (req_po_rec.po_header_id,
                                          ln_new_buyer_id,
                                          p_trx_id);
                            po_approval (req_po_rec.po_header_id,
                                         ln_new_buyer_id,
                                         p_trx_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error   := SQLERRM;
                        END;
                    END IF;
                END LOOP;
            -- END CCR0007258
            END IF;
        END IF;

        -- Commnted as per change 1.3

        /*out_approver_rec_final_list := out_rec_list (NULL);

        OPEN lcu_post_approval_list (cp_trx_id            => p_trx_id,
                                     cp_approval_limit    => ln_non_trade_appr_limit_amt,
                                     cp_conversion_rate   => ln_conv_rate);

        FETCH lcu_post_approval_list
           BULK COLLECT INTO lt_c1_tab;

        CLOSE lcu_post_approval_list;

        IF lt_c1_tab.COUNT > 0
        THEN
           FOR x IN lt_c1_tab.FIRST .. lt_c1_tab.LAST
           LOOP
              out_approver_rec_final_list (out_approver_rec_final_list.LAST).approver_id :=
                 lt_c1_tab (x).attribute1;
              out_approver_rec_final_list.EXTEND;
           END LOOP;
        END IF;

        FOR x IN 1 .. out_approver_rec_final_list.COUNT - 1
        LOOP
           IF out_approver_rec_final_list (x).approver_id IS NULL
           THEN
              NULL;
           ELSE
              PIPE ROW (out_approver_rec_final_list (x));
           END IF;
        END LOOP;

        RETURN;*/

        -- Calculate the Requisition amount

        BEGIN
            SELECT po_ame_setup_pvt.get_changed_req_total (p_trx_id)
              INTO ln_req_amount
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_req_amount   := 0;
        END;

        ln_req_amount      := ln_req_amount * ln_conv_rate;

        BEGIN
              SELECT DISTINCT prla.org_id, mc.attribute9
                INTO ln_org_id, lv_cat_type
                FROM apps.mtl_categories mc, apps.po_requisition_lines_all prla
               WHERE     1 = 1
                     AND mc.attribute_category = 'PO Mapping Data Elements'
                     AND mc.category_id = prla.category_id
                     AND prla.requisition_header_id = p_trx_id
            GROUP BY prla.org_id, mc.attribute9
              HAVING   po_ame_setup_pvt.get_changed_req_total (p_trx_id)
                     * ln_conv_rate >
                     ln_non_trade_appr_limit_amt;
        --                  * ln_conv_rate >= ln_non_trade_appr_limit_amt;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_org_id     := NULL;
                lv_cat_type   := NULL;
        END;

        IF ln_org_id IS NOT NULL AND lv_cat_type IS NOT NULL
        THEN
            out_approver_rec_final_list   := out_rec_list (NULL);

            --              OPEN lcu_post_approval_list (cp_trx_id            => p_trx_id,
            --                                   cp_approval_limit    => ln_non_trade_appr_limit_amt,
            --                                   cp_conversion_rate   => ln_conv_rate);


            OPEN lcu_post_approval_list (cp_org_id       => ln_org_id,
                                         cp_req_amount   => ln_req_amount,
                                         cp_cat_type     => lv_cat_type);

            FETCH lcu_post_approval_list BULK COLLECT INTO lt_c1_tab;

            CLOSE lcu_post_approval_list;


            IF lt_c1_tab.COUNT > 0
            THEN
                FOR x IN lt_c1_tab.FIRST .. lt_c1_tab.LAST
                LOOP
                    out_approver_rec_final_list (
                        out_approver_rec_final_list.LAST).approver_id   :=
                        lt_c1_tab (x).person_id;
                    out_approver_rec_final_list.EXTEND;
                END LOOP;
            END IF;

            FOR x IN 1 .. out_approver_rec_final_list.COUNT - 1
            LOOP
                IF out_approver_rec_final_list (x).approver_id IS NULL
                THEN
                    NULL;
                ELSE
                    PIPE ROW (out_approver_rec_final_list (x));
                END IF;
            END LOOP;

            RETURN;
        ELSE
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error   := SQLERRM;
            RETURN;
    END change_po_buyer;

    --procedure to chnage buyer name on purchase order
    PROCEDURE change_buyer (pn_po_header_id    NUMBER,
                            pn_new_buyer_id    NUMBER,
                            pn_req_header_id   NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR po_details_cur (cp_po_header_id NUMBER)
        IS
            SELECT pha.ROWID, pha.*
              FROM po_headers_all pha
             WHERE pha.po_header_id = cp_po_header_id;

        lv_error        VARCHAR2 (2000);
        ln_changed_po   NUMBER;
    BEGIN
        BEGIN
            FOR hdr_rec IN po_details_cur (pn_po_header_id)
            LOOP
                apps.po_headers_pkg_s3.update_row (
                    x_rowid                    => hdr_rec.ROWID,
                    x_po_header_id             => hdr_rec.po_header_id,
                    x_agent_id                 => pn_new_buyer_id,
                    x_type_lookup_code         => hdr_rec.type_lookup_code,
                    x_last_update_date         => hdr_rec.last_update_date,
                    x_last_updated_by          => hdr_rec.last_updated_by,
                    x_segment1                 => hdr_rec.segment1,
                    x_summary_flag             => hdr_rec.summary_flag,
                    x_enabled_flag             => hdr_rec.enabled_flag,
                    x_segment2                 => hdr_rec.segment2,
                    x_segment3                 => hdr_rec.segment3,
                    x_segment4                 => hdr_rec.segment4,
                    x_segment5                 => hdr_rec.segment5,
                    x_last_update_login        => hdr_rec.last_update_login,
                    x_vendor_id                => hdr_rec.vendor_id,
                    x_vendor_site_id           => hdr_rec.vendor_site_id,
                    x_vendor_contact_id        => hdr_rec.vendor_contact_id,
                    x_ship_to_location_id      => hdr_rec.ship_to_location_id,
                    x_bill_to_location_id      => hdr_rec.bill_to_location_id,
                    x_terms_id                 => hdr_rec.terms_id,
                    x_ship_via_lookup_code     => hdr_rec.ship_via_lookup_code,
                    x_fob_lookup_code          => hdr_rec.fob_lookup_code,
                    x_freight_terms_lookup_code   =>
                        hdr_rec.freight_terms_lookup_code,
                    x_status_lookup_code       => hdr_rec.status_lookup_code,
                    x_currency_code            => hdr_rec.currency_code,
                    x_rate_type                => hdr_rec.rate_type,
                    x_rate_date                => hdr_rec.rate_date,
                    x_rate                     => hdr_rec.rate,
                    x_from_header_id           => hdr_rec.from_header_id,
                    x_from_type_lookup_code    => hdr_rec.from_type_lookup_code,
                    x_start_date               => hdr_rec.start_date,
                    x_end_date                 => hdr_rec.end_date,
                    x_revision_num             => hdr_rec.revision_num,
                    x_revised_date             => hdr_rec.revised_date,
                    x_note_to_vendor           => hdr_rec.note_to_vendor,
                    x_printed_date             => hdr_rec.printed_date,
                    x_comments                 => hdr_rec.comments,
                    x_reply_date               => hdr_rec.reply_date,
                    x_reply_method_lookup_code   =>
                        hdr_rec.reply_method_lookup_code,
                    x_rfq_close_date           => hdr_rec.rfq_close_date,
                    x_quote_type_lookup_code   =>
                        hdr_rec.quote_type_lookup_code,
                    x_quotation_class_code     => hdr_rec.quotation_class_code,
                    x_quote_warning_delay      => hdr_rec.quote_warning_delay,
                    x_quote_vendor_quote_number   =>
                        hdr_rec.quote_vendor_quote_number,
                    x_closed_date              => hdr_rec.closed_date,
                    x_approval_required_flag   =>
                        hdr_rec.approval_required_flag,
                    x_attribute_category       => hdr_rec.attribute_category,
                    x_attribute1               => hdr_rec.attribute1,
                    x_attribute2               => hdr_rec.attribute2,
                    x_attribute3               => hdr_rec.attribute3,
                    x_attribute4               => hdr_rec.attribute4,
                    x_attribute5               => hdr_rec.attribute5,
                    x_attribute6               => hdr_rec.attribute6,
                    x_attribute7               => hdr_rec.attribute7,
                    x_attribute8               => hdr_rec.attribute8,
                    x_attribute9               => hdr_rec.attribute9,
                    x_attribute10              => hdr_rec.attribute10,
                    x_attribute11              => hdr_rec.attribute11,
                    x_attribute12              => hdr_rec.attribute12,
                    x_attribute13              => hdr_rec.attribute13,
                    x_attribute14              => hdr_rec.attribute14,
                    x_attribute15              => hdr_rec.attribute15);
                COMMIT;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error   := SQLERRM;
        END;
    END change_buyer;

    PROCEDURE po_approval (pn_po_header_id    NUMBER,
                           pn_new_buyer_id    NUMBER,
                           pn_req_header_id   NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR po_details_cur (cp_po_header_id NUMBER)
        IS
            SELECT pha.ROWID, DECODE (pha.type_lookup_code,  'BLANKET', 'PA',  'CONTRACT', 'PA',  'PO') doc_type, pha.*
              FROM po_headers_all pha
             WHERE pha.po_header_id = cp_po_header_id;

        lv_error          VARCHAR2 (2000);
        ln_changed_po     NUMBER;
        x_return_status   VARCHAR2 (1);
        x_msg_data        VARCHAR2 (2000);
    BEGIN
        BEGIN
            FOR hdr_rec IN po_details_cur (pn_po_header_id)
            LOOP
                BEGIN
                    -- Check if purchase order is changed requistion line purchase order
                    SELECT COUNT (*)
                      INTO ln_changed_po
                      FROM po_headers_all ph, po_lines_all pl, po_distributions_all pd,
                           po_requisition_headers_all prh, po_requisition_lines_all prl, po_req_distributions_all prd,
                           po_change_requests pr
                     WHERE     ph.po_header_id = pl.po_header_id
                           AND ph.po_header_id = pd.po_header_id
                           AND pd.req_distribution_id = prd.distribution_id
                           AND prl.requisition_line_id =
                               prd.requisition_line_id
                           AND prh.requisition_header_id =
                               prl.requisition_header_id
                           AND prh.requisition_header_id = pn_req_header_id
                           AND pr.document_header_id =
                               prh.requisition_header_id
                           AND pr.document_line_id = prd.requisition_line_id
                           AND pr.request_status = 'NEW'
                           AND ph.po_header_id = pn_po_header_id;

                    IF ln_changed_po = 0
                    THEN
                        apps.po_document_action_pvt.do_approve (
                            p_document_id        => pn_po_header_id,
                            p_document_type      => hdr_rec.doc_type,
                            p_document_subtype   => hdr_rec.type_lookup_code,
                            p_note               => NULL,
                            p_approval_path_id   => NULL,
                            x_return_status      => x_return_status,
                            x_exception_msg      => x_msg_data);
                    --Manual approval is required for PO which is not part of requistion line modification
                    /*  po_reqapproval_init1.start_wf_process
                              (itemtype                    => 'POAPPRV',
                               itemkey                     => hdr_rec.wf_item_key,---wf_item_key,
                               workflowprocess             => 'XXDO_POAPPRV_TOP',
                               actionoriginatedfrom        => 'PO_FORM',
                               documentid                  => pn_po_header_id, -- po_header_id
                               documentnumber              => hdr_rec.segment1,-- Purchase Order Number
                               preparerid                  => pn_new_buyer_id,  -- Buyer/Preparer_id
                               documenttypecode            => 'PO',  --'PO'
                               documentsubtype             => 'STANDARD',
                               submitteraction             => 'APPROVE',
                               forwardtoid                 => NULL,
                               forwardfromid               => NULL,
                               defaultapprovalpathid       => NULL,
                               note                        => NULL,
                               printflag                   => 'N',
                               faxflag                     => 'N',
                               faxnumber                   => NULL,
                               emailflag                   => 'N',
                               emailaddress                => NULL,
                               createsourcingrule          => 'N',
                               releasegenmethod            => 'N',
                               updatesourcingrule          => 'N',
                               massupdatereleases          => 'N',
                               retroactivepricechange      => 'N',
                               orgassignchange             => 'N',
                               communicatepricechange      => 'N',
                               p_background_flag           => 'N',
                               p_initiator                 => NULL,
                               p_xml_flag                  => NULL,
                               fpdsngflag                  => 'N',
                               p_source_type_code          => NULL
                              );*/
                    END IF;
                END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error   := SQLERRM;
        END;
    END po_approval;

    --fucntion to get buyer approver limit
    FUNCTION get_req_eligible (p_transaction_id NUMBER)
        RETURN NUMBER
    IS
        lc_currency_code              VARCHAR2 (50) := NULL;
        lv_return                     VARCHAR2 (10) := NULL;
        ln_unit_price                 NUMBER;
        lv_conv_rate                  NUMBER := 1;
        ln_requisition_line_id        NUMBER;
        ln_non_trade_appr_limit_amt   NUMBER := 0;

        -- TOTAL_REQ_AMOUNT - Start
        ln_total_price                NUMBER;
    -- TOTAL_REQ_AMOUNT - End


    BEGIN
        lc_currency_code   := NULL;                   --- Added for CCR0008534

        --      lc_currency_code :=
        --         po_ame_setup_pvt.get_function_currency (p_transaction_id);

        --Get the approval limit set for Non-Trade Requistion from profile DO_REQ_BUYER_LIMIT
        SELECT TO_NUMBER (fpov.profile_option_value)
          INTO ln_non_trade_appr_limit_amt
          FROM fnd_profile_options fpo, fnd_profile_option_values fpov
         WHERE     fpo.profile_option_id = fpov.profile_option_id
               AND fpo.profile_option_name = 'DO_REQ_BUYER_LIMIT';

        BEGIN
            SELECT po_ame_setup_pvt.get_changed_req_total (p_transaction_id)
              INTO ln_total_price
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_total_price   := 0;
        END;

        -- TOTAL_REQ_AMOUNT - End

        -- Start of Change for CCR0008534

        -- Getting everything in Functional Currency

        IF lc_currency_code IS NULL
        THEN
            lc_currency_code   :=
                po_ame_setup_pvt.get_function_currency (p_transaction_id);
        END IF;

        -- Get the requisition line currency
        /*BEGIN
           SELECT DISTINCT currency_code
             INTO lc_currency_code
             FROM apps.po_requisition_lines_all
            WHERE requisition_header_id = p_transaction_id;
        EXCEPTION
           WHEN OTHERS
           THEN
              lc_currency_code := NULL;
        END;

        IF lc_currency_code IS NULL
        THEN
           lc_currency_code :=
              po_ame_setup_pvt.get_function_currency (p_transaction_id);
        END IF;*/

        -- End of Change

        --When currency of requistion is non USD,do a corporate rate conversion.
        IF lc_currency_code <> 'USD'
        THEN
            --Get the corprate conversion rate for SYSDATE
            SELECT rate.conversion_rate
              INTO lv_conv_rate
              FROM apps.gl_daily_rates rate, apps.gl_daily_conversion_types ratetyp
             WHERE     ratetyp.conversion_type = rate.conversion_type
                   AND UPPER (ratetyp.user_conversion_type) = 'CORPORATE'
                   AND rate.from_currency = lc_currency_code
                   AND rate.to_currency = 'USD'
                   AND rate.conversion_date = TRUNC (SYSDATE);

            ln_total_price   := ln_total_price * lv_conv_rate;

            --         IF ln_total_price >= ln_non_trade_appr_limit_amt
            --         THEN
            --            RETURN 1;
            --         ELSE
            --            RETURN 0;
            --         END IF;
            -- TOTAL_REQ_AMOUNT - End
            IF ln_total_price > ln_non_trade_appr_limit_amt
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        ELSE
            IF ln_total_price > ln_non_trade_appr_limit_amt
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        --         IF ln_total_price >= ln_non_trade_appr_limit_amt
        --         THEN
        --            RETURN 1;
        --         ELSE
        --            RETURN 0;
        --         END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_req_eligible;

    -- START CCR0007258

    FUNCTION get_req_buyer_change_eligible (p_transaction_id NUMBER)
        RETURN NUMBER
    IS
        ln_old_buyer   NUMBER;
        ln_new_buyer   NUMBER;
    BEGIN
        /*SELECT NVL (approver_id,
                     (SELECT DISTINCT ppf1.person_id
                                 FROM po_requisition_headers_all pha,
                                      po_requisition_lines_all pla,
                                      mtl_categories mc,
                                      per_people_f ppf,
                                      fnd_lookup_values fv,
                                      per_people_f ppf1
                                WHERE pha.requisition_header_id = p_transaction_id
                                  AND pla.requisition_header_id =  pha.requisition_header_id
                                  AND pla.category_id = mc.category_id
                                  AND ppf.person_id = mc.attribute1
                                  AND fv.description = ppf.full_name
                                  AND fv.lookup_type = 'XXDO_REQ_BUYER_APPR_LIST'
                                  AND fv.LANGUAGE = 'US'
                                  AND fv.enabled_flag = 'Y'
                                  AND SYSDATE BETWEEN fv.start_date_active AND NVL (fv.end_date_active,SYSDATE + 1)
                                  AND ppf1.full_name = fv.meaning
                                  AND fv.tag =  (SELECT MIN (tag)
                                                   FROM fnd_lookup_values fv1
                                                  WHERE fv1.lookup_type = 'XXDO_REQ_BUYER_APPR_LIST'
                                                    AND fv1.LANGUAGE = 'US'
                                                    AND fv1.enabled_flag = 'Y'
                                                    AND SYSDATE   BETWEEN fv1.start_date_active  AND NVL (fv1.end_date_active,SYSDATE + 1)))
                    )
           INTO ln_old_buyer
           FROM TABLE (xxd_po_rco_approval_pkg.get_post_apprvrlist (p_transaction_id));*/

        SELECT NVL (
                   (SELECT approver_id FROM TABLE (xxd_po_req_approval_pkg.get_post_apprvrlist (p_transaction_id))),
                   (SELECT DISTINCT ppf1.person_id
                      FROM po_requisition_headers_all pha, po_requisition_lines_all pla, mtl_categories mc,
                           per_people_f ppf, fnd_lookup_values fv, per_people_f ppf1
                     WHERE     pha.requisition_header_id = p_transaction_id
                           AND pla.requisition_header_id =
                               pha.requisition_header_id
                           AND pla.category_id = mc.category_id
                           AND ppf.person_id = mc.attribute1
                           AND fv.description = ppf.full_name
                           AND fv.lookup_type = 'XXDO_REQ_BUYER_APPR_LIST'
                           AND fv.LANGUAGE = 'US'
                           AND fv.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN fv.start_date_active
                                           AND NVL (fv.end_date_active,
                                                    SYSDATE + 1)
                           AND ppf1.full_name = fv.meaning
                           AND fv.tag =
                               (SELECT MIN (tag)
                                  FROM fnd_lookup_values fv1
                                 WHERE     fv1.lookup_type =
                                           'XXDO_REQ_BUYER_APPR_LIST'
                                       AND fv1.LANGUAGE = 'US'
                                       AND fv1.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN fv1.start_date_active
                                                       AND NVL (
                                                               fv1.end_date_active,
                                                               SYSDATE + 1))))
          INTO ln_old_buyer
          FROM DUAL;

        SELECT APPROVER_ID
          INTO ln_new_buyer
          FROM TABLE (XXD_PO_RCO_APPROVAL_PKG.get_post_apprvrlist (p_transaction_id));

        IF ln_old_buyer <> ln_new_buyer
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_req_buyer_change_eligible;

    -- Added New function as per change 1.7
    FUNCTION is_req_auto_approved (p_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        lc_currency_code        VARCHAR2 (50) := NULL;
        ln_req_approval_limit   NUMBER := 0;
        ln_total_price          NUMBER := 0;
        ln_conv_rate            NUMBER := 1;
    BEGIN
        lc_currency_code   := NULL;                    -- Added for CCR0008534

        -- Get the Approval limit set for Operating Unit

        BEGIN
            SELECT fpov.profile_option_value
              INTO ln_req_approval_limit
              FROM fnd_profile_options fpo, fnd_profile_option_values fpov, po_requisition_headers_all req
             WHERE     fpo.profile_option_id = fpov.profile_option_id
                   AND fpo.profile_option_name =
                       'DO_REQ_MIN_AUTO_APPROVAL_AMOUNT'
                   AND fpov.level_value = req.org_id
                   AND req.requisition_header_id = p_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_req_approval_limit   := 0;
        END;

        -- Get the Requisition amount

        BEGIN
            SELECT po_ame_setup_pvt.get_changed_req_total (p_trx_id)
              INTO ln_total_price
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_total_price   := 0;
        END;

        -- Start of Change for CCR0008534

        -- Getting everything in Functional Currency

        IF lc_currency_code IS NULL
        THEN
            lc_currency_code   :=
                po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;

        -- Get the requisition line currency
        /*BEGIN
           SELECT DISTINCT currency_code
             INTO lc_currency_code
             FROM apps.po_requisition_lines_all
            WHERE requisition_header_id = p_trx_id;
        EXCEPTION
           WHEN OTHERS
           THEN
              lc_currency_code := NULL;
        END;

        IF lc_currency_code IS NULL
        THEN
           lc_currency_code := po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;*/


        -- End of Change

        IF lc_currency_code <> 'USD'
        THEN
            --Get the corprate conversion rate for SYSDATE
            SELECT rate.conversion_rate
              INTO ln_conv_rate
              FROM apps.gl_daily_rates rate, apps.gl_daily_conversion_types ratetyp
             WHERE     ratetyp.conversion_type = rate.conversion_type
                   AND UPPER (ratetyp.user_conversion_type) = 'CORPORATE'
                   AND rate.from_currency = lc_currency_code
                   AND rate.to_currency = 'USD'
                   AND rate.conversion_date = TRUNC (SYSDATE);

            -- TOTAL_REQ_AMOUNT - Start
            ln_total_price   := ln_total_price * ln_conv_rate;

            --         IF ln_req_approval_limit > ln_total_price
            IF ln_req_approval_limit >= ln_total_price
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        -- TOTAL_REQ_AMOUNT - End

        ELSE
            --         IF ln_req_approval_limit > ln_total_price
            IF ln_req_approval_limit >= ln_total_price
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        END IF;
    END is_req_auto_approved;

    FUNCTION get_unit_price (p_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        lv_type              VARCHAR2 (20) := NULL;
        ln_line_type_id      NUMBER := NULL;
        ln_curr_unit_price   NUMBER := NULL;
        ln_unit_price        NUMBER := NULL;
        ln_price             NUMBER := NULL;
        lv_func_curr_code    VARCHAR2 (10) := NULL;
        lv_currency_code     VARCHAR2 (10) := NULL;
    BEGIN
        -- Get Functional Currency for the Requisition

        lv_func_curr_code   := NULL;

        lv_func_curr_code   :=
            po_ame_setup_pvt.get_function_currency (p_trx_id);

        -- Get Transactional  Currency code for the Requisition

        BEGIN
            SELECT DISTINCT currency_code
              INTO lv_currency_code
              FROM apps.po_requisition_lines_all
             WHERE requisition_header_id = p_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_currency_code   := NULL;
        END;

        IF lv_currency_code IS NULL
        THEN
            lv_currency_code   :=
                po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;


        BEGIN
            SELECT unit_price, currency_unit_price, line_type_id
              INTO ln_unit_price, ln_curr_unit_price, ln_line_type_id
              FROM apps.po_requisition_lines_all
             WHERE requisition_header_id = p_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_unit_price        := 1;
                ln_curr_unit_price   := 1;
        END;

        -- Start of Change for CCR0008534

        ln_price            := ln_unit_price;

        /* IF lv_func_curr_code = lv_currency_code
         THEN
            ln_price := ln_unit_price;
         ELSIF     lv_func_curr_code <> lv_currency_code
               AND lv_currency_code = 'USD'
         THEN
            ln_price := ln_unit_price;                      --ln_curr_unit_price;
         ELSIF     lv_func_curr_code <> lv_currency_code
               AND lv_currency_code <> 'USD'
         THEN
            ln_price := ln_unit_price;
         END IF; */

        /*IF lv_func_curr_code = lv_currency_code
        THEN
           ln_price := ln_unit_price;
        ELSIF lv_func_curr_code <> lv_currency_code
        THEN
           BEGIN
              SELECT attribute1
                INTO lv_type
                FROM po_line_types_v
               WHERE line_type_id = ln_line_type_id;
           EXCEPTION
              WHEN OTHERS
              THEN
                 lv_type := 'NO';
           END;

           IF lv_type IS NULL
           THEN
              lv_type := 'NO';
           END IF;
        END IF;

        IF NVL (lv_type, 'NO') = 'YES'
        THEN
           ln_price := ln_curr_unit_price;
        ELSE
           ln_price := ln_unit_price;
        END IF;*/

        -- End of Change for CCR0008534

        RETURN ln_price;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_unit_price;
-- End of Change

END XXD_PO_RCO_APPROVAL_PKG;
/
