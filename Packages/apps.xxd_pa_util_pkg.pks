--
-- XXD_PA_UTIL_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PA_UTIL_PKG"
AS
    /****************************************************************************************
    * Change#      : CCR0008074
    * Package      : XXD_PA_UTIL_PKG
    * Description  : Projects Utility Package (Created for CCR0008074)
    * Notes        :
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 25-Jul-2019  1.0         Kranthi Bollam          Initial Version
    --
    -- ===========  ========    ======================= =======================================
    ******************************************************************************************/
    gn_api_version_number   NUMBER := 1.0;
    gn_user_id              NUMBER := fnd_global.user_id;
    gn_login_id             NUMBER := fnd_global.login_id;
    gn_request_id           NUMBER := fnd_global.conc_request_id;
    gn_program_id           NUMBER := fnd_global.conc_program_id;
    gn_program_appl_id      NUMBER := fnd_global.prog_appl_id;
    gn_resp_appl_id         NUMBER := fnd_global.resp_appl_id;
    gn_resp_id              NUMBER := fnd_global.resp_id;
    gn_org_id               NUMBER := fnd_profile.VALUE ('ORG_ID');

    FUNCTION get_cip_cca_account (pn_project_id IN NUMBER DEFAULT NULL, pn_task_id IN NUMBER DEFAULT NULL, pn_expenditure_item_id IN NUMBER DEFAULT NULL)
        RETURN VARCHAR2;
END xxd_pa_util_pkg;
/
