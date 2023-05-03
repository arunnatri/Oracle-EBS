--
-- XXD_PO_CLOSE_RECEIVED_POS_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_CLOSE_RECEIVED_POS_PKG"
IS
    --  ####################################################################################################
    --  Package      : xxd_po_close_received_pos_pkg
    --  Design       : Package is used to Automate PO Closing for TQ PO's and SFS PO's.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  21-May-2020     1.0        Showkath Ali             Initial Version
    --  ####################################################################################################

    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;

    PROCEDURE main_prc (pv_errbuf OUT VARCHAR2, pn_retcode OUT NUMBER, pv_run_mode IN VARCHAR2, pv_po_type IN VARCHAR2, pv_po_from_date IN VARCHAR2, pv_po_to_date IN VARCHAR2
                        , pv_po_number IN VARCHAR2);
END xxd_po_close_received_pos_pkg;
/
