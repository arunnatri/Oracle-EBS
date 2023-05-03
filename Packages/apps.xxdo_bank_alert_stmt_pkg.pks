--
-- XXDO_BANK_ALERT_STMT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_BANK_ALERT_STMT_PKG"
AS
    /*
       ********************************************************************************************************************************
       **                                                                                                                             *
       **    Author          : Infosys                                                                                                *
       **    Created         : 25-OCT-2016                                                                                            *
       **    Description     : This package is used to send notification to mailer for bank account statement not generated           *
       **                                                                                                                             *
       **History         :                                                                                                            *
       **------------------------------------------------------------------------------------------                                   *
       **Date        Author                        Version Change Notes                                                               *
       **----------- --------- ------- ------------------------------------------------------------                                   */


    /*********************************************************************************************************************
    * Type                : Procedure                                                                                    *
    * Name                : create_bank_stmt_alert                                                                       *
    * Purpose             : To Fectch bank accounts data for no statement generated and Send Mail to the Users           *
    *********************************************************************************************************************/
    PROCEDURE create_bank_stmt_alert (errbuf                OUT VARCHAR2,
                                      retcode               OUT VARCHAR2,
                                      p_i_from_emailid   IN     VARCHAR2,
                                      p_subject          IN     VARCHAR2,
                                      p_date             IN     VARCHAR2);

    /*********************************************************************************************************************
  * Type                : Procedure                                                                                    *
  * Name                : send_mail                                                                                      *
  * Purpose             : To Send Mail to the Users                                          *
  *********************************************************************************************************************/
    PROCEDURE send_mail (p_i_from_email    IN     VARCHAR2,
                         p_i_to_email      IN     VARCHAR2,
                         p_i_mail_format   IN     VARCHAR2 DEFAULT 'TEXT',
                         p_i_mail_server   IN     VARCHAR2,
                         p_i_subject       IN     VARCHAR2,
                         p_i_mail_body     IN     CLOB DEFAULT NULL,
                         p_o_status           OUT VARCHAR2,
                         p_o_error_msg        OUT VARCHAR2);
END XXDO_BANK_ALERT_STMT_PKG;
/
