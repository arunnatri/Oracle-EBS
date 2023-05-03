--
-- XXDO_PO_CLOSE_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PO_CLOSE_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  XXDO_PO_CLOSE_PKG.sql   1.0    2016/05/03    10:00:00   Bala Murugesan $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  XXDO_PO_CLOSE_PKG
    --
    -- Description  :  This package is to close the PO line
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 03-May-16    Bala Murugesan            1.0       Created
    -- ***************************************************************************


    g_num_api_version       NUMBER := 1.0;
    g_num_user_id           NUMBER := fnd_global.user_id;
    g_num_login_id          NUMBER := fnd_global.login_id;
    g_num_request_id        NUMBER := fnd_global.conc_request_id;
    g_num_program_id        NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id   NUMBER := fnd_global.prog_appl_id;
    g_num_org_id            NUMBER := fnd_profile.VALUE ('ORG_ID');



    PROCEDURE close_po_lines (pv_errbuf    OUT VARCHAR2,
                              pv_retcode   OUT VARCHAR2);
END XXDO_PO_CLOSE_PKG;
/
