--
-- XXD_GL_SBX_INT_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_SBX_INT_REP_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Deckers GL One Source Tax Report                                 *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  08-MAR-2021                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     18-MAR-2021  Srinath Siricilla     Initial Creation CCR0009103         *
   * 1.1     08-OCT-2021  Aravind Kannuri       Modified for CCR0009638             *
   * 1.1     12-OCT-2021  Showkath ALi          Modified for CCR0009638             *
      **********************************************************************************/
    PROCEDURE MAIN_PRC (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, --pn_org_id        IN            NUMBER,
                                                                                     pv_operating_unit IN VARCHAR2, --1.1
                                                                                                                    pv_company IN VARCHAR2, pv_period_from IN VARCHAR2, pv_period_to IN VARCHAR2
                        , pv_account IN VARCHAR2, pv_status IN VARCHAR2);

    FUNCTION get_ou_fnc (pv_comp IN VARCHAR2, pv_cc IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_ou_vat (pv_company IN VARCHAR2, pv_geo IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_ou_name_fnc (pv_comp IN VARCHAR2, pv_cc IN VARCHAR2)    --1.1
        RETURN VARCHAR2;

    -- Start Added for 1.1
    FUNCTION remove_junk_char (p_input IN VARCHAR2)
        RETURN VARCHAR2;
--End Added for 1.1

END XXD_GL_SBX_INT_REP_PKG;
/
