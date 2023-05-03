--
-- XXDO_PURGING_STAGING_TABLE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PURGING_STAGING_TABLE_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  XXDO_PURGING_STAGING_TABLE_PKG.sql   1.0    2015/09/02    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  XXDO_PURGING_STAGING_TABLE_PKG
    --
    -- Description  :  This is package  for purging staging table
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 02-Sep-2015    Infosys            1.0       Created
    -- ***************************************************************************

    PROCEDURE main (p_error_buf OUT VARCHAR2, p_ret_code OUT NUMBER, p_table_name IN VARCHAR2
                    , p_to_email_id IN VARCHAR2, p_mode IN VARCHAR2);
END XXDO_PURGING_STAGING_TABLE_PKG;
/
