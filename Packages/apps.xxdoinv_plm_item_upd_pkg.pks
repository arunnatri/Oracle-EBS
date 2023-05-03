--
-- XXDOINV_PLM_ITEM_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINV_PLM_ITEM_UPD_PKG"
AS
    /************************************************************
    * Package Name     : xxdoinv_plm_item_upd_pkg
    *
    * File Type        : Package Specification
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/28/2016     INFOSYS     1.0         Initial Version
    ************************************************************/

    TYPE rec_request_id IS RECORD
    (
        request_id    NUMBER
    );

    TYPE tabtype_request_id IS TABLE OF rec_request_id
        INDEX BY BINARY_INTEGER;

    PROCEDURE msg (pv_msg VARCHAR2, pn_level NUMBER:= 1000);

    PROCEDURE LOG (pv_msg VARCHAR2, pn_level NUMBER:= 1000);

    PROCEDURE update_description (p_item_description VARCHAR2, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2);

    PROCEDURE update_poreq_item_desc (p_item_desc VARCHAR2, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2);

    PROCEDURE validate_lookup_val (pv_lookup_type IN VARCHAR2, pv_lookup_code IN VARCHAR2, pv_lookup_mean IN VARCHAR2
                                   , pv_reterror OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_final_code OUT VARCHAR2);

    PROCEDURE assign_category (pv_segment1 VARCHAR2, pv_segment2 VARCHAR2, pv_segment3 VARCHAR2, pv_segment4 VARCHAR2, pv_segment5 VARCHAR2, pn_item_id NUMBER, pn_organizationid NUMBER, pv_colorwaystatus VARCHAR2, pv_cat_set VARCHAR2
                               , pn_segment1 VARCHAR2, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2);

    PROCEDURE assign_inventory_category (pv_brand VARCHAR2, pv_division VARCHAR2, pv_sub_group VARCHAR2, pv_class VARCHAR2, pv_sub_class VARCHAR2, pv_master_style VARCHAR2, pv_style VARCHAR2, pv_colorway VARCHAR2, pn_organizationid NUMBER, pv_introseason VARCHAR2, pv_colorwaystatus VARCHAR2, pv_size VARCHAR2, pn_item_id NUMBER, pn_segment1 VARCHAR2, pv_retcode OUT VARCHAR2
                                         , pv_reterror OUT VARCHAR2);

    PROCEDURE create_inventory_category (pv_brand VARCHAR2, pv_gender VARCHAR2, pv_prodsubgroup VARCHAR2, pv_class VARCHAR2, pv_sub_class VARCHAR2, pv_master_style VARCHAR2, pv_style_name VARCHAR2, pv_colorway VARCHAR2, pv_clrway VARCHAR2, pv_sub_division VARCHAR2, pv_detail_silhouette VARCHAR2, pv_style VARCHAR2
                                         , pv_structure_id NUMBER, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2);

    PROCEDURE create_category (pv_segment1 VARCHAR2, pv_segment2 VARCHAR2, pv_segment3 VARCHAR2, pv_segment4 VARCHAR2, pv_segment5 VARCHAR2, pv_category_set VARCHAR2
                               , pv_structure_id NUMBER, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2);

    PROCEDURE create_price (pv_style VARCHAR2, pv_pricelistid NUMBER, pv_list_line_id NUMBER, pv_pricing_attr_id NUMBER, pv_uom VARCHAR2, pv_item_id VARCHAR2, pn_org_id NUMBER, pn_price NUMBER, pv_begin_date DATE, pv_end_date DATE, pv_mode VARCHAR2, pv_brand VARCHAR2, pv_current_season VARCHAR2, pv_precedence NUMBER, pv_retcode OUT VARCHAR2
                            , pv_reterror OUT VARCHAR2);

    PROCEDURE validate_valueset (pv_segment1 VARCHAR2, pv_value_set VARCHAR2, pv_description VARCHAR2
                                 , pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2, pv_final_value OUT VARCHAR2);

    PROCEDURE pre_process_validation (p_brand_v IN VARCHAR2, p_style_v IN VARCHAR2, pv_reterror OUT VARCHAR2
                                      , pv_retcode OUT VARCHAR2);

    PROCEDURE update_category (pv_category_id NUMBER, pv_retcode OUT VARCHAR2, pv_reterror OUT VARCHAR2);

    PROCEDURE main (p_reterror OUT VARCHAR2, p_retcode OUT NUMBER, p_style_v IN VARCHAR2
                    , p_color_v IN VARCHAR2, pn_conc_request_id IN NUMBER);


    PROCEDURE main_prc (p_reterror OUT VARCHAR2, p_retcode OUT NUMBER, pv_style_v IN VARCHAR2
                        , pv_color_v IN VARCHAR2, pv_debug_v IN VARCHAR2);
END xxdoinv_plm_item_upd_pkg;
/
