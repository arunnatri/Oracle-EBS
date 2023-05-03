--
-- XXD_AR_CREDIT_APPL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_ar_credit_appl_pkg
IS
    /*******************************************************************************
* $Header$
* Program Name : XXD_AR_CREDIT_APPL_PKG.pks
* Language     : PL/SQL
* Description  :
* History      :
*
* WHO            WHAT                                    WHEN
* -------------- --------------------------------------- ---------------
* Jason Zhang    Original version.                       07-Jan-2015
*
*
*******************************************************************************/

    PROCEDURE send_mail_notification (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_from_date IN VARCHAR2
                                      , p_to_date IN VARCHAR2);
END xxd_ar_credit_appl_pkg;
/
