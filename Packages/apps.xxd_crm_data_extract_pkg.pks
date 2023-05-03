--
-- XXD_CRM_DATA_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CRM_DATA_EXTRACT_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_CRM_DATA_EXTRACT_PKG
    * Description     : This package will be used to extract data for CRM
    * Notes           :
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date            Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 28-Jun-2022     1.0           Ramesh BR/Viswanathan      Initial version
    ************************************************************************************************/

    FUNCTION phone_num_mask (pn_contact_point_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION remove_special_char (pv_string IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE generate_customer_csv (
        xv_errbuf                OUT NOCOPY VARCHAR2,
        xv_retcode               OUT NOCOPY VARCHAR2,
        pv_integration_mode                 VARCHAR2,
        pv_mode_check                       VARCHAR2,
        pn_cust_acct_id                     NUMBER);
END xxd_crm_data_extract_pkg;
/
