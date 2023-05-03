--
-- XXD_WSH_PROCESS_ORDER_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WSH_PROCESS_ORDER_PKG"
AS /******************************************************************************************
  * Package      :XXD_WSH_PROCESS_ORDER_PKG
  * Design       : This package is used for splitting delivery details by
  *                 container for the inbound ASN and to populate the EDI ASN outbound tables
  * Notes        :
  * Modification :
 -- =============================================================================
 -- Date         Version#   Name                    Comments
 -- =============================================================================
 -- 02-MAY-2019  1.0        Greg Jensen           Initial Version
 ******************************************************************************************/
                                                                  --  DEFAULTS
    g_miss_num                   CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    g_miss_char                  CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    g_miss_date                  CONSTANT DATE := apps.fnd_api.g_miss_date;
    -- RETURN STATUSES
    g_ret_success                CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    g_ret_error                  CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    g_ret_unexp_error            CONSTANT VARCHAR2 (1)
                                              := apps.fnd_api.g_ret_sts_unexp_error ;
    g_ret_warning                CONSTANT VARCHAR2 (1) := 'W';
    g_ret_init                   CONSTANT VARCHAR2 (1) := 'I';
    g_proc_status_acknowledged   CONSTANT VARCHAR2 (1) := 'A';
    -- CONCURRENT STATUSES
    g_fnd_normal                 CONSTANT VARCHAR2 (20) := 'NORMAL';
    g_fnd_warning                CONSTANT VARCHAR2 (20) := 'WARNING';
    g_fnd_error                  CONSTANT VARCHAR2 (20) := 'ERROR';

    PROCEDURE add_edi_shipments (pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pv_bill_of_lading IN VARCHAR2
                                 , pv_container IN VARCHAR2, pn_ship_to_org_id IN NUMBER, pn_delivery_id IN NUMBER);

    PROCEDURE do_process (pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pn_delivery_id IN NUMBER:= NULL
                          , pv_debug IN VARCHAR2);
END;
/
