--
-- XXD_SO_DOC_ATTACHMENTS_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_SO_DOC_ATTACHMENTS_PKG"
AS
    -- +==============================================================================+
    -- +                        Deckers BT Oracle 12i                                 +
    -- +==============================================================================+
    -- |                                                                              |
    -- |CVS ID:   1.1                                                                 |
    -- |Name:                                                                         |
    -- |Creation Date: 27-AUG-2015                                                    |
    -- |Application Name: Deckers Conversion Application                              |
    -- |Source File Name: XXD_SO_DOC_ATTACHMENTS_PKG.sql                         |
    -- |                                                                              |
    -- |Object Name :   XXD_SO_DOC_ATTACHMENTS_PKG                               |
    -- |Description   : The package  is defined to convert the                        |
    -- |                Deckers SO Document Attachments                                             |
    -- |                Conversion to R12                                             |
    -- |                                                                              |
    -- |Usage:                                                                        |
    -- |                                                                              |
    -- |Parameters   :                                                                |
    -- |                p_debug          -- Debug Flag                                  |
    -- |                                                                              |
    -- |                                                                              |
    -- |                                                                              |
    -- |Change Record:                                                                |
    -- |===============                                                               |
    -- |Version   Date             Author             Remarks                              |
    -- |=======   ==========  ===================   ============================      |
    -- |DRAFT 1A  27-AUG-2015                        Initial draft version            |
    -- +==============================================================================+
    gc_debug_flag                 VARCHAR2 (10) := 'N';
    gn_user_id                    NUMBER := FND_GLOBAL.USER_ID;
    gn_login_id                   NUMBER := FND_GLOBAL.CONC_LOGIN_ID;
    gn_request_id                 NUMBER := FND_GLOBAL.CONC_REQUEST_ID;


    gc_validate_status   CONSTANT VARCHAR2 (20) := 'VALIDATED';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'ERROR';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'NEW';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'PROCESSED';
    gc_interfaced        CONSTANT VARCHAR2 (20) := 'INTERFACED';


    /*********************************************************************************************
    *                                                                                            *
    * Function  Name       :  so_doc_attachment_main                                             *
    *                                                                                            *
    * Description          :                                                                     *
    *                                                                                            *
    *                                                                                            *
    *                                                                                            *
    * Change History                                                                             *
    * -----------------                                                                          *
    * Version       Date            Author                 Description                           *
    * -------       ----------      -----------------      ---------------------------           *
    * Draft1a      04-APR-2011     Phaneendra Vadrevu     Initial creation                       *
    *                                                                                            *
    **********************************************************************************************/



    PROCEDURE so_doc_attachment_main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_debug IN VARCHAR2);
END XXD_SO_DOC_ATTACHMENTS_PKG;
/
