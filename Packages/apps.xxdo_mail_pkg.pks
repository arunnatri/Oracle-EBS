--
-- XXDO_MAIL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_MAIL_PKG"
    AUTHID CURRENT_USER
IS
    -------------------------------------------------------------------------------
    -- TYPE      : Package Specification                                 --
    -- NAME      : xxdo_mail_pkg.spc                                                 --
    -- PURPOSE   : Contains common utilities to send email, spool query              --
    --             and notify exceptions                               --
    --                                                                               --
    -- Modification History:                                                         --
    -----------------------------------------------------------------------------    --
    -- Date          Developer     Version         Description                       --
    -- -----------   -----------   ------------    ----------------                  --
    -- 01/09/2013    Infosys       1.0             Initial version                   --
    -- 10/01/2022    Balavenu      2.0             Added Global Variables CCR0009135--
    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Type  : Procedure       --
    -- Name  : SEND_MAIL       --
    -- Purpose    : Wrapper for sending email     --
    --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description     --
    -- -----------------------  ---------------------------------------------------
    -- pv_sender                SMTP Connection     --
    -- pv_recipients            Email recipient list, separated by "," or ";" --
    -- pv_ccrecipients          CC Email recipient list, separated by "," or ";" --
    -- pv_subject               Email subject     --
    -- pv_message               Email message text    --
    -- pv_attachments           Full path and filename for attachments, multiple --
    --                          separated by "," or ";"    --
    -- xv_result                SUCCESS/FAILURE result    --
    -- xv_result_msg            Result message     --
    -------------------------------------------------------------------------------
    --Start 2.0 CCR0009135
    pv_smtp_host     VARCHAR2 (256);
    pv_smtp_port     PLS_INTEGER;
    pv_smtp_domain   VARCHAR2 (256);

    --End 2.0 CCR0009135

    PROCEDURE send_mail (pv_sender         IN     VARCHAR2,
                         pv_recipients     IN     VARCHAR2,
                         pv_ccrecipients   IN     VARCHAR2,
                         pv_subject        IN     VARCHAR2,
                         pv_message        IN     VARCHAR2,
                         pv_attachments    IN     VARCHAR2,
                         xv_result            OUT VARCHAR2,
                         xv_result_msg        OUT VARCHAR2);

    -------------------------------------------------------------------------------
    -- Type     : Procedure                            --
    -- Name     : SEND_EMAIL_WRAPPER                            --
    -- Purpose    : Wrapper for sending email                  --
    --
    -------------------------------------------------------------------------------
    -- Parameter Name           Description
    -- -----------------------  ---------------------------------------------------
    -- xv_errbuf               Result message                 --
    -- xn_retcode            Result code                    --
    -- pv_sender                SMTP Connection                    --
    -- pv_recipients            Email recipient list, separated by "," or ";"    --
    -- pv_ccrecipients          Email CC recipient list, separated by "," or ";"    --
    -- pv_subject               Email subject                    --
    -- pv_message               Email message text                --
    -- pv_attachments           Full path and filename for attachments, multiple --
    --                          separated by "," or ";"                --
    -- pn_request_id         Request Id of the concurrent program after which send mail
    --                               will send email
    --                                                                           --
    -- Modification History                                                      --
    -------------------------------------------------------------------------------
    -- Date      Developer      Version      Description                  --
    -- ----------   -----------     ------------    -------------------------------
    -- 03/15/2013   Infosys      1.0          Initial Version            --
    -------------------------------------------------------------------------------
    PROCEDURE send_email_wrapper (
        xv_errbuf             OUT VARCHAR2,
        xn_retcode            OUT NUMBER,
        pv_sender          IN     VARCHAR2,
        pv_recipients      IN     VARCHAR2,
        pv_ccrecipients    IN     VARCHAR2,
        pv_subject         IN     VARCHAR2,
        pv_message         IN     VARCHAR2,
        pv_attachments     IN     VARCHAR2,
        pn_request_id      IN     NUMBER,
        pv_override_file   IN     VARCHAR2 DEFAULT NULL);

    /*
     -------------------------------------------------------------------------------
     -- Type     : Procedure                            --
     -- Name     : SEND_MAIL_AFTER_REQUEST                            --
     -- Purpose    : Wrapper for sending email after a request completes                 --
     --
     -------------------------------------------------------------------------------
     -- Parameter Name           Description
     -- -----------------------  ---------------------------------------------------
     -- pv_sender                SMTP Connection                    --
     -- pv_recipients            Email recipient list, separated by "," or ";"    --
     -- pv_ccrecipients          Email CC recipient list, separated by "," or ";"    --
     -- pv_subject               Email subject                    --
     -- pv_message               Email message text                --
     -- pv_attachments           Full path and filename for attachments, multiple --
     --                          separated by "," or ";"                --
     -- pn_request_id         Request Id of the concurrent program after which send mail
     --                               will send email
     -- pv_override_fn           To change attachment file name
     -- xv_result                SUCCESS/FAILURE result                --
     -- xv_result_msg            Result message                    --
     --                                                                           --
     -- Modification History                                                      --
     -------------------------------------------------------------------------------
     -- Date      Developer      Version      Description                  --
     -- ----------   -----------     ------------    -------------------------------
     -- 01/08/2013   Infosys      1.0          Initial Version            --
     -------------------------------------------------------------------------------
   PROCEDURE send_mail_after_request
     (
       pv_sender       IN VARCHAR2,
       pv_recipients   IN VARCHAR2,
       pv_ccrecipients IN VARCHAR2,
       pv_subject      IN VARCHAR2,
       pv_message      IN VARCHAR2,
       pv_attachments  IN VARCHAR2,
       pn_request_id   IN NUMBER,
       xv_result OUT VARCHAR2,
       xv_result_msg OUT VARCHAR2); */
    PROCEDURE send_mail_after_request (pv_sender IN VARCHAR2, pv_recipients IN VARCHAR2, pv_ccrecipients IN VARCHAR2, pv_subject IN VARCHAR2, pv_message IN VARCHAR2, pv_attachments IN VARCHAR2, pn_request_id IN NUMBER, pv_override_fn IN VARCHAR2 DEFAULT NULL, xv_result OUT VARCHAR2
                                       , xv_result_msg OUT VARCHAR2);
END xxdo_mail_pkg;
/
