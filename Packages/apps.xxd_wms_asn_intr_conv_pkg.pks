--
-- XXD_WMS_ASN_INTR_CONV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_ASN_INTR_CONV_PKG"
AS
    /******************************************************************************************
     * Package      : XXD_ASN_INTRANSIT_CONV
     * Design       : This package is used for receiving an ASN then scheduling/shipping the corresponding IRISO
     * Notes        :
     * Modification :
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 03-SEP-2019  1.0        Greg Jensen           Initial Version
    ******************************************************************************************/


    --Public access procedure
    PROCEDURE Process_intr_asn (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_shipment_header_id IN NUMBER);
END XXD_WMS_ASN_INTR_CONV_PKG;
/
