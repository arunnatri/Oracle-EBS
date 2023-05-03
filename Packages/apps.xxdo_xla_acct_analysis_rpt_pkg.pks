--
-- XXDO_XLA_ACCT_ANALYSIS_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_XLA_ACCT_ANALYSIS_RPT_PKG"
    AUTHID CURRENT_USER
AS                            -- Added by #BT Technology Team V1.1 17/Nov/2014
    /**********************************************************************************************
    * Package   : APPS.XXDO_XLA_ACCT_ANALYSIS_RPT_PKG
    * Author   : BT Technology Team
    * Created   : 25-NOV-2014
    * Program Name  : Account Analysis Report - Deckers
    * Description  : Default package for the XML Data template
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date   Developer    Version  Description
    *-----------------------------------------------------------------------------------------------
    *  17-Nov-2014 BT Technology Team  V1.1   Standard Package XLA_ACCT_ANALYSIS_RPT_PKG has
                 been customized to XXDO_XLA_ACCT_ANALYSIS_RPT_PKG
                #Redesign
     18-MAR-2022 Srinath Siricilla   V2.0        CCR0009873
     21-NOV-2022 Ramesh Reddy        V2.1        CCR0010275
    ************************************************************************************************/

    -- $Header: xlarpaan.pkh 120.19 2011/07/26 10:53:07 vgopiset ship $
    /*===========================================================================+
    |  Copyright (c) 2003 Oracle Corporation BelmFont, California, USA           |
    |                          ALL rights reserved.                              |
    +============================================================================+
    | FILENAME                                                                   |
    |     xlarpaan.pkh                                                           |
    |                                                                            |
    | PACKAGE NAME                                                               |
    |     xla_acct_analysis_rpt_pkg                                              |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     Package specification.This provides XML extract for Account Analysis   |
    |     Report.                                                                |
    |                                                                            |
    | HISTORY                                                                    |
    |     07/20/2005  V. Kumar        Created                                    |
    |     12/19/2005  V. Swapna       Modifed the package to use data template   |
    |     12/27/2005  S. Swapna       Added code to display TP information.      |
    |     06/02/2006  V. Kumar        Added Custom Parameter                     |
    |     16-Sep-2008 rajose          bug#7386068                                |
    |                                 Added parameter P_INCLUDE_ACCT_WITH_NO_ACT |
    |                                 to display accounts havng beginning bal and|
    |                                 no activity and p_begin_balance_union_all  |
    |                                 to query such records                      |
    |     20-Oct-2008 rajose          bug#7489252                                |
    |                                 Added parameter P_INC_ACCT_WITH_NO_ACT     |
    |                                 to display in Account Analysis Report      |
    |     16-Feb-2009 nksurana        Added new parameters to handle more than   |
    |                                 50 event classes per application for FSAH  |
    |     28-DEC-2009 rajose          bug#9002134 to make Acct Analysis Rpt      |
    |                                 queryable by source if source is provided  |
    |                                 as input                                   |
    |     05-Jan-2010 nksurana        Added new parameter p_tax_query to handle  |
    |                                 the tax query in the package.              |
    |     23-Dec-2010 nksurana        Added new variables to move the logic from |
    |                                 xml to pkb to make the xml reuasable and   |
    |                                 improve performance.                       |
    +===========================================================================*/

    --
    -- To be used in query as bind variable
    --
    P_RESP_APPLICATION_ID         NUMBER;
    P_LEDGER_ID                   NUMBER;
    P_LEDGER                      VARCHAR2 (300);
    P_COA_ID                      NUMBER;
    P_LEGAL_ENTITY_ID             NUMBER;
    P_LEGAL_ENTITY                VARCHAR2 (300);
    P_PERIOD_FROM                 VARCHAR2 (15);
    P_PERIOD_TO                   VARCHAR2 (15);
    P_GL_DATE_FROM                DATE;
    P_GL_DATE_TO                  DATE;
    P_BALANCE_TYPE_CODE           VARCHAR2 (1);
    P_BALANCE_TYPE                VARCHAR2 (300);
    P_DUMMY_BUDGET_VERSION        VARCHAR2 (300);
    P_BUDGET_VERSION_ID           NUMBER;
    P_BUDGET_NAME                 VARCHAR2 (300);
    P_DUMMY_ENCUMBRANCE_TYPE      VARCHAR2 (300);
    P_ENCUMBRANCE_TYPE_ID         NUMBER;
    P_ENCUMBRANCE_TYPE            VARCHAR2 (300);
    P_BALANCE_SIDE_CODE           VARCHAR2 (300);
    P_BALANCE_SIDE                VARCHAR2 (300);
    P_BALANCE_AMOUNT_FROM         NUMBER;
    P_BALANCE_AMOUNT_TO           NUMBER;
    P_BALANCING_SEGMENT_FROM      VARCHAR2 (300);
    P_BALANCING_SEGMENT_TO        VARCHAR2 (300);
    P_ACCOUNT_SEGMENT_FROM        VARCHAR2 (80);
    P_ACCOUNT_SEGMENT_TO          VARCHAR2 (80);
    P_ACCOUNT_FLEXFIELD_FROM      VARCHAR2 (780);
    P_ACCOUNT_FLEXFIELD_TO        VARCHAR2 (780);
    P_INCLUDE_ZERO_AMOUNT_LINES   VARCHAR2 (1);
    P_INCLUDE_ZERO_AMT_LINES      VARCHAR2 (20);
    P_INCLUDE_USER_TRX_ID_FLAG    VARCHAR2 (1);
    P_INCLUDE_USER_TRX_ID         VARCHAR2 (20);
    P_INCLUDE_TAX_DETAILS_FLAG    VARCHAR2 (1);
    P_INCLUDE_TAX_DETAILS         VARCHAR2 (20);
    P_INCLUDE_LE_INFO_FLAG        VARCHAR2 (30);
    P_INCLUDE_LEGAL_ENTITY        VARCHAR2 (30);
    P_CUSTOM_PARAMETER_1          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_2          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_3          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_4          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_5          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_6          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_7          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_8          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_9          VARCHAR2 (240);
    P_CUSTOM_PARAMETER_10         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_11         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_12         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_13         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_14         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_15         VARCHAR2 (240);
    /* 16-30 Custom Parameters added for bug12699905 */
    P_CUSTOM_PARAMETER_16         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_17         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_18         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_19         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_20         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_21         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_22         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_23         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_24         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_25         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_26         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_27         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_28         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_29         VARCHAR2 (240);
    P_CUSTOM_PARAMETER_30         VARCHAR2 (240);
    /* end of changes for bug12699905 */
    P_INCLUDE_STAT_AMOUNT_LINES   VARCHAR2 (1);
    P_INCLUDE_STAT_AMT_LINES      VARCHAR2 (20);
    P_INCLUDE_ACCT_WITH_NO_ACT    VARCHAR2 (1);                  --bug#7386068
    P_INC_ACCT_WITH_NO_ACT        VARCHAR2 (30);                 --bug#7489252
    P_CDATE                       VARCHAR2 (1); -- Added by #BT Technology Team V1.1 17/Nov/2014
    P_FROM_DATE                   VARCHAR2 (20); -- Added by #BT Technology Team V1.1 17/Nov/2014
    P_TO_DATE                     VARCHAR2 (20); -- Added by #BT Technology Team V1.1 17/Nov/2014
    P_TBL_SELECT                  VARCHAR2 (80);       -- Added for CCR0010275



    p_party_col                   VARCHAR2 (2000)
                                      := ',NULL,NULL,NULL,NULL,NULL,NULL';
    p_party_tab                   VARCHAR2 (2000) := '';
    p_party_join                  VARCHAR2 (2000) := '';
    p_legal_ent_col               VARCHAR2 (2000) := '';
    p_legal_ent_from              VARCHAR2 (2000) := '';
    p_legal_ent_join              VARCHAR2 (2000) := '';
    p_qualifier_segment           VARCHAR2 (4000) := '';
    p_seg_desc_from               VARCHAR2 (2000) := '';
    p_seg_desc_join               VARCHAR2 (2000) := '';
    p_trx_identifiers             VARCHAR2 (32000) := ',NULL';
    p_sla_other_filter            VARCHAR2 (2000) := '';
    p_gl_other_filter             VARCHAR2 (2000) := '';
    p_party_columns               VARCHAR2 (4000) := ' ';
    p_ledger_filters              VARCHAR2 (4000) := ' ';
    p_begin_balance_union_all     VARCHAR2 (32000) := ' ';       --bug#7386068

    --bug#9002134
    p_application_id              NUMBER;
    p_je_source_name              VARCHAR2 (300);
    p_je_category_name            VARCHAR2 (300); -- Added by #BT Technology Team V1.1 17/Nov/2014
    p_je_source_period            VARCHAR2 (32000) := ' ';
    p_sla_application_id_filter   VARCHAR2 (4000) := ' ';
    p_gl_application_id_filter    VARCHAR2 (4000) := ' ';
    --bug#9002134

    p_commercial_query            VARCHAR2 (32000);
    p_vat_registration_query      VARCHAR2 (32000);
    p_tax_query                   VARCHAR2 (32000);       --bug9011171,8762703

    --Added for bug 7580995
    p_trx_identifiers_1           VARCHAR2 (32000) := ' ';
    p_trx_identifiers_2           VARCHAR2 (32000) := ' ';
    p_trx_identifiers_3           VARCHAR2 (32000) := ' ';
    p_trx_identifiers_4           VARCHAR2 (32000) := ' ';
    p_trx_identifiers_5           VARCHAR2 (32000) := ' ';

    p_long_report                 VARCHAR2 (2);

    --bug 10425976
    p_main_col_start              VARCHAR2 (32000) := ' ';
    p_main_lgr_sgmt_col           VARCHAR2 (32000) := ' ';
    p_main_le_col                 VARCHAR2 (32000) := ' ';
    p_main_col_end                VARCHAR2 (32000) := ' ';
    p_sla_col_start               VARCHAR2 (32000) := ' ';
    p_gt_lgr_sgmt_col             VARCHAR2 (32000) := ' ';
    p_gt_le_col                   VARCHAR2 (32000) := ' ';
    p_sla_col_end                 VARCHAR2 (32000) := ' ';
    p_sla_from                    VARCHAR2 (32000) := ' ';
    p_sla_main_filter             VARCHAR2 (32000) := ' ';
    p_union_all                   VARCHAR2 (20) := ' UNION ALL ';
    p_gl_col_start                VARCHAR2 (32000) := ' ';
    p_gl_col_end                  VARCHAR2 (32000) := ' ';
    p_gl_from                     VARCHAR2 (32000) := ' ';
    p_gl_main_filter              VARCHAR2 (32000) := ' ';
    p_upg_gl_from                 VARCHAR2 (32000) := ' ';
    p_upg_gl_main_filter          VARCHAR2 (32000) := ' ';
    p_order_by_clause             VARCHAR2 (4000) := ' ';
    P_PARAM_CONDITION             VARCHAR2 (1500) := ' '; -- Added by #BT Technology Team V1.1 17/Nov/2014

    -- Start of Change as per CCR0009873
    p_sla_from_arch               VARCHAR2 (32000) := ' ';
    p_gl_col_start_arch           VARCHAR2 (32000) := ' ';
    p_sla_col_start_arch          VARCHAR2 (32000) := ' ';
    p_gl_from_arch                VARCHAR2 (32000) := ' ';
    p_upg_gl_from_arch            VARCHAR2 (32000) := ' ';
    -- End of Change as per CCR0009873
    p_invoke_gl                   VARCHAR2 (240) := ' '; --Added for CCR0010275
    p_invoke_arch                 VARCHAR2 (240) := ' '; --Added for CCR0010275

    FUNCTION beforeReport
        RETURN BOOLEAN;

    -- Start of Changes by BT Technology Team V1.1 17/Nov/2014
    FUNCTION get_voucher_num (p_source IN VARCHAR2, p_source_id_int_1 IN NUMBER, p_source_id_int_1_upg IN NUMBER)
        RETURN NUMBER;
-- End of Changes by BT Technology Team V1.1 17/Nov/2014

END XXDO_XLA_ACCT_ANALYSIS_RPT_PKG;
/
