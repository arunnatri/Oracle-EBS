--
-- XXD_PO_ASN_RECEIVING_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_ASN_RECEIVING_PKG"
AS
    /******************************************************************************************
     * Package      : XXD_PO_ASN_RECEIVING_PKG
     * Design       : This package is used for Receiving ASNs for Direct Ship and Special VAS
     * Notes        :
     * Modification :
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 02-MAY-2019  1.0        Greg Jensen           Initial Version
    ******************************************************************************************/
    --Utility function to split a delivery detail record for an ASN and post the attributes
    PROCEDURE record_error_log (pn_shipment_header_id IN NUMBER, pn_shipment_line_id IN NUMBER:= NULL, pn_status IN VARCHAR2:= 'E'
                                , pv_msg IN VARCHAR2);

    PROCEDURE split_delivery_details (pn_shipment_header_id IN VARCHAR2, pv_error_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR);

    --Main access function to reser the rcv interface for a particular group
    PROCEDURE reset_rcv_interface (pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pn_group_id IN NUMBER);

    --Main access function for Receive ASN Process
    PROCEDURE do_receive (pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pv_asn_number IN VARCHAR2:= NULL
                          , pv_debug IN VARCHAR2);
--Main access function for reprocessing an asn
END XXD_PO_ASN_RECEIVING_PKG;
/
