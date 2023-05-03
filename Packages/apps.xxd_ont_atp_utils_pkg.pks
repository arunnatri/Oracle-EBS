--
-- XXD_ONT_ATP_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_ATP_UTILS_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_ATP_UTILS_PKG
    -- Design       : This package will be used to find ATP for items based on avaiable dates
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 04-Mar-2022    Shivanshu Talwar       1.0    Initial Version
    -- #########################################################################################################################

    --Global Variables declaration
    g_miss_num          CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    g_miss_char         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    g_miss_date         CONSTANT DATE := apps.fnd_api.g_miss_date;
    g_ret_success       CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    g_ret_error         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    g_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                     := apps.fnd_api.g_ret_sts_unexp_error ;


    PROCEDURE GET_ATP_FUTURE_DATES (p_in_style_color IN VARCHAR2, p_in_demand_class IN VARCHAR2, p_in_customer IN VARCHAR2, p_in_order_type IN VARCHAR2, p_in_bulk_flag IN VARCHAR2, p_out_size_atp OUT SYS_REFCURSOR
                                    , p_out_err_msg OUT VARCHAR2);
END XXD_ONT_ATP_UTILS_PKG;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_ATP_UTILS_PKG TO XXORDS
/
