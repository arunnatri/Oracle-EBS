--
-- XXD_ONT_FREE_ATP_BLK_OM_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_FREE_ATP_BLK_OM_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_FREE_ATP_BLK_OM_PKG
    -- Design       : This package will be called by the Deckers Free ATP Bulk Order Management Program.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name               Ver    Description
    -- ----------      --------------    -----  ------------------
    -- 02-May-2022     Jayarajan A K      1.0    Initial Version (CCR0009893)
    -- #########################################################################################################################

    --free_atp_blk_main procedure
    PROCEDURE free_atp_blk_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER
                                 , p_req_date_from IN VARCHAR2, p_req_date_to IN VARCHAR2, p_debug IN VARCHAR2:= 'N');

    --get_bulk_line_id function
    FUNCTION get_bulk_line_id (pn_line_id IN NUMBER)
        RETURN NUMBER;
END xxd_ont_free_atp_blk_om_pkg;
/
