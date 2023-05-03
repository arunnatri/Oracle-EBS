--
-- XXD_ONT_CALLOFF_ORDER_SCH_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CALLOFF_ORDER_SCH_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_ORDER_SCH_PKG
    * Design       : This package will be used for Calloff Order Scheduling
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-May-2018  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    FUNCTION insert_split_sys_param_fnc
        RETURN VARCHAR2;

    FUNCTION delete_split_sys_param_fnc (p_row_id IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE schedule_prc (
        x_errbuf                      OUT NOCOPY VARCHAR2,
        x_retcode                     OUT NOCOPY VARCHAR2,
        p_from_calloff_batch_id    IN            NUMBER,
        p_to_calloff_batch_id      IN            NUMBER,
        p_from_customer_batch_id   IN            NUMBER,
        p_to_customer_batch_id     IN            NUMBER,
        p_parent_request_id        IN            NUMBER,
        p_debug                    IN            VARCHAR2);
END xxd_ont_calloff_order_sch_pkg;
/
