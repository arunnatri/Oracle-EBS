--
-- XXDOGL_DAILY_RATES_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdogl_daily_rates_pkg
AS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy ( Suneara Technologies )
    -- Creation Date           : 25-APR-2011
    -- File Name               : XXDOGL009.pks
    -- INCIDENT                : INC0110283 Auto Population and modification of Exchange Rate
    --                           ENHC0010763
    -- Program                 : Daily Rates Import and Calculation - Deckers
    --
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 25-APR-2012       1.0         Vijaya Reddy         Initial development.
    --
    -------------------------------------------------------------------------------
    ---------------------------
    -- Declare Input Parameters
    ---------------------------

    --------------------
    -- GLOBAL VARIABLES
    --------------------
    gv_error_position   VARCHAR2 (3000);

    PROCEDURE get_gl_daily_rates (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_src_conv_type VARCHAR2, pd_src_date DATE, pv_src_from_cur VARCHAR2, pv_src_to_cur VARCHAR2, pv_trg_conv_type VARCHAR2, pd_trg_from_date DATE, pd_trg_to_date DATE
                                  , pv_dec_precision NUMBER);
END xxdogl_daily_rates_pkg;
/
