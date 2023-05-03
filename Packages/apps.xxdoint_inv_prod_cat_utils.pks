--
-- XXDOINT_INV_PROD_CAT_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINT_INV_PROD_CAT_UTILS"
    AUTHID DEFINER
AS
    /********************************************************************************************
     * Package         : XXDOINT_INV_PROD_CAT_UTILS
     * Description     : This package is used to capture CDC for Items and raise business for SOA
     * Notes           :
     * Modification    :
     *-------------------------------------------------------------------------------------------
     * Date          Version#    Name                   Description
     *-------------------------------------------------------------------------------------------
     * 04-Apr-2016   1.0                                Initial Version
     * 19-Nov-2020   1.1         Aravind Kannuri        Updated for CCR0009029
     * 27-july-2021  1.2         Gaurav Joshi           Updated for CCR0009447
     ********************************************************************************************/
    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2);

    PROCEDURE process_update_batch (
        p_raise_event          IN     VARCHAR2 := 'Y',
        p_raise_season_event   IN     VARCHAR2 := 'Y', --Added as per CCR0009029
        x_batch_id                OUT NUMBER,
        x_ret_stat                OUT VARCHAR2,
        x_error_messages          OUT VARCHAR2);

    PROCEDURE process_update_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_raise_event IN VARCHAR2:= 'Y'
                                         , p_raise_season_event IN VARCHAR2:= 'Y', --Added as per CCR0009029
                                                                                   p_debug_level IN NUMBER:= NULL);

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    --Start Added as per CCR0009029
    PROCEDURE raise_season_event (p_batch_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    PROCEDURE insert_plm_sizes (p_size_chart_code IN NUMBER, p_size_chart_desc IN VARCHAR2, p_size_chart_values IN VARCHAR2
                                , p_enabled_flag IN VARCHAR2:= 'Y');

    PROCEDURE purge_season_batch (p_batch_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    -- 1.2  added to get Country of origin
    FUNCTION get_country_of_origin (p_inventory_item_id   NUMBER,
                                    p_inv_org_id          NUMBER)
        RETURN VARCHAR2;
--End Added as per CCR0009029
END;
/


GRANT EXECUTE ON APPS.XXDOINT_INV_PROD_CAT_UTILS TO SOA_INT
/

GRANT EXECUTE ON APPS.XXDOINT_INV_PROD_CAT_UTILS TO XXDO
/
