--
-- XXD_IR_ISO_ALERT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_IR_ISO_ALERT_PKG"
    AUTHID CURRENT_USER
/****************************************************************************************
* Package : XXD_IR_ISO_ALERT_PKG
* Author : BT Technology Team
* Created : 23-APR-2016
* Program Name : Deckers Alert For IR ISO
*
* Modification :
*--------------------------------------------------------------------------------------
* Date Developer Version Description
*--------------------------------------------------------------------------------------
* 23-APR-2016 BT Technology Team 1.00 Created package script
***********************************************************************************/
AS
    --------------------------------------------------------------------------------------
    -- Main Procedure to send email
    --------------------------------------------------------------------------------------
    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2);
END XXD_IR_ISO_ALERT_PKG;
/
