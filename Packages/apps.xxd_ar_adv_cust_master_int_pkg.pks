--
-- XXD_AR_ADV_CUST_MASTER_INT_PKG  (Package) 
--
--  Dependencies: 
--   FND_LOOKUP_VALUES (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_ADV_CUST_MASTER_INT_PKG"
AS
    /****************************************************************************************
    * Package      : xxd_ar_adv_cust_master_int_pkg
    * Design       : This package will be used as Customer Outbound Interface
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 29-Apr-2021  1.0        Balavenu Rao        Initial Version (CCR0009135)
    ******************************************************************************************/
    PROCEDURE customer_master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_create_file IN VARCHAR2, p_send_mail IN VARCHAR2, p_dummy_email IN VARCHAR2, p_email_id IN VARCHAR2, p_number_days_purg IN NUMBER, p_enter_dates IN VARCHAR2, p_dummy_val IN VARCHAR2
                                   , p_start_date IN VARCHAR2, p_end_date IN VARCHAR2, p_debug_flag IN VARCHAR2);

    TYPE country_record_rec IS RECORD
    (
        country                   fnd_lookup_values.meaning%TYPE,
        sub_region                fnd_lookup_values.attribute1%TYPE,
        region                    fnd_lookup_values.attribute2%TYPE,
        include_state_province    fnd_lookup_values.attribute3%TYPE
    );

    TYPE country_record_tble IS TABLE OF country_record_rec;

    FUNCTION get_country_values_fnc
        RETURN country_record_tble
        PIPELINED;

    TYPE sales_region_record_rec IS RECORD
    (
        country         fnd_lookup_values.tag%TYPE,
        brand           fnd_lookup_values.attribute1%TYPE,
        ou              fnd_lookup_values.attribute2%TYPE,
        sales_region    fnd_lookup_values.attribute3%TYPE
    );

    TYPE sales_region_record_tbl IS TABLE OF sales_region_record_rec;

    FUNCTION get_sales_region_values_fnc
        RETURN sales_region_record_tbl
        PIPELINED;

    TYPE sales_channel_code_record_rec IS RECORD
    (
        sales_channel         fnd_lookup_values.meaning%TYPE,
        sales_channel_code    fnd_lookup_values.DESCRIPTION%TYPE
    );

    TYPE sales_channel_code_record_tbl
        IS TABLE OF sales_channel_code_record_rec;

    FUNCTION get_sale_channel_code_fnc
        RETURN sales_channel_code_record_tbl
        PIPELINED;

    TYPE parent_act_record_rec IS RECORD
    (
        customer_number          fnd_lookup_values.meaning%TYPE,
        parent_account_number    fnd_lookup_values.DESCRIPTION%TYPE,
        parent_account_name      fnd_lookup_values.tag%TYPE
    );

    TYPE parent_act_record_tbl IS TABLE OF parent_act_record_rec;

    FUNCTION get_parent_act_record_fnc
        RETURN parent_act_record_tbl
        PIPELINED;

    TYPE brand_rec IS RECORD
    (
        brand    fnd_lookup_values.meaning%TYPE
    );

    TYPE brand_tbl IS TABLE OF brand_rec;

    FUNCTION get_brand_val_fnc
        RETURN brand_tbl
        PIPELINED;
END xxd_ar_adv_cust_master_int_pkg;
/
