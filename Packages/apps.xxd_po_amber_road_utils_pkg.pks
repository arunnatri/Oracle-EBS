--
-- XXD_PO_AMBER_ROAD_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_AMBER_ROAD_UTILS_PKG"
/****************************************************************************************
* Package      : xxd_po_amber_road_utils_pkg
* Design       : This is a utility package used for Amber Road Project
* Notes        :
* Modification :
-- ===========  ========    ======================= =====================================
-- Date         Version#    Name                    Comments
-- ===========  ========    ======================= =======================================
-- 11-Sep-2018  1.0         Kranthi Bollam          Initial Version
--
-- ===========  ========    ======================= =======================================
******************************************************************************************/
IS
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

    --Procedure to write messages into log and output files or to dbms output
    PROCEDURE msg (pv_msg    IN VARCHAR2,
                   pv_time   IN VARCHAR2 DEFAULT 'N',
                   pv_file   IN VARCHAR2 DEFAULT 'LOG');

    --Sets values for the Purchase Order extract filter in the Incremental View(XXD_PO_AMB_RD_PO_INC_LOAD_V)
    --This procedure writes values to the XXD_PO_AMBER_ROAD_UTILS_LKP lookup
    PROCEDURE set_po_last_extract_date (pv_dummy IN VARCHAR2 --To make SOA code work
                                                            , xv_status OUT NOCOPY VARCHAR2, xv_message OUT NOCOPY VARCHAR2);
END xxd_po_amber_road_utils_pkg;
/


--
-- XXD_PO_AMBER_ROAD_UTILS_PKG  (Synonym) 
--
--  Dependencies: 
--   XXD_PO_AMBER_ROAD_UTILS_PKG (Package)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_PO_AMBER_ROAD_UTILS_PKG FOR APPS.XXD_PO_AMBER_ROAD_UTILS_PKG
/


GRANT EXECUTE, DEBUG ON APPS.XXD_PO_AMBER_ROAD_UTILS_PKG TO SOA_INT
/
