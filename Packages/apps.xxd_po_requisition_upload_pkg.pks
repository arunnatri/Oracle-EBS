--
-- XXD_PO_REQUISITION_UPLOAD_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_REQUISITION_UPLOAD_PKG"
IS
    --  ####################################################################################################
    --  Author(s)       : Tejaswi Gangumalla (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : EBS
    --  Change          : CCR0006710
    --  Schema          : APPS
    --  Purpose         : Package is used to create Internal Requisitions for DC to Transfers
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  21-Feb-2018     Tejaswi Gangumalla  1.0     NA              Initial Version
    --  5-MAR-2020      Tejaswi Gangumalla  1.1     CCR0008870      GAS Project
    --  ####################################################################################################
    --Global Variables
    -- Return Statuses
    g_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    g_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    g_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                     := fnd_api.g_ret_sts_unexp_error ;
    g_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success          CONSTANT NUMBER := 0;    --Added as part of change 1.1
    gn_warning          CONSTANT NUMBER := 1;    --Added as part of change 1.1
    gn_error            CONSTANT NUMBER := 2;    --Added as part of change 1.1

    --Main Procedure called by WebADI
    PROCEDURE upload_proc (pv_sku VARCHAR2, pv_dest_org VARCHAR2, pv_source_org VARCHAR2, pn_quantity NUMBER, pv_need_by_date VARCHAR2, pn_grouping_number NUMBER, pv_sales_channel VARCHAR2, --Added for change 1.1
                                                                                                                                                                                              pv_attribute1 VARCHAR2, --Added for change 1.1
                                                                                                                                                                                                                      pv_attribute2 VARCHAR2, --Added for change 1.1
                                                                                                                                                                                                                                              pv_attribute3 VARCHAR2, --Added for change 1.1
                                                                                                                                                                                                                                                                      pv_attribute4 VARCHAR2, --Added for change 1.1
                                                                                                                                                                                                                                                                                              pv_attribute5 VARCHAR2, --Added for change 1.1
                                                                                                                                                                                                                                                                                                                      pn_attribute6 NUMBER, --Added for change 1.1
                                                                                                                                                                                                                                                                                                                                            pn_attribute7 NUMBER, --Added for change 1.1
                                                                                                                                                                                                                                                                                                                                                                  pn_attribute8 NUMBER
                           ,                            --Added for change 1.1
                             pd_attribute9 DATE,        --Added for change 1.1
                                                 pd_attribute10 DATE --Added for change 1.1
                                                                    );

    PROCEDURE importer_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER);

    PROCEDURE status_report (pv_error_message OUT VARCHAR2);
END xxd_po_requisition_upload_pkg;
/
