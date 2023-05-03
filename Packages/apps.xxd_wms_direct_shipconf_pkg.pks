--
-- XXD_WMS_DIRECT_SHIPCONF_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--   XXD_WMS_EMAIL_OUTPUT_T (Table)
--
/* Formatted on 4/26/2023 4:25:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_DIRECT_SHIPCONF_PKG"
AS
    /************************************************************************************************
       * Package         : xxd_wms_direct_shipconf_pkg
       * Description     : This package is used to ship confirm the staged pick tickets.(Calling from both SOA and EBS)
       * Notes           :
       * Modification    :
       *-----------------------------------------------------------------------------------------------
       * Date         Version#      Name                   Description
       *-----------------------------------------------------------------------------------------------
       * 13-MAY-2019  1.0           Showkath Ali           Initial Version
       * 16-May-2022  2.0           Gaurav Joshi           Updated for CCR0009921
       * 30-May-2022  2.1           Aravind Kannuri        Updated for CCR0009887
       * 21-Nov-2022  2.2           Shivanshu              Updated for CCR0010291 - Direct Ship Improvements
    * 12-Dec-2022  2.3           Aravind Kannuri        Updated for CCR0009817 - HK Wholesale Changes
       ************************************************************************************************/
    gv_debug_text        VARCHAR2 (4000);
    gn_session_id        NUMBER := USERENV ('SESSIONID');
    gn_debug_id          NUMBER := 0;
    gn_request_id        NUMBER := fnd_global.conc_request_id;
    gv_application       VARCHAR2 (100)
                             := 'Direct Ship – WMS Ship Confirm Process';
    gv_debug_message     VARCHAR2 (1000);
    --Added for 2.1
    gn_created_by        NUMBER := fnd_global.user_id;
    gn_last_updated_by   NUMBER := fnd_global.user_id;
    gd_date              DATE := SYSDATE;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_user_account IN VARCHAR2, p_bol_number IN VARCHAR2, p_container IN VARCHAR2, p_triggering_event IN VARCHAR2
                    ,                                          --Added for 2.1
                      p_delivery_number IN NUMBER              --Added for 2.3
                                                 );

    -- begin ver 2.0
    PROCEDURE update_delivery_attrs (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_event_name IN VARCHAR2
                                     , p_order_number IN NUMBER, p_container_number IN VARCHAR2, p_delivery_number IN NUMBER); --Added for 2.3

    PROCEDURE email_output (p_request_id IN NUMBER);

    --Start Added for 2.1
    FUNCTION get_triggering_event_lkp (p_customer_id IN NUMBER, p_organization_id IN NUMBER, p_triggering_event IN VARCHAR2) --w.r.t 2.2
        RETURN VARCHAR2;

    PROCEDURE ship_confirm_email_out (p_request_id IN NUMBER);

    --End Added for 2.1

    TYPE xxd_wms_email_output_type
        IS TABLE OF xxdo.xxd_wms_email_output_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    PROCEDURE insert_into_email_table (p_data IN xxd_wms_email_output_type);
-- end ver 2.0

END;
/


GRANT EXECUTE ON APPS.XXD_WMS_DIRECT_SHIPCONF_PKG TO SOA_INT
/
