--
-- XXDOEC_ORDER_MONITOR_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_ORDER_MONITOR_PKG"
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

    PROCEDURE get_monitoring_results (p_actions IN ttbl_action_codes, p_status_codes IN ttbl_status_codes, p_min_interval_val IN VARCHAR2, p_max_interval_val IN VARCHAR2, p_interval_type IN VARCHAR2, p_exclude_custom IN VARCHAR2
                                      , x_results OUT INT)
    IS
        l_status_list      xxdoec_upc_list := xxdoec_upc_list ();
        l_action_list      xxdoec_upc_list := xxdoec_upc_list ();
        l_max_interval     VARCHAR2 (8) := NVL (p_max_interval_val, '24');
        l_min_interval     VARCHAR2 (8) := p_min_interval_val;
        l_max_date         DATE;
        l_min_date         DATE;
        l_interval_type    VARCHAR2 (50) := NVL (p_interval_type, 'MINUTE');
        l_exclude_custom   VARCHAR2 (1) := NVL (p_exclude_custom, 'Y');
    BEGIN
        --Prepare action list
        l_action_list.EXTEND (p_actions.COUNT);

        FOR i IN p_actions.FIRST .. p_actions.LAST
        LOOP
            l_action_list (i)   := p_actions (i);
        END LOOP;

        --Prepare status list
        l_status_list.EXTEND (p_status_codes.COUNT);

        FOR i IN p_status_codes.FIRST .. p_status_codes.LAST
        LOOP
            l_status_list (i)   := p_status_codes (i);
        END LOOP;

        --Calculate max datetime to go back to
        --NUMTODSINTERVAL is a standard Oracle Function that returns a value used in date calculations
        l_max_date   :=
            SYSDATE - NUMTODSINTERVAL (NVL (l_max_interval, '24'), 'HOUR');
        --Calculate min datetime to go back to
        l_min_date   :=
            SYSDATE - NUMTODSINTERVAL (l_min_interval, l_interval_type);

        SELECT COUNT (*)
          INTO x_results
          FROM oe_order_lines_all ool
               JOIN oe_order_headers_all ooh ON ooh.header_id = ool.header_id
               JOIN oe_transaction_types_all ott
                   ON ott.transaction_type_id = ooh.order_type_id
         WHERE     1 = 1
               AND ool.order_source_id IN (SELECT order_source_id
                                             FROM ont.oe_order_sources
                                            WHERE name = 'Flagstaff')
               AND ool.last_update_date <= l_min_date
               AND ool.last_update_date > l_max_date
               AND ool.attribute20 IN (SELECT * FROM TABLE (l_action_list))
               AND ool.attribute17 IN (SELECT * FROM TABLE (l_status_list))
               AND ool.cancelled_flag <> 'Y'
               AND ool.ordered_item NOT LIKE '%CUSTOM%'
               AND (NVL (ott.attribute13, '~') NOT IN ('RE', 'EE', 'RR',
                                                       'AE', 'ER', 'PE'));
    EXCEPTION
        WHEN OTHERS
        THEN
            x_results   := 0;
            DBMS_OUTPUT.PUT_LINE (SQLERRM);
    END get_monitoring_results;
END XXDOEC_ORDER_MONITOR_PKG;
/
