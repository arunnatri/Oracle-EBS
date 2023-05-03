--
-- XXDO_PO_UTIL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_PO_UTIL_PKG
AS
    /*******************************************************************************
    * Program Name : XXDO_PO_UTIL_PKG
    * Language     : PL/SQL
    * Description  : This package will get org_id mapped to given project
    *
    * History      :
    *
    * WHO            WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * Swapna N          1.0 - Initial Version                         AUG/6/2014
    * --------------------------------------------------------------------------- */



    FUNCTION IS_REL_NOT_IN_PROJECT_BUDGET (P_PO_release_ID IN NUMBER)
        RETURN VARCHAR2;                   -- New function added by Siddhartha

    FUNCTION IS_PO_NOT_IN_PROJECT_BUDGET (P_PO_HEADER_ID IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_Project_approved_amt (p_project_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_po_amount_for_project (p_project_id IN NUMBER, p_po_header_id IN NUMBER, p_proj_currency IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_project_expenditure_amt (p_project_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_project_commitment_amt (p_project_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_rel_amount_for_project (p_project_id IN NUMBER, p_po_release_id IN NUMBER, p_proj_currency IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION IS_REQ_NOT_IN_PROJECT_BUDGET (P_REQ_HEADER_ID IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_req_amount_for_project (p_project_id IN NUMBER, p_req_header_id IN NUMBER, p_proj_currency IN VARCHAR2)
        RETURN NUMBER;
END XXDO_PO_UTIL_PKG;
/
