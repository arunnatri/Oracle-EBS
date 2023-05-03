--
-- XXDO_HJ_CONSTRAINTS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_HJ_CONSTRAINTS_PKG"
IS
    G_DEBUG_MSG                   VARCHAR2 (2000);
    G_DEBUG_CALL                  NUMBER;
    G_BULK_WSH_INTERFACE_CALLED   BOOLEAN := FALSE;   -- ADDED FOR BUG 4070931

    PROCEDURE validate_release_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                       , x_result_out OUT NOCOPY NUMBER);
END xxdo_hj_constraints_pkg;
/
