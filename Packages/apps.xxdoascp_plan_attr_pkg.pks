--
-- XXDOASCP_PLAN_ATTR_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOASCP_PLAN_ATTR_PKG"
AS
    FUNCTION xxdo_get_japan_intransit_time (p_category_id NUMBER)
        RETURN NUMBER;
END xxdoascp_plan_attr_pkg;
/
