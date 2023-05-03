--
-- XXD_PO_MODIFY_CONV_PKG  (Package) 
--
--  Dependencies: 
--   HR_OPERATING_UNITS (View)
--   MTL_PARAMETERS (Synonym)
--   PO_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_MODIFY_CONV_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PO_MODIFY_CONV_PKG
    * Design       : This package is used for PO Modify Move Org Conversion
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 07-Oct-2019  1.0        Viswanathan Pandian     Initial version
    ******************************************************************************************/
    PROCEDURE upload_prc (p_operating_unit IN hr_operating_units.name%TYPE, p_po_number IN po_headers_all.segment1%TYPE, p_warehouse IN mtl_parameters.organization_code%TYPE);

    PROCEDURE master_prc (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_po_header_id IN po_headers_all.po_header_id%TYPE
                          , p_dest_org_id IN mtl_parameters.organization_id%TYPE, p_threads IN NUMBER, p_debug IN VARCHAR2);

    PROCEDURE child_prc (x_retcode            OUT NOCOPY VARCHAR2,
                         x_errbuf             OUT NOCOPY VARCHAR2,
                         p_from_batch_id   IN            NUMBER,
                         p_to_batch_id     IN            NUMBER,
                         p_request_id      IN            NUMBER,
                         p_debug           IN            VARCHAR2);
END xxd_po_modify_conv_pkg;
/
