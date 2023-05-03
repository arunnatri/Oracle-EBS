--
-- XXDOINV_PLM_ITEM_GEN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:08 PM (QP5 v5.362) */

CREATE OR REPLACE PACKAGE APPS."XXDOINV_PLM_ITEM_GEN_PKG" AUTHID CURRENT_USER
IS
   /**********************************************************************************************************
      file name    : xxdoinv_plm_item_gen_pkg.pkb
      created on   : 10-NOV-2014
      created by   : INFOSYS
      purpose      : package specification used for the following
                             1. to create the categories like inventory, OM sales, production line , region ,season and tariff categories.
                             2. to create inventory items for all organizations
                             3. to create wholesale and retail price lists for the all the items
                             4. to assign inventory items to the categories like inventory, OM sales, production line , region ,season and tariff categories.
     ***********************************************************************************************************
     Modification history:
    *****************************************************************************
        NAME:        xxdoinv_plm_item_gen_pkg
        PURPOSE:

        REVISIONS:
        Version        Date        Author           Description
        ---------  ----------  ---------------  ------------------------------------
        1.0         10-NOV-2014   INFOSYS       1. Created this package Specification.
        1.12        11/5/2015     INFOSYS      13. Reprocessing Items - Cost  PLM Errors
        1.35        09/09/2016    INFOSYS      36. Dropped In Current Season Flag Updationg
        1.40        02/26/2017    INFOSYS      41. NRF Changes
		1.41        10/26/2020    Showkath     41. CCR0008684
   *********************************************************************
   *********************************************************************/
   TYPE rec_request_id IS RECORD (
      request_id   NUMBER
   );

   TYPE tabtype_request_id IS TABLE OF rec_request_id
      INDEX BY BINARY_INTEGER;

   PROCEDURE msg (pv_msg VARCHAR2, pn_level NUMBER := 1000);

   PROCEDURE submit_cost_import_proc (
      pv_cost_type   IN       VARCHAR2,
      pv_reterror    OUT      VARCHAR2,
      pv_retcode     OUT      VARCHAR2
   );

   PROCEDURE insert_into_cost_interface (
      pn_item_id    IN       VARCHAR2,
      pv_reterror   OUT      VARCHAR2,
      pv_retcode    OUT      VARCHAR2
   );

   PROCEDURE validate_lookup_val (
      pv_lookup_type   IN       VARCHAR2,
      pv_lookup_code   IN       VARCHAR2,
      pv_lookup_mean   IN       VARCHAR2,
      pv_reterror      OUT      VARCHAR2,
      pv_retcode       OUT      VARCHAR2,
      pv_final_code    OUT      VARCHAR2
   );

   PROCEDURE assign_category (
      pn_batchid                NUMBER,
      pv_segment1               VARCHAR2,
      pv_segment2               VARCHAR2,
      pv_segment3               VARCHAR2,
      pv_segment4               VARCHAR2,
      pv_segment5               VARCHAR2,
      pn_item_id                NUMBER,
      pn_organizationid         NUMBER,
      pv_colorwaystatus         VARCHAR2,
      pv_cat_set                VARCHAR2,
      pv_retcode          OUT   VARCHAR2,
      pv_reterror         OUT   VARCHAR2
   );

   PROCEDURE assign_multi_mem_category (
      pv_cat_set                VARCHAR2,
      pv_segment1               VARCHAR2,
      pv_segment2               VARCHAR2,
      pv_segment3               VARCHAR2,
      pv_segment4               VARCHAR2,
      pv_segment5               VARCHAR2,
      pn_item_id                NUMBER,
      pn_organizationid         NUMBER,
      pv_retcode          OUT   VARCHAR2,
      pv_reterror         OUT   VARCHAR2
   );

   PROCEDURE assign_inventory_category (
      pn_batchid                NUMBER,
      pv_brand                  VARCHAR2,
      pv_division               VARCHAR2,
      pv_sub_group              VARCHAR2,
      pv_class                  VARCHAR2,
      pv_sub_class              VARCHAR2,
      pv_master_style           VARCHAR2,
      pv_style                  VARCHAR2,
      pv_colorway               VARCHAR2,
      pn_organizationid         NUMBER,
      pv_introseason            VARCHAR2,
      pv_colorwaystatus         VARCHAR2,
      pv_size                   VARCHAR2,
      pn_item_id                NUMBER,
      pv_retcode          OUT   VARCHAR2,
      pv_reterror         OUT   VARCHAR2
   );

   PROCEDURE create_inventory_category (
      pv_brand                     VARCHAR2,
      pv_gender                    VARCHAR2,
      pv_prodsubgroup              VARCHAR2,
      pv_class                     VARCHAR2,
      pv_sub_class                 VARCHAR2,
      pv_master_style              VARCHAR2,
      pv_style_name                VARCHAR2,                            -- 1.1
      pv_colorway                  VARCHAR2,
      pv_clrway                    VARCHAR2,
      pv_sub_division              VARCHAR2,
      pv_detail_silhouette         VARCHAR2,
      pv_style                     VARCHAR2,                            -- 1.1
      pv_retcode             OUT   VARCHAR2,
      pv_reterror            OUT   VARCHAR2
   );

   PROCEDURE create_category (
      pv_segment1             VARCHAR2,
      pv_segment2             VARCHAR2,
      pv_segment3             VARCHAR2,
      pv_segment4             VARCHAR2,
      pv_segment5             VARCHAR2,
      pv_category_set         VARCHAR2,
      pv_retcode        OUT   VARCHAR2,
      pv_reterror       OUT   VARCHAR2
   );

   PROCEDURE create_price (
      pv_style                   VARCHAR2,
      pv_pricelistid             NUMBER,
      pv_list_line_id            NUMBER,
      pv_pricing_attr_id         NUMBER,
      pv_uom                     VARCHAR2,
      pv_item_id                 VARCHAR2,
      pn_org_id                  NUMBER,
      pn_price                   NUMBER,
      pv_begin_date              VARCHAR2,
      pv_end_date                VARCHAR2,
      pv_mode                    VARCHAR2,
      pv_brand                   VARCHAR2,
      pv_current_season          VARCHAR2,
      pv_retcode           OUT   VARCHAR2,
      pv_reterror          OUT   VARCHAR2
   );

   PROCEDURE validate_valueset (
      pv_segment1            VARCHAR2,
      pv_value_set           VARCHAR2,
      pv_description         VARCHAR2,
      pv_retcode       OUT   VARCHAR2,
      pv_reterror      OUT   VARCHAR2,
      pv_final_value   OUT   VARCHAR2
   );

   PROCEDURE create_mtl_cross_reference (
      pv_retcode    OUT   VARCHAR2,
      pv_reterror   OUT   VARCHAR2
   );

   PROCEDURE control_proc (
      pv_retcode     OUT   NUMBER,
      pv_errproc     OUT   VARCHAR2,
      pv_brand_v           VARCHAR2,
      pv_style_v           VARCHAR2,
      pv_reprocess         VARCHAR2                       --W.r.t Version 1.12
   );

   PROCEDURE staging_table_purging (
      pv_reterror   OUT   VARCHAR2,
      pv_retcode    OUT   VARCHAR2
   );

   PROCEDURE pre_process_validation (
      pv_brand_v    IN       VARCHAR2,
      pv_style_v    IN       VARCHAR2,
      pv_reterror   OUT      VARCHAR2,
      pv_retcode    OUT      VARCHAR2
   );

   PROCEDURE plm_insert_msii_stg (
      pn_record_id                     NUMBER,
      pn_batch_id                      NUMBER,
      pv_style                         VARCHAR2,
      pv_master_style                  VARCHAR2,
      pn_scale_code_id                 NUMBER,
      pv_color                         VARCHAR2,
      pv_colorway                      VARCHAR2,
      pv_subgroup                      VARCHAR2,
      pv_size                          VARCHAR2,
      pv_inv_type                      VARCHAR2,
      pv_brand                         VARCHAR2,
      pv_product_group                 VARCHAR2,
      pv_class                         VARCHAR2,
      pv_subclass                      VARCHAR2,
      pv_region                        VARCHAR2,
      pv_gender                        VARCHAR2,
      pn_projectedcost                 NUMBER,
      pn_landedcost                    NUMBER,
      pv_templateid                    VARCHAR2,
      pv_styledescription              VARCHAR2,
      pv_currentseason                 VARCHAR2,
      pv_begin_date                    VARCHAR2,
      pv_end_date                      VARCHAR2,
      pv_uom                           VARCHAR2,
      pv_contry_code                   VARCHAR2,
      pv_factory                       VARCHAR2,
      pv_rank                          VARCHAR2,
      pv_colorwaystatus                VARCHAR2,
      pn_tarrif                        VARCHAR2,
      pn_wholesale_price               NUMBER,
      pn_retail_price                  NUMBER,
      pv_upc                           VARCHAR2,
      pn_purchase_cost                 NUMBER,
      pv_item_number                   VARCHAR2,
      pv_item_status                   VARCHAR2,
      pv_cost_type                     VARCHAR2,
      pn_buyer_id                      NUMBER,
      pv_project_type                  VARCHAR2,
      pv_collection                    VARCHAR2,
      pv_item_type                     VARCHAR2,
      pv_supplier                      VARCHAR2,
      pv_production_line               VARCHAR2,
      pv_size_scale_id                 VARCHAR2,
      pv_detail_silhouette             VARCHAR2,
      pv_sub_division                  VARCHAR2,
      pv_lead_time                     VARCHAR2,
      pv_lifecycle                     VARCHAR2,
      pv_user_item_type                VARCHAR2,
      pn_vendor_id                     NUMBER,
      pn_vendor_site_id                NUMBER,
      pv_sourcing_flag                 VARCHAR2,
      pn_po_item_cat_id                NUMBER,
      pv_purchasing_start_date         VARCHAR2,
      pv_purchasing_end_date           VARCHAR2,
      pv_tariff_country_code           VARCHAR2,
      pv_style_name                    VARCHAR2,                        -- 1.1
      pv_nrf_color_code                VARCHAR2,   --Start W.r.t version 1.40 
      pv_nrf_description               VARCHAR2,
      pv_nrf_size_code                 VARCHAR2,
      pv_nrf_size_description          VARCHAR2,
      pv_intro_date                    VARCHAR2,
      pv_tq_sourcing_name              VARCHAR2,
      pv_disable_auto_upc              VARCHAR2,  --w.r.t version 1.47
      pv_ats_date                      VARCHAR2,   --w.r.t version 1.47
      pv_retcode                 OUT   VARCHAR2,
      pv_reterror                OUT   VARCHAR2
   );

   PROCEDURE create_master_item (
      pv_item_number         IN       VARCHAR2,
      pv_item_desc           IN       VARCHAR2,
      pv_primary_uom         IN       VARCHAR2,
      pv_item_type           IN       VARCHAR2,
      pv_size_num            IN       VARCHAR2,
      pv_org_code            IN       VARCHAR2,
      pn_orgn_id             IN       NUMBER,
      pn_inv_item_id         IN       NUMBER,
      pv_buyer_code          IN       VARCHAR2,
      pv_planner_code        IN       VARCHAR2,
      pv_record_status       IN       VARCHAR2,
      pn_template_id         IN       VARCHAR2,
      pv_project_cost        IN       VARCHAR2,
      pv_style               IN       VARCHAR2,
      pv_color_code          IN       VARCHAR2,
      pv_subdivision         IN       VARCHAR2,
      pv_det_silho           IN       VARCHAR2,
      pv_size_scale          IN       VARCHAR2,
      pv_tran_type           IN       VARCHAR2,
      pv_user_item_type      IN       VARCHAR2,
      pv_region              IN       VARCHAR2,
      pv_brand               IN       VARCHAR2,
      pv_department          IN       VARCHAR2,
      pv_upc                 IN       VARCHAR2,
      pv_life_cycle          IN       VARCHAR2,
      pv_scale_code_id       IN       VARCHAR2,
      pv_lead_time           IN       VARCHAR2,
      pv_current_season      IN       VARCHAR2,
      pv_drop_in_season      IN       VARCHAR2,
      -- Added by Infosys on 09Sept2016 - Ver 1.35
      pv_exist_item_status   IN       VARCHAR2,
      pv_nrf_color_code      IN       VARCHAR2,  --W.r.t Version 1.39
      pv_nrf_description     IN       VARCHAR2,
      pv_nrf_size_code       IN       VARCHAR2,
      pv_nrf_size_description   IN       VARCHAR2,
      pv_intro_season         IN       VARCHAR2, --W.r.t Version 1.42
      pv_intro_date           IN       VARCHAR2, --W.r.t Version 1.42
      pv_disable_auto_upc      IN       VARCHAR2, --w.r.t Version 1.47
      pv_ats_date      IN       VARCHAR2, --w.r.t Version 1.47
      xv_err_code            OUT      VARCHAR2,
      xv_err_msg             OUT      VARCHAR2,
      xn_item_id             OUT      NUMBER,
      pv_item_class             IN       VARCHAR2 DEFAULT NULL, -- 1.41
      pv_item_subclass          IN       VARCHAR2 DEFAULT NULL-- 1.41
   );

   PROCEDURE create_src_rule (
      pv_chr_src_name           VARCHAR2,
      pn_num_pri_org            NUMBER,
      pn_vendor_id              NUMBER,
      pn_vendor_site_id         NUMBER,
      pn_rank                   NUMBER,
      pd_begin_date             DATE,
      pd_end_date               DATE,
      pv_num_src_rule     OUT   NUMBER,
      pv_err_code         OUT   VARCHAR2,
      pv_err_msg          OUT   VARCHAR2
   );

   PROCEDURE item_src_assignment (
      pv_chr_operation               VARCHAR2,
      pn_num_assignment              NUMBER,
      pn_num_item                    NUMBER,
      pn_category_id                 NUMBER,
      pn_category_set_id             NUMBER,
      pn_org_id                      NUMBER,
      pn_chr_expiration_date         VARCHAR2,
      pn_num_src_rule_id             NUMBER,
      pn_num_assigment_type          NUMBER,
      pv_err_code              OUT   VARCHAR2,
      pv_err_msg               OUT   VARCHAR2
   );

   PROCEDURE log_error_exception (
      pv_procedure_name   IN   VARCHAR2 DEFAULT NULL,
      pv_operation_code   IN   VARCHAR2 DEFAULT NULL,
      pv_operation_key    IN   VARCHAR2 DEFAULT NULL,
      pv_plm_row_id       IN   VARCHAR2 DEFAULT NULL,
      pv_item_number      IN   VARCHAR2 DEFAULT NULL,
      pv_style            IN   VARCHAR2 DEFAULT NULL,
      pv_color            IN   VARCHAR2 DEFAULT NULL,
      pv_class            IN   VARCHAR2 DEFAULT NULL,
      pv_sub_class        IN   VARCHAR2 DEFAULT NULL,
      pv_size             IN   VARCHAR2 DEFAULT NULL,
      pv_brand            IN   VARCHAR2 DEFAULT NULL,
      pv_gender           IN   VARCHAR2 DEFAULT NULL,
      pv_sub_group        IN   VARCHAR2 DEFAULT NULL,
      pv_master_style     IN   VARCHAR2 DEFAULT NULL,
      pv_season           IN   VARCHAR2 DEFAULT NULL,
      pv_reterror         IN   VARCHAR2 DEFAULT NULL,
      pv_error_code       IN   VARCHAR2 DEFAULT NULL,
      pv_request_id       IN   VARCHAR2 DEFAULT NULL,
      pv_error_type       IN   VARCHAR2 DEFAULT NULL,
      pv_attribute1       IN   VARCHAR2 DEFAULT NULL,
      pv_attribute2       IN   VARCHAR2 DEFAULT NULL
   );
END xxdoinv_plm_item_gen_pkg;
/
