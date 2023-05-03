--
-- XXDO_OM_INT_028_STG_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_OM_INT_028_STG_PKG"
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
    1.0            Viswa and Siva      05-Apr-2012       Initial Version
    1.1            Infosys             17-Apr-2015       Modified to implement the Canada Virtual Warehouse change. Defect ID 958.
    *********************************************************************
    Parameters:
    *********************************************************************/
    PROCEDURE load_xml_data (retcode OUT VARCHAR2, errbuf OUT VARCHAR2);

    PROCEDURE insert_oe_iface_tables (retcode               OUT VARCHAR2,
                                      errbuf                OUT VARCHAR2,
                                      pv_reprocess       IN     VARCHAR2,
                                      pd_rp_start_date   IN     DATE,
                                      pd_rp_end_date     IN     DATE);

    PROCEDURE CALL_ORDER_IMPORT;

    PROCEDURE FETCH_CUSTOMER_ID (pn_dest_id           IN     NUMBER,
                                 pn_customer_id          OUT NUMBER,
                                 pn_customer_number      OUT NUMBER,
                                 pv_status               OUT VARCHAR2,
                                 pv_error_message        OUT VARCHAR2);

    PROCEDURE FETCH_ORG_ID (pn_dc_dest_id      IN     NUMBER,
                            pn_vm_id           IN     NUMBER,
                            pn_dest_id         IN     NUMBER -- Added for 1.1.
                                                            ,
                            pn_org_id             OUT NUMBER,
                            pv_status             OUT VARCHAR2,
                            pv_error_message      OUT VARCHAR2);

    PROCEDURE FETCH_ORDER_SOURCE (pn_order_source_id OUT NUMBER, pv_status OUT VARCHAR2, pv_error_message OUT VARCHAR2);

    PROCEDURE FETCH_ORDER_TYPE (pv_ship_return IN VARCHAR2, pn_org_id IN NUMBER, pn_vw_id IN NUMBER, pn_str_nbr IN NUMBER, pn_order_type_id OUT NUMBER, pv_status OUT VARCHAR2
                                , pv_error_message OUT VARCHAR2);

    PROCEDURE PRINT_AUDIT_REPORT;

    PROCEDURE SO_CANCEL_PRC (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_header_id IN NUMBER
                             , p_line_id IN NUMBER, p_status OUT VARCHAR2);

    PROCEDURE CHK_ORDER_SCHEDULE (errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
END xxdo_om_int_028_stg_pkg;
/
