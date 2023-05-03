--
-- XXD_FA_CIP_ROLL_FWD_REPORT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FA_CIP_ROLL_FWD_REPORT_PKG"
AS
    /***********************************************************************************
     *$header :                                                                        *
     *                                                                                 *
     * AUTHORS : Infosys                                                               *
     *                                                                                 *
     * PURPOSE : Used CIP Reports                                                      *
     *                                                                                 *
     * PARAMETERS :                                                                    *
     *                                                                                 *
     * DATE : 16-Sep-2016                                                              *
     *                                                                                 *
     * History      :                                                                  *
     *                                                                                 *
     * =============================================================================== *
     * Who                   Version    Comments                          When         *
     * Infosys               1.1        Change as part of CCR0007020      08-MAY-2018  *
     * Showkath              1.2        Change as part of CCR0008086      20-AUG-2019  *
     * Aravind Kannuri       1.3        Change as part of CCR0007965      19-NOV-2019  *
     * =============================================================================== *
     **********************************************************************************/

    g_from_currency   VARCHAR2 (3) DEFAULT 'USD';
    g_to_currency     VARCHAR2 (3) DEFAULT 'USD';

    --START Added as per version 1.3
    PROCEDURE get_project_cip_dtls_prc (p_book           IN VARCHAR2,
                                        p_currency       IN VARCHAR2,
                                        p_from_period    IN VARCHAR2,
                                        p_to_period      IN VARCHAR2,
                                        p_project_type   IN VARCHAR2);

    --END Added as per version 1.3

    --START Commented as per version 1.3
    /*
    PROCEDURE get_project_cip_prc (p_book                  IN     VARCHAR2,
                                  p_currency              IN     VARCHAR2,
                                  p_from_period           IN     VARCHAR2,
                                  p_to_period             IN     VARCHAR2,
                                  p_project_type     IN     VARCHAR2 -- CCR0008086
                                 );
    */
    --END Commented as per version 1.3

    PROCEDURE main_detail (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_book IN VARCHAR2, p_currency IN VARCHAR2, p_from_period IN VARCHAR2, p_to_period IN VARCHAR2
                           , p_project_type IN VARCHAR2          -- CCR0008086
                                                       );

    PROCEDURE print_log_prc (p_msg IN VARCHAR2);
END;
/
