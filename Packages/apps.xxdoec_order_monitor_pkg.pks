--
-- XXDOEC_ORDER_MONITOR_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_ORDER_MONITOR_PKG"
AS
    -- =======================================================
    -- Author:      Keith Copeland
    -- Create date: 11/12/2014
    -- Description: This package is used to return a count of order lines that have been at a
    --                   particular state for longer that x interval
    -- =======================================================
    -- Modification History
    -- Modified Date/By/Description:
    -- <Modifying Date, Modifying Author, Change Description>
    -- =======================================================
    -- Sample Execution
    -- =======================================================

    TYPE ttbl_status_codes IS TABLE OF VARCHAR2 (64)
        INDEX BY BINARY_INTEGER;

    TYPE ttbl_action_codes IS TABLE OF VARCHAR2 (128)
        INDEX BY BINARY_INTEGER;

    PROCEDURE get_monitoring_results (p_actions IN ttbl_action_codes, p_status_codes IN ttbl_status_codes, p_min_interval_val IN VARCHAR2, p_max_interval_val IN VARCHAR2, p_interval_type IN VARCHAR2, p_exclude_custom IN VARCHAR2
                                      , x_results OUT INT);
END XXDOEC_ORDER_MONITOR_PKG;
/
