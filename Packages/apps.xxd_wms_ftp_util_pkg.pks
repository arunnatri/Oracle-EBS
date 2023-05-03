--
-- XXD_WMS_FTP_UTIL_PKG  (Package) 
--
--  Dependencies: 
--   DO_MAIL_UTILS (Package)
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_FTP_UTIL_PKG"
AS
    /****************************************************************************************
    * Change#      : CCR0007775
    * Package      : xxd_wms_ftp_util_pkg
    * Description  : This package is used to transfer files from HJ Server to EBS
    *                and load the XML file data into respective staging tables
    * Notes        : File transfer and load into respective staging tables
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 26-Sep-2019  1.0         Kranthi Bollam          Initial Version
    --
    -- ===========  ========    ======================= =======================================
    ******************************************************************************************/

    gn_api_version_number      NUMBER := 1.0;
    gn_user_id                 NUMBER := fnd_global.user_id;
    gn_login_id                NUMBER := fnd_global.login_id;
    gn_request_id              NUMBER := fnd_global.conc_request_id;
    gn_program_id              NUMBER := fnd_global.conc_program_id;
    gn_program_appl_id         NUMBER := fnd_global.prog_appl_id;
    gn_resp_appl_id            NUMBER := fnd_global.resp_appl_id;
    gn_resp_id                 NUMBER := fnd_global.resp_id;
    gn_org_id                  NUMBER := fnd_profile.VALUE ('ORG_ID');
    gv_ship_confirm_msg_type   VARCHAR2 (30) := '720';

    PROCEDURE file_pull_push (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_organization IN VARCHAR2
                              , pv_entity IN VARCHAR2);

    PROCEDURE send_notification (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_notification_type IN VARCHAR2
                                 , pn_request_id IN NUMBER);

    PROCEDURE wait_for_request (pn_req_id IN NUMBER);

    FUNCTION get_email_ids (pv_lookup_type VARCHAR2)
        RETURN do_mail_utils.tbl_recips;

    PROCEDURE sc_upload_xml (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_inbound_directory IN VARCHAR2
                             , pv_file_name IN VARCHAR2);

    PROCEDURE sc_extract_xml_data (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_bulk_limit IN NUMBER
                                   , pv_file_name IN VARCHAR2);
END xxd_wms_ftp_util_pkg;
/
