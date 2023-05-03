--
-- XXDOGL_BAL_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOGL_BAL_EXTRACT_PKG"
AS
    /******************************************************************************
       NAME: XXDOGL_BAL_EXTRACT_PKG
       REP NAME:GL Balance Extract for Hyperion - Deckers
       This data Extract if for HYPERION budgeting tool.

       REVISIONS:
       Ver        Date        Author                   Description
       ---------  ----------  ---------------          ------------------------------------
       1.0       07/25/2011     Shibu            1. Created this package for GL XXDOGL003 Report
    ******************************************************************************/
    PROCEDURE populate_data_file (p_errbuf           OUT VARCHAR2,
                                  p_retcode          OUT VARCHAR2,
                                  p_period_name   IN     VARCHAR2,
                                  p_final         IN     VARCHAR2,
                                  p_output_loc    IN     VARCHAR2);
END xxdogl_bal_extract_pkg;
/


--
-- XXDOGL_BAL_EXTRACT_PKG  (Synonym) 
--
--  Dependencies: 
--   XXDOGL_BAL_EXTRACT_PKG (Package)
--
CREATE OR REPLACE SYNONYM XXDO.XXDOGL_BAL_EXTRACT_PKG FOR APPS.XXDOGL_BAL_EXTRACT_PKG
/
