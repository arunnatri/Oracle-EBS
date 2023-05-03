--
-- XXD_RETURN_PERIOD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_return_period_pkg
AS
    FUNCTION XXD_RETURN_QUARTER_func (pv_period_name VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION XXD_RETURN_first_period_func (pv_period_name VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION RETURN_QUARTER_DATE_func (pv_period_name VARCHAR2)
        RETURN DATE;

    FUNCTION RETURN_first_period_date_func (pv_period_name VARCHAR2)
        RETURN DATE;

    FUNCTION XXD_RETURN_PREV_PRD_FUNC (pv_period_name VARCHAR2)
        RETURN VARCHAR2;
END;
/
