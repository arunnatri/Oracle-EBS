--
-- XXD_VT_CONSOLIDATED_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_VT_CONSOLIDATED_PKG"
IS
    /***********************************************************************************
    *$header :                                                                         *
    *                                                                                  *
    * AUTHORS :Suraj Valluri                                                           *
    *                                                                                  *
    * PURPOSE : Deckers Virtual Tax Consolidated Report                                *
    *                                                                                  *
    * PARAMETERS :                                                                     *
    *                                                                                  *
    * DATE : 18-MAR-2021                                                               *
    *                                                                                  *
    * Assumptions:                                                                     *
    *                                                                                  *
    *                                                                                  *
    * History                                                                          *
    * Vsn    Change Date Changed By          Change Description                        *
    * ----- ----------- ------------------ ------------------------------------        *
    * 1.0    18-MAR-2021 Suraj Valluri       Initial Creation CCR0009031               *
    * 1.1    30-NOV-2021 Srinath Siricilla   CCR0009638 -Redesign and UAT Changes      *
    ***********************************************************************************/

    --variables declaration
    gn_user_id      CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id     CONSTANT NUMBER := fnd_global.login_id;
    gd_date         CONSTANT DATE := SYSDATE;
    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;

    PROCEDURE MAIN (errbuf                   OUT VARCHAR2,
                    retcode                  OUT VARCHAR2,
                    p_invoice_date_from   IN     VARCHAR2,
                    p_invoice_date_to     IN     VARCHAR2,
                    p_gl_date_from        IN     VARCHAR2,
                    p_gl_date_to          IN     VARCHAR2,
                    p_posting_status      IN     VARCHAR2,
                    pv_final_mode         IN     VARCHAR2);

    -- Added as per CCR0009638
    FUNCTION remove_junk_fnc (pv_data IN VARCHAR2)
        RETURN VARCHAR2;
END XXD_VT_CONSOLIDATED_PKG;
/
