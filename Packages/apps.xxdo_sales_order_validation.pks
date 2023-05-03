--
-- XXDO_SALES_ORDER_VALIDATION  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_SALES_ORDER_VALIDATION"
--****************************************************************************************************
--*  NAME       : XXDO_SALES_ORDER_VALIDATION
--*  APPLICATION: Oracle Order Management
--*
--*  AUTHOR     : Sivakumar Boothathan
--*  DATE       : 01-MAR-2017
--*
--*  DESCRIPTION: This package will do the following
--*               A. Intro Season Validation : To check the intro season for the SKU's and take an action
--*                  an action is either to mark them as success or failed if the order line request
--*                  dates is before the intro season date
--*               B. Order type grouping : Based on a mapping the order type will be updated either as
--*                  pre-season or in-season order type
--*  REVISION HISTORY:
--*  Change Date     Version             By              Change Description
--****************************************************************************************************
--* 01-MAR-2017      1.0           Siva Boothathan       Initial Creation
--* 22-JAN-2018      1.1           Siva Boothathan       Creating a new procedure for Duplicate Check
--* 24-MAY-2018      1.2           Infosys               Creating a new procedure for cancel date validation
--* 18-Jul-2018      1.3           Viswanathan Pandian   Creating a new procedure for CCR0007226 to
--*                                                      delete iface records
--* 21-Apr-2020      1.4           Sivakumar Boothathan  Modified for CCR0008604 - To enable deckersb2b
--*                                                      for drop shipments
--* 17-Jun-2020      1.5           Aravind Kannuri   Modified for CCR0008488 - EDI 850 and 860
--* 18-Aug-2020      1.6           Gaurav Joshi      CCR0008657 Implement new VAS, shipping and packing instructions logic
--* 12-FEB-2021      1.7           Aravind Kannuri       Modified for CCR0009192
--*  01-Sep-2021     2.8           Shivanshu Talwar         Modified for CCR0009525
--*  15-Sep-2022     2.10          Shivanshu Talwar         Modified for CCR0010110 : Brand SKU Mismatch
--****************************************************************************************************
IS
    -- Control procedure to navigate the control for the package
    -- Input Operating Unit
    -- Functionality :
    -- A. The input : Operating Unit is taken as the input Parameter
    -- B. Execute the delete scripts which will find the records
    -- in the interface table with the change sequence and delete
    -- C. Call the next procedures for ATP, LAD etc.
    -------------------------------------------------------------

    PROCEDURE release_hold_proc (p_errbuf OUT VARCHAR2,                 -- 2.8
                                                        p_retcode OUT VARCHAR2, p_operating_unit IN NUMBER
                                 , p_osid IN NUMBER);

    PROCEDURE main_control (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_operating_unit IN NUMBER
                            , p_osid IN NUMBER);

    --Start: Added by Infosys for CCR0007225
    --------------------------------------------------------------------
    -- Procedure to validate cancel date
    --------------------------------------------------------------------
    PROCEDURE cancel_date_validation (p_operating_unit   IN NUMBER,
                                      p_osid             IN NUMBER);

    --End : Added by Infosys for CCR0007225

    PROCEDURE order_brand_mismatch (p_operating_unit   IN NUMBER,
                                    p_osid             IN NUMBER); --w.r.t CCR0010110

    -------------------------------------------------------------
    -- Procedure to perform the order line validation
    -- This procedure does the below
    -- A. For the eligable records of Operating unit and Order source
    -- B. The lines will be selected and the SKU's will be
    -- validated with the below logic i.e
    -- It checks for the intro season  in mtl_system_items_b
    -- The intro season's start date should be taken and validated
    -- with the request date and if the request date is before
    -- the item's intro date then mark the line as error
    -- don't mark the error flag
    -------------------------------------------------------------

    PROCEDURE order_line_validation (p_operating_unit   IN NUMBER,
                                     p_osid             IN NUMBER);

    --------------------------------------------------------------------
    -- Procdure to get the order type and the procedure does the below
    -- determine based on creation date and request date of an order
    --------------------------------------------------------------------
    PROCEDURE get_order_type (p_operating_unit IN NUMBER, p_osid IN NUMBER);

    --------------------------------------------------------------------
    -- Procdure to validate for any EDI : 860 i.e updates by an
    -- EDI order and don't process an EDI order if there is a reservation exists
    --------------------------------------------------------------------
    PROCEDURE edi_860_validation (p_operating_unit   IN NUMBER,
                                  p_osid             IN NUMBER);

    ----------------------------------------
    -- Procedure to check for Duplicate Data
    ----------------------------------------
    PROCEDURE order_header_duplicate (p_operating_unit   IN NUMBER,
                                      p_osid             IN NUMBER);

    --------------------------------------------------------------------
    -- Procdure to validate for any inactive SKU lines in IFACE tables
    -- for specific customers and then delete them. Also this will capture
    -- the same set of data to send Hard Reject "R2" status in 855
    --------------------------------------------------------------------
    PROCEDURE edi_855_validation (p_operating_unit   IN NUMBER,
                                  p_osid             IN NUMBER);

    -- Start of changes By Siva Boothathan for CCR0008604
    --------------------------------------------------------------------
    -- Procdure to validate if the customer is enabled for drop shipments
    -- The goal for this procuedure is to change the order type to :
    -- Consumer Direct - US if
    -- The customer number exists in the lookup:XXD_ONT_B2B2C_CUSTOMERS
    -- And also the interface records should have deliver to org ID
    --------------------------------------------------------------------
    PROCEDURE get_b2b2c_ordertype (p_operating_unit   IN NUMBER,
                                   p_osid             IN NUMBER);

    -- End of changes By Siva Boothathan for CCR0008604

    --------------------------------------------------------------------
    -- Start of changes as per Ver 1.5
    --Procedure to Validate and Update EDI 850 SPS Enablement
    PROCEDURE edi_850_sps_validation (p_operating_unit   IN NUMBER,
                                      p_osid             IN NUMBER);

    --Procedure to Update EDI 860 Exclusion
    PROCEDURE edi_860_exclusion (p_operating_unit   IN NUMBER,
                                 p_osid             IN NUMBER);

    --Procedure to Update Line Status Exclusion
    PROCEDURE ord_line_status_chk (p_operating_unit   IN NUMBER,
                                   p_osid             IN NUMBER);

    --Procedure to apply hold on order for 860
    PROCEDURE ord_header_hold_chk (p_operating_unit   IN NUMBER,
                                   p_osid             IN NUMBER);

    FUNCTION get_hz_ship_to_org_id (p_org_id NUMBER, p_customer_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_hz_bill_to_org_id (p_org_id NUMBER, p_customer_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_hz_order_type_id (p_org_id NUMBER, p_customer_id NUMBER)
        RETURN NUMBER;

    TYPE sps_customer_rec_type IS RECORD
    (
        orig_sys_document_ref    VARCHAR2 (100),
        sps_cust_flag            VARCHAR2 (1)
    );

    TYPE sps_customer_tab_type IS TABLE OF sps_customer_rec_type;

    FUNCTION get_sps_details (p_osid NUMBER, p_operating_unit NUMBER)
        RETURN sps_customer_tab_type
        PIPELINED;

    -- END of changes as per Ver 1.5

    -- Added for ver 1.6
    FUNCTION get_vas_code (p_level IN VARCHAR2, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER
                           , p_inventory_item_id IN NUMBER)
        RETURN VARCHAR2;
END xxdo_sales_order_validation;
/
