--
-- XXDO_CUSTACNOTIFY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_CUSTACNOTIFY_PKG"
/*----------------------------------------------------------------------------------
|  $Header: XXADWEA_AR_EMAIL_PKG.pkb 12-Apr-2015 Pani Kumar v1.0 ship $                                                                      |
|
|  Description: This is utility to use bursting functionality to send email
|
|  Ebs Version: 12.2.4
|
|
|  Modification History:
|
|
|   Author       Date         Version       Comments
|------------   -----------   ------------ -----------------------------------------
|BT team  12-Apr-2015   1.0           Initial Creation
|
------------------------------------------------------------------------------------*/
AS
    /*function for submitting bursting program */
    FUNCTION submit_burst_request (p_code         IN VARCHAR2,
                                   p_request_id   IN NUMBER)
        RETURN NUMBER
    IS
        l_req_id   NUMBER := 0;
        l_result   BOOLEAN;
        l_count    NUMBER;
    BEGIN
        SELECT COUNT (xl.lob_code)
          INTO l_count
          FROM fnd_concurrent_programs fcp, xdo_templates_b xt, xdo_lobs xl
         WHERE     fcp.concurrent_program_name = p_code
               AND xt.template_code = fcp.concurrent_program_name
               AND xl.lob_code = xt.template_code
               AND xl.xdo_file_type = 'XML-BURSTING-FILE';

        IF l_count > 0
        THEN
            l_result   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XDO',
                    template_code        => 'BURST_STATUS_REPORT',
                    template_language    => 'en',
                    template_territory   => '00',
                    output_format        => 'PDF');
            l_req_id   :=
                fnd_request.submit_request ('XDO', 'XDOBURSTREP', NULL,
                                            NULL, FALSE, 'N',
                                            p_request_id, 'Y');
        END IF;

        RETURN l_req_id;
    END submit_burst_request;

    /*Before Report*/
    FUNCTION beforereport
        RETURN BOOLEAN
    IS
        l_emails   VARCHAR2 (500);
        l_count    NUMBER;
    BEGIN
        p_conc_request_id   := fnd_global.conc_request_id;
        RETURN (TRUE);
    END beforereport;

    /*After Report*/
    FUNCTION afterreport
        RETURN BOOLEAN
    IS
        l_result   NUMBER;
    BEGIN
        RETURN (TRUE);
    END afterreport;
  /* PROCEDURE build_where
   IS
      CURSOR cust_notify
      IS
         SELECT c.cust_account_id customer_id,
                c.account_number customer_number,
                c.account_name customer_name, c.attribute1 brand,
                cust_prof.collector_id, prof_amts.overall_credit_limit,
                prof_amts.currency_code, prof_clas.credit_analyst_id,
                c.creation_date                            --,drc.salesrep_id
           FROM hz_cust_accounts c,
                hz_parties party,
                --hz_party_sites party_site,
                hz_cust_acct_sites_all cust_sites,
                --hz_cust_site_uses_all site_uses,
                hz_customer_profiles cust_prof,
                hz_cust_profile_amts prof_amts,
                hz_cust_profile_classes prof_clas,
                fnd_lookup_values ccpc,
          fnd_lookup_values ccc
          --do_custom.do_rep_cust_assignment drc
         WHERE  c.party_id = party.party_id
            --AND drc.customer_id = hca.cust_account_id
            --AND party.party_id = party_site.party_id
            AND cust_sites.cust_account_id = c.cust_account_id
            -- AND site_uses.cust_acct_site_id = cust_sites.cust_acct_site_id
            AND cust_prof.cust_account_id = c.cust_account_id
            AND prof_clas.profile_class_id = cust_prof.profile_class_id
           -- AND prof_clas.collector_id = cust_prof.collector_id
            AND cust_prof.cust_account_profile_id =
                                             prof_amts.cust_account_profile_id
            AND prof_clas.status = 'A'
            AND cust_prof.status = 'A'
            AND EXISTS (
                   SELECT NULL
                     FROM hz_cust_acct_sites_all hcas,
                          hz_cust_site_uses_all hcsu
                    WHERE hcas.cust_account_id = c.cust_account_id
                      AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                      AND hcsu.status = 'A'
                      AND hcsu.site_use_code = 'BILL_TO')
            AND prof_clas.NAME LIKE '%' || ccpc.lookup_code(+)
            AND ccpc.LANGUAGE = USERENV ('LANG')
            AND ccpc.lookup_type = 'XXD_CREDIT_CUST_PROFILE_CLASS'
            AND ccc.lookup_code(+) = c.sales_channel_code
            AND ccc.LANGUAGE = USERENV ('LANG')
            AND ccc.lookup_type(+) = 'XXD_CREDIT_CUSTOMER_CLASS'
            --AND c.creation_date > trunc(sysdate)-10
            AND NOT EXISTS (SELECT NULL
                              FROM xxdo_cust_acct_credit_notify
                             WHERE customer_id = c.cust_account_id)
            AND TRUNC (c.creation_date) >=
                   TO_DATE (fnd_profile.VALUE ('XXD_LAST_RUN_CREDIT_NTFY'),
                            'DD/MM/YYYY'
                        );
   BEGIN
--Delete from do_custom.xxdo_cust_acct_credit_notify;
--commit;
      FOR i IN cust_notify
      LOOP
         INSERT INTO do_custom.xxdo_cust_acct_credit_notify
                     (customer_id, customer_number, customer_name,
                      brand, collector_id, overall_credit_limit,
                      currency_code, credit_analyst_id, printed_flag,
                      print_count, request_id, cust_creation_date,
                      created_by, creation_date, last_updated_by,
                      last_update_date                          --,salesrep_id
                     )
              VALUES (i.customer_id, i.customer_number, i.customer_name,
                      i.brand, i.collector_id, i.overall_credit_limit,
                      i.currency_code, i.credit_analyst_id, 'N',
                      1, fnd_global.conc_request_id, i.creation_date,
                      fnd_global.user_id, SYSDATE, fnd_global.user_id,
                      SYSDATE                               --,'i.salesrep_id'
                     );
      END LOOP;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END build_where;*/
END xxdo_custacnotify_pkg;
/
