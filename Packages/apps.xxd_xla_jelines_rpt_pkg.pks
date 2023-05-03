--
-- XXD_XLA_JELINES_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_XLA_JELINES_RPT_PKG"
    AUTHID CURRENT_USER
AS
    -- $Header: xlarpjel.pkh 120.18 2011/07/26 10:52:01 vgopiset ship $
    -- $Header: xlarpjel.pkb 120.68.12020000.5 2013/02/18 17:36:33 sgullape ship $
    /*===========================================================================+
    /  V1.0    10-MAY-2017      Sourced from XLA_JELINES_RPT_PKG                /
    /                           Created by Deckers IT Team
    +============================================================================+
    */


    --
    -- To be used in query as bind variable
    --

    p_resp_application_id            NUMBER;
    p_ledger_id                      NUMBER;
    p_coa_id                         NUMBER;
    p_ledger                         VARCHAR2 (300);
    p_legal_entity_id                NUMBER;
    p_legal_entity                   VARCHAR2 (300);
    p_trx_legal_entity_id            NUMBER;
    p_trx_legal_entity               VARCHAR2 (300);
    p_period_from                    VARCHAR2 (30);
    p_period_to                      VARCHAR2 (30);
    p_gl_date_from                   DATE;
    p_gl_date_to                     DATE;
    p_creation_date_from             DATE;
    p_creation_date_to               DATE;
    p_transaction_date_from          DATE;
    p_transaction_date_to            DATE;
    p_je_status_code                 VARCHAR2 (30);
    p_je_status                      VARCHAR2 (300);
    p_posting_status_code            VARCHAR2 (30);
    p_posting_status                 VARCHAR2 (30);
    p_je_source                      VARCHAR2 (30);
    p_je_source_name                 VARCHAR2 (300);
    p_process_category_rowid         VARCHAR2 (30);
    p_process_category               VARCHAR2 (300);
    p_dummy_event_class              VARCHAR2 (30);
    p_event_class_rowid              VARCHAR2 (30);
    p_event_class                    VARCHAR2 (300);
    p_transaction_view               VARCHAR2 (30);
    p_acct_sequence_name             VARCHAR2 (240);
    p_acct_sequence_version          NUMBER;
    p_acct_sequence_num_from         NUMBER;
    p_acct_sequence_num_to           NUMBER;
    p_rpt_sequence_name              VARCHAR2 (240);
    p_rpt_sequence_version           NUMBER;
    p_rpt_sequence_num_from          NUMBER;
    p_rpt_sequence_num_to            NUMBER;
    p_doc_sequence_name              VARCHAR2 (240);
    p_doc_sequence_num_from          NUMBER;
    p_doc_sequence_num_to            NUMBER;
    p_party_type_code                VARCHAR2 (30);
    p_party_type                     VARCHAR2 (300);
    p_party_id                       NUMBER;
    p_party_name                     VARCHAR2 (360);
    p_party_number_from              VARCHAR2 (100);
    p_party_number_to                VARCHAR2 (100);
    p_je_category                    VARCHAR2 (30);
    p_je_category_name               VARCHAR2 (300);
    p_balance_type_code              VARCHAR2 (30);
    p_balance_type                   VARCHAR2 (300);
    p_budget_version_id              NUMBER;
    p_budget_name                    VARCHAR2 (300);
    p_encumbrance_type_id            NUMBER;
    p_encumbrance_type               VARCHAR2 (300);
    p_include_zero_amount_flag       VARCHAR2 (30);
    p_include_zero_amount_lines      VARCHAR2 (30);
    p_entered_currency               VARCHAR2 (30);
    p_accounted_amount_from          NUMBER;
    p_accounted_amount_to            NUMBER;
    p_balancing_segment_from         VARCHAR2 (30);
    p_balancing_segment_to           VARCHAR2 (30);
    p_account_segment_from           VARCHAR2 (30);
    p_account_segment_to             VARCHAR2 (30);
    p_account_flexfield_from         VARCHAR2 (780);
    p_account_flexfield_to           VARCHAR2 (780);
    p_side_code                      VARCHAR2 (30);
    p_side                           VARCHAR2 (300);
    p_valuation_method               VARCHAR2 (30);
    p_security_id_int_1              NUMBER;
    p_security_id_int_2              NUMBER;
    p_security_id_int_3              NUMBER;
    p_security_id_char_1             VARCHAR2 (30);
    p_security_id_char_2             VARCHAR2 (30);
    p_security_id_char_3             VARCHAR2 (30);
    p_post_acct_program_rowid        VARCHAR2 (30);
    p_post_accounting_program        VARCHAR2 (240);
    p_user_trx_id_column_1           VARCHAR2 (30);
    p_user_trx_id_value_1            VARCHAR2 (240);
    p_user_trx_id_column_2           VARCHAR2 (30);
    p_user_trx_id_value_2            VARCHAR2 (240);
    p_user_trx_id_column_3           VARCHAR2 (30);
    p_user_trx_id_value_3            VARCHAR2 (240);
    p_user_trx_id_column_4           VARCHAR2 (30);
    p_user_trx_id_value_4            VARCHAR2 (240);
    p_user_trx_id_column_5           VARCHAR2 (30);
    p_user_trx_id_value_5            VARCHAR2 (240);
    p_gl_batch_name                  VARCHAR2 (240);
    p_include_user_trx_id_flag       VARCHAR2 (30);
    p_include_user_trx_identifiers   VARCHAR2 (30);
    p_include_tax_details_flag       VARCHAR2 (30);
    p_include_tax_details            VARCHAR2 (30);
    p_include_le_info_flag           VARCHAR2 (30);
    p_ytd_carriedfwd_flag            VARCHAR2 (30);
    p_ytd_carriedfwd_info            VARCHAR2 (30);
    p_include_legal_entity_info      VARCHAR2 (240);
    p_custom_parameter_1             VARCHAR2 (240);
    p_custom_parameter_2             VARCHAR2 (240);
    p_custom_parameter_3             VARCHAR2 (240);
    p_custom_parameter_4             VARCHAR2 (240);
    p_custom_parameter_5             VARCHAR2 (240);
    p_custom_parameter_6             VARCHAR2 (240);
    p_custom_parameter_7             VARCHAR2 (240);
    p_custom_parameter_8             VARCHAR2 (240);
    p_custom_parameter_9             VARCHAR2 (240);
    p_custom_parameter_10            VARCHAR2 (240);
    p_custom_parameter_11            VARCHAR2 (240);
    p_custom_parameter_12            VARCHAR2 (240);
    p_custom_parameter_13            VARCHAR2 (240);
    p_custom_parameter_14            VARCHAR2 (240);
    p_custom_parameter_15            VARCHAR2 (240);
    /* 16-30 Custom Parameters added for bug12699905 */
    P_CUSTOM_PARAMETER_16            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_17            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_18            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_19            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_20            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_21            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_22            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_23            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_24            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_25            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_26            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_27            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_28            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_29            VARCHAR2 (240);
    P_CUSTOM_PARAMETER_30            VARCHAR2 (240);
    /* end of changes for bug12699905 */
    p_legal_audit_flag               VARCHAR2 (240);
    p_fetch_from_gl                  VARCHAR2 (10);
    p_doc_seq_name                   VARCHAR2 (240);

    p_sla_legal_ent_col              VARCHAR2 (2000) := ' ';
    p_sla_legal_ent_from             VARCHAR2 (1000) := ' ';
    p_sla_legal_ent_join             VARCHAR2 (1000) := ' ';
    p_gl_legal_ent_col               VARCHAR2 (2000) := ' ';
    p_gl_legal_ent_from              VARCHAR2 (1000) := ' ';
    p_gl_legal_ent_join              VARCHAR2 (1000) := ' ';
    p_party_details                  VARCHAR2 (4000) := ' ';
    p_party_details_col              VARCHAR2 (4000)
        := ',TABLE1.party_number                   PARTY_NUMBER
    ,TABLE1.party_name                     PARTY_NAME
    ,TABLE1.party_site_number              PARTY_SITE_NUMBER
    ,TABLE1.party_site_name                PARTY_SITE_NAME
    ,TABLE1.party_type_taxpayer_id         PARTY_TYPE_TAXPAYER_ID
    ,TABLE1.party_tax_registration_number  PARTY_TAX_REGISTRATION_NUMBER
    ,TABLE1.party_site_tax_rgstn_number    PARTY_SITE_TAX_RGSTN_NUMBER  ';
    p_gl_party_details               VARCHAR2 (2000) := ' ';
    p_party_from                     VARCHAR2 (240) := ' ';
    p_party_join                     VARCHAR2 (1000) := ' ';
    p_sla_qualifier_segment          VARCHAR2 (4000) := ' ';
    p_sla_seg_desc_from              VARCHAR2 (1000) := ' ';
    p_sla_seg_desc_join              VARCHAR2 (1000) := ' ';
    p_gl_qualifier_segment           VARCHAR2 (4000) := ' ';
    p_gl_seg_desc_from               VARCHAR2 (1000) := ' ';
    p_gl_seg_desc_join               VARCHAR2 (1000) := ' ';
    p_trx_identifiers                VARCHAR2 (32000) := ' ';
    p_gl_view                        VARCHAR2 (1000) := ' ';
    p_other_param_filter             VARCHAR2 (8000) := ' ';
    p_gl_join                        VARCHAR2 (1000) := ' ';
    p_gl_columns                     VARCHAR2 (1000) := ' ';
    p_le_col                         VARCHAR2 (4000) := ' ';
    p_le_from                        VARCHAR2 (2000) := ' ';
    p_le_join                        VARCHAR2 (2000) := ' ';
    p_sla_col_1                      VARCHAR2 (8000) := ' ';
    p_sla_col_2                      VARCHAR2 (8000) := ' ';
    p_sla_col_3                      VARCHAR2 (8000) := ' ';
    p_sla_from                       VARCHAR2 (4000) := ' ';
    p_sla_join                       VARCHAR2 (4000) := ' ';
    p_gl_col_1                       VARCHAR2 (8000) := ' ';
    p_gl_col_2                       VARCHAR2 (8000) := ' ';
    p_gl_from                        VARCHAR2 (4000) := ' ';
    p_gl_where                       VARCHAR2 (4000) := ' ';
    p_union_all                      VARCHAR2 (30) := ' ';
    p_trx_id_filter                  VARCHAR2 (3000) := ' ';
    p_tax_query                      VARCHAR2 (32000);
    p_ytd_carriedfwd                 VARCHAR2 (32000);
    p_created_query                  VARCHAR2 (32000);
    p_posted_query                   VARCHAR2 (32000);
    p_approved_query                 VARCHAR2 (32000);
    p_commercial_query               VARCHAR2 (32000);
    p_vat_registration_query         VARCHAR2 (32000);


    --Added for bug 7580995
    p_trx_identifiers_1              VARCHAR2 (32000) := ' ';
    p_trx_identifiers_2              VARCHAR2 (32000) := ' ';
    p_trx_identifiers_3              VARCHAR2 (32000) := ' ';
    p_trx_identifiers_4              VARCHAR2 (32000) := ' ';
    p_trx_identifiers_5              VARCHAR2 (32000) := ' ';

    p_period_type                    VARCHAR2 (1) := 'B';        --bug 7645837
    p_trx_num_from                   VARCHAR2 (240);             --bug 8337868
    p_trx_num_to                     VARCHAR2 (240);             --bug 8337868
    p_order_by                       VARCHAR2 (30) := ' ';       --bug 7159772
    p_order_by_clause                VARCHAR2 (40) := ' ';       --bug 7159772

    --Bug 8683445 Added for Custom Query
    p_custom_query_flag              VARCHAR2 (1);
    p_custom_header_query            VARCHAR2 (32000);
    p_custom_line_query              VARCHAR2 (32000);

    -- Bug 9205753
    p_long_report                    VARCHAR2 (2);
    p_main_col_start                 VARCHAR2 (32000) := ' ';
    p_segment_col                    VARCHAR2 (32000) := ' ';
    p_uti_col                        VARCHAR2 (32000) := ' ';
    p_main_col_end                   VARCHAR2 (32000) := ' ';
    p_other_union                    VARCHAR2 (32000) := ' ';
    p_other_from                     VARCHAR2 (32000) := ' ';
    p_other_join                     VARCHAR2 (32000) := ' ';


    FUNCTION beforeReport
        RETURN BOOLEAN;
END xxd_xla_jelines_rpt_pkg;
/
