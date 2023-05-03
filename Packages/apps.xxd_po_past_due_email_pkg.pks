--
-- XXD_PO_PAST_DUE_EMAIL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_PAST_DUE_EMAIL_PKG"
AS
    /****************************************************************************************
       * Package      : XXD_PO_PAST_DUE_EMAIL_PKG
       * Design       : This package is used to send email as Zip file to after concurrent program
                        sent data to oracle directory
       * Notes        :
       * Modification :
       -- ===============================================================================
       -- Date         Version#   Name                    Comments
       -- ===============================================================================
       -- 08-AUG-2021  1.0        Srinath Siricilla      Initial Version
       ******************************************************************************************/
    FUNCTION file_to_blob_fnc (pv_directory_name   IN VARCHAR2,
                               pv_file_name        IN VARCHAR2)
        RETURN BLOB;

    PROCEDURE save_zip_prc (pb_zipped_blob     IN BLOB,
                            pv_dir             IN VARCHAR2,
                            pv_zip_file_name   IN VARCHAR2);

    PROCEDURE create_final_zip_prc (pv_directory_name IN VARCHAR2, pv_file_name IN VARCHAR2, pv_zip_file_name IN VARCHAR2);

    PROCEDURE zip_email_file_prc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER, pn_request_id IN NUMBER
                                  , pv_directory IN VARCHAR2, pv_file_name IN VARCHAR2, pv_zip_file_name IN VARCHAR2);
END XXD_PO_PAST_DUE_EMAIL_PKG;
/
