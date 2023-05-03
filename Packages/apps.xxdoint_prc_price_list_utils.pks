--
-- XXDOINT_PRC_PRICE_LIST_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINT_PRC_PRICE_LIST_UTILS"
    AUTHID DEFINER
AS
    /*************************************************************************************
     * Package         : XXDOINT_PRC_PRICE_LIST_UTILS
     * Description     : The purpose of this package to capture the CDC for Pricelist
     *                   and raise business for SOA.
     * Notes           :
     * Modification    :
     *-------------------------------------------------------------------------------------
     * Date         Version#      Name                       Description
     *-------------------------------------------------------------------------------------
     *              1.0                                Initial Version
     * 03-Dec-2020  1.1        Aravind Kannuri         Updated for CCR0009027
     ***************************************************************************************/

    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2);

    PROCEDURE archive_batch (p_batch_id IN NUMBER, p_process_id IN NUMBER:= NULL, x_ret_stat OUT VARCHAR2
                             , x_error_messages OUT VARCHAR2);

    PROCEDURE remove_batch (p_batch_id IN NUMBER, p_process_id IN NUMBER:= NULL, x_ret_stat OUT VARCHAR2
                            , x_error_messages OUT VARCHAR2);

    PROCEDURE process_update_batch (p_raise_event IN VARCHAR2:= 'Y', p_style IN VARCHAR2, p_batch IN NUMBER
                                    , x_batch_id OUT NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    PROCEDURE process_update_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_raise_event IN VARCHAR2:= 'Y'
                                         , p_debug_level IN VARCHAR2:= NULL, p_style IN VARCHAR2:= NULL, p_batch IN NUMBER:= NULL);

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, p_batch_name IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                    , x_error_messages OUT VARCHAR2);

    PROCEDURE reprocess_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_hours_old IN NUMBER
                                    , p_debug_level IN VARCHAR2:= NULL);

    --Start Added as per CCR0009027
    PROCEDURE process_full_load_batch (
        psqlstat           OUT VARCHAR2,
        perrproc           OUT VARCHAR2,
        p_raise_event   IN     VARCHAR2 := 'Y',
        p_debug_level   IN     VARCHAR2 := NULL,
        p_brand         IN     VARCHAR2 := NULL,
        p_region        IN     VARCHAR2 := NULL,
        p_season        IN     VARCHAR2 := NULL,
        p_price_list    IN     VARCHAR2 := NULL);
--End Added as per CCR0009027
END;
/


GRANT EXECUTE ON APPS.XXDOINT_PRC_PRICE_LIST_UTILS TO SOA_INT
/
