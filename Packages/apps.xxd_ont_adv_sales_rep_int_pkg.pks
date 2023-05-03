--
-- XXD_ONT_ADV_SALES_REP_INT_PKG  (Package) 
--
--  Dependencies: 
--   FND_LOOKUP_VALUES (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_ADV_SALES_REP_INT_PKG"
AS
    /****************************************************************************************
    * Package      : xxd_ont_adv_sales_rep_int_pkg
    * Design       : This package will be used as Customer Sales Rep Interface to O9.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 10-May-2021   1.0        Balavenu Rao        Initial Version (CCR0009135)
    ******************************************************************************************/
    PROCEDURE xxd_ont_sales_rep_int_prc (
        x_errbuf                OUT NOCOPY VARCHAR2,
        x_retcode               OUT NOCOPY VARCHAR2,
        p_create_file        IN            VARCHAR2,
        p_send_mail          IN            VARCHAR2,
        p_dummy_email        IN            VARCHAR2,
        p_email_id           IN            VARCHAR2,
        p_number_days_purg   IN            NUMBER,
        p_full_load          IN            VARCHAR2,
        p_dummy_val          IN            VARCHAR2,
        p_start_date         IN            VARCHAR2,
        p_debug_flag         IN            VARCHAR2);

    TYPE brand_rec IS RECORD
    (
        brand    fnd_lookup_values.meaning%TYPE
    );

    TYPE brand_tbl IS TABLE OF brand_rec;

    FUNCTION get_brand_val_fnc
        RETURN brand_tbl
        PIPELINED;
END xxd_ont_adv_sales_rep_int_pkg;
/
