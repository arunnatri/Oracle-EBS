--
-- XXD_ONT_DTC_BULK_ROLLOVER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_DTC_BULK_ROLLOVER_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_DTC_BULK_ROLLOVER_PKG
    * Design       :
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 01-Dec-2021  1.0        Gaurav Joshi     Initial Version
    ******************************************************************************************/
    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_operation_mode IN VARCHAR2
                          , p_group_id IN NUMBER);

    PROCEDURE child_prc (x_errbuf              OUT NOCOPY VARCHAR2,
                         x_retcode             OUT NOCOPY NUMBER,
                         p_operation_mode   IN            VARCHAR2,
                         p_group_id         IN            NUMBER,
                         p_batch_id         IN            NUMBER,
                         p_line_status      IN            VARCHAR2);

    PROCEDURE start_rollover (p_operation_mode   IN VARCHAR2,
                              p_group_id         IN NUMBER);

    PROCEDURE create_header (p_operation_mode   IN VARCHAR2,
                             p_group_id         IN NUMBER);

    PROCEDURE insert_prc (p_operation_mode IN VARCHAR2, p_group_id IN NUMBER);



    PROCEDURE process_order_prc (p_operation_mode IN VARCHAR2, p_group_id IN NUMBER, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_brand IN VARCHAR2, p_order_type_id IN VARCHAR2, p_inv_org_id IN NUMBER, p_channel IN VARCHAR2, p_department IN VARCHAR2, p_request_date_from IN DATE, p_request_date_to IN DATE, p_execution_mode IN VARCHAR2, x_ret_status OUT NOCOPY VARCHAR2
                                 , x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE bucketing_of_lines (p_operation_mode   IN VARCHAR2,
                                  p_group_id         IN NUMBER);

    PROCEDURE add_lines (p_group_id      IN NUMBER,
                         p_thread_no     IN NUMBER,
                         p_line_status   IN VARCHAR2);

    FUNCTION validate_request_date_to (p_in_request_date DATE)
        RETURN VARCHAR2;

    FUNCTION validate_request_date_from (p_in_request_date_from DATE)
        RETURN VARCHAR2;

    FUNCTION validate_access (p_in_org_id NUMBER)
        RETURN VARCHAR2;
END XXD_ONT_DTC_BULK_ROLLOVER_PKG;
/
