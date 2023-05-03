--
-- XXDO_PO_ACCT_SEGMENT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PO_ACCT_SEGMENT_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Restricting Natual Accounts in IProcurement                      *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  01-MAY-2017                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     01-MAY-2017  Srinath Siricilla     Initial Creation                    *
      * 1.1     21-MAY-2018  Srinath Siricilla     CCR0007253                          *                                                                                *
      *                                                                                *
      *********************************************************************************/
    FUNCTION get_natural_segment (p_project_id IN NUMBER, p_task_id IN NUMBER, p_expenditure_type IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_non_proj_acct_segment (p_unit_price      IN NUMBER,
                                        p_category_id     IN NUMBER,
                                        p_requestor_id    IN NUMBER,
                                        p_currency_code   IN VARCHAR2,
                                        p_org_id          IN NUMBER)
        RETURN VARCHAR2;

    -- Changes as part of CCR0007253

    FUNCTION validate_cost_center_seg (pn_requester_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_supervisor_id (Pn_requester_id IN NUMBER)
        RETURN NUMBER;
-- End of change for CCR0007253


END XXDO_PO_ACCT_SEGMENT_PKG;
/
