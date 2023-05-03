--
-- XXD_AR_OPNINV_C_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_OPNINV_C_PK"
AS
    /*******************************************************************************************
       File Name : APPS.XXD_AR_OPNINV_C_PK

       Created On   : 02-Mar-2015

       Created By   : BT Technology Team

       Purpose      : This is the conversion program to load open invoices data into Oracle AR
    ********************************************************************************************
         Modification History:
        Version   SCN#     By                       Date             Comments

          1.0             BT Technology Team       02-Mar-2015       Initial version
    *******************************************************************************************/

    -- Global Variable Declaration
    gn_req_id                     NUMBER := fnd_global.conc_request_id;
    gc_new                        VARCHAR2 (10) := 'N';
    gc_code_pointer               VARCHAR2 (500);
    gc_module_name                VARCHAR2 (40) := 'XXD_AR_OPNINV_C_PK';
    gc_no                         VARCHAR2 (1) := 'N';
    gn_login_id                   NUMBER := fnd_global.login_id;
    gc_yes                        VARCHAR2 (1) := 'Y';
    gc_error                      VARCHAR2 (1) := 'E';
    gc_process                    VARCHAR2 (1) := 'P';
    gc_validate                   VARCHAR2 (1) := 'V';
    gc_custom_appl_name           fnd_application.application_short_name%TYPE
                                      := 'XXD';
    gc_succ                       VARCHAR2 (1) := 'S';
    gc_line_dff_context           VARCHAR2 (100) := 'LEGACY1';
    --need to get clarity on this
    gc_batch_src_name             VARCHAR2 (100) := 'LEGACY1';
    gc_company_vs                 VARCHAR2 (150) := 'Operations Company';
    gc_dept_vs                    VARCHAR2 (150) := 'Operations Department';
    gc_acct_vs                    VARCHAR2 (150) := 'Operations Account';
    gc_sub_acct_vs                VARCHAR2 (150) := 'Operations Sub-Account';
    gc_product_vs                 VARCHAR2 (150) := 'Operations Product';
    --common variables used in all the procedures
    ln_batch_id                   NUMBER;
    lc_status                     VARCHAR2 (1);
    ln_request_id                 NUMBER;
    ln_request_id1                NUMBER;
    ln_request_id2                NUMBER;
    ln_line_num                   NUMBER := 0;
    lc_valid_ex_flag              VARCHAR2 (1) := gc_no;
    lc_api_ex_flag                VARCHAR2 (1) := gc_no;
    lc_err_msg                    VARCHAR2 (4000);
    lc_data                       VARCHAR2 (1000);
    ln_cust_trx_id                NUMBER;
    ln_msg_index_out              NUMBER;
    lc_procedure                  VARCHAR2 (30) := 'OPNINV_PRC';
    lc_inv_type                   ra_cust_trx_types_all.TYPE%TYPE;
    lc_cust_num                   hz_cust_accounts_all.account_number%TYPE;
    ln_cust_id                    NUMBER;
    ln_coa_id                     NUMBER := NULL;
    ln_cust_trx_typ_id            NUMBER;
    ln_tot_rec_cnt                NUMBER := 0;
    ln_err_rec_cnt                NUMBER := 0;
    ln_vld_cnt                    NUMBER := 0;
    lc_dff                        VARCHAR2 (1) := NULL;
    ln_ledger_id                  NUMBER;
    ln_org_id                     NUMBER;
    ln_bus_grpid                  NUMBER;
    lx_ret_code                   VARCHAR2 (1);
    lx_errmsg                     VARCHAR2 (1000);
    ln_bill_add_id                NUMBER;
    ln_bill_cust_id               NUMBER;
    ld_gl_date                    DATE;
    lc_reference                  ra_interface_lines_all.interface_line_attribute1%TYPE;
    lc_func_curr                  gl_ledgers.currency_code%TYPE;
    ln_exch_rate                  NUMBER;
    ln_dup_inv_cnt                NUMBER := 0;
    lc_exch_rate_typ              VARCHAR2 (4);
    lc_concatenated_segment       VARCHAR2 (100);
    lc_natural_acct               VARCHAR2 (10) := NULL;
    lc_acct_class                 VARCHAR2 (3);
    ln_pay_term_id                NUMBER;
    ln_code_combination_id        NUMBER;
    ln_dummy                      NUMBER := NULL;
    ln_amount                     NUMBER := 0;
    lc_credit_memo                VARCHAR2 (50) := 'CM';
    ex_program_abort              EXCEPTION;
    ex_val                        EXCEPTION;
    ex_insert                     EXCEPTION;
    ex_dup_invoice_delete         EXCEPTION;

    TYPE xxd_ar_trx_headers_stg_tab
        IS TABLE OF xxd_conv.xxd_ar_trx_headers_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_opninv_stg_rec         xxd_ar_trx_headers_stg_tab;

    TYPE xxd_ar_opninv_lines_stg_tab
        IS TABLE OF xxd_conv.xxd_ar_trx_lines_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_opninv_lines_stg_rec   xxd_ar_opninv_lines_stg_tab;

    /******************************************************
        * Procedure: log_recordss
        *
        * Synopsis: This procedure will call we be called by the concurrent program
         * Design:
         *
         * Notes:
         *
         * PARAMETERS:
         *   IN    : p_debug    Varchar2
         *   IN    : p_message  Varchar2
         *
         * Return Values:
         * Modifications:
         *
         ******************************************************/
    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    FUNCTION get_org_id (p_org_name IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
        x_org_id         NUMBER;
    BEGIN
        px_meaning   := p_org_name;
        apps.xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING',
            -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,
            -- internal name of old entity
            px_description   => px_description,
            -- name of the old entity
            x_attribute1     => x_attribute1,
            -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (name) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AR',
                -1,
                'Organization Mapping Not Found',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_org_id;

    FUNCTION get_targetorg_id (p_org_name IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : get_targetorg_id                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_org_id   NUMBER;
    BEGIN
        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (name) = UPPER (p_org_name);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AR',
                -1,
                'Transaction Number Already Exist in the system',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_targetorg_id;

    /*+==========================================================================+
    | Function name                                                              |
    |     calc_eligible_records                                              |
    |                                                                            |
    | DESCRIPTION                                                                |
    |Function calc_eligible_records identifies the number of records eligible for|
    |the conversion process.                            |
    +===========================================================================*/
    FUNCTION calc_eligible_records (p_org_id IN VARCHAR2)
        RETURN NUMBER
    IS
        --Function calc_eligible_records identifies the number of records eligible for
        --the conversion process.
        l_eligible_rec_cnt   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_eligible_rec_cnt
          FROM xxd_ar_trx_headers_stg_t x
         WHERE     x.source_org_id = NVL (p_org_id, x.source_org_id)
               AND NVL (x.record_status, 'N') IN ('N', 'E');

        fnd_file.put_line (
            fnd_file.LOG,
            'Function calc_eligible_records:' || l_eligible_rec_cnt);
        RETURN l_eligible_rec_cnt;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'OTHERS Exception in the Function Calc_Eligible_Records:  '
                || SUBSTR (SQLERRM, 1, 499));
    END;

    /*+==========================================================================+
 | Procedure name                                                             |
 |     min_max_batch_prc                                                  |
 |                                                                            |
 | DESCRIPTION                                                                |
 |Procedure min_max_batch_prc retrieives the Minimum and Maximum Batch Number.|
 +===========================================================================*/
    PROCEDURE min_max_batch_prc (x_low_batch_limit    OUT NUMBER,
                                 x_high_batch_limit   OUT NUMBER)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Procedure min_max_batch_prc');

        SELECT MIN (batch_number), MAX (batch_number)
          INTO x_low_batch_limit, x_high_batch_limit
          FROM xxd_ar_trx_headers_stg_t;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'OTHERS Exception in the Procedure Min_Max_Batch_Prc:  '
                || SUBSTR (SQLERRM, 1, 499));
    END;

    -- To generate the proces report..
    --
    PROCEDURE print_processing_summary (x_ret_code OUT VARCHAR2)
    IS
        ln_process_cnt              NUMBER := 0;
        ln_error_cnt                NUMBER := 0;
        ln_validate_cnt             NUMBER := 0;
        ln_total                    NUMBER := 0;
        --Price list line cnt
        ln_line_process_cnt         NUMBER := 0;
        ln_line_error_cnt           NUMBER := 0;
        ln_line_validate_cnt        NUMBER := 0;
        ln_line_total               NUMBER := 0;
        --Price Attribute cnt
        ln_attrib_process_cnt       NUMBER := 0;
        ln_attrib_error_cnt         NUMBER := 0;
        ln_attrib_validate_cnt      NUMBER := 0;
        ln_attrib_total             NUMBER := 0;
        --Price list Qualifier cnt
        ln_qualifier_process_cnt    NUMBER := 0;
        ln_qualifier_error_cnt      NUMBER := 0;
        ln_qualifier_validate_cnt   NUMBER := 0;
        ln_qualifier_total          NUMBER := 0;
    BEGIN
        x_ret_code   := gn_suc_const;
        fnd_file.put_line (
            fnd_file.output,
            '***************************************************************************************');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Transaction Header Id', 20, ' ')
            || '  '
            || RPAD (' Transaction Line Id', 20, ' ')
            || '  '
            || RPAD ('Transaction Distribution Id', 20, ' ')
            || '  '
            || RPAD (' ', 10, ' ')
            || '  '
            || RPAD ('Error Message', 500, ' '));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('--', 20, '-')
            || '  '
            || RPAD ('--', 20, '-')
            || '  '
            || RPAD ('--', 20, '-')
            || '  '
            || RPAD ('--', 10, '-')
            || '  '
            || RPAD ('--', 500, '-'));

        FOR error_in IN (SELECT object_name, error_message, useful_info1,
                                useful_info2, useful_info3, useful_info4
                           FROM xxd_error_log_t
                          WHERE request_id = gn_conc_request_id)
        LOOP
            fnd_file.put_line (
                fnd_file.output,
                   RPAD (error_in.useful_info1, 20, ' ')
                || '  '
                || RPAD (NVL (error_in.useful_info2, ' '), 20, ' ')
                || '  '
                || RPAD (NVL (error_in.useful_info3, ' '), 20, ' ')
                || '  '
                || RPAD (NVL (error_in.useful_info4, ' '), 10, ' ')
                || '  '
                || RPAD (error_in.error_message, 500, ' '));
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_err_const;
            log_records (
                'Y',
                   SUBSTR (SQLERRM, 1, 150)
                || ' Exception in print_processing_summary procedure ');
    END print_processing_summary;

    /*======================================================================================
    | Procedure name                                                             |  New procedure added by smehrotra006
    |     submit_child_requests                                                   |
    |                                                                            |
    | DESCRIPTION                                                                |
    | Procedure submit_child_requests submits the child requests 'n'          |
    | number of times based on no of batches created for the records.         |
    | This procedure is common for submitting the child programs             |
    |  related to both Validation and Load.                      |

     =============================================================================================*/
    PROCEDURE submit_child_requests (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_appln_shrt_name IN VARCHAR2, p_conc_pgm_name IN VARCHAR2, p_org_id IN VARCHAR2, p_batch_low_limit IN NUMBER
                                     , p_batch_high_limit IN NUMBER)
    IS
        --Cursor for Distinct Batch Number
        CURSOR c1 IS
              SELECT batch_number, source_org_id
                FROM xxd_ar_trx_headers_stg_t
               WHERE     batch_number BETWEEN p_batch_low_limit
                                          AND p_batch_high_limit
                     AND source_org_id = NVL (p_org_id, source_org_id)
            GROUP BY batch_number, source_org_id
            ORDER BY batch_number;

        l_batch_nos         VARCHAR2 (1000);
        l_sub_requests      fnd_concurrent.requests_tab_type;
        l_errored_rec_cnt   NUMBER;
        l_warning_cnt       NUMBER := 0;
        l_error_cnt         NUMBER := 0;
        l_return            BOOLEAN;
        l_phase             VARCHAR2 (30);
        l_status            VARCHAR2 (30);
        l_dev_phase         VARCHAR2 (30);
        l_dev_status        VARCHAR2 (30);
        l_message           VARCHAR2 (1000);
        l_request_id        NUMBER;
        ln_cnt              NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Submitting child requests.');
        fnd_file.put_line (
            fnd_file.LOG,
               'p_batch_low_limit'
            || ','
            || p_batch_low_limit
            || ','
            || 'p_batch_high_limit'
            || p_batch_high_limit
            || 'p_org_id'
            || ','
            || p_org_id);

        FOR c1_rec IN c1
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'p_appln_shrt_name'
                || p_appln_shrt_name
                || ','
                || 'p_conc_pgm_name'
                || ','
                || p_conc_pgm_name
                || ','
                || 'c1_rec.SOURCE_ORG_ID'
                || c1_rec.source_org_id
                || ','
                || 'c1_rec.batch_number'
                || ','
                || c1_rec.batch_number);
            l_request_id   :=
                fnd_request.submit_request (
                    application   => p_appln_shrt_name,
                    --Submitting Child Requests
                    program       => p_conc_pgm_name,
                    argument1     => c1_rec.source_org_id,
                    argument2     => c1_rec.batch_number,
                    argument3     => c1_rec.batch_number);
            COMMIT;
            fnd_file.put_line (fnd_file.LOG, 'l_request_id' || l_request_id);
            fnd_file.put_line (fnd_file.LOG,
                               ' batch_number :' || c1_rec.batch_number);
            fnd_file.put_line (fnd_file.LOG, 'Inside the Loop of cursor c1');
        END LOOP;

        --COMMIT;
        fnd_file.put_line (fnd_file.LOG,
                           ' End Time :' || TO_CHAR (SYSDATE, 'hh:mi:ss'));
        l_sub_requests   := fnd_concurrent.get_sub_requests (gn_req_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Waiting for child requests to be completed.');

        FOR i IN l_sub_requests.FIRST .. l_sub_requests.LAST
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                'request_id : ' || l_sub_requests (i).request_id);
            fnd_file.put_line (fnd_file.LOG,
                               'phase : ' || l_sub_requests (i).phase);
            fnd_file.put_line (fnd_file.LOG,
                               'status :' || l_sub_requests (i).status);
            fnd_file.put_line (fnd_file.LOG,
                               'dev_phase :' || l_sub_requests (i).dev_phase);
            fnd_file.put_line (
                fnd_file.LOG,
                'dev_status :' || l_sub_requests (i).dev_status);
            fnd_file.put_line (fnd_file.LOG,
                               'message :' || l_sub_requests (i).MESSAGE);
            fnd_file.put_line (
                fnd_file.LOG,
                l_sub_requests.COUNT || 'Count of the l_sub_requests');

            IF NVL (l_sub_requests (i).request_id, 0) > 0
            THEN
                LOOP
                    l_return   :=
                        fnd_concurrent.wait_for_request (
                            l_sub_requests (i).request_id,
                            --Waiting for Child Requests to be completed.
                            10,
                            240,
                            l_sub_requests (i).phase,
                            l_sub_requests (i).status,
                            l_sub_requests (i).dev_phase,
                            l_sub_requests (i).dev_status,
                            l_sub_requests (i).MESSAGE);
                    COMMIT;

                    IF UPPER (l_sub_requests (i).status) = 'WARNING'
                    THEN
                        l_warning_cnt   := l_warning_cnt + 1;
                    --Count of records ended in warning.
                    END IF;

                    IF UPPER (l_sub_requests (i).status) = 'ERROR'
                    THEN
                        l_error_cnt   := l_error_cnt + 1;
                    --Count of records ended in error.
                    END IF;

                    EXIT WHEN    UPPER (l_sub_requests (i).phase) =
                                 'COMPLETED'
                              OR UPPER (l_sub_requests (i).status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_code_pointer   := 'Caught Exception' || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, gc_code_pointer);
            fnd_file.put_line (fnd_file.LOG,
                               'End of the procedure submit_child_requests');
            fnd_file.put_line (
                fnd_file.LOG,
                   'The Request Id of the concurrent request submitted'
                || l_request_id);
    END;

    --+---------------------------------------------
    --| Name        : IMPORT
    --| Description : Imports the validated records
    --+---------------------------------------------
    PROCEDURE import_record (x_errbuff OUT VARCHAR2, x_retcode OUT NUMBER, p_batch_number IN NUMBER, p_action IN VARCHAR2, p_org_name IN VARCHAR2, pv_from_trx_no IN VARCHAR2
                             , pv_to_trx_no IN VARCHAR2)
    IS
        ln_customer_trx_id               NUMBER;
        gc_stage                         VARCHAR2 (250) := 'import_record';
        lc_return_status                 VARCHAR2 (10);
        ln_msg_count                     NUMBER := 0;
        lc_msg_data                      VARCHAR2 (2000);
        ln_err_trx_header_id             NUMBER;
        ln_err_trx_line_id               NUMBER;
        lc_invalid_value                 VARCHAR2 (2000);
        lc_error_msg                     VARCHAR2 (2000);
        l_tbl_message_list               error_handler.error_tbl_type;
        ln_msg_index                     NUMBER;
        ln_error_count                   NUMBER := 0;
        lc_error_message                 LONG;
        lc_dev_phase                     VARCHAR2 (200);
        lc_dev_status                    VARCHAR2 (200);
        lb_wait                          BOOLEAN;
        lc_phase                         VARCHAR2 (100);
        lc_message                       VARCHAR2 (100);
        ln_msg_index_out                 NUMBER;
        ln_err_count                     NUMBER;
        ln_count                         NUMBER := 0;
        l_cnt                            NUMBER := 0;
        v_org_id                         NUMBER := 0;
        ln_records_processed_cnt         NUMBER := 0;
        ln_records_imported_cnt          NUMBER := 0;
        line_id                          NUMBER := 0;
        ln_batch_source_id               NUMBER;
        ln_amount                        NUMBER;
        lc_description                   VARCHAR2 (500);
        lc_comm_interface_line_context   VARCHAR2 (30);
        lc_comm_interface_line_attr1     VARCHAR2 (150);
        lc_comm_interface_line_attr2     VARCHAR2 (150);
        lc_comm_interface_line_attr3     VARCHAR2 (150);
        lc_comm_interface_line_attr4     VARCHAR2 (150);
        lc_comm_interface_line_attr5     VARCHAR2 (150);
        lc_comm_interface_line_attr6     VARCHAR2 (150);
        lc_comm_interface_line_attr7     VARCHAR2 (150);
        lc_comm_interface_line_attr8     VARCHAR2 (150);
        lc_comm_interface_line_attr9     VARCHAR2 (150);
        lc_comm_interface_line_attr10    VARCHAR2 (150);
        lc_comm_interface_line_attr11    VARCHAR2 (150);
        lc_comm_interface_line_attr12    VARCHAR2 (150);
        lc_comm_interface_line_attr13    VARCHAR2 (150);
        lc_comm_interface_line_attr14    VARCHAR2 (150);
        lc_comm_interface_line_attr15    VARCHAR2 (150);
        lc_location                      VARCHAR2 (150);
        l_new_trx_number                 ra_customer_trx_all.trx_number%TYPE;
        l_new_customer_trx_id            ra_customer_trx_all.customer_trx_id%TYPE;
        l_new_customer_trx_line_id       ra_customer_trx_lines_all.customer_trx_line_id%TYPE;
        ln_new_rowid                     NUMBER;
        lt_trx_header_tbl_tmp            ar_invoice_api_pub.trx_header_tbl_type;
        lt_trx_header_tbl                ar_invoice_api_pub.trx_header_tbl_type;
        lt_trx_lines_tbl                 ar_invoice_api_pub.trx_line_tbl_type;
        lt_trx_dist_tbl                  ar_invoice_api_pub.trx_dist_tbl_type;
        lt_trx_dist_tbl_1                ar_invoice_api_pub.trx_dist_tbl_type;
        lt_trx_salescredits_tbl          ar_invoice_api_pub.trx_salescredits_tbl_type;
        l_batch_source_rec               ar_invoice_api_pub.batch_source_rec_type;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                         request_table;



        TYPE l_batch_source_tbl_type IS TABLE OF VARCHAR2 (100)
            INDEX BY BINARY_INTEGER;

        l_batch_source_tbl               l_batch_source_tbl_type;

        ld_billing_date                  VARCHAR2 (30);

        CURSOR cur_batch_sources IS
            SELECT DISTINCT new_batch_source_name
              FROM xxd_ar_trx_headers_stg_t;

        --+------------------------------------------------------------------
        --|Cursor for fetching only consolidated billing OUs i.e. Japan OU and Shanghai OU added on 20 Aug 2015
        --+------------------------------------------------------------------
        CURSOR cur_for_cons_OUs (p_batch_source_name VARCHAR2)
        IS
              /*    SELECT bill_to_customer_id,
                         cons_inv_id,
                         trx_currency,
                         billing_cycle_id,
                         hca.account_number,
                         consolidation_flag,
                         --         fnd_date.canonical_to_date(max(trx_date)+1) billing_date
                         MAX (trx_date) billing_date
                    FROM xxd_conv.xxd_ar_trx_headers_stg_t xath,
                         hz_cust_accounts_all hca
                   WHERE     record_status = p_action
                         --          and consolidation_flag = 'Y'
                         AND xath.bill_to_customer_id = hca.cust_account_id
                         --                AND destination_org_id =  pn_org_id
                         AND batch_number = p_batch_number
                         AND new_batch_source_name = p_batch_source_name
                --                and cons_inv_id in (15455, 13521)
                GROUP BY bill_to_customer_id,
                         cons_inv_id,
                         trx_currency,
                         billing_cycle_id,
                         hca.account_number,
                         consolidation_flag
                ORDER BY account_number, billing_date, cons_inv_id;*/
              SELECT bill_to_customer_id, cons_inv_id, trx_currency,
                     billing_cycle_id, hca.account_number, consolidation_flag,
                     MAX (trx_date) billing_date, hcsua.site_use_id --cust_acct_site_id
                FROM xxd_conv.xxd_ar_trx_headers_stg_t xath, hz_cust_accounts_all hca, hz_cust_acct_sites_all hcasa,
                     hz_cust_site_uses_all hcsua
               WHERE     record_status = p_action
                     AND xath.bill_to_customer_id = hca.cust_account_id
                     AND batch_number = p_batch_number
                     AND new_batch_source_name = p_batch_source_name
                     AND hcasa.cust_account_id = hca.cust_account_id
                     AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                     --Start changes for BT Team on 1 Mar
                     -- AND xath.bill_to_site_use_id = hcsua.bill_to_site_use_id
                     AND xath.bill_to_site_use_id = hcsua.site_use_id
            --End changes for BT Team on 1 Mar
            GROUP BY bill_to_customer_id, hcsua.site_use_id, --cust_acct_site_id,
                                                             cons_inv_id,
                     trx_currency, billing_cycle_id, hca.account_number,
                     consolidation_flag
            ORDER BY account_number, billing_date, cons_inv_id;

        --+------------------------------------------------------------------
        --|Cursor for fetching the header lines
        --+------------------------------------------------------------------
        CURSOR cur_trx_headers (p_batch_source_name   VARCHAR2,
                                pn_cons_inv_id        NUMBER DEFAULT NULL)
        IS
              SELECT trx_header_id, trx_number, trx_date,
                     trx_currency, reference_number, trx_class,
                     cust_trx_type_id, gl_date, bill_to_customer_id,
                     bill_to_account_number, NULL, bill_to_contact_id,
                     bill_to_address_id, bill_to_site_use_id, ship_to_customer_id,
                     ship_to_account_number, ship_to_customer_name, ship_to_contact_id,
                     ship_to_address_id, ship_to_site_use_id, sold_to_customer_id,
                     term_id, primary_salesrep_id, primary_salesrep_name,
                     exchange_rate_type, exchange_date, exchange_rate,
                     territory_id, remit_to_address_id, invoicing_rule_id,
                     printing_option, purchase_order, purchase_order_revision,
                     purchase_order_date, comments, internal_notes,
                     finance_charges, receipt_method_id, related_customer_trx_id,
                     agreement_id, ship_via, ship_date_actual,
                     waybill_number, fob_point, customer_bank_account_id,
                     default_ussgl_transaction_code, status_trx, paying_customer_id,
                     paying_site_use_id, default_tax_exempt_flag, doc_sequence_value,
                     NULL attribute_category, TO_CHAR (TO_DATE (attribute1, 'DD-MON-RR'), 'YYYY/MM/DD'), NULL attribute2,
                     attribute3, attribute4, attribute5,
                     attribute6, attribute7, attribute8,
                     attribute9, attribute10, attribute11,
                     attribute12, attribute13, attribute14,
                     attribute15, global_attribute_category, global_attribute1,
                     global_attribute2, global_attribute3, global_attribute4,
                     global_attribute5, global_attribute6, global_attribute7,
                     global_attribute8, global_attribute9, global_attribute10,
                     global_attribute11, global_attribute12, global_attribute13,
                     global_attribute14, global_attribute15, global_attribute16,
                     global_attribute17, global_attribute18, global_attribute19,
                     global_attribute20, global_attribute21, global_attribute22,
                     global_attribute23, global_attribute24, global_attribute25,
                     global_attribute26, global_attribute27, global_attribute28,
                     global_attribute29, global_attribute30, NULL interface_header_context,
                     interface_header_attribute1, interface_header_attribute2, interface_header_attribute3,
                     interface_header_attribute4, interface_header_attribute5, interface_header_attribute6,
                     interface_header_attribute7, interface_header_attribute8, interface_header_attribute9,
                     interface_header_attribute10, interface_header_attribute11, interface_header_attribute12,
                     interface_header_attribute13, interface_header_attribute14, interface_header_attribute15,
                     destination_org_id, legal_entity_id, payment_trxn_extension_id,
                     billing_date, interest_header_id, late_charges_assessed,
                     document_sub_type, default_taxation_country, mandate_last_trx_flag
                FROM xxd_ar_trx_headers_stg_t
               WHERE     record_status = p_action
                     --        AND source_org_id =  gn_source_org_id
                     AND batch_number = p_batch_number
                     AND new_batch_source_name = p_batch_source_name
                     --Start of Added new condition for consolidation on 20 Aug 2015
                     AND NVL (cons_inv_id, 1) = NVL (pn_cons_inv_id, 1)
                     AND trx_number BETWEEN NVL (TO_CHAR (pv_from_trx_no),
                                                 trx_number)
                                        AND NVL (TO_CHAR (pv_to_trx_no),
                                                 trx_number)
            ORDER BY old_bill_to_customer_id, trx_date, cons_inv_id NULLS LAST;

        --End of Added new condition for consolidation on 20 Aug 2015



        --+------------------------------------------------------------------
        --|Cursor for fetching the  lines
        --+------------------------------------------------------------------
        CURSOR cur_trx_lines (p_header_id NUMBER)
        IS
            SELECT trx_header_id, trx_line_id, link_to_trx_line_id,
                   line_number, reason_code, inventory_item_id,
                   description, quantity_ordered, quantity_invoiced,
                   unit_standard_price, unit_selling_price, sales_order,
                   sales_order_line, sales_order_date, accounting_rule_id,
                   NULL accounting_rule_duration, line_type, attribute_category,
                   attribute1, attribute2, attribute3,
                   attribute4, attribute5, attribute6,
                   attribute7, attribute8, attribute9,
                   attribute10, attribute11, attribute12,
                   attribute13, attribute14, attribute15,
                   rule_start_date, interface_line_context, interface_line_attribute1,
                   interface_line_attribute2, interface_line_attribute3, interface_line_attribute4,
                   interface_line_attribute5, interface_line_attribute6, interface_line_attribute7,
                   interface_line_attribute8, interface_line_attribute9, interface_line_attribute10,
                   interface_line_attribute11, interface_line_attribute12, interface_line_attribute13,
                   interface_line_attribute14, interface_line_attribute15, sales_order_source,
                   amount, tax_precedence, tax_rate,
                   tax_exemption_id, memo_line_id, uom_code,
                   default_ussgl_transaction_code, default_ussgl_trx_code_context, vat_tax_id,
                   tax_exempt_flag, tax_exempt_number, tax_exempt_reason_code,
                   tax_vendor_return_code, movement_id, global_attribute1,
                   global_attribute2, global_attribute3, global_attribute4,
                   global_attribute5, global_attribute6, global_attribute7,
                   global_attribute8, global_attribute9, global_attribute10,
                   global_attribute11, global_attribute12, global_attribute13,
                   global_attribute14, global_attribute15, global_attribute16,
                   global_attribute17, global_attribute18, global_attribute19,
                   global_attribute20, global_attribute_category, amount_includes_tax_flag,
                   warehouse_id, contract_line_id, source_data_key1,
                   source_data_key2, source_data_key3, source_data_key4,
                   source_data_key5, invoiced_line_acctg_level, ship_date_actual,
                   override_auto_accounting_flag, deferral_exclusion_flag, rule_end_date,
                   source_application_id, source_event_class_code, source_entity_code,
                   source_trx_id, source_trx_line_id, source_trx_line_type,
                   source_trx_detail_tax_line_id, historical_flag, taxable_flag,
                   tax_regime_code, tax, tax_status_code,
                   tax_rate_code, tax_jurisdiction_code, tax_classification_code,
                   interest_line_id, trx_business_category, product_fisc_classification,
                   product_category, product_type, line_intended_use,
                   assessable_value
              FROM xxd_ar_trx_lines_stg_t
             WHERE trx_header_id = p_header_id;

        --+------------------------------------------------------------------
        --|Cursor for fetching the errors from ar_trx_errors_gt table
        --+------------------------------------------------------------------
        CURSOR lcu_get_errors (p_trx_header_id NUMBER)
        IS
            SELECT ateg.trx_header_id trx_header_id, ateg.trx_line_id trx_line_id, ateg.trx_dist_id trx_dist_id,
                   ateg.trx_salescredit_id trx_salescredit_id, ateg.error_message error_message, ateg.invalid_value invalid_value
              FROM ar_trx_errors_gt ateg
             WHERE ateg.trx_header_id = p_trx_header_id;

        --+------------------------------------------------------------------
        --|Cursor for fetching the error count  from ar_trx_errors_gt table
        --+------------------------------------------------------------------
        CURSOR lcu_get_error_count (p_trx_header_id NUMBER)
        IS
            SELECT COUNT (*)
              FROM ar_trx_errors_gt ateg
             WHERE ateg.trx_header_id = p_trx_header_id;

        --+------------------------------------------------------------------
        --|Cursor for fetching the batch source id
        --+------------------------------------------------------------------
        CURSOR lcu_get_batch_source_id (p_name VARCHAR2, p_org_id NUMBER)
        IS
            SELECT batch_source_id
              FROM ra_batch_sources_all
             WHERE name = p_name AND org_id = p_org_id;

        --+------------------------------------------------------------------
        --|Cursor for fetching the location
        --+------------------------------------------------------------------
        CURSOR cur_get_location (p_site_use_id     NUMBER,
                                 l_target_org_id   NUMBER)
        IS
            SELECT location
              FROM hz_cust_site_uses_all
             WHERE site_use_id = p_site_use_id AND org_id = l_target_org_id;

        l_target_org_id                  NUMBER;
    BEGIN
        l_target_org_id                      := get_targetorg_id (p_org_name => p_org_name);
        mo_global.init ('AR');
        mo_global.set_policy_context ('S', l_target_org_id);
        x_errbuff                            := NULL;
        x_retcode                            := NULL;

        log_records (gc_debug_flag, ' Target org_id : ' || l_target_org_id);
        log_records (
            gc_debug_flag,
            'Fetching batch source id for org_id : ' || l_target_org_id);

        log_records (
            gc_debug_flag,
               'Batch source id for org_id :'
            || l_target_org_id
            || 'is  '
            || ln_batch_source_id);
        l_batch_source_rec.batch_source_id   := ln_batch_source_id;
        log_records (gc_debug_flag, gc_stage);
        log_records (gc_debug_flag, 'Inserting records in PLSQL tables');

        OPEN cur_batch_sources;

        LOOP
            l_batch_source_tbl.delete;

            FETCH cur_batch_sources BULK COLLECT INTO l_batch_source_tbl;

            FOR i IN 1 .. l_batch_source_tbl.COUNT
            LOOP
                OPEN lcu_get_batch_source_id (l_batch_source_tbl (i),
                                              l_target_org_id);

                FETCH lcu_get_batch_source_id INTO ln_batch_source_id;

                CLOSE lcu_get_batch_source_id;

                l_batch_source_rec.batch_source_id   := ln_batch_source_id;

                IF p_org_name IN ('Deckers Shanghai OU', 'Deckers Japan OU')
                THEN
                    FOR rec_cur_cons_ous
                        IN cur_for_cons_OUs (l_batch_source_tbl (i))
                    LOOP
                        OPEN cur_trx_headers (l_batch_source_tbl (i),
                                              rec_cur_cons_ous.cons_inv_id);

                        LOOP
                            -- Added on 24 Aug 2015
                            ln_error_count   := 0;
                            lt_trx_header_tbl_tmp.delete;

                            FETCH cur_trx_headers
                                BULK COLLECT INTO lt_trx_header_tbl_tmp;

                            FOR i IN 1 .. lt_trx_header_tbl_tmp.COUNT
                            LOOP
                                log_records (
                                    gc_debug_flag,
                                       ' Header Table Count '
                                    || lt_trx_header_tbl_tmp.COUNT);
                                --ln_count := 0;
                                lt_trx_header_tbl.delete;
                                log_records (gc_debug_flag,
                                             'After delete pl/sql Table ');
                                lt_trx_header_tbl (1)   :=
                                    lt_trx_header_tbl_tmp (i);
                                lc_error_message   := NULL;

                                IF lt_trx_header_tbl (1).trx_class = 'CM'
                                THEN
                                    lt_trx_header_tbl (1).term_id   := NULL;
                                END IF;

                                OPEN cur_trx_lines (
                                    lt_trx_header_tbl (1).trx_header_id);

                                LOOP
                                    lt_trx_lines_tbl.delete;
                                    lt_trx_dist_tbl.delete;
                                    ln_count   := 1;

                                    FETCH cur_trx_lines
                                        BULK COLLECT INTO lt_trx_lines_tbl;

                                    log_records (
                                        gc_debug_flag,
                                           ' Line Table Count '
                                        || lt_trx_lines_tbl.COUNT);

                                    FOR j IN 1 .. lt_trx_lines_tbl.COUNT
                                    LOOP
                                        line_id   :=
                                            lt_trx_lines_tbl (j).trx_line_id;
                                        ln_amount   :=
                                            lt_trx_lines_tbl (j).amount;
                                        lc_description   :=
                                            lt_trx_lines_tbl (j).description;
                                        lc_comm_interface_line_context   :=
                                            lt_trx_lines_tbl (j).interface_line_context;
                                        lc_comm_interface_line_attr1   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute1;
                                        lc_comm_interface_line_attr2   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute2;
                                        lc_comm_interface_line_attr3   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute3;
                                        lc_comm_interface_line_attr4   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute4;
                                        lc_comm_interface_line_attr5   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute5;
                                        lc_comm_interface_line_attr6   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute6;
                                        lc_comm_interface_line_attr7   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute7;
                                        lc_comm_interface_line_attr8   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute8;
                                        lc_comm_interface_line_attr9   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute9;
                                        lc_comm_interface_line_attr10   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute10;
                                        lc_comm_interface_line_attr11   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute11;
                                        lc_comm_interface_line_attr12   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute12;
                                        lc_comm_interface_line_attr13   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute13;
                                        lc_comm_interface_line_attr14   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute14;
                                        lc_comm_interface_line_attr15   :=
                                            lt_trx_lines_tbl (j).interface_line_attribute15;
                                        lt_trx_lines_tbl (j).source_trx_id   :=
                                            NULL;
                                        lt_trx_lines_tbl (j).source_trx_line_id   :=
                                            NULL;
                                    END LOOP;

                                    EXIT WHEN cur_trx_lines%NOTFOUND;
                                END LOOP;

                                CLOSE cur_trx_lines;

                                log_records (
                                    gc_debug_flag,
                                       'No of records in lt_trx_header_tbl '
                                    || lt_trx_header_tbl.COUNT);
                                log_records (
                                    gc_debug_flag,
                                       'No of records in lt_trx_lines_tbl ID : '
                                    || lt_trx_lines_tbl.COUNT);
                                log_records (
                                    gc_debug_flag,
                                       'No of records in lt_trx_salescredits_tbl '
                                    || lt_trx_salescredits_tbl.COUNT);
                                log_records (
                                    gc_debug_flag,
                                    'Calling standard API for creating single invoice');

                                BEGIN
                                    log_records (
                                        gc_debug_flag,
                                           'Transaction class '
                                        || lt_trx_header_tbl (1).trx_class);
                                    log_records (
                                        gc_debug_flag,
                                           'Bill to site_use_id:'
                                        || lt_trx_header_tbl (1).bill_to_site_use_id);

                                    IF lt_trx_header_tbl (1).bill_to_site_use_id
                                           IS NOT NULL
                                    THEN
                                        OPEN cur_get_location (
                                            lt_trx_header_tbl (1).bill_to_site_use_id,
                                            l_target_org_id);

                                        FETCH cur_get_location
                                            INTO lc_location;

                                        CLOSE cur_get_location;

                                        log_records (
                                            gc_debug_flag,
                                               'Bill to Location:'
                                            || lc_location);
                                    END IF;

                                    log_records (
                                        gc_debug_flag,
                                           'ORG_ID'
                                        || lt_trx_header_tbl (1).org_id);

                                    arp_standard.enable_debug;

                                    ar_invoice_api_pub.create_single_invoice (
                                        p_api_version     => 1.0,
                                        p_init_msg_list   => fnd_api.g_false,
                                        p_commit          => fnd_api.g_false,
                                        p_batch_source_rec   =>
                                            l_batch_source_rec,
                                        p_trx_header_tbl   =>
                                            lt_trx_header_tbl,
                                        p_trx_lines_tbl   => lt_trx_lines_tbl,
                                        p_trx_dist_tbl    => lt_trx_dist_tbl_1,
                                        p_trx_salescredits_tbl   =>
                                            lt_trx_salescredits_tbl,
                                        x_customer_trx_id   =>
                                            ln_customer_trx_id,
                                        x_return_status   => lc_return_status,
                                        x_msg_count       => ln_msg_count,
                                        x_msg_data        => lc_msg_data);
                                    COMMIT;
                                    log_records (
                                        gc_debug_flag,
                                        'MSG Count ' || ln_msg_count);
                                    log_records (gc_debug_flag,
                                                 'MSG Data ' || lc_msg_data);

                                    OPEN lcu_get_error_count (
                                        lt_trx_header_tbl (1).trx_header_id);

                                    FETCH lcu_get_error_count
                                        INTO ln_err_count;

                                    CLOSE lcu_get_error_count;

                                    log_records (
                                        gc_debug_flag,
                                        'Status ' || lc_return_status);
                                    log_records (
                                        gc_debug_flag,
                                           'trx_header_id'
                                        || lt_trx_header_tbl (1).trx_header_id);

                                    IF ln_msg_count >= 1
                                    THEN
                                        FOR i IN 1 .. ln_msg_count
                                        LOOP
                                            fnd_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     => 'F',
                                                p_data        => lc_error_msg,
                                                p_msg_index_out   =>
                                                    ln_msg_index);

                                            log_records (
                                                gc_debug_flag,
                                                   'Error Message Index:'
                                                || ln_msg_index);
                                            log_records (
                                                gc_debug_flag,
                                                   'FND_MSG_PUB Error Message:'
                                                || lc_error_msg);
                                        END LOOP;
                                    END IF;

                                    error_handler.get_message_list (
                                        x_message_list => l_tbl_message_list);

                                    FOR i IN 1 .. l_tbl_message_list.COUNT
                                    LOOP
                                        log_records (
                                            gc_debug_flag,
                                               'Error'
                                            || l_tbl_message_list (i).MESSAGE_TEXT);
                                    END LOOP;

                                    log_records (
                                        gc_debug_flag,
                                           'Success'
                                        || lc_return_status
                                        || '. ln_customer_trx_id = '
                                        || ln_customer_trx_id);
                                    log_records (gc_debug_flag, ' ');
                                    log_records (gc_debug_flag, ' ');
                                    log_records (gc_debug_flag, 'ERROR LOG:');
                                    log_records (
                                        gc_debug_flag,
                                           RPAD ('Header', 20)
                                        || RPAD ('Line', 20)
                                        || RPAD ('Dist', 20)
                                        || RPAD ('Sales', 20)
                                        || RPAD ('Invalid Value', 20)
                                        || 'Error');
                                    log_records (
                                        gc_debug_flag,
                                           RPAD ('-', 20, '-')
                                        || RPAD ('-', 20, '-')
                                        || RPAD ('-', 20, '-')
                                        || RPAD ('-', 20, '-')
                                        || RPAD ('-', 20, '-')
                                        || RPAD ('-', 20, '-'));

                                    FOR lr_get_errors
                                        IN lcu_get_errors (
                                               lt_trx_header_tbl (1).trx_header_id)
                                    LOOP
                                        ln_error_count   :=
                                            ln_error_count + 1;
                                        xxd_common_utils.record_error (
                                            p_module       => 'AR',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers AR Open Invoice Conversion Program',
                                            p_error_msg    =>
                                                lr_get_errors.error_message,
                                            p_error_line   =>
                                                DBMS_UTILITY.format_error_backtrace,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_trx_header_tbl (1).trx_number,
                                            p_more_info2   =>
                                                lt_trx_header_tbl (1).org_id,
                                            p_more_info3   => NULL,
                                            p_more_info4   => NULL);
                                    END LOOP;

                                    IF    ln_error_count >= 1
                                       OR NVL (ln_customer_trx_id, 0) = 0
                                    THEN
                                        log_records (
                                            gc_debug_flag,
                                            'Update headers staging table with status IMPORT ERROR');

                                        UPDATE xxd_ar_trx_headers_stg_t
                                           SET record_status = gc_error_status, request_id = gn_conc_request_id
                                         WHERE trx_header_id =
                                               lt_trx_header_tbl (1).trx_header_id;

                                        log_records (
                                            gc_debug_flag,
                                            'Update lines staging table with status IMPORT ERROR');

                                        UPDATE xxd_ar_trx_lines_stg_t
                                           SET record_status = gc_error_status
                                         WHERE trx_header_id =
                                               lt_trx_header_tbl (1).trx_header_id;

                                        IF    lc_msg_data IS NOT NULL
                                           OR lc_error_msg IS NOT NULL
                                        THEN
                                            xxd_common_utils.record_error (
                                                p_module       => 'AR',
                                                p_org_id       => gn_org_id,
                                                p_program      =>
                                                    'Deckers AR Open Invoice Conversion Program',
                                                p_error_msg    =>
                                                       lc_msg_data
                                                    || '. '
                                                    || lc_error_msg,
                                                p_error_line   =>
                                                    DBMS_UTILITY.format_error_backtrace,
                                                p_created_by   => gn_user_id,
                                                p_request_id   =>
                                                    gn_conc_request_id,
                                                p_more_info1   =>
                                                    lt_trx_header_tbl (1).trx_number,
                                                p_more_info2   =>
                                                    lt_trx_header_tbl (1).org_id,
                                                p_more_info3   => NULL,
                                                p_more_info4   => NULL);
                                        END IF;

                                        COMMIT;
                                    ELSE
                                        log_records (
                                            gc_debug_flag,
                                               'Transaction created with trx_id :'
                                            || ln_customer_trx_id);
                                        log_records (
                                            gc_debug_flag,
                                            'Update headers staging table with status IMPORTED');

                                        FOR lt_trx_header_rec
                                            IN (SELECT printing_last_printed, printing_count
                                                  FROM xxd_ar_trx_headers_stg_t
                                                 WHERE trx_header_id =
                                                       lt_trx_header_tbl (1).trx_header_id)
                                        LOOP
                                            IF    lt_trx_header_rec.printing_last_printed
                                                      IS NOT NULL
                                               OR lt_trx_header_rec.printing_count
                                                      IS NOT NULL
                                            THEN
                                                UPDATE ra_customer_trx_all
                                                   SET printing_last_printed = lt_trx_header_rec.printing_last_printed, printing_count = lt_trx_header_rec.printing_count
                                                 WHERE customer_trx_id =
                                                       ln_customer_trx_id;
                                            END IF;
                                        END LOOP;

                                        UPDATE xxd_ar_trx_headers_stg_t
                                           SET record_status = gc_process_status
                                         WHERE trx_header_id =
                                               lt_trx_header_tbl (1).trx_header_id;

                                        log_records (
                                            gc_debug_flag,
                                            'Update lines staging table with status IMPORTED');

                                        UPDATE xxd_ar_trx_lines_stg_t
                                           SET record_status = gc_process_status
                                         WHERE trx_header_id =
                                               lt_trx_header_tbl (1).trx_header_id;

                                        COMMIT;
                                    END IF;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        log_records (
                                            gc_debug_flag,
                                               'EXCEPTION for API : AR_INVOICE_API_PUB.create_single_invoice API at '
                                            || gc_stage
                                            || SQLERRM);

                                        UPDATE xxd_ar_trx_headers_stg_t
                                           SET record_status   = 'API Error'
                                         WHERE trx_header_id =
                                               lt_trx_header_tbl (1).trx_header_id;
                                END;
                            END LOOP;

                            EXIT WHEN cur_trx_headers%NOTFOUND;
                        END LOOP;

                        CLOSE cur_trx_headers;

                        --Calling Consolidate Forward billing
                        ln_count   := 0;

                        IF rec_cur_cons_ous.cons_inv_id IS NOT NULL
                        THEN
                            BEGIN
                                -- Start Changes by BT Technology team on 16 Feb 2016
                                IF rec_cur_cons_ous.billing_cycle_id IS NULL
                                THEN
                                    BEGIN
                                        --Start Changes by BT Team on  1 March
                                        /*  UPDATE xxd_ar_trx_headers_stg_t a
                                             SET billing_cycle_id =
                                                    (SELECT billing_cycle_id
                                                       FROM apps.ra_terms
                                                      WHERE name =
                                                               (SELECT DISTINCT
                                                                       PAYMENT_TERMS
                                                                  FROM xxd_ar_brand_cust_stg_t b,
                                                                       apps.hz_cust_accounts_all hca
                                                                 WHERE     b.brand_customer_account =
                                                                              hca.account_number
                                                                       AND a.bill_to_customer_id =
                                                                              hca.cust_account_id
                                                                       AND a.cons_inv_id =
                                                                              rec_cur_cons_ous.cons_inv_id
                                                                       AND b.brand_customer_account =
                                                                              rec_cur_cons_ous.account_number))
                                           WHERE     trx_class = 'CM'
                                                 AND a.cons_inv_id =
                                                        rec_cur_cons_ous.cons_inv_id
                                                 AND a.bill_to_customer_id =
                                                        rec_cur_cons_ous.bill_to_customer_id;*/
                                        UPDATE xxd_ar_trx_headers_stg_t a
                                           SET billing_cycle_id   =
                                                   (SELECT billing_cycle_id
                                                      FROM apps.ra_terms rt, apps.hz_customer_profiles hcp
                                                     WHERE     rt.term_id =
                                                               hcp.standard_terms
                                                           AND hcp.cust_account_id =
                                                               a.bill_to_customer_id
                                                           AND hcp.site_use_id =
                                                               a.bill_to_site_use_id)
                                         WHERE     trx_class = 'CM'
                                               AND a.cons_inv_id =
                                                   rec_cur_cons_ous.cons_inv_id;

                                        COMMIT;
                                    --End Changes by BT Team on  1 March

                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            xxd_common_utils.record_error (
                                                p_module       => 'AR',
                                                p_org_id       => gn_org_id,
                                                p_program      =>
                                                    'Deckers AR Open Invoice Conversion Program',
                                                p_error_msg    => SQLERRM,
                                                p_error_line   =>
                                                    DBMS_UTILITY.format_error_backtrace,
                                                p_created_by   => gn_user_id,
                                                p_request_id   =>
                                                    gn_conc_request_id,
                                                p_more_info1   => NULL,
                                                p_more_info2   => NULL,
                                                p_more_info3   =>
                                                    rec_cur_cons_ous.cons_inv_id,
                                                p_more_info4   =>
                                                    rec_cur_cons_ous.account_number);
                                    END;
                                END IF;

                                -- End Changes by BT Technology team on 16 Feb 2016
                                SELECT TO_CHAR (NVL (MAX (billing_date), LAST_DAY (MAX (trx_date))), 'RRRR/MM/DD HH24:mi:ss')
                                  INTO ld_billing_date
                                  FROM ra_customer_trx_all
                                 WHERE trx_number IN
                                           (SELECT trx_number
                                              FROM xxd_ar_trx_headers_stg_t
                                             WHERE     cons_inv_id =
                                                       rec_cur_cons_ous.cons_inv_id
                                                   AND record_status =
                                                       'PROCESSED');
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    log_records (
                                        gc_debug_flag,
                                           'Error @import_record while getting the max billing date'
                                        || SQLERRM);
                            END;


                            SELECT COUNT (1)
                              INTO ln_count
                              FROM xxd_ar_trx_headers_stg_t
                             WHERE     cons_inv_id =
                                       rec_cur_cons_ous.cons_inv_id
                                   AND record_status = gc_process_status
                                   AND cons_inv_id IS NOT NULL;
                        END IF;

                        IF     ln_count >= 1
                           AND rec_cur_cons_ous.cons_inv_id IS NOT NULL
                        THEN
                            BEGIN
                                log_records (
                                    gc_debug_flag,
                                       'Calling Forward Billing Standard program CONS_INV_ID'
                                    || rec_cur_cons_ous.cons_inv_id);
                                log_records (
                                    gc_debug_flag,
                                       'Calling Forward Billing Standard program BIILING CYCLE ID'
                                    || rec_cur_cons_ous.billing_cycle_id);
                                ln_request_id1   :=
                                    apps.fnd_request.submit_request (
                                        'AR',
                                        'ARBFB_GEN',
                                        '',
                                        '',
                                        FALSE,
                                        'PRINT',
                                        l_target_org_id,
                                        'Y',
                                        rec_cur_cons_ous.billing_cycle_id, --this is the billing cycle period 25th of every month
                                        'N',        --Future date billing flag
                                        ld_billing_date,        --billing date
                                        rec_cur_cons_ous.trx_currency,
                                        '',
                                        '',
                                        rec_cur_cons_ous.account_number, --customer number low
                                        rec_cur_cons_ous.account_number, --customer number high
                                        rec_cur_cons_ous.site_use_id, --  Bill To Site
                                        rec_cur_cons_ous.site_use_id, --  Bill To Site
                                        '',
                                        0,     --rec_cur_cons_ous.cons_inv_id,
                                        0);
                                log_records (
                                    gc_debug_flag,
                                    'v_request_id := ' || ln_request_id1);

                                IF ln_request_id1 > 0
                                THEN
                                    l_req_id (i)   := ln_request_id1;
                                    COMMIT;
                                ELSE
                                    ROLLBACK;
                                END IF;


                                log_records (
                                    gc_debug_flag,
                                    'Calling WAIT FOR REQUEST CONSOLIDATED FORWARD BILLING ');

                                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                                LOOP
                                    IF l_req_id (rec) > 0
                                    THEN
                                        LOOP
                                            lc_dev_phase    := NULL;
                                            lc_dev_status   := NULL;
                                            lb_wait         :=
                                                fnd_concurrent.wait_for_request (
                                                    request_id   =>
                                                        l_req_id (rec) --ln_concurrent_request_id
                                                                      ,
                                                    interval   => 1,
                                                    max_wait   => 1,
                                                    phase      => lc_phase,
                                                    status     => lc_status,
                                                    dev_phase   =>
                                                        lc_dev_phase,
                                                    dev_status   =>
                                                        lc_dev_status,
                                                    MESSAGE    => lc_message);

                                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                                            THEN
                                                EXIT;
                                            END IF;
                                        END LOOP;
                                    END IF;
                                END LOOP;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    x_retcode   := 2;
                                    x_errbuff   := x_errbuff || SQLERRM;
                                    log_records (
                                        gc_debug_flag,
                                           'Calling WAIT FOR REQUEST CONSOLIDATED FORWARD BILLING error'
                                        || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    x_retcode   := 2;
                                    x_errbuff   := x_errbuff || SQLERRM;
                                    log_records (
                                        gc_debug_flag,
                                           'Calling WAIT FOR REQUEST CONSOLIDATED FORWARD BILLING error'
                                        || SQLERRM);
                            END;


                            --confirm billing part
                            BEGIN
                                log_records (
                                    gc_debug_flag,
                                       'Calling Forward Billing Confirm program CONS_INV_ID'
                                    || rec_cur_cons_ous.cons_inv_id);
                                ln_request_id2   :=
                                    apps.fnd_request.submit_request (
                                        'AR',
                                        'ARBFB_CONF',
                                        '',
                                        '',
                                        FALSE,
                                        'ACCEPT',
                                        l_target_org_id,
                                        rec_cur_cons_ous.account_number, -- customer number low
                                        rec_cur_cons_ous.account_number, -- customer number high
                                        '',                -- bill to site low
                                        '',               -- bill to site high
                                        '',                 --biiling date low
                                        '',                --biiling date high
                                        '',               --cons bill num from
                                        '',                 --cons bill num to
                                        ln_request_id1 --concurrent request id
                                                      );
                                log_records (
                                    gc_debug_flag,
                                    'v_request_id := ' || ln_request_id2);

                                IF ln_request_id2 > 0
                                THEN
                                    l_req_id (i)   := ln_request_id2;
                                    COMMIT;
                                ELSE
                                    ROLLBACK;
                                END IF;


                                log_records (
                                    gc_debug_flag,
                                    'Calling WAIT FOR REQUEST CONSOLIDATED FORWARD BILLING ');

                                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                                LOOP
                                    IF l_req_id (rec) > 0
                                    THEN
                                        LOOP
                                            lc_dev_phase    := NULL;
                                            lc_dev_status   := NULL;
                                            lb_wait         :=
                                                fnd_concurrent.wait_for_request (
                                                    request_id   =>
                                                        l_req_id (rec) --ln_concurrent_request_id
                                                                      ,
                                                    interval   => 1,
                                                    max_wait   => 1,
                                                    phase      => lc_phase,
                                                    status     => lc_status,
                                                    dev_phase   =>
                                                        lc_dev_phase,
                                                    dev_status   =>
                                                        lc_dev_status,
                                                    MESSAGE    => lc_message);

                                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                                            THEN
                                                EXIT;
                                            END IF;
                                        END LOOP;
                                    END IF;
                                END LOOP;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    x_retcode   := 2;
                                    x_errbuff   := x_errbuff || SQLERRM;
                                    log_records (
                                        gc_debug_flag,
                                           'Calling WAIT FOR REQUEST CONSOLIDATED FORWARD BILLING error'
                                        || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    x_retcode   := 2;
                                    x_errbuff   := x_errbuff || SQLERRM;
                                    log_records (
                                        gc_debug_flag,
                                           'Calling WAIT FOR REQUEST CONSOLIDATED FORWARD BILLING error'
                                        || SQLERRM);
                            END;
                        END IF;
                    END LOOP;
                -- for non consolidation OUs
                ELSE
                    log_records (
                        gc_debug_flag,
                        ' inside else condition' || lt_trx_header_tbl_tmp.COUNT);

                    OPEN cur_trx_headers (l_batch_source_tbl (i)); --passing null value for cons_inv_id

                    LOOP
                        lt_trx_header_tbl_tmp.delete;

                        FETCH cur_trx_headers
                            BULK COLLECT INTO lt_trx_header_tbl_tmp;

                        FOR i IN 1 .. lt_trx_header_tbl_tmp.COUNT
                        LOOP
                            --Added on 24 Aug 2015
                            ln_error_count          := 0;
                            log_records (
                                gc_debug_flag,
                                   ' Header Table Count '
                                || lt_trx_header_tbl_tmp.COUNT);
                            --ln_count := 0;
                            lt_trx_header_tbl.delete;
                            log_records (gc_debug_flag,
                                         'After delete pl/sql Table ');
                            lt_trx_header_tbl (1)   :=
                                lt_trx_header_tbl_tmp (i);
                            lc_error_message        := NULL;

                            IF lt_trx_header_tbl (1).trx_class = 'CM'
                            THEN
                                lt_trx_header_tbl (1).term_id   := NULL;
                            END IF;

                            OPEN cur_trx_lines (
                                lt_trx_header_tbl (1).trx_header_id);

                            LOOP
                                lt_trx_lines_tbl.delete;
                                lt_trx_dist_tbl.delete;
                                ln_count   := 1;

                                FETCH cur_trx_lines
                                    BULK COLLECT INTO lt_trx_lines_tbl;

                                log_records (
                                    gc_debug_flag,
                                    ' Line Table Count ' || lt_trx_lines_tbl.COUNT);

                                FOR j IN 1 .. lt_trx_lines_tbl.COUNT
                                LOOP
                                    line_id   :=
                                        lt_trx_lines_tbl (j).trx_line_id;
                                    ln_amount   :=
                                        lt_trx_lines_tbl (j).amount;
                                    lc_description   :=
                                        lt_trx_lines_tbl (j).description;
                                    lc_comm_interface_line_context   :=
                                        lt_trx_lines_tbl (j).interface_line_context;
                                    lc_comm_interface_line_attr1   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute1;
                                    lc_comm_interface_line_attr2   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute2;
                                    lc_comm_interface_line_attr3   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute3;
                                    lc_comm_interface_line_attr4   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute4;
                                    lc_comm_interface_line_attr5   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute5;
                                    lc_comm_interface_line_attr6   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute6;
                                    lc_comm_interface_line_attr7   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute7;
                                    lc_comm_interface_line_attr8   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute8;
                                    lc_comm_interface_line_attr9   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute9;
                                    lc_comm_interface_line_attr10   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute10;
                                    lc_comm_interface_line_attr11   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute11;
                                    lc_comm_interface_line_attr12   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute12;
                                    lc_comm_interface_line_attr13   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute13;
                                    lc_comm_interface_line_attr14   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute14;
                                    lc_comm_interface_line_attr15   :=
                                        lt_trx_lines_tbl (j).interface_line_attribute15;
                                    lt_trx_lines_tbl (j).source_trx_id   :=
                                        NULL;
                                    lt_trx_lines_tbl (j).source_trx_line_id   :=
                                        NULL;
                                END LOOP;

                                EXIT WHEN cur_trx_lines%NOTFOUND;
                            END LOOP;

                            CLOSE cur_trx_lines;

                            log_records (
                                gc_debug_flag,
                                   'No of records in lt_trx_header_tbl '
                                || lt_trx_header_tbl.COUNT);
                            log_records (
                                gc_debug_flag,
                                   'No of records in lt_trx_lines_tbl ID : '
                                || lt_trx_lines_tbl.COUNT);
                            log_records (
                                gc_debug_flag,
                                   'No of records in lt_trx_salescredits_tbl '
                                || lt_trx_salescredits_tbl.COUNT);
                            log_records (
                                gc_debug_flag,
                                'Calling standard API for creating single invoice');

                            BEGIN
                                log_records (
                                    gc_debug_flag,
                                       'Transaction class '
                                    || lt_trx_header_tbl (1).trx_class);
                                log_records (
                                    gc_debug_flag,
                                       'Bill to site_use_id:'
                                    || lt_trx_header_tbl (1).bill_to_site_use_id);

                                IF lt_trx_header_tbl (1).bill_to_site_use_id
                                       IS NOT NULL
                                THEN
                                    OPEN cur_get_location (
                                        lt_trx_header_tbl (1).bill_to_site_use_id,
                                        l_target_org_id);

                                    FETCH cur_get_location INTO lc_location;

                                    CLOSE cur_get_location;

                                    log_records (
                                        gc_debug_flag,
                                        'Bill to Location:' || lc_location);
                                END IF;

                                log_records (
                                    gc_debug_flag,
                                    'ORG_ID' || lt_trx_header_tbl (1).org_id);

                                arp_standard.enable_debug;

                                ar_invoice_api_pub.create_single_invoice (
                                    p_api_version        => 1.0,
                                    p_init_msg_list      => fnd_api.g_false,
                                    p_commit             => fnd_api.g_false,
                                    p_batch_source_rec   => l_batch_source_rec,
                                    p_trx_header_tbl     => lt_trx_header_tbl,
                                    p_trx_lines_tbl      => lt_trx_lines_tbl,
                                    p_trx_dist_tbl       => lt_trx_dist_tbl_1,
                                    p_trx_salescredits_tbl   =>
                                        lt_trx_salescredits_tbl,
                                    x_customer_trx_id    => ln_customer_trx_id,
                                    x_return_status      => lc_return_status,
                                    x_msg_count          => ln_msg_count,
                                    x_msg_data           => lc_msg_data);
                                COMMIT;
                                log_records (gc_debug_flag,
                                             'MSG Count ' || ln_msg_count);
                                log_records (gc_debug_flag,
                                             'MSG Data ' || lc_msg_data);

                                OPEN lcu_get_error_count (
                                    lt_trx_header_tbl (1).trx_header_id);

                                FETCH lcu_get_error_count INTO ln_err_count;

                                CLOSE lcu_get_error_count;

                                log_records (gc_debug_flag,
                                             'Status ' || lc_return_status);
                                log_records (
                                    gc_debug_flag,
                                       'trx_header_id'
                                    || lt_trx_header_tbl (1).trx_header_id);

                                IF ln_msg_count >= 1
                                THEN
                                    FOR i IN 1 .. ln_msg_count
                                    LOOP
                                        fnd_msg_pub.get (
                                            p_msg_index       => i,
                                            p_encoded         => 'F',
                                            p_data            => lc_error_msg,
                                            p_msg_index_out   => ln_msg_index);

                                        log_records (
                                            gc_debug_flag,
                                               'Error Message Index:'
                                            || ln_msg_index);
                                        log_records (
                                            gc_debug_flag,
                                               'FND_MSG_PUB Error Message:'
                                            || lc_error_msg);
                                    END LOOP;
                                END IF;

                                error_handler.get_message_list (
                                    x_message_list => l_tbl_message_list);

                                FOR i IN 1 .. l_tbl_message_list.COUNT
                                LOOP
                                    log_records (
                                        gc_debug_flag,
                                           'Error'
                                        || l_tbl_message_list (i).MESSAGE_TEXT);
                                END LOOP;

                                log_records (
                                    gc_debug_flag,
                                       'Success'
                                    || lc_return_status
                                    || '. ln_customer_trx_id = '
                                    || ln_customer_trx_id);
                                log_records (gc_debug_flag, ' ');
                                log_records (gc_debug_flag, ' ');
                                log_records (gc_debug_flag, 'ERROR LOG:');
                                log_records (
                                    gc_debug_flag,
                                       RPAD ('Header', 20)
                                    || RPAD ('Line', 20)
                                    || RPAD ('Dist', 20)
                                    || RPAD ('Sales', 20)
                                    || RPAD ('Invalid Value', 20)
                                    || 'Error');
                                log_records (
                                    gc_debug_flag,
                                       RPAD ('-', 20, '-')
                                    || RPAD ('-', 20, '-')
                                    || RPAD ('-', 20, '-')
                                    || RPAD ('-', 20, '-')
                                    || RPAD ('-', 20, '-')
                                    || RPAD ('-', 20, '-'));

                                FOR lr_get_errors
                                    IN lcu_get_errors (
                                           lt_trx_header_tbl (1).trx_header_id)
                                LOOP
                                    ln_error_count   := ln_error_count + 1;
                                    xxd_common_utils.record_error (
                                        p_module       => 'AR',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers AR Open Invoice Conversion Program',
                                        p_error_msg    =>
                                            lr_get_errors.error_message,
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   =>
                                            lt_trx_header_tbl (1).trx_number,
                                        p_more_info2   =>
                                            lt_trx_header_tbl (1).org_id,
                                        p_more_info3   => NULL,
                                        p_more_info4   => NULL);
                                END LOOP;

                                IF    ln_error_count >= 1
                                   OR NVL (ln_customer_trx_id, 0) = 0
                                THEN
                                    log_records (
                                        gc_debug_flag,
                                        'Update headers staging table with status IMPORT ERROR');

                                    UPDATE xxd_ar_trx_headers_stg_t
                                       SET record_status = gc_error_status, request_id = gn_conc_request_id
                                     WHERE trx_header_id =
                                           lt_trx_header_tbl (1).trx_header_id;

                                    log_records (
                                        gc_debug_flag,
                                        'Update lines staging table with status IMPORT ERROR');

                                    UPDATE xxd_ar_trx_lines_stg_t
                                       SET record_status   = gc_error_status
                                     WHERE trx_header_id =
                                           lt_trx_header_tbl (1).trx_header_id;

                                    IF    lc_msg_data IS NOT NULL
                                       OR lc_error_msg IS NOT NULL
                                    THEN
                                        xxd_common_utils.record_error (
                                            p_module       => 'AR',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers AR Open Invoice Conversion Program',
                                            p_error_msg    =>
                                                   lc_msg_data
                                                || '. '
                                                || lc_error_msg,
                                            p_error_line   =>
                                                DBMS_UTILITY.format_error_backtrace,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_trx_header_tbl (1).trx_number,
                                            p_more_info2   =>
                                                lt_trx_header_tbl (1).org_id,
                                            p_more_info3   => NULL,
                                            p_more_info4   => NULL);
                                    END IF;

                                    COMMIT;
                                ELSE
                                    log_records (
                                        gc_debug_flag,
                                           'Transaction created with trx_id :'
                                        || ln_customer_trx_id);
                                    log_records (
                                        gc_debug_flag,
                                        'Update headers staging table with status IMPORTED');

                                    FOR lt_trx_header_rec
                                        IN (SELECT printing_last_printed, printing_count
                                              FROM xxd_ar_trx_headers_stg_t
                                             WHERE trx_header_id =
                                                   lt_trx_header_tbl (1).trx_header_id)
                                    LOOP
                                        IF    lt_trx_header_rec.printing_last_printed
                                                  IS NOT NULL
                                           OR lt_trx_header_rec.printing_count
                                                  IS NOT NULL
                                        THEN
                                            UPDATE ra_customer_trx_all
                                               SET printing_last_printed = lt_trx_header_rec.printing_last_printed, printing_count = lt_trx_header_rec.printing_count
                                             WHERE customer_trx_id =
                                                   ln_customer_trx_id;
                                        END IF;
                                    END LOOP;

                                    UPDATE xxd_ar_trx_headers_stg_t
                                       SET record_status = gc_process_status
                                     WHERE trx_header_id =
                                           lt_trx_header_tbl (1).trx_header_id;

                                    log_records (
                                        gc_debug_flag,
                                        'Update lines staging table with status IMPORTED');

                                    UPDATE xxd_ar_trx_lines_stg_t
                                       SET record_status = gc_process_status
                                     WHERE trx_header_id =
                                           lt_trx_header_tbl (1).trx_header_id;

                                    COMMIT;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    log_records (
                                        gc_debug_flag,
                                           'EXCEPTION for API : AR_INVOICE_API_PUB.create_single_invoice API at '
                                        || gc_stage
                                        || SQLERRM);

                                    UPDATE xxd_ar_trx_headers_stg_t
                                       SET record_status   = 'API Error'
                                     WHERE trx_header_id =
                                           lt_trx_header_tbl (1).trx_header_id;
                            END;
                        END LOOP;

                        EXIT WHEN cur_trx_headers%NOTFOUND;
                    END LOOP;

                    CLOSE cur_trx_headers;
                END IF;
            END LOOP;

            EXIT WHEN cur_batch_sources%NOTFOUND;

            CLOSE cur_batch_sources;
        END LOOP;

        COMMIT;

        log_records (
            gc_debug_flag,
            'No. of Invoices Processed :' || ln_records_processed_cnt);
        log_records (gc_debug_flag,
                     'No. of Invoices Imported :' || ln_records_imported_cnt);
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                gc_debug_flag,
                   'EXCEPTION : AR_INVOICE_API_PUB.create_single_invoice API at '
                || gc_stage
                || SQLERRM);
            x_retcode   := 1;
    END import_record;

    PROCEDURE extract_1206_data (p_target_org_name   IN     VARCHAR2,
                                 pv_from_trx_no      IN     VARCHAR2,
                                 pv_to_trx_no        IN     VARCHAR2,
                                 x_errbuf               OUT VARCHAR2,
                                 x_retcode              OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        ln_target_org_id          NUMBER := 0;
        lv_string                 LONG;
        ln_count                  NUMBER := 0;

        CURSOR lcu_ra_trx_data (p_org_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   batch_number, source_trx_header_id, trx_header_id,
                   trx_number, trx_date, trx_currency,
                   reference_number, trx_class, batch_source_name,
                   cust_trx_type_id, cust_trx_type_name, gl_date,
                   bill_to_customer_id, old_bill_to_customer_id, bill_to_account_number,
                   bill_to_customer_name, bill_to_contact_id, old_bill_to_contact_id,
                   bill_to_address_id, old_bill_to_address_id, bill_to_site_use_id,
                   old_bill_to_site_use_id, ship_to_customer_id, old_ship_to_customer_id,
                   ship_to_account_number, ship_to_customer_name, old_ship_to_contact_id,
                   ship_to_contact_id, old_ship_to_address_id, ship_to_address_id,
                   old_ship_to_site_use_id, ship_to_site_use_id, old_sold_to_customer_id,
                   sold_to_customer_id, term_id, term_name,
                   primary_salesrep_id, primary_salesrep_number, primary_salesrep_name,
                   exchange_rate_type, exchange_date, exchange_rate,
                   territory_id, remit_to_address_id, invoicing_rule_id,
                   invoicing_rule_name, printing_option, purchase_order,
                   purchase_order_revision, purchase_order_date, comments,
                   internal_notes, finance_charges, receipt_method_id,
                   receipt_method_name, related_customer_trx_id, agreement_id,
                   ship_via, ship_date_actual, waybill_number,
                   fob_point, customer_bank_account_id, default_ussgl_transaction_code,
                   status_trx, paying_customer_id, paying_site_use_id,
                   default_tax_exempt_flag, doc_sequence_value, attribute_category,
                   attribute1, attribute2, attribute3,
                   attribute4, attribute5, attribute6,
                   attribute7, attribute8, attribute9,
                   attribute10, attribute11, attribute12,
                   DECODE (attribute13,  'N', NULL,  'Y', NULL,  attribute13) attribute13, attribute14, attribute15,
                   global_attribute_category, global_attribute1, global_attribute2,
                   global_attribute3, global_attribute4, global_attribute5,
                   global_attribute6, global_attribute7, global_attribute8,
                   global_attribute9, global_attribute10, global_attribute11,
                   global_attribute12, global_attribute13, global_attribute14,
                   global_attribute15, global_attribute16, global_attribute17,
                   global_attribute18, global_attribute19, global_attribute20,
                   global_attribute21, global_attribute22, global_attribute23,
                   global_attribute24, global_attribute25, global_attribute26,
                   global_attribute27, global_attribute28, global_attribute29,
                   global_attribute30, interface_header_context, interface_header_attribute1,
                   interface_header_attribute2, interface_header_attribute3, interface_header_attribute4,
                   interface_header_attribute5, interface_header_attribute6, interface_header_attribute7,
                   interface_header_attribute8, interface_header_attribute9, interface_header_attribute10,
                   interface_header_attribute11, interface_header_attribute12, interface_header_attribute13,
                   interface_header_attribute14, interface_header_attribute15, source_org_id,
                   legal_entity_id, payment_trxn_extension_id, billing_date,
                   interest_header_id, late_charges_assessed, document_sub_type,
                   default_taxation_country, mandate_last_trx_flag, record_status,
                   error_msg, request_id, destination_org_id,
                   customer_website, new_batch_source_name, new_cust_trx_type_name,
                   printing_last_printed, printing_count, open_invoice_status,
                   cons_inv_id, consolidation_flag, billing_cycle_id
              FROM xxd_conv.xxd_ar_trx_headers_1206_t
             WHERE     source_org_id = p_org_id
                   AND record_status = 'NEW'
                   --                and trx_class = 'CM'
                   AND trx_number BETWEEN NVL ((pv_from_trx_no), trx_number)
                                      AND NVL ((pv_to_trx_no), trx_number);


        CURSOR lcu_ra_trx_lines_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   xatl.trx_header_id, xatl.trx_line_id, xatl.link_to_trx_line_id,
                   xatl.line_number, NULL reason_code, --xatl.reason_code,  -- reason_code made NULL -- API restriction
                                                       xatl.inventory_item_id,
                   xatl.inv_item_number, xatl.description, xatl.quantity_ordered,
                   xatl.quantity_invoiced, xatl.unit_standard_price, xatl.unit_selling_price,
                   xatl.sales_order, xatl.sales_order_line, xatl.sales_order_date,
                   xatl.accounting_rule_id, xatl.accounting_rule_name, xatl.line_type,
                   NULL attribute_category, --xatl.attribute_category,  -- attribute_category made NULL
                                            xatl.attribute1, xatl.attribute2,
                   xatl.attribute3, xatl.attribute4, xatl.attribute5,
                   xatl.attribute6, xatl.attribute7, xatl.attribute8,
                   xatl.attribute9, xatl.attribute10, xatl.attribute11,
                   xatl.attribute12, xatl.attribute13, xatl.attribute14,
                   xatl.attribute15, xatl.rule_start_date, xatl.rule_end_date,
                   xatl.interface_line_context, xatl.interface_line_attribute1, xatl.interface_line_attribute2,
                   xatl.interface_line_attribute3, xatl.interface_line_attribute4, xatl.interface_line_attribute5,
                   xatl.interface_line_attribute6, xatl.interface_line_attribute7, xatl.interface_line_attribute8,
                   xatl.interface_line_attribute9, xatl.interface_line_attribute10, xatl.interface_line_attribute11,
                   xatl.interface_line_attribute12, xatl.interface_line_attribute13, xatl.interface_line_attribute14,
                   xatl.interface_line_attribute15, xatl.sales_order_source, xatl.amount,
                   xatl.tax_precedence, xatl.tax_rate, xatl.tax_exemption_id,
                   xatl.memo_line_id, xatl.memo_line_name, DECODE (xatl.line_type, 'FREIGHT', NULL, DECODE (xath.trx_class, 'CM', NULL, xatl.uom_code)) uom_code, -- for CM uom_code is made null xatl.uom_code,
                   xatl.default_ussgl_transaction_code, xatl.default_ussgl_trx_code_context, xatl.vat_tax_id,
                   xatl.tax_exempt_flag, xatl.tax_exempt_number, xatl.tax_exempt_reason_code,
                   xatl.tax_vendor_return_code, xatl.movement_id, xatl.global_attribute1,
                   xatl.global_attribute2, xatl.global_attribute3, xatl.global_attribute4,
                   xatl.global_attribute5, xatl.global_attribute6, xatl.global_attribute7,
                   xatl.global_attribute8, xatl.global_attribute9, xatl.global_attribute10,
                   xatl.global_attribute11, xatl.global_attribute12, xatl.global_attribute13,
                   xatl.global_attribute14, xatl.global_attribute15, xatl.global_attribute16,
                   xatl.global_attribute17, xatl.global_attribute18, xatl.global_attribute19,
                   xatl.global_attribute20, xatl.global_attribute_category, xatl.amount_includes_tax_flag,
                   xatl.warehouse_id, xatl.contract_line_id, xatl.source_data_key1,
                   xatl.source_data_key2, xatl.source_data_key3, xatl.source_data_key4,
                   xatl.source_data_key5, xatl.invoiced_line_acctg_level, xatl.ship_date_actual,
                   xatl.override_auto_accounting_flag, xatl.deferral_exclusion_flag, xatl.source_application_id,
                   xatl.source_event_class_code, xatl.source_entity_code, xatl.source_trx_id,
                   xatl.source_trx_line_id, xatl.source_trx_line_type, xatl.source_trx_detail_tax_line_id,
                   xatl.historical_flag, xatl.taxable_flag, xatl.tax_regime_code,
                   xatl.tax, xatl.tax_status_code, xatl.tax_rate_code,
                   xatl.tax_jurisdiction_code, xatl.tax_classification_code, xatl.interest_line_id,
                   xatl.trx_business_category, xatl.product_fisc_classification, xatl.product_category,
                   xatl.product_type, xatl.line_intended_use, xatl.assessable_value,
                   xatl.request_id, xatl.record_status, xatl.error_msg,
                   xatl.source_org_id, xatl.destination_org_id
              FROM xxd_ar_trx_lines_1206_t xatl, xxd_ar_trx_headers_stg_t xath
             WHERE     xatl.source_trx_id = xath.source_trx_header_id
                   AND xath.record_status = 'NEW';
    BEGIN
        gtt_ar_opninv_stg_rec.delete;
        gtt_ar_opninv_lines_stg_rec.delete;

        --gtt_ar_line_dist_stg_rec.DELETE;

        FOR ln_org
            IN (SELECT TO_NUMBER (lookup_code) org_id
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND language = 'US'
                       AND attribute1 = p_target_org_name)
        LOOP
            ln_target_org_id   := get_targetorg_id (p_target_org_name);

            log_records (gc_debug_flag,
                         'ln_target_org_id' || ln_target_org_id);

            OPEN lcu_ra_trx_data (p_org_id => ln_org.org_id);

            LOOP
                lv_error_stage   :=
                    'Inserting lcu_ra_trx_data Data' || SYSDATE;
                fnd_file.put_line (fnd_file.LOG, lv_error_stage);
                gtt_ar_opninv_stg_rec.delete;

                FETCH lcu_ra_trx_data
                    BULK COLLECT INTO gtt_ar_opninv_stg_rec
                    LIMIT 5000;

                FOR inv_idx IN 1 .. gtt_ar_opninv_stg_rec.COUNT
                LOOP
                    gtt_ar_opninv_stg_rec (inv_idx).destination_org_id   :=
                        ln_target_org_id;
                END LOOP;

                FORALL i IN 1 .. gtt_ar_opninv_stg_rec.COUNT
                    INSERT INTO xxd_ar_trx_headers_stg_t
                         VALUES gtt_ar_opninv_stg_rec (i);

                gtt_ar_opninv_stg_rec.delete;
                COMMIT;
                EXIT WHEN lcu_ra_trx_data%NOTFOUND;
            END LOOP;

            CLOSE lcu_ra_trx_data;
        END LOOP;

        OPEN lcu_ra_trx_lines_data;

        LOOP
            lv_error_stage   :=
                'Inserting lcu_ra_trx_lines_data Data' || SYSDATE;
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_opninv_lines_stg_rec.delete;

            FETCH lcu_ra_trx_lines_data
                BULK COLLECT INTO gtt_ar_opninv_lines_stg_rec
                LIMIT 5000;

            ln_count   := gtt_ar_opninv_lines_stg_rec.COUNT;

            log_records (gc_debug_flag, 'ln_count' || ln_count);

            FOR line_idx IN 1 .. gtt_ar_opninv_lines_stg_rec.COUNT
            LOOP
                gtt_ar_opninv_lines_stg_rec (line_idx).destination_org_id   :=
                    ln_target_org_id;
            END LOOP;

            FORALL i IN 1 .. gtt_ar_opninv_lines_stg_rec.COUNT
                INSERT INTO xxd_ar_trx_lines_stg_t
                     VALUES gtt_ar_opninv_lines_stg_rec (i);

            gtt_ar_opninv_lines_stg_rec.delete;
            COMMIT;
            EXIT WHEN lcu_ra_trx_lines_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_ra_trx_lines_data;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END extract_1206_data;

    --truncte_stage_tables
    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        --x_ret_code   := gn_suc_const;
        fnd_file.put_line (
            fnd_file.LOG,
            'Working on truncte_stage_tables to purge the data');

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_TRX_HEADERS_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_TRX_LINES_STG_T';

        --EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_TRX_LINE_DIST_STG_T';

        fnd_file.put_line (fnd_file.LOG, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            --x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Truncate Stage Table Exception ' || x_return_mesg);
    END truncte_stage_tables;

    /*+=========================================================================================+
     | Procedure name                                                                                     |
     |     extract_val_load_main                                                                             |
     |                                                                                                    |
     | DESCRIPTION                                                                                        |
     | Procedure extract_val_load_main is the main program to be called for the AR conversion  |
     | process.Based on the value passed to Parameter p_process_level, Either extract from       |
     | R12 instance using the view XXD_AR_OPEN_INV_CONV_V and inserts into staging table                |
     | XXD_AR_TRX_HEADERS_STG_T validation of the records                          |
     | in the staging table or loading of records into interface table, takes place in this      |
     | procedure.                                                    |
 +==========================================================================================*/
    PROCEDURE extract_val_load_main (
        x_errbuf               OUT NOCOPY VARCHAR2,
        x_retcode              OUT NOCOPY NUMBER,
        p_process_level     IN            VARCHAR2,
        p_no_of_process     IN            VARCHAR2,
        p_target_org_name   IN            VARCHAR2,
        pv_from_trx_no      IN            VARCHAR2,
        pv_to_trx_no        IN            VARCHAR2,
        p_debug_flag        IN            VARCHAR2)
    IS
        l_err_msg                VARCHAR2 (4000);
        l_err_code               NUMBER;
        l_interface_rec_cnt      NUMBER;
        l_request_id             NUMBER;
        l_succ_interfc_rec_cnt   NUMBER := 0;
        l_warning_cnt            NUMBER := 0;
        l_error_cnt              NUMBER := 0;
        l_return                 BOOLEAN;
        l_low_batch_limit        NUMBER;
        l_high_batch_limit       NUMBER;
        l_phase                  VARCHAR2 (30);
        l_status                 VARCHAR2 (30);
        l_dev_phase              VARCHAR2 (30);
        l_dev_status             VARCHAR2 (30);
        l_message                VARCHAR2 (1000);
        l_instance               VARCHAR2 (1000);
        l_batch_nos              VARCHAR2 (1000);
        l_sub_requests           fnd_concurrent.requests_tab_type;
        l_errored_rec_cnt        NUMBER;
        l_validated_rec_cnt      NUMBER;
        v_request_id             NUMBER;
        g_debug                  VARCHAR2 (10);
        g_process_level          VARCHAR2 (50);
        l_count                  NUMBER;
        ln_org_id                NUMBER;
        ln_parent_request_id     NUMBER := fnd_global.conc_request_id;
        ln_valid_rec_cnt         NUMBER;
        ln_request_id            NUMBER := 0;
        lc_phase                 VARCHAR2 (200);
        lc_status                VARCHAR2 (200);
        lc_dev_phase             VARCHAR2 (200);
        lc_dev_status            VARCHAR2 (200);
        lc_message               VARCHAR2 (200);
        ln_ret_code              NUMBER;
        lc_err_buff              VARCHAR2 (1000);
        ln_count                 NUMBER;
        ln_cntr                  NUMBER := 0;
        lb_wait                  BOOLEAN;
        lx_return_mesg           VARCHAR2 (2000);

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id          hdr_batch_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                 request_table;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Procedure val_load_main p_process_level ' || p_process_level);
        g_process_level   := p_process_level;
        gc_debug_flag     := p_debug_flag;

        --Extract Process starts here
        IF p_process_level = gc_extract_only
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Procedure extract_main');
            fnd_file.put_line (
                fnd_file.LOG,
                'Start Time:' || TO_CHAR (SYSDATE, 'hh:mi:ss'));
            truncte_stage_tables (x_ret_code      => x_retcode,
                                  x_return_mesg   => x_errbuf);
            extract_1206_data (p_target_org_name => p_target_org_name, --p_target_org_id
                                                                       pv_from_trx_no => pv_from_trx_no, pv_to_trx_no => pv_to_trx_no
                               , x_errbuf => x_errbuf, x_retcode => x_retcode);
            DBMS_OUTPUT.put_line (
                'End Time:' || TO_CHAR (SYSDATE, 'hh:mi:ss'));
            COMMIT;
            gc_code_pointer   :=
                'After the Extraction of data from XXD_AR_OPEN_INV_CONV_V';
            fnd_file.put_line (fnd_file.LOG, gc_code_pointer);
        --Validation Process starts here.
        ELSIF (p_process_level = gc_validate_only)
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Call Procedure create_batch_prc.');

            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM xxd_ar_trx_headers_stg_t
             WHERE batch_number IS NULL AND record_status = gc_new_status;

            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT xxd_ar_opninv_batch_s.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    log_records (
                        gc_debug_flag,
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                log_records (gc_debug_flag,
                             ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                log_records (
                    gc_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_no_of_process) := '
                    || CEIL (ln_valid_rec_cnt / p_no_of_process));

                UPDATE xxd_ar_trx_headers_stg_t
                   SET batch_number = ln_hdr_batch_id (i), request_id = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND ROWNUM <=
                           CEIL (ln_valid_rec_cnt / p_no_of_process)
                       AND record_status = gc_new_status;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_AR_CUST_INT_STG_T');
        ELSIF (p_process_level = gc_load_only)
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Loading Process Initiated');
            fnd_file.put_line (fnd_file.LOG,
                               'Call Procedure min_max_batch_prc');
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_AR_TRX_HEADERS_STG_T stage to call worker process');
            ln_cntr   := 0;

            FOR i
                IN (SELECT DISTINCT batch_number
                      FROM xxd_ar_trx_headers_stg_t
                     WHERE     batch_number IS NOT NULL
                           AND record_status = gc_validate_status)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_number;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_AR_TRX_HEADERS_STG_T');
        END IF;

        COMMIT;

        IF ln_hdr_batch_id.COUNT > 0
        THEN
            log_records (
                gc_debug_flag,
                   'Calling XXD_AR_OPNINV_CHILD_CONV in batch '
                || ln_hdr_batch_id.COUNT);

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_ar_trx_headers_stg_t
                 WHERE batch_number = ln_hdr_batch_id (i);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        log_records (
                            gc_debug_flag,
                               'Calling Worker process for batch id ln_hdr_batch_id(i) := '
                            || ln_hdr_batch_id (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_AR_OPNINV_CHILD_CONV',
                                '',
                                '',
                                FALSE,
                                gc_debug_flag,
                                p_process_level,
                                p_target_org_name,
                                ln_hdr_batch_id (i),
                                ln_parent_request_id,
                                pv_from_trx_no,
                                pv_to_trx_no);
                        log_records (gc_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_AR_OPNINV_CHILD_CONV error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_AR_OPNINV_CHILD_CONV error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            log_records (
                gc_debug_flag,
                   'Calling XXD_AR_OPNINV_CHILD_CONV in batch '
                || ln_hdr_batch_id.COUNT);
            log_records (
                gc_debug_flag,
                'Calling WAIT FOR REQUEST XXD_AR_OPNINV_CHILD_CONV to complete');

            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec) > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec) --ln_concurrent_request_id
                                                              ,
                                interval     => 1,
                                max_wait     => 1,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('Org Code does not exist in 11i');
            gc_code_pointer   := 'Caught Exception' || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, gc_code_pointer);
    END extract_val_load_main;

    FUNCTION invoice_line_validation (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_source_trx_header_id IN NUMBER
                                      , px_trx_header_id IN NUMBER, p_amount_due_original IN NUMBER, p_amount_due_remaining IN NUMBER)
        RETURN VARCHAR2
    AS
        CURSOR cur_ar_trx_lines (p_trx_header_id NUMBER)
        IS
              SELECT /*+ FIRST_ROWS(10) */
                     *
                FROM xxd_ar_trx_lines_stg_t
               WHERE source_trx_id = p_trx_header_id
            ORDER BY line_type DESC;

        CURSOR cur_get_vat_tax_id (p_tax_regime_code         VARCHAR2,
                                   p_tax                     VARCHAR2,
                                   p_tax_status_code         VARCHAR2,
                                   p_tax_rate_code           VARCHAR2,
                                   p_tax_jurisdiction_code   VARCHAR2)
        IS
            SELECT a.tax_rate_id
              FROM zx_rates_b a
             WHERE     tax_regime_code = p_tax_regime_code
                   AND TAX = p_tax
                   AND TAX_STATUS_CODE = p_tax_status_code
                   AND tax_rate_code = p_tax_rate_code
                   AND NVL (tax_jurisdiction_code, 'Y') =
                       NVL (p_tax_jurisdiction_code, 'Y') --for null jurisdiction code
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (effective_from,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (effective_to,
                                                        SYSDATE));

        CURSOR cur_get_rule_id (p_accounting_rule_name VARCHAR2)
        IS
            SELECT rule_id
              FROM ra_rules
             WHERE name = p_accounting_rule_name;

        --Memo derivation based on Brand for each OU
        --7 Brands * 9 OUs = 63 Unique Memos
        CURSOR cur_memo_line_id (p_brand VARCHAR2, p_org_id NUMBER)
        IS
            SELECT amlab.memo_line_id
              FROM ar_memo_lines_all_tl amlat, ar_memo_lines_all_b amlab, hr_operating_units hou
             WHERE     amlat.memo_line_id = amlab.memo_line_id
                   AND amlat.org_id = hou.organization_id
                   AND amlat.language = USERENV ('LANG')
                   AND amlab.line_type = 'LINE'
                   AND REGEXP_SUBSTR (amlat.name, '[^ ]+', 1,
                                      2) = p_brand
                   AND hou.organization_id = p_org_id;

        CURSOR cur_get_new_warehouse_id (pn_warehouse_id NUMBER)
        IS
            SELECT mp.organization_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                   AND flv.attribute1 = mp.organization_code
                   AND lookup_code = pn_warehouse_id
                   AND language = USERENV ('LANG');

        CURSOR get_open_invoice_status IS
            SELECT open_invoice_status, attribute5 brand, trx_date
              FROM xxd_ar_trx_headers_stg_t
             WHERE source_trx_header_id = p_source_trx_header_id;

        CURSOR cur_get_tax_rate (p_tax_rate_id VARCHAR2, p_trx_date DATE)
        IS
            SELECT percentage_rate
              FROM zx_rates_b
             WHERE     tax_rate_id = p_tax_rate_id
                   AND p_trx_date BETWEEN TRUNC (
                                              NVL (effective_from, SYSDATE))
                                      AND TRUNC (NVL (effective_to, SYSDATE));

        lc_invoice_line_flag       VARCHAR2 (1) := gc_yes_flag;
        lx_final_flag              VARCHAR2 (1) := gc_yes_flag;
        ln_amount_due_remaining    NUMBER;
        ln_inv_item_id             NUMBER;
        ln_tax_id                  NUMBER;
        ln_percentage_rate         NUMBER;
        ln_rule_id                 NUMBER := NULL;
        ln_line_id                 NUMBER := NULL;
        ln_dist_id                 NUMBER := NULL;
        ln_trx_line_id             NUMBER := NULL;
        ln_memo_line_id            NUMBER := NULL;
        ln_link_trx_line_id        NUMBER := NULL;
        ln_line_key                NUMBER := NULL;
        ln_line_prorate_amount     NUMBER := 0;
        ln_dist_key                NUMBER := NULL;
        lc_segments                VARCHAR2 (100) := NULL;
        ln_code_comb_id            NUMBER := NULL;
        ln_dist_prorate_amount     NUMBER := 0;
        lc_concatenated_segments   VARCHAR2 (550);
        lv_new_ord_line_type       VARCHAR2 (300);
        ln_warehouse_id            NUMBER;
        lc_open_invoice_status     VARCHAR2 (100);
        lc_brand                   VARCHAR2 (100);
        ld_trx_date                DATE;
        ln_tax_rate                NUMBER;
    BEGIN
        log_records (gc_debug_flag, 'Calling invoice_line_validation');

        FOR lcur_ar_trx_lines IN cur_ar_trx_lines (p_source_trx_header_id)
        LOOP
            ln_inv_item_id           := NULL;
            ln_tax_id                := NULL;
            ln_percentage_rate       := NULL;
            ln_code_comb_id          := NULL;
            ln_rule_id               := NULL;
            ln_line_id               := NULL;
            ln_dist_id               := NULL;
            ln_trx_line_id           := NULL;
            ln_memo_line_id          := NULL;
            ln_link_trx_line_id      := NULL;
            ln_line_key              := NULL;
            ln_line_prorate_amount   := 0;
            ln_warehouse_id          := NULL;
            lc_open_invoice_status   := NULL;
            lc_brand                 := NULL;
            ld_trx_date              := NULL;
            ln_tax_rate              := NULL;
            log_records (
                gc_debug_flag,
                'Calling validation for lcur_ar_trx_lines.tax_rate_code');
            -- Fetching sequence for line id
            ln_trx_line_id           := ra_customer_trx_lines_s.NEXTVAL;
            ln_line_id               := lcur_ar_trx_lines.source_trx_line_id;
            ln_line_prorate_amount   :=
                  (lcur_ar_trx_lines.amount / p_amount_due_original)
                * p_amount_due_remaining;
            log_records (
                gc_debug_flag,
                   'Calling validation for Ln_line_prorate_amount.=> '
                || ln_line_prorate_amount);

            IF lcur_ar_trx_lines.tax_rate_code IS NOT NULL
            THEN
                OPEN cur_get_vat_tax_id (
                    lcur_ar_trx_lines.tax_regime_code,
                    lcur_ar_trx_lines.tax,
                    lcur_ar_trx_lines.tax_status_code,
                    lcur_ar_trx_lines.tax_rate_code,
                    lcur_ar_trx_lines.tax_jurisdiction_code);

                FETCH cur_get_vat_tax_id INTO ln_tax_id;

                CLOSE cur_get_vat_tax_id;

                IF ln_tax_id IS NULL
                THEN
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Open Invoice Conversion Program',
                        p_error_msg    =>
                               ' Vat tax code '
                            || lcur_ar_trx_lines.tax_rate_code
                            || ' Not found',
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => gc_invoice_number,
                        p_more_info2   => gc_bill_to_customer_name,
                        p_more_info3   => lcur_ar_trx_lines.tax_rate_code,
                        p_more_info4   => lcur_ar_trx_lines.source_trx_line_id);
                    lc_invoice_line_flag   := gc_no_flag;
                END IF;
            END IF;

            IF lcur_ar_trx_lines.accounting_rule_name IS NOT NULL
            THEN
                OPEN cur_get_rule_id (lcur_ar_trx_lines.accounting_rule_name);

                FETCH cur_get_rule_id INTO ln_rule_id;

                CLOSE cur_get_rule_id;

                IF ln_rule_id IS NULL
                THEN
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Open Invoice Conversion Program',
                        p_error_msg    =>
                               ' Rule name'
                            || lcur_ar_trx_lines.accounting_rule_name
                            || ' Not found',
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => gc_invoice_number,
                        p_more_info2   => gc_bill_to_customer_name,
                        p_more_info3   =>
                            lcur_ar_trx_lines.accounting_rule_name,
                        p_more_info4   => lcur_ar_trx_lines.source_trx_line_id);
                    lc_invoice_line_flag   := gc_no_flag;
                END IF;
            END IF;

            --Get details from Invoice Header
            OPEN get_open_invoice_status;

            FETCH get_open_invoice_status INTO lc_open_invoice_status, lc_brand, ld_trx_date;

            CLOSE get_open_invoice_status;

            --Auto Accounting for Partial Invoices
            IF           -- Start changes by BT Technology Team on 09 Aug 2015
                                          --lc_open_invoice_status = 'PARTIAL'
                 lcur_ar_trx_lines.inventory_item_id IS NULL -- End changes by BT Technology Team on 09 Aug 2015
             AND lcur_ar_trx_lines.line_type = 'LINE'
            THEN
                OPEN cur_memo_line_id (lc_brand,
                                       lcur_ar_trx_lines.destination_org_id);

                FETCH cur_memo_line_id INTO ln_memo_line_id;

                CLOSE cur_memo_line_id;
            ELSE
                ln_memo_line_id   := NULL;
            END IF;

            --In case of Percentage Rate differences between 1206 and BT
            IF ln_tax_id IS NOT NULL
            THEN
                OPEN cur_get_tax_rate (ln_tax_id, ld_trx_date);

                FETCH cur_get_tax_rate INTO ln_percentage_rate;

                CLOSE cur_get_tax_rate;

                log_records (
                    gc_debug_flag,
                    'ln_percentage_rate is --> ' || ln_percentage_rate);
                log_records (
                    gc_debug_flag,
                       'lcur_ar_trx_lines.tax_rate  ----------> '
                    || lcur_ar_trx_lines.tax_rate);

                IF lcur_ar_trx_lines.tax_rate <> ln_percentage_rate
                THEN
                    ln_tax_rate   := ln_percentage_rate;
                END IF;
            END IF;

            IF lcur_ar_trx_lines.warehouse_id IS NOT NULL
            THEN
                OPEN cur_get_new_warehouse_id (
                    lcur_ar_trx_lines.warehouse_id);

                FETCH cur_get_new_warehouse_id INTO ln_warehouse_id;

                CLOSE cur_get_new_warehouse_id;

                IF ln_warehouse_id IS NULL
                THEN
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Open Invoice Conversion Program',
                        p_error_msg    =>
                               ' WareHouse ID not found in the Mapping. Please check in the lookup XXD_1206_INV_ORG_MAPPING'
                            || lcur_ar_trx_lines.warehouse_id
                            || ' Not found',
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => gc_invoice_number,
                        p_more_info2   => gc_bill_to_customer_name,
                        p_more_info3   => lcur_ar_trx_lines.warehouse_id,
                        p_more_info4   => lcur_ar_trx_lines.source_trx_line_id);
                    lc_invoice_line_flag   := gc_no_flag;
                END IF;
            END IF;

            IF lc_invoice_line_flag = gc_no_flag
            THEN
                lx_final_flag   := gc_no_flag;
            END IF;

            log_records (
                gc_debug_flag,
                'validate lc_invoice_line_flag ' || lc_invoice_line_flag);
            log_records (
                gc_debug_flag,
                   'validate p_source_trx_header_id =>'
                || p_source_trx_header_id);
            log_records (
                gc_debug_flag,
                   'validate lcur_ar_trx_lines.source_trx_line_id =>'
                || lcur_ar_trx_lines.source_trx_line_id);

            IF lc_invoice_line_flag = gc_yes_flag
            THEN
                UPDATE xxd_ar_trx_lines_stg_t
                   SET vat_tax_id = ln_tax_id, record_status = gc_validate_status, trx_header_id = px_trx_header_id,
                       trx_line_id = ln_trx_line_id, memo_line_id = ln_memo_line_id, accounting_rule_id = ln_rule_id,
                       warehouse_id = ln_warehouse_id, interface_line_attribute10 = NVL2 (interface_line_attribute10, ln_warehouse_id, NULL), tax_rate = NVL (ln_tax_rate, tax_rate) --added one NVL conditionon 12 Aug 2015
                 WHERE     source_trx_id = p_source_trx_header_id
                       AND source_trx_line_id =
                           lcur_ar_trx_lines.source_trx_line_id;
            ELSE
                UPDATE xxd_ar_trx_lines_stg_t
                   SET vat_tax_id = ln_tax_id, record_status = gc_error_status, trx_header_id = px_trx_header_id,
                       trx_line_id = ln_trx_line_id, memo_line_id = ln_memo_line_id, accounting_rule_id = ln_rule_id,
                       warehouse_id = ln_warehouse_id, interface_line_attribute10 = NVL2 (interface_line_attribute10, ln_warehouse_id, NULL), tax_rate = ln_tax_rate
                 WHERE     source_trx_id = p_source_trx_header_id
                       AND source_trx_line_id =
                           lcur_ar_trx_lines.source_trx_line_id;
            END IF;

            COMMIT;

            IF lcur_ar_trx_lines.line_type = 'LINE'
            THEN
                BEGIN
                    log_records (gc_debug_flag,
                                 'px_trx_header_id -' || px_trx_header_id);
                    log_records (
                        gc_debug_flag,
                        'source_trx_line_id -' || lcur_ar_trx_lines.source_trx_line_id);
                    log_records (gc_debug_flag,
                                 'ln_trx_line_id -' || ln_trx_line_id);
                    log_records (
                        gc_debug_flag,
                        'line_number -' || lcur_ar_trx_lines.line_number);
                    log_records (
                        gc_debug_flag,
                        'VAT_TAX_ID -' || lcur_ar_trx_lines.vat_tax_id);

                    UPDATE xxd_ar_trx_lines_stg_t
                       SET line_number = lcur_ar_trx_lines.line_number, link_to_trx_line_id = ln_trx_line_id, --Start changes on 15 Aug 15
                                                                                                              --                      tax_regime_code = lcur_ar_trx_lines.tax_regime_code,
                                                                                                              --                      tax = lcur_ar_trx_lines.tax,
                                                                                                              --                      tax_status_code = lcur_ar_trx_lines.tax_status_code,
                                                                                                              --                      tax_rate_code = lcur_ar_trx_lines.tax_rate_code,
                                                                                                              --                      tax_jurisdiction_code =
                                                                                                              --                         lcur_ar_trx_lines.tax_jurisdiction_code,
                                                                                                              -- End Changes on 15 Aug 15
                                                                                                              vat_tax_id = ln_tax_id --lcur_ar_trx_lines.vat_tax_id
                     WHERE     line_type = 'TAX'
                           AND link_to_trx_line_id =
                               lcur_ar_trx_lines.source_trx_line_id
                           AND trx_header_id = px_trx_header_id;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        log_records (
                            gc_debug_flag,
                               'Exception Occured at Link to Line ID -'
                            || SQLERRM);
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Open Invoice Conversion Program',
                            p_error_msg    =>
                                   ' Error While updating TAX Line Tax Details '
                                || lcur_ar_trx_lines.trx_line_id
                                || ' Not found',
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => gc_invoice_number,
                            p_more_info2   => gc_bill_to_customer_name,
                            p_more_info3   =>
                                lcur_ar_trx_lines.source_trx_line_id,
                            p_more_info4   => p_source_trx_header_id);
                END;
            END IF;
        END LOOP;

        COMMIT;

        RETURN lx_final_flag;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            log_records (gc_debug_flag, 'validate lx_final_flag ' || SQLERRM);
            RETURN gc_no_flag;
        WHEN OTHERS
        THEN
            log_records (gc_debug_flag, 'validate lx_final_flag ' || SQLERRM);
            RETURN gc_no_flag;
    END invoice_line_validation;

    /******************************************************************************************
      *  Procedure Name :   invoice_validation                                                *
      *                                                                                       *
      *  Description    :   Procedure to validate the invoice  in the stag                    *
      *                                                                                       *
      *                                                                                       *
      *  Called From    :   Concurrent Program                                                *
      *                                                                                       *
      *  Parameters             Type       Description                                        *
      *  -----------------------------------------------------------------------------        *
      *  errbuf                  OUT       Standard errbuf                                    *
      *  retcode                 OUT       Standard retcode                                   *
      *  p_batch_id               IN       Batch Number to fetch the data from header stage   *
      *  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
      *                                                                                       *
      * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
      *                                                                                       *
      *****************************************************************************************/
    PROCEDURE invoice_validation (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_action IN VARCHAR2, p_org_name IN VARCHAR2, p_batch_id IN NUMBER, pv_from_trx_no IN VARCHAR2
                                  , pv_to_trx_no IN VARCHAR2)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lc_status                  VARCHAR2 (20);

        CURSOR cur_invoice (p_batch_id        NUMBER,
                            p_action          VARCHAR2,
                            p_target_org_id   NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_trx_headers_stg_t cust
             WHERE     record_status IN (p_action, gc_error_status)
                   AND batch_number = p_batch_id
                   AND destination_org_id = p_target_org_id
                   --Start changes 16 Aug 15
                   --                AND trx_number BETWEEN NVL (TO_NUMBER (pv_from_trx_no),
                   --                                            trx_number)
                   --                                   AND NVL (TO_NUMBER (pv_to_trx_no),
                   --                                            trx_number);
                   AND trx_number BETWEEN NVL (TO_CHAR (pv_from_trx_no),
                                               trx_number)
                                      AND NVL (TO_CHAR (pv_to_trx_no),
                                               trx_number);

        --End Changes 16 Aug 15

        -----------R11 Customer Details Starts------------
        CURSOR cur_get_customer_id (p_cust_acct_id NUMBER)
        IS
            SELECT cust_account_id
              FROM hz_cust_accounts hca
             WHERE hca.orig_system_reference = TO_CHAR (p_cust_acct_id);

        CURSOR cur_get_customer_brand_id (p_cust_acct_id   NUMBER,
                                          p_brad           VARCHAR2)
        IS
            SELECT hca.cust_account_id
              FROM hz_cust_acct_relate_all hcar, hz_cust_accounts_all hca
             WHERE     hca.cust_account_id = hcar.cust_account_id
                   AND related_cust_account_id = TO_CHAR (p_cust_acct_id)
                   AND hca.attribute1 = p_brad;

        --to get ship to
        CURSOR cur_get_cust_site_id (p_cust_acct_id NUMBER, p_cust_site_use_id NUMBER, p_target_org_id NUMBER)
        IS
            SELECT hcas.cust_acct_site_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca.orig_system_reference = TO_CHAR (p_cust_acct_id)
                   AND hcsu.orig_system_reference =
                       TO_CHAR (p_cust_site_use_id)
                   AND hcas.org_id = p_target_org_id;

        --to get bill to
        CURSOR cur_get_cust_site_brand_id (p_cust_acct_id NUMBER, p_cust_site_use_id NUMBER, p_target_org_id NUMBER
                                           , p_brand VARCHAR2)
        IS
            SELECT hcas.cust_acct_site_id
              FROM hz_cust_accounts_all hca, hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu,
                   hz_cust_acct_relate_all hcar
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca.cust_account_id = hcar.cust_account_id
                   AND hcar.related_cust_account_id =
                       TO_CHAR (p_cust_acct_id)
                   AND hcas.org_id = p_target_org_id
                   AND hca.attribute1 = p_brand;

        CURSOR cur_get_cust_brand_id (p_cust_acct_id   NUMBER,
                                      p_brand          VARCHAR2)
        IS
            SELECT cust_account_id
              FROM hz_cust_accounts hca
             WHERE hca.orig_system_reference =
                   TO_CHAR (p_cust_acct_id) || '-' || p_brand;

        --to get ship to (should pass legacy cust account id)
        CURSOR cur_get_ship_to_site_id (p_cust_acct_id       NUMBER,
                                        p_cust_site_use_id   NUMBER)
        IS
            SELECT hcsa.cust_acct_site_id
              FROM hz_cust_acct_sites_all hcsa, hz_cust_site_uses_all hcsu
             WHERE     hcsa.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_code = 'SHIP_TO'
                   AND hcsa.cust_account_id = TO_CHAR (p_cust_acct_id)
                   AND hcsu.orig_system_reference = p_cust_site_use_id;

        CURSOR cur_get_ship_to_site_use_id (p_site_id NUMBER)
        IS
            SELECT site_use_id
              FROM hz_cust_site_uses_all
             WHERE     cust_acct_site_id = p_site_id
                   AND site_use_code = 'SHIP_TO';

        --to get bill to site id
        CURSOR cur_get_bill_to_site_id (p_cust_acct_id NUMBER, p_cust_site_use_id NUMBER, p_brand VARCHAR2)
        IS
            SELECT hcsa.cust_acct_site_id
              FROM hz_cust_acct_sites_all hcsa, hz_cust_site_uses_all hcsu
             WHERE     hcsa.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hcsa.cust_account_id = TO_CHAR (p_cust_acct_id)
                   AND hcsu.orig_system_reference =
                       p_cust_site_use_id || '-' || p_brand;

        --to get bill to site use id
        CURSOR cur_get_bill_to_site_use_id (p_cust_site_id NUMBER)
        IS
            SELECT hcsu.site_use_id
              FROM hz_cust_site_uses_all hcsu
             WHERE hcsu.cust_acct_site_id = p_cust_site_id;

        CURSOR cur_get_cust_site_id2 (p_cust_acct_id    NUMBER,
                                      p_target_org_id   NUMBER)
        IS
            SELECT hcas.cust_acct_site_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca.orig_system_reference = TO_CHAR (p_cust_acct_id)
                   AND hcas.org_id = p_target_org_id;

        CURSOR cur_get_cust_site_brand_id2 (p_cust_acct_id NUMBER, p_target_org_id NUMBER, p_brand VARCHAR2)
        IS
            SELECT hcas.cust_acct_site_id
              FROM hz_cust_accounts_all hca, hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu,
                   hz_cust_acct_relate_all hcar
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca.cust_account_id = hcar.cust_account_id
                   AND hcar.related_cust_account_id =
                       TO_CHAR (p_cust_acct_id)
                   AND hcas.org_id = p_target_org_id
                   AND hca.attribute1 = p_brand;

        CURSOR cur_get_cust_site_use_id (p_cust_site_use_id   NUMBER,
                                         p_target_org_id      NUMBER)
        IS
            SELECT hcsu.site_use_id
              FROM hz_cust_site_uses_all hcsu
             WHERE     hcsu.orig_system_reference =
                       TO_CHAR (p_cust_site_use_id)
                   AND hcsu.org_id = p_target_org_id;

        CURSOR cur_get_site_use_brand_id (p_target_org_id NUMBER, p_brand VARCHAR2, p_bill_to_cust_id NUMBER)
        IS
            SELECT hcsu.site_use_id
              FROM hz_cust_site_uses_all hcsu, hz_cust_accounts hca, hz_cust_acct_sites_all hcas
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hca.cust_account_id = p_bill_to_cust_id
                   AND hcsu.org_id = p_target_org_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca.attribute1 = p_brand;

        CURSOR cur_get_cust_site_use_id2 (p_cust_acct_id    NUMBER,
                                          p_target_org_id   NUMBER)
        IS
            SELECT hcsu.site_use_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca.orig_system_reference = TO_CHAR (p_cust_acct_id)
                   AND hcas.org_id = p_target_org_id;

        CURSOR cur_get_cust_site_cont_id (p_contact_id NUMBER)
        IS
            SELECT cust_account_role_id
              FROM hz_cust_account_roles hcar
             WHERE hcar.orig_system_reference = TO_CHAR (p_contact_id);

        CURSOR cur_get_salesrepname_id (p_salerep_number   VARCHAR2,
                                        p_target_org_id    NUMBER)
        IS
            SELECT salesrep_id
              FROM ra_salesreps_all
             WHERE     salesrep_number = p_salerep_number
                   AND org_id = p_target_org_id;

        --Added billing_cycle_id column to this cursor
        CURSOR cur_get_terms_id (p_terms_name VARCHAR2)
        IS
            SELECT rt.term_id, billing_cycle_id
              FROM ra_terms rt, xxd_1206_payment_term_map_t xrt
             WHERE     rt.name = xrt.new_term_name
                   AND NVL (old_term_name, 'V') = NVL (p_terms_name, 'V');

        CURSOR cur_get_receipt_method_id (p_receipt_method VARCHAR2)
        IS
            SELECT receipt_method_id
              FROM ar_receipt_methods
             WHERE name = p_receipt_method;

        /*CURSOR cur_get_outstanding_amount1 (
           p_customer_trx_id NUMBER)
        IS
           SELECT SUM (amount_due_original),
                  SUM (amount_due_remaining),
                  SUM (amount_applied)
             FROM ar_payment_schedules_all@bt_read_1206
            WHERE customer_trx_id = p_customer_trx_id;*/

        CURSOR cur_get_transaction_type (p_cust_trx_type_name VARCHAR2, p_trx_class VARCHAR2, p_source_name VARCHAR2
                                         , p_org_id NUMBER)
        IS
            SELECT cust_trx_type_id, rctt.name
              FROM ra_cust_trx_types_all rctt, xxd_ar_trx_src_mapping_t map
             WHERE     rctt.name = map.new_cust_trx_type_name
                   AND map.cust_trx_type_name = p_cust_trx_type_name
                   AND rctt.TYPE = map.trx_class
                   AND rctt.TYPE = p_trx_class
                   AND map.batch_source_name = p_source_name
                   AND org_id = p_org_id;

        CURSOR cur_get_source_name (p_source_name   VARCHAR2,
                                    p_org_id        NUMBER,
                                    p_trx_class     VARCHAR2)
        IS
            SELECT name
              FROM ra_batch_sources_all batches, xxd_ar_trx_src_mapping_t map
             WHERE     batches.name = map.new_batch_source_name
                   AND map.batch_source_name = p_source_name
                   AND org_id = p_org_id
                   AND trx_class = p_trx_class;

        CURSOR cur_get_remit_add (p_org_id NUMBER)
        IS
            SELECT acctsites.cust_acct_site_id
              FROM hz_party_sites sites, hz_cust_acct_sites_all acctsites, hz_locations loc,
                   hr_operating_units hr
             WHERE     sites.party_id = -1
                   AND acctsites.cust_account_id = -1
                   AND sites.party_site_id = acctsites.party_site_id
                   AND sites.location_id = loc.location_id
                   AND hr.organization_id = acctsites.org_id
                   AND acctsites.status = 'A'
                   AND organization_id = p_org_id;

        CURSOR cur_get_inv_rule_id (p_inv_rule_name VARCHAR2)
        IS
            SELECT rule_id
              FROM ra_rules
             WHERE name = p_inv_rule_name;

        CURSOR cur_check_dup_inv (pv_trx_number        VARCHAR2,
                                  pn_org_id            NUMBER,
                                  pn_cust_trx_typ_id   NUMBER)
        IS
            SELECT trx_number
              FROM ra_customer_trx_all
             WHERE     trx_number = pv_trx_number
                   AND org_id = pn_org_id
                   AND cust_trx_type_id = pn_cust_trx_typ_id;

        CURSOR get_new_ship_method_c (p_ship_via VARCHAR2, p_org_id NUMBER)
        IS
            SELECT wcv.freight_code
              FROM xxd_1206_ship_methods_map_t xsmap, wsh_carriers_v wcv, wsh_carrier_services_v wcsv,
                   wsh_org_carrier_services_v wocsv
             WHERE     xsmap.new_ship_method_code = wcsv.ship_method_code
                   AND wcv.carrier_id = wcsv.carrier_id
                   AND wocsv.carrier_service_id = wcsv.carrier_service_id
                   AND wcsv.enabled_flag = 'Y'
                   AND wocsv.enabled_flag = 'Y'
                   AND wcsv.ship_method_code = xsmap.new_ship_method_code
                   AND wocsv.organization_id = p_org_id
                   AND old_ship_method_code = p_ship_via;

        lc_invoicel_flag           VARCHAR2 (1) := gc_yes_flag;
        lc_invoice_line_flag       VARCHAR2 (1) := gc_yes_flag;
        lc_invoice_dis_flag        VARCHAR2 (1) := gc_yes_flag;
        ln_count                   NUMBER := 0;
        l_target_org_id            NUMBER := 0;
        ln_amount_due_original     NUMBER;
        ln_amount_due_remaining    NUMBER;
        ln_amount_applied          NUMBER;
        lx_trx_header_id           NUMBER;
        ln_cust_trx_type_id        NUMBER;
        ln_bill_to_customer_id     NUMBER;
        ln_ship_to_customer_id     NUMBER;
        ln_sold_to_customer_id     NUMBER;
        ln_bill_to_site_id         NUMBER;
        ln_ship_to_site_id         NUMBER;
        ln_bill_to_site_use_id     NUMBER;
        ln_ship_to_site_use_id     NUMBER;
        ln_bill_to_contact_id      NUMBER;
        ln_ship_to_contact_id      NUMBER;
        ln_primary_salesrep_id     NUMBER;
        ln_term_id                 NUMBER;
        ln_bill_cycle_id           NUMBER;
        ln_receipt_method_id       NUMBER;
        ln_trx_header_id           NUMBER;
        ln_invoice_rule_id         NUMBER;
        ln_dist_key                NUMBER := NULL;
        ln_dist_id                 NUMBER := NULL;
        lc_segments                VARCHAR2 (100) := NULL;
        ln_code_comb_id            NUMBER := NULL;
        ln_dist_prorate_amount     NUMBER := 0;
        lc_concatenated_segments   VARCHAR2 (550) := NULL;
        lc_source_name             VARCHAR2 (100) := NULL;
        lc_cust_trx_type           VARCHAR2 (100) := NULL;
        lv_new_ord_type            VARCHAR2 (500);
        ln_remit_to_address_id     NUMBER;
        lv_dup_trx_number          VARCHAR2 (200);
        lc_ship_via                VARCHAR2 (200);

        TYPE lt_cur_invoice_typ IS TABLE OF cur_invoice%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_inv_data                lt_cur_invoice_typ;
    BEGIN
        retcode           := NULL;
        errbuf            := NULL;
        log_records (
            gc_debug_flag,
            'validate invoice_validation  p_action =.  ' || p_action);
        l_target_org_id   := get_targetorg_id (p_org_name => p_org_name);

        OPEN cur_invoice (p_batch_id        => p_batch_id,
                          p_action          => p_action,
                          p_target_org_id   => l_target_org_id);

        LOOP
            FETCH cur_invoice BULK COLLECT INTO lt_inv_data LIMIT 100;

            log_records (gc_debug_flag,
                         'validate invoice_validation ' || lt_inv_data.COUNT);
            EXIT WHEN lt_inv_data.COUNT = 0;
            lc_source_name   := NULL;

            IF lt_inv_data.COUNT > 0
            THEN
                FOR xc_inv_rec IN lt_inv_data.FIRST .. lt_inv_data.LAST
                LOOP
                    lc_invoicel_flag                                 := gc_yes_flag;
                    lc_invoice_dis_flag                              := gc_yes_flag;
                    ln_dist_id                                       := NULL;
                    ln_cust_trx_type_id                              := NULL;
                    ln_ship_to_customer_id                           := NULL;
                    ln_sold_to_customer_id                           := NULL;
                    ln_bill_to_customer_id                           := NULL;
                    ln_ship_to_site_id                               := NULL;
                    ln_bill_to_site_use_id                           := NULL;
                    ln_invoice_rule_id                               := NULL;
                    ln_ship_to_site_use_id                           := NULL;
                    ln_bill_to_contact_id                            := NULL;
                    ln_ship_to_contact_id                            := NULL;
                    ln_primary_salesrep_id                           := NULL;
                    ln_term_id                                       := NULL;
                    ln_receipt_method_id                             := NULL;
                    ln_remit_to_address_id                           := NULL;
                    gc_bill_to_customer_name                         :=
                        lt_inv_data (xc_inv_rec).bill_to_customer_name;
                    gc_invoice_number                                :=
                        lt_inv_data (xc_inv_rec).trx_number;
                    gn_org_id                                        := l_target_org_id;
                    lx_trx_header_id                                 := ra_customer_trx_s.NEXTVAL;
                    lv_dup_trx_number                                := NULL;

                    /*IF lt_inv_data (xc_inv_rec).source_trx_header_id IS NOT NULL
                    THEN
                       OPEN cur_get_outstanding_amount1 (lt_inv_data (xc_inv_rec).source_trx_header_id);

                       FETCH cur_get_outstanding_amount1
                       INTO ln_amount_due_original,
                            ln_amount_due_remaining,
                            ln_amount_applied;

                       CLOSE cur_get_outstanding_amount1;

                       log_records (
                          'Y',
                             'ln_amount_due_original:'
                          || ln_amount_due_original
                          || 'ln_amount_due_remaining:'
                          || ln_amount_due_remaining
                          || 'ln_amount_applied:'
                          || ln_amount_applied);
                    END IF;*/

                    log_records ('Y', 'BEGIN');

                    IF lt_inv_data (xc_inv_rec).batch_source_name IS NOT NULL
                    THEN
                        log_records ('Y', 'BEGIN1');

                        OPEN cur_get_source_name (
                            p_source_name   =>
                                lt_inv_data (xc_inv_rec).batch_source_name,
                            p_org_id   =>
                                lt_inv_data (xc_inv_rec).destination_org_id,
                            p_trx_class   =>
                                lt_inv_data (xc_inv_rec).trx_class);

                        FETCH cur_get_source_name INTO lc_source_name;

                        CLOSE cur_get_source_name;

                        IF lc_source_name IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       ' Batch Source Name '
                                    || lt_inv_data (xc_inv_rec).batch_source_name
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).batch_source_name,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    lt_inv_data (xc_inv_rec).new_batch_source_name   :=
                        lc_source_name;
                    log_records ('Y', 'lc_source_name' || lc_source_name);

                    IF lt_inv_data (xc_inv_rec).cust_trx_type_name
                           IS NOT NULL
                    THEN
                        OPEN cur_get_transaction_type (
                            p_cust_trx_type_name   =>
                                lt_inv_data (xc_inv_rec).cust_trx_type_name,
                            p_trx_class   =>
                                lt_inv_data (xc_inv_rec).trx_class,
                            p_source_name   =>
                                lt_inv_data (xc_inv_rec).batch_source_name,
                            p_org_id   =>
                                lt_inv_data (xc_inv_rec).destination_org_id);

                        FETCH cur_get_transaction_type
                            INTO ln_cust_trx_type_id, lc_cust_trx_type;

                        CLOSE cur_get_transaction_type;

                        IF ln_cust_trx_type_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       ' CUST TRX TYPE NAME to Customer '
                                    || lt_inv_data (xc_inv_rec).cust_trx_type_name
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).cust_trx_type_name,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    IF ln_cust_trx_type_id IS NOT NULL
                    THEN
                        OPEN cur_check_dup_inv (
                            pv_trx_number        =>
                                lt_inv_data (xc_inv_rec).trx_number,
                            pn_org_id            => gn_org_id,
                            pn_cust_trx_typ_id   => ln_cust_trx_type_id);

                        FETCH cur_check_dup_inv INTO lv_dup_trx_number;

                        CLOSE cur_check_dup_inv;

                        IF lv_dup_trx_number IS NOT NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                    'Transaction Number Already Exist in the system',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   => lv_dup_trx_number,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    log_records ('Y', 'begin');

                    IF lt_inv_data (xc_inv_rec).destination_org_id
                           IS NOT NULL
                    THEN
                        OPEN cur_get_remit_add (
                            p_org_id   =>
                                lt_inv_data (xc_inv_rec).destination_org_id);

                        FETCH cur_get_remit_add INTO ln_remit_to_address_id;

                        CLOSE cur_get_remit_add;

                        IF ln_remit_to_address_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       'Remit to address for org '
                                    || lt_inv_data (xc_inv_rec).destination_org_id
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).destination_org_id,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    IF lt_inv_data (xc_inv_rec).invoicing_rule_name
                           IS NOT NULL
                    THEN
                        OPEN cur_get_inv_rule_id (
                            lt_inv_data (xc_inv_rec).invoicing_rule_name);

                        FETCH cur_get_inv_rule_id INTO ln_invoice_rule_id;

                        CLOSE cur_get_inv_rule_id;

                        IF ln_invoice_rule_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       'Invoicing Rule ID is not found '
                                    || lt_inv_data (xc_inv_rec).invoicing_rule_name
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).invoicing_rule_name,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    log_records ('Y', 'begin');

                    IF lt_inv_data (xc_inv_rec).customer_website IS NOT NULL
                    THEN
                        IF lt_inv_data (xc_inv_rec).old_bill_to_customer_id
                               IS NOT NULL
                        THEN
                            OPEN cur_get_customer_id (
                                lt_inv_data (xc_inv_rec).old_bill_to_customer_id);

                            FETCH cur_get_customer_id
                                INTO ln_bill_to_customer_id;

                            CLOSE cur_get_customer_id;

                            IF ln_bill_to_customer_id IS NULL
                            THEN
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Open Invoice Conversion Program',
                                    p_error_msg    =>
                                           ' Bill to Customer '
                                        || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                        || ' Not found',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => gc_invoice_number,
                                    p_more_info2   => gc_bill_to_customer_name,
                                    p_more_info3   => NULL,
                                    p_more_info4   => NULL);
                                lc_invoicel_flag   := gc_no_flag;
                            END IF;
                        END IF;

                        log_records ('Y', 'begin1a');

                        IF lt_inv_data (xc_inv_rec).old_sold_to_customer_id
                               IS NOT NULL
                        THEN
                            OPEN cur_get_customer_id (
                                lt_inv_data (xc_inv_rec).old_sold_to_customer_id);

                            FETCH cur_get_customer_id
                                INTO ln_sold_to_customer_id;

                            CLOSE cur_get_customer_id;

                            IF ln_sold_to_customer_id IS NULL
                            THEN
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Open Invoice Conversion Program',
                                    p_error_msg    =>
                                           ' Sold to Customer  '
                                        || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                        || ' Not found',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => gc_invoice_number,
                                    p_more_info2   => gc_bill_to_customer_name,
                                    p_more_info3   => NULL,
                                    p_more_info4   => NULL);
                                lc_invoicel_flag   := gc_no_flag;
                            END IF;
                        END IF;

                        log_records ('Y', 'begin1aa');

                        --cursor to validate bill_to_address_id
                        IF     lt_inv_data (xc_inv_rec).bill_to_customer_id
                                   IS NOT NULL
                           AND lt_inv_data (xc_inv_rec).bill_to_site_use_id
                                   IS NOT NULL
                        THEN
                            OPEN cur_get_cust_site_id (
                                lt_inv_data (xc_inv_rec).old_bill_to_customer_id,
                                lt_inv_data (xc_inv_rec).old_bill_to_site_use_id,
                                p_target_org_id   => l_target_org_id);

                            FETCH cur_get_cust_site_id
                                INTO ln_bill_to_site_use_id;

                            CLOSE cur_get_cust_site_id;

                            IF ln_bill_to_site_use_id IS NULL
                            THEN
                                OPEN cur_get_cust_site_id2 (
                                    lt_inv_data (xc_inv_rec).old_bill_to_customer_id,
                                    p_target_org_id   => l_target_org_id);

                                FETCH cur_get_cust_site_id2
                                    INTO ln_bill_to_site_use_id;

                                CLOSE cur_get_cust_site_id2;

                                IF ln_bill_to_site_use_id IS NULL
                                THEN
                                    xxd_common_utils.record_error (
                                        p_module       => 'AR',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers AR Open Invoice Conversion Program',
                                        p_error_msg    =>
                                               ' Bill to Customer Address  '
                                            || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                            || ' Not found',
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   => gc_invoice_number,
                                        p_more_info2   =>
                                            gc_bill_to_customer_name,
                                        p_more_info3   =>
                                            lt_inv_data (xc_inv_rec).bill_to_customer_id,
                                        p_more_info4   =>
                                            lt_inv_data (xc_inv_rec).old_bill_to_site_use_id);
                                    lc_invoicel_flag   := gc_no_flag;
                                END IF;
                            END IF;
                        END IF;

                        log_records (
                            'Y',
                               'here1bill'
                            || lt_inv_data (xc_inv_rec).old_bill_to_site_use_id);

                        --cursor to validate customer site use
                        IF lt_inv_data (xc_inv_rec).old_bill_to_site_use_id
                               IS NOT NULL
                        THEN
                            OPEN cur_get_cust_site_use_id (
                                lt_inv_data (xc_inv_rec).old_bill_to_site_use_id,
                                p_target_org_id   => l_target_org_id);

                            FETCH cur_get_cust_site_use_id
                                INTO ln_bill_to_site_use_id;

                            CLOSE cur_get_cust_site_use_id;

                            IF ln_bill_to_site_use_id IS NULL
                            THEN
                                OPEN cur_get_cust_site_use_id2 (
                                    lt_inv_data (xc_inv_rec).bill_to_customer_id,
                                    p_target_org_id   => l_target_org_id);

                                FETCH cur_get_cust_site_use_id2
                                    INTO ln_bill_to_site_use_id;

                                CLOSE cur_get_cust_site_use_id2;

                                log_records (
                                    'Y',
                                    'here1bill1' || ln_bill_to_site_use_id);

                                IF ln_bill_to_site_use_id IS NULL
                                THEN
                                    xxd_common_utils.record_error (
                                        p_module       => 'AR',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers AR Open Invoice Conversion Program',
                                        p_error_msg    =>
                                               ' bill to site use id not found  '
                                            || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                            || ' Not found',
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   => gc_invoice_number,
                                        p_more_info2   =>
                                            gc_bill_to_customer_name,
                                        p_more_info3   =>
                                            lt_inv_data (xc_inv_rec).old_bill_to_site_use_id,
                                        p_more_info4   => NULL);
                                    lc_invoicel_flag   := gc_no_flag;
                                END IF;
                            END IF;
                        END IF;

                        log_records (
                            'Y',
                               'here1a'
                            || lt_inv_data (xc_inv_rec).old_ship_to_site_use_id);
                        log_records ('Y', 'here1a' || ln_ship_to_site_use_id);

                        IF lt_inv_data (xc_inv_rec).old_ship_to_site_use_id
                               IS NOT NULL
                        THEN
                            log_records ('Y',
                                         'here1ab' || ln_ship_to_site_use_id);

                            OPEN cur_get_cust_site_use_id (
                                lt_inv_data (xc_inv_rec).old_ship_to_site_use_id,
                                p_target_org_id   => l_target_org_id);

                            FETCH cur_get_cust_site_use_id
                                INTO ln_ship_to_site_use_id;

                            CLOSE cur_get_cust_site_use_id;

                            log_records ('Y',
                                         'here1' || ln_ship_to_site_use_id);

                            IF ln_ship_to_site_use_id IS NULL
                            THEN
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Open Invoice Conversion Program',
                                    p_error_msg    =>
                                           ' ship to site use id not found  '
                                        || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                        || ' Not found',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => gc_invoice_number,
                                    p_more_info2   => gc_bill_to_customer_name,
                                    p_more_info3   =>
                                        lt_inv_data (xc_inv_rec).old_ship_to_site_use_id,
                                    p_more_info4   => NULL);
                                lc_invoicel_flag   := gc_no_flag;

                                OPEN cur_get_cust_site_use_id2 (
                                    lt_inv_data (xc_inv_rec).ship_to_customer_id,
                                    p_target_org_id   => l_target_org_id);

                                FETCH cur_get_cust_site_use_id2
                                    INTO ln_ship_to_site_use_id;

                                CLOSE cur_get_cust_site_use_id2;

                                log_records (
                                    'Y',
                                    'here2' || ln_ship_to_site_use_id);

                                IF ln_ship_to_site_use_id IS NULL
                                THEN
                                    xxd_common_utils.record_error (
                                        p_module       => 'AR',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers AR Open Invoice Conversion Program',
                                        p_error_msg    =>
                                               ' ship to site use id not found  '
                                            || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                            || ' Not found',
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   => gc_invoice_number,
                                        p_more_info2   =>
                                            gc_bill_to_customer_name,
                                        p_more_info3   =>
                                            lt_inv_data (xc_inv_rec).old_ship_to_site_use_id,
                                        p_more_info4   => NULL);
                                    lc_invoicel_flag   := gc_no_flag;
                                END IF;
                            END IF;
                        END IF;
                    ELSE
                        IF lt_inv_data (xc_inv_rec).old_bill_to_customer_id
                               IS NOT NULL
                        THEN
                            OPEN cur_get_cust_brand_id (
                                lt_inv_data (xc_inv_rec).old_bill_to_customer_id,
                                lt_inv_data (xc_inv_rec).attribute5);

                            FETCH cur_get_cust_brand_id
                                INTO ln_bill_to_customer_id;

                            CLOSE cur_get_cust_brand_id;

                            IF ln_bill_to_customer_id IS NULL
                            THEN
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Open Invoice Conversion Program',
                                    p_error_msg    =>
                                           ' Bill to Customer '
                                        || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                        || ' Not found',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => gc_invoice_number,
                                    p_more_info2   => gc_bill_to_customer_name,
                                    p_more_info3   => NULL,
                                    p_more_info4   => NULL);
                                lc_invoicel_flag   := gc_no_flag;
                            END IF;
                        END IF;

                        IF lt_inv_data (xc_inv_rec).old_sold_to_customer_id
                               IS NOT NULL
                        THEN
                            OPEN cur_get_customer_brand_id (
                                lt_inv_data (xc_inv_rec).old_sold_to_customer_id,
                                lt_inv_data (xc_inv_rec).attribute5);

                            FETCH cur_get_customer_brand_id
                                INTO ln_sold_to_customer_id;

                            CLOSE cur_get_customer_brand_id;

                            IF ln_sold_to_customer_id IS NULL
                            THEN
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Open Invoice Conversion Program',
                                    p_error_msg    =>
                                           ' Sold to Customer  '
                                        || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                        || ' Not found',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => gc_invoice_number,
                                    p_more_info2   => gc_bill_to_customer_name,
                                    p_more_info3   => NULL,
                                    p_more_info4   => NULL);
                                lc_invoicel_flag   := gc_no_flag;
                            END IF;
                        END IF;

                        log_records (
                            gc_debug_flag,
                               'OLD_BILL_TO_CUSTOMER_ID :'
                            || lt_inv_data (xc_inv_rec).old_bill_to_customer_id);
                        log_records (
                            gc_debug_flag,
                               'old_bill_to_site_use_id :'
                            || lt_inv_data (xc_inv_rec).old_bill_to_site_use_id);
                        log_records (gc_debug_flag,
                                     'l_target_org_id :' || l_target_org_id);
                        log_records (
                            gc_debug_flag,
                               'attribute5 :'
                            || lt_inv_data (xc_inv_rec).attribute5);

                        --cursor to validate bill_to_address_id
                        IF     lt_inv_data (xc_inv_rec).old_bill_to_customer_id
                                   IS NOT NULL
                           AND lt_inv_data (xc_inv_rec).old_bill_to_site_use_id
                                   IS NOT NULL
                           AND ln_bill_to_customer_id IS NOT NULL
                        THEN
                            OPEN cur_get_bill_to_site_id (
                                ln_bill_to_customer_id,
                                lt_inv_data (xc_inv_rec).old_bill_to_site_use_id,
                                p_brand   =>
                                    lt_inv_data (xc_inv_rec).attribute5);

                            FETCH cur_get_bill_to_site_id
                                INTO ln_bill_to_site_id;

                            CLOSE cur_get_bill_to_site_id;

                            log_records (
                                'Y',
                                'ln_bill_to_site_id' || ln_bill_to_site_id);

                            IF ln_bill_to_site_id IS NULL
                            THEN
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Open Invoice Conversion Program',
                                    p_error_msg    =>
                                           ' Bill to Site ID  '
                                        || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                        || ' Not found',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => gc_invoice_number,
                                    p_more_info2   => gc_bill_to_customer_name,
                                    p_more_info3   =>
                                        lt_inv_data (xc_inv_rec).bill_to_customer_id,
                                    p_more_info4   =>
                                        lt_inv_data (xc_inv_rec).old_bill_to_site_use_id);
                                lc_invoicel_flag   := gc_no_flag;
                            ELSE
                                --validation to bill to site use id

                                OPEN cur_get_bill_to_site_use_id (
                                    ln_bill_to_site_id);

                                FETCH cur_get_bill_to_site_use_id
                                    INTO ln_bill_to_site_use_id;

                                CLOSE cur_get_bill_to_site_use_id;

                                IF ln_bill_to_site_use_id IS NULL
                                THEN
                                    xxd_common_utils.record_error (
                                        p_module       => 'AR',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers AR Open Invoice Conversion Program',
                                        p_error_msg    =>
                                               ' Bill to Site Use ID for  '
                                            || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                            || ' Not found',
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   => gc_invoice_number,
                                        p_more_info2   =>
                                            gc_bill_to_customer_name,
                                        p_more_info3   =>
                                            lt_inv_data (xc_inv_rec).bill_to_customer_id,
                                        p_more_info4   =>
                                            lt_inv_data (xc_inv_rec).old_bill_to_site_use_id);
                                    lc_invoicel_flag   := gc_no_flag;
                                END IF;
                            END IF;
                        END IF;

                        --Cursor to validate customer site contact id
                        IF lt_inv_data (xc_inv_rec).old_bill_to_contact_id
                               IS NOT NULL
                        THEN
                            OPEN cur_get_cust_site_cont_id (
                                lt_inv_data (xc_inv_rec).old_bill_to_contact_id);

                            FETCH cur_get_cust_site_cont_id
                                INTO ln_bill_to_contact_id;

                            CLOSE cur_get_cust_site_cont_id;

                            IF ln_bill_to_contact_id IS NULL
                            THEN
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Open Invoice Conversion Program',
                                    p_error_msg    =>
                                           '  Bill to Customer Address Contact'
                                        || lt_inv_data (xc_inv_rec).old_bill_to_contact_id
                                        || ' Not found',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => gc_invoice_number,
                                    p_more_info2   => gc_bill_to_customer_name,
                                    p_more_info3   =>
                                        lt_inv_data (xc_inv_rec).old_bill_to_contact_id,
                                    p_more_info4   => NULL);
                                lc_invoicel_flag   := gc_no_flag;
                            END IF;
                        END IF;
                    END IF;                    -- customer_website IS NOT NULL

                    IF lt_inv_data (xc_inv_rec).old_ship_to_customer_id
                           IS NOT NULL
                    THEN
                        log_records (
                            'Y',
                               'lt_inv_data (xc_inv_rec).old_ship_to_customer_id'
                            || lt_inv_data (xc_inv_rec).old_ship_to_customer_id);

                        OPEN cur_get_customer_id (
                            lt_inv_data (xc_inv_rec).old_ship_to_customer_id);

                        FETCH cur_get_customer_id INTO ln_ship_to_customer_id;

                        CLOSE cur_get_customer_id;

                        IF ln_ship_to_customer_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       ' Ship to Customer '
                                    || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   => NULL,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    IF     lt_inv_data (xc_inv_rec).old_ship_to_customer_id
                               IS NOT NULL
                       AND lt_inv_data (xc_inv_rec).old_ship_to_site_use_id
                               IS NOT NULL
                    THEN
                        OPEN cur_get_ship_to_site_id (
                            lt_inv_data (xc_inv_rec).old_ship_to_customer_id,
                            lt_inv_data (xc_inv_rec).old_ship_to_site_use_id);

                        FETCH cur_get_ship_to_site_id INTO ln_ship_to_site_id;

                        CLOSE cur_get_ship_to_site_id;

                        IF ln_ship_to_site_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       ' Ship to to Customer Address  '
                                    || lt_inv_data (xc_inv_rec).bill_to_customer_name
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).old_ship_to_customer_id,
                                p_more_info4   =>
                                    lt_inv_data (xc_inv_rec).old_ship_to_site_use_id);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    -- ship to site use id derivation
                    IF ln_ship_to_site_id IS NOT NULL
                    THEN
                        OPEN cur_get_ship_to_site_use_id (ln_ship_to_site_id);

                        FETCH cur_get_ship_to_site_use_id
                            INTO ln_ship_to_site_use_id;

                        CLOSE cur_get_ship_to_site_use_id;

                        IF ln_ship_to_site_use_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       '  Ship to site Use ID'
                                    || ln_ship_to_site_id
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   => ln_ship_to_site_id,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    IF lt_inv_data (xc_inv_rec).old_ship_to_contact_id
                           IS NOT NULL
                    THEN
                        OPEN cur_get_cust_site_cont_id (
                            lt_inv_data (xc_inv_rec).old_ship_to_contact_id);

                        FETCH cur_get_cust_site_cont_id
                            INTO ln_ship_to_contact_id;

                        CLOSE cur_get_cust_site_cont_id;

                        IF ln_ship_to_contact_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       '  Ship to Customer Address Contact'
                                    || lt_inv_data (xc_inv_rec).old_ship_to_contact_id
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).old_ship_to_contact_id,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    IF lt_inv_data (xc_inv_rec).primary_salesrep_number
                           IS NOT NULL
                    THEN
                        OPEN cur_get_salesrepname_id (
                            lt_inv_data (xc_inv_rec).primary_salesrep_number,
                            l_target_org_id);

                        FETCH cur_get_salesrepname_id
                            INTO ln_primary_salesrep_id;

                        CLOSE cur_get_salesrepname_id;

                        IF ln_primary_salesrep_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       ' Primary SalesRep Number '
                                    || lt_inv_data (xc_inv_rec).primary_salesrep_number
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).primary_salesrep_number,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    --Initilization of ln_bill_cycle_id
                    ln_bill_cycle_id                                 := NULL;

                    IF lt_inv_data (xc_inv_rec).term_name IS NOT NULL
                    THEN
                        OPEN cur_get_terms_id (
                            lt_inv_data (xc_inv_rec).term_name);

                        FETCH cur_get_terms_id INTO ln_term_id, ln_bill_cycle_id;

                        CLOSE cur_get_terms_id;

                        log_records (
                            gc_debug_flag,
                            'Billing Cycle ID ---> ' || ln_bill_cycle_id);

                        IF ln_term_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       '  Terms Name '
                                    || lt_inv_data (xc_inv_rec).term_name
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).term_name,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    IF lt_inv_data (xc_inv_rec).receipt_method_name
                           IS NOT NULL
                    THEN
                        OPEN cur_get_receipt_method_id (
                            lt_inv_data (xc_inv_rec).receipt_method_name);

                        FETCH cur_get_receipt_method_id
                            INTO ln_receipt_method_id;

                        CLOSE cur_get_receipt_method_id;

                        IF ln_receipt_method_id IS NULL
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Open Invoice Conversion Program',
                                p_error_msg    =>
                                       '  Receipt Method '
                                    || lt_inv_data (xc_inv_rec).receipt_method_name
                                    || ' Not found',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => gc_invoice_number,
                                p_more_info2   => gc_bill_to_customer_name,
                                p_more_info3   =>
                                    lt_inv_data (xc_inv_rec).receipt_method_name,
                                p_more_info4   => NULL);
                            lc_invoicel_flag   := gc_no_flag;
                        END IF;
                    END IF;

                    IF lt_inv_data (xc_inv_rec).ship_via IS NOT NULL
                    THEN
                        OPEN get_new_ship_method_c (
                            lt_inv_data (xc_inv_rec).ship_via,
                            l_target_org_id);

                        FETCH get_new_ship_method_c INTO lc_ship_via;

                        CLOSE get_new_ship_method_c;

                        IF lc_ship_via IS NULL
                        THEN
                            lc_ship_via   := 'CONV';
                        END IF;
                    END IF;

                    --invoice_line_validation
                    lc_invoice_line_flag                             :=
                        invoice_line_validation (
                            p_debug                 => gc_no_flag,
                            p_action                => gc_validate_status,
                            p_source_trx_header_id   =>
                                lt_inv_data (xc_inv_rec).source_trx_header_id,
                            px_trx_header_id        => lx_trx_header_id,
                            p_amount_due_original   => ln_amount_due_original,
                            p_amount_due_remaining   =>
                                ln_amount_due_remaining);
                    log_records ('Y', 'here3' || ln_ship_to_site_use_id);

                    IF     lc_invoicel_flag = gc_yes_flag
                       AND lc_invoice_line_flag = gc_yes_flag
                    THEN
                        -- update customer table with VALID status
                        UPDATE xxd_ar_trx_headers_stg_t
                           SET cust_trx_type_id = ln_cust_trx_type_id, bill_to_customer_id = ln_bill_to_customer_id, ship_to_customer_id = ln_ship_to_customer_id,
                               sold_to_customer_id = ln_sold_to_customer_id, bill_to_address_id = ln_bill_to_site_id, ship_to_address_id = ln_ship_to_site_id,
                               bill_to_site_use_id = ln_bill_to_site_use_id, ship_to_site_use_id = ln_ship_to_site_use_id, bill_to_contact_id = ln_bill_to_contact_id,
                               ship_to_contact_id = ln_ship_to_contact_id, primary_salesrep_id = ln_primary_salesrep_id, term_id = ln_term_id,
                               billing_cycle_id = ln_bill_cycle_id, receipt_method_id = ln_receipt_method_id, trx_header_id = lx_trx_header_id,
                               invoicing_rule_id = ln_invoice_rule_id, record_status = gc_validate_status, request_id = gn_conc_request_id,
                               new_batch_source_name = lc_source_name, new_cust_trx_type_name = lc_cust_trx_type, remit_to_address_id = ln_remit_to_address_id,
                               ship_via = lc_ship_via
                         WHERE source_trx_header_id =
                               lt_inv_data (xc_inv_rec).source_trx_header_id;
                    ELSE
                        UPDATE xxd_ar_trx_headers_stg_t
                           SET cust_trx_type_id = ln_cust_trx_type_id, bill_to_customer_id = ln_bill_to_customer_id, ship_to_customer_id = ln_ship_to_customer_id,
                               sold_to_customer_id = ln_sold_to_customer_id, bill_to_address_id = ln_bill_to_site_id, ship_to_address_id = ln_ship_to_site_id,
                               bill_to_site_use_id = ln_bill_to_site_use_id, ship_to_site_use_id = ln_ship_to_site_use_id, bill_to_contact_id = ln_bill_to_contact_id,
                               ship_to_contact_id = ln_ship_to_contact_id, primary_salesrep_id = ln_primary_salesrep_id, term_id = ln_term_id,
                               billing_cycle_id = ln_bill_cycle_id, receipt_method_id = ln_receipt_method_id, trx_header_id = lx_trx_header_id,
                               invoicing_rule_id = ln_invoice_rule_id, record_status = gc_error_status, request_id = gn_conc_request_id,
                               new_batch_source_name = lc_source_name, new_cust_trx_type_name = lc_cust_trx_type, ship_via = lc_ship_via
                         WHERE source_trx_header_id =
                               lt_inv_data (xc_inv_rec).source_trx_header_id;
                    END IF;

                    COMMIT;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;

        CLOSE cur_invoice;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
            log_records (gc_debug_flag, 'validate cur_invoice ' || SQLERRM);
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Raised During Price List Validation Program');
            log_records (gc_debug_flag, 'validate cur_invoice ' || SQLERRM);
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END invoice_validation;

    --Deckers AR Customer Open Invoice Program (Worker)
    PROCEDURE openinv_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_org_name IN VARCHAR2, p_batch_id IN NUMBER
                             , p_parent_request_id IN NUMBER, pv_from_trx_no IN VARCHAR2, pv_to_trx_no IN VARCHAR2)
    AS
        le_invalid_param    EXCEPTION;
        ln_new_ou_id        hr_operating_units.organization_id%TYPE;
        --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12
        ln_request_id       NUMBER := 0;
        lc_username         fnd_user.user_name%TYPE;
        lc_operating_unit   hr_operating_units.name%TYPE;
        lc_cust_num         VARCHAR2 (5);
        lc_pri_flag         VARCHAR2 (1);
        ld_start_date       DATE;
        ln_ins              NUMBER := 0;
        --ln_request_id             NUMBER                     := 0;
        lc_phase            VARCHAR2 (200);
        lc_status           VARCHAR2 (200);
        lc_delc_phase       VARCHAR2 (200);
        lc_delc_status      VARCHAR2 (200);
        lc_message          VARCHAR2 (200);
        ln_ret_code         NUMBER;
        lc_err_buff         VARCHAR2 (1000);
        ln_count            NUMBER;
        l_target_org_id     NUMBER;
    BEGIN
        gc_debug_flag        := p_debug_flag;

        BEGIN
            SELECT user_name
              INTO lc_username
              FROM fnd_user
             WHERE user_id = fnd_global.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_username   := NULL;
        END;

        BEGIN
            SELECT name
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;

        -- Validation Process for Price List Import
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Busines Unit:'
            || lc_operating_unit);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run By      :'
            || lc_username);
        --      fnd_file.put_line (fnd_file.LOG, '                                         Run Date    :' || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Batch ID    :'
            || p_batch_id);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        log_records (gc_debug_flag,
                     '******** START of Customer Import Program ******');
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        gc_debug_flag        := p_debug_flag;
        gn_org_id            := 0;
        gn_conc_request_id   := p_parent_request_id;

        --      l_target_org_id := get_targetorg_id(p_org_name => p_org_name);
        --      gn_org_id := NVL(l_target_org_id,gn_org_id);
        IF p_action = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling invoice_validation :');
            invoice_validation (errbuf => errbuf, retcode => retcode, p_action => gc_new_status, p_org_name => p_org_name, p_batch_id => p_batch_id, pv_from_trx_no => pv_from_trx_no
                                , pv_to_trx_no => pv_to_trx_no);
        ELSIF p_action = gc_load_only
        THEN
            --      l_target_org_id := get_targetorg_id(p_org_name => p_org_name);
            import_record (x_errbuff => errbuf, x_retcode => retcode, p_batch_number => p_batch_id, p_action => gc_validate_status, p_org_name => p_org_name, pv_from_trx_no => pv_from_trx_no
                           , pv_to_trx_no => pv_to_trx_no);
        END IF;

        print_processing_summary (x_ret_code => retcode);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.output,
                               'Exception Raised During Customer Program');
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END openinv_child;
END xxd_ar_opninv_c_pk;
/
