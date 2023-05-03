--
-- XXD_ONT_ADV_SALE_ORDER_INT_PKG  (Package) 
--
--  Dependencies: 
--   FND_LOOKUP_VALUES (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_ADV_SALE_ORDER_INT_PKG"
AS
    /****************************************************************************************
    * Package      : xxd_ont_sales_order_int_pkg
    * Design       : This package will be used as Customer Sales Rep Interface to O9.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 10-May-2021   1.0        Balavenu Rao        Initial Version  (CCR0009135)
    ******************************************************************************************/
    PROCEDURE xxd_ont_sales_order_int_prc (
        x_errbuf                OUT NOCOPY VARCHAR2,
        x_retcode               OUT NOCOPY VARCHAR2,
        p_order_type         IN            VARCHAR2,
        p_region             IN            VARCHAR2,
        p_create_file        IN            VARCHAR2,
        p_send_mail          IN            VARCHAR2,
        p_dummy_email        IN            VARCHAR2,
        p_email_id           IN            VARCHAR2,
        p_number_days_purg   IN            NUMBER,
        p_enter_dates        IN            VARCHAR2,
        p_dummy_val          IN            VARCHAR2,
        p_start_date         IN            VARCHAR2,
        p_end_date           IN            VARCHAR2,
        p_debug_flag         IN            VARCHAR2);

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

    TYPE invetory_org_record_rec IS RECORD
    (
        inv_organization_code    fnd_lookup_values.meaning%TYPE,
        region                   fnd_lookup_values.tag%TYPE
    );

    TYPE invetory_org_record_tbl IS TABLE OF invetory_org_record_rec;

    FUNCTION get_invetory_org_record_fun
        RETURN invetory_org_record_tbl
        PIPELINED;

    TYPE order_typs_record_rec IS RECORD
    (
        order_type    fnd_lookup_values.description%TYPE
    );

    TYPE order_typs_record_tbl IS TABLE OF order_typs_record_rec;

    FUNCTION get_order_typs_record_fun
        RETURN order_typs_record_tbl
        PIPELINED;

    TYPE segment_values_rec IS RECORD
    (
        identity    VARCHAR2 (50),
        VALUE       VARCHAR2 (50)
    );
END xxd_ont_adv_sale_order_int_pkg;
/
