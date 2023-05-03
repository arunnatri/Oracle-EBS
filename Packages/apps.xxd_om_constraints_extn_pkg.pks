--
-- XXD_OM_CONSTRAINTS_EXTN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OM_CONSTRAINTS_EXTN_PKG"
IS
    ----------------------------------------------------------------------------------------------
    -- Created By              : Mithun Mathew
    -- Creation Date           : 1-DEC-2016
    -- Program Name            : XXD_OM_CONSTRAINTS_EXTN_PKG.pks
    -- Description             : Custom Processing constraints
    -- Language                : PL/SQL
    -- Parameters              : Oracle setup expects below 6 input and 1 output parameters
    --                           by default and it has to be a procedure
    -- Revision History:
    -- ===========================================================================================
    -- Date               Version#    Name                  Remarks
    -- ===========================================================================================
    -- 01-DEC-2016       1.0         Mithun Mathew         Initial development (CCR0005788).
    -- 12-Sep-2017       1.1         Viswanathan Pandian   Updated for CCR0006634
    -- 02-Mar-2018       1.2         Viswanathan Pandian   Updated for CCR0006889
    -- 08-Apr-2020       1.3         Greg Jensen           Updated for CCR0008439
    -- 31-Aug-2020       1.4         Greg Jensen           Updated for CCR0008812
    -- 22-Oct-2020       1.5         Jayarajan AK          Updated for Brexit Changes CCR0009071
    -- 17-Mar-2021       1.6         Jayarajan AK          Modified for CCR0008870 - Global Inventory Allocation Project
    -- 17-Feb-2022       1.7         Mithun Mathew         Updated for CCR0009825
    -- ===========================================================================================

    G_DEBUG_MSG                   VARCHAR2 (2000);
    G_DEBUG_CALL                  NUMBER;
    G_BULK_WSH_INTERFACE_CALLED   BOOLEAN := FALSE;

    PROCEDURE reservation_exists_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                         , x_result_out OUT NOCOPY NUMBER);

    -- Start changes for CCR0006634
    PROCEDURE customer_closed_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                      , x_result_out OUT NOCOPY NUMBER);

    -- End changes for CCR0006634

    -- Start changes for CCR0006889
    PROCEDURE calloff_line_update_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                          , x_result_out OUT NOCOPY NUMBER);

    -- End changes for CCR0006889

    -- Start changes for  CCR0008439
    PROCEDURE customer_class_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                     , x_result_out OUT NOCOPY NUMBER);

    -- End changes for  CCR0008439

    -- Begin changes for CCR0008812
    PROCEDURE line_type_warehouse (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                   , x_result_out OUT NOCOPY NUMBER);

    -- End changes for CCR0008812

    --Start v1.5 Brexit changes for CCR0009071
    PROCEDURE brexit_org_map_hdr (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                  , x_result_out OUT NOCOPY NUMBER);

    PROCEDURE brexit_org_map_line (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                   , x_result_out OUT NOCOPY NUMBER);

    -- End v1.5 Brexit changes for CCR0009071

    -- Start changes for CCR0009825
    PROCEDURE orderdate_update_allowed (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                        , x_result_out OUT NOCOPY NUMBER);
-- End changes for CCR0009825

END XXD_OM_CONSTRAINTS_EXTN_PKG;
/
