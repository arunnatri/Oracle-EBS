--
-- XXD_GL_RECON_REPORT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_RECON_REPORT_PKG"
AS
    /*
       ********************************************************************************************************************************
       **                                                                                                                             *
       **    Author          : Infosys                                                                                                *
       **    Created         : 08-NOV-2016                                                                                            *
       **    Description     : This package is used to reconcile the General Ledger cash account balance                              *
       **                      to the bank statement closing balance and to identify any discrepancies in your cash position.         *
       **                      The General Ledger cash account should pertain to only one bank account.                               *
       **           This report is available in Summary and in Detail format.                                              *
       **                                                                                                                             *
       **History         :                                                                                                            *
       **------------------------------------------------------------------------------------------                                   *
       **Date        Author                        Version Change Notes                                                               *
       **----------- --------- ------- ------------------------------------------------------------                                   */


    /*********************************************************************************************************************
    * Type                : Procedure                                                                                    *
    * Name                : xxd_main_proc                                                                                *
    * Purpose             : To Run both summary procedure and detail procedure                                           *
    *********************************************************************************************************************/
    PROCEDURE xxd_main_proc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_bank_account_id IN NUMBER, p_closing_balance IN NUMBER, p_from_date IN VARCHAR2, p_as_of_date IN VARCHAR2
                             , p_report_type IN VARCHAR2);

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

    PROCEDURE xxd_sum_detail_proc (p_bank_account_id IN NUMBER, p_closing_balance IN NUMBER, p_from_date IN VARCHAR2, p_as_of_date IN VARCHAR2, p_report_type IN VARCHAR2, p_sum_status OUT VARCHAR2
                                   , p_sum_error_msg OUT VARCHAR2);
END XXD_GL_RECON_REPORT_PKG;
/
