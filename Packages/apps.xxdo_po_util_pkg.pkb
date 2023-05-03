--
-- XXDO_PO_UTIL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_UTIL_PKG"
AS
    /*******************************************************************************
   * Program Name : XXDO_PO_UTIL_PKG
   * Language     : PL/SQL
   * Description  : This package will get Ammounts mapped to given project
   *
   * History      :
   *
   * WHO            WHAT              Desc                             WHEN
   * -------------- ---------------------------------------------- ---------------
   * Swapna N          1.0 - Initial Version                         AUG/6/2014
   * Infosys           1.1 - Modified for PRB0041100                 29-DEC-2016
   * Infosys           1.2 - Modifications For CCR0006818            20-Nov-2017
   * --------------------------------------------------------------------------- */
    g_error_message   VARCHAR2 (32767);

    FUNCTION is_rel_not_in_project_budget (p_po_release_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_po_amount_for_project      NUMBER DEFAULT (0);
        ln_rel_amount_for_project     NUMBER DEFAULT (0);
        ln_project_id                 NUMBER;
        ln_actual_project_amt         NUMBER;
        ln_approved_project_amt       NUMBER;
        ln_commitment_project_amt     NUMBER;
        v_stmt_str                    VARCHAR2 (5000);
        lc_project_code               VARCHAR2 (1000);
        lc_project_name               VARCHAR2 (1000);
        lb_is_rel_in_project_budget   VARCHAR2 (1) := 'N';
        lc_project_currency           pa_projects_all.project_currency_code%TYPE;
        ln_expenditure                NUMBER;

        TYPE projectid IS REF CURSOR;

        v_proj_org_id_cursor          projectid;
        i                             NUMBER DEFAULT (0);

        CURSOR get_project_details_c (p_project_id NUMBER)
        IS
            SELECT NAME, segment1, project_currency_code
              FROM pa_projects_all
             WHERE project_id = p_project_id;
    BEGIN
        v_stmt_str        :=
            'select distinct project_id from PO_Distributions_ALL where po_release_id =  :P_PO_RELEASE_ID';
        g_error_message   := NULL;

        -- Open cursor and specify bind variable in USING clause:
        OPEN v_proj_org_id_cursor FOR v_stmt_str USING p_po_release_id;

        i                 := 0;

        -- Fetch rows from result set one at a time:
        LOOP
            i                           := i + 1;
            ln_rel_amount_for_project   := 0;
            ln_project_id               := 0;
            ln_actual_project_amt       := 0;
            ln_approved_project_amt     := 0;
            ln_commitment_project_amt   := 0;
            lc_project_code             := NULL;
            lc_project_name             := NULL;
            lc_project_currency         := NULL;
            ln_expenditure              := 0;

            FETCH v_proj_org_id_cursor INTO ln_project_id;

            IF ln_project_id IS NOT NULL AND ln_project_id <> 0
            THEN
                -- new IF condition added by Siddhartha
                OPEN get_project_details_c (ln_project_id);

                FETCH get_project_details_c INTO lc_project_code, lc_project_name, lc_project_currency;

                CLOSE get_project_details_c;

                ln_rel_amount_for_project   :=
                    get_rel_amount_for_project (ln_project_id,
                                                p_po_release_id,
                                                lc_project_currency);
                ln_approved_project_amt   :=
                    get_project_approved_amt (ln_project_id);
                -- ln_po_amount_for_project := get_po_amount_for_project(ln_project_id,p_po_header_id,lc_project_currency);
                ln_actual_project_amt   :=
                    get_project_expenditure_amt (ln_project_id);
                ln_commitment_project_amt   :=
                    get_project_commitment_amt (ln_project_id);

                IF ln_approved_project_amt < -- Modified by Infosys for PRB0041100
                   --                    ln_rel_amount_for_project+
                   ln_actual_project_amt + ln_commitment_project_amt
                THEN
                    ln_expenditure                :=
                        ln_actual_project_amt + ln_commitment_project_amt;
                    fnd_message.CLEAR;
                    fnd_message.set_name ('XXDO',
                                          'XXDO_REL_BUDGETARY_CONTROL_ERR');
                    fnd_message.set_token ('PROJECT_CODE',
                                           lc_project_code,
                                           TRUE);
                    fnd_message.set_token ('PROJECT_NAME',
                                           lc_project_name,
                                           TRUE);
                    fnd_message.set_token ('EXPENDITURE',
                                           ln_expenditure,
                                           TRUE);
                    fnd_message.set_token ('APPROVED_BUDGET',
                                           ln_approved_project_amt,
                                           TRUE);

                    IF i = 1
                    THEN
                        g_error_message   := fnd_message.get;
                    ELSE
                        g_error_message   :=
                               g_error_message
                            || CHR (13)
                            || ''
                            || CHR (10)
                            || ''
                            || CHR (13)
                            || ''
                            || CHR (10)
                            || fnd_message.get;
                    END IF;

                    lb_is_rel_in_project_budget   := 'Y';
                END IF;
            END IF;

            EXIT WHEN v_proj_org_id_cursor%NOTFOUND;
        END LOOP;

        -- Close cursor:
        CLOSE v_proj_org_id_cursor;

        RETURN lb_is_rel_in_project_budget || g_error_message;
    END is_rel_not_in_project_budget;

    FUNCTION is_po_not_in_project_budget (p_po_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_po_amount_for_project     NUMBER DEFAULT (0);
        ln_project_id                NUMBER;
        ln_actual_project_amt        NUMBER;
        ln_approved_project_amt      NUMBER;
        ln_commitment_project_amt    NUMBER;
        v_stmt_str                   VARCHAR2 (5000);
        lc_project_code              VARCHAR2 (1000);
        lc_project_name              VARCHAR2 (1000);
        lb_is_po_in_project_budget   VARCHAR2 (1) := 'N';
        lc_project_currency          pa_projects_all.project_currency_code%TYPE;
        ln_expenditure               NUMBER;

        TYPE projectid IS REF CURSOR;

        v_proj_org_id_cursor         projectid;
        i                            NUMBER DEFAULT (0);
        ln_cmt_cost_for_po           NUMBER;

        CURSOR get_project_details_c (p_project_id NUMBER)
        IS
            SELECT NAME, segment1, project_currency_code
              FROM pa_projects_all
             WHERE project_id = p_project_id;
    BEGIN
        v_stmt_str        :=
            'select distinct project_id from PO_Distributions_ALL where po_header_id =  :P_PO_HEADER_ID';
        g_error_message   := NULL;

        -- Open cursor and specify bind variable in USING clause:
        OPEN v_proj_org_id_cursor FOR v_stmt_str USING p_po_header_id;

        i                 := 0;

        -- Fetch rows from result set one at a time:
        LOOP
            i                           := i + 1;
            ln_po_amount_for_project    := 0;
            ln_project_id               := 0;
            ln_actual_project_amt       := 0;
            ln_approved_project_amt     := 0;
            ln_commitment_project_amt   := 0;
            lc_project_code             := NULL;
            lc_project_name             := NULL;
            lc_project_currency         := NULL;
            ln_expenditure              := 0;
            ln_cmt_cost_for_po          := 0;

            FETCH v_proj_org_id_cursor INTO ln_project_id;

            IF ln_project_id IS NOT NULL AND ln_project_id <> 0
            THEN
                OPEN get_project_details_c (ln_project_id);

                FETCH get_project_details_c INTO lc_project_code, lc_project_name, lc_project_currency;

                CLOSE get_project_details_c;

                ln_approved_project_amt   :=
                    get_project_approved_amt (ln_project_id);
                ln_po_amount_for_project   :=
                    get_po_amount_for_project (ln_project_id,
                                               p_po_header_id,
                                               lc_project_currency);
                ln_actual_project_amt   :=
                    get_project_expenditure_amt (ln_project_id);
                ln_commitment_project_amt   :=
                    get_project_commitment_amt (ln_project_id);

                ---calculating the existing commitment cost for current PO----
                SELECT NVL (SUM (NVL (tot_cmt_burdened_cost, 0)), 0)
                  INTO ln_cmt_cost_for_po
                  FROM pa_commitment_txns
                 WHERE     transaction_source = 'ORACLE_PURCHASING'
                       AND line_type = 'P'
                       AND cmt_header_id = p_po_header_id
                       AND project_id = ln_project_id;

                --differential commitment for the present requisition (ln_req_amount_for_project-ln_cmt_cost_for_req)
                IF ln_approved_project_amt < -- Modified by Infosys for PRB0041100
                     (ln_po_amount_for_project - ln_cmt_cost_for_po)
                   + ln_actual_project_amt
                   + ln_commitment_project_amt
                THEN
                    ln_expenditure               :=
                        ln_actual_project_amt + ln_commitment_project_amt;
                    fnd_message.CLEAR;
                    fnd_message.set_name ('XXDO',
                                          'XXDO_PO_BUDGETARY_CONTROL_ERR');
                    fnd_message.set_token ('PROJECT_CODE',
                                           lc_project_code,
                                           TRUE);
                    fnd_message.set_token ('PROJECT_NAME',
                                           lc_project_name,
                                           TRUE);
                    fnd_message.set_token ('EXPENDITURE',
                                           ln_expenditure,
                                           TRUE);
                    fnd_message.set_token ('APPROVED_BUDGET',
                                           ln_approved_project_amt,
                                           TRUE);

                    IF i = 1
                    THEN
                        g_error_message   := fnd_message.get;
                    ELSE
                        g_error_message   :=
                               g_error_message
                            || CHR (13)
                            || ''
                            || CHR (10)
                            || ''
                            || CHR (13)
                            || ''
                            || CHR (10)
                            || fnd_message.get;
                    END IF;

                    lb_is_po_in_project_budget   := 'Y';
                END IF;
            END IF;

            EXIT WHEN v_proj_org_id_cursor%NOTFOUND;
        END LOOP;

        -- Close cursor:
        CLOSE v_proj_org_id_cursor;

        RETURN lb_is_po_in_project_budget || g_error_message;
    END is_po_not_in_project_budget;

    FUNCTION get_project_approved_amt (p_project_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_project_approved_amt   NUMBER DEFAULT (0);
        lc_budget_type_code       VARCHAR2 (1000);
    BEGIN
        SELECT budget_type_code
          INTO lc_budget_type_code
          FROM pa_budget_types
         WHERE budget_type = 'Cost Budget';

        SELECT burdened_cost
          INTO ln_project_approved_amt
          FROM pa_budget_versions
         WHERE     project_id = p_project_id
               AND current_flag = 'Y'
               AND budget_type_code = lc_budget_type_code;

        RETURN NVL (ln_project_approved_amt, 0);
    END get_project_approved_amt;

    FUNCTION get_po_amount_for_project (p_project_id IN NUMBER, p_po_header_id IN NUMBER, p_proj_currency IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_po_amount_for_project   NUMBER DEFAULT (0);
        ln_amount                  NUMBER DEFAULT (0);
        ln_po_line_id              NUMBER;
        lc_po_currency_code        po_headers_all.currency_code%TYPE;
        lc_rate_type               po_headers_all.rate_type%TYPE;
        ln_rate                    NUMBER;
        ld_po_rate_date            DATE;

        TYPE lineid IS REF CURSOR;

        v_line_id_cursor           lineid;
        v_stmt_str                 VARCHAR2 (5000);

        CURSOR po_details_c (p_po_header_id NUMBER)
        IS
            SELECT currency_code, rate_type, rate_date
              FROM po_headers_all
             WHERE po_header_id = p_po_header_id;
    BEGIN
        SELECT SUM (pda.quantity_ordered * pll.price_override) + SUM (NVL (pda.nonrecoverable_tax, 0))
          INTO ln_po_amount_for_project
          FROM po_distributions_all pda, po_line_locations pll
         WHERE     pda.po_header_id = pll.po_header_id
               AND pda.line_location_id = pll.line_location_id
               AND pda.po_header_id = p_po_header_id
               AND project_id = p_project_id;

        OPEN po_details_c (p_po_header_id);

        FETCH po_details_c INTO lc_po_currency_code, lc_rate_type, ld_po_rate_date;

        CLOSE po_details_c;

        IF lc_po_currency_code <> p_proj_currency
        THEN
            IF lc_rate_type IS NOT NULL
            THEN
                ln_rate   :=
                    gl_currency_api.get_rate (
                        x_from_currency     => lc_po_currency_code,
                        x_to_currency       => p_proj_currency,
                        x_conversion_date   => ld_po_rate_date,
                        x_conversion_type   => lc_rate_type);

                IF NVL (ln_rate, 0) != 0
                THEN
                    ln_po_amount_for_project   :=
                        ln_po_amount_for_project * ln_rate;
                END IF;
            END IF;
        END IF;

        RETURN NVL (ln_po_amount_for_project, 0);
    EXCEPTION
        WHEN gl_currency_api.no_rate
        THEN
            RAISE;
    END get_po_amount_for_project;

    FUNCTION get_project_expenditure_amt (p_project_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_project_expenditure_amt   NUMBER DEFAULT (0);
    BEGIN
        /*SELECT SUM (ACCT_BURDENED_COST)
          INTO ln_project_expenditure_amt
          FROM pa_commitment_TXNS_V
         WHERE project_id = p_project_id;*/
        SELECT SUM (acct_burdened_cost)
          INTO ln_project_expenditure_amt
          FROM pa_expenditure_items_all
         WHERE project_id = p_project_id;

        RETURN NVL (ln_project_expenditure_amt, 0);
    END get_project_expenditure_amt;

    FUNCTION get_project_commitment_amt (p_project_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_project_commitment_amt   NUMBER DEFAULT (0);
    BEGIN
        /*Start of change as part of Ver 1.2 on 20-Nov-2017*/
        /*
              SELECT SUM (tot_cmt_burdened_cost)
                INTO ln_project_commitment_amt
                FROM pa_commitment_txns
               WHERE project_id = p_project_id;
        */
        SELECT NVL (SUM (NVL (denom_burdened_cost, 0) * NVL (acct_exchange_rate, 1)), 0)
          INTO ln_project_commitment_amt
          FROM pa_commitment_txns
         WHERE project_id = p_project_id;

        /*End  of change as part of Ver 1.2 on 20-Nov-2017*/
        RETURN NVL (ln_project_commitment_amt, 0);
    END get_project_commitment_amt;

    FUNCTION get_rel_amount_for_project (p_project_id IN NUMBER, p_po_release_id IN NUMBER, p_proj_currency IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_po_amount_for_project   NUMBER DEFAULT (0);
        ln_amount                  NUMBER DEFAULT (0);
        ln_po_line_id              NUMBER;
        lc_po_currency_code        po_headers_all.currency_code%TYPE;
        lc_rate_type               po_headers_all.rate_type%TYPE;
        ln_rate                    NUMBER;
        ld_po_rate_date            DATE;
        ln_po_header_id            NUMBER;

        TYPE lineid IS REF CURSOR;

        v_line_id_cursor           lineid;
        v_stmt_str                 VARCHAR2 (5000);

        CURSOR po_details_c (p_po_header_id NUMBER)
        IS
            SELECT currency_code, rate_type, rate_date
              FROM po_headers_all
             WHERE po_header_id = p_po_header_id;
    BEGIN
        SELECT SUM (pda.quantity_ordered * pll.price_override) + SUM (NVL (pda.nonrecoverable_tax, 0))
          INTO ln_po_amount_for_project
          FROM po_distributions_all pda, po_line_locations pll
         WHERE     pda.po_header_id = pll.po_header_id
               AND pda.line_location_id = pll.line_location_id
               AND pda.po_release_id = p_po_release_id
               AND project_id = p_project_id;

        SELECT po_header_id
          INTO ln_po_header_id
          FROM po_distributions_all
         WHERE po_release_id = p_po_release_id;

        OPEN po_details_c (ln_po_header_id);

        FETCH po_details_c INTO lc_po_currency_code, lc_rate_type, ld_po_rate_date;

        CLOSE po_details_c;

        IF lc_po_currency_code <> p_proj_currency
        THEN
            IF lc_rate_type IS NOT NULL
            THEN
                ln_rate   :=
                    gl_currency_api.get_rate (
                        x_from_currency     => lc_po_currency_code,
                        x_to_currency       => p_proj_currency,
                        x_conversion_date   => ld_po_rate_date,
                        x_conversion_type   => lc_rate_type);

                IF NVL (ln_rate, 0) != 0
                THEN
                    ln_po_amount_for_project   :=
                        ln_po_amount_for_project * ln_rate;
                END IF;
            END IF;
        END IF;

        RETURN NVL (ln_po_amount_for_project, 0);
    EXCEPTION
        WHEN gl_currency_api.no_rate
        THEN
            RAISE;
    END get_rel_amount_for_project;

    FUNCTION is_req_not_in_project_budget (p_req_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_req_amount_for_project     NUMBER DEFAULT (0);
        ln_project_id                 NUMBER;
        ln_actual_project_amt         NUMBER;
        ln_approved_project_amt       NUMBER;
        ln_commitment_project_amt     NUMBER;
        ln_cmt_cost_for_req           NUMBER;
        v_stmt_str                    VARCHAR2 (5000);
        lc_project_code               VARCHAR2 (1000);
        lc_project_name               VARCHAR2 (1000);
        lb_is_req_in_project_budget   VARCHAR2 (1) := 'N';
        lc_project_currency           pa_projects_all.project_currency_code%TYPE;
        ln_expenditure                NUMBER;

        TYPE projectid IS REF CURSOR;

        v_proj_org_id_cursor          projectid;
        i                             NUMBER DEFAULT (0);

        CURSOR get_project_details_c (p_project_id NUMBER)
        IS
            SELECT NAME, segment1, project_currency_code
              FROM pa_projects_all
             WHERE project_id = p_project_id;
    BEGIN
        v_stmt_str        := 'SELECT DISTINCT project_id
  FROM po_req_distributions_all prda,
       po_requisition_lines_all PRLA,
       po_requisition_headers_all PRHA
 WHERE     prda.requisition_line_id = prla.requisition_line_id
       AND prla.requisition_header_id = prha.requisition_header_id
       AND prha.requisition_header_id = :p_REQ_HEADER_ID';
        g_error_message   := NULL;

        -- Open cursor and specify bind variable in USING clause:
        OPEN v_proj_org_id_cursor FOR v_stmt_str USING p_req_header_id;

        i                 := 0;

        -- Fetch rows from result set one at a time:
        LOOP
            i                           := i + 1;
            ln_req_amount_for_project   := 0;
            ln_project_id               := 0;
            ln_actual_project_amt       := 0;
            ln_approved_project_amt     := 0;
            ln_commitment_project_amt   := 0;
            lc_project_code             := NULL;
            lc_project_name             := NULL;
            lc_project_currency         := NULL;
            ln_expenditure              := 0;

            FETCH v_proj_org_id_cursor INTO ln_project_id;

            IF ln_project_id IS NOT NULL AND ln_project_id <> 0
            THEN
                OPEN get_project_details_c (ln_project_id);

                FETCH get_project_details_c INTO lc_project_code, lc_project_name, lc_project_currency;

                CLOSE get_project_details_c;

                ln_approved_project_amt   :=
                    get_project_approved_amt (ln_project_id);
                ln_req_amount_for_project   :=
                    get_req_amount_for_project (ln_project_id,
                                                p_req_header_id,
                                                lc_project_currency);
                ln_actual_project_amt   :=
                    get_project_expenditure_amt (ln_project_id);
                ln_commitment_project_amt   :=
                    get_project_commitment_amt (ln_project_id);

                ---calculating the existing commitment cost for current requisiton----
                /*Start of change as part of Ver 1.2 on 20-Nov-2017*/
                /*
                        SELECT NVL (SUM (NVL (tot_cmt_burdened_cost, 0)), 0)
                          INTO ln_cmt_cost_for_req
                          FROM pa_commitment_txns
                         WHERE transaction_source = 'ORACLE_PURCHASING'
                           AND line_type = 'R'
                           AND cmt_header_id = p_req_header_id
                           AND project_id = ln_project_id;
                 */
                SELECT NVL (SUM (NVL (denom_burdened_cost, 0) * NVL (acct_exchange_rate, 1)), 0)
                  INTO ln_cmt_cost_for_req
                  FROM pa_commitment_txns
                 WHERE     transaction_source = 'ORACLE_PURCHASING'
                       AND line_type = 'R'
                       AND cmt_header_id = p_req_header_id
                       AND project_id = ln_project_id;

                /*End of change as part of Ver 1.2 on 20-Nov-2017*/

                --differential commitment for the present requisition (ln_req_amount_for_project-ln_cmt_cost_for_req)
                IF ln_approved_project_amt < -- Modified by Infosys for PRB0041100
                     (ln_req_amount_for_project - ln_cmt_cost_for_req)
                   + ln_actual_project_amt
                   + ln_commitment_project_amt
                THEN
                    /*ln_expenditure :=
                                 ln_actual_project_amt + ln_commitment_project_amt;*/
                    ln_expenditure                :=
                          (ln_req_amount_for_project - ln_cmt_cost_for_req)
                        + ln_actual_project_amt
                        + ln_commitment_project_amt;
                    fnd_message.CLEAR;
                    fnd_message.set_name ('XXDO',
                                          'XXDO_REQ_BUDGETARY_CONTROL_ERR');
                    fnd_message.set_token ('PROJECT_CODE',
                                           lc_project_code,
                                           TRUE);
                    fnd_message.set_token ('PROJECT_NAME',
                                           lc_project_name,
                                           TRUE);
                    fnd_message.set_token ('EXPENDITURE',
                                           ln_expenditure,
                                           TRUE);
                    fnd_message.set_token ('APPROVED_BUDGET',
                                           ln_approved_project_amt,
                                           TRUE);

                    IF i = 1
                    THEN
                        g_error_message   := fnd_message.get;
                    ELSE
                        g_error_message   :=
                               g_error_message
                            || CHR (13)
                            || ''
                            || CHR (10)
                            || ''
                            || CHR (13)
                            || ''
                            || CHR (10)
                            || fnd_message.get;
                    END IF;

                    lb_is_req_in_project_budget   := 'Y';
                END IF;
            END IF;

            EXIT WHEN v_proj_org_id_cursor%NOTFOUND;
        END LOOP;

        -- Close cursor:
        CLOSE v_proj_org_id_cursor;

        RETURN lb_is_req_in_project_budget || g_error_message;
    END is_req_not_in_project_budget;

    FUNCTION get_req_amount_for_project (p_project_id IN NUMBER, p_req_header_id IN NUMBER, p_proj_currency IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_req_amount_for_project   NUMBER DEFAULT (0);
        ln_amount                   NUMBER DEFAULT (0);
        ln_po_line_id               NUMBER;
        lc_req_currency_code        po_headers_all.currency_code%TYPE;
        lc_rate_type                po_headers_all.rate_type%TYPE;
        ln_rate                     NUMBER;
        ld_req_rate_date            DATE;

        TYPE lineid IS REF CURSOR;

        v_line_id_cursor            lineid;
        v_stmt_str                  VARCHAR2 (5000);
    /*Start of change as part of Ver 1.2 on 20-Nov-2017*/
    /*
          CURSOR req_details_c (p_req_header_id NUMBER)
          IS
             SELECT sob.currency_code, prh.creation_date,
                    sob.daily_translation_rate_type
               FROM gl_sets_of_books sob,
                    financials_system_params_all fsp,
                    po_requisition_headers_all prh
              WHERE sob.set_of_books_id = fsp.set_of_books_id
                AND fsp.org_id = prh.org_id
                AND prh.requisition_header_id = p_req_header_id;
    */
    /*End of change as part of Ver 1.2 on 20-Nov-2017*/
    BEGIN
        /*Start of change as part of Ver 1.2 on 20-Nov-2017*/
        SELECT SUM ((prda.req_line_quantity * prla.unit_price) * NVL (prla.rate, 1)) + SUM (NVL (prda.nonrecoverable_tax, 0))
          INTO ln_req_amount_for_project
          FROM po_req_distributions_all prda, po_requisition_lines_all prla
         WHERE     prda.requisition_line_id = prla.requisition_line_id
               AND prla.requisition_header_id = p_req_header_id
               AND prda.project_id = p_project_id;

        /*
        SELECT   SUM (prda.req_line_quantity * prla.unit_price)

                     + SUM (NVL (prda.nonrecoverable_tax, 0))
                INTO ln_req_amount_for_project
                FROM po_req_distributions_all prda, po_requisition_lines_all prla
               WHERE prda.requisition_line_id = prla.requisition_line_id
                 AND prla.requisition_header_id = p_req_header_id
                 AND prda.project_id = p_project_id;

              OPEN req_details_c (p_req_header_id);

              FETCH req_details_c
               INTO lc_req_currency_code, lc_rate_type, ld_req_rate_date;

              CLOSE req_details_c;

              IF lc_req_currency_code <> p_proj_currency
              THEN
                 IF lc_rate_type IS NOT NULL
                 THEN
                    ln_rate :=
                       gl_currency_api.get_rate
                                            (x_from_currency        => lc_req_currency_code,
                                             x_to_currency          => p_proj_currency,
                                             x_conversion_date      => ld_req_rate_date,
                                             x_conversion_type      => lc_rate_type
                                            );

                    IF NVL (ln_rate, 0) != 0
                    THEN
                       ln_req_amount_for_project :=
                                                  ln_req_amount_for_project * ln_rate;
                    END IF;
                 END IF;
              END IF;
              */
        /*End  of change as part of Ver 1.2 on 20-Nov-2017*/
        RETURN NVL (ln_req_amount_for_project, 0);
    EXCEPTION
        WHEN gl_currency_api.no_rate
        THEN
            RAISE;
    END get_req_amount_for_project;
END xxdo_po_util_pkg;
/
