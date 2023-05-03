--
-- XXD_AP_PREPAID_JOURNAL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_PREPAID_JOURNAL_PKG"
AS
    /****************************************************************************************
    * Package      : xxd_ont_sales_rep_int_pkg
    * Design       : This package will be used as Customer Sales Rep Interface to O9.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 10-May-2021   1.0        Balavenu Rao        Initial Version
    ******************************************************************************************/
    PROCEDURE main_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_ledger VARCHAR2, p_accounting_from_date VARCHAR2, p_accounting_to_date VARCHAR2, p_currency_rate_date VARCHAR2, p_period VARCHAR2, p_send_mail VARCHAR2, p_dummy_email VARCHAR2
                        , p_email_id VARCHAR2);

    TYPE segment_values_rec IS RECORD
    (
        identity    VARCHAR2 (50),
        VALUE       VARCHAR2 (50)
    );

    TYPE segment_values_tbl IS TABLE OF segment_values_rec;

    FUNCTION get_segment_values_fnc
        RETURN segment_values_tbl
        PIPELINED;
END XXD_AP_PREPAID_JOURNAL_PKG;
/
