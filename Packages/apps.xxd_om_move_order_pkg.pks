--
-- XXD_OM_MOVE_ORDER_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OM_MOVE_ORDER_PKG"
/***************************************************************************************
* Program Name : XXD_OM_MOVE_ORDER_PKG                                                 *
* Language     : PL/SQL                                                                *
* Description  : Package to cancel the existing order , move the sales order           *
*                                                                                      *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Kishan Reddy         1.0       Initial Version                         24-FEB-2023   *
* -------------------------------------------------------------------------------------*/
AS
    --Global Constants
    -- Return Statuses
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;

    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2-- pn_org_id            IN   NUMBER
                                                                           );

    FUNCTION get_target_order_type (p_source_org_id IN NUMBER, p_target_org_id IN NUMBER, p_source_type_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_target_salesrep (p_salesreps_id    IN NUMBER,
                                  p_target_org_id   IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_target_bill_to (p_source_bill_to    IN NUMBER,
                                 p_source_customer   IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_target_ship_to (p_source_ship_to    IN NUMBER,
                                 p_source_customer   IN VARCHAR2)
        RETURN NUMBER;

    PROCEDURE create_new_bulk_order;

    PROCEDURE create_new_non_bulk_order;

    PROCEDURE import_target_non_bulk_order;

    PROCEDURE import_target_bulk_order;

    PROCEDURE update_order_details;
END XXD_OM_MOVE_ORDER_PKG;
/
