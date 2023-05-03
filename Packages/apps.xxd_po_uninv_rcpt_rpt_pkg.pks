--
-- XXD_PO_UNINV_RCPT_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_UNINV_RCPT_RPT_PKG"
AS
    --  ###################################################################################################
    --  Package      : XXD_PO_UNINV_RCPT_RPT_PKG
    --  Design       : This package provides Text extract for Deckers Uninvoiced Receipts Report to BL
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                          Comments
    --  ======================================================================================
    --  15-APR-2021     1.0       Srinath Siricilla               Intial Version 1.0
    --  18-JAN-2022     1.1       Aravind Kannuri                 Updated for CCR0009783
    --  ###################################################################################################

    --
    -- To be used in query as bind variable
    --
    gn_error   CONSTANT NUMBER := 2;



    PROCEDURE main (errbuf                     OUT NOCOPY VARCHAR2,
                    retcode                    OUT NOCOPY NUMBER,
                    p_title                 IN            VARCHAR2,
                    p_accrued_receipts      IN            VARCHAR2,
                    p_inc_online_accruals   IN            VARCHAR2,
                    p_inc_closed_pos        IN            VARCHAR2,
                    p_struct_num            IN            NUMBER,
                    p_category_from         IN            VARCHAR2,
                    p_category_to           IN            VARCHAR2,
                    p_min_accrual_amount    IN            NUMBER,
                    p_period_name           IN            VARCHAR2,
                    p_vendor_from           IN            VARCHAR2,
                    p_vendor_to             IN            VARCHAR2,
                    p_orderby               IN            VARCHAR2,
                    p_file_path             IN            VARCHAR2,
                    p_age_greater_then      IN            VARCHAR2, --Added for 1.1
                    p_cut_off_date          IN            VARCHAR2); --Added for 1.1

    --Start Added for 1.1
    FUNCTION get_usd_conversion (p_currency IN VARCHAR2, p_cutoff_date IN VARCHAR2, p_accrual_amount IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_invoice_age (p_po_header_id IN NUMBER, p_po_line_id IN NUMBER, p_cutoff_date IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_po_preparer (p_po_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_rcpt_receiver (p_po_header_id   IN NUMBER,
                                p_po_line_id     IN NUMBER)
        RETURN VARCHAR2;
--End Added for 1.1

END XXD_PO_UNINV_RCPT_RPT_PKG;
/
