--
-- XXDO_ICX_UTIL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_ICX_UTIL_PKG
AS
    /*******************************************************************************
    * Program Name : XXDO_ICX_UTIL_PKG
    * Language     : PL/SQL
    * Description  : This package will get org_id mapped to given project
    *
    * History      :
    *
    * WHO            WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * Swapna N          1.0 - Initial Version                         AUG/6/2014
    * --------------------------------------------------------------------------- */



    FUNCTION get_PROJECT_MAPPED_ORG_ID (p_project_Id IN VARCHAR2)
        RETURN VARCHAR2;
END XXDO_ICX_UTIL_PKG;
/
