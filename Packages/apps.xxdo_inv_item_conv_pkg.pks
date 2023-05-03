--
-- XXDO_INV_ITEM_CONV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INV_ITEM_CONV_PKG"
AS
    /******************************************************************************
       NAME:       xxdo_inv_item_conv_pkg
       PURPOSE:    This package contains procedures for One time Item Transmission

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        09/18/2014   Infosys           1. Created this package.
    ******************************************************************************/
    TYPE tabtype_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    PROCEDURE main_extract (
        p_out_var_errbuf         OUT VARCHAR2,
        p_out_var_retcode        OUT NUMBER,
        p_in_var_source       IN     VARCHAR2,
        p_in_var_dest         IN     VARCHAR2 DEFAULT 'US1',
        p_in_var_brand        IN     VARCHAR2,
        p_in_var_gender       IN     VARCHAR2,
        p_in_var_series       IN     VARCHAR2,
        p_in_var_prod_class   IN     VARCHAR2,
        p_in_num_months       IN     NUMBER,
        p_in_var_mode         IN     VARCHAR2 DEFAULT 'Extract',
        p_debug_level         IN     VARCHAR2,
        p_in_var_batch_size   IN     NUMBER,
        p_in_style            IN     VARCHAR2,
        p_in_color            IN     VARCHAR2,
        p_in_size             IN     VARCHAR2);
END xxdo_inv_item_conv_pkg;
/
