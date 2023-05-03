--
-- XXDO_XLA_ACCT_ANALYSIS_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_XLA_ACCT_ANALYSIS_RPT_PKG"
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
    *   27-Jul-2021 Showkath Ali        v1.2        Fix for Performance issue due to 19c upgrade
    *   18-MAR-2022 Srinath Siricilla   V2.0        CCR0009873
    *   14-NOV-2022 Ramesh Reddy        V2.0        CCR0010275 - Performance Issue with Archive Tables
    ************************************************************************************************/

    -- $Header: xlarpaan.pkb 120.36 2011/08/16 13:07:13 nksurana ship $
    /*===========================================================================+
    |  Copyright (c) 2003 Oracle Corporation BelmFont, California, USA           |
    |                          ALL rights reserved.                              |
    +============================================================================+
    | FILENAME                                                                   |
    |     xlarpaan.pkb                                                           |
    |                                                                            |
    | PACKAGE NAME                                                               |
    |     xla_acct_analysis_rpt_pkg                                              |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     PACKAGE BODY. This provides XML extract for Account Analysis Report    |
    |                                                                            |
    | HISTORY                                                                    |
    |     07/20/2005  V. Kumar        Created                                    |
    |     12/19/2005  V. Swapna       Modifed the package to use data template   |
    |     12/27/2005  V. Swapna       Modfied code to use the right GT table.    |
    |                                 Added code to display TP information.      |
    |     04/23/2006  A. Wan          5072266 - replace po_vendors with          |
    |                                           ap_suppliers                     |
    |     08/23/2006  V. Swapna       5474255 - Modify filter condition for      |
    |                                 zero amount lines.                         |
    |     16-Sep-2008 rajose          bug#7386068 To display accounts having     |
    |                                 beginning balance and no activity          |
    |     29-May-2009 rajose          bug#8554433 Insert into _gt query taking   |
    |                                 long time to execute.                      |
    |     05-Jan-2010 nksurana        Added new parameter p_tax_query to handle  |
    |                                 the tax query in the package so that it is |
    |                                 executed only when tax flag is Y           |
    |     09-Aug-2010 nksurana        Removed the clause for zero net period     |
    |                                 activity from the condition on include     |
    |                                 zero amounts.                              |
    |     23-Dec-2010 nksurana        Added new variables to move the logic from |
    |                                 xml to pkb to make the xml reuasable and   |
    |                                 improve performance.                       |
    |     16-Aug-2011 nksurana        Added additional filter in the insert into |
    |                                 xla_report_balances_gt when the flag       |
    |                                 P_INCLUDE_ACCT_WITH_NO_ACT is NULL or N.   |
    +===========================================================================*/

    --=============================================================================
    --           ****************  declarations  ********************
    --=============================================================================

    TYPE t_array_char IS TABLE OF VARCHAR2 (80)
        INDEX BY BINARY_INTEGER;



    -------------------------------------------------------------------------------
    -- constant for getting leagal entity information
    -------------------------------------------------------------------------------
    C_NULL_LEGAL_ENT_COL   CONSTANT VARCHAR2 (4000)
                                        := ' ,NULL         LEGAL_ENTITY_ID
     ,NULL         LEGAL_ENTITY_NAME
     ,NULL         LE_ADDRESS_LINE_1
     ,NULL         LE_ADDRESS_LINE_2
     ,NULL         LE_ADDRESS_LINE_3
     ,NULL         LE_CITY
     ,NULL         LE_REGION_1
     ,NULL         LE_REGION_2
     ,NULL         LE_REGION_3
     ,NULL         LE_POSTAL_CODE
     ,NULL         LE_COUNTRY
     ,NULL         LE_REGISTRATION_NUMBER
     ,NULL         LE_REGISTRATION_EFFECTIVE_FROM
     ,NULL         LE_BR_DAILY_INSCRIPTION_NUMBER
     ,NULL         LE_BR_DAILY_INSCRIPTION_DATE
     ,NULL         LE_BR_DAILY_ENTITY
     ,NULL         LE_BR_DAILY_LOCATION
     ,NULL         LE_BR_DIRECTOR_NUMBER
     ,NULL         LE_BR_ACCOUNTANT_NUMBER
     ,NULL         LE_BR_ACCOUNTANT_NAME ' ;

    C_LEGAL_ENT_COL        CONSTANT VARCHAR2 (4000)
        := ' ,fiv.legal_entity_id                     LEGAL_ENTITY_ID
     ,fiv.NAME                                LEGAL_ENTITY_NAME
     ,fiv.ADDRESS_LINE_1                      LE_ADDRESS_LINE_1
     ,fiv.ADDRESS_LINE_2                      LE_ADDRESS_LINE_2
     ,fiv.ADDRESS_LINE_3                      LE_ADDRESS_LINE_3
     ,fiv.TOWN_OR_CITY                        LE_CITY
     ,fiv.REGION_1                            LE_REGION_1
     ,fiv.REGION_2                            LE_REGION_2
     ,fiv.REGION_3                            LE_REGION_3
     ,fiv.postal_code                         LE_POSTAL_CODE
     ,fiv.country                             LE_COUNTRY
     ,fiv.registration_number                 LE_REGISTRATION_NUMBER
     ,fiv.effective_from                      LE_REGISTRATION_EFFECTIVE_FROM
     ,xrv.registration_number                 LE_BR_DAILY_INSCRIPTION_NUMBER
     ,to_char(xrv.effective_from
             ,''YYYY-MM-DD'')                 LE_BR_DAILY_INSCRIPTION_DATE
     ,xrv.legalauth_name                      LE_BR_DAILY_ENTITY
     ,xlv.city                                LE_BR_DAILY_LOCATION
     ,lc1.contact_number                      LE_BR_DIRECTOR_NUMBER
     ,lc2.contact_number                      LE_BR_ACCOUNTANT_NUMBER
     ,lc2.contact_name                        LE_BR_ACCOUNTANT_NAME ' ;

    C_LEGAL_ENT_FROM       CONSTANT VARCHAR2 (1000)
        := ' ,xle_firstparty_information_v   fiv
     ,xle_registrations_v            xrv
     ,xle_legalauth_v                xlv
     ,xle_legal_contacts_v           lc1
     ,xle_legal_contacts_v           lc2
     ,gl_ledger_le_bsv_specific_v    gle' ;

    C_LEGAL_ENT_JOIN       CONSTANT VARCHAR2 (2000)
        := ' AND gle.ledger_id(+)            = TABLE1.ledger_id
     AND gle.segment_value(+)        = TABLE1.$leg_seg_val$
     AND fiv.legal_entity_id(+)      = gle.legal_entity_id
     AND xrv.legal_entity_id(+)      = fiv.legal_entity_id
     AND xrv.legislative_category(+) = ''FEDERAL_TAX''
     AND xlv.legalauth_id(+)         = xrv.legalauth_id
     AND lc1.entity_id(+)            = fiv.legal_entity_id
     AND lc1.ROLE(+)                 = ''DIRECTOR''
     AND lc1.entity_type(+)          = ''LEGAL_ENTITY''
     AND lc2.entity_id(+)            = fiv.legal_entity_id
     AND lc2.ROLE(+)                 = ''ACCOUNTANT''
     AND lc2.entity_type(+)          = ''LEGAL_ENTITY'' ' ;

    C_ESTBLISHMENT_COL     CONSTANT VARCHAR2 (4000)
        := ' ,xev.establishment_id                    LEGAL_ENTITY_ID
     ,xev.establishment_name                  LEGAL_ENTITY_NAME
     ,xev.address_line_1                      LE_ADDRESS_LINE_1
     ,xev.address_line_2                      LE_ADDRESS_LINE_2
     ,xev.address_line_3                      LE_ADDRESS_LINE_3
     ,xev.town_or_city                        LE_CITY
     ,xev.region_1                            LE_REGION_1
     ,xev.region_2                            LE_REGION_2
     ,xev.region_3                            LE_REGION_3
     ,xev.postal_code                         LE_POSTAL_CODE
     ,xev.country                             LE_COUNTRY
     ,xev.registration_number                 LE_REGISTRATION_NUMBER
     ,xev.effective_from                      LE_REGISTRATION_EFFECTIVE_FROM
     ,xrv.registration_number                 LE_BR_DAILY_INSCRIPTION_NUMBER
     ,to_char(xrv.effective_from
             ,''YYYY-MM-DD'')                 LE_BR_DAILY_INSCRIPTION_DATE
     ,xrv.legalauth_name                      LE_BR_DAILY_ENTITY
     ,xlv.city                                LE_BR_DAILY_LOCATION
     ,lc1.contact_number                      LE_BR_DIRECTOR_NUMBER
     ,lc2.contact_number                      LE_BR_ACCOUNTANT_NUMBER
     ,lc2.contact_name                        LE_BR_ACCOUNTANT_NAME ' ;

    C_ESTABLISHMENT_FROM   CONSTANT VARCHAR2 (2000)
        := ' ,gl_ledger_le_bsv_specific_v      glv
     ,xle_bsv_associations             xba
     ,xle_establishment_v              xev
     ,xle_registrations_v              xrv
     ,xle_legalauth_v                  xlv
     ,xle_legal_contacts_v             lc1
     ,xle_legal_contacts_v             lc2' ;

    C_ESTABLISHMENT_JOIN   CONSTANT VARCHAR2 (2000)
        := ' AND glv.ledger_id(+)            = TABLE1.ledger_id
     AND glv.segment_value(+)        = TABLE1.$leg_seg_val$
     AND xba.legal_parent_id(+)      = glv.legal_entity_id
     AND xba.entity_name(+)          = glv.segment_value
     AND xba.context(+)              = ''EST_BSV_MAPPING''
     AND xev.establishment_id(+)     = xba.legal_construct_id
     AND xrv.establishment_id(+)     = xev.establishment_id
     AND xrv.legislative_category(+) = ''FEDERAL_TAX''
     AND xlv.legalauth_id(+)         = xrv.legalauth_id
     AND lc1.entity_id(+)            = xev.establishment_id
     AND lc1.entity_type(+)          = ''ESTABLISHMENT''
     AND lc1.ROLE(+)                 = ''DIRECTOR''
     AND lc2.entity_id(+)            = xev.establishment_id
     AND lc2.ROLE(+)                 = ''ACCOUNTANT''
     AND lc2.entity_type(+)          = ''ESTABLISHMENT'' ' ;
    --------------------------------------------------------------------------------
    -- constant for COMMERCIAL_NUMBER details
    --------------------------------------------------------------------------------
    C_COMMERCIAL_QUERY              VARCHAR2 (8000)
        := 'SELECT nvl(xler.registration_number,0) LEGAL_COMMERCIAL_NUMBER
FROM XLE_REGISTRATIONS_V xler
WHERE  legislative_category = ''COMMERCIAL_LAW''
 AND legal_entity_id = :P_LEGAL_ENTITY_ID';

    C_COMMERCIAL_NULL_QUERY         VARCHAR2 (8000)
        := 'select NULL LEGAL_COMMERCIAL_NUMBER from dual where 1>2';

    --------------------------------------------------------------------------------
    -- constant for VAT_REGISTRATION details
    --------------------------------------------------------------------------------
    C_VAT_REGISTRATION_QUERY        VARCHAR2 (8000)
        := 'SELECT zptp.REP_REGISTRATION_NUMBER   LEGAL_VAT_REGISTRATION_NUMBER
FROM ZX_PARTY_TAX_PROFILE zptp ,XLE_ETB_PROFILES xetbp
WHERE zptp.PARTY_TYPE_CODE = ''LEGAL_ESTABLISHMENT''
AND xetbp.party_id=zptp.party_id
AND xetbp.MAIN_ESTABLISHMENT_FLAG = ''Y''
AND xetbp.LEGAL_ENTITY_ID = :P_LEGAL_ENTITY_ID';

    C_VAT_REGISTRATION_NULL_QUERY   VARCHAR2 (8000)
        := 'select NULL LEGAL_VAT_REGISTRATION_NUMBER from dual where 1>2';

    --Added for bug 9011171,8762703
    --------------------------------------------------------------------------------
    -- constants for TAX details query
    --------------------------------------------------------------------------------
    C_TAX_QUERY                     VARCHAR2 (8000)
        := 'SELECT /*+ index(xdl, XLA_DISTRIBUTION_LINKS_N3) */
	 zxr.tax_regime_name                                TAX_REGIME
        ,zxl.tax                                            TAX
        ,ztt.tax_full_name                                  TAX_NAME
        ,zst.tax_status_name                                TAX_STATUS_NAME
        ,zrt.tax_rate_name                                  TAX_RATE_NAME
        ,zxl.tax_rate                                       TAX_RATE
        ,flk1.meaning                                       TAX_RATE_TYPE_NAME
        ,to_char(zxl.tax_determine_date
                ,''YYYY-MM-DD'')                            TAX_DETERMINE_DATE
        ,to_char(zxl.tax_point_date
                ,''YYYY-MM-DD'')                            TAX_POINT_DATE
        ,zxl.tax_type_code                                  TAX_TYPE_CODE
        ,flk2.meaning                                       TAX_TYPE_NAME
        ,zxl.tax_code                                       TAX_CODE
        ,zxl.tax_registration_number                        TAX_REGISTRATION_NUMBER
        ,zxl.trx_currency_code                              TRX_CURRENCY_CODE
        ,zxl.tax_currency_code                              TAX_CURRENCY_CODE
        ,zxl.tax_amt                                        TAX_AMOUNT
        ,zxl.tax_amt_tax_curr                               TAX_AMOUNT_TAX_CURRENCY
        ,zxl.tax_amt_funcl_curr                             TAX_AMOUNT_FUNCTIONAL_CURR
        ,zxl.taxable_amt                                    TAXABLE_AMOUNT
        ,zxl.taxable_amt_tax_curr                           TAXABLE_AMOUNT_TAX_CURRENCY
        ,zxl.taxable_amt_funcl_curr                         TAXABLE_AMT_FUNC_CURRENCY
        ,zxl.unrounded_taxable_amt                          UNROUNDED_TAXABLE_AMOUNT
        ,zxl.unrounded_tax_amt                              UNROUNDED_TAX_AMOUNT
        ,zxl.rec_tax_amt                                    RECOVERABLE_TAX_AMOUNT
        ,zxl.rec_tax_amt_tax_curr                           RECOVERABLE_TAX_AMT_TAX_CURR
        ,zxl.rec_tax_amt_funcl_curr                         RECOVERABLE_TAX_AMT_FUNC_CURR
        ,zxl.nrec_tax_amt                                   NON_RECOVERABLE_TAX_AMOUNT
        ,zxl.nrec_tax_amt_tax_curr                          NON_REC_TAX_AMT_TAX_CURR
        ,zxl.nrec_tax_amt_funcl_curr                        NON_REC_TAX_AMT_FUNC_CURR
FROM     xla_distribution_links         xdl
        ,zx_lines                       zxl
        ,zx_regimes_tl                  zxr
        ,zx_taxes_tl                    ztt
        ,zx_status_tl                   zst
        ,zx_rates_tl                    zrt
        ,fnd_lookups                    flk1
        ,fnd_lookups                    flk2
WHERE    xdl.tax_line_ref_id                 = zxl.tax_line_id
  AND    zxr.tax_regime_id(+)                = zxl.tax_regime_id
  AND    zxr.language(+)                     = USERENV(''LANG'')
  AND    ztt.tax_id(+)                       = zxl.tax_id
  AND    ztt.language(+)                     = USERENV(''LANG'')
  AND    zst.tax_status_id(+)                = zxl.tax_status_id
  AND    zst.language(+)                     = USERENV(''LANG'')
  AND    zrt.tax_rate_id(+)                  = zxl.tax_rate_id
  AND    zrt.language(+)                     = USERENV(''LANG'')
  AND    flk1.lookup_type                    = ''ZX_RATE_TYPE''
  AND    flk1.lookup_code                    = zxl.tax_rate_type
  AND    flk2.lookup_type(+)                 = ''ZX_TAX_TYPE_CATEGORY''
  AND    flk2.lookup_code(+)                 = zxl.tax_type_code
  AND    xdl.application_id                  = :APPLICATION_ID
  AND    xdl.ae_header_id                    = :HEADER_ID
  AND    xdl.ae_line_num                     = :ORIG_LINE_NUMBER ';

    C_TAX_NULL_QUERY                VARCHAR2 (8000)
                                        := 'SELECT NULL FROM DUAL WHERE 1=2 ';

    C_QUALIFIED_SEGMENT    CONSTANT VARCHAR2 (1000)
        := '         ,$alias_balancing_segment$      BALANCING_SEGMENT
          ,$alias_account_segment$        NATURAL_ACCOUNT_SEGMENT
          ,$alias_costcenter_segment$     COST_CENTER_SEGMENT
          ,$alias_management_segment$     MANAGEMENT_SEGMENT
          ,$alias_intercompany_segment$   INTERCOMPANY_SEGMENT
           $seg_desc_column$ ' ;

    C_HINT                 CONSTANT VARCHAR2 (240)
                                        := ' /*+ leading(gcck, gl1, glb) */ ' ;

    -- modified for bug#8554433
    --' /*+ leading(gcck $fnd_flex_hint$, gl1, glb) use_nl(glb) */ ';
    /*bug#8554433 causing the optimizer to hit gl_balances with _n1 index and
      using only the code_combination_id as the filter. With this hint _N1 index in
      gl_balances is hit with code_combination_id and period_name filter which is
      highly selective.
    */


    --=============================================================================
    --        **************  forward  declaration *******************
    --=============================================================================
    --------------------------------------------------------------------------------
    -- procedure to create the main SQL
    --------------------------------------------------------------------------------
    --=============================================================================
    --               *********** Local Trace Routine **********
    --=============================================================================
    C_LEVEL_STATEMENT      CONSTANT NUMBER := FND_LOG.LEVEL_STATEMENT;
    C_LEVEL_PROCEDURE      CONSTANT NUMBER := FND_LOG.LEVEL_PROCEDURE;
    C_LEVEL_EVENT          CONSTANT NUMBER := FND_LOG.LEVEL_EVENT;
    C_LEVEL_EXCEPTION      CONSTANT NUMBER := FND_LOG.LEVEL_EXCEPTION;
    C_LEVEL_ERROR          CONSTANT NUMBER := FND_LOG.LEVEL_ERROR;
    C_LEVEL_UNEXPECTED     CONSTANT NUMBER := FND_LOG.LEVEL_UNEXPECTED;

    C_LEVEL_LOG_DISABLED   CONSTANT NUMBER := 99;
    C_DEFAULT_MODULE       CONSTANT VARCHAR2 (240)
        := 'xla.plsql.xxdo_xla_acct_analysis_rpt_pkg' ;

    g_log_level                     NUMBER;
    g_log_enabled                   BOOLEAN;

    PROCEDURE trace (p_msg      IN VARCHAR2,
                     p_level    IN NUMBER,
                     p_module   IN VARCHAR2)
    IS
    BEGIN
        IF (p_msg IS NULL AND p_level >= g_log_level)
        THEN
            fnd_log.MESSAGE (p_level, NVL (p_module, C_DEFAULT_MODULE));
        ELSIF p_level >= g_log_level
        THEN
            fnd_log.string (p_level, NVL (p_module, C_DEFAULT_MODULE), p_msg);
        END IF;
    EXCEPTION
        WHEN xla_exceptions_pkg.application_exception
        THEN
            RAISE;
        WHEN OTHERS
        THEN
            xla_exceptions_pkg.raise_message (
                p_location => 'xxdo_xla_acct_analysis_rpt_pkg.trace');
    END trace;

    -- Start of Changes by BT Technology Team V1.1 17/Nov/2014
    /*======================================================================+
    |                                                                       |
    |  Function                                                        |
    |                                                                       |
    |    get_voucher_num                                                 |
    |                                                                       |
    |                                                                       |
    |    Return the voucher_num if source is Payables                       |
    |                                                                       |
    +======================================================================*/
    FUNCTION get_voucher_num (p_source IN VARCHAR2, p_source_id_int_1 IN NUMBER, p_source_id_int_1_upg IN NUMBER)
        RETURN NUMBER
    IS
        l_vc_num   NUMBER (30) := NULL;
    BEGIN
        IF p_source = 'Payables'
        THEN
            SELECT NVL (ai.voucher_num, ai.doc_sequence_value)
              INTO l_vc_num
              -- FROM ap_invoices_all ai
              FROM ap_invoices ai
             WHERE ai.invoice_id =
                   NVL (p_source_id_int_1, p_source_id_int_1_upg);
        END IF;

        RETURN l_vc_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_voucher_num;

    --End of Changes by BT Technology Team V1.1 17/Nov/2014

    /*======================================================================+
    |                                                                       |
    | Private Function                                                      |
    |                                                                       |
    |    get_flex_range_where                                               |
    |                                                                       |
    |                                                                       |
    |    Return where clauses for flexfield ranges                          |
    |                                                                       |
    +======================================================================*/

    FUNCTION get_flex_range_where (p_coa_id IN NUMBER, p_accounting_flexfield_from IN VARCHAR2, p_accounting_flexfield_to IN VARCHAR2)
        RETURN VARCHAR
    IS
        l_log_module             VARCHAR2 (240);
        l_where                  VARCHAR2 (32000);
        l_bind_variables         fnd_flex_xml_publisher_apis.bind_variables;
        l_numof_bind_variables   NUMBER;
        l_segment_name           VARCHAR2 (30);
        l_segment_value          VARCHAR2 (1000);
        l_data_type              VARCHAR2 (30);
    BEGIN
        IF g_log_enabled
        THEN
            l_log_module   := C_DEFAULT_MODULE || '.get_flex_range_where';
        END IF;

        --
        IF (C_LEVEL_PROCEDURE >= g_log_level)
        THEN
            trace (p_msg      => 'BEGIN of get_flex_range_where',
                   p_level    => C_LEVEL_PROCEDURE,
                   p_module   => l_log_module);
        END IF;

        IF (C_LEVEL_STATEMENT >= g_log_level)
        THEN
            trace (p_msg      => 'p_coa_id = ' || TO_CHAR (p_coa_id),
                   p_level    => C_LEVEL_STATEMENT,
                   p_module   => l_log_module);

            trace (
                p_msg      =>
                       'p_accounting_flexfield_from  = '
                    || TO_CHAR (p_accounting_flexfield_from),
                p_level    => C_LEVEL_STATEMENT,
                p_module   => l_log_module);

            trace (
                p_msg      =>
                       'p_accounting_flexfield_to = '
                    || TO_CHAR (p_accounting_flexfield_to),
                p_level    => C_LEVEL_STATEMENT,
                p_module   => l_log_module);
        END IF;

        --
        --  e.g. l_where stores the following:
        --       gcck.SEGMENT1 BETWEEN :FLEX_PARM1 AND :FLEX_PARM2
        --   AND gcck.SEGMENT2 BETWEEN :FLEX_PARM3 AND :FLEX_PARM4 ...
        --
        fnd_flex_xml_publisher_apis.kff_where (
            p_lexical_name                   => 'FLEX_PARM',
            p_application_short_name         => 'SQLGL',
            p_id_flex_code                   => 'GL#',
            p_id_flex_num                    => p_coa_id,
            p_code_combination_table_alias   => 'gcck',
            p_segments                       => 'ALL',
            p_operator                       => 'BETWEEN',
            p_operand1                       => p_accounting_flexfield_from,
            p_operand2                       => p_accounting_flexfield_to,
            x_where_expression               => l_where,
            x_numof_bind_variables           => l_numof_bind_variables,
            x_bind_variables                 => l_bind_variables);

        FOR i IN l_bind_variables.FIRST .. l_bind_variables.LAST
        LOOP
            l_segment_name   := l_bind_variables (i).name;
            l_data_type      := l_bind_variables (i).data_type;

            IF (l_data_type = 'VARCHAR2')
            THEN
                l_segment_value   :=
                    '''' || l_bind_variables (i).varchar2_value || '''';
            ELSIF (l_data_type = 'NUMBER')
            THEN
                l_segment_value   := l_bind_variables (i).canonical_value;
            ELSIF (l_data_type = 'DATE')
            THEN
                l_segment_value   :=
                       ''''
                    || TO_CHAR (l_bind_variables (i).date_value,
                                'yyyy-mm-dd HH24:MI:SS')
                    || '''';
            END IF;

            --
            -- Use REGEXP_REPLACE instead of REPLACE not to replace
            -- string 'SEGMENT1' in 'SEGMENT10'.
            -- REGEXP_REPLACE replaces the first occurent of a segment name
            -- e.g.
            --  BETWEEN :FLEX_PARM9 AND :FLEX_PARM10
            --  =>
            --  BETWEEN '000' AND '100'
            --
            l_where          :=
                REGEXP_REPLACE (l_where, ':' || l_segment_name, l_segment_value
                                , 1                                -- Position
                                   , 1                  -- The first occurence
                                      , 'c'                  -- Case sensitive
                                           );
        END LOOP;

        IF (C_LEVEL_PROCEDURE >= g_log_level)
        THEN
            trace (p_msg      => 'END of get_flex_range_where',
                   p_level    => C_LEVEL_PROCEDURE,
                   p_module   => l_log_module);
        END IF;

        RETURN l_where;
    EXCEPTION
        WHEN xla_exceptions_pkg.application_exception
        THEN
            RAISE;
        WHEN OTHERS
        THEN
            xla_exceptions_pkg.raise_message (
                p_location => 'xla_tb_report_pvt.get_flex_range_where');
    END get_flex_range_where;

    --=============================================================================
    --          *********** public procedures and functions **********
    --=============================================================================
    --=============================================================================

    --
    --
    --
    --
    --
    --
    --
    -- Following are public routines
    --
    --    1.  beforeReport
    --
    --
    --
    --
    --
    --
    --
    --

    --=============================================================================
    --=============================================================================
    --
    --
    --
    --=============================================================================
    FUNCTION beforeReport
        RETURN BOOLEAN
    IS
        l_ledger_id                    NUMBER;
        l_start_period_num             NUMBER;
        l_end_period_num               NUMBER;
        l_start_date                   DATE;
        l_end_date                     DATE;
        l_lang                         VARCHAR2 (80);
        l_count                        NUMBER;
        l_coa_id                       NUMBER;
        l_object_type                  VARCHAR2 (30);
        l_balancing_segment            P_BALANCING_SEGMENT_FROM%TYPE;
        l_account_segment              P_ACCOUNT_SEGMENT_FROM%TYPE;
        l_costcenter_segment           VARCHAR2 (80);
        l_management_segment           VARCHAR2 (80);
        l_intercompany_segment         VARCHAR2 (80);
        l_alias_balancing_segment      P_BALANCING_SEGMENT_FROM%TYPE;
        l_alias_account_segment        P_ACCOUNT_SEGMENT_FROM%TYPE;
        l_alias_costcenter_segment     l_costcenter_segment%TYPE;
        l_alias_management_segment     l_management_segment%TYPE;
        l_alias_intercompany_segment   l_intercompany_segment%TYPE;
        l_seg_desc_column              VARCHAR2 (2000);
        l_seg_desc_from                p_seg_desc_from%TYPE;
        l_seg_desc_join                p_seg_desc_join%TYPE;
        l_other_param_filter           VARCHAR2 (2000);
        l_log_module                   VARCHAR2 (240);
        l_balance_query                VARCHAR2 (32000);
        l_flex_range_where             VARCHAR2 (32000);
        l_sla_other_filter             p_sla_other_filter%TYPE := ' ';
        l_gl_other_filter              p_gl_other_filter%TYPE := ' ';
        l_ledger_set_from              VARCHAR2 (1000) := ' ';
        l_ledger_set_where             VARCHAR2 (1000) := ' ';
        i                              NUMBER;
        l_conc_seg_delimiter           VARCHAR2 (80);
        l_concat_segment               VARCHAR2 (4000);
        l_array                        t_array_char;

        l_ledgers                      VARCHAR2 (1000);
        l_fnd_flex_hint                VARCHAR2 (240);
        l_hint                         VARCHAR2 (240);
        l_statistical                  VARCHAR2 (50);


        CURSOR c (p_coa_id NUMBER)
        IS
              SELECT 'gcck.' || application_column_name seg
                FROM fnd_id_flex_segments
               WHERE     application_id = 101
                     AND id_flex_code = 'GL#'
                     AND id_flex_num = p_coa_id
            ORDER BY segment_num;

        l_je_source_name               VARCHAR2 (300);            --bug9002134
    BEGIN
        --
        -- default values
        --
        P_INCLUDE_ZERO_AMOUNT_LINES   :=
            NVL (P_INCLUDE_ZERO_AMOUNT_LINES, 'N');
        P_INCLUDE_USER_TRX_ID_FLAG    := NVL (P_INCLUDE_USER_TRX_ID_FLAG, 'N');
        P_INCLUDE_TAX_DETAILS_FLAG    := NVL (P_INCLUDE_TAX_DETAILS_FLAG, 'N');
        P_INCLUDE_LE_INFO_FLAG        := NVL (P_INCLUDE_LE_INFO_FLAG, 'NONE');
        P_INCLUDE_STAT_AMOUNT_LINES   :=
            NVL (P_INCLUDE_STAT_AMOUNT_LINES, 'N');

        P_INCLUDE_ACCT_WITH_NO_ACT    :=
            NVL (P_INCLUDE_ACCT_WITH_NO_ACT, 'N');               --bug#7386068


        --------------------------------------------------------------------------------
        -- Start of the Changes by BT Technology Team V1.1 17/11/2014
        --------------------------------------------------------------------------------
        P_PARAM_CONDITION             :=
               P_PARAM_CONDITION
            || 'AND	   gjh.je_source					  = NVL(:P_JE_SOURCE_NAME,gjh.je_source)
											AND	   gjct.user_je_category_name			  = NVL(:P_JE_CATEGORY_NAME,gjct.user_je_category_name)';

        IF P_CDATE = 'N'
        THEN
            IF ((P_FROM_DATE IS NOT NULL) AND (P_TO_DATE IS NULL))
            THEN
                P_PARAM_CONDITION   :=
                       P_PARAM_CONDITION
                    || ' AND gjl.effective_date >= '''
                    || FND_DATE.canonical_to_date (P_FROM_DATE)
                    || '''';
            ELSIF ((P_TO_DATE IS NOT NULL) AND (P_FROM_DATE IS NULL))
            THEN
                P_PARAM_CONDITION   :=
                       P_PARAM_CONDITION
                    || ' AND gjl.effective_date <= '''
                    || FND_DATE.canonical_to_date (P_TO_DATE)
                    || '''';
            ELSIF ((P_FROM_DATE IS NOT NULL) AND (P_TO_DATE IS NOT NULL))
            THEN
                P_PARAM_CONDITION   :=
                       P_PARAM_CONDITION
                    || ' AND gjl.effective_date >= '''
                    || FND_DATE.canonical_to_date (P_FROM_DATE)
                    || '''';
                P_PARAM_CONDITION   :=
                       P_PARAM_CONDITION
                    || ' AND gjl.effective_date <= '''
                    || FND_DATE.canonical_to_date (P_TO_DATE)
                    || '''';
            END IF;
        ELSIF P_CDATE = 'Y'
        THEN
            IF ((P_FROM_DATE IS NOT NULL) AND (P_TO_DATE IS NULL))
            THEN
                P_PARAM_CONDITION   :=
                       P_PARAM_CONDITION
                    || ' AND gjl.creation_date >= '''
                    || FND_DATE.canonical_to_date (P_FROM_DATE)
                    || '''';
            ELSIF ((P_TO_DATE IS NOT NULL) AND (P_FROM_DATE IS NULL))
            THEN
                P_TO_DATE   :=
                    TO_DATE (P_TO_DATE, 'YYYY/MM/DD HH24:MI:SS') + 1;
                P_PARAM_CONDITION   :=
                       P_PARAM_CONDITION
                    || ' AND gjl.creation_date < '''
                    || P_TO_DATE
                    || '''';
            ELSIF ((P_FROM_DATE IS NOT NULL) AND (P_TO_DATE IS NOT NULL))
            THEN
                P_TO_DATE   :=
                    TO_DATE (P_TO_DATE, 'YYYY/MM/DD HH24:MI:SS') + 1;
                P_PARAM_CONDITION   :=
                       P_PARAM_CONDITION
                    || ' AND gjl.creation_date >= '''
                    || FND_DATE.canonical_to_date (P_FROM_DATE)
                    || '''';
                P_PARAM_CONDITION   :=
                       P_PARAM_CONDITION
                    || ' AND gjl.creation_date < '''
                    || P_TO_DATE
                    || '''';
            END IF;
        END IF;

        --------------------------------------------------------------------------------
        -- End of the Changes by BT Technology Team V1.1 17/11/2014
        --------------------------------------------------------------------------------


        --
        -- following will set the right transaction security
        -- The transaction security in this case is "no security"
        -- becuase the report is submitted from a GL responsibility
        --
        -- xla_security_pkg.set_security_context(602);

        /*For bug#9002134 Account Analysis report can be run for a given je source.
           This je source parameter by default would not be displayed and would be null.
           If je source is null or All ie application id is null or 101 no security else security
           for that je source.
           For a given je source other than gl appropriate filters are added in the report xla and gl queries
           and the period total field is calculated via query and is not taken from gl_balances table.
          Hence the following piece of code
         */

        IF NVL (p_application_id, 101) = 101
        THEN
            xla_security_pkg.set_security_context (602);

            p_je_source_period   := ' ,NULL  JE_SOURCE_PERIOD_DR
                              ,NULL  JE_SOURCE_PERIOD_CR';
        ELSE
            xla_security_pkg.set_security_context (p_application_id);

            BEGIN
                SELECT gjst.je_source_name
                  INTO l_je_source_name
                  FROM xla_subledgers xls, gl_je_sources_tl gjst
                 WHERE     xls.application_id = p_application_id
                       AND xls.je_source_name = gjst.je_source_name
                       AND gjst.language = USERENV ('LANG');


                -- Bug 9668652
                IF p_application_id IS NOT NULL
                THEN
                    p_sla_application_id_filter   :=
                        ' AND ael.application_id = ' || p_application_id;
                END IF;



                IF     p_application_id IS NOT NULL
                   AND l_je_source_name IS NOT NULL
                THEN
                    p_sla_application_id_filter   :=
                           p_sla_application_id_filter
                        || ' AND aeh.application_id = '
                        || p_application_id;                    -- Bug 9668652
                    p_gl_application_id_filter   :=
                        ' AND gjh.je_source = ''' || l_je_source_name || '''';

                    p_je_source_period   :=
                        ' ,sum(TABLE1.ACCOUNTED_DR) OVER (partition by LEDGER_NAME, LEDGER_CURRENCY, BALANCE_TYPE_CODE,BUDGET_NAME, ENCUMBRANCE_TYPE, je_source_name, PERIOD_NAME, ACCOUNTING_CODE_COMBINATION ) JE_SOURCE_PERIOD_DR
                                ,sum(TABLE1.ACCOUNTED_CR) OVER (partition by LEDGER_NAME, LEDGER_CURRENCY, BALANCE_TYPE_CODE,BUDGET_NAME,ENCUMBRANCE_TYPE, je_source_name,  PERIOD_NAME, ACCOUNTING_CODE_COMBINATION)  JE_SOURCE_PERIOD_CR
                              ';
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    p_je_source_period   := ' ,NULL  JE_SOURCE_PERIOD_DR
                                 ,NULL  JE_SOURCE_PERIOD_CR';
            END;
        END IF;

        --end bug#9002134


        --
        -- Transaction identifiers
        -- As account analysis report goes accross application and SLA
        -- does not support user trx ids in such a case, the following
        -- code is not needed.
        --
        --uncommented for bug7514332
        IF p_include_user_trx_id_flag = 'Y'
        THEN
            xla_report_utility_pkg.get_transaction_id (
                p_resp_application_id   => p_resp_application_id,
                p_ledger_id             => p_ledger_id,
                p_trx_identifiers_1     => p_trx_identifiers_1,
                p_trx_identifiers_2     => p_trx_identifiers_2,
                p_trx_identifiers_3     => p_trx_identifiers_3,
                p_trx_identifiers_4     => p_trx_identifiers_4,
                p_trx_identifiers_5     => p_trx_identifiers_5); --Added for bug 7580995
        ELSE
            p_trx_identifiers_1   := ',NULL  USERIDS '; --Added for bug 7580995
        END IF;

        --uncommented for bug7514332
        --
        -- Identifying ledger as Ledger or Ledger Set and get value for language
        --
        SELECT object_type_code, USERENV ('LANG')
          INTO l_object_type, l_lang
          FROM gl_ledgers
         WHERE ledger_id = p_ledger_id;


        --
        -- build join condition based on if ledger passed is a ledger set or a ledger
        --
        IF l_object_type = 'S'
        THEN
            l_ledgers   :=
                   '(SELECT ledger_id '
                || 'FROM gl_ledger_set_assignments '
                || 'WHERE ledger_set_id = :P_LEDGER_ID)';

            SELECT ledger_id
              INTO l_ledger_id
              FROM gl_ledger_set_assignments
             WHERE ledger_set_id = p_ledger_id AND ROWNUM = 1;
        ELSE
            l_ledgers     := '(:P_LEDGER_ID)';

            l_ledger_id   := p_ledger_id;
        END IF;

        --
        -- get effective period number for the from and to period
        --
        SELECT effective_period_num, START_DATE
          INTO l_start_period_num, l_start_date
          FROM gl_period_statuses
         WHERE     application_id = 101
               AND ledger_id = l_ledger_id
               AND period_name = p_period_from;


        SELECT effective_period_num, end_date
          INTO l_end_period_num, l_end_date
          FROM gl_period_statuses
         WHERE     application_id = 101
               AND ledger_id = l_ledger_id
               AND period_name = p_period_to;


        p_commercial_query            := C_COMMERCIAL_QUERY;
        p_vat_registration_query      := C_VAT_REGISTRATION_QUERY;

        --Added for bug 9011171,8762703
        IF p_include_tax_details_flag = 'Y'
        THEN
            p_tax_query   := C_TAX_QUERY;
        ELSE
            p_tax_query   := C_TAX_NULL_QUERY;
        END IF;


        --
        -- Qualified segments
        --
        p_qualifier_segment           := C_QUALIFIED_SEGMENT;


        --
        -- get COA for the ledger/ledger set
        --

        SELECT chart_of_accounts_id
          INTO l_coa_id
          FROM gl_ledgers
         WHERE ledger_id = p_ledger_id;

        -- Get concatenated segment

        l_concat_segment              :=
            xla_report_utility_pkg.get_conc_segments (p_coa_id, 'gcck');


        ----------------------------------------------------------------------------
        -- get qualifier segments for the COA
        ----------------------------------------------------------------------------
        xla_report_utility_pkg.get_acct_qualifier_segs (
            p_coa_id                 => l_coa_id,
            p_balance_segment        => l_balancing_segment,
            p_account_segment        => l_account_segment,
            p_cost_center_segment    => l_costcenter_segment,
            p_management_segment     => l_management_segment,
            p_intercompany_segment   => l_intercompany_segment);

        --
        -- attach table alias to the column names
        --
        IF l_balancing_segment = 'NULL'
        THEN
            l_alias_balancing_segment   := 'NULL';
        ELSE
            l_alias_balancing_segment   := 'gcck.' || l_balancing_segment;
        END IF;

        IF l_account_segment = 'NULL'
        THEN
            l_alias_account_segment   := 'NULL';
        ELSE
            l_alias_account_segment   := 'gcck.' || l_account_segment;
        END IF;

        IF l_costcenter_segment = 'NULL'
        THEN
            l_alias_costcenter_segment   := 'NULL';
        ELSE
            l_alias_costcenter_segment   := 'gcck.' || l_costcenter_segment;
        END IF;

        IF l_management_segment = 'NULL'
        THEN
            l_alias_management_segment   := 'NULL';
        ELSE
            l_alias_management_segment   := 'gcck.' || l_management_segment;
        END IF;

        IF l_intercompany_segment = 'NULL'
        THEN
            l_alias_intercompany_segment   := 'NULL';
        ELSE
            l_alias_intercompany_segment   :=
                'gcck.' || l_intercompany_segment;
        END IF;

        --
        -- replace placeholders for the qualified segemnts
        --
        p_qualifier_segment           :=
            REPLACE (p_qualifier_segment,
                     '$alias_balancing_segment$',
                     l_alias_balancing_segment);

        p_qualifier_segment           :=
            REPLACE (p_qualifier_segment,
                     '$alias_account_segment$',
                     l_alias_account_segment);

        p_qualifier_segment           :=
            REPLACE (p_qualifier_segment,
                     '$alias_costcenter_segment$',
                     l_alias_costcenter_segment);

        p_qualifier_segment           :=
            REPLACE (p_qualifier_segment,
                     '$alias_management_segment$',
                     l_alias_management_segment);

        p_qualifier_segment           :=
            REPLACE (p_qualifier_segment,
                     '$alias_intercompany_segment$',
                     l_alias_intercompany_segment);

        -- bug 8295104

        xla_report_utility_pkg.get_segment_info (
            p_coa_id                       => l_coa_id,
            p_balancing_segment            => l_balancing_segment,
            p_account_segment              => l_account_segment,
            p_costcenter_segment           => l_costcenter_segment,
            p_management_segment           => l_management_segment,
            p_intercompany_segment         => l_intercompany_segment,
            p_alias_balancing_segment      => l_alias_balancing_segment,
            p_alias_account_segment        => l_alias_account_segment,
            p_alias_costcenter_segment     => l_alias_costcenter_segment,
            p_alias_management_segment     => l_alias_management_segment,
            p_alias_intercompany_segment   => l_alias_intercompany_segment,
            p_seg_desc_column              => l_seg_desc_column,
            p_seg_desc_from                => l_seg_desc_from,
            p_seg_desc_join                => l_seg_desc_join,
            p_hint                         => l_fnd_flex_hint);


        --l_hint := REPLACE(C_HINT,'$fnd_flex_hint$',l_fnd_flex_hint);
        l_hint                        := C_HINT;

        --modfied for bug#8554433

        IF (C_LEVEL_STATEMENT >= g_log_level)
        THEN
            trace (p_msg      => 'seg_desc_column =' || l_seg_desc_column,
                   p_level    => C_LEVEL_STATEMENT,
                   p_module   => l_log_module);
            trace (p_msg      => 'seg_desc_from =' || l_seg_desc_from,
                   p_level    => C_LEVEL_STATEMENT,
                   p_module   => l_log_module);
            trace (p_msg      => 'seg_desc_join =' || l_seg_desc_join,
                   p_level    => C_LEVEL_STATEMENT,
                   p_module   => l_log_module);
            trace (p_msg      => 'l_hint =' || l_hint,
                   p_level    => C_LEVEL_STATEMENT,
                   p_module   => l_log_module);
        END IF;

        --
        -- replace placeholders for the qualified segemnts
        --
        p_qualifier_segment           :=
            REPLACE (p_qualifier_segment,
                     '$seg_desc_column$',
                     l_seg_desc_column);

        p_seg_desc_from               := l_seg_desc_from;

        p_seg_desc_join               := l_seg_desc_join;



        --
        -- Legal Entity Information
        --

        --
        -- Replace placeholders for Legal entity information
        --
        IF p_include_le_info_flag = 'LEGAL_ENTITY'
        THEN
            p_legal_ent_col    := C_LEGAL_ENT_COL;
            p_legal_ent_from   := C_LEGAL_ENT_FROM;
            p_legal_ent_join   := C_LEGAL_ENT_JOIN;

            p_legal_ent_join   :=
                REPLACE (p_legal_ent_join,
                         '$leg_seg_val$',
                         l_balancing_segment);

            IF p_legal_entity_id IS NOT NULL
            THEN
                p_legal_ent_join   :=
                       p_legal_ent_join
                    || ' AND gle.legal_entity_id = '
                    || p_legal_entity_id;
            END IF;
        ELSIF p_include_le_info_flag = 'ESTABLISHMENT'
        THEN
            p_legal_ent_col    := C_ESTBLISHMENT_COL;
            p_legal_ent_from   := C_ESTABLISHMENT_FROM;
            p_legal_ent_join   := C_ESTABLISHMENT_JOIN;

            p_legal_ent_join   :=
                REPLACE (p_legal_ent_join,
                         '$leg_seg_val$',
                         l_balancing_segment);

            IF p_legal_entity_id IS NOT NULL
            THEN
                p_legal_ent_join   :=
                       p_legal_ent_join
                    || ' AND glv.legal_entity_id = '
                    || p_legal_entity_id;
            END IF;
        ELSE                           -- p_include_le_info_flag = 'NONE' THEN
            p_legal_ent_col    := C_NULL_LEGAL_ENT_COL;
            p_legal_ent_from   := ' ';
            p_legal_ent_join   := ' ';

            IF p_legal_entity_id IS NOT NULL
            THEN
                p_legal_ent_from   := ' ,gl_ledger_le_bsv_specific_v gle ';
                p_legal_ent_join   :=
                       ' AND gle.ledger_id(+)        = TABLE1.LEDGER_ID '
                    || ' AND gle.segment_value(+)    = TABLE1.$leg_seg_val$ '
                    || ' AND gle.legal_entity_id(+)  = '
                    || p_legal_entity_id;

                p_legal_ent_join   :=
                    REPLACE (p_legal_ent_join,
                             '$leg_seg_val$',
                             l_balancing_segment);
            END IF;
        END IF;


        --
        -- Third party information
        --

        -- 5072266 modify po_vendors.party_id to use ap_suppliers.vendor_id
        -- po_vendors pov  -> ap_suppliers ap
        -- pov.segment1    -> ap.segment1
        -- pov.vendor_name -> ap.vendor_name
        -- pov.party_id    -> ap_vendor_id
        -- pov.party_id    -> ap.vendor_id

        /* Below the inner query is having join to xla_ae_lines ael2
           because it seems that CASE statment doesn't allow to have
           outer join from parent query column.So as a workaround we
           have joined to xla_ae_lines ale2 and then through ale2 we
           have outer joined to sites table for handling cases where
           party_site_id can be NULL for a valid party_id
        */

        --------------------------------------------------------------------------------
        -- Start of the Changes by BT Technology Team V1.1 17/11/2014
        --------------------------------------------------------------------------------

        /*  p_party_columns :=
              ',CASE
                 WHEN ael.party_type_code = ''S'' THEN
                    (SELECT         aps.segment1
                           ||''|''||aps.vendor_name
                           ||''|''||hzp.jgzz_fiscal_code
                           ||''|''||hzp.tax_reference
                           ||''|''||hps.party_site_number
                           ||''|''||hps.party_site_name
                           ||''|''||NULL
                      FROM  ap_suppliers          aps
                           ,ap_supplier_sites_all apss
                           ,hz_parties            hzp
                           ,hz_party_sites        hps
                           ,xla_ae_lines          ael2
                     WHERE  aps.vendor_id          = ael2.party_id
                       AND  hzp.party_id           = aps.party_id
                       AND  apss.vendor_site_id(+) = ael2.party_site_id
                       AND  hps.party_site_id(+)   = apss.party_site_id
                       AND  ael2.application_id    = ael.application_id
                       AND  ael2.ae_header_id      = ael.ae_header_id
                       AND  ael2.ae_line_num       = ael.ae_line_num )
                 WHEN ( ael.party_type_code = ''C'' AND ael.party_id is not null ) THEN
                    (SELECT         hca.account_number
                           ||''|''||hzp.party_name
                           ||''|''||hzp.jgzz_fiscal_code
                           ||''|''||hzp.tax_reference
                           ||''|''||hps.party_site_number
                           ||''|''||hps.party_site_name
                           ||''|''||hzcu.tax_reference
                      FROM  hz_cust_accounts        hca
                           ,hz_cust_acct_sites_all  hcas
                           ,hz_cust_site_uses_all   hzcu
                           ,hz_parties              hzp
                           ,hz_party_sites          hps
                           ,xla_ae_lines            ael2
                     WHERE  hca.cust_account_id       = ael2.party_id
                       AND  hzp.party_id              = hca.party_id
                       AND  hzcu.site_use_id(+)       = ael2.party_site_id
                       AND  hcas.cust_acct_site_id(+) = hzcu.cust_acct_site_id
                       AND  hps.party_site_id(+)      = hcas.party_site_id
                       AND  ael2.application_id       = ael.application_id
                       AND  ael2.ae_header_id         = ael.ae_header_id
                       AND  ael2.ae_line_num          = ael.ae_line_num )
                 ELSE
                   NULL
                 END       PARTY_INFO'; */
        p_party_columns               :=
            --START of the Changes for INC0299694 15 JUN 2016
            -- Added AND xle.event_id = fth.event_id  AND fth.event_id= ent.entity_id in the below query for INC0347589
             ',DECODE ( ael.application_id
           ,( SELECT fa.application_id
              FROM   fnd_application fa
              WHERE  fa.application_short_name = ''OFA''
            )
         ,(    DECODE ( ent.entity_code
                   , ''DEPRECIATION''
                   ,(NULL)

                   ,

                   (SELECT DISTINCT (NULL
                      ||''|''||aps.vendor_name
                      ||''|''||NULL
                      ||''|''||NULL
                      ||''|''||NULL
                                    ||''|''||NULL)
                     FROM ap_suppliers aps
                     ,    xla_ae_headers aeh3
                     ,    xla_ae_lines  ael3
                     ,    xla_transaction_entities xte
                     ,    fa_transaction_headers fth
                     ,    fa_asset_invoices fai
                       WHERE  ael3.ae_header_id = aeh3.ae_header_id
                       AND    xte.entity_id     = aeh3.entity_id
                       AND    xte.source_id_int_1 = fth.transaction_header_id
                       AND    fth.asset_id = fai.asset_id
                       AND xle.event_id = fth.event_id 
                       AND fth.event_id= ent.entity_id 
                       AND    aps.vendor_id = fai.po_vendor_id
                     AND    ael3.ae_header_id = ael.ae_header_id
                     AND    ael3.ae_line_num  = ael.ae_line_num
                     AND       ael3.application_id = ael.application_id)
                    )
          )
        ,( CASE
            WHEN ael.party_type_code = ''S'' THEN
               (SELECT         aps.segment1
                      ||''|''||aps.vendor_name
                      ||''|''||hzp.jgzz_fiscal_code
                      ||''|''||hzp.tax_reference
                      ||''|''||hps.party_site_number
                      ||''|''||hps.party_site_name
                      ||''|''||NULL
                 FROM  ap_suppliers aps
                      ,ap_supplier_sites_all apss
                      ,hz_parties hzp
                      ,hz_party_sites hps
                      ,xla_ae_lines ael2
                WHERE  aps.vendor_id          = ael2.party_id
                  AND  hzp.party_id           = aps.party_id
                  AND  apss.vendor_site_id(+) = ael2.party_site_id
                  AND  hps.party_site_id(+)   = apss.party_site_id
                  AND  ael2.application_id    = ael.application_id
                  AND  ael2.ae_header_id      = ael.ae_header_id
                  AND  ael2.ae_line_num       = ael.ae_line_num )
            WHEN ( ael.party_type_code = ''C'' AND ael.party_id is not null ) THEN
               (SELECT         hca.account_number
                      ||''|''||hzp.party_name
                      ||''|''||hzp.jgzz_fiscal_code
                      ||''|''||hzp.tax_reference
                      ||''|''||hps.party_site_number
                      ||''|''||hps.party_site_name
                      ||''|''||hzcu.tax_reference
                 FROM  hz_cust_accounts        hca
                      ,hz_cust_acct_sites_all  hcas
                      ,hz_cust_site_uses_all   hzcu
                      ,hz_parties hzp
                      ,hz_party_sites hps
                      ,xla_ae_lines   ael2
                WHERE  hca.cust_account_id       = ael2.party_id
                  AND  hzp.party_id              = hca.party_id
                  AND  hzcu.site_use_id(+)       = ael2.party_site_id
                  AND  hcas.cust_acct_site_id(+) = hzcu.cust_acct_site_id
                  AND  hps.party_site_id(+)      = hcas.party_site_id
                  AND  ael2.application_id       = ael.application_id
                  AND  ael2.ae_header_id         = ael.ae_header_id
                  AND  ael2.ae_line_num          = ael.ae_line_num )
            ELSE
               NULL
            END )
        )  PARTY_INFO';                                          --bug 10425976

        --START of the Changes for INC0299694 15 JUN 2016
        --------------------------------------------------------------------------------
        --END of the Changes by BT Technology Team V1.1 17/11/2014
        --------------------------------------------------------------------------------
        --===========================================================================
        -- Build Filter condition based on parameters
        --===========================================================================
        --
        -- Filter based on Balancing Segment Value
        --
        IF     p_balancing_segment_from IS NOT NULL
           AND p_balancing_segment_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND '
                || l_alias_balancing_segment
                || ' BETWEEN '''
                || p_balancing_segment_from
                || '''  AND  '''
                || p_balancing_segment_to
                || '''';
        END IF;

        --
        -- Filter based on Natural Account Segment Value
        --
        IF     p_account_segment_from IS NOT NULL
           AND p_account_segment_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND '
                || l_alias_account_segment
                || ' BETWEEN '''
                || p_account_segment_from
                || '''  AND  '''
                || p_account_segment_to
                || '''';
        END IF;

        --
        -- <conditions based on side>
        --
        IF UPPER (p_balance_side) = 'CREDIT'
        THEN
            IF p_balance_amount_from IS NOT NULL
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND ((NVL(glb.begin_balance_cr,0)+ NVL(glb.period_net_cr,0))
               -   (NVL(glb.begin_balance_dr,0)+ NVL(glb.period_net_dr,0)) ) > '
                    || p_balance_amount_from;
            ELSE
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND ((NVL(glb.begin_balance_cr,0)+ NVL(glb.period_net_cr,0))
               -   (NVL(glb.begin_balance_dr,0)+ NVL(glb.period_net_dr,0))) > 0';
            END IF;

            IF p_balance_amount_to IS NOT NULL
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND ((NVL(glb.begin_balance_cr,0)+ NVL(glb.period_net_cr,0))
               -   (NVL(glb.begin_balance_dr,0)+ NVL(glb.period_net_dr,0)) ) < '
                    || p_balance_amount_to;
            END IF;
        ELSIF UPPER (p_balance_side) = 'DEBIT'
        THEN
            IF p_balance_amount_from IS NOT NULL
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND ((NVL(glb.begin_balance_cr,0)+ NVL(glb.period_net_cr,0))
               -   (NVL(glb.begin_balance_dr,0)+ NVL(glb.period_net_dr,0)) ) < -'
                    || p_balance_amount_from;
            ELSE
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND ((NVL(glb.begin_balance_cr,0)+ NVL(glb.period_net_cr,0))
               -   (NVL(glb.begin_balance_dr,0)+ NVL(glb.period_net_dr,0))) < 0';
            END IF;

            IF p_balance_amount_to IS NOT NULL
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND ((NVL(glb.begin_balance_cr,0)+ NVL(glb.period_net_cr,0))
               -   (NVL(glb.begin_balance_dr,0)+ NVL(glb.period_net_dr,0)) ) > -'
                    || p_balance_amount_to;
            END IF;
        END IF;

        --
        -- <conditions based on Balance Type >
        --
        IF p_balance_type_code IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glb.actual_flag = '''
                || p_balance_type_code
                || '''';
        END IF;

        --
        -- <conditions based on Encumbrance Type>
        --
        IF p_encumbrance_type_id IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glb.encumbrance_type_id = '
                || p_encumbrance_type_id;
        END IF;

        --
        -- <conditions based on Budget Version>
        --
        IF p_budget_version_id IS NOT NULL
        THEN                                                        -- 4458381
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glb.budget_version_id = '
                || p_budget_version_id;
        END IF;

        --
        -- <conditions for Include zero amount lines>
        --
        IF p_include_stat_amount_lines = 'Y'
        THEN
            l_statistical   := ' IN (''STAT'', gl1.currency_code) ';
        ELSE
            l_statistical   := ' = gl1.currency_code ';
        END IF;

        IF p_include_zero_amount_lines = 'N'
        THEN
            /*   l_other_param_filter :=
                  l_other_param_filter ||
                  ' AND (((NVL(glb.begin_balance_cr,0)-NVL(glb.begin_balance_dr,0)) <>0)
                          OR (NVL(glb.period_net_cr,0) <>0 )
                          OR (NVL(glb.period_net_dr,0) <> 0))'; */
            --bug 9921498

            l_sla_other_filter   :=
                   l_sla_other_filter
                || ' AND (NVL(ael.accounted_dr,0) - NVL(ael.accounted_cr,0) <> 0)';

            l_gl_other_filter   :=
                   l_gl_other_filter
                || ' AND (NVL(gjl.accounted_dr,0) - NVL(gjl.accounted_cr,0) <> 0)';
        END IF;

        -- bug 10425976
        p_main_col_start              :=
            '/*+optimizer_features_enable(''11.2.0.4'')*/   -- v1.2 changes
	    TABLE1.GL_DATE                                 GL_DATE
       ,TABLE1.CREATED_BY                              CREATED_BY
       ,TABLE1.CREATION_DATE                           CREATION_DATE
       ,TABLE1.LAST_UPDATE_DATE                        LAST_UPDATE_DATE
       ,TABLE1.GL_TRANSFER_DATE                        GL_TRANSFER_DATE
       ,TABLE1.REFERENCE_DATE                          REFERENCE_DATE
       ,TABLE1.COMPLETED_DATE                          COMPLETED_DATE
       ,TABLE1.TRANSACTION_NUMBER                      TRANSACTION_NUMBER
	   ,TABLE1.VOUCHER_NUMBER						   VOUCHER_NUMBER										-- Added by #BT Technology Team V1.1 17/Nov/2014
	   ,:P_PERIOD_FROM								   START_PERIOD											-- Added by #BT Technology Team V1.1 17/Nov/2014
	   ,:P_PERIOD_TO								    END_PERIOD											-- Added by #BT Technology Team V1.1 17/Nov/2014
	   ,(SELECT  gb.begin_balance_dr
		 FROM    gl_balances gb
		 WHERE   gb.ledger_id             = :P_LEDGER_ID
		 AND     gb.period_name           = :P_PERIOD_FROM
		 AND     gb.code_combination_id   = table1.code_combination_id
		 AND     gb.currency_code         = table1.ledger_currency) 		PERIOD_FROM_BEGIN_BAL_DR		-- Added by #BT Technology Team V1.1 17/Nov/2014
	   ,(SELECT  gb.begin_balance_cr
		 FROM    gl_balances gb
		 WHERE   gb.ledger_id             = :P_LEDGER_ID
		 AND     gb.period_name           = :P_PERIOD_FROM
		 AND     gb.code_combination_id   = table1.code_combination_id
		 AND     gb.currency_code         = table1.ledger_currency )	 	PERIOD_FROM_BEGIN_BAL_CR		-- Added by #BT Technology Team V1.1 17/Nov/2014
	   ,(SELECT  gb.begin_balance_dr
		 FROM    gl_balances gb
		 WHERE   gb.ledger_id             = :P_LEDGER_ID
		 AND     gb.period_name           = :P_PERIOD_TO
		 AND     gb.code_combination_id   = table1.code_combination_id
		 AND     gb.currency_code         = table1.ledger_currency) 		 PERIOD_TO_BEGIN_BAL_DR			-- Added by #BT Technology Team V1.1 17/Nov/2014
	   ,(SELECT  gb.begin_balance_cr
		 FROM    gl_balances gb
		 WHERE   gb.ledger_id             = :P_LEDGER_ID
		 AND     gb.period_name           = :P_PERIOD_TO
		 AND     gb.code_combination_id   = table1.code_combination_id
		 AND     gb.currency_code         = table1.ledger_currency) 		 PERIOD_TO_BEGIN_BAL_CR			-- Added by #BT Technology Team V1.1 17/Nov/2014
	   ,(SELECT  gb.period_net_dr
		 FROM    gl_balances gb
		 WHERE   gb.ledger_id             = :P_LEDGER_ID
		 AND     gb.period_name           = :P_PERIOD_TO
		 AND     gb.code_combination_id   = table1.code_combination_id
		 AND     gb.currency_code         = table1.ledger_currency) 		 PERIOD_TO_PERIOD_NET_DR		-- Added by #BT Technology Team V1.1 17/Nov/2014
	   ,(SELECT  gb.period_net_cr
		 FROM    gl_balances gb
		 WHERE   gb.ledger_id             = :P_LEDGER_ID
		 AND     gb.period_name           = :P_PERIOD_TO
		 AND     gb.code_combination_id   = table1.code_combination_id
		 AND     gb.currency_code         = table1.ledger_currency) 		 PERIOD_TO_PERIOD_NET_CR		 -- Added by #BT Technology Team V1.1 17/Nov/2014
       ,TABLE1.TRANSACTION_DATE                        TRANSACTION_DATE
       ,TABLE1.ACCOUNTING_SEQUENCE_NAME                ACCOUNTING_SEQUENCE_NAME
       ,TABLE1.ACCOUNTING_SEQUENCE_VERSION             ACCOUNTING_SEQUENCE_VERSION
       ,TABLE1.ACCOUNTING_SEQUENCE_NUMBER              ACCOUNTING_SEQUENCE_NUMBER
       ,TABLE1.REPORTING_SEQUENCE_NAME                 REPORTING_SEQUENCE_NAME
       ,TABLE1.REPORTING_SEQUENCE_VERSION              REPORTING_SEQUENCE_VERSION
       ,TABLE1.REPORTING_SEQUENCE_NUMBER               REPORTING_SEQUENCE_NUMBER
       ,TABLE1.DOCUMENT_CATEGORY                       DOCUMENT_CATEGORY
       ,TABLE1.DOCUMENT_SEQUENCE_NAME                  DOCUMENT_SEQUENCE_NAME
       ,TABLE1.DOCUMENT_SEQUENCE_NUMBER                DOCUMENT_SEQUENCE_NUMBER
       ,TABLE1.GL_DOCUMENT_SEQUENCE_NAME               GL_DOCUMENT_SEQUENCE_NAME
       ,TABLE1.GL_DOCUMENT_SEQUENCE_NUMBER             GL_DOCUMENT_SEQUENCE_NUMBER
       ,TABLE1.APPLICATION_ID                          APPLICATION_ID
       ,TABLE1.APPLICATION_NAME                        APPLICATION_NAME
       ,TABLE1.HEADER_ID                               HEADER_ID
       ,TABLE1.HEADER_DESCRIPTION                      HEADER_DESCRIPTION
       ,TABLE1.FUND_STATUS                             FUND_STATUS
       ,TABLE1.JE_CATEGORY_NAME                        JE_CATEGORY_NAME
       ,TABLE1.JE_SOURCE_NAME                          JE_SOURCE_NAME
       ,TABLE1.EVENT_ID                                EVENT_ID
       ,TABLE1.EVENT_DATE                              EVENT_DATE
       ,TABLE1.EVENT_NUMBER                            EVENT_NUMBER
       ,TABLE1.EVENT_CLASS_CODE                        EVENT_CLASS_CODE
       ,TABLE1.EVENT_CLASS_NAME                        EVENT_CLASS_NAME
       ,TABLE1.EVENT_TYPE_CODE                         EVENT_TYPE_CODE
       ,TABLE1.EVENT_TYPE_NAME                         EVENT_TYPE_NAME
       ,TABLE1.GL_BATCH_NAME                           GL_BATCH_NAME
       ,TABLE1.POSTED_DATE                             POSTED_DATE
       ,TABLE1.GL_JE_NAME                              GL_JE_NAME
       ,TABLE1.GL_LINE_NUMBER                          GL_LINE_NUMBER
       ,TABLE1.LINE_NUMBER                             LINE_NUMBER
       ,TABLE1.ORIG_LINE_NUMBER                        ORIG_LINE_NUMBER
       ,TABLE1.ACCOUNTING_CLASS_CODE                   ACCOUNTING_CLASS_CODE
       ,TABLE1.ACCOUNTING_CLASS_NAME                   ACCOUNTING_CLASS_NAME
       ,TABLE1.LINE_DESCRIPTION                        LINE_DESCRIPTION
       ,TABLE1.ENTERED_CURRENCY                        ENTERED_CURRENCY
       ,TABLE1.CONVERSION_RATE                         CONVERSION_RATE
       ,TABLE1.CONVERSION_RATE_DATE                    CONVERSION_RATE_DATE
       ,TABLE1.CONVERSION_RATE_TYPE_CODE               CONVERSION_RATE_TYPE_CODE
       ,TABLE1.CONVERSION_RATE_TYPE                    CONVERSION_RATE_TYPE
       ,TABLE1.ENTERED_DR                              ENTERED_DR
       ,TABLE1.ENTERED_CR                              ENTERED_CR
       ,TABLE1.UNROUNDED_ACCOUNTED_DR                  UNROUNDED_ACCOUNTED_DR
       ,TABLE1.UNROUNDED_ACCOUNTED_CR                  UNROUNDED_ACCOUNTED_CR
       ,TABLE1.ACCOUNTED_DR                            ACCOUNTED_DR
       ,TABLE1.ACCOUNTED_CR                            ACCOUNTED_CR
       ,TABLE1.STATISTICAL_AMOUNT                      STATISTICAL_AMOUNT
       ,TABLE1.RECONCILIATION_REFERENCE                RECONCILIATION_REFERENCE
       ,TABLE1.ATTRIBUTE_CATEGORY                      ATTRIBUTE_CATEGORY
       ,TABLE1.ATTRIBUTE1                              ATTRIBUTE1
       ,TABLE1.ATTRIBUTE2                              ATTRIBUTE2
       ,TABLE1.ATTRIBUTE3                              ATTRIBUTE3
       ,TABLE1.ATTRIBUTE4                              ATTRIBUTE4
       ,TABLE1.ATTRIBUTE5                              ATTRIBUTE5
       ,TABLE1.ATTRIBUTE6                              ATTRIBUTE6
       ,TABLE1.ATTRIBUTE7                              ATTRIBUTE7
       ,TABLE1.ATTRIBUTE8                              ATTRIBUTE8
       ,TABLE1.ATTRIBUTE9                              ATTRIBUTE9
       ,TABLE1.ATTRIBUTE10                             ATTRIBUTE10
       ,TABLE1.PARTY_TYPE_CODE                         PARTY_TYPE_CODE
       ,TABLE1.PARTY_TYPE                              PARTY_TYPE
       ,substr(PARTY_INFO,1,instr(PARTY_INFO,''|'',1,1)-1 )                                                           PARTY_NUMBER
       ,substr(PARTY_INFO,instr(PARTY_INFO,''|'',1,1)+1,(instr(PARTY_INFO,''|'',1,2)-1-instr(PARTY_INFO,''|'',1,1)))  PARTY_NAME
       ,substr(PARTY_INFO,instr(PARTY_INFO,''|'',1,2)+1,(instr(PARTY_INFO,''|'',1,3)-1-instr(PARTY_INFO,''|'',1,2)))  PARTY_TYPE_TAXPAYER_ID
       ,substr(PARTY_INFO,instr(PARTY_INFO,''|'',1,3)+1,(instr(PARTY_INFO,''|'',1,4)-1-instr(PARTY_INFO,''|'',1,3)))  PARTY_TAX_REGISTRATION_NUMBER
       ,substr(PARTY_INFO,instr(PARTY_INFO,''|'',1,4)+1,(instr(PARTY_INFO,''|'',1,5)-1-instr(PARTY_INFO,''|'',1,4)))  PARTY_SITE_NUMBER
       ,substr(PARTY_INFO,instr(PARTY_INFO,''|'',1,5)+1,(instr(PARTY_INFO,''|'',1,6)-1-instr(PARTY_INFO,''|'',1,5)))  PARTY_SITE_NAME
       ,substr(PARTY_INFO,instr(PARTY_INFO,''|'',1,6)+1,(length(PARTY_INFO)- instr(PARTY_INFO,''|'',1,6)))          PARTY_SITE_TAX_RGSTN_NUMBER
       ,substr(USERIDS,1,instr(USERIDS,''|'',1,1)-1)                                                        USER_TRX_IDENTIFIER_NAME_1
       ,substr(USERIDS,instr(USERIDS,''|'',1,1)+1,(instr(USERIDS,''|'',1,2)-1-instr(USERIDS,''|'',1,1)))    USER_TRX_IDENTIFIER_VALUE_1
       ,substr(USERIDS,instr(USERIDS,''|'',1,2)+1,(instr(USERIDS,''|'',1,3)-1-instr(USERIDS,''|'',1,2)))    USER_TRX_IDENTIFIER_NAME_2
       ,substr(USERIDS,instr(USERIDS,''|'',1,3)+1,(instr(USERIDS,''|'',1,4)-1-instr(USERIDS,''|'',1,3)))    USER_TRX_IDENTIFIER_VALUE_2
       ,substr(USERIDS,instr(USERIDS,''|'',1,4)+1,(instr(USERIDS,''|'',1,5)-1-instr(USERIDS,''|'',1,4)))    USER_TRX_IDENTIFIER_NAME_3
       ,substr(USERIDS,instr(USERIDS,''|'',1,5)+1,(instr(USERIDS,''|'',1,6)-1-instr(USERIDS,''|'',1,5)))    USER_TRX_IDENTIFIER_VALUE_3
       ,substr(USERIDS,instr(USERIDS,''|'',1,6)+1,(instr(USERIDS,''|'',1,7)-1-instr(USERIDS,''|'',1,6)))    USER_TRX_IDENTIFIER_NAME_4
       ,substr(USERIDS,instr(USERIDS,''|'',1,7)+1,(instr(USERIDS,''|'',1,8)-1-instr(USERIDS,''|'',1,7)))    USER_TRX_IDENTIFIER_VALUE_4
       ,substr(USERIDS,instr(USERIDS,''|'',1,8)+1,(instr(USERIDS,''|'',1,9)-1-instr(USERIDS,''|'',1,8)))    USER_TRX_IDENTIFIER_NAME_5
       ,substr(USERIDS,instr(USERIDS,''|'',1,9)+1,(instr(USERIDS,''|'',1,10)-1-instr(USERIDS,''|'',1,9)))   USER_TRX_IDENTIFIER_VALUE_5
       ,substr(USERIDS,instr(USERIDS,''|'',1,10)+1,(instr(USERIDS,''|'',1,11)-1-instr(USERIDS,''|'',1,10))) USER_TRX_IDENTIFIER_NAME_6
       ,substr(USERIDS,instr(USERIDS,''|'',1,11)+1,(instr(USERIDS,''|'',1,12)-1-instr(USERIDS,''|'',1,11))) USER_TRX_IDENTIFIER_VALUE_6
       ,substr(USERIDS,instr(USERIDS,''|'',1,12)+1,(instr(USERIDS,''|'',1,13)-1-instr(USERIDS,''|'',1,12))) USER_TRX_IDENTIFIER_NAME_7
       ,substr(USERIDS,instr(USERIDS,''|'',1,13)+1,(instr(USERIDS,''|'',1,14)-1-instr(USERIDS,''|'',1,13))) USER_TRX_IDENTIFIER_VALUE_7
       ,substr(USERIDS,instr(USERIDS,''|'',1,14)+1,(instr(USERIDS,''|'',1,15)-1-instr(USERIDS,''|'',1,14))) USER_TRX_IDENTIFIER_NAME_8
       ,substr(USERIDS,instr(USERIDS,''|'',1,15)+1,(instr(USERIDS,''|'',1,16)-1-instr(USERIDS,''|'',1,15))) USER_TRX_IDENTIFIER_VALUE_8
       ,substr(USERIDS,instr(USERIDS,''|'',1,16)+1,(instr(USERIDS,''|'',1,17)-1-instr(USERIDS,''|'',1,16))) USER_TRX_IDENTIFIER_NAME_9
       ,substr(USERIDS,instr(USERIDS,''|'',1,17)+1,(instr(USERIDS,''|'',1,18)-1-instr(USERIDS,''|'',1,17))) USER_TRX_IDENTIFIER_VALUE_9
       ,substr(USERIDS,instr(USERIDS,''|'',1,18)+1,(instr(USERIDS,''|'',1,19)-1-instr(USERIDS,''|'',1,18))) USER_TRX_IDENTIFIER_NAME_10
       ,substr(USERIDS,instr(USERIDS,''|'',1,19)+1,(length(USERIDS)-instr(USERIDS,''|'',1,19)))             USER_TRX_IDENTIFIER_VALUE_10';

        p_main_lgr_sgmt_col           :=
            ',TABLE1.LEDGER_ID                               LEDGER_ID
       ,TABLE1.LEDGER_SHORT_NAME                       LEDGER_SHORT_NAME
       ,TABLE1.LEDGER_DESCRIPTION                      LEDGER_DESCRIPTION
       ,TABLE1.LEDGER_NAME                             LEDGER_NAME
       ,TABLE1.LEDGER_CURRENCY                         LEDGER_CURRENCY
       ,TABLE1.PERIOD_YEAR                             PERIOD_YEAR
       ,TABLE1.PERIOD_NUMBER                           PERIOD_NUMBER
       ,TABLE1.PERIOD_NAME                             PERIOD_NAME
       ,TABLE1.PERIOD_START_DATE                       PERIOD_START_DATE
       ,TABLE1.PERIOD_END_DATE                         PERIOD_END_DATE
       ,TABLE1.BALANCE_TYPE_CODE                       BALANCE_TYPE_CODE
       ,TABLE1.BALANCE_TYPE                            BALANCE_TYPE
       ,TABLE1.BUDGET_NAME                             BUDGET_NAME
       ,TABLE1.ENCUMBRANCE_TYPE                        ENCUMBRANCE_TYPE
       ,TABLE1.BEGIN_BALANCE_DR                        BEGIN_BALANCE_DR
       ,TABLE1.BEGIN_BALANCE_CR                        BEGIN_BALANCE_CR
       ,TABLE1.PERIOD_NET_DR                           PERIOD_NET_DR
       ,TABLE1.PERIOD_NET_CR                           PERIOD_NET_CR
       ,TABLE1.CODE_COMBINATION_ID                     CODE_COMBINATION_ID
       ,TABLE1.ACCOUNTING_CODE_COMBINATION             ACCOUNTING_CODE_COMBINATION
       ,TABLE1.CODE_COMBINATION_DESCRIPTION            CODE_COMBINATION_DESCRIPTION
       ,TABLE1.CONTROL_ACCOUNT_FLAG                    CONTROL_ACCOUNT_FLAG
       ,TABLE1.CONTROL_ACCOUNT                         CONTROL_ACCOUNT
       ,TABLE1.BALANCING_SEGMENT                       BALANCING_SEGMENT
       ,TABLE1.NATURAL_ACCOUNT_SEGMENT                 NATURAL_ACCOUNT_SEGMENT
       ,TABLE1.COST_CENTER_SEGMENT                     COST_CENTER_SEGMENT
       ,TABLE1.MANAGEMENT_SEGMENT                      MANAGEMENT_SEGMENT
       ,TABLE1.INTERCOMPANY_SEGMENT                    INTERCOMPANY_SEGMENT
       ,TABLE1.BALANCING_SEGMENT_DESC                  BALANCING_SEGMENT_DESC
       ,TABLE1.NATURAL_ACCOUNT_DESC                    NATURAL_ACCOUNT_DESC
       ,TABLE1.COST_CENTER_DESC                        COST_CENTER_DESC
       ,TABLE1.MANAGEMENT_SEGMENT_DESC                 MANAGEMENT_SEGMENT_DESC
       ,TABLE1.INTERCOMPANY_SEGMENT_DESC               INTERCOMPANY_SEGMENT_DESC
       ,TABLE1.SEGMENT1                                SEGMENT1
       ,TABLE1.SEGMENT2                                SEGMENT2
       ,TABLE1.SEGMENT3                                SEGMENT3
       ,TABLE1.SEGMENT4                                SEGMENT4
       ,TABLE1.SEGMENT5                                SEGMENT5
       ,TABLE1.SEGMENT6                                SEGMENT6
       ,TABLE1.SEGMENT7                                SEGMENT7
       ,TABLE1.SEGMENT8                                SEGMENT8
       ,TABLE1.SEGMENT9                                SEGMENT9
       ,TABLE1.SEGMENT10                               SEGMENT10
       ,TABLE1.SEGMENT11                               SEGMENT11
       ,TABLE1.SEGMENT12                               SEGMENT12
       ,TABLE1.SEGMENT13                               SEGMENT13
       ,TABLE1.SEGMENT14                               SEGMENT14
       ,TABLE1.SEGMENT15                               SEGMENT15
       ,TABLE1.SEGMENT16                               SEGMENT16
       ,TABLE1.SEGMENT17                               SEGMENT17
       ,TABLE1.SEGMENT18                               SEGMENT18
       ,TABLE1.SEGMENT19                               SEGMENT19
       ,TABLE1.SEGMENT20                               SEGMENT20
       ,TABLE1.SEGMENT21                               SEGMENT21
       ,TABLE1.SEGMENT22                               SEGMENT22
       ,TABLE1.SEGMENT23                               SEGMENT23
       ,TABLE1.SEGMENT24                               SEGMENT24
       ,TABLE1.SEGMENT25                               SEGMENT25
       ,TABLE1.SEGMENT26                               SEGMENT26
       ,TABLE1.SEGMENT27                               SEGMENT27
       ,TABLE1.SEGMENT28                               SEGMENT28
       ,TABLE1.SEGMENT29                               SEGMENT29
       ,TABLE1.SEGMENT30                               SEGMENT30
       ,TABLE1.BEGIN_RUNNING_TOTAL_CR                  BEGIN_RUNNING_TOTAL_CR
       ,TABLE1.BEGIN_RUNNING_TOTAL_DR                  BEGIN_RUNNING_TOTAL_DR
       ,TABLE1.END_RUNNING_TOTAL_CR                    END_RUNNING_TOTAL_CR
       ,TABLE1.END_RUNNING_TOTAL_DR                    END_RUNNING_TOTAL_DR';

        p_main_le_col                 :=
            ',TABLE1.LEGAL_ENTITY_ID                         LEGAL_ENTITY_ID
       ,TABLE1.LEGAL_ENTITY_NAME                       LEGAL_ENTITY_NAME
       ,TABLE1.LE_ADDRESS_LINE_1                       LE_ADDRESS_LINE_1
       ,TABLE1.LE_ADDRESS_LINE_2                       LE_ADDRESS_LINE_2
       ,TABLE1.LE_ADDRESS_LINE_3                       LE_ADDRESS_LINE_3
       ,TABLE1.LE_CITY                                 LE_CITY
       ,TABLE1.LE_REGION_1                             LE_REGION_1
       ,TABLE1.LE_REGION_2                             LE_REGION_2
       ,TABLE1.LE_REGION_3                             LE_REGION_3
       ,TABLE1.LE_POSTAL_CODE                          LE_POSTAL_CODE
       ,TABLE1.LE_COUNTRY                              LE_COUNTRY
       ,TABLE1.LE_REGISTRATION_NUMBER                  LE_REGISTRATION_NUMBER
       ,TABLE1.LE_REGISTRATION_EFFECTIVE_FROM          LE_REGISTRATION_EFFECTIVE_FROM
       ,TABLE1.LE_BR_DAILY_INSCRIPTION_NUMBER          LE_BR_DAILY_INSCRIPTION_NUMBER
       ,TABLE1.LE_BR_DAILY_INSCRIPTION_DATE            LE_BR_DAILY_INSCRIPTION_DATE
       ,TABLE1.LE_BR_DAILY_ENTITY                      LE_BR_DAILY_ENTITY
       ,TABLE1.LE_BR_DAILY_LOCATION                    LE_BR_DAILY_LOCATION
       ,TABLE1.LE_BR_DIRECTOR_NUMBER                   LE_BR_DIRECTOR_NUMBER
       ,TABLE1.LE_BR_ACCOUNTANT_NUMBER                 LE_BR_ACCOUNTANT_NUMBER
       ,TABLE1.LE_BR_ACCOUNTANT_NAME                   LE_BR_ACCOUNTANT_NAME';

        p_sla_col_start               :=
            'SELECT   /*+ leading (glbgt gjl gjh gir ael aeh) */
	      to_char(aeh.accounting_date
                 ,''YYYY-MM-DD'')                      GL_DATE
         ,fdu.user_name                                CREATED_BY
         ,to_char(aeh.creation_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')           CREATION_DATE
         ,to_char(aeh.last_update_date
                 ,''YYYY-MM-DD'')                      LAST_UPDATE_DATE
         ,to_char(aeh.gl_transfer_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')           GL_TRANSFER_DATE
         ,to_char(aeh.reference_date
                 ,''YYYY-MM-DD'')                      REFERENCE_DATE
         ,to_char(aeh.completed_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')           COMPLETED_DATE
         ,ent.transaction_number                       TRANSACTION_NUMBER
		 ,xxdo_xla_acct_analysis_rpt_pkg.get_voucher_num(gjst.user_je_source_name
						 ,ent.source_id_int_1
						 ,ent_upg.SOURCE_ID_INT_1)	   VOUCHER_NUMBER								-- Added by #BT Technology Team V1.1 17/Nov/2014
         ,to_char(xle.transaction_date
				  , ''DD-MON-YYYY'')				   TRANSACTION_DATE								-- Added by #BT Technology Team V1.1 17/Nov/2014
        --         ,''YYYY-MM-DD"T"hh:mi:ss'')         TRANSACTION_DATE								-- Added by #BT Technology Team V1.1 17/Nov/2014
         ,fsv1.header_name                             ACCOUNTING_SEQUENCE_NAME
         ,fsv1.version_name                            ACCOUNTING_SEQUENCE_VERSION
         ,aeh.completion_acct_seq_value                ACCOUNTING_SEQUENCE_NUMBER
         ,fsv2.header_name                             REPORTING_SEQUENCE_NAME
         ,fsv2.version_name                            REPORTING_SEQUENCE_VERSION
         ,aeh.close_acct_seq_value                     REPORTING_SEQUENCE_NUMBER
         ,NULL                                         DOCUMENT_CATEGORY
         ,fns.name                                     DOCUMENT_SEQUENCE_NAME
         ,aeh.doc_sequence_value                       DOCUMENT_SEQUENCE_NUMBER
         ,fns1.name                                    GL_DOCUMENT_SEQUENCE_NAME
         ,gjh.doc_sequence_value                       GL_DOCUMENT_SEQUENCE_NUMBER
         ,aeh.application_id                           APPLICATION_ID
         ,fap.application_name                         APPLICATION_NAME
         ,aeh.ae_header_id                             HEADER_ID
         ,aeh.description                              HEADER_DESCRIPTION
         ,xlk1.meaning                                 FUND_STATUS
         ,gjct.user_je_category_name                   JE_CATEGORY_NAME
         ,gjst.user_je_source_name                     JE_SOURCE_NAME
         ,xle.event_id                                 EVENT_ID
         ,to_char(xle.event_date
                 ,''YYYY-MM-DD'')                      EVENT_DATE
         ,xle.event_number                             EVENT_NUMBER
         ,xet.event_class_code                         EVENT_CLASS_CODE
         ,xect.NAME                                    EVENT_CLASS_NAME
         ,aeh.event_type_code                          EVENT_TYPE_CODE
         ,xet.NAME                                     EVENT_TYPE_NAME
         ,gjb.NAME                                     GL_BATCH_NAME
         ,to_char(gjb.posted_date
                 ,''YYYY-MM-DD'')                      POSTED_DATE
         ,gjh.NAME                                     GL_JE_NAME
         ,gjh.external_reference                       EXTERNAL_REFERENCE
         ,gjl.je_line_num                              GL_LINE_NUMBER
         ,ael.displayed_line_number                    LINE_NUMBER
		 ,ael.ae_line_num                              ORIG_LINE_NUMBER
         ,ael.accounting_class_code                    ACCOUNTING_CLASS_CODE
         ,xlk2.meaning                                 ACCOUNTING_CLASS_NAME
         ,ael.description                              LINE_DESCRIPTION
         ,ael.currency_code                            ENTERED_CURRENCY
		 ,round(ael.currency_conversion_rate
			    ,(SELECT fc.extended_precision
                  FROM   fnd_currencies fc
                  WHERE  fc.currency_code = ael.currency_code)) CONVERSION_RATE				-- Added by #BT Technology Team V1.1 17/Nov/2014

     --  ,ael.currency_conversion_rate                 CONVERSION_RATE						-- Commented by #BT Technology Team V1.1 17/Nov/2014
         ,to_char(ael.currency_conversion_date
                 ,''YYYY-MM-DD'')                      CONVERSION_RATE_DATE
         ,ael.currency_conversion_type                 CONVERSION_RATE_TYPE_CODE
         ,gdct.user_conversion_type                    CONVERSION_RATE_TYPE
         ,ael.entered_dr                               ENTERED_DR
         ,ael.entered_cr                               ENTERED_CR
         ,ael.unrounded_accounted_dr                   UNROUNDED_ACCOUNTED_DR
         ,ael.unrounded_accounted_cr                   UNROUNDED_ACCOUNTED_CR
         ,ael.accounted_dr                             ACCOUNTED_DR
         ,ael.accounted_cr                             ACCOUNTED_CR
         ,ael.statistical_amount                       STATISTICAL_AMOUNT
         ,ael.jgzz_recon_ref                           RECONCILIATION_REFERENCE
         ,ael.attribute_category                       ATTRIBUTE_CATEGORY
         ,ael.attribute1                               ATTRIBUTE1
         ,ael.attribute2                               ATTRIBUTE2
         ,ael.attribute3                               ATTRIBUTE3
         ,ael.attribute4                               ATTRIBUTE4
         ,ael.attribute5                               ATTRIBUTE5
         ,ael.attribute6                               ATTRIBUTE6
         ,ael.attribute7                               ATTRIBUTE7
         ,ael.attribute8                               ATTRIBUTE8
         ,ael.attribute9                               ATTRIBUTE9
         ,ael.attribute10                              ATTRIBUTE10
         ,ael.party_type_code                          PARTY_TYPE_CODE
         ,NULL                                         PARTY_TYPE';

        -- Start of Change as per CCR0009873

        p_sla_col_start_arch          :=
            'SELECT   /*+ leading (glbgt gjl gjh gir ael aeh) */
	      to_char(aeh.accounting_date
                 ,''YYYY-MM-DD'')                      GL_DATE
         ,fdu.user_name                                CREATED_BY
         ,to_char(aeh.creation_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')           CREATION_DATE
         ,to_char(aeh.last_update_date
                 ,''YYYY-MM-DD'')                      LAST_UPDATE_DATE
         ,to_char(aeh.gl_transfer_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')           GL_TRANSFER_DATE
         ,to_char(aeh.reference_date
                 ,''YYYY-MM-DD'')                      REFERENCE_DATE
         ,to_char(aeh.completed_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')           COMPLETED_DATE
         ,ent.transaction_number                       TRANSACTION_NUMBER
		 ,xxdo_xla_acct_analysis_rpt_pkg.get_voucher_num(gjst.user_je_source_name
						 ,ent.source_id_int_1
						 ,ent_upg.SOURCE_ID_INT_1)	   VOUCHER_NUMBER								-- Added by #BT Technology Team V1.1 17/Nov/2014
         ,to_char(xle.transaction_date
				  , ''DD-MON-YYYY'')				   TRANSACTION_DATE								-- Added by #BT Technology Team V1.1 17/Nov/2014
        --         ,''YYYY-MM-DD"T"hh:mi:ss'')         TRANSACTION_DATE								-- Added by #BT Technology Team V1.1 17/Nov/2014
         ,fsv1.header_name                             ACCOUNTING_SEQUENCE_NAME
         ,fsv1.version_name                            ACCOUNTING_SEQUENCE_VERSION
         ,aeh.completion_acct_seq_value                ACCOUNTING_SEQUENCE_NUMBER
         ,fsv2.header_name                             REPORTING_SEQUENCE_NAME
         ,fsv2.version_name                            REPORTING_SEQUENCE_VERSION
         ,aeh.close_acct_seq_value                     REPORTING_SEQUENCE_NUMBER
         ,NULL                                         DOCUMENT_CATEGORY
         ,fns.name                                     DOCUMENT_SEQUENCE_NAME
         ,aeh.doc_sequence_value                       DOCUMENT_SEQUENCE_NUMBER
         ,fns1.name                                    GL_DOCUMENT_SEQUENCE_NAME
         ,gjh.doc_sequence_value                       GL_DOCUMENT_SEQUENCE_NUMBER
         ,aeh.application_id                           APPLICATION_ID
         ,fap.application_name                         APPLICATION_NAME
         ,aeh.ae_header_id                             HEADER_ID
         ,aeh.description                              HEADER_DESCRIPTION
         ,xlk1.meaning                                 FUND_STATUS
         ,gjct.user_je_category_name                   JE_CATEGORY_NAME
         ,gjst.user_je_source_name                     JE_SOURCE_NAME
         ,xle.event_id                                 EVENT_ID
         ,to_char(xle.event_date
                 ,''YYYY-MM-DD'')                      EVENT_DATE
         ,xle.event_number                             EVENT_NUMBER
         ,xet.event_class_code                         EVENT_CLASS_CODE
         ,xect.NAME                                    EVENT_CLASS_NAME
         ,aeh.event_type_code                          EVENT_TYPE_CODE
         ,xet.NAME                                     EVENT_TYPE_NAME
         ,gjb.NAME                                     GL_BATCH_NAME
         ,to_char(gjb.posted_date
                 ,''YYYY-MM-DD'')                      POSTED_DATE
         ,gjh.NAME                                     GL_JE_NAME
         ,gjh.external_reference                       EXTERNAL_REFERENCE
         ,gjl.je_line_num                              GL_LINE_NUMBER
         ,ael.displayed_line_number                    LINE_NUMBER
		 ,ael.ae_line_num                              ORIG_LINE_NUMBER
         ,ael.accounting_class_code                    ACCOUNTING_CLASS_CODE
         ,xlk2.meaning                                 ACCOUNTING_CLASS_NAME
         ,ael.description                              LINE_DESCRIPTION
         ,ael.currency_code                            ENTERED_CURRENCY
		 ,round(ael.currency_conversion_rate
			    ,(SELECT fc.extended_precision
                  FROM   fnd_currencies fc
                  WHERE  fc.currency_code = ael.currency_code)) CONVERSION_RATE				-- Added by #BT Technology Team V1.1 17/Nov/2014

     --  ,ael.currency_conversion_rate                 CONVERSION_RATE						-- Commented by #BT Technology Team V1.1 17/Nov/2014
         ,to_char(ael.currency_conversion_date
                 ,''YYYY-MM-DD'')                      CONVERSION_RATE_DATE
         ,ael.currency_conversion_type                 CONVERSION_RATE_TYPE_CODE
         ,gdct.user_conversion_type                    CONVERSION_RATE_TYPE
         ,ael.entered_dr                               ENTERED_DR
         ,ael.entered_cr                               ENTERED_CR
         ,ael.unrounded_accounted_dr                   UNROUNDED_ACCOUNTED_DR
         ,ael.unrounded_accounted_cr                   UNROUNDED_ACCOUNTED_CR
         ,ael.accounted_dr                             ACCOUNTED_DR
         ,ael.accounted_cr                             ACCOUNTED_CR
         ,ael.statistical_amount                       STATISTICAL_AMOUNT
         ,ael.jgzz_recon_ref                           RECONCILIATION_REFERENCE
         ,ael.attribute_category                       ATTRIBUTE_CATEGORY
         ,ael.attribute1                               ATTRIBUTE1
         ,ael.attribute2                               ATTRIBUTE2
         ,ael.attribute3                               ATTRIBUTE3
         ,ael.attribute4                               ATTRIBUTE4
         ,ael.attribute5                               ATTRIBUTE5
         ,ael.attribute6                               ATTRIBUTE6
         ,ael.attribute7                               ATTRIBUTE7
         ,ael.attribute8                               ATTRIBUTE8
         ,ael.attribute9                               ATTRIBUTE9
         ,ael.attribute10                              ATTRIBUTE10
         ,ael.party_type_code                          PARTY_TYPE_CODE
         ,NULL                                         PARTY_TYPE';

        -- End of Change for CCR0009873

        p_gt_lgr_sgmt_col             :=
            ',glbgt.ledger_id                              LEDGER_ID
         ,glbgt.ledger_short_name                      LEDGER_SHORT_NAME
         ,glbgt.ledger_description                     LEDGER_DESCRIPTION
         ,glbgt.ledger_name                            LEDGER_NAME
         ,glbgt.ledger_currency                        LEDGER_CURRENCY
         ,glbgt.period_year                            PERIOD_YEAR
         ,glbgt.period_number                          PERIOD_NUMBER
         ,glbgt.period_name                            PERIOD_NAME
         ,to_char(glbgt.period_start_date
                                 ,''YYYY-MM-DD'')      PERIOD_START_DATE
         ,to_char(glbgt.period_end_date
                                 ,''YYYY-MM-DD'')      PERIOD_END_DATE
         ,glbgt.balance_type_code                      BALANCE_TYPE_CODE
         ,glbgt.balance_type                           BALANCE_TYPE
         ,glbgt.budget_name                            BUDGET_NAME
         ,glbgt.encumbrance_type                       ENCUMBRANCE_TYPE
         ,glbgt.begin_balance_dr                       BEGIN_BALANCE_DR
         ,glbgt.begin_balance_cr                       BEGIN_BALANCE_CR
         ,glbgt.period_net_dr                          PERIOD_NET_DR
         ,glbgt.period_net_cr                          PERIOD_NET_CR
         ,glbgt.code_combination_id                    CODE_COMBINATION_ID
         ,glbgt.accounting_code_combination            ACCOUNTING_CODE_COMBINATION
         ,glbgt.code_combination_description           CODE_COMBINATION_DESCRIPTION
         ,glbgt.control_account_flag                   CONTROL_ACCOUNT_FLAG
         ,glbgt.control_account                        CONTROL_ACCOUNT
         ,glbgt.balancing_segment                      BALANCING_SEGMENT
         ,glbgt.natural_account_segment                NATURAL_ACCOUNT_SEGMENT
         ,glbgt.cost_center_segment                    COST_CENTER_SEGMENT
         ,glbgt.management_segment                     MANAGEMENT_SEGMENT
         ,glbgt.intercompany_segment                   INTERCOMPANY_SEGMENT
         ,glbgt.balancing_segment_desc                 BALANCING_SEGMENT_DESC
         ,glbgt.natural_account_desc                   NATURAL_ACCOUNT_DESC
         ,glbgt.cost_center_desc                       COST_CENTER_DESC
         ,glbgt.management_segment_desc                MANAGEMENT_SEGMENT_DESC
         ,glbgt.intercompany_segment_desc              INTERCOMPANY_SEGMENT_DESC
         ,glbgt.segment1                               SEGMENT1
         ,glbgt.segment2                               SEGMENT2
         ,glbgt.segment3                               SEGMENT3
         ,glbgt.segment4                               SEGMENT4
         ,glbgt.segment5                               SEGMENT5
         ,glbgt.segment6                               SEGMENT6
         ,glbgt.segment7                               SEGMENT7
         ,glbgt.segment8                               SEGMENT8
         ,glbgt.segment9                               SEGMENT9
         ,glbgt.segment10                              SEGMENT10
         ,glbgt.segment11                              SEGMENT11
         ,glbgt.segment12                              SEGMENT12
         ,glbgt.segment13                              SEGMENT13
         ,glbgt.segment14                              SEGMENT14
         ,glbgt.segment15                              SEGMENT15
         ,glbgt.segment16                              SEGMENT16
         ,glbgt.segment17                              SEGMENT17
         ,glbgt.segment18                              SEGMENT18
         ,glbgt.segment19                              SEGMENT19
         ,glbgt.segment20                              SEGMENT20
         ,glbgt.segment21                              SEGMENT21
         ,glbgt.segment22                              SEGMENT22
         ,glbgt.segment23                              SEGMENT23
         ,glbgt.segment24                              SEGMENT24
         ,glbgt.segment25                              SEGMENT25
         ,glbgt.segment26                              SEGMENT26
         ,glbgt.segment27                              SEGMENT27
         ,glbgt.segment28                              SEGMENT28
         ,glbgt.segment29                              SEGMENT29
         ,glbgt.segment30                              SEGMENT30
         ,glbgt.begin_running_total_cr                 BEGIN_RUNNING_TOTAL_CR
         ,glbgt.begin_running_total_dr                 BEGIN_RUNNING_TOTAL_DR
         ,glbgt.end_running_total_cr                   END_RUNNING_TOTAL_CR
         ,glbgt.end_running_total_dr                   END_RUNNING_TOTAL_DR';

        p_gt_le_col                   :=
            ',glbgt.legal_entity_id                        LEGAL_ENTITY_ID
         ,glbgt.legal_entity_name                      LEGAL_ENTITY_NAME
         ,glbgt.le_address_line_1                      LE_ADDRESS_LINE_1
         ,glbgt.le_address_line_2                      LE_ADDRESS_LINE_2
         ,glbgt.le_address_line_3                      LE_ADDRESS_LINE_3
         ,glbgt.le_city                                LE_CITY
         ,glbgt.le_region_1                            LE_REGION_1
         ,glbgt.le_region_2                            LE_REGION_2
         ,glbgt.le_region_3                            LE_REGION_3
         ,glbgt.le_postal_code                         LE_POSTAL_CODE
         ,glbgt.le_country                             LE_COUNTRY
         ,glbgt.le_registration_number                 LE_REGISTRATION_NUMBER
         ,glbgt.le_registration_effective_from         LE_REGISTRATION_EFFECTIVE_FROM
         ,glbgt.le_br_daily_inscription_number         LE_BR_DAILY_INSCRIPTION_NUMBER
         ,to_char(glbgt.le_br_daily_inscription_date
                                ,''YYYY-MM-DD'')       LE_BR_DAILY_INSCRIPTION_DATE
         ,glbgt.le_br_daily_entity                     LE_BR_DAILY_ENTITY
         ,glbgt.le_br_daily_location                   LE_BR_DAILY_LOCATION
         ,glbgt.le_br_director_number                  LE_BR_DIRECTOR_NUMBER
         ,glbgt.le_br_accountant_number                LE_BR_ACCOUNTANT_NUMBER
         ,glbgt.le_br_accountant_name                  LE_BR_ACCOUNTANT_NAME';

        p_sla_from                    :=
            'FROM
         xla_ae_headers                   aeh
        ,xla_ae_lines                     ael
        ,xla_lookups                      xlk1
        ,xla_lookups                      xlk2
        ,xla_events                       xle
        ,xla_event_classes_tl             xect
        ,xla_event_types_tl               xet
        ,fnd_user                         fdu
        ,xla_transaction_entities         ent
		,xla_transaction_entities_upg	  ent_upg				-- Added by #BT Technology Team V1.1 17/Nov/2014
        ,fnd_application_tl               fap
        ,fun_seq_versions                 fsv1
        ,fun_seq_versions                 fsv2
        ,fnd_document_sequences           fns
	,fnd_document_sequences           fns1
        ,gl_je_categories_tl              gjct
        ,gl_je_sources_tl                 gjst
        ,gl_daily_conversion_types        gdct
        ,gl_import_references             gir
        ,gl_je_lines                      gjl
        ,gl_je_headers                    gjh
        ,gl_je_batches                    gjb
        ,xla_report_balances_gt           glbgt';

        -- -- Start of Change as per CCR0009873

        p_sla_from_arch               :=
            'FROM
         xla_ae_headers                   aeh
        ,xla_ae_lines                     ael
        ,xla_lookups                      xlk1
        ,xla_lookups                      xlk2
        ,xla_events                       xle
        ,xla_event_classes_tl             xect
        ,xla_event_types_tl               xet
        ,fnd_user                         fdu
        ,xla_transaction_entities         ent
		,xla_transaction_entities_upg	  ent_upg				-- Added by #BT Technology Team V1.1 17/Nov/2014
        ,fnd_application_tl               fap
        ,fun_seq_versions                 fsv1
        ,fun_seq_versions                 fsv2
        ,fnd_document_sequences           fns
	,fnd_document_sequences           fns1
        ,gl_je_categories_tl              gjct
        ,gl_je_sources_tl                 gjst
        ,gl_daily_conversion_types        gdct
        ,XXDO.XXD_GL_ARCHIVE_REFERENCES             gir
        ,xxdo.XXD_GL_ARCHIVE_LINES                      gjl
        ,xxdo.XXD_GL_ARCHIVE_HEADERS                    gjh
        ,XXDO.XXD_GL_ARCHIVE_BATCHES                    gjb
        ,xla_report_balances_gt           glbgt';

        -- -- End of Change as per CCR0009873

        p_sla_main_filter             :=
            '
       AND    gjl.ledger_id                    = glbgt.ledger_id
        AND    gjl.code_combination_id          = glbgt.code_combination_id
	AND    gjl.period_name                  = glbgt.period_name
	--AND   gjl.effective_date               BETWEEN glbgt.period_start_date AND glbgt.period_end_date
	--AND   gjl.effective_date               BETWEEN :P_GL_DATE_FROM AND :P_GL_DATE_TO
	AND    gjl.je_header_id                   = gjh.je_header_id
	AND    gjl.period_name                    = gjh.period_name
	AND    gjl.je_header_id                   = gir.je_header_id
	AND    gjl.je_line_num                    = gir.je_line_num
	AND    gjh.je_header_id                   = gir.je_header_id
	AND    gjh.status                         = ''P''
	AND    fns1.application_id(+)              = 101
	AND    fns1.doc_sequence_id(+)             = gjh.doc_sequence_id
	AND    NVL(gjh.je_from_sla_flag,''N'')      IN(''Y'',''U'')
	AND    gjb.je_batch_id                    = gir.je_batch_id
	AND    gjb.status                         = ''P''
	AND    gir.gl_sl_link_id                  = ael.gl_sl_link_id
	AND    gir.gl_sl_link_table               = ael.gl_sl_link_table
	--AND  gjh.currency_code                    = glbgt.ledger_currency --added bug 6722505
	AND    gjct.je_category_name              = aeh.je_category_name
	AND    gjct.LANGUAGE                      = USERENV(''LANG'')
	AND    gjst.je_source_name                = gjh.je_source
	AND    gjst.LANGUAGE                      = USERENV(''LANG'')
	AND    aeh.accounting_entry_status_code   = ''F''
	AND    aeh.gl_transfer_status_code        = ''Y''
	AND    aeh.balance_type_code              = glbgt.balance_type_code
	AND    NVL(aeh.budget_version_id,-19999)  = NVL(glbgt.budget_version_id,-19999)
	AND    ael.application_id                 = aeh.application_id
	AND    ael.ae_header_id                   = aeh.ae_header_id
	AND    NVL(ael.encumbrance_type_id,-19999)= NVL(glbgt.encumbrance_type_id,-19999)  -- 4458381
	AND    xlk1.lookup_type(+)                = ''XLA_FUNDS_STATUS''
	AND    xlk1.lookup_code(+)                = aeh.funds_status_code
	AND    xlk2.lookup_type                   = ''XLA_ACCOUNTING_CLASS''
	AND    xlk2.lookup_code                   = ael.accounting_class_code
	AND    xle.application_id                 = aeh.application_id
	AND    xle.event_id                       = aeh.event_id
	AND    xet.application_id                 = aeh.application_id
	AND    xet.event_type_code                = aeh.event_type_code
	AND    xet.LANGUAGE                       = USERENV(''LANG'')
	AND    xect.application_id                = xet.application_id
	AND    xect.entity_code                   = xet.entity_code
	AND    xect.event_class_code              = xet.event_class_code
	AND    xect.LANGUAGE                      = USERENV(''LANG'')
	AND    ent.application_id                 = aeh.application_id
	AND    ent.entity_id                      = aeh.entity_id
	AND    ent_upg.application_id(+)		  = aeh.application_id									 -- Added by #BT Technology Team V1.1 17/Nov/2014
	AND	   ent_upg.entity_id(+)				  = aeh.entity_id										 -- Added by #BT Technology Team V1.1 17/Nov/2014
  --AND    ent.ledger_id                      = aeh.ledger_id removed for Bug 7557990
	AND    fdu.user_id                        = ent.created_by
	AND    fap.application_id                 = aeh.application_id
	AND    fap.LANGUAGE                       = USERENV(''LANG'')
	AND    fsv1.seq_version_id(+)             = aeh.completion_acct_seq_version_id
	AND    fsv2.seq_version_id(+)             = aeh.close_acct_seq_version_id
	AND    fns.application_id(+)              = aeh.application_id
	AND    fns.doc_sequence_id(+)             = aeh.doc_sequence_id
	AND    gdct.conversion_type(+)            = ael.currency_conversion_type
	AND    aeh.accounting_date                BETWEEN glbgt.period_start_date AND glbgt.period_end_date
	AND    aeh.accounting_date                BETWEEN :P_GL_DATE_FROM AND :P_GL_DATE_TO';

        p_gl_col_start                :=
            'SELECT  /*+ leading (glbgt gjl gjh gjb) */
              to_char(gjh.default_effective_date
                     ,''YYYY-MM-DD'')                      GL_DATE
             ,fdu.user_name                                CREATED_BY
             ,to_char(gjh.creation_date
                     ,''YYYY-MM-DD"T"hh:mi:ss'')           CREATION_DATE
             ,to_char(gjh.last_update_date
                     ,''YYYY-MM-DD'')                      LAST_UPDATE_DATE
             ,NULL                                         GL_TRANSFER_DATE
             ,to_char(gjh.reference_date
                     ,''YYYY-MM-DD'')                      REFERENCE_DATE
             ,NULL                                         COMPLETED_DATE
             ,NULL                                         TRANSACTION_NUMBER
			 ,NULL										   VOUCHER_NUMBER					-- Added by #BT Technology Team V1.1 17/Nov/2014
             ,NULL                                         TRANSACTION_DATE
             ,fsv1.header_name                             ACCOUNTING_SEQUENCE_NAME
             ,fsv1.version_name                            ACCOUNTING_SEQUENCE_VERSION
             ,gjh.posting_acct_seq_value                   ACCOUNTING_SEQUENCE_NUMBER
             ,fsv2.header_name                             REPORTING_SEQUENCE_NAME
             ,fsv2.version_name                            REPORTING_SEQUENCE_VERSION
             ,gjh.close_acct_seq_value                     REPORTING_SEQUENCE_NUMBER
             ,NULL                                         DOCUMENT_CATEGORY
             ,NULL                                         DOCUMENT_SEQUENCE_NAME
             ,NULL                                         DOCUMENT_SEQUENCE_NUMBER
			 ,fns.name                                     GL_DOCUMENT_SEQUENCE_NAME
             ,gjh.doc_sequence_value                       GL_DOCUMENT_SEQUENCE_NUMBER
             ,NULL                                         APPLICATION_ID
             ,NULL                                         APPLICATION_NAME
             ,gjh.je_header_id                             HEADER_ID
             ,gjh.description                              HEADER_DESCRIPTION
             ,NULL                                         FUND_STATUS
             ,gjct.user_je_category_name                   JE_CATEGORY_NAME
             ,gjst.user_je_source_name                     JE_SOURCE_NAME
             ,NULL                                         EVENT_ID
             ,NULL                                         EVENT_DATE
             ,NULL                                         EVENT_NUMBER
             ,NULL                                         EVENT_CLASS_CODE
             ,NULL                                         EVENT_CLASS_NAME
             ,NULL                                         EVENT_TYPE_CODE
             ,NULL                                         EVENT_TYPE_NAME
             ,gjb.NAME                                     GL_BATCH_NAME
             ,to_char(gjb.posted_date
                     ,''YYYY-MM-DD'')                      POSTED_DATE
             ,gjh.NAME                                     GL_JE_NAME
             ,gjh.external_reference                       EXTERNAL_REFERENCE
             ,gjl.je_line_num                              GL_LINE_NUMBER
             ,gjl.je_line_num                              LINE_NUMBER
             ,gjl.je_line_num                              ORIG_LINE_NUMBER
             ,NULL                                         ACCOUNTING_CLASS_CODE
             ,NULL                                         ACCOUNTING_CLASS_NAME
             ,gjl.description                              LINE_DESCRIPTION
             ,gjh.currency_code                            ENTERED_CURRENCY
       --    ,gjh.currency_conversion_rate                 CONVERSION_RATE						-- Added by #BT Technology Team V1.1 17/Nov/2014
			 ,round(gjh.currency_conversion_rate
				    ,(SELECT fc.extended_precision
					  FROM   fnd_currencies fc
					  WHERE  fc.currency_code = gjh.currency_code)) CONVERSION_RATE				-- Added by #BT Technology Team V1.1 17/Nov/2014
             ,to_char(gjh.currency_conversion_date
                     ,''YYYY-MM-DD'')                      CONVERSION_RATE_DATE
             ,gjh.currency_conversion_type                 CONVERSION_RATE_TYPE_CODE
             ,gdct.user_conversion_type                    CONVERSION_RATE_TYPE
             ,gjl.entered_dr                               ENTERED_DR
             ,gjl.entered_cr                               ENTERED_CR
             ,NULL                                         UNROUNDED_ACCOUNTED_DR
             ,NULL                                         UNROUNDED_ACCOUNTED_CR
             ,gjl.accounted_dr                             ACCOUNTED_DR
             ,gjl.accounted_cr                             ACCOUNTED_CR
             ,gjl.stat_amount                              STATISTICAL_AMOUNT
             ,gjl.jgzz_recon_ref_11i                       RECONCILIATION_REFERENCE
             ,gjl.context                                  ATTRIBUTE_CATEGORY
             ,gjl.attribute1                               ATTRIBUTE1
             ,gjl.attribute2                               ATTRIBUTE2
             ,gjl.attribute3                               ATTRIBUTE3
             ,gjl.attribute4                               ATTRIBUTE4
             ,gjl.attribute5                               ATTRIBUTE5
             ,gjl.attribute6                               ATTRIBUTE6
             ,gjl.attribute7                               ATTRIBUTE7
             ,gjl.attribute8                               ATTRIBUTE8
             ,gjl.attribute9                               ATTRIBUTE9
             ,gjl.attribute10                              ATTRIBUTE10
             ,NULL                                         PARTY_TYPE_CODE
             ,NULL                                         PARTY_TYPE
             ,NULL                                         PARTY_INFO
             ,NULL                                         USERIDS';

        -- -- Start of Change as per CCR0009873

        p_gl_col_start_arch           :=
            'SELECT  /*+ leading (glbgt gjl gjh gjb) */
              to_char(gjh.default_effective_date
                     ,''YYYY-MM-DD'')                      GL_DATE
             ,fdu.user_name                                CREATED_BY
             ,to_char(gjh.creation_date
                     ,''YYYY-MM-DD"T"hh:mi:ss'')           CREATION_DATE
             ,to_char(gjh.last_update_date
                     ,''YYYY-MM-DD'')                      LAST_UPDATE_DATE
             ,NULL                                         GL_TRANSFER_DATE
             ,to_char(gjh.reference_date
                     ,''YYYY-MM-DD'')                      REFERENCE_DATE
             ,NULL                                         COMPLETED_DATE
             ,NULL                                         TRANSACTION_NUMBER
			 ,NULL										   VOUCHER_NUMBER					-- Added by #BT Technology Team V1.1 17/Nov/2014
             ,NULL                                         TRANSACTION_DATE
             ,fsv1.header_name                             ACCOUNTING_SEQUENCE_NAME
             ,fsv1.version_name                            ACCOUNTING_SEQUENCE_VERSION
             ,gjh.posting_acct_seq_value                   ACCOUNTING_SEQUENCE_NUMBER
             ,fsv2.header_name                             REPORTING_SEQUENCE_NAME
             ,fsv2.version_name                            REPORTING_SEQUENCE_VERSION
             ,gjh.close_acct_seq_value                     REPORTING_SEQUENCE_NUMBER
             ,NULL                                         DOCUMENT_CATEGORY
             ,NULL                                         DOCUMENT_SEQUENCE_NAME
             ,NULL                                         DOCUMENT_SEQUENCE_NUMBER
			 ,fns.name                                     GL_DOCUMENT_SEQUENCE_NAME
             ,gjh.doc_sequence_value                       GL_DOCUMENT_SEQUENCE_NUMBER
             ,NULL                                         APPLICATION_ID
             ,NULL                                         APPLICATION_NAME
             ,gjh.je_header_id                             HEADER_ID
             ,gjh.description                              HEADER_DESCRIPTION
             ,NULL                                         FUND_STATUS
             ,gjct.user_je_category_name                   JE_CATEGORY_NAME
             ,gjst.user_je_source_name                     JE_SOURCE_NAME
             ,NULL                                         EVENT_ID
             ,NULL                                         EVENT_DATE
             ,NULL                                         EVENT_NUMBER
             ,NULL                                         EVENT_CLASS_CODE
             ,NULL                                         EVENT_CLASS_NAME
             ,NULL                                         EVENT_TYPE_CODE
             ,NULL                                         EVENT_TYPE_NAME
             ,gjb.NAME                                     GL_BATCH_NAME
             ,to_char(gjb.posted_date
                     ,''YYYY-MM-DD'')                      POSTED_DATE
             ,gjh.NAME                                     GL_JE_NAME
             ,gjh.external_reference                       EXTERNAL_REFERENCE
             ,gjl.je_line_num                              GL_LINE_NUMBER
             ,gjl.je_line_num                              LINE_NUMBER
             ,gjl.je_line_num                              ORIG_LINE_NUMBER
             ,NULL                                         ACCOUNTING_CLASS_CODE
             ,NULL                                         ACCOUNTING_CLASS_NAME
             ,gjl.description                              LINE_DESCRIPTION
             ,gjh.currency_code                            ENTERED_CURRENCY
       --    ,gjh.currency_conversion_rate                 CONVERSION_RATE						-- Added by #BT Technology Team V1.1 17/Nov/2014
			 ,round(gjh.currency_conversion_rate
				    ,(SELECT fc.extended_precision
					  FROM   fnd_currencies fc
					  WHERE  fc.currency_code = gjh.currency_code)) CONVERSION_RATE				-- Added by #BT Technology Team V1.1 17/Nov/2014
             ,to_char(gjh.currency_conversion_date
                     ,''YYYY-MM-DD'')                      CONVERSION_RATE_DATE
             ,gjh.currency_conversion_type                 CONVERSION_RATE_TYPE_CODE
             ,gdct.user_conversion_type                    CONVERSION_RATE_TYPE
             ,gjl.entered_dr                               ENTERED_DR
             ,gjl.entered_cr                               ENTERED_CR
             ,NULL                                         UNROUNDED_ACCOUNTED_DR
             ,NULL                                         UNROUNDED_ACCOUNTED_CR
             ,gjl.accounted_dr                             ACCOUNTED_DR
             ,gjl.accounted_cr                             ACCOUNTED_CR
             ,gjl.stat_amount                              STATISTICAL_AMOUNT
             ,gjl.jgzz_recon_ref                           RECONCILIATION_REFERENCE
             ,gjl.context                                  ATTRIBUTE_CATEGORY
             ,gjl.attribute1                               ATTRIBUTE1
             ,gjl.attribute2                               ATTRIBUTE2
             ,gjl.attribute3                               ATTRIBUTE3
             ,gjl.attribute4                               ATTRIBUTE4
             ,gjl.attribute5                               ATTRIBUTE5
             ,gjl.attribute6                               ATTRIBUTE6
             ,gjl.attribute7                               ATTRIBUTE7
             ,gjl.attribute8                               ATTRIBUTE8
             ,gjl.attribute9                               ATTRIBUTE9
             ,gjl.attribute10                              ATTRIBUTE10
             ,NULL                                         PARTY_TYPE_CODE
             ,NULL                                         PARTY_TYPE
             ,NULL                                         PARTY_INFO
             ,NULL                                         USERIDS';

        -- -- End of Change as per CCR0009873

        p_gl_from                     := 'FROM
             fnd_user                         fdu
            ,fun_seq_versions                 fsv1
            ,fun_seq_versions                 fsv2
	    ,fnd_document_sequences           fns
            ,gl_je_categories_tl              gjct
            ,gl_je_sources_tl                 gjst
            ,gl_daily_conversion_types        gdct
            ,gl_je_lines                      gjl
            ,gl_je_headers                    gjh
            ,gl_je_batches                    gjb
            ,xla_report_balances_gt           glbgt';

        -- -- Start of Change as per CCR0009873



        p_gl_from_arch                := 'FROM
             fnd_user                         fdu
            ,fun_seq_versions                 fsv1
            ,fun_seq_versions                 fsv2
	    ,fnd_document_sequences           fns
            ,gl_je_categories_tl              gjct
            ,gl_je_sources_tl                 gjst
            ,gl_daily_conversion_types        gdct
            ,xxdo.XXD_GL_ARCHIVE_LINES                      gjl
            ,xxdo.XXD_GL_ARCHIVE_HEADERS                    gjh
            ,XXDO.XXD_GL_ARCHIVE_BATCHES                    gjb
            ,xla_report_balances_gt           glbgt';

        -- -- End of Change as per CCR0009873

        p_gl_main_filter              :=
            'WHERE   gjl.ledger_id                    = glbgt.ledger_id
          AND   gjl.code_combination_id          = glbgt.code_combination_id
	  AND   gjl.effective_date               BETWEEN glbgt.period_start_date AND glbgt.period_end_date
	  AND   gjl.effective_date               BETWEEN :P_GL_DATE_FROM AND :P_GL_DATE_TO
	  AND   gjl.period_name                  = glbgt.period_name
	  AND   gjh.je_header_id                 = gjl.je_header_id
	  AND   gjh.actual_flag                  = glbgt.balance_type_code
	  AND   decode(gjh.currency_code,''STAT'',gjh.currency_code,glbgt.ledger_currency) = glbgt.ledger_currency --added bug 6686541
	  AND   NVL(gjh.je_from_sla_flag,''N'')    = ''N''
	  AND   NVL(gjh.budget_version_id,-19999)= NVL(glbgt.budget_version_id,-19999)
	  AND   NVL(gjh.encumbrance_type_id,-19999)= NVL(glbgt.encumbrance_type_id,-19999)
	  AND   gjb.je_batch_id                  = gjh.je_batch_id
	  AND   gjb.status                       = ''P''
	  AND   fns.application_id(+)              = 101
	  AND   fns.doc_sequence_id(+)             = gjh.doc_sequence_id
	  AND   fdu.user_id                      = gjb.created_by
	  AND   fsv1.seq_version_id(+)           = gjh.posting_acct_seq_version_id
	  AND   fsv2.seq_version_id(+)           = gjh.close_acct_seq_version_id
	  AND   gjct.je_category_name            = gjh.je_category
	  AND   gjct.LANGUAGE                    = USERENV(''LANG'')
	  AND   gjst.je_source_name              = gjh.je_source
	  AND   gjst.language                    = USERENV(''LANG'')
	  AND   gdct.conversion_type(+)          = gjh.currency_conversion_type';

        p_upg_gl_from                 := p_gl_from || '
     ,fnd_new_messages                 fnm';

        -- -- Start of Change as per CCR0009873
        p_upg_gl_from_arch            := p_gl_from_arch || '
     ,fnd_new_messages                 fnm';
        -- -- End of Change as per CCR0009873

        p_upg_gl_main_filter          :=
            'WHERE   gjl.ledger_id                    = glbgt.ledger_id
          AND   gjl.code_combination_id          = glbgt.code_combination_id
	  AND   gjl.effective_date               BETWEEN glbgt.period_start_date AND glbgt.period_end_date
	  AND   gjl.effective_date               BETWEEN :P_GL_DATE_FROM AND :P_GL_DATE_TO
	  AND   gjl.period_name                  = glbgt.period_name
	  AND   gjh.je_header_id                 = gjl.je_header_id
	  AND   gjh.actual_flag                  = glbgt.balance_type_code
	  AND   decode(gjh.currency_code,''STAT'',gjh.currency_code,glbgt.ledger_currency) = glbgt.ledger_currency --added bug 6686541
	  AND   NVL(gjh.je_from_sla_flag,''N'')    = ''U''
	  AND   fnm.application_id = 101
	  AND   fnm.language_code = USERENV(''LANG'')
	  AND   fnm.message_name in (''PPOS0220'', ''PPOS0221'', ''PPOS0222'', ''PPOS0243'', ''PPOS0222_G'',''PPOSO275'')
	  AND   gjl.description= fnm.message_text
	  AND   NVL(gjh.budget_version_id,-19999) = NVL(glbgt.budget_version_id,-19999)
	  AND   NVL(gjh.encumbrance_type_id,-19999) = NVL(glbgt.encumbrance_type_id,-19999)
	  AND   gjb.je_batch_id                  = gjh.je_batch_id
	  AND   gjb.status                       = ''P''
	  AND   fns.application_id(+)              = 101
	  AND   fns.doc_sequence_id(+)             = gjh.doc_sequence_id
	  AND   fdu.user_id                      = gjb.created_by
	  AND   fsv1.seq_version_id(+)           = gjh.posting_acct_seq_version_id
	  AND   fsv2.seq_version_id(+)           = gjh.close_acct_seq_version_id
	  AND   gjct.je_category_name            = gjh.je_category
	  AND   gjct.LANGUAGE                    = USERENV(''LANG'')
	  AND   gjst.je_source_name              = gjh.je_source
	  AND   gjst.language                    = USERENV(''LANG'')
	  AND   gdct.conversion_type(+)          = gjh.currency_conversion_type
	  AND  not exists    (select ''x''  from gl_import_references gir
	                      where   gir.je_header_id=gjl.je_header_id
			        and gir.je_line_num=gjl.je_line_num)';

        p_order_by_clause             := 'ORDER BY
        TABLE1.LEDGER_NAME
       ,TABLE1.LEDGER_CURRENCY
       ,TABLE1.ACCOUNTING_CODE_COMBINATION
       ,TABLE1.PERIOD_YEAR
       ,TABLE1.PERIOD_NUMBER
       ,TABLE1.GL_DATE
       ,TABLE1.BALANCE_TYPE_CODE
       ,TABLE1.BUDGET_NAME
       ,TABLE1.ENCUMBRANCE_TYPE
       ,TABLE1.JE_SOURCE_NAME
       ,TABLE1.HEADER_ID';

        --end of bug 10425976


        --bug#7386068
        -- The below query should be executed in the XML if Include Accounts
        -- With No Activity parameter is set to Yes for thic conc program.
        -- This query selects those accounts having a beginning balance and no activity for
        -- the specified date range of the report.

        IF P_INCLUDE_ACCT_WITH_NO_ACT = 'Y'
        THEN
            p_begin_balance_union_all   :=
                ' UNION ALL
          SELECT    NULL                   GL_DATE
         ,NULL                                CREATED_BY
         ,NULL            CREATION_DATE
         ,NULL            LAST_UPDATE_DATE
         ,NULL            GL_TRANSFER_DATE
         ,NULL            REFERENCE_DATE
         ,NULL            COMPLETED_DATE
         ,NULL            TRANSACTION_NUMBER
		 ,NULL			  VOUCHER_NUMBER													-- Added by #BT Technology Team V1.1 17/Nov/2014
         ,NULL            TRANSACTION_DATE
         ,NULL                                         ACCOUNTING_SEQUENCE_NAME
         ,NULL                                         ACCOUNTING_SEQUENCE_VERSION
         ,NULL                                        ACCOUNTING_SEQUENCE_NUMBER
         ,NULL                                        REPORTING_SEQUENCE_NAME
         ,NULL                                        REPORTING_SEQUENCE_VERSION
         ,NULL                                         REPORTING_SEQUENCE_NUMBER
         ,NULL                                         DOCUMENT_CATEGORY
         ,NULL                                         DOCUMENT_SEQUENCE_NAME
         ,NULL                                         DOCUMENT_SEQUENCE_NUMBER
         ,NULL                                         GL_DOCUMENT_SEQUENCE_NAME  -- added bug  9925564 .
         ,NULL                                         GL_DOCUMENT_SEQUENCE_NUMBER
         ,NULL                                         APPLICATION_ID
         ,NULL                                        APPLICATION_NAME
         ,NULL                                         HEADER_ID
         ,NULL                                         HEADER_DESCRIPTION
         ,NULL                                         FUND_STATUS
         ,NULL                                         JE_CATEGORY_NAME
         ,NULL                                         JE_SOURCE_NAME
         ,NULL                                         EVENT_ID
         ,NULL                                         EVENT_DATE
         ,NULL                                         EVENT_NUMBER
         ,NULL                                         EVENT_CLASS_CODE
         ,NULL                                         EVENT_CLASS_NAME
         ,NULL                                         EVENT_TYPE_CODE
         ,NULL                                         EVENT_TYPE_NAME
         ,NULL                                         GL_BATCH_NAME
         ,NULL                                         POSTED_DATE
         ,NULL                                         GL_JE_NAME
         ,NULL                                         EXTERNAL_REFERENCE
         ,NULL                                         GL_LINE_NUMBER
         ,NULL                                         LINE_NUMBER
         ,NULL                                         ORIG_LINE_NUMBER
         ,NULL                                         ACCOUNTING_CLASS_CODE
         ,NULL                                         ACCOUNTING_CLASS_NAME
         ,NULL                                         LINE_DESCRIPTION
         ,NULL                                         ENTERED_CURRENCY
         ,NULL                                         CONVERSION_RATE
         ,NULL                                         CONVERSION_RATE_DATE
         ,NULL                                         CONVERSION_RATE_TYPE_CODE
         ,NULL                                         CONVERSION_RATE_TYPE
         ,NULL                                         ENTERED_DR
         ,NULL                               ENTERED_CR
         ,NULL                   UNROUNDED_ACCOUNTED_DR
         ,NULL                   UNROUNDED_ACCOUNTED_CR
         ,NULL                             ACCOUNTED_DR
         ,NULL                            ACCOUNTED_CR
         ,NULL                       STATISTICAL_AMOUNT
         ,NULL                          RECONCILIATION_REFERENCE
         ,NULL                      ATTRIBUTE_CATEGORY
         ,NULL                               ATTRIBUTE1
         ,NULL                              ATTRIBUTE2
         ,NULL                             ATTRIBUTE3
         ,NULL                              ATTRIBUTE4
         ,NULL                               ATTRIBUTE5
         ,NULL                               ATTRIBUTE6
         ,NULL                               ATTRIBUTE7
         ,NULL                               ATTRIBUTE8
         ,NULL                               ATTRIBUTE9
         ,NULL                             ATTRIBUTE10
         ,NULL                         PARTY_TYPE_CODE
         ,NULL                                         PARTY_TYPE
         ,NULL                                         PARTY_INFO
         ,NULL                                         USERIDS
         ,glbgt.ledger_id                              LEDGER_ID
         ,glbgt.ledger_short_name                      LEDGER_SHORT_NAME
         ,glbgt.ledger_description                     LEDGER_DESCRIPTION
         ,glbgt.ledger_name                            LEDGER_NAME
         ,glbgt.ledger_currency                        LEDGER_CURRENCY
         ,glbgt.period_year                            PERIOD_YEAR
         ,glbgt.period_number                          PERIOD_NUMBER
         ,glbgt.period_name                            PERIOD_NAME
         ,to_char(glbgt.period_start_date
                                 ,''YYYY-MM-DD'')        PERIOD_START_DATE
         ,to_char(glbgt.period_end_date
                                 ,''YYYY-MM-DD'')        PERIOD_END_DATE
         ,glbgt.balance_type_code                      BALANCE_TYPE_CODE
         ,glbgt.balance_type                           BALANCE_TYPE
         ,glbgt.budget_name                            BUDGET_NAME
         ,glbgt.encumbrance_type                       ENCUMBRANCE_TYPE
         ,glbgt.begin_balance_dr                       BEGIN_BALANCE_DR
         ,glbgt.begin_balance_cr                       BEGIN_BALANCE_CR
         ,glbgt.period_net_dr                          PERIOD_NET_DR
         ,glbgt.period_net_cr                          PERIOD_NET_CR
         ,glbgt.code_combination_id                    CODE_COMBINATION_ID
         ,glbgt.accounting_code_combination            ACCOUNTING_CODE_COMBINATION
         ,glbgt.code_combination_description           CODE_COMBINATION_DESCRIPTION
         ,glbgt.control_account_flag                   CONTROL_ACCOUNT_FLAG
         ,glbgt.control_account                        CONTROL_ACCOUNT
         ,glbgt.balancing_segment                      BALANCING_SEGMENT
         ,glbgt.natural_account_segment                NATURAL_ACCOUNT_SEGMENT
         ,glbgt.cost_center_segment                    COST_CENTER_SEGMENT
         ,glbgt.management_segment                     MANAGEMENT_SEGMENT
         ,glbgt.intercompany_segment                   INTERCOMPANY_SEGMENT
         ,glbgt.balancing_segment_desc                 BALANCING_SEGMENT_DESC
         ,glbgt.natural_account_desc                   NATURAL_ACCOUNT_DESC
         ,glbgt.cost_center_desc                       COST_CENTER_DESC
         ,glbgt.management_segment_desc                MANAGEMENT_SEGMENT_DESC
         ,glbgt.intercompany_segment_desc              INTERCOMPANY_SEGMENT_DESC
         ,glbgt.segment1                               SEGMENT1
         ,glbgt.segment2                               SEGMENT2
         ,glbgt.segment3                               SEGMENT3
         ,glbgt.segment4                               SEGMENT4
         ,glbgt.segment5                               SEGMENT5
         ,glbgt.segment6                               SEGMENT6
         ,glbgt.segment7                               SEGMENT7
         ,glbgt.segment8                               SEGMENT8
         ,glbgt.segment9                               SEGMENT9
         ,glbgt.segment10                              SEGMENT10
         ,glbgt.segment11                              SEGMENT11
         ,glbgt.segment12                              SEGMENT12
         ,glbgt.segment13                              SEGMENT13
         ,glbgt.segment14                              SEGMENT14
         ,glbgt.segment15                              SEGMENT15
         ,glbgt.segment16                              SEGMENT16
         ,glbgt.segment17                              SEGMENT17
         ,glbgt.segment18                              SEGMENT18
         ,glbgt.segment19                              SEGMENT19
         ,glbgt.segment20                              SEGMENT20
         ,glbgt.segment21                              SEGMENT21
         ,glbgt.segment22                              SEGMENT22
         ,glbgt.segment23                              SEGMENT23
         ,glbgt.segment24                              SEGMENT24
         ,glbgt.segment25                              SEGMENT25
         ,glbgt.segment26                              SEGMENT26
         ,glbgt.segment27                              SEGMENT27
         ,glbgt.segment28                              SEGMENT28
         ,glbgt.segment29                              SEGMENT29
         ,glbgt.segment30                              SEGMENT30
         ,glbgt.begin_running_total_cr                 BEGIN_RUNNING_TOTAL_CR
         ,glbgt.begin_running_total_dr                 BEGIN_RUNNING_TOTAL_DR
         ,glbgt.end_running_total_cr                   END_RUNNING_TOTAL_CR
         ,glbgt.end_running_total_dr                   END_RUNNING_TOTAL_DR
         ,glbgt.legal_entity_id                        LEGAL_ENTITY_ID
         ,glbgt.legal_entity_name                      LEGAL_ENTITY_NAME
         ,glbgt.le_address_line_1                      LE_ADDRESS_LINE_1
         ,glbgt.le_address_line_2                      LE_ADDRESS_LINE_2
         ,glbgt.le_address_line_3                      LE_ADDRESS_LINE_3
         ,glbgt.le_city                                LE_CITY
         ,glbgt.le_region_1                            LE_REGION_1
         ,glbgt.le_region_2                            LE_REGION_2
         ,glbgt.le_region_3                            LE_REGION_3
         ,glbgt.le_postal_code                         LE_POSTAL_CODE
         ,glbgt.le_country                             LE_COUNTRY
         ,glbgt.le_registration_number                 LE_REGISTRATION_NUMBER
         ,glbgt.le_registration_effective_from         LE_REGISTRATION_EFFECTIVE_FROM
         ,glbgt.le_br_daily_inscription_number         LE_BR_DAILY_INSCRIPTION_NUMBER
         ,to_char(glbgt.le_br_daily_inscription_date
                                ,''YYYY-MM-DD'')                                             LE_BR_DAILY_INSCRIPTION_DATE
         ,glbgt.le_br_daily_entity                     LE_BR_DAILY_ENTITY
         ,glbgt.le_br_daily_location                   LE_BR_DAILY_LOCATION
         ,glbgt.le_br_director_number                  LE_BR_DIRECTOR_NUMBER
         ,glbgt.le_br_accountant_number                LE_BR_ACCOUNTANT_NUMBER
         ,glbgt.le_br_accountant_name                  LE_BR_ACCOUNTANT_NAME
FROM     xla_report_balances_gt           glbgt
WHERE nvl(period_net_dr,0) = 0
  AND   nvl(period_net_cr,0) = 0
  AND (nvl(begin_balance_dr,0) - nvl(begin_balance_cr,0) ) <> 0';
        ELSE                                                    --bug 12329939
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND (((NVL(glb.begin_balance_cr,0)-NVL(glb.begin_balance_dr,0)) <> 0)'
                || ' OR (NVL(glb.period_net_cr,0) <> 0) OR (NVL(glb.period_net_dr,0) <> 0))';
        END IF;

        --End bug#7386068


        --Added below for CCR0010275
        IF p_tbl_select = 'Seeded Table'
        THEN
            p_invoke_gl     := ' AND 1=1 ';
            p_invoke_arch   := ' AND 1=2 ';
        ELSIF p_tbl_select = 'Archive Table'
        THEN
            p_invoke_gl     := ' AND 1=2 ';
            p_invoke_arch   := ' AND 1=1 ';
        ELSE
            p_invoke_gl     := ' AND 1=1 ';
            p_invoke_arch   := ' AND 1=1 ';
        END IF;

        --Added above for CCR0010275



        --
        --<condition for the accounting flex field>
        --

        IF p_account_flexfield_from IS NOT NULL
        THEN
            l_flex_range_where   :=
                get_flex_range_where (
                    p_coa_id                      => l_coa_id,
                    p_accounting_flexfield_from   => p_account_flexfield_from,
                    p_accounting_flexfield_to     => p_account_flexfield_to);
            l_other_param_filter   :=
                l_other_param_filter || ' AND ' || l_flex_range_where;
        END IF;

        -- Bug 5914782
        p_ledger_filters              :=
               ' gjh.ledger_id IN '
            || l_ledgers
            || ' AND glbgt.ledger_id IN '
            || l_ledgers
            || ' AND aeh.ledger_id IN '
            || l_ledgers;

        IF p_balance_type_code IS NOT NULL
        THEN
            p_ledger_filters   :=
                   p_ledger_filters
                || ' AND gjh.actual_flag = '''
                || p_balance_type_code
                || '''';
        END IF;


        p_sla_other_filter            := l_sla_other_filter;
        p_gl_other_filter             := l_gl_other_filter;


        l_balance_query               :=
            '
INSERT INTO xla_report_balances_gt
    (ledger_id
   ,ledger_short_name
   ,ledger_description
   ,ledger_name
   ,ledger_currency
   ,period_year
   ,period_number
   ,period_name
   ,period_start_date
   ,period_end_date
   ,balance_type_code
   ,balance_type
   ,budget_version_id
   ,budget_name
   ,encumbrance_type_id
   ,encumbrance_type
   ,begin_balance_dr
   ,begin_balance_cr
   ,period_net_dr
   ,period_net_cr
   ,code_combination_id
   ,accounting_code_combination
   ,code_combination_description
   ,control_account_flag
   ,control_account
   ,balancing_segment
   ,natural_account_segment
   ,cost_center_segment
   ,management_segment
   ,intercompany_segment
   ,balancing_segment_desc
   ,natural_account_desc
   ,cost_center_desc
   ,management_segment_desc
   ,intercompany_segment_desc
   ,segment1
   ,segment2
   ,segment3
   ,segment4
   ,segment5
   ,segment6
   ,segment7
   ,segment8
   ,segment9
   ,segment10
   ,segment11
   ,segment12
   ,segment13
   ,segment14
   ,segment15
   ,segment16
   ,segment17
   ,segment18
   ,segment19
   ,segment20
   ,segment21
   ,segment22
   ,segment23
   ,segment24
   ,segment25
   ,segment26
   ,segment27
   ,segment28
   ,segment29
   ,segment30
   ,legal_entity_id
   ,legal_entity_name
   ,le_address_line_1
   ,le_address_line_2
   ,le_address_line_3
   ,le_city
   ,le_region_1
   ,le_region_2
   ,le_region_3
   ,le_postal_code
   ,le_country
   ,le_registration_number
   ,le_registration_effective_from
   ,le_br_daily_inscription_number
   ,le_br_daily_inscription_date
   ,le_br_daily_entity
   ,le_br_daily_location
   ,le_br_director_number
   ,le_br_accountant_number
   ,le_br_accountant_name)
(
SELECT TABLE1.LEDGER_ID
      ,TABLE1.LEDGER_SHORT_NAME
      ,TABLE1.LEDGER_DESCRIPTION
      ,TABLE1.LEDGER_NAME
      ,TABLE1.LEDGER_CURRENCY
      ,TABLE1.PERIOD_YEAR
      ,TABLE1.PERIOD_NUMBER
      ,TABLE1.PERIOD_NAME
      ,TABLE1.PERIOD_START_DATE
      ,TABLE1.PERIOD_END_DATE
      ,TABLE1.BALANCE_TYPE_CODE
      ,TABLE1.BALANCE_TYPE
      ,TABLE1.BUDGET_VERSION_ID
      ,TABLE1.BUDGET_NAME
      ,TABLE1.ENCUMBRANCE_TYPE_ID
      ,TABLE1.ENCUMBRANCE_TYPE
      ,TABLE1.BEGIN_BALANCE_DR
      ,TABLE1.BEGIN_BALANCE_CR
      ,TABLE1.PERIOD_NET_DR
      ,TABLE1.PERIOD_NET_CR
      ,TABLE1.CODE_COMBINATION_ID
      ,TABLE1.ACCOUNTING_CODE_COMBINATION
      ,TABLE1.CODE_COMBINATION_DESCRIPTION
      ,TABLE1.CONTROL_ACCOUNT_FLAG
      ,TABLE1.CONTROL_ACCOUNT
      ,TABLE1.BALANCING_SEGMENT
      ,TABLE1.NATURAL_ACCOUNT_SEGMENT
      ,TABLE1.COST_CENTER_SEGMENT
      ,TABLE1.MANAGEMENT_SEGMENT
      ,TABLE1.INTERCOMPANY_SEGMENT
      ,TABLE1.BALANCING_SEGMENT_DESC
      ,TABLE1.NATURAL_ACCOUNT_DESC
      ,TABLE1.COST_CENTER_DESC
      ,TABLE1.MANAGEMENT_SEGMENT_DESC
      ,TABLE1.INTERCOMPANY_SEGMENT_DESC
      ,TABLE1.SEGMENT1
      ,TABLE1.SEGMENT2
      ,TABLE1.SEGMENT3
      ,TABLE1.SEGMENT4
      ,TABLE1.SEGMENT5
      ,TABLE1.SEGMENT6
      ,TABLE1.SEGMENT7
      ,TABLE1.SEGMENT8
      ,TABLE1.SEGMENT9
      ,TABLE1.SEGMENT10
      ,TABLE1.SEGMENT11
      ,TABLE1.SEGMENT12
      ,TABLE1.SEGMENT13
      ,TABLE1.SEGMENT14
      ,TABLE1.SEGMENT15
      ,TABLE1.SEGMENT16
      ,TABLE1.SEGMENT17
      ,TABLE1.SEGMENT18
      ,TABLE1.SEGMENT19
      ,TABLE1.SEGMENT20
      ,TABLE1.SEGMENT21
      ,TABLE1.SEGMENT22
      ,TABLE1.SEGMENT23
      ,TABLE1.SEGMENT24
      ,TABLE1.SEGMENT25
      ,TABLE1.SEGMENT26
      ,TABLE1.SEGMENT27
      ,TABLE1.SEGMENT28
      ,TABLE1.SEGMENT29
      ,TABLE1.SEGMENT30
      $legal_entity_columns$
  FROM
    (SELECT $hint$
            gl1.ledger_id                 LEDGER_ID
           ,gl1.short_name                LEDGER_SHORT_NAME
           ,gl1.description               LEDGER_DESCRIPTION
           ,gl1.NAME                      LEDGER_NAME
           ,glb.currency_code             LEDGER_CURRENCY
           ,glb.period_year               PERIOD_YEAR
           ,glb.period_num                PERIOD_NUMBER
           ,glb.period_name               PERIOD_NAME
           ,gl1.START_DATE                PERIOD_START_DATE
           ,gl1.end_date                  PERIOD_END_DATE
           ,glb.actual_flag               BALANCE_TYPE_CODE
           ,xlk.meaning                   BALANCE_TYPE
           ,glb.budget_version_id         BUDGET_VERSION_ID
           ,glv.budget_name               BUDGET_NAME
           ,glb.encumbrance_type_id       ENCUMBRANCE_TYPE_ID
           ,get.encumbrance_type          ENCUMBRANCE_TYPE
           ,NVL(glb.begin_balance_dr,0)   BEGIN_BALANCE_DR
           ,NVL(glb.begin_balance_cr,0)   BEGIN_BALANCE_CR
           ,NVL(glb.period_net_dr,0)      PERIOD_NET_DR
           ,NVL(glb.period_net_cr,0)      PERIOD_NET_CR
           ,glb.code_combination_id       CODE_COMBINATION_ID
           ,$concat_segments$             ACCOUNTING_CODE_COMBINATION
           ,xla_report_utility_pkg.get_ccid_desc
              (gl1.chart_of_accounts_id
              ,glb.code_combination_id)   CODE_COMBINATION_DESCRIPTION
           ,gcck.reference3               CONTROL_ACCOUNT_FLAG
           ,NULL                          CONTROL_ACCOUNT
           $seg_desc_column$
           ,gcck.segment1                 SEGMENT1
           ,gcck.segment2                 SEGMENT2
           ,gcck.segment3                 SEGMENT3
           ,gcck.segment4                 SEGMENT4
           ,gcck.segment5                 SEGMENT5
           ,gcck.segment6                 SEGMENT6
           ,gcck.segment7                 SEGMENT7
           ,gcck.segment8                 SEGMENT8
           ,gcck.segment9                 SEGMENT9
           ,gcck.segment10                SEGMENT10
           ,gcck.segment11                SEGMENT11
           ,gcck.segment12                SEGMENT12
           ,gcck.segment13                SEGMENT13
           ,gcck.segment14                SEGMENT14
           ,gcck.segment15                SEGMENT15
           ,gcck.segment16                SEGMENT16
           ,gcck.segment17                SEGMENT17
           ,gcck.segment18                SEGMENT18
           ,gcck.segment19                SEGMENT19
           ,gcck.segment20                SEGMENT20
           ,gcck.segment21                SEGMENT21
           ,gcck.segment22                SEGMENT22
           ,gcck.segment23                SEGMENT23
           ,gcck.segment24                SEGMENT24
           ,gcck.segment25                SEGMENT25
           ,gcck.segment26                SEGMENT26
           ,gcck.segment27                SEGMENT27
           ,gcck.segment28                SEGMENT28
           ,gcck.segment29                SEGMENT29
           ,gcck.segment30                SEGMENT30
       FROM (SELECT /*+ no_merge */
                    gll.ledger_id
                   ,gll.short_name
                   ,gll.description
                   ,gll.name
                   ,gll.currency_code
                   ,gll.chart_of_accounts_id
                   ,gls.period_name
                   ,gls.start_date
                   ,gls.end_date
               FROM gl_ledgers                        gll
                   ,gl_period_statuses                gls
              WHERE gls.ledger_id              = gll.ledger_id
                AND gls.application_id         = 101
                AND gls.effective_period_num   BETWEEN :P_START_PERIOD_NUM AND :P_END_PERIOD_NUM
                AND gll.ledger_id              IN $ledger_id$
            )                                 gl1
           ,gl_balances                       glb
           ,gl_code_combinations              gcck
           ,xla_lookups                       xlk
           ,gl_budget_versions                glv
           ,gl_encumbrance_types              get
           $seg_desc_from$
      WHERE glb.ledger_id              = gl1.ledger_id
        AND glb.currency_code          $statistical$
        AND glb.period_name            = gl1.period_name
        AND glb.template_id            IS null
        AND gcck.code_combination_id   = glb.code_combination_id
	AND gcck.chart_of_accounts_id  = gl1.chart_of_accounts_id --12329939
        AND xlk.lookup_type            = ''XLA_BALANCE_TYPE''
        AND xlk.lookup_code            = glb.actual_flag
        AND glv.budget_version_id(+)   = glb.budget_version_id
        AND get.encumbrance_type_id(+) = glb.encumbrance_type_id
            $seg_desc_join$
            $other_param_filter$)  TABLE1
       $legal_entity_from$
 WHERE 1 = 1
       $legal_entity_join$
)';



        l_balance_query               :=
            REPLACE (l_balance_query,
                     '$legal_entity_columns$',
                     p_legal_ent_col);
        l_balance_query               :=
            REPLACE (l_balance_query,
                     '$seg_desc_column$',
                     p_qualifier_segment);
        l_balance_query               :=
            REPLACE (l_balance_query,
                     '$legal_entity_from$',
                     p_legal_ent_from);
        l_balance_query               :=
            REPLACE (l_balance_query, '$seg_desc_from$', p_seg_desc_from);
        l_balance_query               :=
            REPLACE (l_balance_query,
                     '$other_param_filter$',
                     l_other_param_filter);
        l_balance_query               :=
            REPLACE (l_balance_query,
                     '$legal_entity_join$',
                     p_legal_ent_join);
        l_balance_query               :=
            REPLACE (l_balance_query, '$seg_desc_join$', p_seg_desc_join);
        l_balance_query               :=
            REPLACE (l_balance_query, '$concat_segments$', l_concat_segment);
        l_balance_query               :=
            REPLACE (l_balance_query, '$ledger_id$', l_ledgers);
        l_balance_query               :=
            REPLACE (l_balance_query, '$hint$', l_hint);

        l_balance_query               :=
            REPLACE (l_balance_query, '$statistical$', l_statistical);

        EXECUTE IMMEDIATE l_balance_query
            USING l_start_period_num, l_end_period_num, p_ledger_id;

        IF ((p_gl_date_from > l_start_date) OR (p_gl_date_to < l_end_date))
        THEN
            UPDATE xla_report_balances_gt xrb
               SET (begin_running_total_cr, begin_running_Total_dr, end_running_total_cr
                    , end_running_total_dr)   =
                       (SELECT SUM (
                                   CASE
                                       WHEN gjl.effective_date <
                                            p_gl_date_from
                                       THEN
                                           accounted_cr
                                       ELSE
                                           0
                                   END) BEGIN_RUNNING_TOTAL_CR,
                               SUM (
                                   CASE
                                       WHEN gjl.effective_date <
                                            p_gl_date_from
                                       THEN
                                           accounted_dr
                                       ELSE
                                           0
                                   END) BEGIN_RUNNING_TOTAL_DR,
                               SUM (
                                   CASE
                                       WHEN gjl.effective_date > p_gl_date_to
                                       THEN
                                           accounted_cr
                                       ELSE
                                           0
                                   END) END_RUNNING_TOTAL_CR,
                               SUM (
                                   CASE
                                       WHEN gjl.effective_date > p_gl_date_to
                                       THEN
                                           accounted_dr
                                       ELSE
                                           0
                                   END) END_RUNNING_TOTAL_DR
                          FROM gl_je_headers gjh, gl_je_lines gjl
                         WHERE     gjh.je_header_id = gjl.je_header_id
                               AND gjh.status = 'P'
                               AND gjl.status = 'P'             -- Bug 9668652
                               AND gjh.ledger_id = xrb.ledger_id
                               AND gjl.period_name = xrb.period_name -- Bug 9668652
                               AND gjh.actual_flag = xrb.balance_type_code
                               AND gjl.code_combination_id =
                                   xrb.code_combination_id)
             WHERE xrb.period_name IN (p_period_from, p_period_to);
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            xla_exceptions_pkg.raise_message (
                p_location => 'xxdo_xla_acct_analysis_rpt_pkg.beforeReport ');
    END beforeReport;
--=============================================================================
--          *********** Initialization routine **********
--=============================================================================

--=============================================================================
--
--
--
--
--
--
--
--
--
--
-- Following code is executed when the package body is referenced for the first
-- time
--
--
--
--
--
--
--
--
--
--
--
--
--=============================================================================

BEGIN
    g_log_level   := FND_LOG.G_CURRENT_RUNTIME_LEVEL;
    g_log_enabled   :=
        fnd_log.test (log_level => g_log_level, MODULE => C_DEFAULT_MODULE);

    IF NOT g_log_enabled
    THEN
        g_log_level   := C_LEVEL_LOG_DISABLED;
    END IF;
END XXDO_XLA_ACCT_ANALYSIS_RPT_PKG;
/
