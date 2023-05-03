--
-- XXD_PO_BUYER_UPD_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_BUYER_UPD_PKG"
IS
    /********************************************************************************************
     * Package         : XXD_PO_BUYER_UPD_PKG
     * Description     : This package is used to update Buyer on Items and Open Purchase Orders
     * Notes           :
     * Modification    :
     *-------------------------------------------------------------------------------------------
     * Date          Version#    Name                   Description
     *-------------------------------------------------------------------------------------------
     * 19-AUG-2020   1.0         Kranthi Bollam         Initial Version for CCR0008468
     *******************************************************************************************/

    --Global constants
    -- Return Statuses
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;

    PROCEDURE buyer_upd_main (pv_errbuf                  OUT NOCOPY VARCHAR2,
                              pn_retcode                 OUT NOCOPY NUMBER,
                              pv_buyer_upd_on         IN            VARCHAR2 --Mandatory
                                                                            ,
                              pv_brand                IN            VARCHAR2 --Mandatory
                                                                            ,
                              pv_curr_active_season   IN            VARCHAR2 --Optional
                                                                            ,
                              pv_department           IN            VARCHAR2 --Optional
                                                                            ,
                              pn_org_id               IN            NUMBER --Optional (For PO's Only)
                                                                          ,
                              pv_buy_season           IN            VARCHAR2 --Optional (For PO's Only)
                                                                            ,
                              pv_buy_month            IN            VARCHAR2 --Optional (For PO's Only)
                                                                            ,
                              pv_po_date_from         IN            VARCHAR2 --Optional (For PO's Only)
                                                                            ,
                              pv_po_date_to           IN            VARCHAR2 --Optional (For PO's Only)
                                                                            );
END XXD_PO_BUYER_UPD_PKG;
/
