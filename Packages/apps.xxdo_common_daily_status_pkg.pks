--
-- XXDO_COMMON_DAILY_STATUS_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   UTL_SMTP (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_COMMON_DAILY_STATUS_PKG"
AS
    /*********************************************************************************************
    -- Package Name :  XXDO_COMMON_DAILY_STATUS_PKG
    --
    -- Description  :  This is package  for generating query for daily status report
    --
    -- Date          Author                     Version  Description
    -- ------------  -----------------          -------  --------------------------------
    -- 06-AUG-15     Infosys                    1.0      Created
    -- 29-Aug-2022   Viswanathan Pandian        1.1      Updated for CCR0010179
    -- ******************************************************************************************/
    g_num_api_version       NUMBER := 1.0;
    g_num_user_id           NUMBER := fnd_global.user_id;
    g_num_login_id          NUMBER := fnd_global.login_id;
    g_num_request_id        NUMBER := fnd_global.conc_request_id;
    g_num_program_id        NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id   NUMBER := fnd_global.prog_appl_id;
    g_num_org_id            NUMBER := fnd_profile.VALUE ('ORG_ID');
    g_smtp_connection       UTL_SMTP.connection := NULL;
    g_num_connection_flag   NUMBER := 0;

    PROCEDURE main (p_error_buf OUT VARCHAR2, p_ret_code OUT NUMBER, p_track VARCHAR2
                    ,                                  -- Added for CCR0010179
                      in_query_id NUMBER);
END xxdo_common_daily_status_pkg;
/
