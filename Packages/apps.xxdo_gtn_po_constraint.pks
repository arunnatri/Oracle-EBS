--
-- XXDO_GTN_PO_CONSTRAINT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_GTN_PO_CONSTRAINT"
IS
    TYPE Profile_type IS RECORD
    (
        oe_source_code    VARCHAR2 (240),
        user_id           NUMBER,
        login_id          NUMBER,
        request_id        NUMBER,
        application_id    NUMBER,
        program_id        NUMBER
    );

    profile_values   Profile_type;

    PROCEDURE Check_PO_Approved (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_tmplt_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                 , p_result OUT NOCOPY /* file.sql.39 change */
                                                      NUMBER);
END;
/
