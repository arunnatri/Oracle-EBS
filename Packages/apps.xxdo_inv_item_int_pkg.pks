--
-- XXDO_INV_ITEM_INT_PKG  (Package) 
--
--  Dependencies: 
--   ITEM_DIMENSIONS_OBJ_TAB_TYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INV_ITEM_INT_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_inv_item_int_pkg.sql   1.0    2014/10/06    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_item_int_pkg
    --
    -- Description  :  This is package  for WMS to EBS Item Update Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 06-Oct-14    Infosys            1.0       Created
    -- ***************************************************************************

    TYPE g_inv_org_attr_rec_type IS RECORD
    (
        organization_id    NUMBER,
        warehouse_code     VARCHAR2 (30)
    );

    TYPE g_inv_org_attr_tab_type IS TABLE OF g_inv_org_attr_rec_type
        INDEX BY VARCHAR2 (30);

    --TYPE g_item_tab_type IS TABLE OF xxdo_inv_item_int_stg%ROWTYPE INDEX BY BINARY_INTEGER;

    PROCEDURE insert_item_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_item_tab IN item_dimensions_obj_tab_type);


    PROCEDURE msg (p_in_var_message IN VARCHAR2);

    PROCEDURE lock_records (p_out_chr_errbuf    OUT VARCHAR2,
                            p_out_chr_retcode   OUT VARCHAR2);

    PROCEDURE item_update (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_debug_level IN VARCHAR2);

    PROCEDURE create_uom_conversion (p_from_uom_code VARCHAR2, p_to_uom_code VARCHAR2, p_item_id NUMBER
                                     , p_uom_rate NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_data OUT NOCOPY VARCHAR2);
/*
PROCEDURE update_duplicate_records(p_out_chr_errbuf   OUT VARCHAR2,
                                                        p_out_chr_retcode OUT VARCHAR2
                                                        );
*/

END xxdo_inv_item_int_pkg;
/


GRANT EXECUTE ON APPS.XXDO_INV_ITEM_INT_PKG TO SOA_INT
/
