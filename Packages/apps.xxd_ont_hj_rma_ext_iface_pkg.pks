--
-- XXD_ONT_HJ_RMA_EXT_IFACE_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   XXD_ONT_HJ_RMA_BATCH_TBL_TYP (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_HJ_RMA_EXT_IFACE_PKG"
/****************************************************************************************
* Package      : XXD_ONT_RMA_HJ_IFACE_EXT_PKG
* Design       : This package will be used EBS to HJ RMA extraction
* Notes        :
* Modification :
-- ======================================================================================
-- Date         Version#   Name                    Comments
-- ======================================================================================
-- 10-April-2020  1.0       Gjensen        Initial Version
-- 15-April-2021  1.1       Suraj Valluri  US6
******************************************************************************************/
IS
    g_miss_num          CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    g_miss_char         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    g_miss_date         CONSTANT DATE := apps.fnd_api.g_miss_date;
    g_ret_success       CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    g_ret_error         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    g_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                     := apps.fnd_api.g_ret_sts_unexp_error ;
    g_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    g_success           CONSTANT NUMBER := 0;
    g_warning           CONSTANT NUMBER := 1;
    g_error             CONSTANT NUMBER := 2;

    PROCEDURE rma_extract_main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_organization_id IN NUMBER, p_rma_number IN NUMBER, p_sales_channel IN VARCHAR2, p_re_extract IN VARCHAR2:= 'N'
                                , p_debug_mode IN VARCHAR2:= 'N');

    PROCEDURE upd_batch_process_sts (p_batch_number IN NUMBER, p_from_status IN VARCHAR2, p_to_status IN VARCHAR2
                                     , p_error_message IN VARCHAR2, x_update_status OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE rma_extract_soa_obj_type (
        p_org_code        IN     VARCHAR2,                               --1.1
        x_batch_num_tbl      OUT xxd_ont_hj_rma_batch_tbl_typ);

    PROCEDURE purge_rma_data (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_num_archive_days IN NUMBER
                              , p_num_purge_days IN NUMBER);
END;
/


--
-- XXD_ONT_HJ_RMA_EXT_IFACE_PKG  (Synonym) 
--
--  Dependencies: 
--   XXD_ONT_HJ_RMA_EXT_IFACE_PKG (Package)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_ONT_HJ_RMA_EXT_IFACE_PKG FOR APPS.XXD_ONT_HJ_RMA_EXT_IFACE_PKG
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_HJ_RMA_EXT_IFACE_PKG TO SOA_INT
/
