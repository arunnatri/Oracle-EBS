--
-- XXD_PO_REQ_APPROVAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_REQ_APPROVAL_PKG"
AS
    /******************************************************************************
       NAME: XXD_REQ_APPROVAL_PKG

       Ver        Date        Author                       Description
       ---------  ----------  ---------------           ------------------------------------
       1.0        14/10/2014  BT Technology Team        Function to return approval list ( AME )
       1.1        20/07/2015  BT Technology Team        Modified for CR 57
       1.2        13/10/2015  BT Technology Team        Conversion Rate addition for Defect 3181
       1.3        19/10/2015  BT Technology Team        Conversion Rate variable init for UAT2 Defect 13
       1.4        17/08/2016  Infosys                   DFCT0011414 - PRs Not Going to Buyer for Approval
       1.5        27/04/2017  Bala Murugesan            Modified to consider the employee level approval limits;
                                                        Changes identified by EMPLOYEE_LIMITS
       1.5        27/04/2017  Bala Murugesan            Modified to consider the total price of Req
                                                        instead of maximum line price;
                                                        Changes identified by TOTAL_REQ_AMOUNT
       1.6        27/12/2017  Tejaswi Gangumalla        Modified funtion get_post_apprvlist to get buyer approval bases on limit for CSR 4741
       1.6        27/12/2017  Tejaswi Gangumalla        Added funtion get_apac_finance_apprlist,get_apac_finance_apprlimit for APAC Fiance approver for CSR 4741
       1.7        11/07/2019  Srinath Siricilla         CCR0008214
       1.8        01/09/2020  Srinath Siricilla         CCR0008534
    ******************************************************************************/
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
        RETURN XXD_PO_REQ_APPROVAL_PKG.out_rec
        PIPELINED
    IS
        ln_amount            NUMBER;
        ln_per_id            NUMBER;
        ln_sup_id            NUMBER;
        ln_app_amount        NUMBER;
        ln_list              VARCHAR2 (1000) := ' ';
        ln_num               NUMBER;
        ln_org_id            NUMBER;
        lv_currency_code     VARCHAR2 (15);
        lv_func_curr_code    VARCHAR2 (20) := NULL;
        ld_rate_date         DATE;
        ln_conversion_rate   NUMBER := 1;
    BEGIN
        out_approver_rec_final   := out_rec (NULL);

        lv_currency_code         := NULL;               -- Added for CCR008534

          /*SELECT   to_person_id, amount, MIN (line_num),org_id
                  INTO ln_per_id, ln_amount , ln_num, ln_org_id
          FROM     (SELECT prla1.to_person_id, sub.amount, prla1.line_num,prla.org_id
                      FROM apps.po_requisition_lines_all prla1,
                           (SELECT   prla.requisition_header_id,
                                     SUM (prla.quantity * prla.unit_price) amount
                                FROM po_requisition_lines_all prla
                               WHERE prla.requisition_header_id = p_trx_id
                            GROUP BY prla.requisition_header_id) sub
                     WHERE sub.requisition_header_id = prla1.requisition_header_id)
          GROUP BY to_person_id, amount;
          */

          SELECT to_person_id, amount, MIN (line_num),
                 org_id, TRUNC (rate_date)
            INTO ln_per_id, ln_amount, ln_num, ln_org_id,
                          ld_rate_date
            FROM (SELECT prla1.to_person_id, sub.amount, prla1.line_num,
                         prla1.org_id, NVL (prla1.rate_date, prla1.creation_date) rate_date
                    FROM apps.po_requisition_lines_all prla1,
                         (  SELECT prla.requisition_header_id, --SUM (prla.quantity * prla.unit_price) amount commented as per 1.7
                                                               SUM (--                                       prla.quantity * get_unit_price (p_trx_id)) -- Added New function as per 1.7
                                                                    prla.quantity * get_unit_price (p_trx_id, prla.requisition_line_id)) -- Added New function as per 1.7
                                                                                                                                         amount
                              FROM po_requisition_lines_all prla
                             WHERE prla.requisition_header_id = p_trx_id
                          GROUP BY prla.requisition_header_id) sub
                   WHERE sub.requisition_header_id =
                         prla1.requisition_header_id)
        GROUP BY to_person_id, amount, org_id,
                 TRUNC (rate_date);

        -- Start of Change 1.7

        -- Start of Change for CCR0008534

        -- Getting everything in Functional Currency

        IF lv_currency_code IS NULL
        THEN
            lv_currency_code   :=
                po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;

        -- Get the requisition line currency
        /*BEGIN
           SELECT DISTINCT currency_code
             INTO lv_currency_code
             FROM apps.po_requisition_lines_all
            WHERE requisition_header_id = p_trx_id;
        EXCEPTION
           WHEN OTHERS
           THEN
              lv_currency_code := NULL;
        END;

        IF lv_currency_code IS NULL
        THEN
           lv_currency_code := po_ame_setup_pvt.get_function_currency (p_trx_id);
        END IF;*/

        -- End of Change


        -- fetching ledger for getting functional currency

        --      SELECT currency_code
        --        INTO lc_currency_code
        --        FROM hr_operating_units op, gl_ledgers ledgers
        --       WHERE     organization_id = ln_org_id
        --             AND op.set_of_books_id = ledgers.ledger_id;

        -- When requisition line currency and Functional currency is not USD then

        IF lv_currency_code != 'USD'
        THEN
            SELECT conversion_rate
              INTO ln_conversion_rate
              FROM gl_daily_rates
             WHERE     1 = 1
                   --                AND from_currency = 'USD'
                   --                AND to_currency = lc_currency_code
                   AND from_currency = lv_currency_code
                   AND to_currency = 'USD'      -- Convert the values into USD
                   AND conversion_date = ld_rate_date
                   AND CONVERSION_TYPE = 'Corporate';
        ELSIF lv_currency_code = 'USD'
        THEN
            ln_conversion_rate   := 1;
        END IF;


        IF ln_conversion_rate = 0
        THEN
            ln_conversion_rate   := 100;
        END IF;


        IF ln_per_id IS NOT NULL
        THEN
            LOOP
                ln_sup_id       := get_supervisor (ln_per_id);
                ln_app_amount   := 0;

                -- EMPLOYEE_LIMITS -- Start
                BEGIN
                    SELECT TO_NUMBER (flv.tag)
                      INTO ln_app_amount
                      FROM per_all_people_f papf, fnd_lookup_values flv
                     WHERE     papf.person_id = ln_sup_id
                           AND SYSDATE BETWEEN papf.effective_start_date
                                           AND papf.effective_end_date
                           AND flv.language = 'US'
                           AND flv.LOOKUP_TYPE =
                               'XXDO_REQ_APPR_LIMIT_EXCEP_LIST'
                           AND flv.lookup_code = papf.employee_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_app_amount   := 0;
                END;

                IF ln_app_amount = 0
                THEN
                    SELECT NVL (attribute1, 0)
                      INTO ln_app_amount
                      FROM per_jobs jobs, per_all_assignments_f paaf
                     WHERE     paaf.person_id = ln_sup_id
                           AND paaf.job_id = jobs.job_id
                           AND SYSDATE BETWEEN paaf.effective_start_date
                                           AND paaf.effective_end_date;
                END IF;

                -- EMPLOYEE_LIMITS -- End

                ln_per_id       := ln_sup_id;

                -- Currency conversion calculation
                --            ln_app_amount := ln_app_amount * ln_conversion_rate; (job amount is in USD, no need to multiply with rate)


                IF ln_app_amount > 0
                THEN
                    out_approver_rec_final (out_approver_rec_final.LAST).approver   :=
                        ln_sup_id;
                    out_approver_rec_final.EXTEND;
                --ln_list := ln_list || ',' || ln_sup_id;
                END IF;

                --EXIT WHEN ln_app_amount > ln_amount;
                EXIT WHEN ln_app_amount > ln_amount * ln_conversion_rate; --making sure req. amount will be in USD (As per Change 1.3)
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

    --Start Added for CR 57 by BT Technology Team on 20-Jul-15
    /*+==========================================================================+
      | Function name                                                            |
      |     get_req_eligible                                                     |
      |                                                                          |
      | DESCRIPTION                                                                 |
      |     Function to check if Non trade requistion  has line greater then 1000|
     +===========================================================================*/
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
        lc_currency_code   := NULL;                    -- Added for CCR0008534

        -- Get functional Currency
        --      lc_currency_code :=
        --         po_ame_setup_pvt.get_function_currency (p_transaction_id);

        --Get the approval limit set for Non-Trade Requistion from profile DO_REQ_BUYER_LIMIT
        SELECT TO_NUMBER (fpov.profile_option_value)
          INTO ln_non_trade_appr_limit_amt
          FROM fnd_profile_options fpo, fnd_profile_option_values fpov
         WHERE     fpo.profile_option_id = fpov.profile_option_id
               AND fpo.profile_option_name = 'DO_REQ_BUYER_LIMIT';

        -- TOTAL_REQ_AMOUNT - Start
        /*
        BEGIN
        --Get the Requisition line which has maximum amount
        SELECT  prla1.requisition_line_id,prla1.unit_price
        INTO ln_requisition_line_id,ln_unit_price
        FROM apps.po_requisition_lines_all prla1,
                 (SELECT   prla.requisition_header_id,
                           MAX (prla.quantity * prla.unit_price) amount
                      FROM po_requisition_lines_all prla
                     WHERE prla.requisition_header_id = p_transaction_id
                  GROUP BY prla.requisition_header_id) sub
        WHERE sub.requisition_header_id = prla1.requisition_header_id
       AND sub.amount= (prla1.quantity*prla1.unit_price);
        EXCEPTION  -- Exception added as part of DFCT0011414 -PRs Not Going to Buyer for Approval
            WHEN OTHERS THEN
                SELECT  prla1.requisition_line_id,prla1.unit_price
                INTO ln_requisition_line_id,ln_unit_price
                FROM apps.po_requisition_lines_all prla1,
                         (SELECT   prla.requisition_header_id,
                                   MAX (prla.quantity * prla.unit_price) amount
                              FROM po_requisition_lines_all prla
                             WHERE prla.requisition_header_id = p_transaction_id
                          GROUP BY prla.requisition_header_id) sub
                WHERE sub.requisition_header_id = prla1.requisition_header_id
                AND sub.amount= (prla1.quantity*prla1.unit_price)
                AND ROWNUM =1;

        END; -- end of  Exception added as part of DFCT0011414 -PRs Not Going to Buyer for Approval
       */

        -- Start of Change for CCR0008534

        -- Getting everything in Functional Currency

        IF lc_currency_code IS NULL
        THEN
            lc_currency_code   :=
                po_ame_setup_pvt.get_function_currency (p_transaction_id);
        END IF;


        -- Start of Change 1.7
        -- Get the requisition line currency
        /* BEGIN
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

        BEGIN
            --Get the Requisition line which has maximum amount irrespective of currency
            SELECT --SUM (prla.quantity * prla.unit_price) amount -- Commented as per 1.7
  --                   SUM (prla.quantity * get_unit_price (p_transaction_id))
                  SUM (prla.quantity * get_unit_price (p_transaction_id, prla.requisition_line_id)) --added by ANM 1.7
                                                                                                    amount -- Added as per 1.7
             INTO ln_total_price
             FROM po_requisition_lines_all prla
            WHERE     prla.requisition_header_id =
                      po_ame_setup_pvt.get_new_req_header_id (
                          p_transaction_id)
                  AND NVL (CANCEL_FLAG, 'N') = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_total_price   := 0;
        END; -- end of  Exception added as part of DFCT0011414 -PRs Not Going to Buyer for Approval

        -- TOTAL_REQ_AMOUNT - End

        --When currency of OU is non USD,do a corporate rate conversion.
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

            -- TOTAL_REQ_AMOUNT - Start
            --     ln_unit_price := ln_unit_price * lv_conv_rate;
            ln_total_price   := ln_total_price * lv_conv_rate; --- Converted req. amount to USD

            /*
            --Get if the requisition line which has maximum amount is greater than DO_REQ_NON_TRADE_APPROVAL_LIMIT
            SELECT DISTINCT 'X'
            INTO lv_return
              FROM   po_requisition_lines_all a
              WHERE requisition_header_id =po_ame_setup_pvt.get_new_req_header_id (p_transaction_id)
              AND EXISTS(select 1
                from   po_requisition_lines_all b
              WHERE a.REQUISITION_LINE_ID = b.REQUISITION_LINE_ID
              AND a.requisition_header_id =b.requisition_header_id
               AND (quantity * ln_unit_price) >= ln_non_trade_appr_limit_amt);


               IF lv_return IS NOT NULL THEN
                RETURN 1;
               ELSE
                RETURN 0;
               END IF;
            */
            --IF ln_total_price >= ln_non_trade_appr_limit_amt --already USD profile amount value
            IF ln_total_price > ln_non_trade_appr_limit_amt
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        -- TOTAL_REQ_AMOUNT - End

        ELSE
            -- TOTAL_REQ_AMOUNT - Start
            /*         --Get if the requisition line which has maximum amount is greater than DO_REQ_NON_TRADE_APPROVAL_LIMIT when currency is USD
                    SELECT DISTINCT 'X'
                    INTO lv_return
                     FROM   po_requisition_lines_all a
                     WHERE requisition_header_id =po_ame_setup_pvt.get_new_req_header_id (p_transaction_id)
                     AND EXISTS(select 1
                   FROM   po_requisition_lines_all b
                     WHERE a.REQUISITION_LINE_ID = b.REQUISITION_LINE_ID
                     AND a.requisition_header_id =b.requisition_header_id
                     AND (quantity * unit_price) >= ln_non_trade_appr_limit_amt);

                   IF lv_return IS NOT NULL THEN
                       RETURN 1;
                    ELSE
                      RETURN 0;
                    END IF;
            */
            -- TOTAL_REQ_AMOUNT - End

            IF ln_total_price > ln_non_trade_appr_limit_amt
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_req_eligible;


    FUNCTION get_post_apprvrlist (p_trx_id IN NUMBER)
        RETURN xxd_po_req_approval_pkg.out_rec_list
        PIPELINED
    IS
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

        TYPE c1_type IS TABLE OF lcu_post_approval_list%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_c1_tab                     c1_type;
        ln_org_id                     NUMBER;
        lc_currency_code              VARCHAR2 (50) := NULL;
        ln_conv_rate                  NUMBER DEFAULT 1;
        ln_non_trade_appr_limit_amt   NUMBER;
        ln_req_amount                 NUMBER;
        lv_cat_owner                  VARCHAR2 (100);
        lv_cat_type                   VARCHAR2 (100);
    BEGIN
        ln_org_id                     := NULL;
        lv_cat_type                   := NULL;
        lv_cat_owner                  := NULL;
        lc_currency_code              := NULL;
        ln_conv_rate                  := 1;
        ln_non_trade_appr_limit_amt   := NULL;
        ln_req_amount                 := NULL;
        out_approver_rec_final_list   := out_rec_list (NULL);


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

        --       Calculate the Requisition amount

        BEGIN
            SELECT --SUM (prla1.quantity * prla1.unit_price) -- Commented as per 1.7
                   --               SUM (prla1.quantity * get_unit_price (p_trx_id)) -- Added as per 1.7
                   SUM (prla1.quantity * get_unit_price (p_trx_id, prla1.requisition_line_id)) -- Added by ANM 1.7
              INTO ln_req_amount
              FROM apps.po_requisition_lines_all prla1
             WHERE prla1.requisition_header_id = p_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_req_amount   := 0;
        END;

        ln_req_amount                 := ln_req_amount * ln_conv_rate;


        -- Get the Buyer Limit from the profile Option

        BEGIN
            SELECT TO_NUMBER (fpov.profile_option_value) --Converting approval limit to respective currency for Defect 3181
              --Added by BT Technology Team v1.2 Defect 3181 on 13-OCT-2015
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
            SELECT DISTINCT mc.attribute9, prla.org_id
              INTO lv_cat_type, ln_org_id
              FROM apps.mtl_categories mc, apps.po_requisition_lines_all prla
             WHERE     1 = 1
                   AND mc.attribute_category = 'PO Mapping Data Elements'
                   AND mc.category_id = prla.category_id
                   AND prla.requisition_header_id = p_trx_id
                   AND EXISTS
                           (  SELECT 1
                                FROM po_requisition_lines_all prla1
                               WHERE prla1.requisition_header_id = p_trx_id
                            GROUP BY prla1.requisition_header_id
                              HAVING SUM (
                                           prla1.quantity
                                         --                                         * get_unit_price (p_trx_id)
                                         * get_unit_price (
                                               p_trx_id,
                                               prla1.requisition_line_id) --Added by ANM 1.7
                                         * ln_conv_rate) >
                                     ln_non_trade_appr_limit_amt);
        --                          HAVING SUM (
        --                                      prla1.quantity
        --                                    * prla1.unit_price
        --                                    * ln_conv_rate) >=
        --                                    ln_non_trade_appr_limit_amt);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_org_id     := NULL;
                lv_cat_type   := NULL;
        END;


        IF ln_org_id IS NOT NULL AND lv_cat_type IS NOT NULL
        THEN
            out_approver_rec_final_list   := out_rec_list (NULL);


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
    END get_post_apprvrlist;

    -- Commented the below function, rewrote the funtion as per change 1.7

    /*+======================================================================+
    | Function name                                                          |
    |     get_post_apprvrlist                                                |
    |                                                                        |
    | DESCRIPTION                                                            |
    |     Function to get approver name for Non Trade Requistions            |
   +========================================================================*/

    --     FUNCTION get_post_apprvrlist (p_trx_id IN NUMBER)
    --             RETURN xxd_po_req_approval_pkg.out_rec_list PIPELINED
    --       IS
    --
    --       CURSOR lcu_post_approval_list(cp_trx_id NUMBER,cp_approval_limit NUMBER,cp_conversion_rate NUMBER)
    --       IS
    --       --Added new query for CCR CCR0006810
    --       SELECT attribute1
    --     FROM (SELECT   pf.person_id attribute1
    --             FROM fnd_lookup_values flv,
    --                  per_people_f pf,
    --                  (SELECT DISTINCT pf.full_name appr_name
    --                     FROM mtl_categories mc, per_people_f pf
    --                    WHERE mc.attribute_category = 'PO Mapping Data Elements'
    --                      AND mc.category_id IN (SELECT prla.category_id
    --                                               FROM po_requisition_lines_all prla
    --                                              WHERE prla.requisition_header_id =cp_trx_id
    --                                            )
    --                      AND EXISTS (SELECT   1
    --                                    FROM po_requisition_lines_all prla1
    --                                   WHERE prla1.requisition_header_id =cp_trx_id
    --                                GROUP BY prla1.requisition_header_id
    --                              HAVING SUM (prla1.quantity * prla1.unit_price) >= cp_approval_limit)
    --                                 AND pf.person_id = mc.attribute1) pf_name
    --     WHERE flv.LANGUAGE = 'US'
    --       AND flv.lookup_type = 'XXDO_REQ_BUYER_APPR_LIST'
    --       AND enabled_flag = 'Y'
    --       AND SYSDATE BETWEEN start_date_active AND NVL (end_date_active, SYSDATE + 1)
    --       AND flv.description = pf_name.appr_name
    --        AND (flv.tag*cp_conversion_rate) <= (SELECT   SUM (prla1.quantity * prla1.unit_price)
    --                                    FROM po_requisition_lines_all prla1
    --                                   WHERE prla1.requisition_header_id = cp_trx_id
    --                                GROUP BY prla1.requisition_header_id)
    --                AND pf.full_name = flv.meaning
    --           ORDER BY TO_NUMBER (flv.tag) DESC)
    --    WHERE ROWNUM = 1;
    ----   Commented for CCR CCR0006810
    --   /*SELECT distinct attribute1
    --   FROM mtl_categories
    --   WHERE attribute_category = 'PO Mapping Data Elements'
    --   AND category_id IN (SELECT   prla.category_id
    --                        FROM po_requisition_lines_all prla
    --                           WHERE prla.requisition_header_id = cp_trx_id
    --                            TOTAL_REQ_AMOUNT - Start
    --                           AND prla.quantity * prla.unit_price >= cp_approval_limit
    --                       )
    --   AND EXISTS ( SELECT 1
    --                  FROM po_requisition_lines_all prla1
    --                 WHERE prla1.requisition_header_id = cp_trx_id
    --                 GROUP BY prla1.requisition_header_id
    --                 HAVING SUM(prla1.quantity * prla1.unit_price)>=cp_approval_limit
    --               );*/
    ----    TOTAL_REQ_AMOUNT - End
    --
    --      CURSOR lcu_post_approval_list(cp_trx_id NUMBER,cp_approval_limit NUMBER,cp_conversion_rate NUMBER)
    --       IS
    --       SELECT
    --
    --
    --      TYPE c1_type IS TABLE OF lcu_post_approval_list%ROWTYPE
    --       INDEX BY BINARY_INTEGER;
    --
    --      lt_c1_tab                c1_type;
    --      ln_non_trade_appr_limit_amt NUMBER :=0;
    --      l_category_owner            VARCHAR2(100);
    --
    --   --Start Modification by BT Technology Team v1.2 Defect 3181 on 13-OCT-2015
    --     lc_currency_code VARCHAR2(50):=NULL;
    --     ln_conv_rate     NUMBER DEFAULT 1; --Added initialization by BT Technology Team v1.3 UAT2 Defect 13 on 19-OCT-2015
    --   --End Modification by BT Technology Team v1.2 Defect 3181 for on 13-OCT-2015
    --
    --
    --      BEGIN
    --
    --      --Start Modification by BT Technology Team v1.2 Defect 3181 on 13-OCT-2015
    --      lc_currency_code := po_ame_setup_pvt.get_function_currency(p_trx_id);
    --          IF  lc_currency_code <> 'USD' THEN
    --
    --             --Get the corprate conversion rate for SYSDATE
    --             SELECT rate.conversion_rate
    --              INTO   ln_conv_rate
    --              FROM   apps.gl_daily_rates rate, apps.gl_daily_conversion_types ratetyp
    --              WHERE  ratetyp.conversion_type = rate.conversion_type
    --              AND    UPPER( ratetyp.user_conversion_type ) = 'CORPORATE'
    --              AND    rate.from_currency = 'USD'
    --              AND    rate.to_currency = lc_currency_code
    --         AND    rate.conversion_date = TRUNC(SYSDATE);
    --        END IF;
    --      --End Modification by BT Technology Team v1.2 Defect 3181 on 13-OCT-2015
    --
    --      --Get the approval limit set for Non-Trade Requistion from profile DO_REQ_NON_TRADE_APPROVAL_LIMIT
    --       SELECT TO_NUMBER(fpov.profile_option_value)
    --       --Converting approval limit to respective currency for Defect 3181
    --            * ln_conv_rate --Added by BT Technology Team v1.2 Defect 3181 on 13-OCT-2015
    --       INTO ln_non_trade_appr_limit_amt
    --       FROM fnd_profile_options fpo,
    --            fnd_profile_option_values fpov
    --       WHERE fpo.profile_option_id = fpov.profile_option_id
    --      AND   fpo.profile_option_name = 'DO_REQ_BUYER_LIMIT';
    --
    --      out_approver_rec_final_list   := out_rec_list (NULL);
    --
    --      OPEN lcu_post_approval_list(cp_trx_id => p_trx_id,cp_approval_limit => ln_non_trade_appr_limit_amt,cp_conversion_rate =>ln_conv_rate);
    --      FETCH lcu_post_approval_list BULK COLLECT INTO lt_c1_tab;
    --      CLOSE lcu_post_approval_list;
    --
    --
    --      IF lt_c1_tab.COUNT > 0 THEN
    --          FOR x IN lt_c1_tab.FIRST .. lt_c1_tab.LAST
    --           LOOP
    --
    --          out_approver_rec_final_list (out_approver_rec_final_list.LAST).approver_id  := lt_c1_tab(x).attribute1;
    --          out_approver_rec_final_list.EXTEND;
    --
    --          END LOOP;
    --
    --       END IF;
    --
    --      FOR x IN 1 .. out_approver_rec_final_list.COUNT - 1
    --         LOOP
    --              IF out_approver_rec_final_list (x).approver_id IS NULL
    --              THEN
    --                  NULL;
    --              ELSE
    --                  PIPE ROW (out_approver_rec_final_list (x));
    --              END IF;
    --         END LOOP;
    --        RETURN;
    --       EXCEPTION
    --      WHEN OTHERS THEN
    --          RETURN ;
    --      END get_post_apprvrlist;
    --   End Added for CR 57 by BT Technology Team on 20-Jul-15


    FUNCTION can_requestor_approve (p_transaction_id NUMBER)
        RETURN NUMBER
    IS
        lc_currency_code         VARCHAR2 (50) := NULL;
        lv_return                VARCHAR2 (10) := NULL;
        ln_unit_price            NUMBER;
        ln_conv_rate             NUMBER := 1;
        ln_requisition_line_id   NUMBER;
        ln_per_id                NUMBER;
        ln_total_price           NUMBER;
        ln_app_amount            NUMBER := 0;
        l_preparer_id            NUMBER;
    BEGIN
        lc_currency_code   := NULL;                    -- Added for CCR0008534

        BEGIN
            SELECT DISTINCT prla1.to_person_id, prha.preparer_id
              INTO ln_per_id, l_preparer_id
              FROM apps.po_requisition_lines_all prla1, apps.po_requisition_headers_all prha
             WHERE     prla1.requisition_header_id = p_transaction_id
                   AND prla1.requisition_header_id =
                       prha.requisition_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_per_id       := 0;
                l_preparer_id   := 0;
        END;

        -- If preparer and requestor are the same, requestor alone can't approve. one level of supervisor approval is required.
        IF ln_per_id = l_preparer_id
        THEN
            RETURN 0;
        ELSE
            BEGIN
                SELECT TO_NUMBER (flv.tag)
                  INTO ln_app_amount
                  FROM per_all_people_f papf, fnd_lookup_values flv
                 WHERE     papf.person_id = ln_per_id
                       AND SYSDATE BETWEEN papf.effective_start_date
                                       AND papf.effective_end_date
                       AND flv.language = 'US'
                       AND flv.LOOKUP_TYPE = 'XXDO_REQ_APPR_LIMIT_EXCEP_LIST'
                       AND flv.lookup_code = papf.employee_number;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_app_amount   := 0;
            END;

            IF ln_app_amount = 0
            THEN
                BEGIN
                    SELECT NVL (attribute1, 0)
                      INTO ln_app_amount
                      FROM per_jobs jobs, per_all_assignments_f paaf
                     WHERE     paaf.person_id = ln_per_id
                           AND paaf.job_id = jobs.job_id
                           AND SYSDATE BETWEEN paaf.effective_start_date
                                           AND paaf.effective_end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_app_amount   := 0;
                END;
            END IF;

            -- Start of Change for CCR0008534

            -- Get Functional Currency for OU

            -- Getting everything in Functional Currency

            IF lc_currency_code IS NULL
            THEN
                lc_currency_code   :=
                    po_ame_setup_pvt.get_function_currency (p_transaction_id);
            END IF;

            -- Get the requisition line currency
            /* BEGIN
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

            --         lc_currency_code :=
            --            po_ame_setup_pvt.get_function_currency (p_transaction_id);

            -- Get the req total amount
            BEGIN
                SELECT -- SUM (prla.quantity * prla.unit_price) amount -- Commnted as per 1.7
                       SUM (--                           prla.quantity * get_unit_price (p_transaction_id))
                            prla.quantity * get_unit_price (p_transaction_id, prla.requisition_line_id)) --Added by ANM 1.7
                                                                                                         amount -- Added as per 1.7
                  INTO ln_total_price
                  FROM po_requisition_lines_all prla
                 WHERE     prla.requisition_header_id =
                           po_ame_setup_pvt.get_new_req_header_id (
                               p_transaction_id)
                       AND NVL (CANCEL_FLAG, 'N') = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_total_price   := 0;
            END;

            ln_total_price   := ln_total_price * ln_conv_rate;

            --         IF ln_app_amount > ln_total_price
            --         THEN
            --            RETURN 1;
            --         ELSE
            --            RETURN 0;
            --         END IF;
            IF ln_app_amount >= ln_total_price
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END can_requestor_approve;

    --Funtion to get APAC finance approver list
    FUNCTION get_apac_finance_apprlist (p_trx_id IN NUMBER)
        RETURN xxd_po_req_approval_pkg.out_apac_rec_list
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
                             --AND papf.email_address is not null
                             AND TO_NUMBER (flv.tag) < cp_amount
                    ORDER BY TO_NUMBER (flv.tag) ASC);

        --WHERE ROWNUM = 1;
        TYPE c1_type IS TABLE OF apac_aprover_list_cur%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_c1_tab            c1_type;
    BEGIN
          SELECT amount, org_id, TRUNC (rate_date)
            INTO ln_amount, ln_org_id, ld_rate_date
            FROM (SELECT sub.amount, prla1.line_num, prla1.org_id,
                         NVL (prla1.rate_date, prla1.creation_date) rate_date
                    FROM apps.po_requisition_lines_all prla1,
                         (  SELECT prla.requisition_header_id, --SUM (prla.quantity * prla.unit_price) amount Commented as per Change 1.7
                                                               SUM (--                                       prla.quantity * get_unit_price (p_trx_id))
                                                                    prla.quantity * get_unit_price (p_trx_id, prla.requisition_line_id)) --added by ANM 1.7
                                                                                                                                         amount -- Added as per 1.7
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

    --Funtion to get APAC finance approver limit
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
                         (  SELECT prla.requisition_header_id, --SUM (prla.quantity * prla.unit_price) amount -- commented as per change 1.7
                                                               SUM (--                                       prla.quantity * get_unit_price (p_trx_id))
                                                                    prla.quantity * get_unit_price (p_trx_id, prla.requisition_line_id)) amount -- Added as per 1.7
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
        --   ELSIF lc_currency_code = 'USD'
        --   THEN
        --      ln_conversion_rate := 1;
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

        --IF ln_app_amount > ln_limit   -- commented
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

    -- Added New function as per change 1.7
    FUNCTION is_req_auto_approved (p_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        lc_currency_code        VARCHAR2 (50) := NULL;
        ln_req_approval_limit   NUMBER := 0;
        ln_total_price          NUMBER := 0;
        ln_conv_rate            NUMBER := 0;
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
            SELECT --SUM (prla.quantity * prla.unit_price) amount --Commented asper 1.7
   --                   SUM (prla.quantity * get_unit_price (p_trx_id)) amount
                  SUM (prla.quantity * get_unit_price (p_trx_id, prla.requisition_line_id)) amount
             INTO ln_total_price
             FROM po_requisition_lines_all prla
            WHERE     prla.requisition_header_id =
                      po_ame_setup_pvt.get_new_req_header_id (p_trx_id)
                  AND NVL (CANCEL_FLAG, 'N') = 'N';
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

            ln_total_price   := ln_total_price * ln_conv_rate;

            IF ln_req_approval_limit >= ln_total_price
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        --         IF ln_req_approval_limit > ln_total_price
        --         THEN
        --            RETURN 1;
        --         ELSE
        --            RETURN 0;
        --         END IF;
        ELSE
            --         IF ln_req_approval_limit > ln_total_price
            --         THEN
            --            RETURN 1;
            --         ELSE
            --            RETURN 0;
            --         END IF;
            IF ln_req_approval_limit >= ln_total_price
            THEN
                RETURN 1;
            ELSE
                RETURN 0;
            END IF;
        END IF;
    END is_req_auto_approved;

    FUNCTION get_unit_price (p_trx_id IN NUMBER, p_req_line_id NUMBER)
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

        lv_func_curr_code   :=
            po_ame_setup_pvt.get_function_currency (p_trx_id);

        -- Get Transactional  Currency code for the Requisition

        BEGIN
            SELECT DISTINCT currency_code
              INTO lv_currency_code
              FROM apps.po_requisition_lines_all
             WHERE     requisition_header_id = p_trx_id
                   AND requisition_line_id = p_req_line_id;     --Added by ANM
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
             WHERE     requisition_header_id = p_trx_id
                   AND requisition_line_id = p_req_line_id;     --Added by ANM
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_unit_price        := 1;
                ln_curr_unit_price   := 1;
        END;

        -- Start of Change for CCR0008534

        ln_price   := ln_unit_price;

        /*IF lv_func_curr_code = lv_currency_code
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
        END IF;*/


        /*
        IF lv_func_curr_code = lv_currency_code
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

        -- End of Change

        RETURN ln_price;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_unit_price;
-- End of Change

END XXD_PO_REQ_APPROVAL_PKG;
/
