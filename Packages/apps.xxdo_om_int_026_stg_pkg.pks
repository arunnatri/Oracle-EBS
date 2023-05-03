--
-- XXDO_OM_INT_026_STG_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_OM_INT_026_STG_PKG"
IS
    /**********************************************************************************************************
     File Name    : xxdo_om_int_026_stg_pkg.pks
     Created On   : 15-Feb-2012
     Created By   : < >
     Purpose      : Package Specification used for the following
                            1. to load the xml elements into xxdo_inv_int_026_stg2 table
                            2. To Insert the Parsed Records into Order Import Interface Tables
    ***********************************************************************************************************
    Modification History:
    Version        SCN#   By              Date             Comments
    1.0              Viswa and Siva      05-Apr-2012       Initial Version
    1.1              Murali              08-Feb-2013       Added schedule_order procedure to schedule the order lines which failed to process earlier.
    1.6              Infosys             23-Mar-2015       Fix for Sit defect# 1119
    1.7              Infosys            17-Apr-2015       Modified to implement the Canada Virtual Warehouse change. Defect ID 958.
    2.5     Infosys   06-Feb-2016    Added the Profile option for restricting the debug messages
    *********************************************************************
    Parameters:
    *********************************************************************/
    --PROCEDURE load_xml_data (retcode OUT VARCHAR2, errbuf OUT VARCHAR2); -- W.r.t Version 1.6

    GV_XXDO_SCHEDULE_DEBUG_VALUE   VARCHAR2 (2) := NULL;              -----2.5

    PROCEDURE load_xml_data (errbuf OUT VARCHAR2, retcode OUT NUMBER); -- W.r.t Version 1.6

    PROCEDURE insert_oe_iface_tables (retcode OUT VARCHAR2, errbuf OUT VARCHAR2, pv_reprocess IN VARCHAR2, pd_rp_start_date IN DATE, pd_rp_end_date IN DATE, pv_dblink IN VARCHAR2
                                      , p_region IN VARCHAR2);

    PROCEDURE call_order_import;

    PROCEDURE fetch_customer_id (pn_dest_id           IN     NUMBER,
                                 pn_customer_id          OUT NUMBER,
                                 pn_customer_number      OUT NUMBER,
                                 pv_status               OUT VARCHAR2,
                                 pv_error_message        OUT VARCHAR2);

    PROCEDURE fetch_org_id (pn_dc_dest_id IN NUMBER, pn_vm_id IN NUMBER, pn_dest_id IN NUMBER, -- Added for 1.7.
                                                                                               pn_org_id OUT NUMBER, pv_inv_org_code OUT VARCHAR2, pv_status OUT VARCHAR2
                            , pv_error_message OUT VARCHAR2);

    PROCEDURE fetch_order_source (pn_order_source_id OUT NUMBER, pv_status OUT VARCHAR2, pv_error_message OUT VARCHAR2);

    PROCEDURE fetch_order_type (pv_ship_return IN VARCHAR2, pn_org_id IN NUMBER, pn_vw_id IN NUMBER, pn_str_nbr IN NUMBER, pn_order_type_id OUT NUMBER, pv_status OUT VARCHAR2
                                , pv_error_message OUT VARCHAR2);

    FUNCTION fetch_order_type (pv_ship_return IN VARCHAR2, pn_org_id IN NUMBER, pn_vw_id IN NUMBER
                               , pn_str_nbr IN NUMBER)
        RETURN NUMBER;

    PROCEDURE print_audit_report;

    PROCEDURE so_cancel_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_header_id IN NUMBER
                             , p_line_id IN NUMBER, p_status OUT VARCHAR2);

    PROCEDURE chk_order_schedule (errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

    PROCEDURE schedule_order (retcode             OUT VARCHAR2,
                              errbuf              OUT VARCHAR2,
                              p_order_number   IN     NUMBER);

    PROCEDURE insert_oe_iface_tables_th (retcode OUT VARCHAR2, errbuf OUT VARCHAR2, pv_reprocess IN VARCHAR2, pd_rp_start_date IN DATE, pd_rp_end_date IN DATE, pv_dblink IN VARCHAR2, p_region IN VARCHAR2, p_threshold IN NUMBER, p_debug IN VARCHAR2
                                         , p_sql_display IN VARCHAR2);
END xxdo_om_int_026_stg_pkg;
/


GRANT EXECUTE ON APPS.XXDO_OM_INT_026_STG_PKG TO SOA_INT
/
