--
-- XXDO_GTN_PO_COLLABORATION_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_GTN_PO_COLLABORATION_PKG"
IS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Subsystem       : Purchasing
    --  Project         : GT Nexus - Phase 2
    --  Description     : Package for Purchase Order Collaboration
    --  Module          : xxdo_gtn_po_collaboration_pkg
    --  File            : xxdo_gtn_po_collaboration_pkg.pks
    --  Schema          : APPS
    --  Date            : 16-Oct-2014
    --  Version         : 1.0
    --  Author(s)       : Anil Suddapalli [ Suneratech Consulting]
    --  Purpose         : Package used to split the PO Lines based on the split flag sourced from GTN.
    --
    --  dependency      :
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                                  Description
    --  ----------      --------------      -----   --------------------                    ------------------
    --  16-Oct-2014    Anil Suddapalli      1.0                                             Initial Version
    --  24_Nov-2014                         1.1      Added ASN update
    --  06-Jan-2015                         1.2      Added Dropship Order Functioanlity
    --  20-Jan-2015                         1.3      Added Update Dropship PO order price
    --  22-Jan-2015                         1.4      Added Promised Date Changes
    --  03-Mar-2015                         1.5      Added POC Flag changes and new Procedure invoked by SOA
    --  13-Mar-2015                         1.6      Removed Approved flag condition in Update PO line, Shipment procedures
    --  30-Mar-2015                         1.7      Added Approval API
    --  08-Apr-2015                         1.8      Factory code changes at PO line level
    --  09-Apr-2015                         1.9      Added Workflow Backgrund Process to remove dependency on schedule of program
    --  14-Apr-2015                         2.0      BT Retrofit changes
    --  23-Apr-2015                         2.1      BT Retrofit changes - Modified FOB changes at PO line level
    --  21-May-2015                         2.2      BT - Replaced MO:Operating Unit with Security Profile
    --  10-Jun-2015                         2.3      BT - Updating Request date on SO and defaulting EXTERNAL as source type
    --  10-Jun-2015                         2.4      BT - Factory code change - Updating last_update_date, which triggers POA
    --  12-Jun-2015                         2.5      BT - Change to check SO Credit Check Failure hold
    --  29-Jul-2015                         2.6      Launch approval flag as N in Update PO API, we are approving only at end of the POC file
    --                                               Also, we are asking SOA to invoke Approval API at end of the POC file, same as in R12.0.6
    --  14-Sep-2015                         2.7      Check if POC change is for Split type or change in only DFFs and update only DFF values if it is DFF change
    --  16-Sep-2015                         2.8      Including Special VAS Split scenario

    --  ###################################################################################

    PROCEDURE main_proc_validate_poc_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pv_item_key IN VARCHAR2, pv_split_flag IN VARCHAR2, pv_po_number IN VARCHAR2, pv_shipmethod IN VARCHAR2, pn_quantity IN NUMBER, pv_exfactory_date IN VARCHAR2, pn_unit_price IN NUMBER
                                           , pv_new_promised_date IN VARCHAR2, pv_freight_pay_party IN VARCHAR2, pv_original_line_flag IN VARCHAR2);

    PROCEDURE update_po_line (pn_err_code            OUT NUMBER,
                              pv_err_message         OUT VARCHAR2,
                              pn_user_id                 NUMBER,
                              pn_line_num                NUMBER,
                              pn_shipment_num            NUMBER,
                              pv_po_number               VARCHAR2,
                              pn_quantity                NUMBER,
                              pn_unit_price              NUMBER,
                              pd_new_promised_date       DATE);

    PROCEDURE update_shipment_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pv_source VARCHAR2, pn_user_id NUMBER, pn_original_line_num NUMBER, pn_line_num NUMBER, pn_orig_shipment_num NUMBER, pn_shipment_num NUMBER, pv_po_number VARCHAR2, pv_shipmethod VARCHAR2, pd_exfactory_date DATE, pv_freight_pay_party VARCHAR2
                                    , pd_new_promised_date DATE);

    PROCEDURE insert_po_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_po_number VARCHAR2, pv_shipmethod VARCHAR2, pn_quantity NUMBER, pd_exfactory_date DATE, pn_unit_price NUMBER, pd_new_promised_date DATE
                              , pv_freight_pay_party VARCHAR2, xn_line_num OUT NUMBER, xn_shipment_num OUT NUMBER);

    PROCEDURE insert_distribution_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pn_new_line_num NUMBER, pn_new_shipment_num NUMBER, pv_po_number VARCHAR2
                                        , pn_quantity NUMBER);

    PROCEDURE update_asn_line (pn_err_code            OUT NUMBER,
                               pv_err_message         OUT VARCHAR2,
                               pn_user_id                 NUMBER,
                               pn_line_num                NUMBER,
                               pn_shipment_num            NUMBER,
                               pv_po_number               VARCHAR2,
                               pn_quantity                NUMBER,
                               pn_unit_price              NUMBER,
                               pd_new_promised_date       DATE);

    FUNCTION check_order (pv_po_number VARCHAR2, pn_line_num NUMBER)
        RETURN NUMBER;

    PROCEDURE process_normal_po (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_split_flag IN VARCHAR2, pv_po_number IN VARCHAR2, pv_shipmethod IN VARCHAR2, pn_quantity IN NUMBER, pd_exfactory_date IN DATE, pn_unit_price IN NUMBER
                                 , pd_new_promised_date IN DATE, pv_freight_pay_party IN VARCHAR2, pv_original_line_flag IN VARCHAR2);

    PROCEDURE process_dropship_po (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_split_flag IN VARCHAR2, pv_po_number IN VARCHAR2, pv_shipmethod IN VARCHAR2, pn_quantity IN NUMBER, pd_exfactory_date IN DATE, pn_unit_price IN NUMBER
                                   , pd_new_promised_date IN DATE, pv_freight_pay_party IN VARCHAR2, pv_original_line_flag IN VARCHAR2);

    PROCEDURE salesorder_line (pn_err_code       OUT NUMBER,
                               pv_err_message    OUT VARCHAR2,
                               pn_user_id            NUMBER,
                               pn_header_id          NUMBER,
                               pn_line_id            NUMBER,
                               pn_quantity           NUMBER,
                               pd_request_date       DATE,
                               pv_so_source          VARCHAR2,
                               xn_so_line_id     OUT NUMBER);



    PROCEDURE run_programs (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_id NUMBER, pv_po_number IN VARCHAR2, pn_line_num NUMBER
                            , pn_so_new_line_id NUMBER, pn_quantity NUMBER);

    PROCEDURE autocreate_po_from_req (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_so_new_line_id NUMBER, pv_po_number IN VARCHAR2, pn_line_num NUMBER
                                      , pn_new_line_num OUT NUMBER);

    PROCEDURE update_drop_ship_po_line (pn_err_code       OUT NUMBER,
                                        pv_err_message    OUT VARCHAR2,
                                        pn_user_id            NUMBER,
                                        pn_line_num           NUMBER,
                                        pn_new_line_num       NUMBER,
                                        pn_shipment_num       NUMBER,
                                        pv_po_number          VARCHAR2,
                                        pn_unit_price         NUMBER);

    PROCEDURE update_poc_flag (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pv_po_number VARCHAR2);

    PROCEDURE approve_po (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id IN NUMBER
                          , pv_po_number IN VARCHAR2);

    PROCEDURE main_proc_factory_site_line ( -- This procedure is invoked from SOA as part of factory site changes on PO line
        pn_err_code              OUT NUMBER,
        pv_err_message           OUT VARCHAR2,
        pn_line_num           IN     NUMBER,
        pv_po_number          IN     VARCHAR2,
        pv_new_factory_site   IN     VARCHAR2);

    FUNCTION get_so_hold_status (pn_so_header_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE release_so_hold ( -- This procedure is invoked to release hold on SO
                               pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_so_header_id IN NUMBER
                               , pn_user_id IN NUMBER);

    FUNCTION get_type_of_change (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_po_number IN VARCHAR2
                                 , pn_quantity IN NUMBER, pn_unit_price IN NUMBER, pd_new_promised_date IN DATE)
        RETURN VARCHAR2;

    PROCEDURE update_po_dffs (pn_err_code               OUT NUMBER,
                              pv_err_message            OUT VARCHAR2,
                              pn_user_id                    NUMBER,
                              pn_line_num                   NUMBER,
                              pn_shipment_num               NUMBER,
                              pn_distrb_num                 NUMBER,
                              pv_po_number           IN     VARCHAR2,
                              pv_shipmethod          IN     VARCHAR2,
                              pd_exfactory_date      IN     DATE,
                              pv_freight_pay_party   IN     VARCHAR2,
                              pn_order_type_id       IN     NUMBER);

    PROCEDURE process_special_vas_po (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_split_flag IN VARCHAR2, pv_po_number IN VARCHAR2, pv_shipmethod IN VARCHAR2, pn_quantity IN NUMBER, pd_exfactory_date IN DATE, pn_unit_price IN NUMBER
                                      , pd_new_promised_date IN DATE, pv_freight_pay_party IN VARCHAR2, pv_original_line_flag IN VARCHAR2);

    PROCEDURE update_special_vas_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pv_po_number VARCHAR2, pn_quantity NUMBER, pn_unit_price NUMBER, pd_new_promised_date DATE
                                       , pd_exfactory_date DATE);

    PROCEDURE insert_special_vas_line (pn_err_code            OUT NUMBER,
                                       pv_err_message         OUT VARCHAR2,
                                       pn_user_id                 NUMBER,
                                       pn_line_num                NUMBER,
                                       pn_new_line_num            NUMBER,
                                       pn_shipment_num            NUMBER,
                                       pv_po_number               VARCHAR2,
                                       pn_quantity                NUMBER,
                                       pn_unit_price              NUMBER,
                                       pd_new_promised_date       DATE,
                                       pd_exfactory_date          DATE);

    PROCEDURE insert_special_vas_custom_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_new_line_num NUMBER, pn_shipment_num NUMBER, pv_po_number VARCHAR2, pn_quantity NUMBER, pn_unit_price NUMBER, pd_new_promised_date DATE, pd_exfactory_date DATE, pn_old_reservation_id NUMBER
                                              , pn_reservation_id NUMBER);
END xxdo_gtn_po_collaboration_pkg;
/


GRANT EXECUTE ON APPS.XXDO_GTN_PO_COLLABORATION_PKG TO SOA_INT
/

GRANT EXECUTE, DEBUG ON APPS.XXDO_GTN_PO_COLLABORATION_PKG TO XXDO
/
