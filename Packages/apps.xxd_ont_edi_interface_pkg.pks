--
-- XXD_ONT_EDI_INTERFACE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_EDI_INTERFACE_PKG"
AS
    /****************************************************************************************
    * Change#      : CCR0008227
    * Package      : XXD_ONT_EDI_INTERFACE_PKG
    * Description  : This is package for WMS(Highjump) to edi Interface
    * Notes        :
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 11-Mar-2020  1.1         Tejaswi Gangumalla      Intial version
    -- 18-May-2022  1.4         Elaine Yang             Updated for CCR0009997
    -- ===========  ========    ======================= =======================================
    ******************************************************************************************/

    PROCEDURE edi_outbound (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2);

    PROCEDURE purge (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_archival_days IN NUMBER
                     , pn_purge_days IN NUMBER);

    ---updated for CCR0009997
    FUNCTION get_root_line_buyer_part_num (p_child_line_id NUMBER)
        RETURN VARCHAR2;
END XXD_ONT_EDI_INTERFACE_PKG;
/


GRANT EXECUTE ON APPS.XXD_ONT_EDI_INTERFACE_PKG TO SOA_INT
/
