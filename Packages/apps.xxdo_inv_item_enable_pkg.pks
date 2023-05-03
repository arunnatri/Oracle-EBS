--
-- XXDO_INV_ITEM_ENABLE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INV_ITEM_ENABLE_PKG"
AS
    /******************************************************************************
       NAME:       xxdo_inv_item_enable_pkg
       PURPOSE:    This package contains procedures for One time Item Transmission

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        21-Jul-16   SuneraTech        Initial Creation.
       1.1       28-Mar-16    Bala Murugesan   Modified to include Reprocess Mode
    ******************************************************************************/
    TYPE tabtype_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    PROCEDURE main_extract (p_out_var_errbuf OUT VARCHAR2, p_out_var_retcode OUT NUMBER, p_in_var_source IN VARCHAR2 DEFAULT 'US1', p_in_var_dest IN VARCHAR2, p_in_var_brand IN VARCHAR2, p_in_var_division IN VARCHAR2, p_in_season IN VARCHAR2, p_in_var_mode IN VARCHAR2 DEFAULT 'Copy', p_debug_level IN VARCHAR2, p_in_var_batch_size IN NUMBER, p_in_style IN VARCHAR2, p_in_color IN VARCHAR2, p_in_size IN VARCHAR2, p_in_include_sample IN VARCHAR2 DEFAULT 'N', p_in_include_bgrade IN VARCHAR2 DEFAULT 'N'
                            , p_in_include_org_cats IN VARCHAR2 DEFAULT 'Y');

    -- -----------------------------------------------------------
    -- Procedure to derive the GL code combinations
    -- -----------------------------------------------------------
    PROCEDURE get_conc_code_combn (pn_code_combn_id IN NUMBER, pv_brand IN VARCHAR2, xn_new_ccid OUT NUMBER);

    -- -----------------------------------------------------------
    -- Procedure to create UPC Cross Reference -- Start
    -- -----------------------------------------------------------
    PROCEDURE create_mtl_cross_reference (--                                      pv_retcode           OUT VARCHAR2,
                                          --                                      pv_reterror          OUT VARCHAR2,
                                          p_in_var_source   IN VARCHAR2,
                                          p_in_var_dest     IN VARCHAR2);

    -- -----------------------------------------------------------
    -- Procedure to change the item status from Planned to Active if the costs are available - Start
    -- -----------------------------------------------------------

    PROCEDURE activate_items (
        p_out_var_errbuf         OUT VARCHAR2,
        p_out_var_retcode        OUT NUMBER,
        p_in_var_source       IN     VARCHAR2,
        p_in_var_dest         IN     VARCHAR2,
        p_in_var_brand        IN     VARCHAR2,
        p_in_var_division     IN     VARCHAR2,
        p_in_season           IN     VARCHAR2,
        p_debug_level         IN     VARCHAR2,
        p_in_var_batch_size   IN     NUMBER,
        p_in_style            IN     VARCHAR2,
        p_in_color            IN     VARCHAR2,
        p_in_size             IN     VARCHAR2,
        p_in_include_sample   IN     VARCHAR2 DEFAULT 'N',
        p_in_include_bgrade   IN     VARCHAR2 DEFAULT 'N');
END xxdo_inv_item_enable_pkg;
/
