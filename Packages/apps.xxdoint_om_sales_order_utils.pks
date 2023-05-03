--
-- XXDOINT_OM_SALES_ORDER_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINT_OM_SALES_ORDER_UTILS"
    AUTHID DEFINER
AS
    /****************************************************************************
       * PACKAGE Name    : XXDOINT_OM_SALES_ORDER_UTILS
       *
       * Description       : The purpose of this package to capture the CDC
       *                     for Order and raise business for SOA.
       *
       * INPUT Parameters  :
       *
       * OUTPUT Parameters :
       *
       * DEVELOPMENT and MAINTENANCE HISTORY
       *
       * ======================================================================================
       * Date         Version#   Name                    Comments
       * ======================================================================================
       * 04-Apr-2016  1.0                                Initial Version
       * 10-Oct-2020  1.1        Aravind Kannuri         Updated for CCR0008801
       * 23-Nov-2020  1.4        Aravind Kannuri         Updated for CCR0009028
       * 23-Dec-2020  1.5        Shivanshu Talwar        Updated for CCR0009053
       * 10-Jan-2021  1.6        Shivanshu Talwar        Updated for CCR0009093
       ******************************************************************************************/

    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2);

    PROCEDURE archive_batch (p_batch_id IN NUMBER, p_process_id IN NUMBER:= NULL, x_ret_stat OUT VARCHAR2
                             , x_error_messages OUT VARCHAR2);

    PROCEDURE remove_batch (p_batch_id IN NUMBER, p_process_id IN NUMBER:= NULL, x_ret_stat OUT VARCHAR2
                            , x_error_messages OUT VARCHAR2);

    PROCEDURE process_update_batch (
        p_raise_event       IN     VARCHAR2 := 'Y',
        p_ord_source_type   IN     VARCHAR2 := 'ALL', --Added as per CCR0009028
        x_batch_id             OUT NUMBER,
        x_ret_stat             OUT VARCHAR2,
        x_error_messages       OUT VARCHAR2);

    PROCEDURE process_update_batch_conc (
        psqlstat               OUT VARCHAR2,
        perrproc               OUT VARCHAR2,
        p_raise_event       IN     VARCHAR2 := 'Y',
        p_debug_level       IN     NUMBER := NULL,
        p_ord_source_type   IN     VARCHAR2 := 'ALL' --Added as per CCR0009028
                                                    );

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, p_batch_name IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                    , x_error_messages OUT VARCHAR2);

    PROCEDURE reprocess_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_hours_old IN NUMBER
                                    , p_debug_level IN NUMBER:= NULL);

    --START Added for CCR0008801
    --Added Functions used in Full and NC Views
    FUNCTION get_season_code (p_org_id IN NUMBER, p_header_id IN NUMBER, p_brand IN VARCHAR2, p_ord_type_name IN VARCHAR2, p_ord_source_name IN VARCHAR2, p_request_date IN DATE
                              , orig_sys_document_ref IN VARCHAR2  --W.r.t 1.5
                                                                 )
        RETURN VARCHAR2;

    FUNCTION get_hs_price_list (p_org_id IN NUMBER, p_header_id IN NUMBER, p_brand IN VARCHAR2, p_type IN VARCHAR2, p_ord_source_id IN NUMBER, p_ebs_pricelist_id IN NUMBER
                                , p_ebs_pricelist IN VARCHAR2, p_request_date IN DATE, orig_sys_document_ref IN VARCHAR2 --W.r.t 1.5
                                                                                                                        )
        RETURN VARCHAR2;

    --END Added for CCR0008801


    FUNCTION get_hold_information (                       --w.r.t. Version 1.6
                                   p_org_id      IN NUMBER,
                                   p_header_id   IN NUMBER,
                                   p_hold_info   IN VARCHAR2)
        RETURN VARCHAR2;
--END Added for CCR0009093

END;
/


GRANT EXECUTE ON APPS.XXDOINT_OM_SALES_ORDER_UTILS TO SOA_INT
/

GRANT EXECUTE ON APPS.XXDOINT_OM_SALES_ORDER_UTILS TO XXDO
/
