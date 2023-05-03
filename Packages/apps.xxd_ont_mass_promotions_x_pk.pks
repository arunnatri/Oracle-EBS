--
-- XXD_ONT_MASS_PROMOTIONS_X_PK  (Package) 
--
--  Dependencies: 
--   XXD_ONT_MASS_PROMOTIONS_STG_T (Table)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_MASS_PROMOTIONS_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_MASS_PROMOTIONS_X_PK
    * Design       : This package is used for mass reprice and promotion data update
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 13-Apr-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN appsro.xxd_ont_mass_promotions_stg_t.org_id%TYPE
                         , p_brand IN appsro.xxd_ont_mass_promotions_stg_t.brand%TYPE, p_threads IN NUMBER, p_run_id IN NUMBER);

    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN appsro.xxd_ont_mass_promotions_stg_t.org_id%TYPE
                          , p_brand IN appsro.xxd_ont_mass_promotions_stg_t.brand%TYPE, p_threads IN NUMBER);
END xxd_ont_mass_promotions_x_pk;
/
