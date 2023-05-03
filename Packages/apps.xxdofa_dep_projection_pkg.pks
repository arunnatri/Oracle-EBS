--
-- XXDOFA_DEP_PROJECTION_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOFA_DEP_PROJECTION_PKG"
AS
    /******************************************************************************
       NAME:       XXDOFA_DEP_PROJECTION_PKG
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        6/03/2008     Shibu                  Created this package for
                                                      FA Depriciation Projection Process
       1.1        28/08/2014    BT TechnologyTeam     Retrofit for BT project
       1.2          05/01/2015    BT TechnologyTeam     Added code for "CIP Depreciation
                                                      Projection Section" in the report
       1.3          26/11/2015    BT TechnologyTeam     Added code for "CIP Depreciation
                                                      Projection Section" in the report
                                                      to calculate Depreciation amount.
    **********************************************************************************/

    p_cal             VARCHAR2 (20);
    p_periods         VARCHAR2 (10);
    p_per_start       VARCHAR2 (10);
    p_book            VARCHAR2 (60);
    g_proj_req_id     NUMBER;
    g_table           VARCHAR2 (100);
    p_currency        VARCHAR2 (60); -- Added by BT Technology Team on 28-Aug-2014 - v1.1
    g_dummy_table     VARCHAR2 (100); -- Added by BT Technology Team on 28-Aug-2014 - v1.1
    v_where_period    VARCHAR2 (4000); -- Added by BT Technology Team on 05-Jan-2015 - V1.2

    --                                                                      |
    -- Report Lexical Parameters                                            |
    --                                                                      |
    --======================================================================+
    P_SQL_STATEMENT   VARCHAR2 (32000);

    FUNCTION fa_projection_process (p_cal         IN VARCHAR2,
                                    p_periods     IN VARCHAR2,
                                    p_per_start   IN VARCHAR2,
                                    p_book        IN VARCHAR2,
                                    p_currency    IN VARCHAR2 --Added by BT Technology Team on 28-Aug-2014  - v1.1
                                                             )
        RETURN BOOLEAN;


    --------------------------------------------------------------------------------------
    -- Start of Changes by BT Technology Team on 05-Jan-2015 - V1.2
    --------------------------------------------------------------------------------------
    FUNCTION fa_period_range (p_period_name VARCHAR2, p_num_period NUMBER)
        RETURN VARCHAR2;

    --------------------------------------------------------------------------------------
    -- Start of Changes by BT Technology Team on 05-Jan-2015 - V1.2
    --------------------------------------------------------------------------------------
    --------------------------------------------------------------------------------------
    -- End of Changes by BT Technology Team on 26-Nov-2015 - V1.3
    --------------------------------------------------------------------------------------
    FUNCTION cip_depreciation_amount (p_estimated_service_date DATE, p_life_month NUMBER, p_period_name VARCHAR2
                                      , p_estimated_cost NUMBER, p_book VARCHAR2, p_category_id NUMBER)
        RETURN NUMBER;

    --------------------------------------------------------------------------------------
    -- End of Changes by BT Technology Team on 26-Nov-2015 - V1.3
    --------------------------------------------------------------------------------------

    FUNCTION fa_beforereport
        RETURN BOOLEAN;

    --Start changes by BT Technology Team on 28-Aug-2014  - v1.1
    --Function fa_afterreport(g_table Varchar2) Return boolean;
    FUNCTION fa_afterreport (g_dummy_table VARCHAR2)
        RETURN BOOLEAN;
--End changes by BT Technology Team on 28-Aug-2014  - v1.1

END XXDOFA_DEP_PROJECTION_PKG;
/
