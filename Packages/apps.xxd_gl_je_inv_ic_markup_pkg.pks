--
-- XXD_GL_JE_INV_IC_MARKUP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_JE_INV_IC_MARKUP_PKG"
IS
    /******************************************************************************************
     NAME           : XXD_GL_JE_INV_IC_MARKUP_PKG
     Desc           : Deckers Inventory IC Markup for Onhand Journal Creation Program

     REVISIONS:
     Date        Author             Version  Description
     ---------   ----------         -------  ---------------------------------------------------
     06-MAR-2023 Thirupathi Gajula  1.0      Created this package XXD_GL_JE_INV_IC_MARKUP_PKG
                                             for Inventory IC Markup GL Journal Import
    *********************************************************************************************/
    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, p_as_of_date IN VARCHAR2, p_inv_org_id IN NUMBER, p_region IN VARCHAR2, p_brand IN VARCHAR2, p_markup_calc_cur IN VARCHAR2, p_onhand_jour_cur IN VARCHAR2, p_rate_type IN VARCHAR2
                        , p_jl_rate_type IN VARCHAR2, p_type IN VARCHAR2);
END xxd_gl_je_inv_ic_markup_pkg;
/
