--
-- XXD_ONT_PRODUCT_MV_PKG  (Package) 
--
--  Dependencies: 
--   PM_TBL_TYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_PRODUCT_MV_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_PRODUCT_MV_PKG
    -- Design       : This package will be used to fetch values required for LOV
    --                in the product move tool. This package will also  search
    --                for order details based on user entered data.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 23-Feb-2021    Infosys              1.0    Initial Version
    -- 26-May-2021 Infosys              1.1    Created a procedure to fetch username and id
    -- #########################################################################################################################

    PROCEDURE write_to_table (msg VARCHAR2, app VARCHAR2);

    PROCEDURE fetch_user_name (p_in_user_email_id   IN     VARCHAR2,
                               p_out_user_name         OUT VARCHAR2);

    PROCEDURE fetch_user_id (p_in_user_name   IN     VARCHAR2,
                             p_out_user_id       OUT NUMBER);

    /************Start modification for version 1.1 ****************/
    /*FUNCTION fetch_ad_user_name (p_in_user_email IN VARCHAR2)
        RETURN VARCHAR2;*/

    PROCEDURE fetch_ad_user_name (p_in_user_email IN VARCHAR2, p_out_user_name OUT VARCHAR2, p_out_user_id OUT NUMBER);

    PROCEDURE fetch_ad_user_email (p_in_user_id IN VARCHAR2, p_out_user_name OUT VARCHAR2, p_out_display_name OUT VARCHAR2
                                   , p_out_email_id OUT VARCHAR2);

    /************End modification for version 1.1 ****************/

    FUNCTION user_access (p_in_user_name IN VARCHAR2, p_in_segment_name IN VARCHAR2, p_in_segment_value IN VARCHAR2
                          , p_in_instance_name IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE search_results (p_in_user_id IN NUMBER, p_in_warehouse IN VARCHAR2, p_in_style_color IN VARCHAR2, p_in_instance_name IN VARCHAR2, p_out_results OUT SYS_REFCURSOR, p_out_size OUT SYS_REFCURSOR
                              , p_out_err_msg OUT VARCHAR2);

    PROCEDURE insert_stg_data (p_in_user_id IN NUMBER, p_in_org_id IN NUMBER, p_in_batch_id IN NUMBER
                               , p_in_style_color IN VARCHAR2, p_input_data IN PM_TBL_TYPE, p_out_err_msg OUT VARCHAR2);

    PROCEDURE process_order_api_p (p_in_batch_id IN NUMBER);

    PROCEDURE submit_order_p (p_in_batch_id               IN     NUMBER,
                              p_in_org_id                 IN     NUMBER,
                              p_in_header_id              IN     NUMBER,
                              p_in_line_id                IN     NUMBER,
                              p_in_schedule_action_code   IN     VARCHAR2,
                              p_in_batch_commit           IN     VARCHAR2,
                              p_out_err_msg                  OUT VARCHAR2,
                              p_out_err_flag                 OUT VARCHAR2);

    PROCEDURE schedule_order (p_in_batch_id   IN     NUMBER,
                              p_out_err_msg      OUT VARCHAR2);

    PROCEDURE fetch_stg_hdr_data (p_in_user_id IN NUMBER, p_out_hdr OUT SYS_REFCURSOR, p_out_err_msg OUT VARCHAR2);


    PROCEDURE fetch_stg_line_data (p_in_user_id IN NUMBER, p_in_batch_id IN NUMBER, p_out_line OUT SYS_REFCURSOR
                                   , p_out_err_msg OUT VARCHAR2);
END XXD_ONT_PRODUCT_MV_PKG;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_PRODUCT_MV_PKG TO XXORDS
/
