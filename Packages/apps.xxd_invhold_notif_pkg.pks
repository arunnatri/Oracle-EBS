--
-- XXD_INVHOLD_NOTIF_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INVHOLD_NOTIF_PKG"
AS
    /*******************************************************************************
        * Program Name : StartProcess
        * Language     : PL/SQL
        * Description  : This procedure will start the hold notification workflow.
        *
        * History      :
        *
        * WHO            WHAT              Desc                             WHEN
        * -------------- ---------------------------------------------- ---------------
        * Krishna H      1.0                                              10-May-2015
        *******************************************************************************/
    PROCEDURE StartProcess (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_hold_id IN NUMBER
                            , p_invoice_id IN NUMBER);
END xxd_invhold_notif_pkg;
/
