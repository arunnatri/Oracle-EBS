--
-- XXD_FA_ROLL_FWD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FA_ROLL_FWD_PKG"
AS
    /***********************************************************************************
     *$header :                                                                        *
     *                                                                                 *
     * AUTHORS : Srinath Siricilla                                                     *
     *                                                                                 *
     * PURPOSE : Used for Fixed Assets Reports                                         *
     *                                                                                 *
     * PARAMETERS :                                                                    *
     *                                                                                 *
     * DATE : 01-Dec-2013                                                              *
     *                                                                                 *
     * Assumptions:                                                                    *
     *                                                                                 *
     *                                                                                 *
     * History                                                                         *
     * Vsn   Change Date Changed By           Change Description                       *
     * ----- ----------- -------------------  -------------------------------------    *
     * 1.0   01-Dec-2013 Srinath Siricilla    Initial Creation                         *
     * 2.0   31-May-2014 Srinath Siricilla    Added Capitalized Column and NBV logic   *
     * 3.0   16-Oct-2014 BT Technology Team   Retrofitted the program                  *
     * 4.0   10-Nov-2014 BT Technology Team   Retrofited two funcitons and two         *
     *                                        procedures for impairment logic          *
  * 5.0   13-Aug-2019 Showkath Ali         Added Project type parameter(CCR0008086) *
     **********************************************************************************/
    -- Start changes by BT Technology Team v4.0 on 10-Nov-2014
    g_from_currency   VARCHAR2 (3) DEFAULT 'USD';
    g_to_currency     VARCHAR2 (3) DEFAULT 'USD';

    FUNCTION xxd_fa_return_sob_id_fnc (pn_book       IN VARCHAR2,
                                       pn_currency      VARCHAR2)
        RETURN NUMBER;


    FUNCTION xxd_fa_set_client_info_fnc (p_sob_id IN VARCHAR2)
        RETURN NUMBER;

    PROCEDURE xxd_fa_update_impairment (pn_asset_id NUMBER, pn_book VARCHAR2);


    PROCEDURE xxd_fa_update_impairment_sum (pn_asset_id   NUMBER,
                                            pn_book       VARCHAR2);

    -- End changes by BT Technology Team v4.0 on 10-Nov-2014

    -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
    PROCEDURE get_project_cip_prc (p_called_from IN VARCHAR2, p_book IN VARCHAR2, p_currency IN VARCHAR2, p_from_period IN VARCHAR2, p_to_period IN VARCHAR2, p_begin_spot_rate IN NUMBER, p_end_spot_rate IN NUMBER, p_begin_bal_tot OUT NUMBER, p_begin_spot_tot OUT NUMBER, p_begin_trans_tot OUT NUMBER, p_additions_tot OUT NUMBER, p_capitalizations_tot OUT NUMBER, p_end_bal_tot OUT NUMBER, p_end_spot_tot OUT NUMBER, p_end_trans_tot OUT NUMBER
                                   , p_net_trans_tot OUT NUMBER);

    -- End changes by BT Technology Team v4.1 on 26-Dec-2014
    PROCEDURE get_balance (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                           , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2);

    PROCEDURE get_balance_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                               , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2);

    PROCEDURE get_balance_group_begin (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                                       , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2);

    PROCEDURE get_balance_group_begin_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                                           , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2);

    PROCEDURE get_balance_group_end (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                                     , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2);

    PROCEDURE get_balance_group_end_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                                         , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2);

    PROCEDURE get_adjustments (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period1_pc IN NUMBER
                               , period2_pc IN NUMBER, report_type IN VARCHAR2, balance_type IN VARCHAR2);

    PROCEDURE get_adjustments_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period1_pc IN NUMBER
                                   , period2_pc IN NUMBER, report_type IN VARCHAR2, balance_type IN VARCHAR2);

    PROCEDURE get_adjustments_for_group (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period1_pc IN NUMBER
                                         , period2_pc IN NUMBER, report_type IN VARCHAR2, balance_type IN VARCHAR2);

    PROCEDURE get_adjustments_for_group_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period1_pc IN NUMBER
                                             , period2_pc IN NUMBER, report_type IN VARCHAR2, balance_type IN VARCHAR2);

    PROCEDURE get_deprn_effects (book                       IN VARCHAR2,
                                 distribution_source_book   IN VARCHAR2,
                                 period1_pc                 IN NUMBER,
                                 period2_pc                 IN NUMBER,
                                 report_type                IN VARCHAR2);

    PROCEDURE get_deprn_effects_sum (book                       IN VARCHAR2,
                                     distribution_source_book   IN VARCHAR2,
                                     period1_pc                 IN NUMBER,
                                     period2_pc                 IN NUMBER,
                                     report_type                IN VARCHAR2);

    PROCEDURE insert_info (book IN VARCHAR2, start_period_name IN VARCHAR2, end_period_name IN VARCHAR2
                           , report_type IN VARCHAR2, adj_mode IN VARCHAR2);

    PROCEDURE insert_info_sum (book                IN VARCHAR2,
                               start_period_name   IN VARCHAR2,
                               end_period_name     IN VARCHAR2,
                               report_type         IN VARCHAR2,
                               adj_mode            IN VARCHAR2);

    PROCEDURE xxd_fa_rsvldg_proc (book IN VARCHAR2, period IN VARCHAR2);

    PROCEDURE xxd_fa_rsvldg_proc_sum (book IN VARCHAR2, period IN VARCHAR2);

    FUNCTION xxd_fa_cap_asset (pn_asset_id IN NUMBER, p_book IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION xxd_fa_depreciation_cost (pn_asset_id         IN NUMBER,
                                       pv_book_type_code   IN VARCHAR2)
        RETURN NUMBER;

    PROCEDURE xxd_fa_net_book_value (pn_asset_id IN NUMBER, pn_book VARCHAR2);

    PROCEDURE xxd_fa_net_book_value_sum (pn_asset_id   IN NUMBER,
                                         pn_book          VARCHAR2);

    PROCEDURE main_detail (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_book IN VARCHAR2, p_currency IN VARCHAR2, p_from_period IN VARCHAR2, p_to_period IN VARCHAR2
                           , p_subtotal IN VARCHAR2, p_subtotal_value IN VARCHAR2, p_project_type IN VARCHAR2); -- CCR0008086

    PROCEDURE main_summary (errbuf                OUT VARCHAR2,
                            retcode               OUT NUMBER,
                            p_book             IN     VARCHAR2,
                            p_currency         IN     VARCHAR2,
                            p_from_period      IN     VARCHAR2,
                            p_to_period        IN     VARCHAR2,
                            p_subtotal         IN     VARCHAR2,
                            p_subtotal_value   IN     VARCHAR2);
END;
/
