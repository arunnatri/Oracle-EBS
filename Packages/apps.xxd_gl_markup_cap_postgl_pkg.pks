--
-- XXD_GL_MARKUP_CAP_POSTGL_PKG  (Package) 
--
--  Dependencies: 
--   FND_FLEX_VALUES_VL (View)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_MARKUP_CAP_POSTGL_PKG"
AS
    --  #########################################################################################################
    --  Package      : XXD_GL_MARKUP_CAP_POSTGL_PKG
    --  Design       : This package is used to capture the markup and post to GL.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  22-Mar-2020     1.0        Showkath Ali             Initial Version
    --  05-Aug-2010     1.1        Showkath Ali             UAT Defect -- New Changes
    --  28-Mar-2023     1.2        Thirupathi Gajula        CCR0010170 - Summarize the Interface/Journal records
    --  #########################################################################################################

    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_inventory_org IN NUMBER, p_org_id IN NUMBER, p_date_from IN VARCHAR2, p_date_to IN VARCHAR2, --p_transaction_id IN NUMBER, --1.1
                                                                                                                                                                p_from_transaction_id IN NUMBER, --1.1
                                                                                                                                                                                                 p_to_transaction_id IN NUMBER, --1.1
                                                                                                                                                                                                                                p_material_transaction_type IN NUMBER, p_reprocess IN VARCHAR2, -- 1.1
                                                                                                                                                                                                                                                                                                P_Enable_Recalculate IN VARCHAR2, p_recalculate IN VARCHAR2
                    ,                                                    --1.1
                      p_calc_currency IN VARCHAR2,                       --1.2
                                                   p_rate_type IN VARCHAR2 --1.2
                                                                          );

    TYPE source_rec IS RECORD
    (
        source    fnd_flex_values_vl.flex_value%TYPE
    );

    TYPE source_tbl IS TABLE OF source_rec;

    FUNCTION get_source_val_fnc
        RETURN source_tbl
        PIPELINED;
END XXD_GL_MARKUP_CAP_POSTGL_PKG;
/
