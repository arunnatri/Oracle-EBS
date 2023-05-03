--
-- XXDO_IEX_PROFILE_SUMMARY_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_IEX_PROFILE_SUMMARY_PKG"
AS
    /*******************************************************************************
    * Program Name : XXDO_IEX_PROFILE_SUMMARY_PKG
    * Language     : PL/SQL
    * Description  : This package will generateScore for given cust_account_id
    * History      :
    *
    * WHO               WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team          1.0 - Initial Version                 SEP/29/2014
    * --------------------------------------------------------------------------- */
    v_aging_bucket   VARCHAR2 (20);

    PROCEDURE get_order_tot_ship_value (p_cust_id IN NUMBER, p_ord_tot_value OUT NUMBER, p_ship_tot_value OUT NUMBER);

    PROCEDURE get_order_tot_ship_value_cust (p_party_id NUMBER, p_ord_tot_value OUT NUMBER, p_ship_tot_value OUT NUMBER);

    PROCEDURE LOG (p_log_message   IN VARCHAR2,
                   p_module        IN VARCHAR2,
                   p_line_number   IN NUMBER);

    FUNCTION get_Order_header_tax (p_header_id NUMBER)
        RETURN NUMBER;


    FUNCTION get_Order_header_total (p_header_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_precision (p_header_id IN NUMBER)
        RETURN NUMBER;

    --Start of adding new function by BT Technology Team as part of performance improvement process on 09-Nov-2015

    FUNCTION get_precision_by_curr_code (p_currency_code IN VARCHAR2)
        RETURN NUMBER;
--End of adding new function by BT Technology Team as part of performance improvement process on 09-Nov-2015

END xxdo_iex_profile_summary_pkg;
/
