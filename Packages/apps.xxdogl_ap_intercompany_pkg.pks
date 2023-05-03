--
-- XXDOGL_AP_INTERCOMPANY_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOGL_AP_INTERCOMPANY_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Madhav Dhurjaty                                                  *
      *                                                                                *
      * PURPOSE    :  AP Intercompany GL Interface Utility - Deckers                   *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE     :    13-Jan-2013                                                      *
      *                                                                                *
      * Assumptions :                                                                  *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By          Change Description                    *
      * -----   -----------  ------------------  ------------------------------------- *
      * 1.0     13-Jan-2013  Madhav Dhurjaty      Initial Creation                     *
      * 1.1     17-Jan-2013  Madhav Dhurjaty      Created function 'check_debit_ccid', *
      *                                           Modified procedures print_output,    *
      *                                           insert_staging, validate_staging per *
      *                                           Alex's QA testing comments           *
      * 1.2     21-Jan-2013  Madhav Dhurjaty      Modified insert_staging,             *
      *                                           populate_gl_int to mitigate          *
      *                                           Shift+F6 issue.                      *
      *                                           Shift+f6 issue: if users creates a   *
      *                                           new line using copy(shift+f6) the    *
      *                                           previous line, attribute15 of the    *
      *                                           copied lines gets populated to       *
      *                                           attribute15 of new line              *
      * 1.3    30-Apr-2013  Madhav Dhurjaty       Modifications as per changes         *
      *                                           requested during UAT                 *
      * 1.4    16-May-2013  Madhav Dhurjaty       Created procedure Check_BSVAssigned  *
      *                                           function to validate if the balancing*
      *                                           segment is valid for target ledger   *
      * 1.5    24-Jul-2013  Madhav Dhurjaty       Modified procedure Check_BSVAssigned *
      *                                           for defect#DFCT0010552               *
      * 1.6    29-oct-2014  BT technology team    code change for retrofit                                                                *
      *                                                                                *
      *********************************************************************************/
    -- Start retrofit by BT Technology Team on 29-oct-2014 V1.6
    --g_deckers_calendar VARCHAR2(240) := 'Deckers FY Cal';
    g_deckers_calendar   VARCHAR2 (240) := 'DO_FY_CALENDAR';
    -- End retrofit by BT Technology Team on 29-oct-2014 V1.6
    g_mapping_table      VARCHAR2 (240) := 'XXDO_INTERCO_AP_AR_MAPPING';
    g_conc_request_id    NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    g_program_name       VARCHAR2 (240)
        := 'AP Intercompany GL Interface Utility - Deckers';

    FUNCTION check_ledger (p_ledger_id IN NUMBER)
        RETURN BOOLEAN;

    FUNCTION get_interco_ledger (p_ccid IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_credit_ccid (p_ccid IN NUMBER)
        RETURN NUMBER;

    FUNCTION check_debit_ccid (p_ccid            IN     NUMBER,
                               p_dff_ccid        IN     NUMBER,
                               x_valid_segment      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION check_period (p_ledger_id IN NUMBER, p_period IN VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_user_je_source (p_source IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_user_je_category (p_category IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION check_curr_conv_type (p_curr_rate_type IN VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ledger_curr (p_ledger_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION check_rate_exists (p_curr_rate_type IN VARCHAR2, p_conv_date IN VARCHAR2, p_conv_curr IN VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION check_journal_exists (p_journal_name IN VARCHAR2, p_period IN VARCHAR2, p_ledger_id IN NUMBER
                                   , p_source IN VARCHAR2, p_category IN VARCHAR2, p_currency IN VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE get_period_dates (p_period       IN     VARCHAR2,
                                x_start_date      OUT DATE,
                                x_end_date        OUT DATE);

    PROCEDURE insert_staging (p_org_id IN NUMBER, p_period IN VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_curr_rate_type IN VARCHAR2, x_ret_status OUT VARCHAR2
                              , x_ret_msg OUT VARCHAR2);

    PROCEDURE unaccounted_transactions (p_org_id           IN NUMBER,
                                        p_period           IN VARCHAR2,
                                        p_source           IN VARCHAR2,
                                        p_category         IN VARCHAR2,
                                        p_curr_rate_type   IN VARCHAR2);

    PROCEDURE validate_staging (x_ret_status   OUT VARCHAR2,
                                x_ret_msg      OUT VARCHAR2);

    PROCEDURE populate_gl_int (x_ret_status   OUT VARCHAR2,
                               x_ret_msg      OUT VARCHAR2);

    PROCEDURE submit_journal_imp (x_ret_status   OUT VARCHAR2,
                                  x_ret_msg      OUT VARCHAR2);

    PROCEDURE print_output (x_ret_status   OUT VARCHAR2,
                            x_ret_msg      OUT VARCHAR2);

    PROCEDURE main (retcode OUT VARCHAR2, errbuf OUT VARCHAR2, p_org_id IN NUMBER, p_period IN VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2
                    , p_curr_rate_type IN VARCHAR2);
END XXDOGL_AP_INTERCOMPANY_PKG;
/


--
-- XXDOGL_AP_INTERCOMPANY_PKG  (Synonym) 
--
--  Dependencies: 
--   XXDOGL_AP_INTERCOMPANY_PKG (Package)
--
CREATE OR REPLACE SYNONYM XXDO.XXDOGL_AP_INTERCOMPANY_PKG FOR APPS.XXDOGL_AP_INTERCOMPANY_PKG
/
