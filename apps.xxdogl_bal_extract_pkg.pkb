--
-- XXDOGL_BAL_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOGL_BAL_EXTRACT_PKG"
IS
    /******************************************************************************
       NAME: XXDOGL_BAL_EXTRACT_PKG
       REP NAME:GL Balance Extract for Hyperion - Deckers
       This data Extract for HYPERION budgeting tool.

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       07/25/2011     Shibu        1. Created this package for GL XXDOGL003 Report
       2.0       01/08/2014     Sarita        Remove hardcoding of Calendar and comment the lines  101, 102, 133, 134
       3.0       01/13/2015      BT Team      Retrofit for BT cahnges
    ******************************************************************************/


    PROCEDURE POPULATE_DATA_FILE (p_errbuf           OUT VARCHAR2,
                                  p_retcode          OUT VARCHAR2,
                                  P_PERIOD_NAME   IN     VARCHAR2,
                                  P_FINAL         IN     VARCHAR2,
                                  P_OUTPUT_LOC    IN     VARCHAR2)
    IS
        CURSOR c_main (P_PERIOD_NAME IN VARCHAR2)
        IS
              -- *******************************************************************************************************************
              -- *******************************************************************************************************************
              -- *******************************************************************************************************************
              -- **
              -- ** Starting point: SQL code from 7/6/15 version of XXDOGL_BAL_EXTRACT_PKG.pkb
              -- **
              -- ** RMW 7/21/15
              -- ** Baseline version, No logic changes:
              -- **    - Replaced variable P_PERIOD_NAME with literal 'MAY-16'.  Restore variable before updating package
              -- **     - Added expanded comments section ahead of each block
              -- **
              -- ** Version 1
              -- **     - Commented out: AND ffv.ATTRIBUTE7 <> 'USD' in blocks 7 & 9.  This cleared all remaining variances to
              -- **       "expected" ConstantUSD values
              -- **
              -- **     - Removed block 9.  It was redundant to block 7.  Only difference was test for LC entry.  Removed that test
              -- **       in block 7 by commenting out: AND gdr.from_currency <> NVL (ffv.attribute7, 'USD').  All ConstantUSD
              -- **       values still as expected.  No variances
              -- **
              -- ** Version 2
              -- **     - Add special handling for FX accounts 68509 and 68510.  Both can have BEQ values not present as entered
              -- **       values in period_net_cr and period_net_dr fields (entered values).  For these accounts always start
              -- **       with period_net value (not BEQ) for ledger currency balance.  Take as is for USD ledgers or convert at
              -- **       ledger currency plan rate for non_USD ledger
              -- **
              -- **       1) Add exclusion for 68509, 68510 to Constant USD blocks: 7, 7a, 7b, 7c, 11
              -- **         Note: No changes to block 14 (Co 980 and 990).  Neither Co has activity for these accounts
              -- **
              -- **       2) Add blocks 9a and 9b to handle 68509 and 68510.  USD and Non-USD ledgers respectivity
              -- **
              -- ** RMW 7/30/15
              -- ** No logic changes:
              -- **    - Change period to JUN-16 to get benefit of more recent mapping.
              -- **    - Moved block 7 ahead of block 7a (formerly after block 7c)
              -- **
              -- ** Version 3       8/11/15 RMW
              -- **    - Removed following constraint from Block 18 as it was preventing any data from being fetched.
              -- **      This is the LocalCurrency (LC) block for Co 980/990 elims and the join to fnd_flex_values is on
              -- **      segment7 (I/C) instead of segment1.  The primary ledgers for these the companies represented by
              -- **      these I/C segments will never be 'Deckers Consol', but rather the primary ledgers for the given company.
              -- **
              -- **                          AND NVL (ffv.attribute6, 1) IN
              -- **                                 (SELECT gl.ledger_id
              -- **                                    FROM APPS.GL_LEDGER_SETS_V glsv,
              -- **                                         APPS.GL_LEDGER_SET_ASSIGNMENTS glsa,
              -- **                                         APPS.GL_LEDGERS gl
              -- **                                   WHERE     glsv.name = 'Deckers Consol'
              -- **                                         AND glsv.ledger_id =
              -- **                                                glsa.ledger_set_id
              -- **                                         AND glsa.ledger_id = gl.ledger_id
              -- **                                         AND glsa.ledger_set_id <>
              -- **                                                glsa.ledger_id) --Added by BT Team on 13/01/2015
              -- **
              -- **      After this constraint was removed, block 18 returned data as expected for companies with non-USD LC.
              -- **
              -- **
              -- ** Version 4       8/21/15 RMW
              -- **
              -- **   Version 4 modifications were all for ConstantLocal.
              -- **
              -- **   -  Existing blocks were modified as follows to support special handling needed for accounts 68509 & 68510
              -- **       Block 8:  Added condition AND gcc.segment6 NOT IN ('68509', '68510')
              -- **       Block 10:  Added condition AND gcc.segment6 NOT IN ('68509', '68510')
              -- **       Block 12:  Added condition AND gcc.segment6 NOT IN ('68509', '68510')
              -- **
              -- **
              -- **   - Following blocks were added:
              -- **       Block 8a: Non-USD ledger, Non-ledger currency
              -- **       Block 8b: Non-USD ledger, ledger currency
              -- **       Block 9c: Special handling for account 68509 & 68510.  Non-USD ledger, ledger currency
              -- **       Block 9d: Special handling for account 68509 & 68510.  USD ledger, LC = USD
              -- **       Block 9e: Special handling for account 68509 & 68510.  USD ledger, LC <> USD
              -- **       Block 10b: USD ledger, LC, USD balance
              -- **
              -- **   - Block 10a was deleted.
              -- **       It pulled from USD reporting ledgers which was at odds with the final design for
              -- **       ConstantLocal and was most likely a carryover from USD_Rpt blocks
              -- **
              -- **   - Updates   8/25/15
              -- **       Block 8a, 8b: "AND gcc.segment1 NOT IN ('990', '980')" added to where clause. (Only really needed for 8b)
              -- **       Block 8: "AND gdr.to_currency = 'USD'" - changed to "AND gdr.to_currency = ffv.attribute7" to include
              -- **                 non-USD LC companies
              -- **                "AND ffv.attribute7 <> 'USD'" - removed to include USD LC companies
              -- **
              -- **   - Updates   8/26/15
              -- **      * Added to WHERE clause for all blocks that use BEQ amounts (Blocks 6,7b,8b,10b,11,12):
              -- **
              -- **                                OR   NVL (gb.period_net_dr_beq,0)
              -- **                                   - NVL (gb.period_net_cr_beq, 0) <> 0
              -- **
              -- **      Prior to this, no check for BEQ activity was included.  This created an issue for Jun-FY16 data for account
              -- **      500.9400.501.410.1000.51112.500.  A EUR balance was zeroed out in USD (ledger currency), so the amount was
              -- **      written to the BEQ amount fields.  Since Period_Net_Amount was then 0 it was excluded from the data fetched.
              -- **
              -- **      * Removed the following constraint from Block 17 WHERE clasue:
              -- **
              -- **                          AND NVL (ffv.attribute6, 1) IN
              -- **                                 (SELECT gl.ledger_id
              -- **                                    FROM APPS.GL_LEDGER_SETS_V glsv,
              -- **                                         APPS.GL_LEDGER_SET_ASSIGNMENTS glsa,
              -- **                                         APPS.GL_LEDGERS gl
              -- **                                   WHERE     glsv.name = 'Deckers Consol'
              -- **                                         AND glsv.ledger_id =
              -- **                                                glsa.ledger_set_id
              -- **                                         AND glsa.ledger_id = gl.ledger_id
              -- **                                         AND glsa.ledger_set_id <>
              -- **                                                glsa.ledger_id) --Added by BT Team on 13/01/2015
              -- **                          AND ffv.FLEX_VALUE = gcc.segment7
              -- **                          AND gcc.summary_flag = 'N'
              -- **
              -- **       This block handles ConstantLocal for companies 980/990 and is there joined to flex values on segment7
              -- **       Contraint on attribute 6 will therefore block all records as companies in segment 7 won't have 'Deckers
              -- **       Consol' as primary ledger
              -- **
              -- *******************************************************************************************************************
              -- *******************************************************************************************************************
              -- *******************************************************************************************************************


              SELECT ledger_id, code_combination_id, segment1,
                     segment2, segment3, segment4,
                     -- Start modificaton by BT Technology Team on 2/24
                     segment5, segment6, segment7,
                     segment8, -- End modificaton by BT Technology Team on 2/24
                               period_name, period_year,
                     period_num, currency_code, SUM (prior_per_ytd_bal) prior_per_ytd_ba,
                     SUM (net_amount) net_amount, SUM (end_ytd_amount) end_ytd_amount
                -- **************************************************************************************************
                -- Code Block 1: USD_Rpt
                --
                --    USD ledger
                --    USD balance
                --    Get period_net as is
                --
                -- Ledger: 2036 Deckers US Primary
                -- **************************************************************************************************
                FROM (SELECT b.ledger_id, b.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           b.period_name, b.period_year,
                             b.period_num, 'USD_Rpt' currency_code, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) prior_per_ytd_bal,
                             NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) net_amount, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) end_ytd_amount
                        FROM apps.gl_balances b, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       WHERE     b.code_combination_id =
                                 gcc.code_combination_id
                             AND actual_flag = 'A'
                             AND (NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0 OR NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0)
                             AND b.period_name = P_PERIOD_NAME
                             AND b.currency_code = 'USD'
                             AND b.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gcc.summary_flag = 'N' -- Exclude summary accounts
                             --  AND ffv.flex_value_set_id = 1003630 --Deckers company           --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM apps.fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 NOT IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             AND b.ledger_id = NVL (ffv.attribute6, 1) --commented by BT Team on 13/01/2015
                      UNION
                      --********************************************************************************************************
                      -- Code Block 1a: USD_Rpt
                      --
                      --    Reporting ledger
                      --    USD balance
                      --    Get period_net amount as is
                      --
                      --    Copy of Code Block 1 to support even if there is multiple reporting ledger 03/08/2015
                      --********************************************************************************************************
                      SELECT b.ledger_id,                   /* Code Block 1 */
                                          b.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           b.period_name, b.period_year,
                             b.period_num, 'USD_Rpt' currency_code, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) prior_per_ytd_bal,
                             NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) net_amount, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) end_ytd_amount
                        FROM apps.gl_balances b, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv,
                             apps.gl_ledgers pgl, apps.gl_ledgers rgl --                        apps.fnd_lookup_values flv -- To be cleaned up
                                                                     , apps.gl_ledger_relationships glr
                       WHERE     b.code_combination_id =
                                 gcc.code_combination_id
                             AND actual_flag = 'A'
                             AND (NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0 OR NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0)
                             AND b.period_name = P_PERIOD_NAME
                             AND b.currency_code = 'USD'
                             --                        AND gcc.segment1 = flv.lookup_code --Added by BT Team on 13/01/2015 -- To be cleaned up
                             AND b.ledger_id = rgl.ledger_id
                             AND gcc.summary_flag = 'N' -- Exclude summary accounts
                             --  AND ffv.flex_value_set_id = 1003630 --Deckers company           --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM apps.fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 NOT IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             AND pgl.ledger_id = NVL (ffv.attribute6, 1) --commented by BT Team on 13/01/2015
                             AND pgl.configuration_id = rgl.configuration_id(+)
                             AND rgl.ledger_category_code(+) = 'ALC'
                             AND rgl.alc_ledger_type_code(+) = 'TARGET'
                             AND rgl.ledger_id = glr.target_ledger_id
                             AND glr.source_ledger_id = pgl.ledger_id
                             AND glr.relationship_type_code = 'JOURNAL'
                             AND glr.relationship_enabled_flag = 'Y'
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 2: LocalCurrency
                      --
                      --    Non-USD legdger
                      --    Local currency balance / Non-USD balance
                      --    Get period_net amount as is
                      --
                      --   Local Currency info is currently only for R and E accounts
                      -- ********************************************************************************************************
                      SELECT b1.ledger_id, b1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           b1.period_name, b1.period_year,
                             b1.period_num, 'LocalCurrency' currency_code, NVL (b1.begin_balance_dr, 0) - NVL (b1.begin_balance_cr, 0) prior_per_ytd_bal,
                             NVL (b1.period_net_dr, 0) - NVL (b1.period_net_cr, 0) net_amount, NVL (b1.begin_balance_dr, 0) - NVL (b1.begin_balance_cr, 0) + NVL (b1.period_net_dr, 0) - NVL (b1.period_net_cr, 0) end_ytd_amount
                        FROM apps.gl_balances b1, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       WHERE     b1.code_combination_id =
                                 gcc.code_combination_id
                             AND b1.actual_flag = 'A'
                             AND (NVL (b1.period_net_dr, 0) - NVL (b1.period_net_cr, 0) <> 0 OR NVL (b1.begin_balance_dr, 0) - NVL (b1.begin_balance_cr, 0) + NVL (b1.period_net_dr, 0) - NVL (b1.period_net_cr, 0) <> 0)
                             AND b1.period_name = P_PERIOD_NAME
                             AND b1.ledger_id = ffv.attribute6
                             AND ffv.attribute6 IS NOT NULL
                             --   AND b1.ledger_id <> 1        pick up primary ledger if there is a reporting ledger  */
                             --commented by BT Team on 13/01/2015
                             AND b1.ledger_id NOT IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND b1.currency_code = ffv.attribute7
                             AND b1.currency_code <> 'USD'
                             AND b1.currency_code <> 'USD'
                             --and gcc.account_type in ('R', 'E')
                             --and gcc.segment3 not in ('00000', '11230', '11236', '11611', '11612', '12001', '21112') -- wronly classified balance sheet accounts
                             AND gcc.summary_flag = 'N' -- Exclude summary accounts
                             -- AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 NOT IN ('990', '980')
                      -- End modificaton by BT Technology Team on 2/24


                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 3: LocalCurrency
                      --
                      --    USD ledger
                      --    USD balance
                      --    Local currency = USD
                      --   Get period_net amount as is
                      --
                      -- ********************************************************************************************************
                      SELECT b.ledger_id, b.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           b.period_name, b.period_year,
                             b.period_num, 'LocalCurrency' currency_code, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) prior_per_ytd_bal,
                             NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) net_amount, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) end_ytd_amount
                        FROM apps.gl_balances b, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       WHERE     b.code_combination_id =
                                 gcc.code_combination_id
                             AND actual_flag = 'A'
                             AND (NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0 OR NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0)
                             AND b.period_name = P_PERIOD_NAME
                             --   AND b.ledger_id = 1    primary ledger which does not have reporting ledger               --commented by BT Team on 13/01/2015
                             AND b.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND b.currency_code = 'USD'
                             --and gcc.account_type in ('R', 'E')
                             --and gcc.segment3 not in ('00000', '11230', '11236', '11611', '11612', '12001', '21112')
                             AND gcc.summary_flag = 'N' -- Exclude summary accounts
                             ----
                             AND gcc.segment1 = ffv.flex_value
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 NOT IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             -- AND ffv.flex_value_set_id = 1003630                                      --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.flex_value <> 'XX'
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND NVL (ffv.attribute7, 'USD') = 'USD'
                      --AND NVL (ffv.attribute6, 1) = 1


                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 4: LocalCurrency
                      --
                      --    USD ledger
                      --    Non-USD balance
                      --    Non-USD local currency
                      --    Get period_net amount * (rate based on account type)
                      --
                      -- entered in non functional  non Local  for non USD local currency Companies in Corporate Ledger
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'LocalCurrency' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 13-JAN-2014
                             AND gdr.conversion_type =
                                 (CASE
                                      WHEN gcc.account_type = 'R'
                                      THEN
                                          'Corporate'
                                      WHEN gcc.account_type = 'E'
                                      THEN
                                          'Corporate'
                                      WHEN gcc.account_type = 'A'
                                      THEN
                                          'Spot'
                                      WHEN gcc.account_type = 'L'
                                      THEN
                                          'Spot'
                                      WHEN gcc.account_type = 'O'
                                      THEN
                                          'Spot'
                                  END)       --Added by BT Team on 13-JAN-2014
                             AND gdr.from_currency <> 'USD'
                             AND gdr.to_currency <> 'USD'
                             AND gdr.from_currency <>
                                 NVL (ffv.attribute7, 'USD')
                             AND gdr.from_currency = gb1.currency_code
                             AND gdr.to_currency = ffv.attribute7
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 NOT IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 <> 'USD'
                             AND ffv.attribute7 IS NOT NULL
                             AND NVL (ffv.attribute6, 1) IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                        AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                      /* AND gcc.segment3 NOT IN    --  Remove this logic
                              ('00000',
                               '11230',
                               '11236',
                               '11611',
                               '11612',
                               '12001',
                               '21112')*/
                      --


                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 5: LocalCurrency
                      --
                      --    USD ledger
                      --    Local currency balance / Non-USD balance
                      --    Non-USD local currency
                      --    Get Period_net amount as is
                      --
                      --   Entered in Local Currency
                      -- ********************************************************************************************************
                      SELECT gb4.ledger_id, gb4.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb4.period_name, gb4.period_year,
                             gb4.period_num, 'LocalCurrency' currency_code, ROUND ((gb4.BEGIN_BALANCE_DR - gb4.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb4.PERIOD_NET_DR - gb4.PERIOD_NET_CR) * 1, 2) net_amount, ROUND ((gb4.BEGIN_BALANCE_DR - gb4.BEGIN_BALANCE_CR + gb4.PERIOD_NET_DR - gb4.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb4, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       --  WHERE     gb4.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb4.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb4.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb4.Period_name = P_PERIOD_NAME
                             AND gb4.actual_flag = 'A'
                             AND (NVL (gb4.period_net_dr, 0) - NVL (gb4.period_net_cr, 0) <> 0 OR NVL (gb4.begin_balance_dr, 0) - NVL (gb4.begin_balance_cr, 0) + NVL (gb4.period_net_dr, 0) - NVL (gb4.period_net_cr, 0) <> 0)
                             AND gb4.currency_code <> 'USD'
                             AND gb4.currency_code = ffv.ATTRIBUTE7
                             AND ffv.ATTRIBUTE7 IS NOT NULL
                             AND ffv.ATTRIBUTE7 <> 'USD'
                             AND NVL (ffv.ATTRIBUTE6, 1) = gb4.ledger_id
                             --AND ffv.flex_value_set_id = 1003630
                             --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND gcc.segment1 = ffv.FLEX_VALUE
                             AND gcc.account_type IN ('R', 'E')
                             AND gcc.summary_flag = 'N'
                      /* AND gcc.segment3 NOT IN    --  Remove this logic
                              ('00000',
                               '11230',
                               '11236',
                               '11611',
                               '11612',
                               '12001',
                               '21112')*/
                      --commented by BT Team on 13/01/2015
                      --


                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 6: LocalCurrency
                      --
                      --    USD ledger
                      --    USD balance
                      --    Non-USD local currency
                      --    Get period_net_BEQ amount * (rate based on account type)
                      --
                      -- Entered in CORPORATE IN USD BUT LOCAL CURRENCY IS NON USD
                      -- ********************************************************************************************************
                      SELECT gb.ledger_id, gb.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb.period_name, gb.period_year,
                             gb.period_num, 'LocalCurrency' currency_code, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ) * 0, 2) Begining_Local_Curr,
                             ROUND ((PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ + PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * 0, 2) Ending_Accounted_Curr
                        FROM apps.gl_balances gb, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll
                       --  WHERE     gb.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb.ledger_id = gll.ledger_id -- Added by Sarita
                             AND gb.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND ffv.attribute7 IS NOT NULL
                             -- Start modificaton by BT Technology Team on 2/24
                             --                                AND NVL (ffv.attribute6, 1) = 1
                             AND NVL (ffv.attribute6, 1) = gb.ledger_id
                             -- End modificaton by BT Technology Team on 2/24
                             AND gb.Period_name = P_PERIOD_NAME
                             AND gb.actual_flag = 'A'
                             AND gb.currency_code = 'USD'
                             AND (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.period_net_dr_beq, 0) - NVL (gb.period_net_cr_beq, 0) <> 0)
                             ---conversion
                             --   AND gdr.conversion_type = 'Corporate'                       --commented by BT Team on 13-JAN-2014
                             AND gdr.conversion_type =
                                 (CASE
                                      WHEN gcc.account_type = 'R'
                                      THEN
                                          'Corporate'
                                      WHEN gcc.account_type = 'E'
                                      THEN
                                          'Corporate'
                                      WHEN gcc.account_type = 'A'
                                      THEN
                                          'Spot'
                                      WHEN gcc.account_type = 'L'
                                      THEN
                                          'Spot'
                                      WHEN gcc.account_type = 'O'
                                      THEN
                                          'Spot'
                                  END)       --Added by BT Team on 13-JAN-2014
                             AND gdr.from_currency = gb.currency_code
                             AND gdr.to_currency = ffv.attribute7
                             AND ffv.attribute7 <> 'USD'
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb.Period_name
                             AND gp.period_set_name = gll.period_set_name -- 'Deckers Caldr' Added by Sarita
                             -- AND ffv.flex_value_set_id = 1003630                                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             --  AND gcc.account_type IN ('R', 'E')                  --commented by BT team on 13-JAN-2014
                             --                        AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N' /*  AND gcc.segment3 NOT IN
               ('00000',
                '11230',
                '11236',
                '11611',
                '11612',
                '12001',
                '21112')*/
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 7: ConstantUSD
                      --
                      --    USD ledger
                      --    Non-USD balance
                      --    Get period_net amount * plan rate
                      --
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantUSD' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gdr.conversion_type = '1000'
                             AND gdr.from_currency <> 'USD'
                             AND gdr.to_currency = 'USD'
                             AND gdr.from_currency = gb1.currency_code
                             -- Start modification on 15-Jun-15
                             --    AND gdr.to_currency = ffv.attribute7
                             -- End modification on 15-Jun-15
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             -- RMW commented out start 7/21/15
                             -- AND ffv.attribute7 <> 'USD'
                             -- AND gdr.from_currency <> NVL (ffv.attribute7, 'USD') -- 22-Feb May need to revisit the logic Confirm with Rahesh
                             -- RMW commented out end  7/21/15
                             AND ffv.attribute7 IS NOT NULL
                             AND NVL (ffv.attribute6, 1) IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                         AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 7a: ConstantUSD
                      --
                      --    Non-USD ledger
                      --    Non-USD balance
                      --    Non-ledger currency balance
                      --    Get period_net amount * plan rate
                      --
                      --    Copy of Code Block 7 for ConstantUSD
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantUSD' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id NOT IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.ledger_id = ffv.attribute6
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gdr.conversion_type = '1000'
                             AND gdr.from_currency <> 'USD'
                             AND gdr.to_currency = 'USD'
                             AND gdr.from_currency <>
                                 NVL (ffv.attribute7, 'USD') -- 22-Feb May need to revisit the logic Confirm with Rahesh
                             AND gll.currency_code <> gb1.currency_code
                             AND gdr.from_currency = gb1.currency_code
                             -- Start modification on 15-Jun-15
                             --    AND gdr.to_currency = ffv.attribute7
                             -- End modification on 15-Jun-15
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 <> 'USD'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                         AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 7b: ConstantUSD
                      --
                      --    Non-USD ledger
                      --    Ledger currency balance
                      --    Non-USD / Non-Local currency balance
                      --    Get period_net_BEQ * plan rate
                      --
                      --    Copy of Code Block 7 for ConstantUSD
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantUSD' currency_code, 0 prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR_BEQ - gb1.PERIOD_NET_CR_BEQ) * gdr.CONVERSION_RATE, 2) net_amount, 0 end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id NOT IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.ledger_id = ffv.attribute6
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.period_net_dr_beq, 0) - NVL (gb1.period_net_cr_beq, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gdr.conversion_type = '1000'
                             AND gdr.from_currency <> 'USD'
                             AND gdr.to_currency = 'USD'
                             --   AND gdr.from_currency = ffv.attribute7 -- 22-Feb May need to revisit the logic Confirm with Rahesh
                             AND gll.currency_code = gb1.currency_code
                             AND gdr.from_currency = gb1.currency_code
                             -- Start modification on 15-Jun-15
                             --    AND gdr.to_currency = ffv.attribute7
                             -- End modification on 15-Jun-15
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 <> 'USD'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                         AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 7c: ConstantUSD
                      --
                      --    Non-USD ledger
                      --    Non-ledger currency balance
                      --    USD balance
                      --    Get period_net amount as is
                      --
                      --    Non USD Ledger,entered currency USD
                      --    Copy of Code Block 7 for ConstantUSD
                      -- ********************************************************************************************************
                      SELECT gb.ledger_id, gb.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb.period_name, gb.period_year,
                             gb.period_num, 'ConstantUSD' currency_code, 0 Begining_Local_Curr,
                             ROUND ((PERIOD_NET_DR - PERIOD_NET_CR) * 1, 2) net_amount, 0 Ending_Accounted_Curr
                        FROM apps.gl_balances gb, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv,
                             apps.gl_ledgers gll
                       --  WHERE     gb.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb.ledger_id NOT IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb.ledger_id = gll.ledger_id -- Added by Sarita
                             AND gb.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND ffv.attribute7 IS NOT NULL
                             -- Start modificaton by BT Technology Team on 2/24
                             --                                AND NVL (ffv.attribute6, 1) = 1
                             AND ffv.attribute6 = gb.ledger_id
                             -- End modificaton by BT Technology Team on 2/24
                             AND gb.Period_name = P_PERIOD_NAME
                             AND gb.actual_flag = 'A'
                             AND gb.currency_code = 'USD'
                             AND gll.currency_code <> 'USD'
                             AND (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0)
                             -- Start modification on 15-Jun-15
                             --                          AND ffv.attribute7 <> 'USD'
                             -- End modification on 15-Jun-15
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             --  AND gcc.account_type IN ('R', 'E')                  --commented by BT team on 13-JAN-2014
                             --                        AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 8: ConstantLocal
                      --
                      --    USD ledger
                      --    Non-USD balance
                      --    Non-LC balance
                      --    Get period_net amount * plan rate
                      --
                      -- Copy of Code Block 4 for ConstantLocal
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantLocal' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gdr.conversion_type = '1000'
                             AND gdr.from_currency <> 'USD'
                             -- rw AND gdr.to_currency = 'USD'
                             AND gdr.to_currency = ffv.attribute7
                             AND gdr.from_currency <>
                                 NVL (ffv.attribute7, 'USD') -- 22-Feb May need to revisit the logic Confirm with Rahesh
                             -- Start modificaton by BT Technology Team on 2/24
                             --                          AND gdr.from_currency = gb1.currency_code
                             AND gdr.from_currency = gb1.currency_code
                             -- End modificaton by BT Technology Team on 2/24
                             AND gdr.to_currency = ffv.attribute7 -- 22-Feb May need to revisit Confirm with Rahesh
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 IS NOT NULL
                             AND NVL (ffv.attribute6, 1) IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                          AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 8a: ConstantLocal
                      --
                      --    Non-USD ledger
                      --    Non-LC, Non-Ledger currency balance
                      --    Get period_net amount * plan rate
                      --
                      --    Copy of Code Block 7a for ConstantUSD
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantLocal' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id NOT IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.ledger_id = ffv.attribute6
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gdr.conversion_type = '1000'
                             AND gdr.from_currency = gb1.currency_code
                             AND gdr.from_currency <> ffv.attribute7
                             AND gll.currency_code <> gb1.currency_code
                             AND gdr.to_currency = ffv.attribute7
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 <> 'USD'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                         AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                             AND gcc.segment1 NOT IN ('990', '980')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 8b: ConstantLocal
                      --
                      --    Non-USD ledger
                      --    Ledger currency balance
                      --    Get period_net_beq amount
                      --
                      --    Copy of Code Block 8a for ConstantLocal
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantLocal' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR_BEQ - gb1.PERIOD_NET_CR_BEQ), 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_PERIODS gp,
                             apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id NOT IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.ledger_id = ffv.attribute6
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.period_net_dr_beq, 0) - NVL (gb1.period_net_cr_beq, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gll.currency_code = gb1.currency_code
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                         AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                             AND gcc.segment1 NOT IN ('990', '980')
                      -- ********************************************************************************************************
                      -- Code Block 9: ConstantUSD
                      --
                      --    USD ledger
                      --    Non-USD, LC balance
                      --    Get Period_net amount * plan rate
                      --
                      -- Copy of Code Block 5
                      -- ********************************************************************************************************
                      --
                      --  RMW: This block was removed 7/21/15.  Redundant to Block 7
                      --


                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 9a: ConstantUSD
                      --
                      --    USD ledger
                      --    USD balance
                      --    GL accounts: 68509 & 68510
                      --    Get Period_net amount as is
                      --
                      -- Based on Code Block 11
                      -- ********************************************************************************************************
                      SELECT gb.ledger_id, gb.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb.period_name, gb.period_year,
                             gb.period_num, 'ConstantUSD' currency_code, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ) * 0, 2) Begining_Local_Curr,
                             ROUND ((PERIOD_NET_DR - PERIOD_NET_CR) * 1, 2) net_amount, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ + PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * 0, 2) Ending_Accounted_Curr
                        FROM apps.gl_balances gb, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv,
                             apps.gl_ledgers gll
                       --  WHERE     gb.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb.ledger_id = gll.ledger_id -- Added by Sarita
                             AND gb.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND ffv.attribute7 IS NOT NULL
                             -- Start modificaton by BT Technology Team on 2/24
                             --                                AND NVL (ffv.attribute6, 1) = 1
                             AND NVL (ffv.attribute6, 1) = gb.ledger_id
                             -- End modificaton by BT Technology Team on 2/24
                             AND gb.Period_name = P_PERIOD_NAME
                             AND gb.actual_flag = 'A'
                             AND gb.currency_code = 'USD'
                             AND (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0)
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             --  AND gcc.account_type IN ('R', 'E')                  --commented by BT team on 13-JAN-2014
                             --                        AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 9b: ConstantUSD
                      --
                      --    Non-USD ledger
                      --    Ledger currency
                      --    GL accounts: 68509 & 68510
                      --    Get Period_net amount * plan rate
                      --
                      -- Based on Code Block 7b
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantUSD' currency_code, 0 prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, 0 end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id NOT IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.ledger_id = ffv.attribute6
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gdr.conversion_type = '1000'
                             AND gdr.from_currency <> 'USD'
                             AND gdr.to_currency = 'USD'
                             --   AND gdr.from_currency = ffv.attribute7 -- 22-Feb May need to revisit the logic Confirm with Rahesh
                             AND gll.currency_code = gb1.currency_code
                             AND gdr.from_currency = gb1.currency_code
                             -- Start modification on 15-Jun-15
                             --    AND gdr.to_currency = ffv.attribute7
                             -- End modification on 15-Jun-15
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 <> 'USD'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                         AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 9c: ConstantLocal
                      --
                      --    Non-USD ledger
                      --    LC balance (same as ledger currency for non-USD ledgers)
                      --    GL accounts: 68509 & 68510
                      --    Get Period_net amount as is
                      --
                      -- Based on Code Block 9a
                      -- ********************************************************************************************************
                      SELECT gb.ledger_id, gb.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb.period_name, gb.period_year,
                             gb.period_num, 'ConstantLocal' currency_code, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ) * 0, 2) Begining_Local_Curr,
                             ROUND ((PERIOD_NET_DR - PERIOD_NET_CR) * 1, 2) net_amount, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ + PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * 0, 2) Ending_Accounted_Curr
                        FROM apps.gl_balances gb, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv,
                             apps.gl_ledgers gll
                       --  WHERE     gb.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb.ledger_id NOT IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb.ledger_id = gll.ledger_id -- Added by Sarita
                             AND gb.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND ffv.attribute7 IS NOT NULL
                             -- Start modificaton by BT Technology Team on 2/24
                             --                                AND NVL (ffv.attribute6, 1) = 1
                             AND NVL (ffv.attribute6, 1) = gb.ledger_id
                             -- End modificaton by BT Technology Team on 2/24
                             AND gb.Period_name = P_PERIOD_NAME
                             AND gb.actual_flag = 'A'
                             AND gb.currency_code = gll.currency_code
                             AND (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0)
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 9d: ConstantLocal
                      --
                      --    USD ledger
                      --    USD balance, LC = USD
                      --    GL accounts: 68509 & 68510
                      --    Get Period_net amount as is
                      --
                      -- Based on Code Block 9a
                      -- ********************************************************************************************************
                      SELECT gb.ledger_id, gb.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb.period_name, gb.period_year,
                             gb.period_num, 'ConstantLocal' currency_code, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ) * 0, 2) Begining_Local_Curr,
                             ROUND ((PERIOD_NET_DR - PERIOD_NET_CR) * 1, 2) net_amount, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ + PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * 0, 2) Ending_Accounted_Curr
                        FROM apps.gl_balances gb, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv,
                             apps.gl_ledgers gll
                       --  WHERE     gb.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb.ledger_id = gll.ledger_id -- Added by Sarita
                             AND gb.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND ffv.attribute7 IS NOT NULL
                             -- Start modificaton by BT Technology Team on 2/24
                             --                                AND NVL (ffv.attribute6, 1) = 1
                             AND NVL (ffv.attribute6, 1) = gb.ledger_id
                             -- End modificaton by BT Technology Team on 2/24
                             AND gb.Period_name = P_PERIOD_NAME
                             AND gb.actual_flag = 'A'
                             AND gb.currency_code = 'USD'
                             AND gb.currency_code = ffv.attribute7
                             AND (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0)
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             --  AND gcc.account_type IN ('R', 'E')                  --commented by BT team on 13-JAN-2014
                             --                        AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 9e: ConstantLocal
                      --
                      --    USD ledger
                      --    Ledger currency, LC <> USD
                      --    GL accounts: 68509 & 68510
                      --    Get Period_net amount * plan rate
                      --
                      -- Based on Code Block 9b
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantLocal' currency_code, 0 prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, 0 end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.ledger_id = ffv.attribute6
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gdr.conversion_type = '1000'
                             AND gdr.from_currency = 'USD'
                             AND gdr.to_currency = ffv.attribute7
                             --   AND gdr.from_currency = ffv.attribute7 -- 22-Feb May need to revisit the logic Confirm with Rahesh
                             AND gll.currency_code = gb1.currency_code
                             AND gdr.from_currency = gb1.currency_code
                             -- Start modification on 15-Jun-15
                             --    AND gdr.to_currency = ffv.attribute7
                             -- End modification on 15-Jun-15
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 <> 'USD'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                         AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 10: ConstantLocal
                      --
                      --    USD ledger
                      --    Non-USD, LC balance
                      --    LC: Non-USD
                      --    Get Period_net amount as is
                      --
                      -- Copy of Code Block 5
                      -- ********************************************************************************************************
                      SELECT gb4.ledger_id, gb4.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb4.period_name, gb4.period_year,
                             gb4.period_num, 'ConstantLocal' currency_code, ROUND ((gb4.BEGIN_BALANCE_DR - gb4.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb4.PERIOD_NET_DR - gb4.PERIOD_NET_CR) * 1, 2) net_amount, ROUND ((gb4.BEGIN_BALANCE_DR - gb4.BEGIN_BALANCE_CR + gb4.PERIOD_NET_DR - gb4.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb4, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       --  WHERE     gb4.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb4.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb4.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb4.Period_name = P_PERIOD_NAME
                             AND gb4.actual_flag = 'A'
                             AND (NVL (gb4.period_net_dr, 0) - NVL (gb4.period_net_cr, 0) <> 0 OR NVL (gb4.begin_balance_dr, 0) - NVL (gb4.begin_balance_cr, 0) + NVL (gb4.period_net_dr, 0) - NVL (gb4.period_net_cr, 0) <> 0)
                             AND gb4.currency_code <> 'USD'
                             AND gb4.currency_code = ffv.ATTRIBUTE7
                             AND ffv.ATTRIBUTE7 IS NOT NULL
                             AND ffv.ATTRIBUTE7 <> 'USD'
                             AND NVL (ffv.ATTRIBUTE6, 1) = gb4.ledger_id
                             --AND ffv.flex_value_set_id = 1003630
                             --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND gcc.segment1 = ffv.FLEX_VALUE
                             AND gcc.account_type IN ('R', 'E')
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      -- ********************************************************************************************************
                      -- *************************************   DELETED    *****************************************************
                      -- ********************************************************************************************************
                      -- Code Block 10a: ConstanLocal
                      --
                      --    Reporting ledger
                      --    Non-USD, LC balance
                      --    Get Period_net amount
                      --
                      --  RMW: This block was removed 8/21/15.  Did not need USD reporting ledger data in final design for CL
                      --
                      -- ********************************************************************************************************
                      -- *************************************   DELETED    *****************************************************
                      -- ********************************************************************************************************



                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 10b: ConstantLocal
                      --
                      --    USD ledger
                      --    Ledger currency balance
                      --    Get period_net_beq amount
                      --
                      --    Copy of Code Block 8b for ConstantLocal
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantLocal' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR_BEQ - gb1.PERIOD_NET_CR_BEQ), 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_PERIODS gp,
                             apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.ledger_id = ffv.attribute6
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.period_net_dr_beq, 0) - NVL (gb1.period_net_cr_beq, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 22-Feb
                             AND gll.currency_code = gb1.currency_code
                             AND gb1.currency_code = ffv.attribute7
                             AND gp.PERIOD_NAME = gb1.Period_name
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                         AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 11: ConstantUSD
                      --
                      --    USD ledger
                      --    USD balance
                      --    Get period_net_BEQ as is
                      --
                      --    Copy of Code Block 6
                      -- ********************************************************************************************************
                      SELECT gb.ledger_id, gb.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb.period_name, gb.period_year,
                             gb.period_num, 'ConstantUSD' currency_code, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ) * 0, 2) Begining_Local_Curr,
                             ROUND ((PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * 1, 2) net_amount, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ + PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * 0, 2) Ending_Accounted_Curr
                        FROM apps.gl_balances gb, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv,
                             apps.gl_ledgers gll
                       --  WHERE     gb.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb.ledger_id = gll.ledger_id -- Added by Sarita
                             AND gb.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND ffv.attribute7 IS NOT NULL
                             -- Start modificaton by BT Technology Team on 2/24
                             --                                AND NVL (ffv.attribute6, 1) = 1
                             AND NVL (ffv.attribute6, 1) = gb.ledger_id
                             -- End modificaton by BT Technology Team on 2/24
                             AND gb.Period_name = P_PERIOD_NAME
                             AND gb.actual_flag = 'A'
                             AND gb.currency_code = 'USD'
                             AND (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.period_net_dr_beq, 0) - NVL (gb.period_net_cr_beq, 0) <> 0)
                             -- Start modification on 15-Jun-15
                             --                          AND ffv.attribute7 <> 'USD'
                             -- End modification on 15-Jun-15
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             --  AND gcc.account_type IN ('R', 'E')                  --commented by BT team on 13-JAN-2014
                             --                        AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 12: ConstantLocal
                      --
                      --    USD ledger
                      --    USD, Non-LC balance
                      --    Get period_net_BEQ * plan rate
                      --
                      -- Copy of Code Block 6
                      -- ********************************************************************************************************
                      SELECT gb.ledger_id, gb.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb.period_name, gb.period_year,
                             gb.period_num, 'ConstantLocal' currency_code, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ) * 0, 2) Begining_Local_Curr,
                             ROUND ((PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ + PERIOD_NET_DR_BEQ - PERIOD_NET_CR_BEQ) * 0, 2) Ending_Accounted_Curr
                        FROM apps.gl_balances gb, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll
                       --  WHERE     gb.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name =
                                                 'Deckers Primary no Reporting'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb.ledger_id = gll.ledger_id -- Added by Sarita
                             AND gb.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND ffv.attribute7 IS NOT NULL
                             -- Start modificaton by BT Technology Team on 2/24
                             --                                AND NVL (ffv.attribute6, 1) = 1
                             AND NVL (ffv.attribute6, 1) = gb.ledger_id
                             -- End modificaton by BT Technology Team on 2/24
                             AND gb.Period_name = P_PERIOD_NAME
                             AND gb.actual_flag = 'A'
                             AND gb.currency_code = 'USD'
                             AND (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0) <> 0 OR NVL (gb.period_net_dr_beq, 0) - NVL (gb.period_net_cr_beq, 0) <> 0)
                             ---conversion
                             AND gdr.conversion_type = '1000' --commented by BT Team on 13-JAN-2014
                             AND gdr.from_currency = gb.currency_code
                             AND gdr.to_currency = ffv.attribute7
                             AND ffv.attribute7 <> 'USD'
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb.Period_name
                             AND gp.period_set_name = gll.period_set_name -- 'Deckers Caldr' Added by Sarita
                             -- AND ffv.flex_value_set_id = 1003630                                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             --  AND gcc.account_type IN ('R', 'E')                  --commented by BT team on 13-JAN-2014
                             --                        AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N'
                             AND gcc.segment6 NOT IN ('68509', '68510')
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 13: USD_Rpt                 Company 980 / 990 Logic
                      --
                      --    USD ledger ('Deckers Consol')
                      --    USD balance
                      --    Get period_net amount as is
                      --
                      --   Copy of Code Block 1
                      -- ********************************************************************************************************
                      SELECT b.ledger_id, b.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           b.period_name, b.period_year,
                             b.period_num, 'USD_Rpt' currency_code, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) prior_per_ytd_bal,
                             NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) net_amount, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) end_ytd_amount
                        FROM apps.gl_balances b, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       WHERE     b.code_combination_id =
                                 gcc.code_combination_id
                             AND actual_flag = 'A'
                             AND (NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0 OR NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0)
                             AND b.period_name = P_PERIOD_NAME
                             AND b.currency_code = 'USD'
                             AND b.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name = 'Deckers Consol'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gcc.summary_flag = 'N' -- Exclude summary accounts
                             --  AND ffv.flex_value_set_id = 1003630 --Deckers company           --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM apps.fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             AND b.ledger_id = NVL (ffv.attribute6, 1) --commented by BT Team on 13/01/2015
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 14: ConstantUSD                 Company 980 / 990 Logic
                      --
                      --    USD ledger ('Deckers Consol')
                      --    USD balance
                      --    Get period_net amount as is
                      --
                      --   Copy of Code Block 1
                      -- ********************************************************************************************************
                      SELECT b.ledger_id, b.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           b.period_name, b.period_year,
                             b.period_num, 'ConstantUSD' currency_code, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) prior_per_ytd_bal,
                             NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) net_amount, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) end_ytd_amount
                        FROM apps.gl_balances b, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       WHERE     b.code_combination_id =
                                 gcc.code_combination_id
                             AND actual_flag = 'A'
                             AND (NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0 OR NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0)
                             AND b.period_name = P_PERIOD_NAME
                             AND b.currency_code = 'USD'
                             AND b.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name = 'Deckers Consol'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gcc.summary_flag = 'N' -- Exclude summary accounts
                             --  AND ffv.flex_value_set_id = 1003630 --Deckers company           --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM apps.fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.FLEX_VALUE = gcc.segment1
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             AND b.ledger_id = NVL (ffv.attribute6, 1) --commented by BT Team on 13/01/2015
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 15: LocalCurrency                 Company 980 / 990 Logic
                      --
                      --    USD ledger ('Deckers Consol')
                      --    USD, LC balance
                      --    Get period_net as is
                      --
                      -- Copy of Code Block 3
                      -- ********************************************************************************************************
                      SELECT b.ledger_id, b.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           b.period_name, b.period_year,
                             b.period_num, 'LocalCurrency' currency_code, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) prior_per_ytd_bal,
                             NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) net_amount, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) end_ytd_amount
                        FROM apps.gl_balances b, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       WHERE     b.code_combination_id =
                                 gcc.code_combination_id
                             AND actual_flag = 'A'
                             AND (NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0 OR NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0)
                             AND b.period_name = P_PERIOD_NAME
                             --   AND b.ledger_id = 1    primary ledger which does not have reporting ledger               --commented by BT Team on 13/01/2015
                             AND b.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name = 'Deckers Consol'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND b.currency_code = 'USD'
                             --and gcc.account_type in ('R', 'E')
                             --and gcc.segment3 not in ('00000', '11230', '11236', '11611', '11612', '12001', '21112')
                             AND gcc.summary_flag = 'N' -- Exclude summary accounts
                             ----
                             AND gcc.segment7 = ffv.flex_value
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             -- AND ffv.flex_value_set_id = 1003630                                      --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.flex_value <> 'XX'
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND NVL (ffv.attribute7, 'USD') = 'USD'
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 16: ConstantLocal                 Company 980 / 990 Logic
                      --
                      --    USD ledger ('Deckers Consol')
                      --    USD balance
                      --    Get period_net amount as is
                      --
                      --   Copy of Code Block 3
                      -- ********************************************************************************************************
                      SELECT b.ledger_id, b.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           b.period_name, b.period_year,
                             b.period_num, 'ConstantLocal' currency_code, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) prior_per_ytd_bal,
                             NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) net_amount, NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) end_ytd_amount
                        FROM apps.gl_balances b, apps.gl_code_combinations gcc, apps.fnd_flex_values ffv
                       WHERE     b.code_combination_id =
                                 gcc.code_combination_id
                             AND actual_flag = 'A'
                             AND (NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0 OR NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) <> 0)
                             AND b.period_name = P_PERIOD_NAME
                             --   AND b.ledger_id = 1    primary ledger which does not have reporting ledger               --commented by BT Team on 13/01/2015
                             AND b.ledger_id IN
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name = 'Deckers Consol'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND b.currency_code = 'USD'
                             --and gcc.account_type in ('R', 'E')
                             --and gcc.segment3 not in ('00000', '11230', '11236', '11611', '11612', '12001', '21112')
                             AND gcc.summary_flag = 'N' -- Exclude summary accounts
                             ----
                             AND gcc.segment7 = ffv.flex_value
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             -- AND ffv.flex_value_set_id = 1003630                                      --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.flex_value <> 'XX'
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND NVL (ffv.attribute7, 'USD') = 'USD'
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 17: ConstantLocal                 Company 980 / 990 Logic
                      --
                      --    USD ledger('Deckers Consol')
                      --    USD, Non-LC balance
                      --    Get period_net amount * plan rate
                      --
                      -- Copy of Code Block 4
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'ConstantLocal' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name = 'Deckers Consol'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             AND gdr.conversion_type = '1000' --commented by BT team on 13-JAN-2014
                             AND gdr.from_currency = 'USD'
                             AND gdr.to_currency <> 'USD'
                             AND gdr.from_currency = gb1.currency_code
                             AND gdr.to_currency = ffv.attribute7
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 <> 'USD'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment7
                             AND gcc.summary_flag = 'N'
                      UNION
                      -- ********************************************************************************************************
                      -- Code Block 18: LocalCurrency                 Company 980 / 990 Logic
                      --
                      --    USD ledger ('Deckers Consol')
                      --    USD, non-LC balance
                      --    Get period_net amount * (rate based on account type)
                      --
                      --    Copy of Code Block 4
                      -- ********************************************************************************************************
                      SELECT gb1.ledger_id, gb1.code_combination_id, gcc.segment1,
                             gcc.segment2, gcc.segment3, gcc.segment4,
                             -- Start modificaton by BT Technology Team on 2/24
                             gcc.segment5, gcc.segment6, gcc.segment7,
                             gcc.segment8, -- End modificaton by BT Technology Team on 2/24
                                           gb1.period_name, gb1.period_year,
                             gb1.period_num, 'LocalCurrency' currency_code, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR) * 0, 2) prior_per_ytd_bal,
                             ROUND ((gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * gdr.CONVERSION_RATE, 2) net_amount, ROUND ((gb1.BEGIN_BALANCE_DR - gb1.BEGIN_BALANCE_CR + gb1.PERIOD_NET_DR - gb1.PERIOD_NET_CR) * 0, 2) end_ytd_amount
                        FROM apps.gl_balances gb1, apps.gl_code_combinations gcc, apps.GL_DAILY_RATES gdr,
                             apps.GL_PERIODS gp, apps.fnd_flex_values ffv, apps.gl_ledgers gll -- Added by Sarita
                       --  WHERE     gb1.ledger_id = 1                                            --commented by BT team on 13/01/2015
                       WHERE     gb1.ledger_id IN --Added by BT team on 13/01/2015
                                     (SELECT gl.ledger_id
                                        FROM APPS.GL_LEDGER_SETS_V glsv, APPS.GL_LEDGER_SET_ASSIGNMENTS glsa, APPS.GL_LEDGERS gl
                                       WHERE     glsv.name = 'Deckers Consol'
                                             AND glsv.ledger_id =
                                                 glsa.ledger_set_id
                                             AND glsa.ledger_id = gl.ledger_id
                                             AND glsa.ledger_set_id <>
                                                 glsa.ledger_id) --Added by BT Team on 13/01/2015
                             AND gb1.ledger_id = gll.ledger_id ---Added by Sarita
                             AND gb1.code_combination_id =
                                 gcc.CODE_COMBINATION_ID
                             AND gb1.Period_name = P_PERIOD_NAME
                             AND gb1.actual_flag = 'A'
                             AND (NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0 OR NVL (gb1.begin_balance_dr, 0) - NVL (gb1.begin_balance_cr, 0) + NVL (gb1.period_net_dr, 0) - NVL (gb1.period_net_cr, 0) <> 0)
                             /*conversion*/
                             -- AND gdr.conversion_type = 'Corporate'                         --commented by BT team on 13-JAN-2014
                             AND gdr.conversion_type =
                                 (CASE
                                      WHEN gcc.account_type = 'R'
                                      THEN
                                          'Corporate'
                                      WHEN gcc.account_type = 'E'
                                      THEN
                                          'Corporate'
                                      WHEN gcc.account_type = 'A'
                                      THEN
                                          'Spot'
                                      WHEN gcc.account_type = 'L'
                                      THEN
                                          'Spot'
                                      WHEN gcc.account_type = 'O'
                                      THEN
                                          'Spot'
                                  END)       --Added by BT Team on 13-JAN-2014
                             AND gdr.from_currency = 'USD'
                             AND gdr.to_currency <> 'USD'
                             --                        AND gdr.from_currency = NVL (ffv.attribute7, 'USD')
                             AND gdr.from_currency = gb1.currency_code
                             AND gdr.to_currency = ffv.attribute7
                             AND gdr.conversion_date = gp.END_DATE
                             AND gp.PERIOD_NAME = gb1.Period_name
                             -- Start modificaton by BT Technology Team on 2/24
                             AND gcc.segment1 IN ('990', '980')
                             -- End modificaton by BT Technology Team on 2/24
                             AND gp.period_set_name = gll.period_set_name --'Deckers Caldr' -- Changed by Sarita
                             --AND ffv.flex_value_set_id = 1003630                                       --commented by BT Team on 13/01/2015
                             AND ffv.flex_value_set_id IN
                                     (SELECT flex_value_set_id
                                        FROM fnd_flex_value_sets
                                       WHERE flex_value_set_name =
                                             'DO_GL_COMPANY') --Added by BT Team on 13/01/2015
                             AND ffv.ENABLED_FLAG = 'Y'
                             AND ffv.SUMMARY_FLAG = 'N'
                             AND ffv.attribute7 <> 'USD'
                             AND ffv.attribute7 IS NOT NULL
                             AND ffv.FLEX_VALUE = gcc.segment7
                             -- AND gcc.account_type IN ('R','E') --  If R,E then take Corporate rate, if it is Balance sheet, A & L  accounts then take Spot rate as of Month end of that period         --commented by BT Team on 13-JAN-2014
                             --                        AND gcc.account_type IN ('R', 'E', 'A', 'L') --Added by BT Team on 13-JAN-2014
                             AND gcc.summary_flag = 'N')
            GROUP BY ledger_id, code_combination_id, segment1,
                     segment2, segment3, segment4,
                     -- Start modificaton by BT Technology Team on 2/24
                     segment5, segment6, segment7,
                     segment8, -- End modificaton by BT Technology Team on 2/24
                               period_name, period_year,
                     period_num, currency_code
            ORDER BY segment1, segment2, segment3,
                     segment4;



        l_comma              VARCHAR2 (100) := ',';

        v_file_handle        UTL_FILE.file_type;
        l_output             VARCHAR2 (32767);
        l_dir                VARCHAR2 (300);
        l_file_name          VARCHAR2 (100);

        l_file_name_prefix   VARCHAR2 (50) := 'a~ORACLE_ACT_PL~ACTUAL~';
        l_file_name_suffix   VARCHAR2 (50) := '~RR.txt';
        l_file_name_period   VARCHAR2 (50);
    BEGIN
        /*IF P_OUTPUT_LOC IS NULL
        THEN
           -- Start changes by BT Technology Team on 13-jan-2014 - v2.2
           SELECT directory_path
             INTO l_dir
             FROM dba_directories
            WHERE directory_name = 'ODPDIR';
        --  l_dir := '/usr/tmp';
        -- End changes by BT Technology Team on 13-JAN-2014 - v2.2
        ELSE
           l_dir := P_OUTPUT_LOC;
        END IF;*/
        -- Commented by BT Technology Team V2.3 05-May-2015

        l_dir           := P_OUTPUT_LOC; -- Added by BT Technology Team V2.3 05-May-2015

        -- File name period logic
        BEGIN
            SELECT gp1.entered_Period_name || ' - ' || gp1.Period_year
              INTO l_file_name_period
              FROM apps.GL_PERIODS gp1
             WHERE     gp1.period_name = P_PERIOD_NAME -- Start changes by BT Technology Team on 13-JAN-2014 - v2.2
                   --     and gp1.period_set_name = 'Deckers FY Cal';
                   AND gp1.period_set_name = 'DO_FY_CALENDAR';

            -- End changes by BT Technology Team on 13-Jan-2014 - v2.2
            l_file_name   :=
                   l_file_name_prefix
                || l_file_name_period
                || l_file_name_suffix;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_file_name   := 'ERROR.csv';
        END;

        --UTL_FILE file open
        v_file_handle   := UTL_FILE.fopen (l_dir, l_file_name, 'w');
        -- ============================================
        --  Process Detail Extract
        -- ============================================
        -- Set Header Line
        l_output        :=
               'LEDGER_ID'
            || l_comma
            || 'CODE_COMBINATION_ID'
            || l_comma
            || 'SEGMENT1'
            || l_comma
            || 'SEGMENT2'
            || l_comma
            || 'SEGMENT3'
            || l_comma
            || 'SEGMENT4'
            -- Start modificaton by BT Technology Team on 2/24
            || l_comma
            || 'SEGMENT5'
            || l_comma
            || 'SEGMENT6'
            || l_comma
            || 'SEGMENT7'
            || l_comma
            || 'SEGMENT8'
            -- End modificaton by BT Technology Team on 2/24
            || l_comma
            || 'PERIOD_NAME'
            || l_comma
            || 'PERIOD_YEAR'
            || l_comma
            || 'PERIOD_NUM'
            || l_comma
            || 'CURRENCY_CODE'
            || l_comma
            || 'PRIOR_PER_YTD_BA'
            || l_comma
            || 'NET_AMOUNT'
            || l_comma
            || 'END_YTD_AMOUNT';
        apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT, l_output);

        --utl_file.put_line(v_file_handle,l_output);
        -- Write Header Line , header line not required currently for the file


        FOR i IN c_main (P_PERIOD_NAME)
        LOOP
            l_output   :=
                   i.LEDGER_ID
                || l_comma
                || i.CODE_COMBINATION_ID
                || l_comma
                || i.SEGMENT1
                || l_comma
                || i.SEGMENT2
                || l_comma
                || i.SEGMENT3
                || l_comma
                || i.SEGMENT4
                -- Start modificaton by BT Technology Team on 2/24
                || l_comma
                || i.SEGMENT5
                || l_comma
                || i.SEGMENT6
                || l_comma
                || i.SEGMENT7
                || l_comma
                || i.SEGMENT8
                -- End modificaton by BT Technology Team on 2/24
                || l_comma
                || i.PERIOD_NAME
                || l_comma
                || i.PERIOD_YEAR
                || l_comma
                || i.PERIOD_NUM
                || l_comma
                || i.CURRENCY_CODE
                || l_comma
                || i.PRIOR_PER_YTD_BA
                || l_comma
                || i.NET_AMOUNT
                || l_comma
                || i.END_YTD_AMOUNT;
            apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT, l_output);

            UTL_FILE.put_line (v_file_handle, l_output);
        END LOOP;

        UTL_FILE.fclose (v_file_handle);

        /* IF P_FINAL = 'N'
         THEN
            UPDATE apps.GL_PERIODS gp
               SET gp.attribute1 = 'N', gp.context = 'Hyperion'
             WHERE     gp.period_set_name = 'Deckers FY Cal'
                   AND period_name = P_Period_name
                   AND NVL (gp.context, 'Hyperion') = 'Hyperion'
                   AND NVL (gp.attribute1, 'N') = 'N';
         ELSE
            UPDATE apps.GL_PERIODS gp
               SET gp.attribute1 = 'Y', gp.context = 'Hyperion'
             WHERE     gp.period_set_name = 'Deckers FY Cal'
                   AND period_name = P_Period_name
                   AND NVL (gp.context, 'Hyperion') = 'Hyperion'
                   AND NVL (gp.attribute1, 'N') = 'N';
         END IF;
   */
        --commented by BT Team on 13-JAN-2014
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'NO_DATA_FOUND');
            p_errbuf    := 'No Data Found' || SQLERRM;
            p_retcode   := SQLCODE;
        WHEN INVALID_CURSOR
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'INVALID_CURSOR');
            p_errbuf    := 'No Data Found' || SQLERRM;
            p_retcode   := SQLCODE;
        WHEN TOO_MANY_ROWS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'TOO_MANY_ROWS');
            p_errbuf    := 'No Data Found' || SQLERRM;
            p_retcode   := SQLCODE;
        WHEN PROGRAM_ERROR
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'PROGRAM_ERROR');
            p_errbuf    := 'No Data Found' || SQLERRM;
            p_retcode   := SQLCODE;
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'OTHERS');
            p_errbuf    := 'No Data Found' || SQLERRM;
            p_retcode   := SQLCODE;
    END;
END XXDOGL_BAL_EXTRACT_PKG;
/


--
-- XXDOGL_BAL_EXTRACT_PKG  (Synonym) 
--
CREATE OR REPLACE SYNONYM XXDO.XXDOGL_BAL_EXTRACT_PKG FOR APPS.XXDOGL_BAL_EXTRACT_PKG
/
