--
-- XXDO_FTP_WMS_FILES_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_FTP_WMS_FILES_PKG"
AS
    PROCEDURE main (p_out_var_errbuf OUT VARCHAR2, p_out_var_retcode OUT VARCHAR2, p_organization IN VARCHAR2
                    , p_entity IN VARCHAR2);
END xxdo_ftp_wms_files_pkg;
/
