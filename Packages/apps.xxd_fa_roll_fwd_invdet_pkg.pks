--
-- XXD_FA_ROLL_FWD_INVDET_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FA_ROLL_FWD_INVDET_PKG"
AS
    /***********************************************************************************
     *$header :                                                                        *
     *                                                                                 *
     * AUTHORS : Madhav Dhurjaty                                                       *
     *                                                                                 *
     * PURPOSE : Deckers FA Roll Forward Invoice Detail Report                         *
     *                                                                                 *
     * PARAMETERS :                                                                    *
     *                                                                                 *
     * DATE : 01-Dec-2018                                                              *
     *                                                                                 *
     * Assumptions:                                                                    *
     *                                                                                 *
     *                                                                                 *
     * History                                                                         *
     * Vsn   Change Date Changed By           Change Description                       *
     * ----- ----------- -------------------  -------------------------------------    *
     * 1.0   01-Dec-2018 Madhav Dhurjaty      Initial Creation                         *
     * 2.0   24-DEC-2021 Srinath Siricilla    CCR0008761                               *
     **********************************************************************************/
    -- Start changes by BT Technology Team v4.0 on 10-Nov-2014
    g_from_currency   VARCHAR2 (3) DEFAULT 'USD';
    g_to_currency     VARCHAR2 (3) DEFAULT 'USD';

    FUNCTION return_sob_id (pn_book IN VARCHAR2, pn_currency VARCHAR2)
        RETURN NUMBER;


    FUNCTION set_client_info (p_sob_id IN VARCHAR2)
        RETURN NUMBER;

    PROCEDURE update_impairment (pn_asset_id NUMBER, pn_book VARCHAR2);


    PROCEDURE update_impairment_sum (pn_asset_id NUMBER, pn_book VARCHAR2);

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

    PROCEDURE rsvldg_proc (book IN VARCHAR2, period IN VARCHAR2);

    PROCEDURE rsvldg_proc_sum (book IN VARCHAR2, period IN VARCHAR2);

    FUNCTION cap_asset (pn_asset_id IN NUMBER, p_book IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION depreciation_cost (pn_asset_id         IN NUMBER,
                                pv_book_type_code   IN VARCHAR2)
        RETURN NUMBER;

    PROCEDURE net_book_value (pn_asset_id IN NUMBER, pn_book VARCHAR2);

    PROCEDURE net_book_value_sum (pn_asset_id IN NUMBER, pn_book VARCHAR2);

    PROCEDURE invoice_detail (errbuf                OUT NOCOPY VARCHAR2,
                              retcode               OUT NOCOPY NUMBER,
                              p_book             IN            VARCHAR2,
                              p_currency         IN            VARCHAR2,
                              p_from_period      IN OUT        VARCHAR2,
                              p_to_period        IN            VARCHAR2,
                              p_subtotal         IN            VARCHAR2,
                              p_subtotal_value   IN            VARCHAR2);

    -- Start of Change as per CCR0008761
    FUNCTION get_period_name_pc (pn_adj_amount       IN NUMBER,
                                 pv_asset_number     IN VARCHAR2,
                                 pn_asset_id         IN NUMBER,
                                 pv_book             IN VARCHAR2,
                                 pn_period_counter   IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE update_period_prc (pv_book_code   IN VARCHAR2,
                                 pv_to_period   IN VARCHAR2);

    PROCEDURE update_bal_prc (pv_book_code   IN VARCHAR2,
                              pv_to_period   IN VARCHAR2);
-- End of CHnage as per CCR0008761

END;
/
