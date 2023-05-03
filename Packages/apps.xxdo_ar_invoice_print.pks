--
-- XXDO_AR_INVOICE_PRINT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AR_INVOICE_PRINT"
AS
    /*******************************************************************************
    * Program Name : XXDO_AR_INVOICE_PRINT
    * Language     : PL/SQL
    * Description  :
    *
    * History      :
    *
    * WHO          :                 WHAT              Desc                  WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team         1.0 - Initial Version                   16-JAN-2015
    * Infosys            2.0 - Modified to implement parellel processing for invoices.  12-May-2016.
    * BT Technology Team             2.1      Changes for INC0305730       01-Aug-2016
    *                                         to add creation_date logic
    * Madhav Dhurjaty                2.2      Added creation date parameters for CCR0005936 25-AUG-2017
    * -----------------------------------------------------------------------------*/
    FUNCTION remit_to_address_id (p_customer_trx_id IN NUMBER)
        RETURN VARCHAR;

    FUNCTION factored_flag (p_customer_trx_id IN NUMBER)
        RETURN VARCHAR;

    FUNCTION discount_amount_explanation (p_payment_schedule_id IN NUMBER)
        RETURN VARCHAR;

    FUNCTION address_dsp (p_address1 IN VARCHAR2, p_address2 IN VARCHAR2, p_address3 IN VARCHAR2, p_address4 IN VARCHAR2, p_city IN VARCHAR2, p_state IN VARCHAR2, p_postal_code IN VARCHAR2, p_country IN VARCHAR2, p_country_name IN VARCHAR2
                          , p_org_id IN NUMBER)
        RETURN VARCHAR;

    FUNCTION size_quantity_dsp (p_output_option IN VARCHAR, p_customer_trx_id IN NUMBER, p_style IN VARCHAR
                                , p_color IN VARCHAR)
        RETURN VARCHAR;

    FUNCTION org_logo_file_path (p_org_id IN NUMBER)
        RETURN VARCHAR;

    FUNCTION brand_logo_file_path (p_brand IN VARCHAR)
        RETURN VARCHAR;

    PROCEDURE update_print_flag (p_customer_id IN VARCHAR2 DEFAULT NULL, p_trx_class IN VARCHAR2 DEFAULT NULL, p_re_transmit_flag IN VARCHAR2 DEFAULT NULL, p_cust_num_from IN VARCHAR2 DEFAULT NULL, p_cust_num_to IN VARCHAR2 DEFAULT NULL, p_bill_to_site IN VARCHAR2 DEFAULT NULL, p_creation_date_low IN VARCHAR2 DEFAULT NULL, --Added for CCR0005936
                                                                                                                                                                                                                                                                                                                                     p_creation_date_high IN VARCHAR2 DEFAULT NULL, --Added for CCR0005936
                                                                                                                                                                                                                                                                                                                                                                                    p_trx_date_low IN VARCHAR2 DEFAULT NULL, p_trx_date_high IN VARCHAR2 DEFAULT NULL, p_brand IN VARCHAR2 DEFAULT NULL, p_invoice_num_from IN VARCHAR2 DEFAULT NULL, p_invoice_num_to IN VARCHAR2 DEFAULT NULL, p_org_id IN VARCHAR2 DEFAULT NULL, x_return_status OUT VARCHAR2
                                 , x_return_message OUT VARCHAR2);

    PROCEDURE update_pdf_generated_flag (p_customer_id IN VARCHAR2 DEFAULT NULL, p_trx_class IN VARCHAR2 DEFAULT NULL, p_cust_num IN VARCHAR2 DEFAULT NULL, p_trx_date_low IN VARCHAR2 DEFAULT NULL, p_trx_date_high IN VARCHAR2 DEFAULT NULL, --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                                                                                                                                                               p_creation_date_low IN VARCHAR2 DEFAULT NULL, p_creation_date_high IN VARCHAR2 DEFAULT NULL, --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                                                                                                                                                                                                                                                            p_invoice_num_from IN VARCHAR2 DEFAULT NULL, p_invoice_num_to IN VARCHAR2 DEFAULT NULL, p_org_id IN VARCHAR2 DEFAULT NULL, p_batch_id IN NUMBER DEFAULT NULL, -- Added by Infosys. 12-May-2016.
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          x_return_status OUT VARCHAR2
                                         , x_return_message OUT VARCHAR2);

    PROCEDURE soa_event_update (
        p_customer_id          IN VARCHAR2 DEFAULT NULL,
        p_trx_class            IN VARCHAR2 DEFAULT NULL,
        p_cust_num             IN VARCHAR2 DEFAULT NULL,
        p_trx_date_low         IN VARCHAR2 DEFAULT NULL,
        p_trx_date_high        IN VARCHAR2 DEFAULT NULL,
        --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
        p_creation_date_low    IN VARCHAR2 DEFAULT NULL,
        p_creation_date_high   IN VARCHAR2 DEFAULT NULL,
        --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
        p_invoice_num_from     IN VARCHAR2 DEFAULT NULL,
        p_invoice_num_to       IN VARCHAR2 DEFAULT NULL,
        p_org_id               IN VARCHAR2 DEFAULT NULL,
        p_batch_id             IN NUMBER DEFAULT NULL -- Added by Infosys. 12-May-2016.
                                                     );
END;
/
