--
-- XXD_XLA_JELINES_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_XLA_JELINES_RPT_PKG"
AS
    -- $Header: xlarpjel.pkb 120.68.12020000.5 2013/02/18 17:36:33 sgullape ship $
    /*===========================================================================+
    /  V1.0    10-MAY-2017      Sourced from XLA_JELINES_RPT_PKG                /
    /                           Created by Deckers IT Team
    +============================================================================+

    /
    +===========================================================================*/


    --=============================================================================
    --           ****************  declarations  ********************
    --=============================================================================
    -------------------------------------------------------------------------------
    -- constant for getting flexfield segment value description
    -------------------------------------------------------------------------------
    C_SEG_DESC_JOIN            CONSTANT VARCHAR2 (1000)
        :=    ' AND $alias$.flex_value_set_id = $flex_value_set_id$ AND '
           || ' $alias$.flex_value            = $segment_column$ ' ;

    -------------------------------------------------------------------------------
    -- constant for getting leagal entity information
    -------------------------------------------------------------------------------
    C_LE_NULL_COL              CONSTANT VARCHAR2 (4000)
                                            := ' ,NULL         LEGAL_ENTITY_ID
     ,NULL         LEGAL_ENTITY_NAME
     ,NULL         LEGAL_ENTITY_IDENTIFIER
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
     ,NULL         LE_BR_ACCOUNTANT_NUBMER
     ,NULL         LE_BR_ACCOUNTANT_NAME
     ,NULL         TRX_LEGAL_ENTITY_ID
     ,NULL         TRX_LEGAL_ENTITY_NAME
     ,NULL         TRX_LE_ADDRESS_LINE_1
     ,NULL         TRX_LE_ADDRESS_LINE_2
     ,NULL         TRX_LE_ADDRESS_LINE_3
     ,NULL         TRX_LE_CITY
     ,NULL         TRX_LE_REGION_1
     ,NULL         TRX_LE_REGION_2
     ,NULL         TRX_LE_REGION_3
     ,NULL         TRX_LE_POSTAL_CODE
     ,NULL         TRX_LE_COUNTRY
     ,NULL         TRX_LE_REGISTRATION_NUMBER
     ,NULL         TRX_LE_REGST_EFFECTIVE_FROM' ;

    C_LEGAL_ENT_COL            CONSTANT VARCHAR2 (4000)
        := ' ,fiv.legal_entity_id                     LEGAL_ENTITY_ID
     ,fiv.NAME                                LEGAL_ENTITY_NAME
     ,fiv.LEGAL_ENTITY_IDENTIFIER             LEGAL_ENTITY_IDENTIFIER
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
     ,lc2.contact_number                      LE_BR_ACCOUNTANT_NUBMER
     ,lc2.contact_name                        LE_BR_ACCOUNTANT_NAME
     ,TABLE1.TRX_LEGAL_ENTITY_ID              TRX_LEGAL_ENTITY_ID
     ,TABLE1.TRX_LEGAL_ENTITY_NAME            TRX_LEGAL_ENTITY_NAME
     ,TABLE1.TRX_LE_ADDRESS_LINE_1            TRX_LE_ADDRESS_LINE_1
     ,TABLE1.TRX_LE_ADDRESS_LINE_2            TRX_LE_ADDRESS_LINE_2
     ,TABLE1.TRX_LE_ADDRESS_LINE_3            TRX_LE_ADDRESS_LINE_3
     ,TABLE1.TRX_LE_CITY                      TRX_LE_CITY
     ,TABLE1.TRX_LE_REGION_1                  TRX_LE_REGION_1
     ,TABLE1.TRX_LE_REGION_2                  TRX_LE_REGION_2
     ,TABLE1.TRX_LE_REGION_3                  TRX_LE_REGION_3
     ,TABLE1.TRX_LE_POSTAL_CODE               TRX_LE_POSTAL_CODE
     ,TABLE1.TRX_LE_COUNTRY                   TRX_LE_COUNTRY
     ,TABLE1.TRX_LE_REGISTRATION_NUMBER       TRX_LE_REGISTRATION_NUMBER
     ,TABLE1.TRX_LE_REGST_EFFECTIVE_FROM      TRX_LE_REGST_EFFECTIVE_FROM ' ;

    C_LEGAL_ENT_FROM           CONSTANT VARCHAR2 (1000)
                                            := ' ,xle_firstparty_information_v   fiv
     ,xle_registrations_v            xrv
     ,xle_legalauth_v                xlv
     ,xle_legal_contacts_v           lc1
     ,xle_legal_contacts_v           lc2
     ,gl_ledger_le_bsv_specific_v    gle' ;

    C_LEGAL_ENT_JOIN           CONSTANT VARCHAR2 (2000)
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

    C_ESTBLISHMENT_COL         CONSTANT VARCHAR2 (4000)
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
     ,lc2.contact_number                      LE_BR_ACCOUNTANT_NUBMER
     ,lc2.contact_name                        LE_BR_ACCOUNTANT_NAME
     ,TABLE1.TRX_LEGAL_ENTITY_ID              TRX_LEGAL_ENTITY_ID
     ,TABLE1.TRX_LEGAL_ENTITY_NAME            TRX_LEGAL_ENTITY_NAME
     ,TABLE1.TRX_LE_ADDRESS_LINE_1            TRX_LE_ADDRESS_LINE_1
     ,TABLE1.TRX_LE_ADDRESS_LINE_2            TRX_LE_ADDRESS_LINE_2
     ,TABLE1.TRX_LE_ADDRESS_LINE_3            TRX_LE_ADDRESS_LINE_3
     ,TABLE1.TRX_LE_CITY                      TRX_LE_CITY
     ,TABLE1.TRX_LE_REGION_1                  TRX_LE_REGION_1
     ,TABLE1.TRX_LE_REGION_2                  TRX_LE_REGION_2
     ,TABLE1.TRX_LE_REGION_3                  TRX_LE_REGION_3
     ,TABLE1.TRX_LE_POSTAL_CODE               TRX_LE_POSTAL_CODE
     ,TABLE1.TRX_LE_COUNTRY                   TRX_LE_COUNTRY
     ,TABLE1.TRX_LE_REGISTRATION_NUMBER       TRX_LE_REGISTRATION_NUMBER
     ,TABLE1.TRX_LE_REGST_EFFECTIVE_FROM      TRX_LE_REGST_EFFECTIVE_FROM ' ;

    C_ESTABLISHMENT_FROM       CONSTANT VARCHAR2 (2000)
        := ' ,gl_ledger_le_bsv_specific_v      glv
     ,xle_bsv_associations             xba
     ,xle_establishment_v              xev
     ,xle_registrations_v              xrv
     ,xle_legalauth_v                  xlv
     ,xle_legal_contacts_v             lc1
     ,xle_legal_contacts_v             lc2' ;

    C_ESTABLISHMENT_JOIN       CONSTANT VARCHAR2 (2000)
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

    C_SLA_TRX_LEGAL_ENT_COL    CONSTANT VARCHAR2 (4000)
        := ' ,ftx.legal_entity_id      TRX_LEGAL_ENTITY_ID
     ,ftx.NAME                 TRX_LEGAL_ENTITY_NAME
     ,ftx.ADDRESS_LINE_1       TRX_LE_ADDRESS_LINE_1
     ,ftx.ADDRESS_LINE_2       TRX_LE_ADDRESS_LINE_2
     ,ftx.ADDRESS_LINE_3       TRX_LE_ADDRESS_LINE_3
     ,ftx.TOWN_OR_CITY         TRX_LE_CITY
     ,ftx.REGION_1             TRX_LE_REGION_1
     ,ftx.REGION_2             TRX_LE_REGION_2
     ,ftx.REGION_3             TRX_LE_REGION_3
     ,ftx.postal_code          TRX_LE_POSTAL_CODE
     ,ftx.country              TRX_LE_COUNTRY
     ,ftx.registration_number  TRX_LE_REGISTRATION_NUMBER
     ,ftx.effective_from       TRX_LE_REGST_EFFECTIVE_FROM' ;

    C_SLA_TRX_LEGAL_ENT_FROM   CONSTANT VARCHAR2 (1000)
        := ' ,xle_firstparty_information_v   ftx ' ;

    C_SLA_TRX_LEGAL_ENT_JOIN   CONSTANT VARCHAR2 (2000)
        := ' AND ftx.legal_entity_id(+)      = ent.legal_entity_id ' ;

    C_GL_TRX_LEGAL_ENT_COL     CONSTANT VARCHAR2 (4000)
        := ' ,NULL                     TRX_LEGAL_ENTITY_ID
     ,NULL                     TRX_LEGAL_ENTITY_NAME
     ,NULL                     TRX_LE_ADDRESS_LINE_1
     ,NULL                     TRX_LE_ADDRESS_LINE_2
     ,NULL                     TRX_LE_ADDRESS_LINE_3
     ,NULL                     TRX_LE_CITY
     ,NULL                     TRX_LE_REGION_1
     ,NULL                     TRX_LE_REGION_2
     ,NULL                     TRX_LE_REGION_3
     ,NULL                     TRX_LE_POSTAL_CODE
     ,NULL                     TRX_LE_COUNTRY
     ,NULL                     TRX_LE_REGISTRATION_NUMBER
     ,NULL                     TRX_LE_REGST_EFFECTIVE_FROM ' ;

    C_QUALIFIED_SEGMENT        CONSTANT VARCHAR2 (1000)
        := ',$alias_balancing_segment$      BALANCING_SEGMENT
    ,$alias_account_segment$        NATURAL_ACCOUNT_SEGMENT
    ,$alias_costcenter_segment$     COST_CENTER_SEGMENT
    ,$alias_management_segment$     MANAGEMENT_SEGMENT
    ,$alias_intercompany_segment$   INTERCOMPANY_SEGMENT
     $seg_desc_column$ ' ;


    ------------------------------------------------------------------------------
    -- Based on P_YTD_CARRIEDFWD_FLAG building query to fetch Year-to-Date Carried
    -- Forward Debit and Credit Amounts
    ------------------------------------------------------------------------------

    C_YTD_ACTUAL_CARRIEDFWD             VARCHAR2 (8000)
        := 'SELECT
           nvl(sum(nvl(gll.accounted_dr,0)),0)                  YTD_ACTIVITY_DR
          ,nvl(sum(nvl(gll.accounted_cr,0)),0)                  YTD_ACTIVITY_CR
      FROM
           gl_je_headers                     glh
          ,gl_je_lines                       gll
          ,gl_ledgers                        glg
          ,gl_periods                        glp
      ,gl_code_combinations_kfv          gcck
      WHERE  glg.ledger_id               IN (:P_LEDGER_ID)
          AND  glh.period_name    IN ( select distinct Period_name from gl_period_statuses where
                                             ledger_id = :P_LEDGER_ID  and period_num <
                                             (select distinct Period_num from  gl_period_statuses
                                               where ledger_id = :P_LEDGER_ID  and period_name = :P_PERIOD_FROM)
                                             and period_year in
                                             (select distinct Period_year  from  gl_period_statuses
                                             where ledger_id = :P_LEDGER_ID  and period_name = :P_PERIOD_FROM)
                                           )
          AND  glh.ledger_id               =  glg.ledger_id
          AND  gll.je_header_id            =  glh.je_header_id
          AND  glp.period_name             =  glh.period_name
          AND  glp.period_set_name         =  glg.period_set_name
      AND  gcck.code_combination_id    =  gll.code_combination_id
          AND glh.status = ''P''
          AND glh.currency_code <> ''STAT''';     --added gcck for bug 12586551


    C_YTD_ZERO_CARRIEDFWD               VARCHAR2 (500) := 'SELECT
                 0  YTD_ACTIVITY_DR,
                 0  YTD_ACTIVITY_CR
         FROM
         DUAL';


    --------------------------------------------------------------------------------
    -- constant for tax details
    --------------------------------------------------------------------------------
    C_TAX_QUERY                         VARCHAR2 (8000)
        := 'SELECT    /*+ index(xdl, XLA_DISTRIBUTION_LINKS_N3) */
               zxl.tax_line_id               TAX_LINE_ID
              ,zxr.tax_regime_name           TAX_REGIME
              ,zxl.tax                       TAX
              ,ztt.tax_full_name             TAX_NAME
              ,zst.tax_status_name           TAX_STATUS_NAME
              ,zrt.tax_rate_name             TAX_RATE_NAME
              ,zxl.tax_rate                  TAX_RATE
              ,flk1.meaning                  TAX_RATE_TYPE_NAME
              ,to_char(zxl.tax_determine_date
                      ,''YYYY-MM-DD'')       TAX_DETERMINE_DATE
              ,to_char(zxl.tax_point_date
                      ,''YYYY-MM-DD'')       TAX_POINT_DATE
              ,zxl.tax_type_code             TAX_TYPE_CODE
              ,flk2.meaning                  TAX_TYPE_NAME
              ,zxl.tax_code                  TAX_CODE
              ,zxl.tax_registration_number   TAX_REGISTRATION_NUMBER
              ,zxl.trx_currency_code         TRX_CURRENCY_CODE
              ,zxl.tax_currency_code         TAX_CURRENCY_CODE
              ,zxl.tax_amt                   TAX_AMOUNT
              ,zxl.tax_amt_tax_curr          TAX_AMOUNT_TAX_CURRENCY
              ,zxl.tax_amt_funcl_curr        TAX_AMOUNT_FUNCTIONAL_CURR
              ,zxl.taxable_amt               TAXABLE_AMOUNT
              ,zxl.taxable_amt_tax_curr      TAXABLE_AMOUNT_TAX_CURRENCY
              ,zxl.taxable_amt_funcl_curr    TAXABLE_AMT_FUNC_CURRENCY
              ,zxl.unrounded_taxable_amt     UNROUNDED_TAXABLE_AMOUNT
              ,zxl.unrounded_tax_amt         UNROUNDED_TAX_AMOUNT
              ,zxl.rec_tax_amt               RECOVERABLE_TAX_AMOUNT
              ,zxl.rec_tax_amt_tax_curr      RECOVERABLE_TAX_AMT_TAX_CURR
              ,zxl.rec_tax_amt_funcl_curr    RECOVERABLE_TAX_AMT_FUNC_CURR
              ,zxl.nrec_tax_amt              NON_RECOVERABLE_TAX_AMOUNT
              ,zxl.nrec_tax_amt_tax_curr     NON_REC_TAX_AMT_TAX_CURR
              ,zxl.nrec_tax_amt_funcl_curr   NON_REC_TAX_AMT_FUNC_CURR
              ,zxl.tax_jurisdiction_code     TAX_JURISDICTION_CODE
              ,zxl.self_assessed_flag        SELF_ASSESSED_FLAG
              ,zxl.hq_estb_reg_number        HQ_ESTB_REG_NUMBER
              ,zrnd.rec_nrec_tax_dist_id     REC_NREC_TAX_DIST_ID
              ,zrnd.recovery_type_code       RECOVERY_TYPE_CODE
              ,zrnd.recovery_rate_code       RECOVERY_RATE_CODE
              ,zrnd.rec_nrec_rate            REC_NREC_RATE
              ,zrnd.recoverable_flag         RECOVERABLE_FLAG
              ,zrnd.rec_nrec_tax_amt         REC_NREC_TAX_AMT
              ,zrnd.rec_nrec_tax_amt_tax_curr   REC_NREC_TAX_AMT_TAX_CURR
              ,zrnd.rec_nrec_tax_amt_funcl_curr REC_NREC_TAX_AMT_FUNCL_CURR

      FROM     xla_distribution_links         xdl
              ,zx_lines                       zxl
              ,zx_regimes_tl                  zxr
              ,zx_taxes_tl                    ztt
              ,zx_status_tl                   zst
              ,zx_rates_tl                    zrt
              ,fnd_lookups                    flk1
              ,fnd_lookups                    flk2
              ,zx_rec_nrec_dist               zrnd
     WHERE     xdl.tax_line_ref_id    = zxl.tax_line_id
           AND zxr.tax_regime_id(+)   = zxl.tax_regime_id
           AND zxr.language(+)        = USERENV(''LANG'')
           AND ztt.tax_id(+)          = zxl.tax_id
           AND ztt.language(+)        = USERENV(''LANG'')
           AND zst.tax_status_id(+)   = zxl.tax_status_id
           AND zst.language(+)        = USERENV(''LANG'')
           AND zrt.tax_rate_id(+)     = zxl.tax_rate_id
           AND zrt.language(+)        = USERENV(''LANG'')
           AND flk1.lookup_type       = ''ZX_RATE_TYPE''
           AND flk1.lookup_code       = zxl.tax_rate_type
           AND flk2.lookup_type(+)    = ''ZX_TAX_TYPE_CATEGORY''
           AND flk2.lookup_code(+)    = zxl.tax_type_code
           AND xdl.application_id     = :APPLICATION_ID
           AND xdl.ae_header_id       = :HEADER_ID
           AND xdl.ae_line_num        = :ORIG_LINE_NUMBER
           AND xdl.tax_rec_nrec_dist_ref_id = zrnd.rec_nrec_tax_dist_id(+)';

    C_TAX_NULL_QUERY                    VARCHAR2 (8000)
        := 'SELECT     NULL       TAX_LINE_ID
              ,NULL       TAX_REGIME
              ,NULL       TAX
              ,NULL       TAX_NAME
              ,NULL       TAX_STATUS_NAME
              ,NULL       TAX_RATE_NAME
              ,NULL       TAX_RATE
              ,NULL       TAX_RATE_TYPE_NAME
              ,NULL       TAX_DETERMINE_DATE
              ,NULL       TAX_POINT_DATE
              ,NULL       TAX_TYPE_CODE
              ,NULL       TAX_TYPE_NAME
              ,NULL       TAX_CODE
              ,NULL       TAX_REGISTRATION_NUMBER
              ,NULL       TRX_CURRENCY_CODE
              ,NULL       TAX_CURRENCY_CODE
              ,NULL       TAX_AMOUNT
              ,NULL       TAX_AMOUNT_TAX_CURRENCY
              ,NULL       TAX_AMOUNT_FUNCTIONAL_CURR
              ,NULL       TAXABLE_AMOUNT
              ,NULL       TAXABLE_AMOUNT_TAX_CURRENCY
              ,NULL       TAXABLE_AMT_FUNC_CURRENCY
              ,NULL       UNROUNDED_TAXABLE_AMOUNT
              ,NULL       UNROUNDED_TAX_AMOUNT
              ,NULL       RECOVERABLE_TAX_AMOUNT
              ,NULL       RECOVERABLE_TAX_AMT_TAX_CURR
              ,NULL       RECOVERABLE_TAX_AMT_FUNC_CURR
              ,NULL       NON_RECOVERABLE_TAX_AMOUNT
              ,NULL       NON_REC_TAX_AMT_TAX_CURR
              ,NULL       NON_REC_TAX_AMT_FUNC_CURR
              ,NULL       TAX_JURISDICTION_CODE
              ,NULL       SELF_ASSESSED_FLAG
              ,NULL       HQ_ESTB_REG_NUMBER
              ,NULL       REC_NREC_TAX_DIST_ID
              ,NULL       RECOVERY_TYPE_CODE
              ,NULL       RECOVERY_RATE_CODE
              ,NULL       REC_NREC_RATE
              ,NULL       RECOVERABLE_FLAG
              ,NULL       REC_NREC_TAX_AMT
              ,NULL       REC_NREC_TAX_AMT_TAX_CURR
              ,NULL       REC_NREC_TAX_AMT_FUNCL_CURR
      FROM    DUAL
     WHERE    1>2';


    --------------------------------------------------------------------------------
    -- constant for created_by details
    --------------------------------------------------------------------------------
    C_CREATED_QUERY                     VARCHAR2 (8000)
        := 'select last_name||first_name LEGAL_CREATED_BY
from hr_employees
where employee_id =
(
  select employee_id
  from fnd_user
  where user_id = :LEGAL_CREATED_ID
)';

    C_CREATED_NULL_QUERY                VARCHAR2 (8000)
        := 'select NULL LEGAL_CREATED_BY from dual where 1>2';

    --------------------------------------------------------------------------------
    -- constant for posted_by details
    --------------------------------------------------------------------------------
    C_POSTED_QUERY                      VARCHAR2 (8000)
        := 'select last_name||first_name LEGAL_POSTED_BY
from hr_employees
where employee_id =
(
  select employee_id
  from fnd_user
  where user_id = :LEGAL_POSTED_ID
)';

    C_POSTED_NULL_QUERY                 VARCHAR2 (8000)
        := 'select NULL LEGAL_POSTED_BY from dual where 1>2';



    --------------------------------------------------------------------------------
    -- constant for approval details
    --------------------------------------------------------------------------------
    C_APPROVED_QUERY                    VARCHAR2 (8000)
        := 'select last_name||first_name LEGAL_APPROVED_BY
from hr_employees
where employee_id =
(
  select employee_id
  from fnd_user
  where user_name =
  (
    select d.TEXT_VALUE
    from wf_items                 t
    ,wf_item_attribute_values d
         where d.item_key = t.item_key
         and d.name = ''APPROVER_NAME''
         and t.user_key = :GL_BATCH_NAME
         AND d.item_type=''GLBATCH''
         and t.begin_date in (select max(it.begin_date)
                                from wf_items                 it
                                    ,wf_item_attribute_values t1
                                    ,wf_item_attribute_values t
                               where it.user_key = :GL_BATCH_NAME
                                 and it.item_key = t.item_key
                                 and t1.item_type = ''GLBATCH''
                                and t1.item_key = t.item_key
                                 and t.ITEM_TYPE = ''GLBATCH''
                                 AND t.NAME = ''BATCH_NAME''
                                 and t.text_value = :GL_BATCH_NAME
                                 and t1.name = ''PERIOD_NAME''
                                 and t1.text_value = :PERIOD_NAME)
  )
)';

    C_APPROVED_NULL_QUERY               VARCHAR2 (8000)
        := 'select NULL LEGAL_APPROVED_BY from dual where 1>2';

    --------------------------------------------------------------------------------
    -- constant for COMMERCIAL_NUMBER details
    --------------------------------------------------------------------------------
    C_COMMERCIAL_QUERY                  VARCHAR2 (8000)
        := 'SELECT xler.registration_number LEGAL_COMMERCIAL_NUMBER
FROM XLE_REGISTRATIONS_V xler
WHERE  legislative_category = ''COMMERCIAL_LAW''
 AND legal_entity_id = :P_LEGAL_ENTITY_ID';

    C_COMMERCIAL_NULL_QUERY             VARCHAR2 (8000)
        := 'select NULL LEGAL_COMMERCIAL_NUMBER from dual where 1>2';


    --------------------------------------------------------------------------------
    -- constant for VAT_REGISTRATION details
    --------------------------------------------------------------------------------
    C_VAT_REGISTRATION_QUERY            VARCHAR2 (8000)
        := 'SELECT zptp.REP_REGISTRATION_NUMBER   LEGAL_VAT_REGISTRATION_NUMBER
FROM ZX_PARTY_TAX_PROFILE zptp ,XLE_ETB_PROFILES xetbp
WHERE zptp.PARTY_TYPE_CODE = ''LEGAL_ESTABLISHMENT''
AND xetbp.party_id=zptp.party_id
AND xetbp.MAIN_ESTABLISHMENT_FLAG = ''Y''
AND xetbp.LEGAL_ENTITY_ID = :P_LEGAL_ENTITY_ID';

    C_VAT_REGISTRATION_NULL_QUERY       VARCHAR2 (8000)
        := 'select NULL LEGAL_VAT_REGISTRATION_NUMBER from dual where 1>2';



    g_period_year_start_date            VARCHAR2 (30);
    g_period_year_end_date              VARCHAR2 (30);
    g_je_source_application_id          VARCHAR2 (30);
    g_flex_range_where                  VARCHAR2 (4000);        --bug 12586551
    g_start_period_num                  NUMBER;                 --bug 12609107
    g_end_period_num                    NUMBER;                 --bug 12609107


    --=============================================================================
    --        **************  forward  declaraions  ******************
    --=============================================================================
    FUNCTION get_flex_range_where (p_coa_id IN NUMBER, p_acct_flexfield_from IN VARCHAR2, p_acct_flexfield_to IN VARCHAR2)
        RETURN VARCHAR;

    PROCEDURE get_sla_query;

    PROCEDURE get_gl_query (p_accounts_range_specified IN VARCHAR2);

    --=============================================================================
    --               *********** Local Trace Routine **********
    --=============================================================================
    C_LEVEL_STATEMENT          CONSTANT NUMBER := FND_LOG.LEVEL_STATEMENT;
    C_LEVEL_PROCEDURE          CONSTANT NUMBER := FND_LOG.LEVEL_PROCEDURE;
    C_LEVEL_EVENT              CONSTANT NUMBER := FND_LOG.LEVEL_EVENT;
    C_LEVEL_EXCEPTION          CONSTANT NUMBER := FND_LOG.LEVEL_EXCEPTION;
    C_LEVEL_ERROR              CONSTANT NUMBER := FND_LOG.LEVEL_ERROR;
    C_LEVEL_UNEXPECTED         CONSTANT NUMBER := FND_LOG.LEVEL_UNEXPECTED;

    C_LEVEL_LOG_DISABLED       CONSTANT NUMBER := 99;
    C_DEFAULT_MODULE           CONSTANT VARCHAR2 (240)
        := 'xla.plsql.xxd_xla_jelines_rpt_pkg' ;

    g_log_level                         NUMBER;
    g_log_enabled                       BOOLEAN;

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
                p_location => 'xla_jelines_rpt_pkg.trace');
    END trace;

    /*======================================================================+
    |                                                                       |
    | PRIVATE FUNCTION                                                      |
    |                                                                       |
    |    get_flex_range_where :Return WHERE clauses FOR flexfield ranges    |
    |                                                                       |
    | PRIVATE Procedures                                                    |
    |    get_sla_query                                                      |
    |    get_gl_query                                                       |
    |                                                                       |
    |                                                                       |
    +======================================================================*/

    FUNCTION get_flex_range_where (p_coa_id IN NUMBER, p_acct_flexfield_from IN VARCHAR2, p_acct_flexfield_to IN VARCHAR2)
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
                       'p_acct_flexfield_from  = '
                    || TO_CHAR (p_acct_flexfield_from),
                p_level    => C_LEVEL_STATEMENT,
                p_module   => l_log_module);

            trace (
                p_msg      =>
                    'p_acct_flexfield_to = ' || TO_CHAR (p_acct_flexfield_to),
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
            p_operand1                       => p_acct_flexfield_from,
            p_operand2                       => p_acct_flexfield_to,
            x_where_expression               => l_where,
            x_numof_bind_variables           => l_numof_bind_variables,
            x_bind_variables                 => l_bind_variables);

        FOR i IN l_bind_variables.FIRST .. l_bind_variables.LAST
        LOOP
            l_segment_name   := l_bind_variables (i).NAME;
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
                p_location => 'xla_jelines_rpt_pkg.get_flex_range_where');
    END get_flex_range_where;


    --==============================================================================
    -- Private procedure get_sla_query to get value for sla query lexical parameters
    --==============================================================================
    PROCEDURE get_sla_query
    IS
        l_log_module           VARCHAR2 (240);
        l_other_param_filter   VARCHAR2 (8000) := ' ';
        --   l_flex_range_where      VARCHAR2(4000); bug 12586551
        l_application_id       NUMBER;
        l_post_programs        VARCHAR2 (2000) := ' ';
        l_event_classes        VARCHAR2 (2000) := ' ';
        l_event_types          VARCHAR2 (8000) := ' ';              --12663084
    BEGIN
        IF g_log_enabled
        THEN
            l_log_module   := C_DEFAULT_MODULE || '.get_sla_query';
        END IF;

        --
        IF (C_LEVEL_PROCEDURE >= g_log_level)
        THEN
            trace (p_msg      => 'BEGIN of get_sla_query',
                   p_level    => C_LEVEL_PROCEDURE,
                   p_module   => l_log_module);
        END IF;

        --Start changes V1.0 by Deckers IT Team -- Added Source_id_int_1 column for reporting purpose
        p_sla_col_1            :=
               'SELECT /*+ index(aeh XLA_AE_HEADERS_N5) no_index(ael MIS_XLA_AE_LINES_N1)  */
         to_char(aeh.accounting_date
                 ,''YYYY-MM-DD'')           GL_DATE
         ,fdu.user_name                     CREATED_BY
         ,aeh.created_by                    LEGAL_CREATED_ID
         ,gjb.posted_by                     LEGAL_POSTED_ID
         ,to_char(aeh.creation_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')    CREATION_DATE
         ,to_char(aeh.last_update_date
                 ,''YYYY-MM-DD'')           LAST_UPDATE_DATE
         ,to_char(aeh.gl_transfer_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')    GL_TRANSFER_DATE
         ,to_char(aeh.reference_date
                 ,''YYYY-MM-DD'')           REFERENCE_DATE
         ,to_char(aeh.completed_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')    COMPLETED_DATE
         ,null                              EXTERNAL_REFERENCE
         ,null                                REFERENCE_1
         ,null                                REFERENCE_4
         ,glp.period_year                   PERIOD_YEAR
         ,'''
            || g_period_year_start_date
            || '''    PERIOD_YEAR_START_DATE
         ,'''
            || g_period_year_end_date
            || '''      PERIOD_YEAR_END_DATE
         ,glp.period_num                    PERIOD_NUMBER
         ,aeh.period_name                   PERIOD_NAME
         ,to_char(glp.start_date
                         ,''YYYY-MM-DD'')       PERIOD_START_DATE
         ,to_char(glp.end_date
                         ,''YYYY-MM-DD'')       PERIOD_END_DATE
         ,ent.transaction_number            TRANSACTION_NUMBER
         ,ent.source_id_int_1            invoice_id
         ,to_char(xle.transaction_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')    TRANSACTION_DATE
         ,fsv1.header_name                  ACCOUNTING_SEQUENCE_NAME
         ,fsv1.version_name                 ACCOUNTING_SEQUENCE_VERSION
         ,aeh.completion_acct_seq_value     ACCOUNTING_SEQUENCE_NUMBER
         ,fsv2.header_name                  REPORTING_SEQUENCE_NAME
         ,fsv2.version_name                 REPORTING_SEQUENCE_VERSION
         ,aeh.close_acct_seq_value          REPORTING_SEQUENCE_NUMBER
         ,NULL                              DOCUMENT_CATEGORY
--         ,fns.sequence_name                 DOCUMENT_SEQUENCE_NAME  -- Bug 7043803 - Fetching sequence from FND_DOCUMENT_SEQUENCES
         ,fns.name                          DOCUMENT_SEQUENCE_NAME
         ,aeh.doc_sequence_value            DOCUMENT_SEQUENCE_NUMBER
         ,aeh.application_id                APPLICATION_ID
         ,fap.application_name              APPLICATION_NAME
         ,aeh.ledger_id                     LEDGER_ID
         ,glg.short_name                    LEDGER_SHORT_NAME
         ,glg.description                   LEDGER_DESCRIPTION
         ,glg.NAME                          LEDGER_NAME
         ,glg.currency_code                 LEDGER_CURRENCY
         ,aeh.ae_header_id                  HEADER_ID
         ,aeh.description                   HEADER_DESCRIPTION
         ,xlk1.meaning                      JOURNAL_ENTRY_STATUS
         ,xlk2.meaning                      TRANSFER_TO_GL_STATUS
         ,aeh.balance_type_code             BALANCE_TYPE_CODE
         ,xlk3.meaning                      BALANCE_TYPE
         ,glb.budget_name                   BUDGET_NAME
         ,get.encumbrance_type              ENCUMBRANCE_TYPE
         ,xlk4.meaning                      FUND_STATUS
         ,gjct.user_je_category_name        JE_CATEGORY_NAME
         ,gjst.user_je_source_name          JE_SOURCE_NAME ';
        --End changes V1.0 by Deckers IT Team -- Added Source_id_int_1 column for reporting purpose

        p_sla_col_2            := '  ,xle.event_id                      EVENT_ID
         ,to_char(xle.event_date
                 ,''YYYY-MM-DD'')           EVENT_DATE
         ,xle.event_number                  EVENT_NUMBER
         ,xet.event_class_code              EVENT_CLASS_CODE
         ,xect.NAME                         EVENT_CLASS_NAME
         ,aeh.event_type_code               EVENT_TYPE_CODE
         ,xet.NAME                          EVENT_TYPE_NAME
         ,ael.displayed_line_number         LINE_NUMBER
         ,ael.ae_line_num                   ORIG_LINE_NUMBER
         ,ael.accounting_class_code         ACCOUNTING_CLASS_CODE
         ,xlk5.meaning                      ACCOUNTING_CLASS_NAME
         ,ael.description                   LINE_DESCRIPTION
         ,ael.code_combination_id           CODE_COMBINATION_ID
         ,gcck.concatenated_segments        ACCOUNTING_CODE_COMBINATION
         ,xla_report_utility_pkg.get_ccid_desc(glg.chart_of_accounts_id
                                              , ael.code_combination_id)
                                            CODE_COMBINATION_DESCRIPTION
         ,gcck.gl_control_account           CONTROL_ACCOUNT_FLAG
         ,ael.currency_code                 ENTERED_CURRENCY
         ,ael.currency_conversion_rate      CONVERSION_RATE
         ,to_char(ael.currency_conversion_date
                 ,''YYYY-MM-DD'')           CONVERSION_RATE_DATE
         ,ael.currency_conversion_type      CONVERSION_RATE_TYPE_CODE
         ,gdct.user_conversion_type         CONVERSION_RATE_TYPE
         ,ael.entered_dr                    ENTERED_DR
         ,ael.entered_cr                    ENTERED_CR
         ,ael.unrounded_accounted_dr        UNROUNDED_ACCOUNTED_DR
         ,ael.unrounded_accounted_cr        UNROUNDED_ACCOUNTED_CR
         ,ael.accounted_dr                  ACCOUNTED_DR
         ,ael.accounted_cr                  ACCOUNTED_CR
         ,ael.statistical_amount            STATISTICAL_AMOUNT
         ,ael.jgzz_recon_ref                RECONCILIATION_REFERENCE
         ,ael.attribute_category            ATTRIBUTE_CATEGORY
         ,ael.attribute1                    ATTRIBUTE1
         ,ael.attribute2                    ATTRIBUTE2
         ,ael.attribute3                    ATTRIBUTE3
         ,ael.attribute4                    ATTRIBUTE4
         ,ael.attribute5                    ATTRIBUTE5
         ,ael.attribute6                    ATTRIBUTE6
         ,ael.attribute7                    ATTRIBUTE7
         ,ael.attribute8                    ATTRIBUTE8
         ,ael.attribute9                    ATTRIBUTE9
         ,ael.attribute10                   ATTRIBUTE10
         ,ael.party_type_code               PARTY_TYPE_CODE
         ,xlk6.meaning                      PARTY_TYPE';

        p_sla_col_3            := '   ,gcck.segment1                     SEGMENT1
         ,gcck.segment2                     SEGMENT2
         ,gcck.segment3                     SEGMENT3
         ,gcck.segment4                     SEGMENT4
         ,gcck.segment5                     SEGMENT5
         ,gcck.segment6                     SEGMENT6
         ,gcck.segment7                     SEGMENT7
         ,gcck.segment8                     SEGMENT8
         ,gcck.segment9                     SEGMENT9
         ,gcck.segment10                    SEGMENT10
         ,gcck.segment11                    SEGMENT11
         ,gcck.segment12                    SEGMENT12
         ,gcck.segment13                    SEGMENT13
         ,gcck.segment14                    SEGMENT14
         ,gcck.segment15                    SEGMENT15
         ,gcck.segment16                    SEGMENT16
         ,gcck.segment17                    SEGMENT17
         ,gcck.segment18                    SEGMENT18
         ,gcck.segment19                    SEGMENT19
         ,gcck.segment20                    SEGMENT20
         ,gcck.segment21                    SEGMENT21
         ,gcck.segment22                    SEGMENT22
         ,gcck.segment23                    SEGMENT23
         ,gcck.segment24                    SEGMENT24
         ,gcck.segment25                    SEGMENT25
         ,gcck.segment26                    SEGMENT26
         ,gcck.segment27                    SEGMENT27
         ,gcck.segment28                    SEGMENT28
         ,gcck.segment29                    SEGMENT29
         ,gcck.segment30                    SEGMENT30 ';

        p_sla_from             :=
            'FROM
          xla_ae_headers                   aeh
         ,xla_ae_lines                     ael
         ,xla_lookups                      xlk1
         ,xla_lookups                      xlk2
         ,xla_lookups                      xlk3
         ,xla_lookups                      xlk4
         ,xla_lookups                      xlk5
         ,xla_lookups                      xlk6
         ,xla_events                       xle
         ,xla_event_classes_tl             xect
         ,xla_event_types_tl               xet
         ,fnd_user                         fdu
         ,xla_transaction_entities         ent
         ,gl_ledgers                       glg
         ,gl_periods                       glp
         ,fnd_application_tl               fap
         ,gl_budget_versions               glb
         ,gl_encumbrance_types             get
         ,fun_seq_versions                 fsv1
         ,fun_seq_versions                 fsv2
--         ,fnd_sequences                    fns   -- Bug 7043803 - Fetching sequence from FND_DOCUMENT_SEQUENCES
         ,fnd_document_sequences           fns
         ,xla_subledgers                   xls
         ,gl_je_categories_tl              gjct
         ,gl_je_sources_tl                 gjst
         ,gl_daily_conversion_types        gdct
         ,gl_code_combinations_kfv         gcck';

        p_sla_join             :=
            'WHERE  glg.ledger_id              IN $ledger_id$
       AND  aeh.ledger_id              = glg.ledger_id
       AND  aeh.accounting_date  BETWEEN :P_GL_DATE_FROM AND :P_GL_DATE_TO
       AND  ael.application_id         =  aeh.application_id
       AND  ael.ae_header_id           =  aeh.ae_header_id
       AND  xlk1.lookup_type           =  ''XLA_ACCOUNTING_ENTRY_STATUS''
       AND  xlk1.lookup_code           =  aeh.ACCOUNTING_ENTRY_STATUS_CODE
       AND  xlk2.lookup_type           =  ''GL_TRANSFER_FLAG''
       AND  xlk2.lookup_code           =  aeh.GL_TRANSFER_STATUS_CODE
       AND  xlk3.lookup_type           =  ''XLA_BALANCE_TYPE''
       AND  xlk3.lookup_code           =  aeh.BALANCE_TYPE_CODE
       AND  xlk4.lookup_type(+)        = ''XLA_FUNDS_STATUS''
       AND  xlk4.lookup_code(+)        =  aeh.FUNDS_STATUS_CODE
       AND  xlk5.lookup_type           =  ''XLA_ACCOUNTING_CLASS''
       AND  xlk5.lookup_code           =  ael.ACCOUNTING_CLASS_CODE
       AND  xlk6.lookup_type(+)        =  ''XLA_PARTY_TYPE''
       AND  xlk6.lookup_code(+)        =  ael.party_type_code
       AND  xle.application_id         =  aeh.application_id
       AND  xle.event_id               =  aeh.event_id
       AND  xet.application_id         =  xle.application_id
       AND  xet.event_type_code        =  xle.event_type_code
       AND  xet.LANGUAGE               =  USERENV(''LANG'')
       AND  xect.application_id        =  xet.application_id
       AND  xect.entity_code           =  xet.entity_code
       AND  xect.event_class_code      =  xet.event_class_code
       AND  xect.LANGUAGE              =  USERENV(''LANG'')
       AND  ent.application_id         =  aeh.application_id
       AND  ent.entity_id              =  aeh.entity_id
       AND  fdu.user_id                =  ent.created_by
       AND  glp.period_name            =  aeh.period_name
       AND  glp.period_set_name        =  glg.period_set_name
       AND  fap.application_id         =  aeh.application_id
       AND  fap.LANGUAGE               =  USERENV(''LANG'')
       AND  glb.budget_version_id(+)   =  aeh.budget_version_id
       AND  get.encumbrance_type_id(+) =  ael.encumbrance_type_id
       AND  fsv1.seq_version_id(+)     =  aeh.completion_acct_seq_version_id
       AND  fsv2.seq_version_id(+)     =  aeh.close_acct_seq_version_id
       --AND  fns.application_id(+)      =  aeh.application_id  -- Bug 7655791
       AND  fns.doc_sequence_id(+)     =  aeh.doc_sequence_id  -- Bug 7043803 - Fetching sequence from FND_DOCUMENT_SEQUENCES
       AND  xls.application_id         =  aeh.application_id
       AND  gjct.je_category_name      =  aeh.je_category_name
       AND  gjct.LANGUAGE              =  USERENV(''LANG'')
       AND  gjst.je_source_name        =  xls.je_source_name
       AND  gjst.LANGUAGE              =  USERENV(''LANG'')
       AND  gdct.conversion_type(+)    =  ael.currency_conversion_type
       AND  gcck.code_combination_id   =  ael.code_combination_id  ';

        --
        -- User Transaction Identifiers
        --
        IF     p_include_user_trx_id_flag = 'Y'
           AND g_je_source_application_id IS NOT NULL
        THEN
            /*
            p_trx_identifiers :=
               xla_report_utility_pkg.get_transaction_id
                  (g_je_source_application_id
                  ,p_ledger_id)||' USERIDS ';*/
            --Removed for bug 7580995

            xla_report_utility_pkg.get_transaction_id (
                p_resp_application_id   => g_je_source_application_id,
                p_ledger_id             => p_ledger_id,
                p_trx_identifiers_1     => p_trx_identifiers_1,
                p_trx_identifiers_2     => p_trx_identifiers_2,
                p_trx_identifiers_3     => p_trx_identifiers_3,
                p_trx_identifiers_4     => p_trx_identifiers_4,
                p_trx_identifiers_5     => p_trx_identifiers_5); --Added for bug 7580995
        ELSE
            --   p_trx_identifiers  := ',NULL  USERIDS '; --Removed for bug 7580995
            p_trx_identifiers_1   := ',NULL  USERIDS '; --Added for bug 7580995
        END IF;

        --
        -- Third party information
        --
        IF p_party_type_code = 'S'
        THEN
            -- 5072266  Modify po_vendors to use ap_suppliers
            -- po_vendors pov  -> ap_suppliers  ap
            p_party_details   := ',aps.segment1             PARTY_NUMBER
          ,aps.vendor_name          PARTY_NAME
          ,hzp.jgzz_fiscal_code     PARTY_TYPE_TAXPAYER_ID
          ,hzp.tax_reference        PARTY_TAX_REGISTRATION_NUMBER
          ,hps.party_site_number    PARTY_SITE_NUMBER
          ,hps.party_site_name      PARTY_SITE_NAME
          ,NULL                     PARTY_SITE_TAX_RGSTN_NUMBER ';
            p_party_from      := ',ap_suppliers     aps
          ,ap_supplier_sites_all apss
          ,hz_parties       hzp
          ,hz_party_sites   hps ';
            p_party_join      :=
                ' AND  aps.vendor_id          = ael.party_id
           AND  hzp.party_id           = aps.party_id
           AND  apss.vendor_site_id(+) = ael.party_site_id
           AND  hps.party_site_id(+)   = apss.party_site_id  ';
        ELSIF p_party_type_code = 'C'
        THEN
            p_party_details   := ',hca.account_number           PARTY_NUMBER
          ,hzp.party_name               PARTY_NAME
          ,hzp.jgzz_fiscal_code         PARTY_TYPE_TAXPAYER_ID
          ,hzp.tax_reference            PARTY_TAX_REGISTRATION_NUMBER
          ,hps.party_site_number        PARTY_SITE_NUMBER
          ,hps.party_site_name          PARTY_SITE_NAME
          ,hzcu.tax_reference           PARTY_SITE_TAX_RGSTN_NUMBER   ';
            p_party_from      := ',hz_parties               hzp
          ,hz_party_sites           hps
          ,hz_cust_accounts         hca
          ,hz_cust_acct_sites_all   hcas
          ,hz_cust_site_uses_all    hzcu ';

            p_party_join      :=
                ' AND  hzp.party_id              = hca.party_id
           AND  hca.cust_account_id       = ael.party_id
           AND  hzcu.site_use_id(+)       = ael.party_site_id
           AND  hcas.cust_acct_site_id(+) = hzcu.cust_acct_site_id
           AND  hps.party_site_id(+)      = hcas.party_site_id  ';
        ELSE
            -- Modify 5072266 Modify po_vendors to use ap_suppliers
            -- po_vendors pov  -> ap_suppliers ap

            /* Below the inner query is having join to xla_ae_lines ael2
               because it seems that CASE statment doesn't allow to have
               outer join from parent query column.So as a workaround we
               have joined to xla_ae_lines ale2 and then through ale2 we
               have outer joined to sites table for handling cases where
               party_site_id can be NULL for a valid party_id
            */

            p_party_details   :=
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
            WHEN (ael.party_type_code = ''C'' and ael.party_id is not null) THEN
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
            END       PARTY_INFO';

            p_party_from   := ' ';
            p_party_join   := ' ';
        END IF;


        --
        -- Building GL infomration in SLA query
        -- Modified for bug 5555715
        --


        p_gl_columns           :=
            ',gjb.name                 GL_BATCH_NAME
          ,gjb.default_effective_date   GL_DEFAULT_EFFECTIVE_DATE
          ,glk1.meaning             GL_BATCH_STATUS
          ,to_char(gjb.posted_date
              ,''YYYY-MM-DD'')      POSTED_DATE
          ,gjh.NAME                 GL_JE_NAME
          ,fns1.name                GL_DOC_SEQUENCE_NAME  --added bug 10385468
          ,gjh.doc_sequence_value   GL_DOC_SEQUENCE_VALUE --added bug 10385468
          ,gjl.je_line_num          GL_LINE_NUMBER ';

        p_gl_view              := ',gl_import_references             gir
          ,gl_je_lines                      gjl
          ,gl_je_headers                    gjh
          ,gl_je_batches                    gjb
          ,gl_lookups                       glk1
          ,fnd_document_sequences           fns1 ';        --added bug 10385468

        -- bug8250215
        -- No Outer Join when GLTransfer/Posting Status is
        -- N(Not Posted in GL) and Y(Posted in GL) , else Outer Join

        IF NVL (p_posting_status_code, 'A') = 'N'
        THEN
            p_gl_join   :=
                ' AND  gir.gl_sl_link_id     =  ael.gl_sl_link_id
           AND  gir.gl_sl_link_table  =  ael.gl_sl_link_table
           AND  fns1.application_id(+) =  101                 -- added bug 10385468
           AND  fns1.doc_sequence_id(+)=  gjh.doc_sequence_id -- added bug 10385468
           AND  gjl.je_header_id      =  gir.je_header_id
           AND  gjl.je_line_num       =  gir.je_line_num
           AND  gjh.je_header_id      =  gir.je_header_id
           AND  gjb.je_batch_id       =  gir.je_batch_id
       AND  decode(gjh.je_header_id,null,''Y'',gjh.je_from_sla_flag) in (''U'', ''Y'') -- bug 7163158
           AND  glk1.lookup_type      = ''BATCH_STATUS''
           AND  glk1.lookup_code      =  gjb.status
           AND  NVL(gjh.status,''U'')   <> ''P''';
        -- removed outer join for bug:8250215

        ELSIF NVL (p_posting_status_code, 'A') = 'Y'
        THEN
            p_gl_join   :=
                ' AND  gir.gl_sl_link_id     =  ael.gl_sl_link_id
           AND  gir.gl_sl_link_table  =  ael.gl_sl_link_table
           AND  fns1.application_id(+) =  101                 -- added bug 10385468
           AND  fns1.doc_sequence_id(+)=  gjh.doc_sequence_id -- added bug 10385468
           AND  gjl.je_header_id      =  gir.je_header_id
           AND  gjl.je_line_num       =  gir.je_line_num
           AND  gjh.je_header_id      =  gir.je_header_id
           AND  gjb.je_batch_id       =  gir.je_batch_id
       AND  gjh.je_from_sla_flag  in (''U'', ''Y'') -- bug 7163158
           AND  glk1.lookup_type      = ''BATCH_STATUS''
           AND  glk1.lookup_code      =  gjb.status
           AND  gjh.status            =  ''P'' ';
        ELSIF NVL (p_posting_status_code, 'A') = 'T'
        THEN
            p_gl_join   :=
                ' AND  gir.gl_sl_link_id     =  ael.gl_sl_link_id
           AND  gir.gl_sl_link_table  =  ael.gl_sl_link_table
           AND  fns1.application_id(+) =  101                 -- added bug 10385468
           AND  fns1.doc_sequence_id(+)=  gjh.doc_sequence_id -- added bug 10385468
           AND  gjl.je_header_id      =  gir.je_header_id
           AND  gjl.je_line_num       =  gir.je_line_num
           AND  gjh.je_header_id      =  gir.je_header_id
           AND  gjb.je_batch_id       =  gir.je_batch_id
       AND  gjh.je_from_sla_flag  in (''U'', ''Y'') -- bug 7163158
           AND  glk1.lookup_type      = ''BATCH_STATUS''
           AND  glk1.lookup_code      =  gjb.status
       ';                                     -- added for bug:8250215
        ELSIF NVL (p_posting_status_code, 'A') IN ('X', 'A')
        THEN                           -- added status code: X for bug:8250215
            p_gl_join   :=
                ' AND  gir.gl_sl_link_id(+)       =  ael.gl_sl_link_id
           AND  gir.gl_sl_link_table(+)    =  ael.gl_sl_link_table
           AND  fns1.application_id(+) =  101                 -- added bug 10385468
           AND  fns1.doc_sequence_id(+)=  gjh.doc_sequence_id -- added bug 10385468
           AND  gjl.je_header_id(+)        =  gir.je_header_id
           AND  gjl.je_line_num(+)         =  gir.je_line_num
           AND  gjh.je_header_id(+)        =  gir.je_header_id
           AND  gjb.je_batch_id (+)        =  gir.je_batch_id
       AND  decode(gjh.je_header_id,null,''Y'',gjh.je_from_sla_flag) in (''U'', ''Y'') -- bug 7163158
           AND  glk1.lookup_type(+)        = ''BATCH_STATUS''
           AND  glk1.lookup_code(+)        =  gjb.status ';
        END IF;

        IF p_gl_batch_name IS NOT NULL
        THEN
            p_gl_join   :=
                p_gl_join || ' AND gjb.name = ''' || p_gl_batch_name || '''';
        END IF;

        --
        -- Building Legal entity information: Bug 5659083
        --

        IF p_include_le_info_flag = 'NONE'
        THEN
            p_sla_legal_ent_col    := ' ';
            p_sla_legal_ent_from   := ' ';
            p_sla_legal_ent_join   := ' ';
        ELSE
            p_sla_legal_ent_col    := C_SLA_TRX_LEGAL_ENT_COL;
            p_sla_legal_ent_from   := C_SLA_TRX_LEGAL_ENT_FROM;
            p_sla_legal_ent_join   := C_SLA_TRX_LEGAL_ENT_JOIN;
        END IF;

        IF p_trx_legal_entity_id IS NOT NULL
        THEN
            p_sla_legal_ent_join   :=
                   p_sla_legal_ent_join
                || ' AND ent.legal_entity_id  = :p_trx_legal_entity_id ';
        END IF;


        ----------------------------------------------------------------------------
        -- build filter condition based on parameters
        ----------------------------------------------------------------------------
        --
        -- <conditions based on p_post_acct_program_rowid >
        --
        IF p_post_acct_program_rowid IS NOT NULL
        THEN
            l_post_programs        :=
                l_post_programs || ' AND ael.accounting_class_code IN (NULL';

            /*FOR c1 in (select accounting_class_code
                         from xla_acct_class_assgns xac, xla_post_acct_progs_b xpa
                        where xpa.rowid              = p_post_acct_program_rowid
                          and xac.program_owner_code = xpa.program_owner_code
                          and xac.program_code       = xpa.program_code
                      )*/
            -- Changed for bug 8337868
            FOR c1
                IN (SELECT accounting_class_code
                      FROM xla_acct_class_assgns xac, xla_post_acct_progs_b xpa, xla_assignment_defns_b xad
                     WHERE     xpa.ROWID = p_post_acct_program_rowid
                           AND xac.program_owner_code =
                               xpa.program_owner_code
                           AND xac.program_code = xpa.program_code
                           AND xad.program_code = xac.program_code
                           AND xad.program_owner_code =
                               xac.program_owner_code
                           AND xad.assignment_code = xac.assignment_code
                           AND xad.assignment_owner_code =
                               xac.assignment_owner_code
                           AND xad.enabled_flag = 'Y'--  and nvl(xad.ledger_id, p_ledger_id) = p_ledger_id  Removing this as not required
                                                     )
            LOOP
                l_post_programs   :=
                       l_post_programs
                    || ','''
                    || c1.accounting_class_code
                    || '''';
            END LOOP;

            l_post_programs        := l_post_programs || ')';

            l_other_param_filter   := l_other_param_filter || l_post_programs;
        END IF;

        --
        -- <conditions based on transaction view >
        --
        IF p_transaction_view IS NOT NULL
        THEN
            l_event_classes        :=
                l_event_classes || ' AND xet.event_class_code IN (NULL';

            FOR c1
                IN (SELECT DISTINCT event_class_code
                      FROM xla_event_class_attrs
                     WHERE     application_id = g_je_source_application_id
                           AND reporting_view_name = p_transaction_view)
            LOOP
                l_event_classes   :=
                    l_event_classes || ',''' || c1.event_class_code || '''';
            END LOOP;

            l_event_classes        := l_event_classes || ')';

            l_other_param_filter   := l_other_param_filter || l_event_classes;

            --added filter on event types based on event classes 12663084
            l_event_types          :=
                l_event_types || ' AND aeh.event_type_code IN (NULL';

            FOR c1
                IN (SELECT DISTINCT xet.event_type_code
                      FROM xla_event_class_attrs xeca, xla_event_types_b xet
                     WHERE     xeca.application_id =
                               g_je_source_application_id
                           AND xeca.reporting_view_name = p_transaction_view
                           AND xeca.event_class_code = xet.event_class_code
                           AND xeca.entity_code = xet.entity_code
                           AND xeca.application_id = xet.application_id)
            LOOP
                l_event_types   :=
                    l_event_types || ',''' || c1.event_type_code || '''';
            END LOOP;

            l_event_types          := l_event_types || ')';

            l_other_param_filter   := l_other_param_filter || l_event_types;
        --added filter on event types based on event classes 12663084
        END IF;

        --
        -- < conditions based on event class rowid >
        --
        IF p_event_class_rowid IS NOT NULL AND p_transaction_view IS NULL
        THEN
            SELECT ' AND xet.event_class_code = ''' || event_class_code || ''' '
              INTO l_event_classes
              FROM xla_event_classes_b
             WHERE ROWID = p_event_class_rowid;

            l_other_param_filter   := l_other_param_filter || l_event_classes;

            --added filter on event types based on event classes 12663084
            l_event_types          :=
                l_event_types || ' AND aeh.event_type_code IN (NULL';

            FOR c1
                IN (SELECT DISTINCT xet.event_type_code
                      FROM xla_event_classes_b xec, xla_event_types_b xet
                     WHERE     xec.ROWID = p_event_class_rowid
                           AND xec.event_class_code = xet.event_class_code
                           AND xec.entity_code = xet.entity_code
                           AND xec.application_id = xet.application_id)
            LOOP
                l_event_types   :=
                    l_event_types || ',''' || c1.event_type_code || '''';
            END LOOP;

            l_event_types          := l_event_types || ')';

            l_other_param_filter   := l_other_param_filter || l_event_types;
        --added filter on event types based on event classes 12663084
        END IF;

        --
        -- < conditions based on process category rowid >
        --
        IF     p_process_category_rowid IS NOT NULL
           AND p_transaction_view IS NULL
           AND p_event_class_rowid IS NULL
        THEN
            l_event_classes        :=
                l_event_classes || ' AND xet.event_class_code IN (NULL';

            FOR c1
                IN (SELECT DISTINCT event_class_code
                      FROM xla_event_class_grps_b a, xla_event_class_attrs b
                     WHERE     a.application_id = b.application_id
                           AND a.event_class_group_code =
                               b.event_class_group_code
                           AND a.ROWID = p_process_category_rowid)
            LOOP
                l_event_classes   :=
                    l_event_classes || ',''' || c1.event_class_code || '''';
            END LOOP;

            l_event_classes        := l_event_classes || ')';

            l_other_param_filter   := l_other_param_filter || l_event_classes;

            --added filter on event types based on event classes 12663084
            l_event_types          :=
                l_event_types || ' AND aeh.event_type_code IN (NULL';

            FOR c1
                IN (SELECT DISTINCT xet.event_type_code
                      FROM xla_event_class_grps_b xecg, xla_event_class_attrs xeca, xla_event_types_b xet
                     WHERE     xecg.application_id = xeca.application_id
                           AND xecg.event_class_group_code =
                               xeca.event_class_group_code
                           AND xecg.ROWID = p_process_category_rowid
                           AND xeca.event_class_code = xet.event_class_code
                           AND xeca.entity_code = xet.entity_code
                           AND xeca.application_id = xet.application_id)
            LOOP
                l_event_types   :=
                    l_event_types || ',''' || c1.event_type_code || '''';
            END LOOP;

            l_event_types          := l_event_types || ')';

            l_other_param_filter   := l_other_param_filter || l_event_types;
        --added filter on event types based on event classes 12663084
        END IF;

        --
        -- <conditions based on transaction number> bug 8337868
        --
        IF p_trx_num_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.transaction_number >= '
                || ''''
                || p_trx_num_from
                || '''';
        END IF;

        IF p_trx_num_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.transaction_number <= '
                || ''''
                || p_trx_num_to
                || '''';
        END IF;


        --
        -- <conditions based on creation date>
        --
        IF p_creation_date_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.creation_date >= '
                || ''''
                || p_creation_date_from
                || '''';
        END IF;

        IF p_creation_date_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.creation_date <= '
                || ''''
                || p_creation_date_to
                || '''';
        END IF;

        --
        -- <conditions based on transaction date>
        --
        IF p_transaction_date_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND xle.transaction_date >= '
                || ''''
                || p_transaction_date_from
                || '''';
        END IF;

        IF p_transaction_date_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || 'AND xle.transaction_date <= '
                || ''''
                || p_transaction_date_to
                || '''';
        END IF;

        --
        -- <conditions based on je status>
        --
        IF NVL (p_je_status_code, 'A') = 'F'
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.accounting_entry_status_code = ''F'' ';
        ELSIF NVL (p_je_status_code, 'A') = 'D'
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.accounting_entry_status_code = ''D'' ';
        ELSIF NVL (p_je_status_code, 'A') = 'I'
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.accounting_entry_status_code '
                || ' IN (''I'',''R'',''RELATED_EVENT_ERROR'') ';
        ELSE
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.accounting_entry_status_code <> ''N'' ';
        END IF;

        --
        -- added for bug 8250215
        -- Look Up    Transfer/Posting Status     AEH.GL_TRANSFER_STATUS_CODE
        -- ====================================================================
        -- Y              Posted In GL                      Y
        -- N            Not Posted In GL                    Y
        -- T           Transferred to GL               No Condition
        -- X          Not Transferred to GL                 N
        -- NULL           Every thing                  No Condition

        IF NVL (p_posting_status_code, 'A') = 'X'
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.gl_transfer_status_code = ''N'' ';
        ELSIF NVL (p_posting_status_code, 'A') IN ('N', 'Y')
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.gl_transfer_status_code = ''Y'' ';
        END IF;

        --
        -- <conditions based on gl je source (g_je_source_application_id)>
        --
        IF g_je_source_application_id IS NOT NULL
        THEN
            p_sla_col_1   :=
                REPLACE (
                    p_sla_col_1,
                    'index(aeh XLA_AE_HEADERS_N5) no_index(ael MIS_XLA_AE_LINES_N1)',
                    'leading(xls glg aeh glp) use_nl(glp) index(aeh XLA_AE_HEADERS_N5) no_index(ael MIS_XLA_AE_LINES_N1)');

            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.application_id = '
                || g_je_source_application_id;
        END IF;

        --
        -- <conditions based on accounting sequence name and number range>
        --
        IF p_acct_sequence_version IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.completion_acct_seq_version_id = '
                || p_acct_sequence_version;
        END IF;

        IF p_acct_sequence_num_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.completion_acct_seq_value >= '
                || p_acct_sequence_num_from;
        END IF;

        IF p_acct_sequence_num_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.completion_acct_seq_value <= '
                || p_acct_sequence_num_to;
        END IF;

        --
        -- <conditions based on reporting sequence name and number range>
        --
        IF p_rpt_sequence_version IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.close_acct_seq_version_id = '
                || p_rpt_sequence_version;
        END IF;

        IF p_rpt_sequence_num_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.close_acct_seq_value >= '
                || p_rpt_sequence_num_from;
        END IF;

        IF p_rpt_sequence_num_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.close_acct_seq_value <= '
                || p_rpt_sequence_num_to;
        END IF;


        -- <conditions based on document seq name>
        --  Bug #5741692 Added condition based on document sequence name
        IF p_doc_seq_name IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND fns.name = '''
                || p_doc_seq_name
                || '''';
        END IF;


        --
        -- <conditions based on document sequence name and number range>
        --
        IF p_doc_sequence_num_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.doc_sequence_value >= '
                || p_doc_sequence_num_from;
        END IF;

        IF p_doc_sequence_num_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.doc_sequence_value <= '
                || p_doc_sequence_num_to;
        END IF;

        --
        -- <condition based on party type >
        --
        IF p_party_type_code IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ael.party_type_code = '
                || ''''
                || p_party_type_code
                || '''';
        END IF;

        --
        -- <condition based on party name >
        --
        IF p_party_name IS NOT NULL
        THEN
            /* Changed from hzp to XLA_AE_LINES for bug#12571692 */
            l_other_param_filter   :=
                l_other_param_filter || ' AND ael.party_id = ' || p_party_id;
        END IF;

        --
        -- <condition based on party number range >
        --
        IF p_party_number_from IS NOT NULL
        THEN
            IF p_party_type_code = 'S'
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND aps.segment1 >= '
                    || ''''
                    || p_party_number_from
                    || '''';
            ELSIF p_party_type_code = 'C'
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND hca.account_number >= '
                    || ''''
                    || p_party_number_from
                    || '''';
            END IF;
        END IF;

        IF p_party_number_to IS NOT NULL
        THEN
            IF p_party_type_code = 'S'
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND aps.segment1 <= '
                    || ''''
                    || p_party_number_to
                    || '''';
            ELSIF p_party_type_code = 'C'
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND hca.account_number <= '
                    || ''''
                    || p_party_number_to
                    || '''';
            END IF;
        END IF;

        --
        -- <conditions based on period type>  Added for bug 7645837
        --
        IF p_period_type IS NOT NULL
        THEN
            IF p_period_type = 'A'
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND glp.adjustment_period_flag = ''Y'' ';
            ELSIF p_period_type = 'N'
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND glp.adjustment_period_flag = ''N'' ';
            END IF;
        END IF;


        --
        -- <conditions based on gl ge category>
        --
        IF p_je_category IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.je_category_name = '''
                || p_je_category
                || '''';
        END IF;

        --
        -- <conditions based on balance type>
        --
        IF p_balance_type_code IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.balance_type_code = '''
                || p_balance_type_code
                || '''';
        END IF;

        --
        -- <conditions based on budget_version_id>
        --
        IF p_budget_version_id IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND aeh.budget_version_id = '
                || p_budget_version_id;
        END IF;

        --
        -- <conditions based on encumbrance type>
        --
        IF p_encumbrance_type_id IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ael.encumbrance_type_id = '
                || p_encumbrance_type_id;
        END IF;

        --
        -- <conditions based on include zero amount flag>
        --
        IF p_include_zero_amount_flag = 'N'
        THEN
            --bug#6978940 changed > 0  to <> 0
            l_other_param_filter   :=
                l_other_param_filter || ' AND ( NVL(ael.accounted_cr,0) <> 0
                                       OR NVL(ael.accounted_dr,0) <> 0 ) ';
        END IF;

        --
        -- <conditions based on entered currency code>
        --
        IF p_entered_currency IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ael.currency_code ='''
                || p_entered_currency
                || '''';
        END IF;

        --
        -- <conditions based on accounted amount range>
        --
        IF p_accounted_amount_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND (NVL(ael.accounted_cr,0) >= '
                || p_accounted_amount_from
                || ' OR NVL(ael.accounted_dr,0) >= '
                || p_accounted_amount_from
                || ') ';
        END IF;

        IF p_accounted_amount_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND (NVL(ael.accounted_cr,0) <= '
                || p_accounted_amount_to
                || ' OR NVL(ael.accounted_dr,0) <= '
                || p_accounted_amount_to
                || ') ';
        END IF;


        --
        -- <conditions based on side>
        --
        IF p_side_code = 'DEBIT'
        THEN
            l_other_param_filter   :=
                l_other_param_filter || ' AND ( NVL(ael.accounted_cr,0)
                                      - NVL(ael.accounted_dr,0) < 0) ';
        ELSIF p_side_code = 'CREDIT'
        THEN
            l_other_param_filter   :=
                l_other_param_filter || ' AND ( NVL(ael.accounted_cr,0)
                                      - NVL(ael.accounted_dr,0) > 0) ';
        END IF;

        --
        -- <conditions based on valuation method>
        --
        IF p_valuation_method IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.valuation_method = '''
                || p_valuation_method
                || '''';
        END IF;

        --
        -- <conditions based on security identifiers>
        --
        IF p_security_id_int_1 IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.security_id_int_1 = '
                || p_security_id_int_1;
        END IF;

        IF p_security_id_int_2 IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.security_id_int_2 = '
                || p_security_id_int_2;
        END IF;

        IF p_security_id_int_3 IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.security_id_int_3 = '
                || p_security_id_int_3;
        END IF;

        IF p_security_id_char_1 IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.security_id_char_1 = '''
                || p_security_id_char_1
                || '''';
        END IF;

        IF p_security_id_char_2 IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.security_id_char_2 = '''
                || p_security_id_char_2
                || '''';
        END IF;

        IF p_security_id_char_3 IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND ent.security_id_char_3 ='''
                || p_security_id_char_3
                || '''';
        END IF;

        IF     p_account_flexfield_from IS NOT NULL
           AND p_account_flexfield_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                l_other_param_filter || ' AND ' || g_flex_range_where; --bug 12586551
        END IF;

        p_other_param_filter   := l_other_param_filter;

        IF (C_LEVEL_PROCEDURE >= g_log_level)
        THEN
            trace (p_msg      => 'END of get_sla_query',
                   p_level    => C_LEVEL_PROCEDURE,
                   p_module   => l_log_module);
        END IF;
    EXCEPTION
        WHEN xla_exceptions_pkg.application_exception
        THEN
            RAISE;
        WHEN OTHERS
        THEN
            xla_exceptions_pkg.raise_message (
                p_location => 'xla_jelines_rpt_pkg.get_sla_query');
    END get_sla_query;

    --==============================================================================
    -- Private procedure get_gl_query to get value for GL query lexical parameters
    --==============================================================================
    PROCEDURE get_gl_query (p_accounts_range_specified IN VARCHAR2)
    IS
        l_log_module           VARCHAR2 (240);
        l_other_param_filter   VARCHAR2 (8000);
    --   l_flex_range_where     VARCHAR2(4000); bug 12586551
    BEGIN
        IF g_log_enabled
        THEN
            l_log_module   := C_DEFAULT_MODULE || '.get_gl_query';
        END IF;

        --
        IF (C_LEVEL_PROCEDURE >= g_log_level)
        THEN
            trace (p_msg      => 'BEGIN of get_gl_query',
                   p_level    => C_LEVEL_PROCEDURE,
                   p_module   => l_log_module);
        END IF;

        /*
            Added the ordered hint in gl query for bug#8815942
            In customers case the query was hitting gl_je_lines first and taking a path to gl_je_headers causing
            performance. Leading hint to start the query from gl_je_headers was not working at customers instance used ordered
            to start from glh filter the records and then hit gll. The ordered hint has improved the performance of Journal Entries Query
            by 50 percent. Removed the ordered hint as part of bug#12609107
         */



        /* begin performance fix bug14050580 */

        IF p_accounts_range_specified = 'Y'
        THEN
            p_gl_col_1   := 'SELECT /*+ leading(glg glp gcck) */ ';
        ELSE
            p_gl_col_1   := 'SELECT /*+ leading(glg glp) */ ';
        END IF;

        /* End performance fix bug14050580 */

        p_gl_col_1   :=
               p_gl_col_1
            || '
          to_char(glh.default_effective_date
                 ,''YYYY-MM-DD'')           GL_DATE
          ,fdu.user_name                    CREATED_BY
          ,glh.created_by                   LEGAL_CREATED_ID
          ,gjb.posted_by                    LEGAL_POSTED_ID
          ,to_char(glh.creation_date
                 ,''YYYY-MM-DD"T"hh:mi:ss'')    CREATION_DATE
          ,to_char(glh.last_update_date
                 ,''YYYY-MM-DD'')           LAST_UPDATE_DATE
          ,NULL                             GL_TRANSFER_DATE
         ,to_char(glh.reference_date
                 ,''YYYY-MM-DD'')           REFERENCE_DATE
         ,NULL                              COMPLETED_DATE
         ,glh.external_reference            EXTERNAL_REFERENCE
         ,gll.reference_1                    REFERENCE_1
         ,gll.reference_4                    REFERENCE_4
         ,glp.period_year                   PERIOD_YEAR
         ,'''
            || g_period_year_start_date
            || '''   PERIOD_YEAR_START_DATE
         ,'''
            || g_period_year_end_date
            || '''     PERIOD_YEAR_END_DATE
         ,glp.period_num                    PERIOD_NUMBER
         ,glh.period_name                   PERIOD_NAME
         ,to_char(glp.start_date
                         ,''YYYY-MM-DD'')   PERIOD_START_DATE
         ,to_char(glp.end_date
                        ,''YYYY-MM-DD'')    PERIOD_END_DATE
         ,NULL                              TRANSACTION_NUMBER
         --Added by Deckers IT Team on 28 May 2017
         ,NULL                              INVOICE_ID
         --Added by Deckers IT Team on 28 May 2017
         ,NULL                              TRANSACTION_DATE
         ,fsv1.header_name                  ACCOUNTING_SEQUENCE_NAME
         ,fsv1.version_name                 ACCOUNTING_SEQUENCE_VERSION
         ,glh.posting_acct_seq_value        ACCOUNTING_SEQUENCE_NUMBER
         ,fsv2.header_name                  REPORTING_SEQUENCE_NAME
         ,fsv2.version_name                 REPORTING_SEQUENCE_VERSION
         ,glh.close_acct_seq_value          REPORTING_SEQUENCE_NUMBER
         ,NULL                              DOCUMENT_CATEGORY
         ,NULL                              DOCUMENT_SEQUENCE_NAME
         ,NULL                              DOCUMENT_SEQUENCE_NUMBER
         ,NULL                              APPLICATION_ID
         ,NULL                              APPLICATION_NAME
         ,glh.ledger_id                     LEDGER_ID
         ,glg.short_name                    LEDGER_SHORT_NAME
         ,glg.description                   LEDGER_DESCRIPTION
         ,glg.NAME                          LEDGER_NAME
         ,glg.currency_code                 LEDGER_CURRENCY
         ,glh.je_header_id                  HEADER_ID
         ,glh.description                   HEADER_DESCRIPTION
         ,NULL                              JOURNAL_ENTRY_STATUS
         ,NULL                              TRANSFER_TO_GL_STATUS
         ,glh.actual_flag                   BALANCE_TYPE_CODE
         ,xlk.meaning                       BALANCE_TYPE
         ,gbv.budget_name                   BUDGET_NAME
         ,get.encumbrance_type              ENCUMBRANCE_TYPE
         ,NULL                              FUND_STATUS
         ,gjct.user_je_category_name        JE_CATEGORY_NAME
         ,gjst.user_je_source_name          JE_SOURCE_NAME  --bug12408239
         ,gjb.NAME                          GL_BATCH_NAME
         ,gjb.default_effective_date           GL_DEFAULT_EFFECTIVE_DATE
         ,glk2.meaning                      GL_BATCH_STATUS
         ,to_char(glh.posted_date
                 ,''YYYY-MM-DD'')           POSTED_DATE
         ,glh.NAME                          GL_JE_NAME
--         ,fsq.sequence_name                 GL_DOC_SEQUENCE_NAME -- krsankar - Commented as part of Bug 7153425
         ,fsq.name                          GL_DOC_SEQUENCE_NAME
         ,glh.doc_sequence_value            GL_DOC_SEQUENCE_VALUE
         ,gll.je_line_num                   GL_LINE_NUMBER
         ,NULL                              EVENT_ID
         ,NULL                              EVENT_DATE
         ,NULL                              EVENT_NUMBER
         ,NULL                              EVENT_CLASS_CODE
         ,NULL                              EVENT_CLASS_NAME
         ,NULL                              EVENT_TYPE_CODE
         ,NULL                              EVENT_TYPE_NAME
         ,gll.je_line_num                   LINE_NUMBER
         ,gll.je_line_num                   ORIG_LINE_NUMBER
         ,NULL                              ACCOUNTING_CLASS_CODE
         ,NULL                              ACCOUNTING_CLASS_NAME
         ,gll.description                   LINE_DESCRIPTION
         ,gll.code_combination_id           CODE_COMBINATION_ID
         ,gcck.concatenated_segments        ACCOUNTING_CODE_COMBINATION
         ,xla_report_utility_pkg.get_ccid_desc(glg.chart_of_accounts_id
                                              , gll.code_combination_id)
                                            CODE_COMBINATION_DESCRIPTION
         ,gcck.gl_control_account           CONTROL_ACCOUNT_FLAG
         ,glh.currency_code                 ENTERED_CURRENCY
         ,glh.currency_conversion_rate      CONVERSION_RATE
         ,to_char(glh.currency_conversion_date
                 ,''YYYY-MM-DD'')           CONVERSION_RATE_DATE
         ,glh.currency_conversion_type      CONVERSION_RATE_TYPE_CODE
         ,gdct.user_conversion_type         CONVERSION_RATE_TYPE
         ,gll.entered_dr                    ENTERED_DR
         ,gll.entered_cr                    ENTERED_CR
         ,NULL                              UNROUNDED_ACCOUNTED_DR
         ,NULL                              UNROUNDED_ACCOUNTED_CR
         ,gll.accounted_dr                  ACCOUNTED_DR
         ,gll.accounted_cr                  ACCOUNTED_CR
         ,gll.stat_amount                   STATISTICAL_AMOUNT
         ,gll.jgzz_recon_ref_11i            RECONCILIATION_REFERENCE
         ,gll.CONTEXT                       ATTRIBUTE_CATEGORY
         ,gll.attribute1                    ATTRIBUTE1
         ,gll.attribute2                    ATTRIBUTE2
         ,gll.attribute3                    ATTRIBUTE3
         ,gll.attribute4                    ATTRIBUTE4
         ,gll.attribute5                    ATTRIBUTE5
         ,gll.attribute6                    ATTRIBUTE6
         ,gll.attribute7                    ATTRIBUTE7
         ,gll.attribute8                    ATTRIBUTE8
         ,gll.attribute9                    ATTRIBUTE9
         ,gll.attribute10                   ATTRIBUTE10
         ,NULL                              PARTY_TYPE_CODE
         ,NULL                              PARTY_TYPE ';

        p_gl_col_2   := '  ,gcck.segment1                     SEGMENT1
         ,gcck.segment2                     SEGMENT2
         ,gcck.segment3                     SEGMENT3
         ,gcck.segment4                     SEGMENT4
         ,gcck.segment5                     SEGMENT5
         ,gcck.segment6                     SEGMENT6
         ,gcck.segment7                     SEGMENT7
         ,gcck.segment8                     SEGMENT8
         ,gcck.segment9                     SEGMENT9
         ,gcck.segment10                    SEGMENT10
         ,gcck.segment11                    SEGMENT11
         ,gcck.segment12                    SEGMENT12
         ,gcck.segment13                    SEGMENT13
         ,gcck.segment14                    SEGMENT14
         ,gcck.segment15                    SEGMENT15
         ,gcck.segment16                    SEGMENT16
         ,gcck.segment17                    SEGMENT17
         ,gcck.segment18                    SEGMENT18
         ,gcck.segment19                    SEGMENT19
         ,gcck.segment20                    SEGMENT20
         ,gcck.segment21                    SEGMENT21
         ,gcck.segment22                    SEGMENT22
         ,gcck.segment23                    SEGMENT23
         ,gcck.segment24                    SEGMENT24
         ,gcck.segment25                    SEGMENT25
         ,gcck.segment26                    SEGMENT26
         ,gcck.segment27                    SEGMENT27
         ,gcck.segment28                    SEGMENT28
         ,gcck.segment29                    SEGMENT29
         ,gcck.segment30                    SEGMENT30
         ,NULL                              USERIDS ';

        p_gl_from    :=
            'FROM
          gl_je_headers                     glh
         ,gl_je_lines                       gll
         ,gl_ledgers                        glg
         ,xla_lookups                       xlk
         ,gl_lookups                        glk2
         ,gl_budget_versions                gbv
         ,fnd_user                          fdu
         ,gl_period_statuses                glp       --12609107
         ,fun_seq_versions                  fsv1
         ,fun_seq_versions                  fsv2
--         ,fnd_sequences                     fsq -- krsankar - Commented as part of Bug 7153425
         ,fnd_document_sequences            fsq
         ,gl_encumbrance_types              get
         ,gl_je_categories_tl               gjct
     ,gl_je_sources_tl                  gjst  --bug12408239
         ,gl_je_batches                     gjb
         ,gl_code_combinations_kfv          gcck
         ,gl_daily_conversion_types         gdct ';

        -- Bug 5097723. Put an outer join while joining gl_je_headers and fnd_sequences.
        p_gl_where   :=
               'WHERE  glg.ledger_id               IN $ledger_id$
         --AND  glh.period_name    BETWEEN :P_PERIOD_FROM AND :P_PERIOD_TO
         and  glp.period_name             = glh.period_name  -- Added perf 14050580
         and  glp.period_name             = gll.period_name  -- Added perf 14050580
         AND  glh.ledger_id               =  glg.ledger_id
         AND  gll.je_header_id            =  glh.je_header_id
         AND  gll.effective_date BETWEEN :P_GL_DATE_FROM AND :P_GL_DATE_TO
         AND  xlk.lookup_type             =  ''XLA_BALANCE_TYPE''
         AND  xlk.lookup_code             =  glh.actual_flag
         AND  fdu.user_id                 =  glh.created_by
         AND  glp.period_name             =  glh.period_name
         -- Begin 12609107
         AND  glp.effective_period_num BETWEEN '
            || g_start_period_num
            || ' AND '
            || g_end_period_num
            || ' AND  glp.application_id     =  101
         AND  glp.ledger_id               =  glh.ledger_id
         AND  glp.ledger_id               =  glg.ledger_id
         -- End 12609107
         AND  fsv1.seq_version_id(+)      =  glh.posting_acct_seq_version_id
         AND  fsv2.seq_version_id(+)      =  glh.close_acct_seq_version_id
         AND  fsq.application_id(+)       =  101
--         AND  fsq.sequence_id(+)          =  glh.doc_sequence_id --krsankar - Commented as part of Bug 7153425
     AND  fsq.doc_sequence_id(+)          =  glh.doc_sequence_id
         AND  gbv.budget_version_id(+)    =  glh.budget_version_id
         AND  get.encumbrance_type_id(+)  =  glh.encumbrance_type_id
         AND  gjct.je_category_name       =  glh.je_category
         AND  gjct.LANGUAGE               =  USERENV(''LANG'')
         AND  gjst.je_source_name         =  glh.je_source     --bug12408239
         AND  gjst.LANGUAGE               =  USERENV(''LANG'') --bug12408239
         AND  gjb.je_batch_id             =  glh.je_batch_id
         AND  glk2.lookup_type            =  ''BATCH_STATUS''
         AND  glk2.lookup_code            =  glh.status
         AND  gcck.code_combination_id    =  gll.code_combination_id
         AND  gdct.conversion_type(+)     =  glh.currency_conversion_type
         AND  NVL(glh.je_from_sla_flag,''N'')   = ''N'' ';

        IF p_party_type_code IN ('C', 'S')
        THEN
            p_gl_party_details   := ' ,NULL                 PARTY_NUMBER
           ,NULL                 PARTY_NAME
           ,NULL                 PARTY_TYPE_TAXPAYER_ID
           ,NULL                 PARTY_TAX_REGISTRATION_NUMBER
           ,NULL                 PARTY_SITE_NUMBER
           ,NULL                 PARTY_SITE_NAME
           ,NULL                 PARTY_SITE_TAX_RGSTN_NUMBER ';
        ELSE
            p_gl_party_details   := ',NULL  PARTY_INFO ';
        END IF;

        --
        -- Building Legal entity information: Bug 5659083
        --

        IF p_include_le_info_flag = 'NONE'
        THEN
            p_gl_legal_ent_col    := ' ';
            p_gl_legal_ent_from   := ' ';
            p_gl_legal_ent_join   := ' ';
        ELSE
            p_gl_legal_ent_col    := C_GL_TRX_LEGAL_ENT_COL;
            p_gl_legal_ent_from   := ' ';
            p_gl_legal_ent_join   := ' ';
        END IF;

        ----------------------------------------------------------------------------
        -- build filter condition based on parameters
        ----------------------------------------------------------------------------
        --
        -- <conditions based on creation date>
        --
        IF p_creation_date_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.creation_date >= '
                || ''''
                || p_creation_date_from
                || '''';
        END IF;

        IF p_creation_date_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.creation_date <= '
                || ''''
                || p_creation_date_to
                || '''';
        END IF;

        --
        -- <conditions based on posting status> Modified for bug 5555715
        --
        IF NVL (p_posting_status_code, 'A') = 'Y'
        THEN
            l_other_param_filter   :=
                l_other_param_filter || ' AND glh.status = ''P''';
        ELSIF NVL (p_posting_status_code, 'A') = 'N'
        THEN
            l_other_param_filter   :=
                l_other_param_filter || ' AND glh.status <> ''P''';
        ELSIF NVL (p_posting_status_code, 'A') IN ('T', 'A')
        THEN                                        -- added T for bug 8250215
            NULL;                                                 -- No filter
        END IF;

        --
        -- <conditions based on gl je source>
        --
        IF p_je_source IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.je_source = '''
                || p_je_source
                || '''';
        END IF;

        -- Bug 5653925
        -- <conditions based on accounting sequence name and number range>
        --
        IF p_acct_sequence_version IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.posting_acct_seq_version_id = '
                || p_acct_sequence_version;
        END IF;

        IF p_acct_sequence_num_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.posting_acct_seq_value >= '
                || p_acct_sequence_num_from;
        END IF;

        IF p_acct_sequence_num_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.posting_acct_seq_value <= '
                || p_acct_sequence_num_to;
        END IF;


        --
        -- <conditions based on reporting sequence name and number range>
        --
        IF p_rpt_sequence_version IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.close_acct_seq_version_id = '
                || p_rpt_sequence_version;
        END IF;

        IF p_rpt_sequence_num_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.close_acct_seq_value >= '
                || p_rpt_sequence_num_from;
        END IF;

        IF p_rpt_sequence_num_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.close_acct_seq_value <= '
                || p_rpt_sequence_num_to;
        END IF;

        -- <conditions based on period type>  Added for bug 7645837
        --
        IF p_period_type IS NOT NULL
        THEN
            IF p_period_type = 'A'
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND glp.adjustment_period_flag = ''Y'' ';
            ELSIF p_period_type = 'N'
            THEN
                l_other_param_filter   :=
                       l_other_param_filter
                    || ' AND glp.adjustment_period_flag = ''N'' ';
            END IF;
        END IF;

        --


        --
        -- <conditions based on gl je category> - Bug 5059634
        --
        IF p_je_category IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.je_category  = '''
                || p_je_category
                || '''';
        END IF;

        --
        -- <conditions based on balance type>
        --
        IF p_balance_type_code IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.actual_flag = '''
                || p_balance_type_code
                || '''';
        END IF;

        --
        -- <conditions based on budget_version_id>
        --
        IF p_budget_version_id IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.budget_version_id = '
                || p_budget_version_id;
        END IF;

        --
        -- <conditions based on encumbrance type>
        --
        IF p_encumbrance_type_id IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.encumbrance_type_id = '
                || p_encumbrance_type_id;
        END IF;

        --
        -- <conditions based on include zero amount flag>
        --
        IF p_include_zero_amount_flag = 'N'
        THEN
            --bug#6978940 changed > 0  to <> 0
            l_other_param_filter   :=
                l_other_param_filter || ' AND ( NVL(gll.accounted_cr,0) <> 0
                                       OR NVL(gll.accounted_dr,0) <> 0 ) ';
        END IF;

        --
        -- <conditions based on entered currency code> Modified for bug 5721755
        --
        IF p_entered_currency IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND glh.currency_code ='''
                || p_entered_currency
                || '''';
        ELSE
            l_other_param_filter   :=
                l_other_param_filter || ' AND glh.currency_code <> ''STAT''';
        END IF;

        --
        -- <conditions based on accounted amount range>
        --
        IF p_accounted_amount_from IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND (NVL(gll.accounted_cr,0) >= '
                || p_accounted_amount_from
                || ' OR NVL(gll.accounted_dr,0) >= '
                || p_accounted_amount_from
                || ') ';
        END IF;

        IF p_accounted_amount_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND (NVL(gll.accounted_cr,0) <= '
                || p_accounted_amount_to
                || ' OR NVL(gll.accounted_dr,0) <= '
                || p_accounted_amount_to
                || ') ';
        END IF;


        --
        -- <conditions based on side>
        --
        IF p_side_code = 'DEBIT'
        THEN
            l_other_param_filter   :=
                l_other_param_filter || ' AND ( NVL(gll.accounted_cr,0)
                                      - NVL(gll.accounted_dr,0) < 0) ';
        ELSIF p_side_code = 'CREDIT'
        THEN
            l_other_param_filter   :=
                l_other_param_filter || ' AND ( NVL(gll.accounted_cr,0)
                                      - NVL(gll.accounted_dr,0) > 0) ';
        END IF;


        IF     p_account_flexfield_from IS NOT NULL
           AND p_account_flexfield_to IS NOT NULL
        THEN
            l_other_param_filter   :=
                l_other_param_filter || ' AND ' || g_flex_range_where; --bug 12586551
        END IF;

        --
        -- condition based on gl_batch_name. Bug 4725878.
        --
        IF p_gl_batch_name IS NOT NULL
        THEN
            l_other_param_filter   :=
                   l_other_param_filter
                || ' AND gjb.name = '''
                || p_gl_batch_name
                || '''';
        END IF;

        p_gl_where   := p_gl_where || l_other_param_filter;

        IF (C_LEVEL_PROCEDURE >= g_log_level)
        THEN
            trace (p_msg      => 'END of get_gl_sql',
                   p_level    => C_LEVEL_PROCEDURE,
                   p_module   => l_log_module);
        END IF;
    EXCEPTION
        WHEN xla_exceptions_pkg.application_exception
        THEN
            RAISE;
        WHEN OTHERS
        THEN
            xla_exceptions_pkg.raise_message (
                p_location => 'xla_jelines_rpt_pkg.get_gl_sql');
    END get_gl_query;

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
        l_object_type                  VARCHAR2 (30);
        l_select_str                   VARCHAR2 (4000);
        l_from_str                     VARCHAR2 (240);
        l_where_str                    VARCHAR2 (4000);
        l_count                        NUMBER;
        l_ledger_id                    NUMBER;
        l_coa_id                       NUMBER;
        l_balancing_segment            VARCHAR2 (80);
        l_account_segment              VARCHAR2 (80);
        l_costcenter_segment           VARCHAR2 (80);
        l_management_segment           VARCHAR2 (80);
        l_intercompany_segment         VARCHAR2 (80);
        l_alias_balancing_segment      VARCHAR2 (80);
        l_alias_account_segment        VARCHAR2 (80);
        l_alias_costcenter_segment     VARCHAR2 (80);
        l_alias_management_segment     VARCHAR2 (80);
        l_alias_intercompany_segment   VARCHAR2 (80);
        l_qualifier_segment            VARCHAR2 (4000) := ' ';
        l_seg_desc_column              VARCHAR2 (2000) := ' ';
        l_seg_desc_from                VARCHAR2 (1000) := ' ';
        l_seg_desc_join                VARCHAR2 (1000) := ' ';
        l_log_module                   VARCHAR2 (240);
        --l_flex_range_where              VARCHAR2(32000); bug 12586551
        l_gl_columns                   VARCHAR2 (2000);
        l_gl_view                      VARCHAR2 (4000);
        l_gl_join                      VARCHAR2 (2000);
        l_fetch_from_sla_flag          VARCHAR2 (1);
        l_fetch_from_gl_flag           VARCHAR2 (1);
        l_user_trx_value               VARCHAR2 (2000) := ' ';
        l_period_year                  NUMBER;
        l_temp                         NUMBER;
        l_fnd_flex_hint                VARCHAR2 (200);
        i                              NUMBER;

        l_ledgers                      VARCHAR2 (1000);
        --bug#7834671
        l_display_flag                 fnd_id_flex_segments.display_flag%TYPE;

        CURSOR C_SEG_DISP_REQ_CHECK (p_application_id INTEGER, p_id_flex_code VARCHAR2, p_id_flex_num INTEGER
                                     , p_segment_code VARCHAR2)
        IS
            SELECT display_flag
              FROM fnd_id_flex_segments fid
             WHERE     application_id = p_application_id
                   AND id_flex_code = p_id_flex_code
                   AND id_flex_num = p_id_flex_num
                   AND application_column_name = p_segment_code;
    --bug#7834671



    BEGIN
        --
        -- default values
        --
        p_include_zero_amount_flag   := NVL (p_include_zero_amount_flag, 'N');
        p_include_user_trx_id_flag   := NVL (p_include_user_trx_id_flag, 'N');
        p_include_tax_details_flag   := NVL (p_include_tax_details_flag, 'N');
        p_include_le_info_flag       := NVL (p_include_le_info_flag, 'NONE');
        p_ytd_carriedfwd_flag        := NVL (p_ytd_carriedfwd_flag, 'N');

        --Added for bug 7159772

        IF p_order_by IS NOT NULL
        THEN
            p_order_by_clause   := ' order by ' || p_order_by;
        END IF;

        --Added for bug 7159772

        IF p_je_source = '#ALL#'
        THEN
            p_je_source   := NULL;
        END IF;

        BEGIN
            SELECT application_id
              INTO g_je_source_application_id
              FROM xla_subledgers
             WHERE je_source_name = p_je_source;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                g_je_source_application_id   := NULL;
        END;

        --
        -- following will set the right transaction security
        --
        -- if g_je_source_application_id is NULL
        --   set security context for 602
        -- else g_je_source_application_id is an SLA subledger
        --   set security context for the g_je_source_application_id
        -- end if

        IF g_je_source_application_id IS NULL
        THEN
            xla_security_pkg.set_security_context (602);
        ELSE
            xla_security_pkg.set_security_context (
                g_je_source_application_id);
        END IF;

        --
        -- Logic to restrict SLA or GL query to get executed unnecessarly
        --
        -- if g_je_source_application_id is NULL
        --   if je source is NULL
        --     fetch from SLA and GL for all applciations and je_sources
        --   else je source is not NULL
        --     fetch from GL for that je_source
        --   end if
        -- else g_je_source_application_id is an SLA subledger
        --   fetch from SLA and GL (Non-upgraded entries) for that application
        -- end if

        l_fetch_from_sla_flag        := 'N';
        l_fetch_from_gl_flag         := 'N';

        IF g_je_source_application_id IS NULL
        THEN
            IF p_je_source IS NULL
            THEN
                l_fetch_from_sla_flag   := 'Y';
                l_fetch_from_gl_flag    := 'Y';
            ELSE
                l_fetch_from_sla_flag   := 'N';
                l_fetch_from_gl_flag    := 'Y';
            END IF;
        ELSE
            l_fetch_from_sla_flag   := 'Y';
            l_fetch_from_gl_flag    := 'Y';
        END IF;

        IF ((NVL (p_je_status_code, 'F') <> 'F') OR (NVL (p_posting_status_code, 'A') = 'X')) -- added X for bug 8250215
        THEN
            l_fetch_from_gl_flag   := 'N';
        END IF;

        IF (C_LEVEL_STATEMENT >= g_log_level)
        THEN
            trace ('l_fetch_from_sla_flag =' || l_fetch_from_sla_flag,
                   C_LEVEL_STATEMENT,
                   l_log_module);
        END IF;

        IF (C_LEVEL_STATEMENT >= g_log_level)
        THEN
            trace ('l_fetch_from_gl_flag =' || l_fetch_from_gl_flag,
                   C_LEVEL_STATEMENT,
                   l_log_module);
        END IF;

        --
        -- Identifying ledger as Ledger or Ledger Set
        --
        SELECT object_type_code
          INTO l_object_type
          FROM gl_ledgers
         WHERE ledger_id = p_ledger_id;

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

        -----------------------------------------------------------------------------------
        -- Calculating Period Year Start and End Date. Bug 4755531- Use application_id 101
        -- Getting effective period number for the from and to periods. Bug 12609107
        -----------------------------------------------------------------------------------
        SELECT period_year, effective_period_num
          INTO l_period_year, g_start_period_num
          FROM gl_period_statuses
         WHERE     application_id = 101
               AND set_of_books_id = l_ledger_id
               AND period_name = p_period_from;

        SELECT effective_period_num
          INTO g_end_period_num
          FROM gl_period_statuses
         WHERE     application_id = 101
               AND ledger_id = l_ledger_id
               AND period_name = p_period_to;

        SELECT TO_CHAR (MIN (start_date), 'YYYY-MM-DD'), TO_CHAR (MAX (end_date), 'YYYY-MM-DD')
          INTO g_period_year_start_date, g_period_year_end_date
          FROM gl_period_statuses
         WHERE     application_id = 101
               AND set_of_books_id = l_ledger_id
               AND period_year = l_period_year
               AND adjustment_period_flag = 'N';

        -----------------------------------------------------------------------------------
        -- Building the where clause based on the flex range. Bug 12586551.
        -----------------------------------------------------------------------------------
        IF     p_account_flexfield_from IS NOT NULL
           AND p_account_flexfield_to IS NOT NULL
        THEN
            g_flex_range_where   :=
                get_flex_range_where (
                    p_coa_id                => p_coa_id,
                    p_acct_flexfield_from   => p_account_flexfield_from,
                    p_acct_flexfield_to     => p_account_flexfield_to);
        END IF;

        -----------------------------------------------------------------------------
        -- Based on P_INCLUDE_TAX_DETAIL building query to fetch tax info
        -----------------------------------------------------------------------------
        IF p_include_tax_details_flag = 'Y'
        THEN
            p_tax_query   := C_TAX_QUERY;
        ELSE
            p_tax_query   := C_TAX_NULL_QUERY;
        END IF;

        --bug5702057
        IF p_legal_audit_flag = 'Y'
        THEN
            p_created_query    := C_CREATED_QUERY;
            p_posted_query     := C_POSTED_QUERY;
            p_approved_query   := C_APPROVED_QUERY;
        ELSE
            p_created_query    := C_CREATED_NULL_QUERY;
            p_posted_query     := C_POSTED_NULL_QUERY;
            p_approved_query   := C_APPROVED_NULL_QUERY;
        END IF;

        p_commercial_query           := C_COMMERCIAL_QUERY;
        p_vat_registration_query     := C_VAT_REGISTRATION_QUERY;


        ------------------------------------------------------------------------------
        -- Based on P_YTD_CARRIEDFWD_FLAG building query to fetch Year-to-Date Carried
        -- Forward Debit and Credit Amounts
        ------------------------------------------------------------------------------
        IF p_ytd_carriedfwd_flag = 'Y'
        THEN
            p_ytd_carriedfwd   := C_YTD_ACTUAL_CARRIEDFWD;

            IF     p_account_flexfield_from IS NOT NULL
               AND                                              --bug 12586551
                   p_account_flexfield_to IS NOT NULL
            THEN
                p_ytd_carriedfwd   :=
                    p_ytd_carriedfwd || ' AND ' || g_flex_range_where;
            END IF;
        ELSE
            p_ytd_carriedfwd   := C_YTD_ZERO_CARRIEDFWD;
        END IF;

        ------------------------------------------------------------------------------
        -- Bug 8683445 Based on p_custom_query_flag building Report/Application
        -- specific Custom Query
        ------------------------------------------------------------------------------
        IF p_custom_query_flag IS NOT NULL
        THEN
            xla_rpt_util_qry_pkg.get_custom_query (
                p_application_id        => g_je_source_application_id,
                p_custom_query_flag     => p_custom_query_flag,
                p_custom_header_query   => p_custom_header_query,
                p_custom_line_query     => p_custom_line_query);
        END IF;

        IF p_custom_header_query IS NULL
        THEN
            p_custom_header_query   := 'SELECT NULL FROM DUAL WHERE 1=2';
        END IF;

        IF p_custom_line_query IS NULL
        THEN
            p_custom_line_query   := 'SELECT NULL FROM DUAL WHERE 1=2';
        END IF;

        --
        -- Qualified segments
        --
        l_qualifier_segment          := C_QUALIFIED_SEGMENT;
        l_coa_id                     := p_coa_id;

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
        l_qualifier_segment          :=
            REPLACE (l_qualifier_segment,
                     '$alias_balancing_segment$',
                     l_alias_balancing_segment);

        l_qualifier_segment          :=
            REPLACE (l_qualifier_segment,
                     '$alias_account_segment$',
                     l_alias_account_segment);

        l_qualifier_segment          :=
            REPLACE (l_qualifier_segment,
                     '$alias_costcenter_segment$',
                     l_alias_costcenter_segment);

        l_qualifier_segment          :=
            REPLACE (l_qualifier_segment,
                     '$alias_management_segment$',
                     l_alias_management_segment);

        l_qualifier_segment          :=
            REPLACE (l_qualifier_segment,
                     '$alias_intercompany_segment$',
                     l_alias_intercompany_segment);


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
        END IF;

        --
        -- REPLACE placeholders for the qualified segemnts
        --
        l_qualifier_segment          :=
            REPLACE (l_qualifier_segment,
                     '$seg_desc_column$',
                     l_seg_desc_column);

        --
        -- Legal Entity Information
        --

        --
        -- REPLACE placeholders for Legal entity information
        --
        IF p_include_le_info_flag = 'LEGAL_ENTITY'
        THEN
            p_le_col    := C_LEGAL_ENT_COL;
            p_le_from   := C_LEGAL_ENT_FROM;
            p_le_join   := C_LEGAL_ENT_JOIN;

            p_le_join   :=
                REPLACE (p_le_join, '$leg_seg_val$', l_balancing_segment);

            IF p_legal_entity_id IS NOT NULL
            THEN
                p_le_join   :=
                       p_le_join
                    || ' AND gle.legal_entity_id(+) = :p_legal_entity_id ';
            END IF;
        ELSIF p_include_le_info_flag = 'ESTABLISHMENT'
        THEN
            p_le_col    := C_ESTBLISHMENT_COL;
            p_le_from   := C_ESTABLISHMENT_FROM;
            p_le_join   := C_ESTABLISHMENT_JOIN;

            p_le_join   :=
                REPLACE (p_le_join, '$leg_seg_val$', l_balancing_segment);

            IF p_legal_entity_id IS NOT NULL
            THEN
                p_le_join   :=
                       p_le_join
                    || ' AND glv.legal_entity_id = :p_legal_entity_id ';
            END IF;
        ELSE                           -- p_include_le_info_flag = 'NONE' THEN
            p_le_col    := C_LE_NULL_COL;
            p_le_from   := ' ';
            p_le_join   := ' ';

            IF p_legal_entity_id IS NOT NULL
            THEN
                p_le_from   := ' ,gl_ledger_le_bsv_specific_v gle ';
                p_le_join   :=
                       ' AND gle.ledger_id        = TABLE1.LEDGER_ID '
                    || ' AND gle.segment_value    = TABLE1.$leg_seg_val$ '
                    || ' AND gle.legal_entity_id(+) = :p_legal_entity_id ';

                p_le_join   :=
                    REPLACE (p_le_join, '$leg_seg_val$', l_balancing_segment);
            END IF;
        END IF;


        --===========================================================================
        --  Building filter for outer query based on user trx ids
        --===========================================================================
        IF p_transaction_view IS NOT NULL
        THEN
            FOR c1
                IN (  SELECT user_sequence, column_name
                        FROM xla_event_mappings_b
                       WHERE     application_id = g_je_source_application_id
                             AND event_class_code IN
                                     (SELECT event_class_code
                                        FROM xla_event_class_attrs
                                       WHERE     application_id =
                                                 g_je_source_application_id
                                             AND reporting_view_name =
                                                 p_transaction_view
                                             AND ROWNUM = 1)
                             AND column_name IN
                                     (p_user_trx_id_column_1, p_user_trx_id_column_2, p_user_trx_id_column_3,
                                      p_user_trx_id_column_4, p_user_trx_id_column_5)
                    ORDER BY user_sequence)
            LOOP
                CASE c1.column_name
                    WHEN p_user_trx_id_column_1
                    THEN
                        l_user_trx_value   := p_user_trx_id_value_1;
                    WHEN p_user_trx_id_column_2
                    THEN
                        l_user_trx_value   := p_user_trx_id_value_2;
                    WHEN p_user_trx_id_column_3
                    THEN
                        l_user_trx_value   := p_user_trx_id_value_3;
                    WHEN p_user_trx_id_column_4
                    THEN
                        l_user_trx_value   := p_user_trx_id_value_4;
                    WHEN p_user_trx_id_column_5
                    THEN
                        l_user_trx_value   := p_user_trx_id_value_5;
                END CASE;

                p_trx_id_filter   :=
                       p_trx_id_filter
                    || /* ' AND TABLE1.USER_TRX_IDENTIFIER_VALUE_'||c1.user_sequence||' = ' || ''' || l_user_trx_value || '''; */
                       ' AND substr(USERIDS,instr(USERIDS,''|'',1,5)+1,(instr(USERIDS,''|'',1,6)-1-instr(USERIDS,''|'',1,5)))'
                    || ' = '
                    || ''''
                    || l_user_trx_value
                    || '''';
            -- bug#6802751

            END LOOP;
        END IF;

        --===========================================================================
        --  Building party string for the outer query.
        --===========================================================================
        IF p_party_type_code IN ('C', 'S')
        THEN
            NULL;
        ELSE
            p_party_details_col   :=
                ',SUBSTR(PARTY_INFO,1,INSTR(PARTY_INFO,''|'',1,1)-1 )                  PARTY_NUMBER
          ,SUBSTR(PARTY_INFO,INSTR(PARTY_INFO,''|'',1,1)+1
                 ,(INSTR(PARTY_INFO,''|'',1,2)-1-INSTR(PARTY_INFO,''|'',1,1)))  PARTY_NAME
          ,SUBSTR(PARTY_INFO,INSTR(PARTY_INFO,''|'',1,2)+1
                 ,(INSTR(PARTY_INFO,''|'',1,3)-1-INSTR(PARTY_INFO,''|'',1,2)))  PARTY_TYPE_TAXPAYER_ID
          ,SUBSTR(PARTY_INFO,INSTR(PARTY_INFO,''|'',1,3)+1
                 ,(INSTR(PARTY_INFO,''|'',1,4)-1-INSTR(PARTY_INFO,''|'',1,3)))  PARTY_TAX_REGISTRATION_NUMBER
          ,SUBSTR(PARTY_INFO,INSTR(PARTY_INFO,''|'',1,4)+1
                 ,(INSTR(PARTY_INFO,''|'',1,5)-1-INSTR(PARTY_INFO,''|'',1,4)))  PARTY_SITE_NUMBER
          ,SUBSTR(PARTY_INFO,INSTR(PARTY_INFO,''|'',1,5)+1
                 ,(INSTR(PARTY_INFO,''|'',1,6)-1-INSTR(PARTY_INFO,''|'',1,5)))  PARTY_SITE_NAME
          ,SUBSTR(PARTY_INFO,INSTR(PARTY_INFO,''|'',1,6)+1
                 ,(LENGTH(PARTY_INFO)- INSTR(PARTY_INFO,''|'',1,6)))            PARTY_SITE_TAX_RGSTN_NUMBER ';
        END IF;


        p_main_col_start             :=
            ' /*+ opt_param(''_optimizer_cost_based_transformation'',''off'')  */
               TABLE1.GL_DATE                                   GL_DATE
              ,TABLE1.CREATED_BY                                CREATED_BY
              ,TABLE1.CREATION_DATE                             CREATION_DATE
              ,TABLE1.LAST_UPDATE_DATE                          LAST_UPDATE_DATE
              ,TABLE1.GL_TRANSFER_DATE                          GL_TRANSFER_DATE
              ,TABLE1.REFERENCE_DATE                            REFERENCE_DATE
              ,TABLE1.COMPLETED_DATE                            COMPLETED_DATE
              ,TABLE1.EXTERNAL_REFERENCE                        EXTERNAL_REFERENCE
        ,TABLE1.REFERENCE_1       REFERENCE_1
        ,TABLE1.REFERENCE_4       REFERENCE_4
              ,TABLE1.PERIOD_YEAR                               PERIOD_YEAR
              ,TABLE1.PERIOD_YEAR_START_DATE                    PERIOD_YEAR_START_DATE
              ,TABLE1.PERIOD_YEAR_END_DATE                       PERIOD_YEAR_END_DATE
              ,TABLE1.PERIOD_NUMBER                             PERIOD_NUMBER
              ,TABLE1.PERIOD_NAME                               PERIOD_NAME
              ,TABLE1.PERIOD_START_DATE                         PERIOD_START_DATE
              ,TABLE1.PERIOD_END_DATE                           PERIOD_END_DATE
              ,TABLE1.TRANSACTION_NUMBER                        TRANSACTION_NUMBER
              ,TABLE1.TRANSACTION_DATE                          TRANSACTION_DATE
              ,TABLE1.ACCOUNTING_SEQUENCE_NAME                  ACCOUNTING_SEQUENCE_NAME
              ,TABLE1.ACCOUNTING_SEQUENCE_VERSION               ACCOUNTING_SEQUENCE_VERSION
              ,TABLE1.ACCOUNTING_SEQUENCE_NUMBER                ACCOUNTING_SEQUENCE_NUMBER
              ,TABLE1.REPORTING_SEQUENCE_NAME                   REPORTING_SEQUENCE_NAME
              ,TABLE1.REPORTING_SEQUENCE_VERSION                REPORTING_SEQUENCE_VERSION
              ,TABLE1.REPORTING_SEQUENCE_NUMBER                 REPORTING_SEQUENCE_NUMBER
              ,TABLE1.DOCUMENT_CATEGORY                         DOCUMENT_CATEGORY
              ,TABLE1.DOCUMENT_SEQUENCE_NAME                    DOCUMENT_SEQUENCE_NAME
              ,TABLE1.DOCUMENT_SEQUENCE_NUMBER                  DOCUMENT_SEQUENCE_NUMBER
              ,TABLE1.APPLICATION_ID                            APPLICATION_ID
              ,TABLE1.APPLICATION_NAME                          APPLICATION_NAME
              ,TABLE1.LEDGER_ID                                 LEDGER_ID
              ,TABLE1.LEDGER_SHORT_NAME                         LEDGER_SHORT_NAME
              ,TABLE1.LEDGER_DESCRIPTION                        LEDGER_DESCRIPTION
              ,TABLE1.LEDGER_NAME                               LEDGER_NAME
              ,TABLE1.LEDGER_CURRENCY                           LEDGER_CURRENCY
              ,TABLE1.HEADER_ID                                 HEADER_ID
              ,TABLE1.HEADER_DESCRIPTION                        HEADER_DESCRIPTION
              ,TABLE1.JOURNAL_ENTRY_STATUS                      JOURNAL_ENTRY_STATUS
              ,TABLE1.TRANSFER_TO_GL_STATUS                     TRANSFER_TO_GL_STATUS
              ,TABLE1.BALANCE_TYPE_CODE                         BALANCE_TYPE_CODE
              ,TABLE1.BALANCE_TYPE                              BALANCE_TYPE
              ,TABLE1.BUDGET_NAME                               BUDGET_NAME
              ,TABLE1.ENCUMBRANCE_TYPE                          ENCUMBRANCE_TYPE
              ,TABLE1.FUND_STATUS                               FUND_STATUS
              ,TABLE1.JE_CATEGORY_NAME                          JE_CATEGORY_NAME
              ,TABLE1.JE_SOURCE_NAME                            JE_SOURCE_NAME
              ,TABLE1.GL_BATCH_NAME                             GL_BATCH_NAME
        ,TABLE1.GL_DEFAULT_EFFECTIVE_DATE     GL_DEFAULT_EFFECTIVE_DATE
              ,TABLE1.GL_BATCH_STATUS                           GL_BATCH_STATUS
              ,TABLE1.POSTED_DATE                               POSTED_DATE
              ,TABLE1.GL_JE_NAME                                GL_JE_NAME
              ,TABLE1.GL_DOC_SEQUENCE_NAME                      GL_DOC_SEQUENCE_NAME
              ,TABLE1.GL_DOC_SEQUENCE_VALUE                     GL_DOC_SEQUENCE_VALUE
              ,TABLE1.GL_LINE_NUMBER                            GL_LINE_NUMBER
              ,TABLE1.EVENT_ID                                  EVENT_ID
              ,TABLE1.EVENT_DATE                                EVENT_DATE
              ,TABLE1.EVENT_NUMBER                              EVENT_NUMBER
              ,TABLE1.EVENT_CLASS_CODE                          EVENT_CLASS_CODE
              ,TABLE1.EVENT_CLASS_NAME                          EVENT_CLASS_NAME
              ,TABLE1.EVENT_TYPE_CODE                           EVENT_TYPE_CODE
              ,TABLE1.EVENT_TYPE_NAME                           EVENT_TYPE_NAME
              ,TABLE1.LINE_NUMBER                               LINE_NUMBER
              ,TABLE1.ACCOUNTING_CLASS_CODE                     ACCOUNTING_CLASS_CODE
              ,TABLE1.ACCOUNTING_CLASS_NAME                     ACCOUNTING_CLASS_NAME
              ,TABLE1.LINE_DESCRIPTION                          LINE_DESCRIPTION
              ,TABLE1.CODE_COMBINATION_ID                       CODE_COMBINATION_ID
              ,TABLE1.ACCOUNTING_CODE_COMBINATION               ACCOUNTING_CODE_COMBINATION
              ,TABLE1.CODE_COMBINATION_DESCRIPTION              CODE_COMBINATION_DESCRIPTION
              ,TABLE1.CONTROL_ACCOUNT_FLAG                      CONTROL_ACCOUNT_FLAG
              ,TABLE1.ENTERED_CURRENCY                          ENTERED_CURRENCY
              ,TABLE1.CONVERSION_RATE                           CONVERSION_RATE
              ,TABLE1.CONVERSION_RATE_DATE                      CONVERSION_RATE_DATE
              ,TABLE1.CONVERSION_RATE_TYPE_CODE                 CONVERSION_RATE_TYPE_CODE
              ,TABLE1.CONVERSION_RATE_TYPE                      CONVERSION_RATE_TYPE
              ,TABLE1.ENTERED_DR                                ENTERED_DR
              ,TABLE1.ENTERED_CR                                ENTERED_CR
              ,TABLE1.UNROUNDED_ACCOUNTED_DR                    UNROUNDED_ACCOUNTED_DR
              ,TABLE1.UNROUNDED_ACCOUNTED_CR                    UNROUNDED_ACCOUNTED_CR
              ,TABLE1.ACCOUNTED_DR                              ACCOUNTED_DR
              ,TABLE1.ACCOUNTED_CR                              ACCOUNTED_CR
              ,TABLE1.STATISTICAL_AMOUNT                        STATISTICAL_AMOUNT
              ,TABLE1.RECONCILIATION_REFERENCE                  RECONCILIATION_REFERENCE
              ,TABLE1.ATTRIBUTE_CATEGORY                        ATTRIBUTE_CATEGORY
              ,TABLE1.ATTRIBUTE1                                ATTRIBUTE1
              ,TABLE1.ATTRIBUTE2                                ATTRIBUTE2
              ,TABLE1.ATTRIBUTE3                                ATTRIBUTE3
              ,TABLE1.ATTRIBUTE4                                ATTRIBUTE4
              ,TABLE1.ATTRIBUTE5                                ATTRIBUTE5
              ,TABLE1.ATTRIBUTE6                                ATTRIBUTE6
              ,TABLE1.ATTRIBUTE7                                ATTRIBUTE7
              ,TABLE1.ATTRIBUTE8                                ATTRIBUTE8
              ,TABLE1.ATTRIBUTE9                                ATTRIBUTE9
              ,TABLE1.ATTRIBUTE10                               ATTRIBUTE10
              ,TABLE1.PARTY_TYPE_CODE                           PARTY_TYPE_CODE
              ,TABLE1.PARTY_TYPE                                PARTY_TYPE';


        p_segment_col                :=
            ',TABLE1.BALANCING_SEGMENT                         BALANCING_SEGMENT
              ,TABLE1.NATURAL_ACCOUNT_SEGMENT                   NATURAL_ACCOUNT_SEGMENT
              ,TABLE1.COST_CENTER_SEGMENT                       COST_CENTER_SEGMENT
              ,TABLE1.MANAGEMENT_SEGMENT                        MANAGEMENT_SEGMENT
              ,TABLE1.INTERCOMPANY_SEGMENT                      INTERCOMPANY_SEGMENT
              ,TABLE1.BALANCING_SEGMENT_DESC                    BALANCING_SEGMENT_DESC
              ,TABLE1.NATURAL_ACCOUNT_DESC                      NATURAL_ACCOUNT_DESC
              ,TABLE1.COST_CENTER_DESC                          COST_CENTER_DESC
              ,TABLE1.MANAGEMENT_SEGMENT_DESC                   MANAGEMENT_SEGMENT_DESC
              ,TABLE1.INTERCOMPANY_SEGMENT_DESC                 INTERCOMPANY_SEGMENT_DESC
              ,TABLE1.SEGMENT1                                  SEGMENT1
              ,TABLE1.SEGMENT2                                  SEGMENT2
              ,TABLE1.SEGMENT3                                  SEGMENT3
              ,TABLE1.SEGMENT4                                  SEGMENT4
              ,TABLE1.SEGMENT5                                  SEGMENT5
              ,TABLE1.SEGMENT6                                  SEGMENT6
              ,TABLE1.SEGMENT7                                  SEGMENT7
              ,TABLE1.SEGMENT8                                  SEGMENT8
              ,TABLE1.SEGMENT9                                  SEGMENT9
              ,TABLE1.SEGMENT10                                 SEGMENT10
              ,TABLE1.SEGMENT11                                 SEGMENT11
              ,TABLE1.SEGMENT12                                 SEGMENT12
              ,TABLE1.SEGMENT13                                 SEGMENT13
              ,TABLE1.SEGMENT14                                 SEGMENT14
              ,TABLE1.SEGMENT15                                 SEGMENT15
              ,TABLE1.SEGMENT16                                 SEGMENT16
              ,TABLE1.SEGMENT17                                 SEGMENT17
              ,TABLE1.SEGMENT18                                 SEGMENT18
              ,TABLE1.SEGMENT19                                 SEGMENT19
              ,TABLE1.SEGMENT20                                 SEGMENT20
              ,TABLE1.SEGMENT21                                 SEGMENT21
              ,TABLE1.SEGMENT22                                 SEGMENT22
              ,TABLE1.SEGMENT23                                 SEGMENT23
              ,TABLE1.SEGMENT24                                 SEGMENT24
              ,TABLE1.SEGMENT25                                 SEGMENT25
              ,TABLE1.SEGMENT26                                 SEGMENT26
              ,TABLE1.SEGMENT27                                 SEGMENT27
              ,TABLE1.SEGMENT28                                 SEGMENT28
              ,TABLE1.SEGMENT29                                 SEGMENT29
              ,TABLE1.SEGMENT30                                 SEGMENT30';

        p_uti_col                    :=
            ',substr(USERIDS,1,instr(USERIDS,''|'',1,1)-1)                                                    USER_TRX_IDENTIFIER_NAME_1
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
              ,substr(USERIDS,instr(USERIDS,''|'',1,19)+1,(length(USERIDS)-instr(USERIDS,''|'',1,19)))           USER_TRX_IDENTIFIER_VALUE_10';


        -- Added LEGAL_CREATED_ID and LEGAL_POSTED_ID values for bug 16241762
        P_MAIN_COL_END               :=
            ',TABLE1.ORIG_LINE_NUMBER                          ORIG_LINE_NUMBER
                   ,TABLE1.LEGAL_CREATED_ID                          LEGAL_CREATED_ID
                   ,TABLE1.LEGAL_POSTED_ID                           LEGAL_POSTED_ID';


        --===========================================================================
        --  Building SLA query
        --===========================================================================
        IF l_fetch_from_sla_flag = 'Y'
        THEN
            get_sla_query;

            p_sla_join                := REPLACE (p_sla_join, '$ledger_id$', l_ledgers);

            p_sla_qualifier_segment   := l_qualifier_segment;
            p_sla_seg_desc_from       := l_seg_desc_from;
            p_sla_seg_desc_join       := l_seg_desc_join;


            --
            -- <conditions based on balancing segment range>
            --
            IF (p_balancing_segment_from IS NOT NULL AND p_balancing_segment_to IS NOT NULL)
            THEN
                p_other_param_filter   :=
                       p_other_param_filter
                    || ' AND '
                    || l_balancing_segment
                    || ' BETWEEN '
                    || p_balancing_segment_from
                    || ' AND '
                    || p_balancing_segment_to;
            END IF;

            --
            -- <conditions based on accounting segment range>
            --
            IF (p_account_segment_from IS NOT NULL AND p_account_segment_to IS NOT NULL)
            THEN
                p_other_param_filter   :=
                       p_other_param_filter
                    || ' AND '
                    || l_account_segment
                    || ' BETWEEN '
                    || p_account_segment_from
                    || ' AND '
                    || p_account_segment_to;
            END IF;
        END IF;

        --===========================================================================
        -- Building GL query
        --===========================================================================
        IF l_fetch_from_gl_flag = 'Y'
        THEN
            IF NVL (p_fetch_from_gl, 'Y') IN ('Y', 'Yes')
            THEN                                      -- Added for bug 7007065
                /* Begin Performance fix  bug14050580 */


                IF (p_balancing_segment_from IS NULL AND p_balancing_segment_to IS NULL AND p_account_segment_from IS NULL AND p_account_segment_to IS NULL AND p_account_flexfield_from IS NULL AND p_account_flexfield_to IS NULL)
                THEN
                    get_gl_query ('N');
                ELSE
                    get_gl_query ('Y');
                END IF;

                /* End Performance fix  bug14050580 */

                p_gl_where               :=
                    REPLACE (p_gl_where, '$ledger_id$', l_ledgers);

                p_gl_qualifier_segment   := l_qualifier_segment;
                p_gl_seg_desc_from       := l_seg_desc_from;
                p_gl_seg_desc_join       := l_seg_desc_join;


                IF l_fetch_from_sla_flag = 'Y'
                THEN
                    p_union_all   := 'UNION ALL ';
                END IF;
            END IF;                                   -- Added for bug 7007065
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            xla_exceptions_pkg.raise_message (
                p_location => 'xla_jelines_rpt_pkg.beforeReport ');
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
END xxd_xla_jelines_rpt_pkg;
/
