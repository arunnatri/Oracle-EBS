--
-- XXD_VT_ICS_RECON_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_VT_ICS_RECON_EXTRACT_PKG"
IS
    /****************************************************************************************
  * Package      : XXD_VT_ICS_RECON_EXTRACT_PKG
  * Design       : This package will be used to fetch the VT details and send to blackline
  * Notes        :
  * Modification :
  -- ======================================================================================
  -- Date         Version#   Name                    Comments
  -- ======================================================================================
  -- 02-Jun-2021  1.0        Showkath Ali            Initial Version
  ******************************************************************************************/
    FUNCTION Software_Version
        RETURN VARCHAR2;

    PROCEDURE Tax_Registrations (errbuf OUT VARCHAR2, retcode OUT NUMBER);

    PROCEDURE Sett_Pay_File (errbuf OUT VARCHAR2, retcode OUT NUMBER);

    PROCEDURE Ics_Recon1 (errbuf OUT VARCHAR2, retcode OUT NUMBER);

    PROCEDURE Ics_Balance_Listing (errbuf            OUT VARCHAR2,
                                   retcode           OUT NUMBER,
                                   cAcct_Period   IN     VARCHAR2 DEFAULT '',
                                   cCompany       IN     VARCHAR2 DEFAULT '',
                                   cCurrency      IN     VARCHAR2 DEFAULT '');

    PROCEDURE Ics_Balance_Summary (errbuf            OUT VARCHAR2,
                                   retcode           OUT NUMBER,
                                   cAcct_Period   IN     VARCHAR2 DEFAULT '');


    PROCEDURE Ics_Balance_Total (errbuf            OUT VARCHAR2,
                                 retcode           OUT NUMBER,
                                 cAcct_Period   IN     VARCHAR2 DEFAULT '');

    PROCEDURE Ics_Invoice_Listing (errbuf            OUT VARCHAR2,
                                   retcode           OUT NUMBER,
                                   cAcct_Period   IN     VARCHAR2 DEFAULT '');

    PROCEDURE Ics_GL_Recon (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAcct_Period IN VARCHAR2 DEFAULT ''
                            , cConv_Type IN VARCHAR2 DEFAULT '', cConv_Date IN VARCHAR2 DEFAULT '', cPaired_Sorting IN VARCHAR2 DEFAULT 'N');

    PROCEDURE Ics_GL_Recon_summ (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAcct_Period IN VARCHAR2 DEFAULT '', cConv_Type IN VARCHAR2 DEFAULT '', cConv_Date IN VARCHAR2 DEFAULT '', cSegment1 IN VARCHAR2 DEFAULT 'N', cSegment2 IN VARCHAR2 DEFAULT 'N', cSegment3 IN VARCHAR2 DEFAULT 'N', cSegment4 IN VARCHAR2 DEFAULT 'N', cSegment5 IN VARCHAR2 DEFAULT 'N', cSegment6 IN VARCHAR2 DEFAULT 'N', cSegment7 IN VARCHAR2 DEFAULT 'N'
                                 , cSegment8 IN VARCHAR2 DEFAULT 'N', cSegment9 IN VARCHAR2 DEFAULT 'N', cSegment10 IN VARCHAR2 DEFAULT 'N');

    PROCEDURE Ics_YTD_GL_Recon (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAcct_Period IN VARCHAR2 DEFAULT '', cConv_Type IN VARCHAR2 DEFAULT '', cConv_Date IN VARCHAR2 DEFAULT '', cSegment1 IN VARCHAR2 DEFAULT 'N', cSegment2 IN VARCHAR2 DEFAULT 'N', cSegment3 IN VARCHAR2 DEFAULT 'N', cSegment4 IN VARCHAR2 DEFAULT 'N', cSegment5 IN VARCHAR2 DEFAULT 'N', cSegment6 IN VARCHAR2 DEFAULT 'N', cSegment7 IN VARCHAR2 DEFAULT 'N', cSegment8 IN VARCHAR2 DEFAULT 'N', cSegment9 IN VARCHAR2 DEFAULT 'N', cSegment10 IN VARCHAR2 DEFAULT 'N'
                                , cFile_Path IN VARCHAR2 DEFAULT '');

    PROCEDURE Ics_Day_Aged_By_Status (errbuf OUT VARCHAR2, retcode OUT NUMBER, cCompany IN VARCHAR2 DEFAULT ''
                                      , cRun_Date IN VARCHAR2 DEFAULT '');

    PROCEDURE Ics_Report_Entered (errbuf        OUT VARCHAR2,
                                  retcode       OUT NUMBER,
                                  cCompany   IN     VARCHAR2 DEFAULT '');

    PROCEDURE Ics_payment_data_sheet (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAP_short_code IN VARCHAR2 DEFAULT '');

    PROCEDURE Mtch_det_inv_extract (
        errbuf                  OUT VARCHAR2,
        retcode                 OUT NUMBER,
        cTransaction_Ref     IN     VARCHAR2 DEFAULT '',
        cTransaction_Class   IN     VARCHAR2 DEFAULT '');

    PROCEDURE Mtch_inv_discrep (errbuf OUT VARCHAR2, retcode OUT NUMBER, cOwner_short_code IN VARCHAR2 DEFAULT ''
                                , cPartner_short_code IN VARCHAR2 DEFAULT '');

    PROCEDURE Mtch_sum_intr_bal (errbuf OUT VARCHAR2, retcode OUT NUMBER);

    PROCEDURE Mtch_unmatched_inv (
        errbuf                     OUT VARCHAR2,
        retcode                    OUT NUMBER,
        cSource_Assignment_id   IN     NUMBER DEFAULT NULL,
        cOwner_short_code       IN     VARCHAR2 DEFAULT '',
        cPartner_short_code     IN     VARCHAR2 DEFAULT '');

    PROCEDURE IC_Invoice (errbuf                     OUT VARCHAR2,
                          retcode                    OUT NUMBER,
                          cInvoiceType            IN     VARCHAR2,
                          cSource_id              IN     VARCHAR2,
                          cSource_group_id        IN     VARCHAR2,
                          cSource_assignment_id   IN     VARCHAR2,
                          cInvoiceTaxReg          IN     VARCHAR2,
                          cCustomerTaxReg         IN     VARCHAR2,
                          cInvoice_Number_From    IN     VARCHAR2,
                          cInvoice_Number_To      IN     VARCHAR2,
                          cPurchase_Order         IN     VARCHAR2,
                          cSales_Order            IN     VARCHAR2,
                          cInvoice_Date_Low       IN     VARCHAR2,
                          cInvoice_Date_High      IN     VARCHAR2,
                          cProduct_Family         IN     VARCHAR2,
                          cUnPrinted_Flag         IN     VARCHAR2,
                          cInvoice_class          IN     VARCHAR2);

    PROCEDURE IC_Invoice_Listing (errbuf OUT VARCHAR2, retcode OUT NUMBER, cInvoiceType IN VARCHAR2, cSource_id IN VARCHAR2, cSource_group_id IN VARCHAR2, cSource_assignment_id IN VARCHAR2, cInvoiceTaxReg IN VARCHAR2, cCustomerTaxReg IN VARCHAR2, cInvoice_Date_Low IN VARCHAR2
                                  , cInvoice_Date_High IN VARCHAR2, cUnPrinted_Flag IN VARCHAR2, cInvoice_class IN VARCHAR2);

    PROCEDURE Sub_Journal_Recon (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAccess_Set IN VARCHAR2, cCOA_ID IN VARCHAR2, cLedger_ID IN VARCHAR2, cStart_Date IN VARCHAR2, cEnd_Date IN VARCHAR2, cAccount_From IN VARCHAR2, cAccount_To IN VARCHAR2
                                 , cPosting_Status IN VARCHAR2, cJournal_Source IN VARCHAR2, cJournal_Category IN VARCHAR2);

    PROCEDURE Ics_Day_Aged_By_Status_Det (errbuf OUT VARCHAR2, retcode OUT NUMBER, cCompany IN VARCHAR2 DEFAULT ''
                                          , cRun_Date IN VARCHAR2 DEFAULT '');

    PROCEDURE Ics_Report_Entered_Det (errbuf OUT VARCHAR2, retcode OUT NUMBER, cCompany IN VARCHAR2 DEFAULT ''
                                      , cExch_Rate_Date IN VARCHAR2 DEFAULT '', cExch_Rate_Type IN VARCHAR2 DEFAULT '');

    PROCEDURE Best_Match_Reporting (errbuf OUT VARCHAR2, retcode OUT NUMBER, cStart_Date IN VARCHAR2
                                    , cEnd_Date IN VARCHAR2);
END XXD_VT_ICS_RECON_EXTRACT_PKG;
/
