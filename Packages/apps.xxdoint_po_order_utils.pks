--
-- XXDOINT_PO_ORDER_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINT_PO_ORDER_UTILS"
    AUTHID DEFINER
AS
    /**********************************************************************************************************
       file name    : XXDOINT_PO_ORDER_UTILS.pkg
       created on   : 10-NOV-2014
       created by   :
       purpose      : package specification used for the following
      ****************************************************************************
      Modification history:
     *****************************************************************************
         NAME:        XXDOINT_PO_ORDER_UTILS
         PURPOSE:      MIAN PROCEDURE
         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  ------------------------------------
         1.1         9/11/2014                   1. Created this package body.
         1.2         1/23/2020     GJensen        Added functions to get vendor site ID/OU Name based on either PO Number or Inv Number CCR0008186
      **************************************************************************************************************/

    FUNCTION get_po_header_id (p_po_number IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_po_line_id (p_po_number IN VARCHAR2, p_line_number IN NUMBER, p_shipment_number IN NUMBER
                             , p_distribution_number IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_po_line_location_id (p_po_number IN VARCHAR2, p_line_number IN NUMBER, p_shipment_number IN NUMBER
                                      , p_distribution_number IN NUMBER)
        RETURN NUMBER;

    --Start CCR0008186
    FUNCTION get_po_ship_to_name (p_po_number    IN VARCHAR2 := NULL,
                                  p_inv_number   IN VARCHAR2 := NULL)
        RETURN VARCHAR2;

    FUNCTION get_po_vendor_site_id (p_po_number    IN VARCHAR2 := NULL,
                                    p_inv_number   IN VARCHAR2 := NULL)
        RETURN NUMBER;

    FUNCTION get_po_ou_name (p_po_number IN VARCHAR2:= NULL, p_inv_number IN VARCHAR2:= NULL, p_le_name IN VARCHAR2:= NULL)
        RETURN VARCHAR2;

    --End CCR0008186

    FUNCTION get_vendor_site_id (p_vendor_number IN VARCHAR2, p_vendor_site_code IN VARCHAR2, p_business_unit IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_vendor_id (p_vendor_number IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION business_name_to_org_id (p_bu_name IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION org_code_to_org_id (p_org_code IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_dest_org_id (p_po_number IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_dest_org_location_id (p_org_id IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_po_line_unit_price (p_po_number IN VARCHAR2, p_line_number IN NUMBER, p_shipment_number IN NUMBER
                                     , p_distribution_number IN NUMBER)
        RETURN NUMBER;
END;
/


GRANT EXECUTE ON APPS.XXDOINT_PO_ORDER_UTILS TO SOA_INT
/
