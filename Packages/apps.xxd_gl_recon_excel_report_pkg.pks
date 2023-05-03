--
-- XXD_GL_RECON_EXCEL_REPORT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_RECON_EXCEL_REPORT_PKG"
AS
    /*
       ********************************************************************************************************************************
       **                                                                                                                             *
       **    Author          : Srinath Siricilla                                                                                      *
       **                                                                                                                             *
       **    Purpose         : This is based on General Ledger Reconciliation Report - Deckers                                        *
       **                      This is excel version of the report.                                                                   *
       **                      This will provide the details of the Text version of report in Excel format.                           *
       **                                                                                                                             *
       **                                                                                                                             *
       **History         :                                                                                                            *
       **------------------------------------------------------------------------------------------                                   *
       **Date        Author              Version   Change Notes                                                                       *
       **----------- ---------           -------   ------------------------------------------------------------                       *
       *29-JUL-2018  Srinath Siricilla   1.0       Initial creation for CCR0007351                                                    *
       ********************************************************************************************************************************/

    -- Global Variables

    p_bank_account_id    NUMBER;
    p_closing_balance    NUMBER;
    p_from_date          VARCHAR2 (100);
    p_as_of_date         VARCHAR2 (100);
    p_report_type        VARCHAR2 (100);
    pv_include_reval     VARCHAR2 (10);
    pv_temp              VARCHAR2 (10);
    pv_exld_prev_reval   VARCHAR2 (10);

    /*********************************************************************************************************************
    * Type                : Procedure                                                                                    *
    * Name                : xxd_main                                                                                     *
    * Purpose             : Function to Initiate the XML data generation                                                 *
    *********************************************************************************************************************/
    FUNCTION xxd_main
        RETURN BOOLEAN;

    /*********************************************************************************************************************
    * Type                : Procedure                                                                                    *
    * Name                : xxd_main_proc                                                                                *
    * Purpose             : To Run both summary procedure and detail procedure                                           *
    *********************************************************************************************************************/
    PROCEDURE xxd_main_proc (p_bank_account_id    IN NUMBER,
                             p_closing_balance    IN NUMBER,
                             p_from_date          IN VARCHAR2,
                             p_as_of_date         IN VARCHAR2,
                             p_report_type        IN VARCHAR2,
                             pv_include_reval     IN VARCHAR2,
                             pv_exld_prev_reval   IN VARCHAR2,
                             pv_temp              IN VARCHAR2);

    /*********************************************************************************************************************
   * Type                : Procedure                                                                                      *
   * Name                : xxd_sum_detail_proc                                                                            *
   * Purpose             : The Summary report lists the General Ledger cash account balance and an adjusted balance for   *
                        the bank statement. It also lists a separate adjustment amount for unreconciled receipts,      *
      payments, and journal entries which have been recorded in the General Ledger cash account,     *
      as well as bank errors.                                                                        *
                           The Detail report provides details for the unreconciled items as well as the information       *
                        contained in the Summary report.This report does not include information on Payroll            *
      payments, Treasury settlements, or external transactions in the Reconciliation Open            *
      Interface because they may have been posted to a different General Ledger account              *
      than the one assigned to the bank account.                                  *
   ************************************************************************************************************************/

    PROCEDURE xxd_sum_detail_proc (p_bank_account_id IN NUMBER, p_closing_balance IN NUMBER, p_from_date IN VARCHAR2, p_as_of_date IN VARCHAR2, p_report_type IN VARCHAR2, pv_include_reval IN VARCHAR2
                                   , pv_exld_prev_reval IN VARCHAR2, p_sum_status OUT VARCHAR2, p_sum_error_msg OUT VARCHAR2);

    FUNCTION xxd_format_amount (p_amount NUMBER)
        RETURN VARCHAR2;
END XXD_GL_RECON_EXCEL_REPORT_PKG;
/
