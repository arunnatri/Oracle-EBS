--
-- XXD_GL_JE_UPLOAD_IB_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_JE_UPLOAD_IB_PKG"
IS
    /*******************************************************************************************
     NAME           : XXD_GL_JE_UPLOAD_IB_PKG
     REPORT NAME    : Deckers GL Journal Automation Inbound program

     REVISIONS:
     Date        Author             Version  Description
     ----------  ----------         -------  ---------------------------------------------------
     05-SEP-2022 Thirupathi Gajula  1.0      Created this package XXD_GL_JE_UPLOAD_IB_PKG for
                                             validate GL Journal data and send it to GL Interface
    *********************************************************************************************/
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;

    PROCEDURE main_prc (errbuf       OUT NOCOPY VARCHAR2,
                        retcode      OUT NOCOPY VARCHAR2);
END XXD_GL_JE_UPLOAD_IB_PKG;
/
