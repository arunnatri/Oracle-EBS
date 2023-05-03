--
-- XXD_ONT_SO_CORRECTION_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_SO_CORRECTION_PKG"
IS
    --  ###################################################################################################
    --  Author(s)       : Kranthi Bollam (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : Order Management
    --  Change          : CCR0007644
    --  Schema          : APPS
    --  Purpose         : Syncing Latest Acceptable Date and Line cancel date with Header Cancel Date of
    --                      Sales Orders
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  15-Jan-2019     Kranthi Bollam      1.0     NA              Initial Version
    --
    --  ####################################################################################################
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

    PROCEDURE so_correction_main (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pn_org_id IN NUMBER --Mandatory
                                                                                                                  , pv_brand IN VARCHAR2 --Optional
                                                                                                                                        , pv_order_type IN VARCHAR2 DEFAULT 'NONE' --Mandatory
                                                                                                                                                                                  , pv_order_source IN VARCHAR2 DEFAULT 'NONE' --Mandatory
                                                                                                                                                                                                                              , pv_request_date_from IN VARCHAR2 --Optional
                                                                                                                                                                                                                                                                , pv_request_date_to IN VARCHAR2 --Optional
                                                                                                                                                                                                                                                                                                , pv_process IN VARCHAR2 DEFAULT 'BOTH' --Mandatory
                                  , pv_send_email IN VARCHAR2 DEFAULT 'N' --Optional
                                                                         );
END XXD_ONT_SO_CORRECTION_PKG;
/
