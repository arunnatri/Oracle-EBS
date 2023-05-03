--
-- XXD_AP_INV_APPROVAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_AP_INV_APPROVAL_PKG
AS
    /******************************************************************************
       NAME: XXD_REQ_APPROVAL_PKG

       Ver        Date        Author                       Description
       ---------  ----------  ---------------           ------------------------------------
       1.0        14/10/2014  BT Technology Team        Function to return approval list ( AME )
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
        RETURN XXD_AP_INV_APPROVAL_PKG.out_rec
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
        ln_conversion_rate   NUMBER := 0;
    BEGIN
        out_approver_rec_final   := out_rec (NULL);

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
        SELECT NVL (line_req.req_id, aia.requester_id) requester, NVL (aia.base_amount, aia.invoice_amount) amount, aia.org_id,
               TRUNC (NVL (aia.exchange_date, aia.creation_date)) rate_date
          INTO ln_per_id, ln_amount, ln_org_id, ld_rate_date
          FROM ap_invoices_all aia,
               (  SELECT MIN (line_number), req_id, invoice_id
                    FROM (SELECT aila1.requester_id req_id, line_number, invoice_id
                            FROM ap_invoice_lines_all aila1
                           WHERE     aila1.po_header_id IS NULL
                                 AND aila1.line_type_lookup_code = 'ITEM' ---Accrual
                                 AND aila1.invoice_id = p_trx_id)
                GROUP BY req_id, invoice_id) line_req
         WHERE aia.invoice_id = line_req.invoice_id;

        -- fetching ledger for getting functional currency

        SELECT currency_code
          INTO lc_currency_code
          FROM hr_operating_units op, gl_ledgers ledgers
         WHERE     organization_id = ln_org_id
               AND op.set_of_books_id = ledgers.ledger_id;

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
             WHERE     from_currency = 'USD'
                   AND to_currency = lc_currency_code
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

                -- Currency conversion calculation
                ln_app_amount   := ln_app_amount * ln_conversion_rate;


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
END XXD_AP_INV_APPROVAL_PKG;
/
