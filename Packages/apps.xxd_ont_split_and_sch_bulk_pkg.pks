--
-- XXD_ONT_SPLIT_AND_SCH_BULK_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_SPLIT_AND_SCH_BULK_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_SPLIT_AND_SCH_BULK_PKG
    -- Design       : This package will be called by Deckers Automated Split and Schedule Bulk Orders program.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name               Ver    Description
    -- ----------      --------------    -----  ------------------
    -- 25-Jul-2022     Jayarajan A K      1.0    Initial Version (CCR0010085)
    -- #########################################################################################################################

    --split_sch_blk_main procedure
    PROCEDURE split_sch_blk_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_ware_hse_id IN NUMBER, p_brand IN VARCHAR2, p_channel IN VARCHAR2, p_sch_status IN VARCHAR2:= 'BOTH', p_req_date_from IN VARCHAR2, p_req_date_to IN VARCHAR2
                                  , p_debug IN VARCHAR2:= 'N');

    --get_atp_val_prc proecdure
    PROCEDURE get_atp_val_prc (x_atp_qty OUT NUMBER, p_msg_data OUT VARCHAR2, p_err_code OUT VARCHAR2, p_inventory_item_id IN NUMBER, p_org_id IN NUMBER, p_primary_uom_code IN VARCHAR2, p_source_org_id IN NUMBER, p_qty_ordered IN NUMBER, p_req_ship_date IN DATE
                               , p_demand_class_code IN VARCHAR2, x_req_date_qty OUT NUMBER, x_available_date OUT DATE);
END xxd_ont_split_and_sch_bulk_pkg;
/
