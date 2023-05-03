--
-- XXDO_SOX_ALERT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdo_sox_alert_pkg
    AUTHID CURRENT_USER
/****************************************************************************************
* Package : XXDO_SOX_ALERT_PKG
* Author : BT Technology Team
* Created : 30-OCT-2014
* Program Name : Deckers Alert For Large Unusual SOX Transactions
* Description : Package having all the functions used for the SOX alert
*
* Modification :
*--------------------------------------------------------------------------------------
* Date Developer Version Description
*--------------------------------------------------------------------------------------
* 30-OCT-2014 BT Technology Team 1.00 Created package script
* 04-FEB-2015 BT Technology Team 1.10 Added main procedure
***********************************************************************************/
AS
    --------------------------------------------------------------------------------------
    -- Function to check if journal has control account in any of the lines
    --------------------------------------------------------------------------------------
    FUNCTION xxd_alert_gl_header_fnc (p_gl_header_id IN NUMBER)
        RETURN VARCHAR2;

    --------------------------------------------------------------------------------------
    -- Function to retrieve email id for primary and secondary ledger
    --------------------------------------------------------------------------------------
    FUNCTION xxd_primary_secondary_email (p_header_id IN NUMBER)
        RETURN VARCHAR2;

    --------------------------------------------------------------------------------------
    -- Function to convert currencies to equivalent of USD
    --------------------------------------------------------------------------------------
    FUNCTION xxd_gl_conversion_rate (p_header_id IN NUMBER, p_from_currency IN VARCHAR2, p_total_amount IN FLOAT)
        RETURN FLOAT;

    --------------------------------------------------------------------------------------
    -- Function to return 'Y' or 'N' depending on the ledger type
    --------------------------------------------------------------------------------------
    FUNCTION xxd_check_gl_ledger (p_header_id IN NUMBER)
        RETURN VARCHAR2;

    --------------------------------------------------------------------------------------
    -- Function to return last_updated_by and created_by
    --------------------------------------------------------------------------------------
    FUNCTION xxd_created_updated_by (p_name        IN VARCHAR2,
                                     p_header_id   IN NUMBER)
        RETURN VARCHAR2;

    --------------------------------------------------------------------------------------
    -- Main Procedure to send email
    --------------------------------------------------------------------------------------
    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2);
END xxdo_sox_alert_pkg;
/
